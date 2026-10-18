#import <Foundation/Foundation.h>
#import <objc/runtime.h>
static id ShimStubIMP(id self, SEL _cmd, ...) { return nil; }
static id ShimStubInit(id self, SEL _cmd, ...) { return self; }
static BOOL ShimStubResolve(Class c, SEL s, BOOL meta) {
    NSLog(@"SHIM MISSING %c[%@ %@]", meta ? '+' : '-', NSStringFromClass(c), NSStringFromSelector(s));
    BOOL init = !meta && [NSStringFromSelector(s) hasPrefix:@"init"];
    class_addMethod(meta ? object_getClass(c) : c, s, (IMP)(init ? ShimStubInit : ShimStubIMP), "@@:"); return YES; }
__attribute__((visibility("default"))) void *shim_f0(void) __asm__("_NSAppKitVersionNumber");
void *shim_f0(void) { static int n; if (!n++) NSLog(@"SHIM STUB AppKit NSAppKitVersionNumber"); return 0; }
__attribute__((visibility("default"))) NSString *shim_d1 __asm__("_NSApplicationDidBecomeActiveNotification") = @"NSApplicationDidBecomeActiveNotification";
__attribute__((visibility("default"))) NSString *shim_d2 __asm__("_NSApplicationDidChangeScreenParametersNotification") = @"NSApplicationDidChangeScreenParametersNotification";
__attribute__((visibility("default"))) NSString *shim_d3 __asm__("_NSCalibratedRGBColorSpace") = @"NSCalibratedRGBColorSpace";
__attribute__((visibility("default"))) NSString *shim_d4 __asm__("_NSPasteboardTypeString") = @"NSPasteboardTypeString";
__attribute__((visibility("default"))) NSString *shim_d5 __asm__("_NSTextInputContextKeyboardSelectionDidChangeNotification") = @"NSTextInputContextKeyboardSelectionDidChangeNotification";
@interface NSEvent : NSObject @end
@interface NSRunningApplication : NSObject @end
@interface NSWorkspace : NSObject @end
@interface NSResponder : NSObject @end
@interface NSView : NSResponder @end
@interface NSViewController : NSResponder @end
@interface NSScreen : NSObject @end
@interface NSWindow : NSResponder @end
@interface NSWindowController : NSResponder @end
@interface NSApplication : NSResponder @end
@interface NSAlert : NSObject @end
@interface NSBitmapImageRep : NSObject @end
@interface NSImage : NSObject @end
@interface NSCursor : NSObject @end
__attribute__((visibility("default"))) @interface NSInputManager : NSObject @end
@implementation NSInputManager
+ (BOOL)resolveInstanceMethod:(SEL)s { return [super resolveInstanceMethod:s] || ShimStubResolve(self, s, NO); }
+ (BOOL)resolveClassMethod:(SEL)s { return [super resolveClassMethod:s] || ShimStubResolve(self, s, YES); }
@end
__attribute__((visibility("default"))) @interface NSOpenGLContext : NSObject @end
@implementation NSOpenGLContext
+ (BOOL)resolveInstanceMethod:(SEL)s { return [super resolveInstanceMethod:s] || ShimStubResolve(self, s, NO); }
+ (BOOL)resolveClassMethod:(SEL)s { return [super resolveClassMethod:s] || ShimStubResolve(self, s, YES); }
@end
__attribute__((visibility("default"))) @interface NSPasteboard : NSObject @end
@implementation NSPasteboard
+ (BOOL)resolveInstanceMethod:(SEL)s { return [super resolveInstanceMethod:s] || ShimStubResolve(self, s, NO); }
+ (BOOL)resolveClassMethod:(SEL)s { return [super resolveClassMethod:s] || ShimStubResolve(self, s, YES); }
@end
__attribute__((visibility("default"))) @interface NSTrackingArea : NSObject @end
@implementation NSTrackingArea
+ (BOOL)resolveInstanceMethod:(SEL)s { return [super resolveInstanceMethod:s] || ShimStubResolve(self, s, NO); }
+ (BOOL)resolveClassMethod:(SEL)s { return [super resolveClassMethod:s] || ShimStubResolve(self, s, YES); }
@end
