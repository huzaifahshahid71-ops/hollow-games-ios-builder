#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
extern BOOL PXExtractPackage(NSURL *,NSURL *,void(^)(NSString *),NSDictionary **,NSError **);
@interface PXController:UIViewController<UIDocumentPickerDelegate>
@property UILabel *status;@property UIButton *choose;@property UIButton *folder;@property BOOL busy;@property NSURL *pendingPackage;
@end
@implementation PXController
- (void)viewDidLoad{[super viewDidLoad];self.title=@"GOG PKG Extractor";self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.view.backgroundColor=[UIColor colorWithRed:.04 green:.07 blue:.12 alpha:1];UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=26;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:stack];UIImageView *icon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"shippingbox.and.arrow.backward.fill"]];icon.contentMode=UIViewContentModeScaleAspectFit;icon.tintColor=UIColor.systemTealColor;[icon.heightAnchor constraintEqualToConstant:96].active=YES;[stack addArrangedSubview:icon];UILabel *title=[UILabel new];title.text=@"From package\nto game folder.";title.numberOfLines=0;title.font=[UIFont systemFontOfSize:32 weight:UIFontWeightBold];[stack addArrangedSubview:title];UILabel *intro=[UILabel new];intro.text=@"Extract your GOG Mac copy of Hollow Knight 1.5.12620 or Silksong 1.0.30000 entirely on this iPhone. Then select the extracted game folder in Hollow Builder. Other PKG formats are not supported.";intro.numberOfLines=0;[stack addArrangedSubview:intro];UIButtonConfiguration *config;if(@available(iOS 26.0,*))config=[UIButtonConfiguration prominentGlassButtonConfiguration];else config=[UIButtonConfiguration filledButtonConfiguration];config.title=@"Choose GOG .pkg";self.choose=[UIButton buttonWithConfiguration:config primaryAction:nil];[self.choose addTarget:self action:@selector(selectPackage) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:self.choose];UIButtonConfiguration *folderConfig=[UIButtonConfiguration tintedButtonConfiguration];folderConfig.title=@"Choose containing folder instead";folderConfig.subtitle=@"Open its folder, then tap Open at top-right.";self.folder=[UIButton buttonWithConfiguration:folderConfig primaryAction:nil];[self.folder addTarget:self action:@selector(selectFolder) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:self.folder];self.status=[UILabel new];self.status.numberOfLines=0;self.status.text=@"Original packages stay unchanged. Installer scripts are never executed. Keep at least 5.5 GB free for Hollow Knight or 9 GB for Silksong, in addition to the package.";self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];[stack addArrangedSubview:self.status];UILayoutGuide *safe=self.view.safeAreaLayoutGuide;[NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:26],[stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-26],[stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:28],[stack.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-20]]];}
- (void)selectPackage{
 if(self.busy)return;
 // Providers may classify flat installer packages as composite items, not data.
 UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeItem,UTTypeContent,UTTypeData,UTTypeArchive] asCopy:YES];
 picker.allowsMultipleSelection=NO;picker.shouldShowFileExtensions=YES;picker.delegate=self;picker.modalPresentationStyle=UIModalPresentationFullScreen;self.status.text=@"Tap your .pkg file to import a temporary local copy. This needs additional free space equal to the package size. No checkmark is required in single-file mode.";
 [self presentViewController:picker animated:YES completion:nil];
}
- (void)selectFolder{
 if(self.busy)return;
 UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
 picker.allowsMultipleSelection=NO;picker.delegate=self;self.status.text=@"Browse to the folder containing your .pkg, then tap Open at the top-right. Select the folder itself, not the package inside it.";
 [self presentViewController:picker animated:YES completion:nil];
}
- (void)showSelectionError:(NSString *)message{
 self.status.text=message;
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Choose a GOG package" message:message preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller{self.pendingPackage=nil;}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
 NSURL *selected=urls.firstObject;if(!selected)return;
 BOOL access=[selected startAccessingSecurityScopedResource];
 if(self.pendingPackage){NSURL *package=self.pendingPackage;self.pendingPackage=nil;if(access)[selected stopAccessingSecurityScopedResource];[self extractPackage:package scope:selected];return;}
 NSNumber *directory=nil;[selected getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
 if(directory.boolValue && ![selected.pathExtension.lowercaseString isEqual:@"pkg"]){
  NSError *error=nil;NSArray *items=[NSFileManager.defaultManager contentsOfDirectoryAtURL:selected includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:0 error:&error];
  NSMutableArray<NSURL *> *packages=[NSMutableArray new];
  for(NSURL *item in items){NSNumber *regular=nil;[item getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];if(regular.boolValue&&[item.pathExtension.lowercaseString isEqual:@"pkg"])[packages addObject:item];}
  if(access)[selected stopAccessingSecurityScopedResource];
  if(!packages.count){[self showSelectionError:error.localizedDescription?:@"No flat .pkg files found. Choose the folder directly containing your downloaded GOG Mac installer. Download cloud files to this iPhone first."];return;}
  if(packages.count==1){[self extractPackage:packages.firstObject scope:selected];return;}
  UIAlertController *list=[UIAlertController alertControllerWithTitle:@"Select a package" message:nil preferredStyle:UIAlertControllerStyleAlert];
  for(NSURL *item in packages)[list addAction:[UIAlertAction actionWithTitle:item.lastPathComponent style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self extractPackage:item scope:selected];}]];
  [list addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:list animated:YES completion:nil];return;
 }
 if(access)[selected stopAccessingSecurityScopedResource];
 if(directory.boolValue||![selected.pathExtension.lowercaseString isEqual:@"pkg"]){[self showSelectionError:@"Select the original flat GOG .pkg installer file. Directory-style packages and other file formats are not supported."];return;}
 self.pendingPackage=selected;[self selectFolder];
}
- (void)extractPackage:(NSURL *)source scope:(NSURL *)scope{
 if(self.busy)return;
 BOOL access=[scope startAccessingSecurityScopedResource];
 self.busy=YES;self.choose.enabled=NO;self.folder.enabled=NO;UIApplication.sharedApplication.idleTimerDisabled=YES;self.status.text=@"Checking package and available storage…";dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSString *apps=NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent,*base=[apps.lastPathComponent isEqual:@"Applications"]?apps.stringByDeletingLastPathComponent:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;NSNumber *scopeDirectory=nil;[scope getResourceValue:&scopeDirectory forKey:NSURLIsDirectoryKey error:nil];NSString *parent=scopeDirectory.boolValue?scope.path:[base stringByAppendingPathComponent:@"Extracted GOG Games"];NSFileManager *fm=NSFileManager.defaultManager;NSError *error=nil;BOOL prepared=[fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:&error];NSString *name=[source.lastPathComponent.stringByDeletingPathExtension stringByReplacingOccurrencesOfString:@"/" withString:@"-"];if(name.length>100)name=[name substringToIndex:100];NSString *folder=[parent stringByAppendingPathComponent:name];NSUInteger count=2;while([fm fileExistsAtPath:folder])folder=[parent stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu",name,(unsigned long)count++]];NSDictionary *report=nil;BOOL okay=prepared&&PXExtractPackage(source,[NSURL fileURLWithPath:folder isDirectory:YES],^(NSString *message){dispatch_async(dispatch_get_main_queue(),^{self.status.text=message;});},&report,&error);if(access)[scope stopAccessingSecurityScopedResource];if(okay)[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[folder stringByAppendingPathComponent:@"Extraction-report.json"] atomically:YES];dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.choose.enabled=YES;self.folder.enabled=YES;UIApplication.sharedApplication.idleTimerDisabled=NO;self.status.text=okay?[NSString stringWithFormat:@"Extraction complete. Game folder saved in %@. Choose this folder in the game builder.",folder]:error.localizedDescription?:@"Extraction failed; the original package is preserved.";UIAlertController *notice=[UIAlertController alertControllerWithTitle:okay?@"Game folder ready":@"Could not extract package" message:self.status.text preferredStyle:UIAlertControllerStyleAlert];[notice addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:notice animated:YES completion:nil];});});}
@end
