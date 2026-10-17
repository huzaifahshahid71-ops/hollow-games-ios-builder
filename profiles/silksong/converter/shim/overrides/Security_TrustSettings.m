// Desktop trust-settings enumeration is unavailable on iOS. Never report
// success without populating the owned output array; do not invent trust anchors.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
typedef uint32_t SecTrustSettingsDomain;
#endif
__attribute__((visibility("default"))) OSStatus SecTrustSettingsCopyCertificates(SecTrustSettingsDomain domain, CFArrayRef *certificates) {
    if (!certificates) return errSecParam;
    *certificates = NULL;
    if (domain > 2) return errSecParam;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ NSLog(@"SHIM desktop trust-settings enumeration unavailable -> errSecUnimplemented"); });
    return errSecUnimplemented;
}
