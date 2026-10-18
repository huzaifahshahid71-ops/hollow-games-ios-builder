#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>
#import <objc/message.h>
#import <stdint.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <limits.h>

extern BOOL HLRunPrivateGameExport(void(^)(NSString *),NSDictionary **,NSError **);
extern BOOL HLCreateGameCompilerIPA(NSString *,NSURL *,NSURL *,void(^)(NSString *),NSDictionary **,NSError **);
extern BOOL HLCreateHollowKnightCompilerIPA(NSURL *,NSURL *,void(^)(NSString *),NSDictionary **,NSError **);
extern BOOL HLFinishHollowKnightGameIPA(NSURL *,NSURL *,void(^)(NSString *),NSDictionary **,NSError **);
extern BOOL HLBuildHollowKnightDataArchive(NSURL *,NSURL *,void(^)(NSUInteger,NSUInteger,unsigned long long),NSDictionary **,NSError **);
extern NSData *HLConvertMacMachO(NSData *,NSDictionary *,NSDictionary *,NSError **);
extern BOOL HLExportCoreIPAWithRuntime(NSString *,NSString *,NSString *,NSError **);
extern BOOL HLExportCoreIPA(NSString *,NSString *,NSError **);
extern BOOL HLExportFixtureIPA(NSString *,NSString *,NSError **);

static NSString *HLDocuments(void) { return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject; }
static NSString *HLHash(NSURL *url, NSError **error) {
 NSInputStream *stream=[NSInputStream inputStreamWithURL:url];[stream open];CC_SHA256_CTX context;CC_SHA256_Init(&context);uint8_t buffer[65536];NSInteger count;
 while((count=[stream read:buffer maxLength:sizeof(buffer)])>0) CC_SHA256_Update(&context,buffer,(CC_LONG)count);
 NSError *failure=stream.streamError;[stream close];if(count<0||failure){if(error)*error=failure?:[NSError errorWithDomain:@"Loader" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Could not read a selected file."}];return nil;}
 unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&context);NSMutableString *s=[NSMutableString new];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[s appendFormat:@"%02x",digest[i]];return s;
}
static id HLJSON(NSURL *url) { NSData *d=[NSData dataWithContentsOfURL:url];return d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil; }
static NSString *HLExportsDirectory(void){NSString *apps=NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;NSString *base=[apps.lastPathComponent isEqual:@"Applications"]?apps.stringByDeletingLastPathComponent:HLDocuments();NSString *folder=[base stringByAppendingPathComponent:@"Hollow Builder Exports"];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];return folder;}
static NSURL *HLNextExport(NSString *name){NSString *folder=HLExportsDirectory(),*path=[folder stringByAppendingPathComponent:name];NSUInteger suffix=2;while([NSFileManager.defaultManager fileExistsAtPath:path])path=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu.%@",name.stringByDeletingPathExtension,(unsigned long)suffix++,name.pathExtension]];return [NSURL fileURLWithPath:path];}
static NSDictionary *HLCompilerAdaptation(void){NSString *game=NSBundle.mainBundle.infoDictionary[@"HLGameProfile"]?:@"hollow-knight";return HLJSON([NSBundle.mainBundle URLForResource:@"compiler-adaptations" withExtension:@"json" subdirectory:@"Profiles"])[game];}
static NSData *HLHexBytes(NSString *text){NSMutableData *data=[NSMutableData new];for(NSUInteger i=0;i+1<text.length;i+=2){unsigned int value=0;[[NSScanner scannerWithString:[text substringWithRange:NSMakeRange(i,2)]] scanHexInt:&value];uint8_t byte=value;[data appendBytes:&byte length:1];}return data;}
static BOOL HLAdaptSilksongCore(NSString *path,NSError **error){
 if(![NSBundle.mainBundle.infoDictionary[@"HLGameProfile"] isEqual:@"silksong"])return YES;
 NSDictionary *guard=HLJSON([NSBundle.mainBundle URLForResource:@"type-bridge-guard" withExtension:@"json" subdirectory:@"Profiles"]);NSString *text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];NSRange start=[text rangeOfString:guard[@"method"]?:@"__missing_guard__"];if(start.location==NSNotFound)return NO;NSUInteger body=start.location+start.length;NSRange end=[text rangeOfString:@"\nLme_" options:0 range:NSMakeRange(body,text.length-body)];if(end.location==NSNotFound)return NO;NSData *bytes=[[text substringWithRange:NSMakeRange(body,end.location-body)] dataUsingEncoding:NSUTF8StringEncoding];unsigned char digest[32];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,digest);if(![[NSData dataWithBytes:digest length:32] isEqual:HLHexBytes(guard[@"generated_body_sha256"])])return NO;
 NSString *bridge=[NSString stringWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"BuilderSupport/SilksongTypeBridge.s"] encoding:NSUTF8StringEncoding error:error];if(!bridge)return NO;
 NSString *replacement=@"\nstp x29, x30, [sp, #-0x30]!\nmov x29, sp\nstp x23, x24, [x29, #0x10]\nstp x25, x26, [x29, #0x20]\nbl _SilksongTypeAssignable\nldp x23, x24, [x29, #0x10]\nldp x25, x26, [x29, #0x20]\nldp x29, x30, [sp], #0x30\nret\n";
 NSMutableString *adapted=[text mutableCopy];[adapted replaceCharactersInRange:NSMakeRange(body,end.location-body) withString:replacement];[adapted appendFormat:@"\n%@\n",bridge];return [adapted writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}
