// Minimal packed 8-bit RGB/RGBA image storage for Unity's cursor startup path.
// Cursor objects retain their images; visible UIKit pointer integration is not provided.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <stdint.h>

@interface NSBitmapImageRep : NSObject {
    unsigned char *_pixels;
    BOOL _ownsPixels;
    NSInteger _width, _height, _rowBytes, _samples, _bitsPerPixel;
    BOOL _alpha;
    NSUInteger _format;
}
- (instancetype)initWithBitmapDataPlanes:(unsigned char **)planes pixelsWide:(NSInteger)width pixelsHigh:(NSInteger)height bitsPerSample:(NSInteger)bits samplesPerPixel:(NSInteger)samples hasAlpha:(BOOL)alpha isPlanar:(BOOL)planar colorSpaceName:(NSString *)space bitmapFormat:(NSUInteger)format bytesPerRow:(NSInteger)rowBytes bitsPerPixel:(NSInteger)pixelBits;
- (unsigned char *)bitmapData;
- (NSInteger)pixelsWide;
- (NSInteger)pixelsHigh;
- (NSInteger)bytesPerRow;
- (CGImageRef)CGImage;
@end
@implementation NSBitmapImageRep
- (instancetype)initWithBitmapDataPlanes:(unsigned char **)planes pixelsWide:(NSInteger)width pixelsHigh:(NSInteger)height bitsPerSample:(NSInteger)bits samplesPerPixel:(NSInteger)samples hasAlpha:(BOOL)alpha isPlanar:(BOOL)planar colorSpaceName:(NSString *)space bitmapFormat:(NSUInteger)format bytesPerRow:(NSInteger)rowBytes bitsPerPixel:(NSInteger)pixelBits {
    self = [super init];
    if (!self) return nil;
    (void)space;
    if (width <= 0 || height <= 0 || bits != 8 || planar || (samples != 3 && samples != 4) || (alpha && samples != 4) || (format & ~3u)) return nil;
    if ((NSUInteger)width > SIZE_MAX / (NSUInteger)samples) return nil;
    NSUInteger minimum = (NSUInteger)width * (NSUInteger)samples;
    if (!rowBytes) rowBytes = (NSInteger)minimum;
    if (rowBytes < 0 || (NSUInteger)rowBytes < minimum || (NSUInteger)height > (NSUInteger)NSIntegerMax / (NSUInteger)rowBytes) return nil;
    if (pixelBits && pixelBits != samples * 8) return nil;
    _width = width; _height = height; _rowBytes = rowBytes;
    _samples = samples; _bitsPerPixel = samples * 8; _alpha = alpha; _format = format;
    if (planes && planes[0]) _pixels = planes[0];
    else { _pixels = calloc((NSUInteger)height, (NSUInteger)rowBytes); _ownsPixels = YES; }
    if (!_pixels) return nil;
    NSLog(@"SHIM bitmap allocated %ldx%ld rowBytes=%ld", (long)width, (long)height, (long)rowBytes);
    return self;
}
- (void)dealloc { if (_ownsPixels) free(_pixels); }
- (unsigned char *)bitmapData { return _pixels; }
- (NSInteger)pixelsWide { return _width; }
- (NSInteger)pixelsHigh { return _height; }
- (NSInteger)bytesPerRow { return _rowBytes; }
- (CGImageRef)CGImage {
    // Copy bytes so the returned image's provider does not borrow mutable storage.
    CFDataRef data = CFDataCreate(NULL, _pixels, _rowBytes * _height);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageAlphaInfo info = _samples == 3 ? kCGImageAlphaNone : kCGImageAlphaNoneSkipLast;
    if (_alpha) info = (_format & 1) ? ((_format & 2) ? kCGImageAlphaFirst : kCGImageAlphaPremultipliedFirst) : ((_format & 2) ? kCGImageAlphaLast : kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGImageCreate(_width, _height, 8, _bitsPerPixel, _rowBytes, space, (CGBitmapInfo)info, provider, NULL, NO, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space); CGDataProviderRelease(provider); CFRelease(data);
    // Match an unowned getter while keeping the image alive with the representation.
    objc_setAssociatedObject(self, @selector(CGImage), CFBridgingRelease(image), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return (__bridge CGImageRef)objc_getAssociatedObject(self, @selector(CGImage));
}
@end

@interface NSImage : NSObject
@property CGSize size;
@property(strong) NSMutableArray *representations;
- (instancetype)initWithSize:(CGSize)size;
- (void)addRepresentation:(id)representation;
@end
@implementation NSImage
- (instancetype)initWithSize:(CGSize)size { if ((self = [super init])) { _size = size; _representations = [NSMutableArray new]; } return self; }
- (void)addRepresentation:(id)representation { if (representation) [_representations addObject:representation]; }
@end

@interface NSCursor : NSObject
@property(strong) NSImage *image;
@property CGPoint hotSpot;
- (instancetype)initWithImage:(NSImage *)image hotSpot:(CGPoint)point;
+ (NSCursor *)arrowCursor;
+ (void)hide;
+ (void)unhide;
- (void)set;
@end
static NSUInteger gCursorHideCount;
@implementation NSCursor
- (instancetype)initWithImage:(NSImage *)image hotSpot:(CGPoint)point { if ((self = [super init])) { _image = image; _hotSpot = point; } return self; }
+ (NSCursor *)arrowCursor { static NSCursor *cursor; static dispatch_once_t once; dispatch_once(&once, ^{ cursor = [NSCursor new]; }); return cursor; }
+ (void)hide {
    @synchronized(NSCursor.class) { if (gCursorHideCount < NSUIntegerMax) gCursorHideCount++; }
}
+ (void)unhide {
    @synchronized(NSCursor.class) { if (gCursorHideCount) gCursorHideCount--; }
    static dispatch_once_t once;
    dispatch_once(&once, ^{ NSLog(@"SHIM cursor hide/unhide state supported; visible pointer not implemented"); });
}
- (void)set { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"SHIM cursor retained; visible pointer not implemented"); }); }
@end
