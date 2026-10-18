// Compiler-only data buffers: never grant executable memory. Not a game runtime shim.
#include <sys/mman.h>
#include <dlfcn.h>
#include <stdio.h>
#include <pthread.h>
static void *kernel;
static pthread_once_t once=PTHREAD_ONCE_INIT;
static void load_kernel(void){kernel=dlopen("/usr/lib/system/libsystem_kernel.dylib",RTLD_NOW|RTLD_LOCAL);}
void *smmp(void *address,size_t length,int protection,int flags,int fd,off_t offset){
 if(protection&PROT_EXEC){fprintf(stderr,"HL compiler stores executable-requested buffer as RW data (%zu bytes)\n",length);protection=(protection&~PROT_EXEC)|PROT_READ|PROT_WRITE;}
#ifdef MAP_JIT
 flags&=~MAP_JIT;
#endif
 return mmap(address,length,protection,flags,fd,offset);
}
int mprotect(void *address,size_t length,int protection){
 pthread_once(&once,load_kernel);int(*real_protect)(void*,size_t,int)=kernel?dlsym(kernel,"mprotect"):NULL;if(!real_protect)return -1;
 if(protection&PROT_EXEC)protection=(protection&~PROT_EXEC)|PROT_READ|PROT_WRITE;
 return real_protect(address,length,protection);
}

// Exact runtime parser workaround: upstream passes a leading = to atoi.
#include <stdlib.h>
int atoi(const char *text){return (int)strtol(text&&text[0]=='='?text+1:text,NULL,10);}