static void HLWriteReport(NSDictionary *report) { NSData *d=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];[d writeToFile:[HLDocuments() stringByAppendingPathComponent:@"Loader-report.json"] atomically:YES]; }
// Ask LiveContainer to sign the project-authored fixture in place. Never read/export keys.
static void HLUsePreloadedSigner(id cls,SEL selector,NSError **error) {
 if(!NSClassFromString(@"ZSigner")&&error)*error=[NSError errorWithDomain:@"HollowLoader" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Preloaded host signer class is missing."}];
}
static void HLSignAndRun(NSString *path, NSMutableDictionary *result, void (^checkpoint)(void)) {
 NSMutableArray *classes=[NSMutableArray new];unsigned int count=0;Class *list=objc_copyClassList(&count);
 for(unsigned int i=0;i<count;i++){NSString *name=NSStringFromClass(list[i]);if([name localizedCaseInsensitiveContainsString:@"LCUtils"]||[name localizedCaseInsensitiveContainsString:@"ZSign"]||[name localizedCaseInsensitiveContainsString:@"LCSharedUtils"])[classes addObject:name];}free(list);result[@"signing_classes"]=classes;
 NSString *host=@(_dyld_get_image_name(0));NSString *frameworks=[[host stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Frameworks"];
 result[@"host_executable"]=host;result[@"host_frameworks"]=[NSFileManager.defaultManager contentsOfDirectoryAtPath:frameworks error:nil]?:@[];
 Class signer=NSClassFromString(@"LCUtils");
 if(!signer&&NSClassFromString(@"LCSharedUtils")) {
  NSString *ui=[frameworks stringByAppendingPathComponent:@"LiveContainerSwiftUI.framework/LiveContainerSwiftUI"];
  if([NSFileManager.defaultManager fileExistsAtPath:ui]){
   result[@"stage"]=@"host-signing-framework-load";checkpoint();
   __block void *handle=NULL;__block NSString *failure=nil;
   dispatch_sync(dispatch_get_main_queue(),^{handle=dlopen(ui.UTF8String,RTLD_LAZY|RTLD_LOCAL);if(!handle){const char *error=dlerror();failure=error?@(error):@"Host signing framework could not load.";}});
   result[@"host_signing_framework_loaded"]=@(handle!=NULL);if(failure)result[@"host_signing_framework_error"]=failure;
   signer=NSClassFromString(@"LCUtils");
  }
 }
 SEL selector=NSSelectorFromString(@"signFilesWithZSignWithURLs:completionHandler:");
 if(signer){
  NSString *crypto=[frameworks stringByAppendingPathComponent:@"OpenSSL.framework/OpenSSL"];NSString *zsign=[frameworks stringByAppendingPathComponent:@"ZSign.dylib"];
  __block void *zsignHandle=NULL;__block NSString *failure=nil;
  dispatch_sync(dispatch_get_main_queue(),^{
   if([NSFileManager.defaultManager fileExistsAtPath:crypto])dlopen(crypto.UTF8String,RTLD_NOW|RTLD_GLOBAL);
   zsignHandle=dlopen(zsign.UTF8String,RTLD_NOW|RTLD_GLOBAL);if(!zsignHandle){const char *e=dlerror();failure=e?@(e):@"Host signer could not load.";}
  });result[@"host_zsign_loaded"]=@(zsignHandle!=NULL);if(failure)result[@"host_zsign_error"]=failure;
 }
 result[@"host_signer_available"]=@([signer respondsToSelector:selector]);
 if(![signer respondsToSelector:selector]){result[@"signing_error"]=@"Open this private diagnostic inside LiveContainer to test host signing.";checkpoint();return;}
 result[@"stage"]=@"host-signing";checkpoint();
 dispatch_semaphore_t done=dispatch_semaphore_create(0);__block BOOL signedOK=NO;__block NSString *signError=nil;
 dispatch_async(dispatch_get_main_queue(),^{
  Method loader=class_getClassMethod(signer,NSSelectorFromString(@"loadStoreFrameworksWithError2:"));IMP oldLoader=NULL;
  // The host helper uses @executable_path, which LC redirects to the guest.
  // Scope this adapter to our one API request, after loading the signed host image by absolute path.
  if(loader&&NSClassFromString(@"ZSigner"))oldLoader=method_setImplementation(loader,(IMP)HLUsePreloadedSigner);
  @try {
   ((id(*)(id,SEL,NSArray *,void(^)(BOOL,NSError *)))objc_msgSend)(signer,selector,@[[NSURL fileURLWithPath:path]],^(BOOL success,NSError *error){signedOK=success;signError=error.localizedDescription;dispatch_semaphore_signal(done);});
  } @catch(NSException *exception){signError=exception.reason;dispatch_semaphore_signal(done);} @finally {if(oldLoader)method_setImplementation(loader,oldLoader);}
 });
 if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,45*NSEC_PER_SEC))){result[@"signing_error"]=@"Host signing timed out; no generated code was loaded.";checkpoint();return;}
 result[@"host_signed"]=@(signedOK);
 if(!signedOK){result[@"signing_error"]=signError?:@"Host signer declined the test library.";checkpoint();return;}
 // The host signer grows __LINKEDIT in 4 KiB units. ARM64 iOS requires 16 KiB VM alignment.
 // Correct only our generated image header, then request a fresh signature over the corrected bytes.
 NSMutableData *image=[NSMutableData dataWithContentsOfFile:path];BOOL repaired=NO;
 if(image.length>=sizeof(struct mach_header_64)){
  struct mach_header_64 *header=image.mutableBytes;NSUInteger offset=sizeof(*header);
  if(header->magic==MH_MAGIC_64)for(uint32_t i=0;i<header->ncmds;i++){
   if(offset+sizeof(struct load_command)>image.length)break;struct load_command *command=(void *)((uint8_t *)image.mutableBytes+offset);
   if(command->cmdsize<sizeof(*command)||offset+command->cmdsize>image.length)break;
   if(command->cmd==LC_SEGMENT_64&&command->cmdsize>=sizeof(struct segment_command_64)){
    struct segment_command_64 *segment=(void *)command;
    if(!strncmp(segment->segname,"__LINKEDIT",16)&&(segment->vmsize&16383)){segment->vmsize=(segment->vmsize+16383)&~(uint64_t)16383;repaired=YES;}
   }offset+=command->cmdsize;
  }
 }
 if(repaired){
  if([result[@"segment_alignment_repaired"] boolValue]){result[@"signing_error"]=@"Host signer changed segment alignment again.";checkpoint();return;}
  result[@"segment_alignment_repaired"]=@YES;
  if(![image writeToFile:path atomically:YES]){result[@"signing_error"]=@"Could not normalize generated segment alignment.";checkpoint();return;}
  HLSignAndRun(path,result,checkpoint);return;
 }
 result[@"stage"]=@"generated-library-load";checkpoint();void *library=dlopen(path.UTF8String,RTLD_NOW|RTLD_LOCAL);
 if(!library){const char *error=dlerror();result[@"load_error"]=error?@(error):@"Generated library could not be loaded.";checkpoint();return;}
 result[@"generated_library_loaded"]=@YES;
 int32_t (*add)(int32_t,int32_t)=dlsym(library,"HLFixtureAdd");int64_t (*sum)(int64_t,int64_t)=dlsym(library,"HLFixtureSum");int32_t (*positive)(int32_t)=dlsym(library,"HLFixturePositive");
 if(!add||!sum||!positive){result[@"execution_error"]=@"Fixture test exports are missing.";checkpoint();return;}
 result[@"stage"]=@"generated-code-tests";checkpoint();NSUInteger passed=0,total=0;
 int32_t pairs[][2]={{1,2},{-100,23},{0,0},{INT32_MAX,1}};
 for(NSUInteger i=0;i<4;i++){int32_t expected=(int32_t)((uint32_t)pairs[i][0]+(uint32_t)pairs[i][1]);passed+=(add(pairs[i][0],pairs[i][1])==expected);total++;}
 int64_t longPairs[][2]={{1LL<<40,1LL<<40},{-(1LL<<40),123},{0,0},{INT64_MAX,1}};
 for(NSUInteger i=0;i<4;i++){int64_t expected=(int64_t)((uint64_t)longPairs[i][0]+(uint64_t)longPairs[i][1]);passed+=(sum(longPairs[i][0],longPairs[i][1])==expected);total++;}
 int32_t values[]={INT32_MIN,-1,0,1,INT32_MAX};for(NSUInteger i=0;i<5;i++){passed+=(positive(values[i])==(values[i]>0));total++;}
 result[@"generated_library_executed"]=@YES;result[@"arithmetic_cases_passed"]=@(passed);result[@"arithmetic_cases_total"]=@(total);result[@"all_arithmetic_cases_passed"]=@(passed==total);result[@"stage"]=@"generated-code-tested";checkpoint();
}
static NSURL *HLFindGame(NSURL *root) {
 NSFileManager *fm=NSFileManager.defaultManager;
 if([fm fileExistsAtPath:[[root URLByAppendingPathComponent:@"Contents/Info.plist"] path]])return root;
 NSMutableArray<NSURL *> *queue=[NSMutableArray arrayWithObject:root];NSUInteger visited=0;
 while(queue.count&&visited++<256){NSURL *dir=queue.firstObject;[queue removeObjectAtIndex:0];NSArray *children=[fm contentsOfDirectoryAtURL:dir includingPropertiesForKeys:@[NSURLIsDirectoryKey,NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
  for(NSURL *child in children){NSNumber *isDir,*symlink;[child getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];[child getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil];if(!isDir.boolValue||symlink.boolValue)continue;
   if([fm fileExistsAtPath:[[child URLByAppendingPathComponent:@"Contents/Info.plist"] path]])return child;
   if(child.pathComponents.count-root.pathComponents.count<4)[queue addObject:child];
  }
 }
 return nil;
}

@interface HLController : UIViewController <UIDocumentPickerDelegate>
@property UILabel *status;
@property UITextView *details;
@property UIButton *choose,*probe,*share;
@property BOOL busy,probeRan;
@property NSMutableDictionary *report;
@property NSString *selectedGame;
@end
@implementation HLController
- (void)viewDidLoad {
 [super viewDidLoad];fprintf(stderr,"HL loader view loaded\n");self.view.backgroundColor=[UIColor colorWithRed:.05 green:.08 blue:.13 alpha:1];self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.selectedGame=self.selectedGame?:NSBundle.mainBundle.infoDictionary[@"HLGameProfile"]?:@"hollow-knight";self.title=[self.selectedGame isEqual:@"silksong"]?@"Silksong Builder":@"Hollow Knight Builder";
 self.report=[@{@"prototype":@1,@"original_folder_launch_implemented":@NO,@"jit_requested":@NO} mutableCopy];
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=18;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:stack];
 UILabel *title=[UILabel new];title.text=@"Your files. On your phone.";title.font=[UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];title.numberOfLines=0;[stack addArrangedSubview:title];
 UILabel *intro=[UILabel new];intro.numberOfLines=0;intro.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];intro.text=@"Select the complete Mac game folder for Hollow Knight 1.5.12620 or Silksong 1.0.30000. This prototype checks the files and tests the on-device compiler. Playing directly from original files is not implemented yet.";[stack addArrangedSubview:intro];
 self.choose=[self button:@"Choose original game folder" action:@selector(chooseFolder)];[stack addArrangedSubview:self.choose];
 self.probe=[self button:@"Test on-device compiler" action:@selector(runProbe)];BOOL private=[NSBundle.mainBundle.infoDictionary[@"HLPrivateCompilerProbe"] boolValue];self.probe.enabled=private;[stack addArrangedSubview:self.probe];
 self.status=[UILabel new];self.status.numberOfLines=0;self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];self.status.text=private?@"Private diagnostic: runtime libraries came from your own game. Do not redistribute this IPA.":@"No game code included. Compiler test requires a private diagnostic build.";[stack addArrangedSubview:self.status];
 self.details=[UITextView new];self.details.editable=NO;self.details.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];self.details.backgroundColor=UIColor.secondarySystemBackgroundColor;[stack addArrangedSubview:self.details];[self.details.heightAnchor constraintGreaterThanOrEqualToConstant:130].active=YES;
 self.share=[self button:@"Share IPA / report" action:@selector(shareReport)];[stack addArrangedSubview:self.share];
 UILayoutGuide *safe=self.view.safeAreaLayoutGuide;[NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],[stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:20],[stack.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-20]]];
 if([NSBundle.mainBundle.infoDictionary[@"HLCompilerStage"] boolValue]){intro.text=@"Keep this app open while your game code is built. When ready, choose the same original game folder to compress its files and export your game IPA.";self.probe.hidden=YES;NSDictionary *saved=HLJSON([NSURL fileURLWithPath:[HLDocuments() stringByAppendingPathComponent:@"CompilerBuild.json"]]);if([saved[@"compiler_code_ready"] boolValue]){self.report=[saved mutableCopy];self.probeRan=YES;self.status.text=@"Native game code is ready. Choose the original game folder to export the game IPA.";}}
 else if([NSBundle.mainBundle.infoDictionary[@"HLBuilderSupportAvailable"] boolValue]){intro.text=@"1. Choose your original Mac game folder.\n2. Import the compiler IPA in LiveContainer and open it with JIT disabled.\n3. Choose the same folder there to export your playable game IPA.";self.probe.hidden=YES;self.status.text=[self.selectedGame isEqual:@"silksong"]?@"Ready for Silksong 1.0.30000.":@"Ready for Hollow Knight 1.5.12620.";self.details.hidden=YES;}
 [self refresh];
 if([NSBundle.mainBundle.infoDictionary[@"HLRunDiagnosticGameBuild"] boolValue]&&[self.report[@"compiler_code_ready"] boolValue]){[self setBusy:YES text:@"Exporting separate phone-built game test…"];dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;NSDictionary *result=nil;BOOL okay=HLRunPrivateGameExport(^(NSString *text){dispatch_async(dispatch_get_main_queue(),^{self.status.text=text;});},&result,&error);self.report[@"private_game_export"]=result?:@{};if(error)self.report[@"private_game_export_error"]=error.localizedDescription;HLWriteReport(self.report);dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:okay?@"Phone-built game IPA ready in LiveContainer Files. Import HollowKnight-PhoneBuilt-Test-Unsigned.ipa as a separate app.":error.localizedDescription?:@"Export failed"];[self refresh];});});}
 if([NSBundle.mainBundle.infoDictionary[@"HLBuildCompilerStageProbe"] boolValue])dispatch_async(dispatch_get_main_queue(),^{[self runProbe];});
 if(([NSProcessInfo.processInfo.arguments containsObject:@"--compiler-probe"]||[NSBundle.mainBundle.infoDictionary[@"HLRunProbeOnLaunch"] boolValue])&&private&&!self.probeRan)dispatch_async(dispatch_get_main_queue(),^{[self runProbe];});
}
- (UIButton *)button:(NSString *)title action:(SEL)action { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];UIButtonConfiguration *c;if(@available(iOS 26.0,*))c=[UIButtonConfiguration glassButtonConfiguration];else c=[UIButtonConfiguration filledButtonConfiguration];c.title=title;c.cornerStyle=UIButtonConfigurationCornerStyleMedium;b.configuration=c;[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b; }
- (void)setBusy:(BOOL)busy text:(NSString *)text {self.busy=busy;UIApplication.sharedApplication.idleTimerDisabled=busy;self.choose.enabled=!busy;self.share.enabled=!busy;self.probe.enabled=!busy&&!self.probeRan&&[NSBundle.mainBundle.infoDictionary[@"HLPrivateCompilerProbe"] boolValue];self.status.text=text;}
- (void)refresh {
 NSDictionary *storage=[NSFileManager.defaultManager attributesOfFileSystemForPath:HLDocuments() error:nil];
 if(storage)self.report[@"storage"]=@{@"free_bytes":storage[NSFileSystemFreeSize]?:@0,@"total_bytes":storage[NSFileSystemSize]?:@0};
 NSData *data=[NSJSONSerialization dataWithJSONObject:self.report options:NSJSONWritingPrettyPrinted error:nil];self.details.text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];HLWriteReport(self.report); }
