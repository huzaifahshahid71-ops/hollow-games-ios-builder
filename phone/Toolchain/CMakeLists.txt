set(LLVM_LINK_COMPONENTS AArch64AsmParser AArch64Desc AArch64Info MC MCParser Support Object BinaryFormat TargetParser)
include_directories(${LLVM_MAIN_SRC_DIR}/../lld/include)
add_llvm_library(HollowAssembler STATIC HollowAssembler.cpp HollowLinker.cpp LINK_LIBS lldMachO lldCommon)
