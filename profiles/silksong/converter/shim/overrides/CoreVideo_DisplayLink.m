// Experimental 60 Hz timer-backed Mac display-link adapter.
// Callbacks run on a serial worker queue, not the UIKit main thread.
// This provides engine pacing, not hardware-vblank synchronization.
#import <Foundation/Foundation.h>
#import <CoreVideo/CVBase.h>
#import <CoreVideo/CVReturn.h>
#import <mach/mach_time.h>
#import <stdatomic.h>

typedef struct __CVDisplayLink *CVDisplayLinkRef;
typedef CVReturn (*CVDisplayLinkOutputCallback)(CVDisplayLinkRef, const CVTimeStamp *, const CVTimeStamp *, CVOptionFlags, CVOptionFlags *, void *);

static char kLinkQueueKey;
static _Atomic int TargetHz = 60;
static NSHashTable *Links;
static NSHashTable *LinkRegistry(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ Links = [NSHashTable weakObjectsHashTable]; });
    return Links;
}
static uint64_t PeriodNS(void) { return NSEC_PER_SEC / atomic_load(&TargetHz); }
@interface ShimCVLink : NSObject
@property(strong) dispatch_queue_t queue;
@property(strong) dispatch_source_t timer;
@property CVDisplayLinkOutputCallback callback;
@property void *context;
@property BOOL running;
@property uint32_t displayID;
@property uint64_t count;
@property uint64_t generation;
@end
__attribute__((visibility("default"))) void ShimCVSetTargetFPS(int fps) {
    atomic_store(&TargetHz, fps == 120 ? 120 : 60);
    NSHashTable *registry = LinkRegistry(); NSArray *links;
    @synchronized (registry) { links = registry.allObjects; }
    for (ShimCVLink *link in links) dispatch_async(link.queue, ^{
        if (link.running && link.timer) {
            uint64_t period = PeriodNS();
            dispatch_source_set_timer(link.timer, dispatch_time(DISPATCH_TIME_NOW, period), period, NSEC_PER_MSEC / 4);
        }
    });
    NSLog(@"SHIM display-link target %d Hz", atomic_load(&TargetHz));
}
@implementation ShimCVLink
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("org.jsabcompat.displaylink", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));
        dispatch_queue_set_specific(_queue, &kLinkQueueKey, (__bridge void *)self, NULL);
        _displayID = 1;
        NSHashTable *registry = LinkRegistry();
        @synchronized (registry) { [registry addObject:self]; }
    }
    return self;
}
- (void)dealloc { if (_timer) dispatch_source_cancel(_timer); }
@end
static ShimCVLink *Link(CVDisplayLinkRef ref) { return (__bridge ShimCVLink *)(void *)ref; }
static void OnQueue(ShimCVLink *link, dispatch_block_t work) {
    if (dispatch_get_specific(&kLinkQueueKey) == (__bridge void *)link) work();
    else dispatch_sync(link.queue, work);
}
static CVTimeStamp Stamp(uint64_t host) {
    static mach_timebase_info_data_t base; static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&base); });
    CVTimeStamp stamp = {0};
    stamp.hostTime = host;
    stamp.videoTimeScale = NSEC_PER_SEC;
    stamp.videoTime = (int64_t)(((__uint128_t)host * base.numer) / base.denom);
    stamp.videoRefreshPeriod = PeriodNS();
    stamp.rateScalar = 1.0;
    stamp.flags = kCVTimeStampVideoHostTimeValid | kCVTimeStampVideoRefreshPeriodValid | kCVTimeStampRateScalarValid;
    return stamp;
}
__attribute__((visibility("default"))) CVReturn CVDisplayLinkCreateWithActiveCGDisplays(CVDisplayLinkRef *out) {
    if (!out) return kCVReturnInvalidArgument;
    *out = (CVDisplayLinkRef)CFBridgingRetain([ShimCVLink new]);
    NSLog(@"SHIM display-link created (%d Hz worker timer)", atomic_load(&TargetHz));
    return kCVReturnSuccess;
}
__attribute__((visibility("default"))) CVReturn CVDisplayLinkCreateWithCGDisplay(uint32_t display, CVDisplayLinkRef *out) {
    if (out) *out = NULL;
    if (display != 1) return kCVReturnInvalidArgument;
    return CVDisplayLinkCreateWithActiveCGDisplays(out);
}
__attribute__((visibility("default"))) CVReturn CVDisplayLinkSetCurrentCGDisplay(CVDisplayLinkRef ref, uint32_t display) {
    return ref && display == 1 ? kCVReturnSuccess : kCVReturnInvalidArgument;
}
__attribute__((visibility("default"))) CVReturn CVDisplayLinkSetOutputCallback(CVDisplayLinkRef ref, CVDisplayLinkOutputCallback callback, void *context) {
    if (!ref) return kCVReturnInvalidArgument;
    ShimCVLink *link = Link(ref);
    OnQueue(link, ^{ link.callback = callback; link.context = context; });
    return kCVReturnSuccess;
}
__attribute__((visibility("default"))) CVReturn CVDisplayLinkStart(CVDisplayLinkRef ref) {
    if (!ref) return kCVReturnInvalidArgument;
    NSLog(@"SHIM display-link start %p", ref);
    ShimCVLink *link = Link(ref); __block CVReturn result = kCVReturnSuccess;
    OnQueue(link, ^{
        if (link.running) { result = kCVReturnDisplayLinkAlreadyRunning; return; }
        if (!link.callback) { result = kCVReturnDisplayLinkCallbacksNotSet; return; }
        link.running = YES;
        uint64_t generation = ++link.generation;
        link.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, link.queue);
        uint64_t period = PeriodNS();
        dispatch_source_set_timer(link.timer, dispatch_time(DISPATCH_TIME_NOW, period), period, NSEC_PER_MSEC / 4);
        __weak ShimCVLink *weak = link;
        dispatch_source_set_event_handler(link.timer, ^{
            @autoreleasepool {
                ShimCVLink *live = weak;
                if (!live || !live.running || live.generation != generation || !live.callback) return;
                CVTimeStamp now = Stamp(mach_absolute_time()), output = now;
                static mach_timebase_info_data_t base; static dispatch_once_t once;
                dispatch_once(&once, ^{ mach_timebase_info(&base); });
                uint64_t period = PeriodNS();
                output.hostTime += (uint64_t)(((__uint128_t)period * base.denom) / base.numer);
                output.videoTime += period;
                CVOptionFlags flags = 0;
                live.callback((CVDisplayLinkRef)(__bridge void *)live, &now, &output, 0, &flags, live.context);
                if (++live.count == 1) NSLog(@"SHIM display-link first callback delivered");
            }
        });
        dispatch_resume(link.timer);
    });
    return result;
}
__attribute__((visibility("default"))) CVReturn CVDisplayLinkStop(CVDisplayLinkRef ref) {
    if (!ref) return kCVReturnInvalidArgument;
    NSLog(@"SHIM display-link stop %p", ref);
    ShimCVLink *link = Link(ref); __block CVReturn result = kCVReturnSuccess;
    OnQueue(link, ^{
        if (!link.running) { result = kCVReturnDisplayLinkNotRunning; return; }
        link.running = NO;
        dispatch_source_cancel(link.timer); link.timer = nil;
    });
    return result;
}
__attribute__((visibility("default"))) CVTime CVDisplayLinkGetNominalOutputVideoRefreshPeriod(CVDisplayLinkRef ref) {
    return ref ? (CVTime){1, atomic_load(&TargetHz), 0} : (CVTime){0, 0, kCVTimeIsIndefinite};
}
__attribute__((visibility("default"))) double CVDisplayLinkGetActualOutputVideoRefreshPeriod(CVDisplayLinkRef ref) {
    if (!ref) return 0;
    ShimCVLink *link = Link(ref); __block BOOL running;
    OnQueue(link, ^{ running = link.running; });
    // Timer target interval, not a measured hardware refresh interval.
    return running ? 1.0 / atomic_load(&TargetHz) : 0;
}
__attribute__((visibility("default"))) CVDisplayLinkRef CVDisplayLinkRetain(CVDisplayLinkRef ref) {
    if (ref) CFRetain((CFTypeRef)ref);
    return ref;
}
__attribute__((visibility("default"))) void CVDisplayLinkRelease(CVDisplayLinkRef ref) {
    if (ref) CFRelease((CFTypeRef)ref);
}
