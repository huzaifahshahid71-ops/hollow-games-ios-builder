// In-process Mach-O linking through LLVM LLD. No subprocess or JIT is used.
#include "lld/Common/Driver.h"
#include "llvm/Support/raw_ostream.h"
#include <mutex>
#include <string>
#include "llvm/Support/FileSystem.h"
LLD_HAS_DRIVER(macho)
extern "C" int HLLink(const char *input, const char *output) {
 static std::mutex lock;std::lock_guard<std::mutex> guard(lock);
 static bool usable=true;if(!usable)return 2;
 // Project-authored API declaration only; no Apple SDK files are bundled.
 std::string stub=std::string(output)+".libSystem.tbd";std::error_code ec;
 {llvm::raw_fd_ostream file(stub,ec,llvm::sys::fs::OF_None);if(ec){llvm::errs()<<ec.message()<<"\n";return 3;}
 file<<"--- !tapi-tbd\ntbd-version: 4\ntargets: [ arm64-ios ]\ninstall-name: '/usr/lib/libSystem.B.dylib'\ncurrent-version: 1\ncompatibility-version: 1\n...\n";file.flush();if(file.has_error())return 4;}
 std::string target(output);std::string install="@rpath/"+target.substr(target.find_last_of("/\\")+1);
 const char *args[]={"ld64.lld","-dylib","-arch","arm64","-platform_version","ios","17.0","27.0","-install_name",install.c_str(),"-undefined","dynamic_lookup","-needed_library",stub.c_str(),"-o",output,input};
 const lld::DriverDef drivers[]={{lld::Darwin,&lld::macho::link}};
 lld::Result result=lld::lldMain(args,llvm::outs(),llvm::errs(),drivers);
 usable=result.canRunAgain;return result.retCode;
}
