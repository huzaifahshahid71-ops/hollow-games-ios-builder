#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <stdint.h>
#import <limits.h>
@interface HLFixtureScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation HLFixtureScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];UIViewController *vc=[UIViewController new];vc.view.backgroundColor=UIColor.systemBackgroundColor;self.window.rootViewController=vc;
 UILabel *label=[UILabel new];label.numberOfLines=0;label.textAlignment=NSTextAlignmentCenter;label.translatesAutoresizingMaskIntoConstraints=NO;[vc.view addSubview:label];[NSLayoutConstraint activateConstraints:@[[label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],[label.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:24],[label.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-24]]];[self.window makeKeyAndVisible];
 NSMutableDictionary *report=[@{@"test":@"phone-generated-library-import",@"generated_library_executed":@NO} mutableCopy];
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/CompilerFixture.dll.dylib"];void *lib=dlopen(path.UTF8String,RTLD_NOW|RTLD_LOCAL);
 if(!lib){const char *e=dlerror();report[@"error"]=e?@(e):@"Library load failed";label.text=@"Library loading failed. See Import-test-report.json.";}
 else {
  int32_t(*add)(int32_t,int32_t)=dlsym(lib,"HLFixtureAdd");int64_t(*sum)(int64_t,int64_t)=dlsym(lib,"HLFixtureSum");int32_t(*positive)(int32_t)=dlsym(lib,"HLFixturePositive");
  if(!add||!sum||!positive){report[@"error"]=@"Fixture exports missing";label.text=@"Fixture exports missing.";}
  else {int passed=0,total=0;int32_t p[][2]={{1,2},{-100,23},{0,0},{INT32_MAX,1}};for(int i=0;i<4;i++){passed+=add(p[i][0],p[i][1])==(int32_t)((uint32_t)p[i][0]+(uint32_t)p[i][1]);total++;}int64_t q[][2]={{1LL<<40,1LL<<40},{-(1LL<<40),123},{0,0},{INT64_MAX,1}};for(int i=0;i<4;i++){passed+=sum(q[i][0],q[i][1])==(int64_t)((uint64_t)q[i][0]+(uint64_t)q[i][1]);total++;}int32_t v[]={INT32_MIN,-1,0,1,INT32_MAX};for(int i=0;i<5;i++){passed+=positive(v[i])==(v[i]>0);total++;}report[@"generated_library_executed"]=@YES;report[@"passed"]=@(passed);report[@"total"]=@(total);label.text=[NSString stringWithFormat:@"Phone-generated code\n%d / %d tests passed\n\nGame import is still unfinished.",passed,total];}
 }
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[docs stringByAppendingPathComponent:@"Import-test-report.json"] atomically:YES];
}
@end
@interface HLFixtureDelegate : UIResponder <UIApplicationDelegate> @end
@implementation HLFixtureDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {return YES;}
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:@"Fixture" sessionRole:session.role];config.delegateClass=HLFixtureScene.class;return config;}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(HLFixtureDelegate.class));}}
