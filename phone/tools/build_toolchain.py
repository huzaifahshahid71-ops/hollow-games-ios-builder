#!/usr/bin/env python3
"""Build experimental iOS LLVM MC/LLD libraries; no game input is used."""
from pathlib import Path
import argparse,hashlib,json,subprocess,tarfile,urllib.request,os
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--cmake',required=True);p.add_argument('--ninja',required=True);p.add_argument('--jobs',type=int,default=8);a=p.parse_args()
work=a.work.resolve();work.mkdir(parents=True,exist_ok=True)
archive=work/'llvm-project-20.1.8.src.tar.xz';digest='6898f963c8e938981e6c4a302e83ec5beb4630147c7311183cf61069af16333d'
if not archive.exists():urllib.request.urlretrieve('https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/llvm-project-20.1.8.src.tar.xz',archive)
if hashlib.sha256(archive.read_bytes()).hexdigest()!=digest:raise SystemExit('LLVM source checksum mismatch')
source=work/'source'/'llvm-project-20.1.8.src'
if not (source/'.selected-extraction-complete').exists():
 with tarfile.open(archive,'r:xz') as t:
  for m in t:
   parts=Path(m.name).parts
   if len(parts)<2 or parts[1] not in ('llvm','lld','cmake','third-party'):continue
   if any(x in ('test','unittests','docs','benchmarks','examples') for x in parts[2:]) and parts[-1]!='CMakeLists.txt':continue
   if '..' in parts:raise SystemExit('Unexpected source archive path')
   t.extract(m,work/'source')
 (source/'.selected-extraction-complete').touch()
root=Path(__file__).resolve().parent.parent;host=work/'host';ios=work/'ios'
common=['-G','Ninja','-DCMAKE_MAKE_PROGRAM='+str(Path(a.ninja).resolve()),'-DLLVM_TARGETS_TO_BUILD=AArch64','-DLLVM_INCLUDE_TESTS=OFF','-DLLVM_INCLUDE_EXAMPLES=OFF','-DLLVM_INCLUDE_BENCHMARKS=OFF','-DLLVM_INCLUDE_DOCS=OFF','-DLLVM_ENABLE_ZLIB=OFF','-DLLVM_ENABLE_ZSTD=OFF','-DLLVM_ENABLE_LIBXML2=OFF','-DLLVM_ENABLE_TERMINFO=OFF','-DLLVM_ENABLE_LIBEDIT=OFF','-DLLVM_ENABLE_BACKTRACES=OFF','-DLLVM_ENABLE_CRASH_OVERRIDES=OFF','-DLLVM_BUILD_TOOLS=OFF']
def run(args,name):
 print(name,flush=True)
 with (work/(name+'.log')).open('w') as log:subprocess.run([a.cmake,*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True)
run(['-S',source/'llvm','-B',host,*common,'-DCMAKE_BUILD_TYPE=Release'],'host-configure')
run(['--build',host,'--target','llvm-tblgen','-j',a.jobs],'host-build')
run(['-S',source/'llvm','-B',ios,*common,'-DCMAKE_BUILD_TYPE=MinSizeRel','-DCMAKE_SYSTEM_NAME=iOS','-DCMAKE_OSX_SYSROOT=iphoneos','-DCMAKE_OSX_ARCHITECTURES=arm64','-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0','-DCMAKE_MACOSX_BUNDLE=OFF','-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO','-DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios17.0','-DLLVM_HOST_TRIPLE=arm64-apple-ios17.0','-DLLVM_TABLEGEN='+str(host/'bin/llvm-tblgen'),'-DLLVM_NATIVE_TOOL_DIR='+str(host/'bin'),'-DLLVM_ENABLE_PROJECTS=lld','-DLLVM_EXTERNAL_PROJECTS=HollowAssembler','-DLLVM_EXTERNAL_HOLLOWASSEMBLER_SOURCE_DIR='+str(root/'Toolchain'),'-DLLD_BUILD_TOOLS=OFF','-DLLD_INCLUDE_DOCS=OFF','-DLLD_INCLUDE_TESTS=OFF','-DLLVM_ENABLE_THREADS=OFF','-DLLVM_ENABLE_PIC=ON'],'ios-configure')
run(['--build',ios,'--target','HollowAssembler','lldMachO','-j',a.jobs],'ios-build')
library=work/'libHollowToolchain.dylib'
archives=sorted((ios/'lib').glob('*.a'))
subprocess.run(['xcrun','--sdk','iphoneos','clang++','-target','arm64-apple-ios17.0','-dynamiclib','-Wl,-install_name,@rpath/libHollowToolchain.dylib','-Wl,-dead_strip','-Wl,-u,_HLAssemble','-Wl,-u,_HLLink','-Wl,-exported_symbol,_HLAssemble','-Wl,-exported_symbol,_HLLink',*map(str,archives),'-o',str(library)],check=True)
(work/'toolchain-report.json').write_text(json.dumps({'llvm':'20.1.8','source_sha256':digest,'target':'arm64-apple-ios17.0','libraries':str(ios/'lib'),'phone_execution_verified':False},indent=2)+'\n')
