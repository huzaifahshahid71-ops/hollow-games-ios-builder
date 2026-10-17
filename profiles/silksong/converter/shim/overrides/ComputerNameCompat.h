#import <Foundation/Foundation.h>
static inline CFStringRef ShimCopyNameFallback(CFStringRef realName, CFStringEncoding *encoding, NSString *fallback) CF_RETURNS_RETAINED;
static inline CFStringRef ShimCopyNameFallback(CFStringRef realName, CFStringEncoding *encoding, NSString *fallback) {
    if (realName) return realName; // already owned under the system function's Copy rule
    if (encoding) *encoding = kCFStringEncodingUTF8;
    return CFBridgingRetain(fallback.length ? fallback : @"iPhone");
}
