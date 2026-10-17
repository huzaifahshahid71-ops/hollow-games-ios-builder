#import <Foundation/Foundation.h>
#import <dlfcn.h>
__attribute__((visibility("default"))) void HKQueueGameKey(unsigned short key,BOOL down) {
 static void *runtime,*method;static unsigned failures;
 if(!runtime){NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Frameworks/libmonobdwgc-2.0.dylib"];runtime=dlopen(path.UTF8String,RTLD_LAZY|RTLD_NOLOAD);}
 if(!runtime)return;
 void *(*domain)(void)=dlsym(runtime,"mono_domain_get");
 void *(*open)(void *,const char *)=dlsym(runtime,"mono_domain_assembly_open");
 void *(*image)(void *)=dlsym(runtime,"mono_assembly_get_image");
 void *(*klass)(void *,const char *,const char *)=dlsym(runtime,"mono_class_from_name");
 void *(*getmethod)(void *,const char *,int)=dlsym(runtime,"mono_class_get_method_from_name");
 void *(*invoke)(void *,void *,void **,void **)=dlsym(runtime,"mono_runtime_invoke");
 if(!domain||!open||!image||!klass||!getmethod||!invoke||!domain())return;
 if(!method){NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Data/Managed/HKInputBridge.dll"];void *a=open(domain(),path.UTF8String);if(a){void *k=klass(image(a),"HKPort","KeyboardBridge");if(k)method=getmethod(k,"SetKey",2);}if(method)NSLog(@"HK managed input bridge loaded");}
 if(!method){if(failures++<3)NSLog(@"HK managed input bridge not found");return;}
 int code=key,pressed=down?1:0;void *args[]={&code,&pressed},*exception=0;invoke(method,0,args,&exception);
 if(exception&&failures++<10){void *(*getclass)(void *)=dlsym(runtime,"mono_object_get_class");const char *(*getname)(void *)=dlsym(runtime,"mono_class_get_name");NSLog(@"HK queued-key exception %s",getclass&&getname?getname(getclass(exception)):"unknown");}
}
