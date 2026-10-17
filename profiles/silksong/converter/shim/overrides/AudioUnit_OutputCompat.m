// Guest-local Mac output-unit mapping to the iPhone RemoteIO output.
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <dlfcn.h>
#include <string.h>

AudioComponent AudioComponentFindNext(AudioComponent previous,const AudioComponentDescription *description) {
    typedef AudioComponent (*Fn)(AudioComponent,const AudioComponentDescription *);
    static Fn original;
    if (!original) original=(Fn)dlsym(dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox",RTLD_NOW),"AudioComponentFindNext");
    AudioComponentDescription mapped=*description;
    if (mapped.componentType==kAudioUnitType_Output && (mapped.componentSubType=='ahal'||mapped.componentSubType=='def '||mapped.componentSubType=='sys ')) {
        mapped.componentSubType=kAudioUnitSubType_RemoteIO;
        NSLog(@"SHIM Mac audio output -> RemoteIO");
    }
    return original ? original(previous,&mapped) : NULL;
}
OSStatus AudioUnitSetProperty(AudioUnit unit,AudioUnitPropertyID property,AudioUnitScope scope,AudioUnitElement element,const void *data,UInt32 size) {
    typedef OSStatus (*Fn)(AudioUnit,AudioUnitPropertyID,AudioUnitScope,AudioUnitElement,const void *,UInt32);
    static Fn original;
    if (property==2000) { NSLog(@"SHIM RemoteIO uses current iPhone output route"); return noErr; }
    if (!original) original=(Fn)dlsym(dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox",RTLD_NOW),"AudioUnitSetProperty");
    AudioStreamBasicDescription correctedFormat;
    if (property==kAudioUnitProperty_StreamFormat && size>=sizeof(AudioStreamBasicDescription)) {
        correctedFormat=*(const AudioStreamBasicDescription *)data;
        if (!(correctedFormat.mSampleRate>0)) correctedFormat.mSampleRate=AVAudioSession.sharedInstance.sampleRate ?: 48000;
        data=&correctedFormat;
        const AudioStreamBasicDescription *f=data;
        NSLog(@"SHIM audio format rate=%.0f channels=%u bytes/frame=%u flags=%u",f->mSampleRate,f->mChannelsPerFrame,f->mBytesPerFrame,f->mFormatFlags);
    }
    if (property==kAudioUnitProperty_MaximumFramesPerSlice && size>=4) NSLog(@"SHIM audio maximum frames %u",*(const UInt32 *)data);
    OSStatus result=original?original(unit,property,scope,element,data,size):-1;
    NSLog(@"SHIM audio unit set %u scope=%u element=%u -> %d",property,scope,element,result);
    return result;
}
OSStatus AudioUnitGetProperty(AudioUnit unit,AudioUnitPropertyID property,AudioUnitScope scope,AudioUnitElement element,void *data,UInt32 *size) {
    typedef OSStatus (*Fn)(AudioUnit,AudioUnitPropertyID,AudioUnitScope,AudioUnitElement,void *,UInt32 *);
    static Fn original;
    if (!original) original=(Fn)dlsym(dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox",RTLD_NOW),"AudioUnitGetProperty");
    OSStatus r=original?original(unit,property,scope,element,data,size):-1;
    NSLog(@"SHIM audio unit get %u scope=%u element=%u bytes=%u -> %d",property,scope,element,size?*size:0,r);
    if (!r && property==8 && size && *size>=sizeof(AudioStreamBasicDescription)) {
        AudioStreamBasicDescription *f=data;
        if (!(f->mSampleRate>0)) f->mSampleRate=AVAudioSession.sharedInstance.sampleRate ?: 48000;
        NSLog(@"SHIM audio queried format rate=%.0f channels=%u bytes/frame=%u",f->mSampleRate,f->mChannelsPerFrame,f->mBytesPerFrame);
    }
    return r;
}
