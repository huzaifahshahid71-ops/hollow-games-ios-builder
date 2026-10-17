// Private diagnostic launcher for the exact shipped Mono runtime on macOS.
#include <stdio.h>
#include <dlfcn.h>
int main(int argc, char **argv) {
 if (argc < 3) { fprintf(stderr,"usage: mono_host runtime.dylib options...\n"); return 2; }
 void *runtime=dlopen(argv[1],RTLD_NOW|RTLD_GLOBAL);
 if (!runtime) { fprintf(stderr,"%s\n",dlerror()); return 3; }
 int (*mono_main)(int,char **)=dlsym(runtime,"mono_main");
 if (!mono_main) return 4;
 return mono_main(argc-1,argv+1);
}
