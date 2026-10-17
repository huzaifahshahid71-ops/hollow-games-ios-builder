// CoreGraphics display APIs (macOS-only): one display, the iPad screen, one mode.
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

typedef uint32_t CGDirectDisplayID;
typedef struct ShimDisplayMode *CGDisplayModeRef;
struct ShimDisplayMode { int unused; };
static struct ShimDisplayMode gMode;
enum { kShimDisplay = 1 };

// Measured once on the main thread at load (game threads must not touch UIKit).
static CGSize gPixels = {2752, 2064};
static CGSize gPoints = {1376, 1032};
static double gHz = 120;
__attribute__((constructor)) static void MeasureScreen(void) {
    CGSize s = UIScreen.mainScreen.nativeBounds.size;
    if (s.width > 0) gPixels = s.width >= s.height ? s : CGSizeMake(s.height, s.width);  // games run landscape
    CGSize points = UIScreen.mainScreen.bounds.size;
    if (points.width > 0) gPoints = points.width >= points.height ? points : CGSizeMake(points.height, points.width);
    NSLog(@"SHIM display geometry: points %.0fx%.0f native %.0fx%.0f scale %.2f", gPoints.width,gPoints.height,gPixels.width,gPixels.height,UIScreen.mainScreen.scale);
    if (UIScreen.mainScreen.maximumFramesPerSecond > 0) gHz = UIScreen.mainScreen.maximumFramesPerSecond;
}
static CGSize ScreenPixels(void) { return gPixels; }

#define EXPORT __attribute__((visibility("default")))

EXPORT int32_t CGGetActiveDisplayList(uint32_t max, CGDirectDisplayID *displays, uint32_t *count) {
    if (displays && max) displays[0] = kShimDisplay;
    if (count) *count = 1;
    return 0;
}
EXPORT int32_t CGGetOnlineDisplayList(uint32_t max, CGDirectDisplayID *displays, uint32_t *count) {
    return CGGetActiveDisplayList(max, displays, count);
}
EXPORT CGDirectDisplayID CGMainDisplayID(void) { return kShimDisplay; }
EXPORT CGDisplayModeRef CGDisplayCopyDisplayMode(CGDirectDisplayID d) { return &gMode; }
EXPORT CFArrayRef CGDisplayCopyAllDisplayModes(CGDirectDisplayID d, CFDictionaryRef options) {
    const void *modes[] = { &gMode };
    return CFArrayCreate(NULL, modes, 1, NULL);  // non-CF elements: no retain/release callbacks
}
// Unity compares this owned CF string while restoring a saved screen mode.
EXPORT CFStringRef CGDisplayModeCopyPixelEncoding(CGDisplayModeRef mode) {
    return CFStringCreateCopy(kCFAllocatorDefault, CFSTR("--------RRRRRRRRGGGGGGGGBBBBBBBB"));
}
EXPORT void CGDisplayModeRelease(CGDisplayModeRef m) {}
EXPORT CGDisplayModeRef CGDisplayModeRetain(CGDisplayModeRef m) { return m; }
EXPORT size_t CGDisplayModeGetWidth(CGDisplayModeRef m) { return gPoints.width; }   // UIKit logical points
EXPORT size_t CGDisplayModeGetHeight(CGDisplayModeRef m) { return gPoints.height; }
EXPORT size_t CGDisplayModeGetPixelWidth(CGDisplayModeRef m) { return ScreenPixels().width; }
EXPORT size_t CGDisplayModeGetPixelHeight(CGDisplayModeRef m) { return ScreenPixels().height; }
EXPORT double CGDisplayModeGetRefreshRate(CGDisplayModeRef m) { return gHz; }
EXPORT CGRect CGDisplayBounds(CGDirectDisplayID d) { return (CGRect){CGPointZero,gPoints}; }
EXPORT size_t CGDisplayPixelsWide(CGDirectDisplayID d) { return ScreenPixels().width; }
EXPORT size_t CGDisplayPixelsHigh(CGDirectDisplayID d) { return ScreenPixels().height; }
EXPORT int32_t CGWarpMouseCursorPosition(CGPoint p) { return 0; }
EXPORT int32_t CGAssociateMouseAndMouseCursorPosition(int connected) { return 0; }
EXPORT int CGDisplayIsBuiltin(CGDirectDisplayID d) { return 1; }
EXPORT int CGDisplayIsInMirrorSet(CGDirectDisplayID d) { return 0; }
EXPORT int CGDisplayModeIsUsableForDesktopGUI(CGDisplayModeRef m) { return 1; }
EXPORT uint32_t CGDisplayModeGetIOFlags(CGDisplayModeRef m) { return 0x3; }  // valid + safe
EXPORT uint32_t CGDisplayVendorNumber(CGDirectDisplayID d) { return 0x610; }  // Apple
EXPORT uint32_t CGDisplayModelNumber(CGDirectDisplayID d) { return 1; }
EXPORT uint32_t CGDisplaySerialNumber(CGDirectDisplayID d) { return 1; }
EXPORT CGSize CGDisplayScreenSize(CGDirectDisplayID d) {  // millimetres; iPad Pro/Air panels are 264 ppi
    CGSize p = ScreenPixels(); return CGSizeMake(p.width / 264.0 * 25.4, p.height / 264.0 * 25.4);
}
EXPORT id<MTLDevice> CGDirectDisplayCopyCurrentMetalDevice(CGDirectDisplayID d) NS_RETURNS_RETAINED {
    return MTLCreateSystemDefaultDevice();
}
