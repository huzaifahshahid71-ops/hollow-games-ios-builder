#import <Foundation/Foundation.h>
int ShimTargetFPS(void) { return [NSUserDefaults.standardUserDefaults integerForKey:@"SKTargetFPS"]==120?120:60; }
