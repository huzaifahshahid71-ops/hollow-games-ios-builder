// Experimental fixed US input source. Paired with CoreServices_Keyboard.m.
// The private token is not an Apple uchr resource and must only reach our translator.
#import <Foundation/Foundation.h>

__attribute__((visibility("default"))) CFStringRef const kTISPropertyUnicodeKeyLayoutData = CFSTR("kTISPropertyUnicodeKeyLayoutData");
__attribute__((visibility("default"))) CFStringRef const kTISPropertyInputSourceID = CFSTR("kTISPropertyInputSourceID");
__attribute__((visibility("default"))) CFStringRef const kTISPropertyInputSourceType = CFSTR("kTISPropertyInputSourceType");
__attribute__((visibility("default"))) CFStringRef const kTISTypeKeyboardLayout = CFSTR("kTISTypeKeyboardLayout");
__attribute__((visibility("default"))) CFStringRef const kTISNotifySelectedKeyboardInputSourceChanged = CFSTR("kTISNotifySelectedKeyboardInputSourceChanged");

static NSDictionary *Source(void) {
    static NSDictionary *source;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const unsigned char token[] = "JSAB-US-KEYBOARD-v1";
        source = @{
            (__bridge NSString *)kTISPropertyUnicodeKeyLayoutData: [NSData dataWithBytes:token length:sizeof(token)],
            (__bridge NSString *)kTISPropertyInputSourceID: @"org.jsabcompat.FixedUS",
            (__bridge NSString *)kTISPropertyInputSourceType: (__bridge NSString *)kTISTypeKeyboardLayout
        };
        NSLog(@"SHIM keyboard fixed US source ready (experimental)");
    });
    return source;
}
__attribute__((visibility("default"))) CFTypeRef TISCopyCurrentASCIICapableKeyboardLayoutInputSource(void) {
    return CFBridgingRetain(Source());
}
__attribute__((visibility("default"))) CFTypeRef TISCopyCurrentKeyboardLayoutInputSource(void) {
    return CFBridgingRetain(Source());
}
__attribute__((visibility("default"))) CFTypeRef TISCopyCurrentKeyboardInputSource(void) {
    return CFBridgingRetain(Source());
}
__attribute__((visibility("default"))) CFTypeRef TISGetInputSourceProperty(CFTypeRef source, CFStringRef property) {
    if (!source || !property || CFGetTypeID(source) != CFDictionaryGetTypeID()) return NULL;
    return CFDictionaryGetValue((CFDictionaryRef)source, property);
}
__attribute__((visibility("default"))) uint8_t LMGetKbdType(void) { return 40; }
