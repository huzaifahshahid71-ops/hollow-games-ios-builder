#import <UIKit/UIKit.h>
#import <dlfcn.h>
@interface HLCoreScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation HLCoreScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 self.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)scene];UIViewController *vc=[UIViewController new];vc.view.backgroundColor=UIColor.systemBackgroundColor;self.window.rootViewController=vc;UILabel *label=[UILabel new];label.numberOfLines=0;label.translatesAutoresizingMaskIntoConstraints=NO;label.text=@"Testing phone-built core…";[vc.view addSubview:label];[NSLayoutConstraint activateConstraints:@[[label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],[label.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:24],[label.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-24]]];[self.window makeKeyAndVisible];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
 NSString *root=NSBundle.mainBundle.bundlePath,*managed=[root stringByAppendingPathComponent:@"Managed"],*docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 NSMutableDictionary *result=[@{@"test":@"phone-built-original-core",@"aot_mode":@5,@"phone_converted_runtime":@([NSBundle.mainBundle.infoDictionary[@"HLPhoneConvertedRuntime"] boolValue]),@"managed_method_executed":@NO,@"stage":@"runtime-load"} mutableCopy];
 void *h=dlopen([root stringByAppendingPathComponent:@"Frameworks/libmonobdwgc-2.0.dylib"].UTF8String,RTLD_NOW|RTLD_GLOBAL);
 if(!h){const char *e=dlerror();result[@"error"]=e?@(e):@"Runtime load failed";}
 else {
 void(*mode)(int)=dlsym(h,"mono_jit_set_aot_mode");void(*dirs)(const char*,const char*)=dlsym(h,"mono_set_dirs");void(*paths)(const char*)=dlsym(h,"mono_set_assemblies_path");unsigned int(*defaultOpts)(const char*)=dlsym(h,"mono_parse_default_optimizations");void(*defaults)(int,unsigned int)=dlsym(h,"mono_set_defaults");void*(*initialize)(const char*,const char*)=dlsym(h,"mono_jit_init_version_for_test_only");
 void*(*corlib)(void)=dlsym(h,"mono_get_corlib");void*(*descriptor)(const char*,int)=dlsym(h,"mono_method_desc_new");void*(*find)(void*,void*)=dlsym(h,"mono_method_desc_search_in_image");void*(*invoke)(void*,void*,void**,void**)=dlsym(h,"mono_runtime_invoke");void*(*unbox)(void*)=dlsym(h,"mono_object_unbox");
 if(!mode||!initialize||!corlib||!descriptor||!find||!invoke||!unbox)result[@"error"]=@"Required runtime entry missing";
 else {
 mode(5);setenv("MONO_PATH",managed.UTF8String,1);if(dirs)dirs(managed.UTF8String,docs.UTF8String);if(paths)paths(managed.UTF8String);if(defaults)defaults(0,defaultOpts?defaultOpts(NULL):0);
 result[@"stage"]=@"core-bootstrap";[[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[docs stringByAppendingPathComponent:@"Core-test-report.json"] atomically:YES];
 void *domain=initialize("PhoneGeneratedCoreTest","v4.0.30319");result[@"core_initialized"]=@(domain!=NULL);
 if(domain){void *method=find(descriptor("System.Math:Abs(int)",1),corlib());if(!method)result[@"error"]=@"Math.Abs(int) not found";else {int input=-123;void *args[]={&input},*exception=NULL;result[@"stage"]=@"managed-invoke";[[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[docs stringByAppendingPathComponent:@"Core-test-report.json"] atomically:YES];void *value=invoke(method,NULL,args,&exception);if(value&&!exception){int answer=*(int *)unbox(value);result[@"result"]=@(answer);result[@"managed_method_executed"]=@YES;result[@"passed"]=@(answer==123);}else result[@"error"]=@"Managed invocation failed";}}
 }
 }
 result[@"stage"]=@"finished";[[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[docs stringByAppendingPathComponent:@"Core-test-report.json"] atomically:YES];dispatch_async(dispatch_get_main_queue(),^{label.text=[result[@"passed"] boolValue]?@"Phone-built original core works!\nMath.Abs(-123) = 123\nJIT disabled runtime mode\n\nFull game testing remains unfinished.":[NSString stringWithFormat:@"Core test did not pass.\n%@",result[@"error"]?:result.description];});
 });
}
@end
@interface HLCoreDelegate : UIResponder <UIApplicationDelegate> @end
@implementation HLCoreDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{return YES;}
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options{UISceneConfiguration *c=[[UISceneConfiguration alloc]initWithName:@"Core" sessionRole:session.role];c.delegateClass=HLCoreScene.class;return c;}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(HLCoreDelegate.class));}}
