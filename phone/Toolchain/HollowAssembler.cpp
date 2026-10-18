// LLVM MC integration, following llvm-mc's assembly pipeline.
// LLVM is licensed under Apache-2.0 WITH LLVM-exception.
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectFileInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCParser/MCAsmParser.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCTargetOptions.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TargetParser/Triple.h"
#include <memory>
#include <mutex>
extern "C" void LLVMInitializeAArch64TargetInfo();
extern "C" void LLVMInitializeAArch64TargetMC();
extern "C" void LLVMInitializeAArch64AsmParser();
extern "C" int HLAssemble(const char *input, const char *output) {
 using namespace llvm;
 static std::once_flag once;
 std::call_once(once, [] { LLVMInitializeAArch64TargetInfo();LLVMInitializeAArch64TargetMC();LLVMInitializeAArch64AsmParser(); });
 // LLVM registries and diagnostics are shared; serialize tool invocations.
 static std::mutex lock;std::lock_guard<std::mutex> guard(lock);
 const std::string triple="arm64-apple-ios17.0";std::string error;
 const Target *target=TargetRegistry::lookupTarget(triple,error);
 if(!target){errs()<<error<<"\n";return 1;}
 auto buffer=MemoryBuffer::getFile(input,true);
 if(!buffer){errs()<<buffer.getError().message()<<"\n";return 2;}
 SourceMgr source;source.AddNewSourceBuffer(std::move(*buffer),SMLoc());
 MCTargetOptions options;
 std::unique_ptr<MCRegisterInfo> registers(target->createMCRegInfo(triple));
 std::unique_ptr<MCAsmInfo> asmInfo(target->createMCAsmInfo(*registers,triple,options));
 std::unique_ptr<MCSubtargetInfo> subtarget(target->createMCSubtargetInfo(triple,"generic",""));
 std::unique_ptr<MCInstrInfo> instructions(target->createMCInstrInfo());
 if(!registers||!asmInfo||!subtarget||!instructions)return 3;
 Triple targetTriple(triple);MCContext context(targetTriple,asmInfo.get(),registers.get(),subtarget.get(),&source,&options);
 std::unique_ptr<MCObjectFileInfo> objectInfo(target->createMCObjectFileInfo(context,true,false));
 context.setObjectFileInfo(objectInfo.get());context.setDwarfVersion(4);
 std::error_code ec;raw_fd_ostream destination(output,ec,sys::fs::OF_None);
 if(ec){errs()<<ec.message()<<"\n";return 4;}
 std::unique_ptr<MCAsmBackend> backend(target->createMCAsmBackend(*subtarget,*registers,options));
 auto writer=backend->createObjectWriter(destination);
 std::unique_ptr<MCCodeEmitter> emitter(target->createMCCodeEmitter(*instructions,context));
 std::unique_ptr<MCStreamer> streamer(target->createMCObjectStreamer(targetTriple,context,std::move(backend),std::move(writer),std::move(emitter),*subtarget));
 streamer->emitVersionForTarget(targetTriple,VersionTuple(),nullptr,VersionTuple());
 std::unique_ptr<MCAsmParser> parser(createMCAsmParser(source,context,*streamer,*asmInfo));
 std::unique_ptr<MCTargetAsmParser> targetParser(target->createMCAsmParser(*subtarget,*parser,*instructions,options));
 if(!targetParser)return 5;
 parser->setTargetParser(*targetParser);
 int status=parser->Run(false);destination.flush();
 if(destination.has_error())return 6;
 return status;
}