- (void)chooseFolder {
 UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
 NSURL *selected=urls.firstObject;if(!selected)return;[self setBusy:YES text:@"Checking selected files…"];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{BOOL access=[selected startAccessingSecurityScopedResource];NSURL *app=HLFindGame(selected);NSString *message;NSMutableDictionary *result=[NSMutableDictionary new];
  if(!app){message=@"Choose a folder containing a complete Mac game .app. Assets alone are not enough.";result[@"valid"]=@NO;}
  else {NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[app URLByAppendingPathComponent:@"Contents/Info.plist"]];NSDictionary *profile=nil;
   for(NSString *key in @[@"hollow-knight",@"silksong"]){NSDictionary *candidate=HLJSON([NSBundle.mainBundle URLForResource:key withExtension:@"json" subdirectory:@"Profiles"]);if([info[@"CFBundleExecutable"] isEqual:candidate[@"executable"]]){profile=candidate;break;}}
   if(!profile){message=@"This game is not supported by the prototype.";result[@"valid"]=@NO;}
   else {NSMutableArray *mismatch=[NSMutableArray new];NSUInteger matched=0;NSMutableDictionary *expected=[profile[@"native_sha256"] mutableCopy];for(NSString *name in profile[@"managed_sha256"]) expected[[@"Resources/Data/Managed/" stringByAppendingString:name]]=profile[@"managed_sha256"][name];
    NSString *allowed=[[app URLByResolvingSymlinksInPath].path stringByAppendingString:@"/"];
    for(NSString *name in expected){NSURL *file=[app URLByAppendingPathComponent:[@"Contents/" stringByAppendingString:name]];NSError *error=nil;
     if(![[file URLByResolvingSymlinksInPath].path hasPrefix:allowed]){[mismatch addObject:name];continue;}
     NSString *digest=HLHash(file,&error);if(!error&&[digest isEqual:expected[name]])matched++;else [mismatch addObject:name];
    }
    NSURL *managedFolder=[app URLByAppendingPathComponent:@"Contents/Resources/Data/Managed"];
    NSArray *actual=[NSFileManager.defaultManager contentsOfDirectoryAtPath:managedFolder.path error:nil];
    for(NSString *entry in actual)if([entry.pathExtension.lowercaseString isEqual:@"dll"]&&!profile[@"managed_sha256"][entry])[mismatch addObject:[@"Unexpected managed assembly: " stringByAppendingString:entry]];
    result[@"game"]=profile[@"id"];result[@"version"]=profile[@"version"];result[@"files_matched"]=@(matched);result[@"mismatches"]=mismatch;result[@"valid"]=@(mismatch.count==0);
    message=mismatch.count?@"Some required files do not match the supported Mac release.":@"Original game files verified. On-device native conversion is still required before Play can be enabled.";
   }
  }
  if([result[@"valid"] boolValue]&&![result[@"game"] isEqual:self.selectedGame]){result[@"valid"]=@NO;message=@"This folder belongs to the other game. Choose the matching game on the home screen.";}
  if([result[@"valid"] boolValue]&&([NSBundle.mainBundle.infoDictionary[@"HLBuilderSupportAvailable"] boolValue]||[NSBundle.mainBundle.infoDictionary[@"HLCompilerStage"] boolValue])){
   BOOL stage=[NSBundle.mainBundle.infoDictionary[@"HLCompilerStage"] boolValue];NSString *stem=[self.selectedGame isEqual:@"silksong"]?@"Silksong":@"HollowKnight";NSURL *output=HLNextExport([NSString stringWithFormat:@"%@-%@-Unsigned.ipa",stem,stage?@"Game":@"CompilerStage"]);NSError *error=nil;NSDictionary *build=nil;void(^progress)(NSString *)=^(NSString *text){dispatch_async(dispatch_get_main_queue(),^{self.status.text=text;});};BOOL okay=stage?HLFinishHollowKnightGameIPA(app,output,progress,&build,&error):HLCreateGameCompilerIPA(self.selectedGame,app,output,progress,&build,&error);result[@"build"]=build?:@{};result[@"ipa_exported"]=@(okay);if(okay){self.report[@"last_export_path"]=output.path;message=[NSString stringWithFormat:@"Export complete: %@\nSaved in Hollow Builder Exports in Files.",output.lastPathComponent];dispatch_async(dispatch_get_main_queue(),^{UIAlertController *notice=[UIAlertController alertControllerWithTitle:@"Your IPA is ready" message:stage?@"Open Files → Hollow Builder Exports and import the game IPA into LiveContainer. Keep JIT disabled, then launch and play.":@"Open Files → Hollow Builder Exports and import the compiler IPA into LiveContainer. Launch its builder with JIT disabled, keep it open, then select the same game folder to finish." preferredStyle:UIAlertControllerStyleAlert];[notice addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:nil]];[notice addAction:[UIAlertAction actionWithTitle:@"Share IPA" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[output] applicationActivities:nil];share.popoverPresentationController.sourceView=self.share;[self presentViewController:share animated:YES completion:nil];}]];[self presentViewController:notice animated:YES completion:nil];});}else message=error.localizedDescription?:@"Build did not complete; originals were preserved.";
  }
  if(access)[selected stopAccessingSecurityScopedResource];dispatch_async(dispatch_get_main_queue(),^{self.report[@"selected_folder_validation"]=result;[self setBusy:NO text:message];[self refresh];});
 });
}
- (void)runProbe {
 if(self.busy||self.probeRan)return;
 if([NSBundle.mainBundle.infoDictionary[@"HLBuildCompilerStageProbe"] boolValue]){self.probeRan=YES;[self setBusy:YES text:@"Building compiler-stage IPA from original code inputs…"];dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[HLDocuments() stringByAppendingPathComponent:[@"CompilerSourceFixture-" stringByAppendingString:NSUUID.UUID.UUIDString]],*managed=[root stringByAppendingPathComponent:@"Contents/Resources/Data/Managed"];[fm createDirectoryAtPath:managed withIntermediateDirectories:YES attributes:nil error:nil];[fm createDirectoryAtPath:[root stringByAppendingPathComponent:@"Contents/Frameworks"] withIntermediateDirectories:YES attributes:nil error:nil];NSDictionary *profile=HLJSON([NSBundle.mainBundle URLForResource:@"hollow-knight" withExtension:@"json" subdirectory:@"Profiles"]);if([NSBundle.mainBundle.infoDictionary[@"HLGameProfile"] isEqual:@"silksong"])profile=HLJSON([NSBundle.mainBundle URLForResource:@"silksong" withExtension:@"json" subdirectory:@"Profiles"]);NSError *error=nil;BOOL staged=YES;
  for(NSString *name in profile[@"managed_sha256"]){if(![fm copyItemAtPath:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[@"Compiler/OriginalManaged/" stringByAppendingString:name]] toPath:[managed stringByAppendingPathComponent:name] error:&error]){staged=NO;break;}}
  if(staged)staged=[fm copyItemAtPath:[HLDocuments() stringByAppendingPathComponent:@"OriginalInputMono.bin"] toPath:[root stringByAppendingPathComponent:@"Contents/Frameworks/libmonobdwgc-2.0.dylib"] error:&error];
  NSDictionary *result=nil;NSURL *output=[NSURL fileURLWithPath:[HLDocuments() stringByAppendingPathComponent:[NSBundle.mainBundle.infoDictionary[@"HLGameProfile"] isEqual:@"silksong"]?@"Silksong-CompilerStage-Unsigned.ipa":@"HollowKnight-CompilerStage-Unsigned.ipa"]];BOOL okay=staged&&HLCreateHollowKnightCompilerIPA([NSURL fileURLWithPath:root isDirectory:YES],output,^(NSString *text){dispatch_async(dispatch_get_main_queue(),^{self.status.text=text;});},&result,&error);self.report[@"compiler_stage_export"]=result?:@{@"exported":@NO,@"error":error.localizedDescription?:@"Fixture staging failed"};self.report[@"compiler_source_fixture_has_assets"]=@NO;HLWriteReport(self.report);[fm removeItemAtPath:root error:nil];dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:okay?@"Compiler-stage IPA exported on phone from original code files. Import Hollow Knight Builder in LiveContainer with JIT disabled.":error.localizedDescription?:@"Compiler-stage export failed"];[self refresh];});
 });return;}
 if([NSBundle.mainBundle.infoDictionary[@"HLAssetCompressionProbe"] boolValue]){self.probeRan=YES;[self setBusy:YES text:@"Testing lossless Unity compression on original sample assets…"];dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSString *base=[HLDocuments() stringByAppendingPathComponent:@"CompressionProbe"],*data=[base stringByAppendingPathComponent:@"Data"],*output=[base stringByAppendingPathComponent:@"data.unity3d"];NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtPath:[data stringByAppendingPathComponent:@"Resources"] withIntermediateDirectories:YES attributes:nil error:nil];NSArray *entries=HLJSON([NSBundle.mainBundle URLForResource:@"manifest" withExtension:@"json" subdirectory:@"ExportTemplate/CompressionSamples"]);NSError *error=nil;BOOL valid=entries.count>0;
  for(NSDictionary *entry in entries){NSURL *file=[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:[@"ExportTemplate/CompressionSamples/" stringByAppendingString:entry[@"resource"]]];NSData *wrapped=[NSData dataWithContentsOfURL:file];if(wrapped.length<16||memcmp(wrapped.bytes,"HLRAWINPUTv1\0\0\0\0",16)){valid=NO;break;}NSData *raw=[wrapped subdataWithRange:NSMakeRange(16,wrapped.length-16)];NSString *path=[data stringByAppendingPathComponent:entry[@"path"]];if(![raw writeToFile:path options:NSDataWritingAtomic error:&error]||![[HLHash([NSURL fileURLWithPath:path],&error) lowercaseString] isEqual:entry[@"sha256"]]){valid=NO;break;}}
  NSDictionary *details=nil;BOOL okay=valid&&HLBuildHollowKnightDataArchive([NSURL fileURLWithPath:data isDirectory:YES],[NSURL fileURLWithPath:output],^(NSUInteger finished,NSUInteger total,unsigned long long bytes){dispatch_async(dispatch_get_main_queue(),^{self.status.text=[NSString stringWithFormat:@"Compressing and verifying %lu/%lu files…",(unsigned long)finished,(unsigned long)total];});},&details,&error);NSMutableDictionary *result=[details mutableCopy]?:[NSMutableDictionary new];result[@"passed"]=@(okay);if(error)result[@"error"]=error.localizedDescription;self.report[@"asset_compression"]=result;HLWriteReport(self.report);dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:okay?@"Phone lossless compression passed: every decoded asset matches the original SHA-256.":error.localizedDescription?:@"Compression sample staging failed"];[self refresh];});
 });return;}
 if([NSBundle.mainBundle.infoDictionary[@"HLNativeConversionProbe"] boolValue]){self.probeRan=YES;[self setBusy:YES text:@"Converting original Mac runtime on this phone…"];dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSError *error=nil;NSURL *source=[NSBundle.mainBundle URLForResource:@"OriginalMacMono" withExtension:@"data" subdirectory:@"ExportTemplate"];NSDictionary *profile=HLJSON([NSBundle.mainBundle URLForResource:@"hollow-knight" withExtension:@"json" subdirectory:@"Profiles"]);NSData *wrapped=[NSData dataWithContentsOfURL:source];NSData *raw=nil;if(wrapped.length>16&&!memcmp(wrapped.bytes,"HLRAWINPUTv1\0\0\0\0",16))raw=[wrapped subdataWithRange:NSMakeRange(16,wrapped.length-16)];NSString *inputPath=[HLDocuments() stringByAppendingPathComponent:@"OriginalInputMono.bin"];[raw writeToFile:inputPath options:NSDataWritingAtomic error:&error];NSString *hash=raw?HLHash([NSURL fileURLWithPath:inputPath],&error):nil;NSMutableDictionary *result=[NSMutableDictionary new];
  if(![hash isEqual:profile[@"native_sha256"][@"Frameworks/libmonobdwgc-2.0.dylib"]])result[@"error"]=@"Original Mac runtime fingerprint mismatch";
  else {
   NSDictionary *map=HLJSON([NSBundle.mainBundle URLForResource:@"hk-mono-imports" withExtension:@"json" subdirectory:@"ExportTemplate"]);NSData *converted=HLConvertMacMachO(raw,map,@{@"_mmap":@"_smmp"},&error);NSString *runtime=[HLDocuments() stringByAppendingPathComponent:@"PhoneConvertedMono.dylib"],*ipa=[HLDocuments() stringByAppendingPathComponent:@"HollowLoader-OriginalRuntime-CoreTest-Unsigned.ipa"];
   if(converted&&[converted writeToFile:runtime options:NSDataWritingAtomic error:&error]){result[@"converted_runtime_bytes"]=@(converted.length);result[@"converted_runtime_sha256"]=HLHash([NSURL fileURLWithPath:runtime],nil);BOOL okay=HLExportCoreIPAWithRuntime([HLDocuments() stringByAppendingPathComponent:@"CompilerProbe/mscorlib.dll.dylib"],runtime,ipa,&error);result[@"exported"]=@(okay);result[@"ipa_bytes"]=@([[NSFileManager.defaultManager attributesOfItemAtPath:ipa error:nil] fileSize]);}
   if(error)result[@"error"]=error.localizedDescription;
  }
  NSArray *engineProfiles=HLJSON([NSBundle.mainBundle URLForResource:@"hk-engine-imports" withExtension:@"json" subdirectory:@"ExportTemplate"]);NSMutableArray *engines=[NSMutableArray new];result[@"engine_conversions"]=engines;
  for(NSDictionary *entry in engineProfiles){NSMutableDictionary *row=[@{@"input":entry[@"relative_path"]} mutableCopy];[engines addObject:row];NSError *failure=nil;NSData *blob=[NSData dataWithContentsOfURL:[NSBundle.mainBundle URLForResource:entry[@"resource"] withExtension:@"data" subdirectory:@"ExportTemplate"]];
   if(blob.length<=16||memcmp(blob.bytes,"HLRAWINPUTv1\0\0\0\0",16)){row[@"error"]=@"Invalid raw native input";continue;}NSData *input=[blob subdataWithRange:NSMakeRange(16,blob.length-16)];NSString *inputFile=[HLDocuments() stringByAppendingPathComponent:[entry[@"resource"] stringByAppendingString:@".bin"]];[input writeToFile:inputFile options:NSDataWritingAtomic error:&failure];NSString *hash=HLHash([NSURL fileURLWithPath:inputFile],&failure);
   if(failure||![hash isEqual:(entry[@"original_sha256"]?:profile[@"native_sha256"][entry[@"relative_path"]])]){row[@"error"]=@"Native input fingerprint mismatch";continue;}
   NSData *native=HLConvertMacMachO(input,entry[@"dependency_replacements"],entry[@"aliases"],&failure);NSString *file=[HLDocuments() stringByAppendingPathComponent:[entry[@"resource"] stringByAppendingString:@"-iOS.dylib"]];if(native&&[native writeToFile:file options:NSDataWritingAtomic error:&failure]){row[@"converted_bytes"]=@(native.length);row[@"sha256"]=HLHash([NSURL fileURLWithPath:file],nil);row[@"converted"]=@YES;}else row[@"error"]=failure.localizedDescription?:@"Conversion failed";
  }
  self.report[@"native_conversion"]=result;HLWriteReport(self.report);dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:[result[@"exported"] boolValue]?@"Original runtime converted and core test IPA exported on phone. Import separately into LiveContainer.":result[@"error"]?:@"Native conversion failed"];[self refresh];});
 });return;}
 if([NSBundle.mainBundle.infoDictionary[@"HLExportCoreProbe"] boolValue]){self.probeRan=YES;[self setBusy:YES text:@"Packaging phone-generated core test…"];dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;NSString *ipa=[HLDocuments() stringByAppendingPathComponent:@"HollowLoader-PhoneBuilt-CoreTest-Unsigned.ipa"];BOOL okay=HLExportCoreIPA([HLDocuments() stringByAppendingPathComponent:@"CompilerProbe/mscorlib.dll.dylib"],ipa,&error);self.report[@"core_export"]=@{@"exported":@(okay),@"error":error.localizedDescription?:@"",@"ipa_bytes":@([[NSFileManager.defaultManager attributesOfItemAtPath:ipa error:nil] fileSize])};HLWriteReport(self.report);dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:okay?@"Core validation IPA exported. Import separately into LiveContainer with JIT disabled.":error.localizedDescription];[self refresh];});});return;}
 self.probeRan=YES;[self setBusy:YES text:@"Testing Mono compiler with JIT disabled…"];
 NSURL *root=NSBundle.mainBundle.bundleURL;NSString *managed=[[root URLByAppendingPathComponent:([NSBundle.mainBundle.infoDictionary[@"HLOriginalCoreBootstrap"] boolValue]?@"Compiler/OriginalManaged":@"Compiler/Managed")] path];NSString *runtime=[[root URLByAppendingPathComponent:@"Frameworks/libmonobdwgc-2.0.dylib"] path];NSString *work=[HLDocuments() stringByAppendingPathComponent:@"CompilerProbe"];[NSFileManager.defaultManager createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:nil];BOOL compileCore=[NSBundle.mainBundle.infoDictionary[@"HLCompileOriginalCore"] boolValue];NSString *fixture=[work stringByAppendingPathComponent:compileCore?@"mscorlib.dll":@"CompilerFixture.dll"];[NSFileManager.defaultManager removeItemAtPath:fixture error:nil];[NSFileManager.defaultManager copyItemAtPath:(compileCore?[managed stringByAppendingPathComponent:@"mscorlib.dll"]:[[root URLByAppendingPathComponent:@"Compiler/CompilerFixture.dll"] path]) toPath:fixture error:nil];
 NSString *filtered=[work stringByAppendingPathComponent:@"CompilerInputs"];NSString *search=managed;
 if([NSBundle.mainBundle.infoDictionary[@"HLCompileGameAssemblies"] count]){
  NSString *original=[managed stringByAppendingPathComponent:@"UnityEngine.CoreModule.dll"];NSError *error=nil;NSString *digest=HLHash([NSURL fileURLWithPath:original],&error);
  NSDictionary *adaptation=HLCompilerAdaptation();NSUInteger flagOffset=[adaptation[@"unity_core_flag_offset"] unsignedIntegerValue];if(error||![digest isEqual:adaptation[@"unity_core_sha256"]]){[self setBusy:NO text:@"Compiler-only Unity input fingerprint mismatch."];return;}
  NSMutableData *data=[NSMutableData dataWithContentsOfFile:original];if(data.length<=flagOffset||((uint8_t *)data.bytes)[flagOffset]!=0){[self setBusy:NO text:@"Compiler-only Unity metadata guard failed."];return;}
  ((uint8_t *)data.mutableBytes)[flagOffset]=4;[NSFileManager.defaultManager createDirectoryAtPath:filtered withIntermediateDirectories:YES attributes:nil error:nil];
  if(![data writeToFile:[filtered stringByAppendingPathComponent:@"UnityEngine.CoreModule.dll"] atomically:YES]){[self setBusy:NO text:@"Could not stage compiler-only Unity input."];return;}
  search=[NSString stringWithFormat:@"%@:%@",filtered,managed];
 }
 self.report[@"compiler_probe"]=@{@"stage":@"starting",@"aot_mode":@5,@"jit_enabled":@NO};[self refresh];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSString *log=[HLDocuments() stringByAppendingPathComponent:@"CompilerProbe.log"];int fd=open(log.fileSystemRepresentation,O_CREAT|O_TRUNC|O_WRONLY,0600);if(fd>=0){dup2(fd,STDOUT_FILENO);dup2(fd,STDERR_FILENO);close(fd);}setvbuf(stdout,NULL,_IONBF,0);setvbuf(stderr,NULL,_IONBF,0);
  setenv("MONO_PATH",search.UTF8String,1);setenv("MONO_CFG_DIR",work.UTF8String,1);setenv("MONO_LOG_LEVEL","debug",1);setenv("MONO_LOG_MASK","aot",1);setenv("TMPDIR",work.UTF8String,1);
  NSMutableDictionary *result=[@{@"stage":@"runtime-load",@"aot_mode":@5,@"jit_enabled":@NO} mutableCopy];self.report[@"compiler_probe"]=result;HLWriteReport(self.report);
  void *h=dlopen(runtime.UTF8String,RTLD_NOW|RTLD_GLOBAL);
  if(!h){const char *e=dlerror();result[@"error"]=e?@(e):@"Runtime load failed";}
  else {void(*mode)(int)=dlsym(h,"mono_jit_set_aot_mode");void(*dirs)(const char*,const char*)=dlsym(h,"mono_set_dirs");void(*assemblies)(const char*)=dlsym(h,"mono_set_assemblies_path");int(*mainfn)(int,char**)=dlsym(h,"mono_main");
   if(!mode||!mainfn){result[@"error"]=@"Required Mono entry points are missing";}
   else {BOOL originalCore=[NSBundle.mainBundle.infoDictionary[@"HLOriginalCoreBootstrap"] boolValue];mode(originalCore?0:5);
    result[@"original_core_bootstrap"]=@(originalCore);result[@"aot_mode"]=@(originalCore?0:5);result[@"compiling_original_core"]=@(compileCore);result[@"prepared_core_helper_present"]=@([NSFileManager.defaultManager fileExistsAtPath:[managed stringByAppendingPathComponent:@"mscorlib.dll.dylib"]]);
    if(originalCore){Dl_info image={0};dladdr((void *)mainfn,&image);int *flag=(int *)((unsigned char *)image.dli_fbase+[HLCompilerAdaptation()[@"flag_offset"] unsignedIntegerValue]);int(*isCompiling)(void)=dlsym(h,"mono_jit_aot_compiling");if(!isCompiling||isCompiling()!=0){result[@"error"]=@"Compiler-state guard failed before bootstrap";[self completeProbe:result];return;}*flag=1;if(isCompiling()!=1){result[@"error"]=@"Could not enable no-execution compiler bootstrap";[self completeProbe:result];return;}}
    if(dirs)dirs(managed.UTF8String,work.UTF8String);if(assemblies)assemblies(search.UTF8String);
    void *(*initialize)(const char *,const char *)=dlsym(h,"mono_jit_init_version_for_test_only");
    result[@"stage"]=@"bootstrap-init";HLWriteReport(self.report);
    if(!initialize){result[@"error"]=@"Runtime initialization entry missing";[self completeProbe:result];return;}
    unsigned int (*defaultOpts)(const char *)=dlsym(h,"mono_parse_default_optimizations");
    unsigned int opts=defaultOpts?defaultOpts(NULL):0;
    void (*setDefaults)(int,unsigned int)=dlsym(h,"mono_set_defaults");if(setDefaults)setDefaults(0,opts);
    void *domain=initialize("LoaderCompilerBootstrap","v4.0.30319");
    result[@"bootstrap_initialized"]=@(domain!=NULL);result[@"stage"]=@"compiler-call";HLWriteReport(self.report);
    Dl_info monoImage={0};dladdr((void *)mainfn,&monoImage);
    unsigned char *entry=(unsigned char *)monoImage.dli_fbase+[HLCompilerAdaptation()[@"entry_offset"] unsignedIntegerValue];
    NSData *expected=HLHexBytes(HLCompilerAdaptation()[@"entry_guard"]);
    if(expected.length!=8||memcmp(entry,expected.bytes,expected.length)){result[@"error"]=@"Private compiler entry fingerprint mismatch";[self completeProbe:result];return;}
    void *(*openAssembly)(void *,const char *)=dlsym(h,"mono_domain_assembly_open");
    void *assemblyInput=openAssembly?openAssembly(domain,fixture.UTF8String):NULL;
    if(!assemblyInput){result[@"error"]=@"Fixture could not be loaded";[self completeProbe:result];return;}
    int (*compileAssembly)(void *,unsigned int,const char *,void **)= (void *)entry;void *compilerState=NULL;
    // Private inspected-runtime flag: compiler mode is enabled only after AOT bootstrap.
    int *compiling=(int *)((unsigned char *)monoImage.dli_fbase+[HLCompilerAdaptation()[@"flag_offset"] unsignedIntegerValue]);
    int (*isCompiling)(void)=dlsym(h,"mono_jit_aot_compiling");
    if(!isCompiling||isCompiling()!=(originalCore?1:0)){result[@"error"]=@"Unexpected compiler state";[self completeProbe:result];return;}
    *compiling=1;if(isCompiling()!=1){result[@"error"]=@"Compiler flag guard failed";[self completeProbe:result];return;}
    const char *flags=compileCore?"full,interp,nopagetrampolines,asmonly,ntrampolines=65536,nrgctx-trampolines=16384,nimt-trampolines=8192,nunbox-arbitrary-trampolines=8192":"full,interp,nopagetrampolines,asmonly";NSString *outputAssembly=[fixture stringByAppendingString:@".s"];NSString *extra=compileCore&&[NSBundle.mainBundle.infoDictionary[@"HLGameProfile"] isEqual:@"silksong"]?@",ngsharedvt-trampolines=32768,nftnptr-arg-trampolines=8192":@"";NSString *compilerFlags=[NSString stringWithFormat:@"%s%@,outfile=%@",flags,extra,outputAssembly];int rc=compileAssembly(assemblyInput,opts,compilerFlags.UTF8String,&compilerState);result[@"return_code"]=@(rc);NSString *assembly=[fixture stringByAppendingString:@".s"];NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:assembly error:nil];unsigned long long bytes=[attrs fileSize];result[@"assembly_bytes"]=@(bytes);result[@"assembly_emitted"]=@(rc==0&&bytes>128);result[@"stage"]=@"returned";
    NSString *toolchain=[[[root URLByAppendingPathComponent:@"Frameworks/libHollowToolchain.dylib"] path] copy];
    if(rc==0&&bytes>128&&[NSFileManager.defaultManager fileExistsAtPath:toolchain]) {
     result[@"stage"]=@"toolchain-load";HLWriteReport(self.report);void *tools=dlopen(toolchain.UTF8String,RTLD_NOW|RTLD_LOCAL);
     int (*assemble)(const char *,const char *)=tools?dlsym(tools,"HLAssemble"):NULL;
     int (*link)(const char *,const char *)=tools?dlsym(tools,"HLLink"):NULL;
     if(!assemble||!link){const char *error=dlerror();result[@"toolchain_error"]=error?@(error):@"Toolchain entry missing";}
     else {
      NSString *object=[fixture stringByAppendingString:@".o"];NSString *library=[fixture stringByAppendingString:@".dylib"];
      // Export aliases for our own fixture only; game methods are never renamed here.
      if(!compileCore){NSMutableString *fixtureText=[[NSString stringWithContentsOfFile:assembly encoding:NSUTF8StringEncoding error:nil] mutableCopy];
      [fixtureText appendString:@"\n.globl _HLFixtureAdd\n.set _HLFixtureAdd, CompilerFixture_Add_int_int\n.globl _HLFixtureSum\n.set _HLFixtureSum, CompilerFixture_Sum_long_long\n.globl _HLFixturePositive\n.set _HLFixturePositive, CompilerFixture_IsPositive_int\n"];
      if(![fixtureText writeToFile:assembly atomically:YES encoding:NSUTF8StringEncoding error:nil]){result[@"error"]=@"Could not prepare fixture exports";[self completeProbe:result];return;}
      }
      if(compileCore&&!HLAdaptSilksongCore(assembly,nil)){result[@"error"]=@"Silksong core type-dispatch adaptation guard failed";[self completeProbe:result];return;}
      result[@"stage"]=@"assembling";HLWriteReport(self.report);int ar=assemble(assembly.UTF8String,object.UTF8String);result[@"assembler_return_code"]=@(ar);
      result[@"object_bytes"]=@([[NSFileManager.defaultManager attributesOfItemAtPath:object error:nil] fileSize]);
      if(ar==0){result[@"stage"]=@"linking";HLWriteReport(self.report);int lr=link(object.UTF8String,library.UTF8String);result[@"linker_return_code"]=@(lr);result[@"linked_library_bytes"]=@([[NSFileManager.defaultManager attributesOfItemAtPath:library error:nil] fileSize]);}
      result[@"generated_library_executed"]=@NO;result[@"stage"]=@"toolchain-returned";
      if([result[@"linker_return_code"] intValue]==0&&[result[@"linked_library_bytes"] unsignedLongLongValue]>0){
       result[@"stage"]=@"exporting-unsigned-ipa";HLWriteReport(self.report);NSError *exportError=nil;NSString *ipa=[HLDocuments() stringByAppendingPathComponent:@"HollowLoader-PhoneGenerated-ImportTest-Unsigned.ipa"];
       if(compileCore){[NSFileManager.defaultManager removeItemAtPath:assembly error:nil];[NSFileManager.defaultManager removeItemAtPath:object error:nil];result[@"original_core_native_library_built"]=@YES;result[@"native_library_path"]=library;result[@"stage"]=@"original-core-built";
        NSArray *targets=NSBundle.mainBundle.infoDictionary[@"HLCompileGameAssemblies"];NSMutableArray *rows=[NSMutableArray new];result[@"game_assemblies"]=rows;
        for(NSString *name in targets){@autoreleasepool{
         if(![name.pathExtension isEqual:@"dll"]||![name.lastPathComponent isEqual:name]){result[@"batch_error"]=@"Invalid assembly target";break;}
         NSMutableDictionary *row=[@{@"name":name,@"stage":@"opening"} mutableCopy];[rows addObject:row];result[@"stage"]=@"game-assembly-conversion";HLWriteReport(self.report);
         dispatch_async(dispatch_get_main_queue(),^{self.status.text=[@"Converting original game code: " stringByAppendingString:name];});
         NSString *input=[([name isEqual:@"UnityEngine.CoreModule.dll"]?filtered:managed) stringByAppendingPathComponent:name],*output=[work stringByAppendingPathComponent:[name stringByAppendingString:@".s"]];
         void *gameAssembly=openAssembly(domain,input.UTF8String);if(!gameAssembly){row[@"error"]=@"Could not open original assembly";break;}
         NSString *options=[@"full,interp,nopagetrampolines,asmonly,outfile=" stringByAppendingString:output];void *state=NULL;row[@"stage"]=@"compiling";HLWriteReport(self.report);
         int code=compileAssembly(gameAssembly,opts,options.UTF8String,&state);row[@"compiler_return_code"]=@(code);row[@"assembly_bytes"]=@([[NSFileManager.defaultManager attributesOfItemAtPath:output error:nil] fileSize]);
         if(code||![row[@"assembly_bytes"] unsignedLongLongValue]){row[@"error"]=@"Compiler did not emit assembly";break;}
         NSString *objectPath=[work stringByAppendingPathComponent:[name stringByAppendingString:@".o"]],*nativePath=[work stringByAppendingPathComponent:[name stringByAppendingString:@".dylib"]];
         row[@"stage"]=@"assembling";HLWriteReport(self.report);int assembled=assemble(output.UTF8String,objectPath.UTF8String);row[@"assembler_return_code"]=@(assembled);if(assembled)break;
         row[@"stage"]=@"linking";HLWriteReport(self.report);int linked=link(objectPath.UTF8String,nativePath.UTF8String);row[@"linker_return_code"]=@(linked);if(linked)break;
         row[@"native_bytes"]=@([[NSFileManager.defaultManager attributesOfItemAtPath:nativePath error:nil] fileSize]);row[@"stage"]=@"built";[NSFileManager.defaultManager removeItemAtPath:output error:nil];[NSFileManager.defaultManager removeItemAtPath:objectPath error:nil];HLWriteReport(self.report);
        }}
        result[@"stage"]=@"game-assembly-batch-returned";[self completeProbe:result];return;}
       BOOL exported=HLExportFixtureIPA(library,ipa,&exportError);result[@"unsigned_ipa_exported"]=@(exported);result[@"host_signing_requested"]=@NO;result[@"stage"]=exported?@"awaiting-livecontainer-import":@"export-failed";if(exported)result[@"ipa_bytes"]=@([[NSFileManager.defaultManager attributesOfItemAtPath:ipa error:nil] fileSize]);else result[@"export_error"]=exportError.localizedDescription?:@"IPA export failed";
      }
     }
    }

   }
  }
  [self completeProbe:result];
 });
}
- (void)completeProbe:(NSDictionary *)result {
 self.report[@"compiler_probe"]=result;
 if([NSBundle.mainBundle.infoDictionary[@"HLCompilerStage"] boolValue]){NSArray *targets=NSBundle.mainBundle.infoDictionary[@"HLCompileGameAssemblies"];NSArray *rows=result[@"game_assemblies"];BOOL ready=[result[@"original_core_native_library_built"] boolValue]&&rows.count==targets.count;for(NSDictionary *row in rows)if(![row[@"stage"] isEqual:@"built"])ready=NO;self.report[@"compiler_code_ready"]=@(ready);[[NSJSONSerialization dataWithJSONObject:self.report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[HLDocuments() stringByAppendingPathComponent:@"CompilerBuild.json"] atomically:YES];if(ready){HLWriteReport(self.report);dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:@"Native game code is ready. Choose the original game folder to compress assets and export the game IPA."];[self refresh];});return;}}
 HLWriteReport(self.report);
 if([result[@"original_core_native_library_built"] boolValue]){dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:@"Original core library compiled and linked on this phone without a prepared helper. Game assembly conversion and packaging remain unfinished."];[self refresh];});return;}
 if([result[@"unsigned_ipa_exported"] boolValue]){dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:@"Unsigned test IPA created on this phone. Share it and import it into LiveContainer with JIT disabled. Game import is still unfinished."];[self refresh];});return;}
 dispatch_async(dispatch_get_main_queue(),^{[self setBusy:NO text:[result[@"all_arithmetic_cases_passed"] boolValue]?@"Phone build, host signing and all 13 native-code tests passed without JIT. Game import is still unfinished.":[result[@"assembly_emitted"] boolValue]?([result[@"linked_library_bytes"] unsignedLongLongValue]>0?@"Compiler, assembler and linker completed without JIT. Signing and execution remain unverified.":@"Compiler emitted assembly without JIT. Assembly, linking and signing still need implementation."):@"Compiler test did not complete. The report contains the failing stage."];[self refresh];});
}
- (void)shareReport { [self refresh];NSMutableArray *items=[NSMutableArray arrayWithObject:[NSURL fileURLWithPath:[HLDocuments() stringByAppendingPathComponent:@"Loader-report.json"]]];NSString *last=self.report[@"last_export_path"];if(last&&[NSFileManager.defaultManager fileExistsAtPath:last])[items addObject:[NSURL fileURLWithPath:last]];NSURL *log=[NSURL fileURLWithPath:[HLDocuments() stringByAppendingPathComponent:@"CompilerProbe.log"]];if([NSFileManager.defaultManager fileExistsAtPath:log.path])[items addObject:log];NSURL *ipa=[NSURL fileURLWithPath:[HLDocuments() stringByAppendingPathComponent:@"HollowLoader-PhoneGenerated-ImportTest-Unsigned.ipa"]];if([NSFileManager.defaultManager fileExistsAtPath:ipa.path])[items addObject:ipa];for(NSString *name in @[@"HollowKnight-CompilerStage-Unsigned.ipa",@"HollowKnight-PhoneBuilt-Unsigned.ipa"]){NSURL *file=[NSURL fileURLWithPath:[HLDocuments() stringByAppendingPathComponent:name]];if([NSFileManager.defaultManager fileExistsAtPath:file.path])[items addObject:file];}UIActivityViewController *sheet=[[UIActivityViewController alloc]initWithActivityItems:items applicationActivities:nil];sheet.popoverPresentationController.sourceView=self.share;[self presentViewController:sheet animated:YES completion:nil]; }
@end
@interface HLSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation HLSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 self.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)scene];BOOL home=[NSBundle.mainBundle.infoDictionary[@"HLBuilderSupportAvailable"] boolValue]&&![NSBundle.mainBundle.infoDictionary[@"HLBuildCompilerStageProbe"] boolValue]&&![NSBundle.mainBundle.infoDictionary[@"HLCompilerStage"] boolValue];UIViewController *root=home?[NSClassFromString(@"HLHomeController") new]:[HLController new];self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:root];[self.window makeKeyAndVisible];
}
@end
@interface HLAppDelegate : UIResponder <UIApplicationDelegate> @end
@implementation HLAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {fprintf(stderr,"HL loader application started\n");return YES;}
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:@"Loader" sessionRole:session.role];config.delegateClass=HLSceneDelegate.class;return config;}
@end
int main(int argc,char **argv) {@autoreleasepool{fprintf(stderr,"HL native main started\n");return UIApplicationMain(argc,argv,nil,NSStringFromClass(HLAppDelegate.class));}}
