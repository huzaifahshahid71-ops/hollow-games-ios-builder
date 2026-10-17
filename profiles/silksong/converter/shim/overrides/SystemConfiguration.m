// Unity's Mac player assumes the computer-name Copy query cannot return NULL.
#import "ComputerNameCompat.h"
#import <TargetConditionals.h>
#include <dlfcn.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
struct __SCDynamicStore;
__attribute__((visibility("default"))) CFStringRef SCDynamicStoreCopyComputerName(struct __SCDynamicStore *store, CFStringEncoding *encoding) CF_RETURNS_RETAINED;
CFStringRef SCDynamicStoreCopyComputerName(struct __SCDynamicStore *store, CFStringEncoding *encoding) {
    static CFStringRef (*realCopy)(struct __SCDynamicStore *, CFStringEncoding *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_LAZY | RTLD_LOCAL | RTLD_FIRST);
        if (handle) realCopy = dlsym(handle, "SCDynamicStoreCopyComputerName");
    });
    CFStringRef result = realCopy ? realCopy(store, encoding) : NULL;
    if (result) return result;
#if TARGET_OS_IPHONE
    NSString *name = UIDevice.currentDevice.name;
#else
    NSString *name = NSProcessInfo.processInfo.hostName;
#endif
    static dispatch_once_t logged;
    dispatch_once(&logged, ^{ NSLog(@"SHIM computer-name query: using device-name fallback"); });
    return ShimCopyNameFallback(NULL, encoding, name);
}
