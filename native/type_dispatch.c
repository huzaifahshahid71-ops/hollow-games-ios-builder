// Diagnostic bridge for a failing generated core-library virtual call.
#include <string.h>
#include <stdio.h>
#include <stdint.h>
extern void *mono_object_get_class(void *);
extern const char *mono_class_get_name(void *);
extern void *mono_class_get_method_from_name(void *, const char *, int);
extern void *mono_runtime_invoke(void *, void *, void **, void **);
extern void mono_raise_exception(void *);
extern void *mono_reflection_type_get_type(void *);
extern void *mono_class_from_mono_type(void *);
extern int mono_class_is_assignable_from(void *, void *);
extern void mono_stack_walk(int (*)(void *,int32_t,int32_t,int,void *),void *);
extern char *mono_method_full_name(void *,int);
extern void mono_free(void *);
static int trace_frame(void *method,int32_t native,int32_t il,int managed,void *data) {
 unsigned *n=data; if((*n)++>=24) return 1;
 if(method) {char *name=mono_method_full_name(method,1); fprintf(stderr,"TYPESTACK %s il=%d\n",name,il); mono_free(name);} return 0;
}
extern void *mono_profiler_create(void *);
extern void mono_profiler_set_exception_throw_callback(void *,void (*)(void *,void *));
extern void *mono_class_get_parent(void *);
extern void *mono_class_get_field_from_name(void *,const char *);
extern void mono_field_get_value(void *,void *,void *);
extern char *mono_string_to_utf8(void *);
static void trace_exception(void *prof,void *exception) {
 static unsigned count; if(++count>30) return;
 void *klass=mono_object_get_class(exception); fprintf(stderr,"TYPEEX %u %s\n",count,mono_class_get_name(klass));
 for(void *k=klass;k;k=mono_class_get_parent(k)) {void *f=mono_class_get_field_from_name(k,"_message"); if(f) {void *str=0;mono_field_get_value(exception,f,&str);if(str){char *txt=mono_string_to_utf8(str);fprintf(stderr,"TYPEEX message=%s\n",txt);mono_free(txt);}break;}}
 unsigned frames=0;mono_stack_walk(trace_frame,&frames);
}
int SilksongTypeAssignable(void *target, void *candidate) {
    if (!candidate) return 0;
    if (target == candidate) return 1;
    static unsigned calls; unsigned n=++calls;
    if(n==1) mono_profiler_set_exception_throw_callback(mono_profiler_create(0),trace_exception);
    if(n<8) fprintf(stderr,"TYPEBRIDGE call=%u target=%p candidate=%p\n",n,target,candidate);
    void *klass = mono_object_get_class(candidate);
    if(n<8) fprintf(stderr,"TYPEBRIDGE klass=%p name=%s\n",klass,mono_class_get_name(klass));
    if (strcmp(mono_class_get_name(klass), "RuntimeType") != 0) {
        uintptr_t *o=candidate,*v=(uintptr_t *)o[0];
        fprintf(stderr,"TYPEBRIDGE unusual call=%u target=%p candidate=%p class=%p name=%s obj=%llx,%llx,%llx,%llx vtable=%llx,%llx,%llx,%llx\n",n,target,candidate,klass,mono_class_get_name(klass),(unsigned long long)o[0],(unsigned long long)o[1],(unsigned long long)o[2],(unsigned long long)o[3],(unsigned long long)v[0],(unsigned long long)v[1],(unsigned long long)v[2],(unsigned long long)v[3]);
        unsigned frames=0; mono_stack_walk(trace_frame,&frames);
        void *method = mono_class_get_method_from_name(klass, "get_UnderlyingSystemType", 0);
        fprintf(stderr,"TYPEBRIDGE getter=%p\n",method);
        if (!method) return 0;
        void *exception = 0;
        candidate = mono_runtime_invoke(method, candidate, 0, &exception);
        if (exception) mono_raise_exception(exception);
        if (!candidate || strcmp(mono_class_get_name(mono_object_get_class(candidate)), "RuntimeType") != 0) return 0;
    }
    void *targetClass = mono_class_from_mono_type(mono_reflection_type_get_type(target));
    void *candidateClass = mono_class_from_mono_type(mono_reflection_type_get_type(candidate));
    if(n<8) fprintf(stderr,"TYPEBRIDGE targetClass=%p candidateClass=%p\n",targetClass,candidateClass);
    return mono_class_is_assignable_from(targetClass, candidateClass);
}

void SilksongTraceWrapper(void *obj, void *ret, void **arg, void **desc) {
 static unsigned count; if(++count<4) fprintf(stderr,"TYPEWRAPPER this=%p ret=%p argp=%p arg0=%p arg1=%p desc=%p func=%p extra=%p\n",obj,ret,arg,arg[0],arg[1],desc,desc[0],desc[1]);
}
