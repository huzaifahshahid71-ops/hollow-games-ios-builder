// Adapted from the verified JSAB API shim; no engine offsets or game logic.
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <dlfcn.h>
#include <string.h>

typedef struct { UInt32 selector, scope, element; } SKAudioAudioAddress;
static const OSStatus SKAudioUnknown = 2003332927;
static const UInt32 SKAudioOutputDevice = 2;
static NSString *SKAudioSelector(UInt32 x) {
    char c[5] = {(char)(x>>24),(char)(x>>16),(char)(x>>8),(char)x,0};
    return [NSString stringWithUTF8String:c] ?: @"?";
}
static UInt32 SKAudioSize(UInt32 selector, BOOL input) {
    switch (selector) {
        case 'dev#': case 'dOut': case 'dSys': case 'dIn ': case 'livn':
        case 'dflt': case 'fsiz': case 'ltnc': case 'saft': case 'stm#': return 4;
        case 'name': return sizeof("iPhone Stereo Output");
        case 'manu': return sizeof("Apple");
        case 'lnam': case 'uid ': case 'lmak': return sizeof(CFStringRef);
        case 'nsrt': return sizeof(Float64);
        case 'nsr#': case 'fsz#': return sizeof(AudioValueRange);
        case 'sfmt': return sizeof(AudioStreamBasicDescription);
        case 'srnd': return offsetof(AudioChannelLayout,mChannelDescriptions);
        case 'slay': return input ? offsetof(AudioBufferList,mBuffers) : sizeof(AudioBufferList);
        default: return 0;
    }
}
static OSStatus SKAudioRead(UInt32 selector, BOOL input, UInt32 *size, void *out) {
    UInt32 need = SKAudioSize(selector,input);
    if (!need) { NSLog(@"SHIM audio unknown property %@",SKAudioSelector(selector)); return SKAudioUnknown; }
    if (!size || !out || *size < need) return 'psiz';
    memset(out,0,need);
    switch (selector) {
        case 'dev#': case 'dOut': case 'dSys': *(UInt32 *)out = SKAudioOutputDevice; break;
        case 'dIn ': break;
        case 'livn': case 'dflt': *(UInt32 *)out = 1; break;
        case 'stm#': *(UInt32 *)out = input ? 0 : 3; break;
        case 'fsiz': *(UInt32 *)out = 512; break;
        case 'ltnc': case 'saft': break;
        case 'name': memcpy(out,"iPhone Stereo Output",need); break;
        case 'manu': memcpy(out,"Apple",need); break;
        case 'lnam': case 'uid ': case 'lmak': {
            CFStringRef value = selector=='uid ' ? CFSTR("silksong.iphone.output") : selector=='lmak' ? CFSTR("Apple") : CFSTR("iPhone Stereo Output");
            *(CFStringRef *)out = CFRetain(value);
            break;
        }
        case 'nsrt': *(Float64 *)out = AVAudioSession.sharedInstance.sampleRate ?: 48000; break;
        case 'nsr#': *(AudioValueRange *)out = (AudioValueRange){48000,48000}; break;
        case 'fsz#': *(AudioValueRange *)out = (AudioValueRange){128,4096}; break;
        case 'slay': {
            AudioBufferList *list = out;
            list->mNumberBuffers = input ? 0 : 1;
            if (!input) list->mBuffers[0].mNumberChannels = 2;
            break;
        }
        case 'srnd': ((AudioChannelLayout *)out)->mChannelLayoutTag=kAudioChannelLayoutTag_Stereo; break;
        case 'sfmt': {
            AudioStreamBasicDescription *format = out;
            *format = (AudioStreamBasicDescription){48000,kAudioFormatLinearPCM,kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked,8,1,8,2,32,0};
            break;
        }
    }
    *size = need;
    NSLog(@"SHIM audio property %@ -> %u bytes",SKAudioSelector(selector),need);
    return noErr;
}
OSStatus AudioHardwareGetPropertyInfo(UInt32 selector, UInt32 *size, Boolean *writable) {
    UInt32 need = SKAudioSize(selector,NO);
    NSLog(@"SHIM audio hardware info %@ -> %u",SKAudioSelector(selector),need);
    if (!need) return SKAudioUnknown;
    if (size) *size=need;
    if (writable) *writable=NO;
    return noErr;
}
OSStatus AudioHardwareGetProperty(UInt32 selector,UInt32 *size,void *out) { return SKAudioRead(selector,NO,size,out); }
OSStatus AudioHardwareAddPropertyListener(UInt32 selector,void *listener,void *context) { return noErr; }
OSStatus AudioDeviceGetPropertyInfo(UInt32 device,UInt32 channel,Boolean input,UInt32 selector,UInt32 *size,Boolean *writable) {
    UInt32 need=SKAudioSize(selector,input);
    NSLog(@"SHIM audio device info %@ input=%u -> %u",SKAudioSelector(selector),input,need);
    if (!need) return SKAudioUnknown;
    if (size) *size=need;
    if (writable) *writable=selector=='fsiz'||selector=='nsrt';
    return noErr;
}
OSStatus AudioDeviceGetProperty(UInt32 device,UInt32 channel,Boolean input,UInt32 selector,UInt32 *size,void *out) { return SKAudioRead(selector,input,size,out); }
OSStatus AudioDeviceSetProperty(UInt32 device,const AudioTimeStamp *time,UInt32 channel,Boolean input,UInt32 selector,UInt32 size,const void *data) {
    NSLog(@"SHIM audio device set %@",SKAudioSelector(selector));
    return selector=='fsiz'||selector=='nsrt' ? noErr : SKAudioUnknown;
}
OSStatus AudioObjectGetPropertyDataSize(UInt32 object,const SKAudioAudioAddress *a,UInt32 qualifierSize,const void *qualifier,UInt32 *out) {
    UInt32 need=SKAudioSize(a->selector,a->scope=='inpt');
    if (!need) { NSLog(@"SHIM audio object size unknown %@",SKAudioSelector(a->selector)); return SKAudioUnknown; }
    if (out) *out=need;
    return noErr;
}
OSStatus AudioObjectGetPropertyData(UInt32 object,const SKAudioAudioAddress *a,UInt32 qualifierSize,const void *qualifier,UInt32 *size,void *out) { return SKAudioRead(a->selector,a->scope=='inpt',size,out); }

__attribute__((constructor)) static void SKAudioActivateAudio(void) {
    @autoreleasepool {
        NSError *error=nil;
        AVAudioSession *session=AVAudioSession.sharedInstance;
        [session setCategory:AVAudioSessionCategoryPlayback error:&error];
        [session setActive:YES error:&error];
        NSLog(@"SHIM iPhone audio session rate=%.0f channels=%lu error=%@",session.sampleRate,(unsigned long)session.outputNumberOfChannels,error);
    }
}
