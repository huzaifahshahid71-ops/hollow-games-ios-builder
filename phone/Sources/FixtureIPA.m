#import <Foundation/Foundation.h>
#import <zlib.h>
static void HLU16(NSMutableData *d,uint16_t v){uint8_t b[]={v&255,v>>8};[d appendBytes:b length:2];}
static void HLU32(NSMutableData *d,uint32_t v){HLU16(d,v&65535);HLU16(d,v>>16);}
// Stored ZIP entries suffice for this small fixture. All content is project-authored.
BOOL HLExportFixtureIPA(NSString *library,NSString *destination,NSError **error){
 NSData *runner=[NSData dataWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"FixtureRunner" withExtension:nil subdirectory:@"ExportTemplate"] options:0 error:error];if(!runner)return NO;
 NSData *code=[NSData dataWithContentsOfFile:library options:0 error:error];if(!code)return NO;
 NSDictionary *info=@{@"CFBundleExecutable":@"FixtureRunner",@"CFBundleIdentifier":@"com.example.hollowfixtureimport",@"CFBundleName":@"Hollow Import Test",@"CFBundleDisplayName":@"Hollow Import Test",@"CFBundlePackageType":@"APPL",@"CFBundleVersion":@"1",@"CFBundleShortVersionString":@"0.1",@"CFBundleSupportedPlatforms":@[@"iPhoneOS"],@"MinimumOSVersion":@"17.0",@"UIDeviceFamily":@[@1,@2],@"UILaunchScreen":@{},@"UIFileSharingEnabled":@YES,@"UIApplicationSceneManifest":@{@"UIApplicationSupportsMultipleScenes":@NO,@"UISceneConfigurations":@{@"UIWindowSceneSessionRoleApplication":@[@{@"UISceneConfigurationName":@"Fixture",@"UISceneDelegateClassName":@"HLFixtureScene"}]}}};
 NSData *plist=[NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:error];if(!plist)return NO;
 NSArray *names=@[@"Payload/HollowImportTest.app/FixtureRunner",@"Payload/HollowImportTest.app/Info.plist",@"Payload/HollowImportTest.app/Frameworks/CompilerFixture.dll.dylib"];NSArray *contents=@[runner,plist,code];NSMutableData *zip=[NSMutableData new],*central=[NSMutableData new];
 for(NSUInteger i=0;i<names.count;i++){NSData *name=[names[i] dataUsingEncoding:NSUTF8StringEncoding],*data=contents[i];if(data.length>UINT32_MAX)return NO;uint32_t offset=(uint32_t)zip.length,size=(uint32_t)data.length,crc=(uint32_t)crc32(0,data.bytes,size);
 HLU32(zip,0x04034b50);HLU16(zip,20);HLU16(zip,0);HLU16(zip,0);HLU16(zip,0);HLU16(zip,33);HLU32(zip,crc);HLU32(zip,size);HLU32(zip,size);HLU16(zip,(uint16_t)name.length);HLU16(zip,0);[zip appendData:name];[zip appendData:data];
 HLU32(central,0x02014b50);HLU16(central,0x0314);HLU16(central,20);HLU16(central,0);HLU16(central,0);HLU16(central,0);HLU16(central,33);HLU32(central,crc);HLU32(central,size);HLU32(central,size);HLU16(central,(uint16_t)name.length);HLU16(central,0);HLU16(central,0);HLU16(central,0);HLU16(central,0);HLU32(central,(i==1?0100644:0100755)<<16);HLU32(central,offset);[central appendData:name];}
 uint32_t start=(uint32_t)zip.length;[zip appendData:central];HLU32(zip,0x06054b50);HLU16(zip,0);HLU16(zip,0);HLU16(zip,3);HLU16(zip,3);HLU32(zip,(uint32_t)central.length);HLU32(zip,start);HLU16(zip,0);return [zip writeToFile:destination options:NSDataWritingAtomic error:error];
}
