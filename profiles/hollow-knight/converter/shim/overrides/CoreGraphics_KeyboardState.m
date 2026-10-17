#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <stdbool.h>
__attribute__((visibility("default"))) bool CGEventSourceKeyState(int32_t source, uint16_t key) {
 bool (*state)(unsigned short)=dlsym(RTLD_DEFAULT,"ShimIsVirtualKeyDown");return state?state(key):false;
}
