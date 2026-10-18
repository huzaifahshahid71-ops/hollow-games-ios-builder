#import <Foundation/Foundation.h>
extern BOOL HLWriteIPAFromDirectory(NSURL *,NSURL *,void(^)(NSUInteger,unsigned long long),NSError **);
BOOL HLExportCoreIPAWithRuntime(NSString *library,NSString *runtime,NSString *destination,NSError **error){
 NSFileManager *fm=NSFileManager.defaultManager;NSString *bundle=NSBundle.mainBundle.bundlePath,*root=[destination.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"CoreExport/CoreTest.app"];
 if([fm fileExistsAtPath:root]&&![fm removeItemAtPath:root error:error])return NO;
 for(NSString *sub in @[@"Frameworks",@"Managed"])if(![fm createDirectoryAtPath:[root stringByAppendingPathComponent:sub] withIntermediateDirectories:YES attributes:nil error:error])return NO;
 NSDictionary *copies=@{@"ExportTemplate/CoreRunner":@"CoreRunner",@"ExportTemplate/OriginalMono.dylib":@"Frameworks/libmonobdwgc-2.0.dylib",@"Frameworks/libShim_libSystem.dylib":@"Frameworks/libShim_libSystem.dylib",@"Frameworks/libShim_Foundation.dylib":@"Frameworks/libShim_Foundation.dylib",@"Compiler/OriginalManaged/mscorlib.dll":@"Managed/mscorlib.dll"};
 for(NSString *source in copies)if(![fm copyItemAtPath:[bundle stringByAppendingPathComponent:source] toPath:[root stringByAppendingPathComponent:copies[source]] error:error])return NO;
 if(runtime){NSString *target=[root stringByAppendingPathComponent:@"Frameworks/libmonobdwgc-2.0.dylib"];if(![fm removeItemAtPath:target error:error]||![fm copyItemAtPath:runtime toPath:target error:error])return NO;}
 if(![fm copyItemAtPath:library toPath:[root stringByAppendingPathComponent:@"Managed/mscorlib.dll.dylib"] error:error])return NO;
 NSMutableDictionary *info=[@{@"CFBundleExecutable":@"CoreRunner",@"CFBundleIdentifier":@"com.example.hollowcoreimport",@"CFBundleName":@"Hollow Core Test",@"CFBundleDisplayName":@"Hollow Core Test",@"CFBundlePackageType":@"APPL",@"CFBundleVersion":@"1",@"CFBundleShortVersionString":@"0.1",@"CFBundleSupportedPlatforms":@[@"iPhoneOS"],@"MinimumOSVersion":@"17.0",@"UIDeviceFamily":@[@1,@2],@"UILaunchScreen":@{},@"UIFileSharingEnabled":@YES,@"UIApplicationSceneManifest":@{@"UIApplicationSupportsMultipleScenes":@NO,@"UISceneConfigurations":@{@"UIWindowSceneSessionRoleApplication":@[@{@"UISceneConfigurationName":@"Core",@"UISceneDelegateClassName":@"HLCoreScene"}]}}} mutableCopy];info[@"HLPhoneConvertedRuntime"]=@(runtime!=nil);
 if(![info writeToFile:[root stringByAppendingPathComponent:@"Info.plist"] atomically:YES])return NO;
 return HLWriteIPAFromDirectory([NSURL fileURLWithPath:root isDirectory:YES],[NSURL fileURLWithPath:destination],nil,error);
}

BOOL HLExportCoreIPA(NSString *library,NSString *destination,NSError **error){return HLExportCoreIPAWithRuntime(library,nil,destination,error);}
