#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <string.h>
#include <stdbool.h>
static int (*HKOriginalGetKey)(int);
static void (*HKRegister)(const char *,const void *);
static void (*HKRegisterFlags)(const char *,const void *,int);
static int HKMacKey(int key) {
 switch(key){case 13:return 36;case 27:return 53;case 32:return 49;case 9:return 48;case 273:return 126;case 274:return 125;case 275:return 124;case 276:return 123;case 97:return 0;case 115:return 1;case 100:return 2;case 102:return 3;case 122:return 6;case 120:return 7;case 99:return 8;case 118:return 9;case 105:return 34;case 109:return 46;}return -1;
}
static int HKGetKey(int key) {
 int mac=HKMacKey(key);bool(*state)(unsigned short)=dlsym(RTLD_DEFAULT,"ShimIsVirtualKeyDown");
 int down=mac>=0&&state&&state(mac);static unsigned logs;if(down&&logs++<30)NSLog(@"HK native key accepted unity=%d mac=%d",key,mac);
 return down?1:(HKOriginalGetKey?HKOriginalGetKey(key):0);
}
static const void *HKInputCall(const char *name,const void *fn) {
 if(name&&strcmp(name,"UnityEngine.Input::GetKeyInt")==0){HKOriginalGetKey=(int(*)(int))fn;NSLog(@"HK installed legacy keyboard state bridge %@",@(name));return (const void *)HKGetKey;}return fn;
}
static void HKAddCall(const char *n,const void *fn){HKRegister(n,HKInputCall(n,fn));}
static void HKAddCallFlags(const char *n,const void *fn,int flags){HKRegisterFlags(n,HKInputCall(n,fn),flags);}
__attribute__((visibility("default"))) void *HKsym(void *handle,const char *name) {
 void *result=dlsym(handle,name);
 if(result&&strcmp(name,"mono_add_internal_call")==0){HKRegister=result;return (void*)HKAddCall;}
 if(result&&strcmp(name,"mono_add_internal_call_with_flags")==0){HKRegisterFlags=result;return (void*)HKAddCallFlags;}
 return result;
}
