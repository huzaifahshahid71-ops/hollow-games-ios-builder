#import <Foundation/Foundation.h>
extern BOOL HLFinishHollowKnightGameIPA(NSURL *,NSURL *,void(^)(NSString *),NSDictionary **,NSError **);
// Private integration fixture only. Never part of the original-folder import path.
BOOL HLRunPrivateGameExport(void(^progress)(NSString *),NSDictionary **report,NSError **error){
 NSFileManager *fm=NSFileManager.defaultManager;NSString *bundle=NSBundle.mainBundle.bundlePath,*apps=bundle.stringByDeletingLastPathComponent;
 if(![NSBundle.mainBundle.infoDictionary[@"HLAllowDiagnosticPackedAssets"] boolValue]||![apps.lastPathComponent isEqual:@"Applications"]){if(error)*error=[NSError errorWithDomain:@"PrivateFixture" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Private LiveContainer fixture guard failed."}];return NO;}
 BOOL sk=[NSBundle.mainBundle.infoDictionary[@"HLGameProfile"] isEqual:@"silksong"];NSString *game=sk?@"silksong":@"hollow-knight",*workingBid=sk?@"com.example.silksongport.app":@"com.example.hollowknightport.app";
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 NSString *fixture=[docs stringByAppendingPathComponent:[@"GameSourceFixture-" stringByAppendingString:NSUUID.UUID.UUIDString]],*contents=[fixture stringByAppendingPathComponent:@"Contents"],*working=[[apps stringByAppendingPathComponent:workingBid] stringByAppendingPathComponent:@"Mac/Contents"],*templates=[apps stringByAppendingPathComponent:@"com.example.hollowloaderprobe.app/ExportTemplate"];
 NSData *manifest=[NSData dataWithContentsOfFile:[templates stringByAppendingPathComponent:sk?@"sk-engine-imports.json":@"hk-engine-imports.json"]];if(!manifest)return NO;NSArray *entries=[NSJSONSerialization JSONObjectWithData:manifest options:0 error:error];if(entries.count!=9)return NO;
 NSMutableSet *native=[NSMutableSet new];for(NSDictionary *entry in entries)[native addObject:entry[@"relative_path"]];
 BOOL okay=[fm createDirectoryAtPath:contents withIntermediateDirectories:YES attributes:nil error:error];
 __block NSError *walkError=nil;NSDirectoryEnumerator *walker=[fm enumeratorAtURL:[NSURL fileURLWithPath:working isDirectory:YES] includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url,NSError *failure){walkError=failure;return NO;}];if(!walker)okay=NO;
 for(NSURL *url in walker){@autoreleasepool{if(!okay)break;NSString *relative=[url.path substringFromIndex:working.length+1];if([relative isEqual:@"Resources/Data/Managed"]||[relative isEqual:@"_CodeSignature"]){[walker skipDescendants];continue;}NSDictionary *attrs=[fm attributesOfItemAtPath:url.path error:error];if([attrs[NSFileType] isEqual:NSFileTypeDirectory])continue;if(![attrs[NSFileType] isEqual:NSFileTypeRegular]){okay=NO;break;}if([native containsObject:relative]||[relative isEqual:@"Info.plist"])continue;
  NSString *out=[contents stringByAppendingPathComponent:relative];okay=[fm createDirectoryAtPath:out.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]&&[fm linkItemAtPath:url.path toPath:out error:error];
 }}
 if(walkError){okay=NO;if(error)*error=walkError;}
 if(okay)okay=[fm copyItemAtPath:[[apps stringByAppendingPathComponent:workingBid] stringByAppendingPathComponent:@"Info.plist"] toPath:[contents stringByAppendingPathComponent:@"Info.plist"] error:error];
 NSString *managed=[contents stringByAppendingPathComponent:@"Resources/Data/Managed"];if(okay)okay=[fm createDirectoryAtPath:managed withIntermediateDirectories:YES attributes:nil error:error];
 NSDictionary *profile=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[bundle stringByAppendingPathComponent:[NSString stringWithFormat:@"Profiles/%@.json",game]]] options:0 error:error];
 for(NSString *name in profile[@"managed_sha256"]){if(!okay)break;okay=[fm linkItemAtPath:[bundle stringByAppendingPathComponent:[@"Compiler/OriginalManaged/" stringByAppendingString:name]] toPath:[managed stringByAppendingPathComponent:name] error:error];}
 for(NSDictionary *entry in entries){@autoreleasepool{if(!okay)break;NSData *wrapped=[NSData dataWithContentsOfFile:[templates stringByAppendingPathComponent:[entry[@"resource"] stringByAppendingString:@".data"]]];if(wrapped.length<=16||memcmp(wrapped.bytes,"HLRAWINPUTv1\0\0\0\0",16)){okay=NO;break;}NSString *out=[contents stringByAppendingPathComponent:entry[@"relative_path"]];okay=[fm createDirectoryAtPath:out.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]&&[[wrapped subdataWithRange:NSMakeRange(16,wrapped.length-16)] writeToFile:out options:NSDataWritingAtomic error:error];}}
 NSString *out=[apps.stringByDeletingLastPathComponent stringByAppendingPathComponent:sk?@"Silksong-PhoneBuilt-Test-Unsigned.ipa":@"HollowKnight-PhoneBuilt-Test-Unsigned.ipa"];
 // Unique diagnostic destination; refuse replacing any existing export.
 if([fm fileExistsAtPath:out]){okay=NO;if(error)*error=[NSError errorWithDomain:@"PrivateFixture" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Diagnostic IPA already exists; preserve it before rerunning."}];}
 if(okay)okay=HLFinishHollowKnightGameIPA([NSURL fileURLWithPath:fixture isDirectory:YES],[NSURL fileURLWithPath:out],progress,report,error);
 [fm removeItemAtPath:fixture error:nil];return okay;
}
