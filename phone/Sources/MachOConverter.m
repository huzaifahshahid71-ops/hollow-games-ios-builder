#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
// Bounded conversions only. No original input is modified and no signatures are produced.
static NSData *HLMachOFail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"HollowMachO" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return nil;}
static uint32_t HLBE32(const uint8_t *p){return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3];}
static uint64_t HLBE64(const uint8_t *p){return (uint64_t)HLBE32(p)<<32|HLBE32(p+4);}
static BOOL HLRewriteDependencies(NSMutableData *image,NSDictionary *imports,NSError **error){
 uint8_t *bytes=image.mutableBytes;struct mach_header_64 *header=(void *)bytes;uint64_t end=32+(uint64_t)header->sizeofcmds,position=32,firstData=image.length;NSMutableData *commands=[NSMutableData new];NSMutableSet *matched=[NSMutableSet new];BOOL hasFrameworkRpath=NO;uint32_t extraCommands=0;
 if(end>image.length||header->ncmds>header->sizeofcmds/8)return HLMachOFail(error,@"Invalid load-command region")!=nil;
 for(uint32_t i=0;i<header->ncmds;i++){
  if(position+8>end)return HLMachOFail(error,@"Truncated load command")!=nil;struct load_command *cmd=(void *)(bytes+position);if(cmd->cmdsize<8||cmd->cmdsize%8||cmd->cmdsize>end-position)return HLMachOFail(error,@"Invalid load command")!=nil;
  NSMutableData *copy=[[image subdataWithRange:NSMakeRange(position,cmd->cmdsize)] mutableCopy];
  if(cmd->cmd==LC_SEGMENT_64){if(cmd->cmdsize<sizeof(struct segment_command_64))return NO;struct segment_command_64 *segment=(void *)cmd;if(sizeof(*segment)+(uint64_t)segment->nsects*sizeof(struct section_64)>cmd->cmdsize)return NO;if(segment->fileoff&&segment->filesize)firstData=MIN(firstData,segment->fileoff);
   struct section_64 *sections=(void *)(segment+1);for(uint32_t j=0;j<segment->nsects;j++){uint32_t type=sections[j].flags&SECTION_TYPE;if(sections[j].offset&&sections[j].size&&type!=S_ZEROFILL&&type!=S_GB_ZEROFILL&&type!=S_THREAD_LOCAL_ZEROFILL)firstData=MIN(firstData,sections[j].offset);}
  }
  if(cmd->cmd==LC_LOAD_DYLIB||cmd->cmd==LC_LOAD_WEAK_DYLIB||cmd->cmd==LC_REEXPORT_DYLIB||cmd->cmd==LC_LOAD_UPWARD_DYLIB){
   if(cmd->cmdsize<sizeof(struct dylib_command))return NO;struct dylib_command *d=(void *)cmd;uint32_t offset=d->dylib.name.offset;if(offset<sizeof(*d)||offset>=cmd->cmdsize)return NO;const char *name=(char *)cmd+offset;size_t count=strnlen(name,cmd->cmdsize-offset);if(count==cmd->cmdsize-offset)return NO;NSString *old=[[NSString alloc]initWithBytes:name length:count encoding:NSUTF8StringEncoding];NSString *replacement=old?imports[old]:nil;
   if(replacement){NSData *text=[replacement dataUsingEncoding:NSUTF8StringEncoding];if(!text.length||memchr(text.bytes,0,text.length)||text.length>UINT32_MAX-offset-8)return NO;NSUInteger size=MAX(copy.length,(offset+text.length+1+7)&~(NSUInteger)7);copy.length=size;struct dylib_command *changed=copy.mutableBytes;changed->cmdsize=(uint32_t)size;memset((uint8_t *)copy.mutableBytes+offset,0,size-offset);memcpy((uint8_t *)copy.mutableBytes+offset,text.bytes,text.length);[matched addObject:old];}
  }
  if(cmd->cmd==LC_RPATH){if(cmd->cmdsize<sizeof(struct rpath_command))return NO;struct rpath_command *r=(void *)cmd;uint32_t offset=r->path.offset;if(offset<sizeof(*r)||offset>=cmd->cmdsize)return NO;const char *name=(char *)cmd+offset;size_t count=strnlen(name,cmd->cmdsize-offset);if(count==cmd->cmdsize-offset)return NO;NSString *old=[[NSString alloc]initWithBytes:name length:count encoding:NSUTF8StringEncoding];if(!old)return NO;NSString *updated=[old stringByReplacingOccurrencesOfString:@"@executable_path/../" withString:@"@executable_path/Mac/Contents/"];if([updated isEqual:@"@executable_path/Frameworks"])hasFrameworkRpath=YES;
   if(![old isEqual:updated]){NSData *text=[updated dataUsingEncoding:NSUTF8StringEncoding];NSUInteger size=MAX(copy.length,(offset+text.length+1+7)&~(NSUInteger)7);copy.length=size;((struct rpath_command *)copy.mutableBytes)->cmdsize=(uint32_t)size;memset((uint8_t *)copy.mutableBytes+offset,0,size-offset);memcpy((uint8_t *)copy.mutableBytes+offset,text.bytes,text.length);}}
  [commands appendData:copy];position+=cmd->cmdsize;
 }
 if(!hasFrameworkRpath){NSData *text=[@"@executable_path/Frameworks" dataUsingEncoding:NSUTF8StringEncoding];NSUInteger size=(sizeof(struct rpath_command)+text.length+1+7)&~(NSUInteger)7;NSMutableData *entry=[NSMutableData dataWithLength:size];struct rpath_command *r=entry.mutableBytes;r->cmd=LC_RPATH;r->cmdsize=(uint32_t)size;r->path.offset=sizeof(*r);memcpy((uint8_t *)entry.mutableBytes+sizeof(*r),text.bytes,text.length);[commands appendData:entry];extraCommands=1;}
 if(position!=end||matched.count!=imports.count||commands.length>UINT32_MAX||32+commands.length>firstData)return HLMachOFail(error,@"Dependency commands exceed header padding or mapping does not match")!=nil;
 uint64_t newEnd=32+commands.length;if(newEnd>end)for(uint64_t i=end;i<newEnd;i++)if(bytes[i])return HLMachOFail(error,@"Header expansion would overwrite nonzero data")!=nil;
 memset(bytes+32,0,MAX(end,newEnd)-32);memcpy(bytes+32,commands.bytes,commands.length);header->sizeofcmds=(uint32_t)commands.length;header->ncmds+=extraCommands;return YES;
}
NSData *HLConvertMacMachO(NSData *input,NSDictionary<NSString *,NSString *> *imports,NSDictionary<NSString *,NSString *> *aliases,NSError **error){
 if(input.length<32)return HLMachOFail(error,@"Truncated Mach-O input.");const uint8_t *raw=input.bytes;uint64_t start=0,length=input.length;uint32_t fat=HLBE32(raw);
 if(fat==0xcafebabe||fat==0xcafebabf){uint32_t count=HLBE32(raw+4);uint64_t stride=fat==0xcafebabe?20:32;if(count>64||8+(uint64_t)count*stride>input.length)return HLMachOFail(error,@"Invalid universal architecture table.");BOOL found=NO;
  for(uint32_t i=0;i<count;i++){const uint8_t *arch=raw+8+i*stride;if(HLBE32(arch)!=(uint32_t)CPU_TYPE_ARM64||((HLBE32(arch+4)&0x00ffffff)!=CPU_SUBTYPE_ARM64_ALL))continue;if(found)return HLMachOFail(error,@"Ambiguous ARM64 slices.");start=fat==0xcafebabe?HLBE32(arch+8):HLBE64(arch+8);length=fat==0xcafebabe?HLBE32(arch+12):HLBE64(arch+16);found=YES;}
  if(!found||start>input.length||length>input.length-start||length<32)return HLMachOFail(error,@"Missing or invalid ARM64 slice.");
 }
 NSMutableData *output=[[input subdataWithRange:NSMakeRange((NSUInteger)start,(NSUInteger)length)] mutableCopy];uint8_t *bytes=output.mutableBytes;struct mach_header_64 *h=(void *)bytes;
 if(h->magic!=MH_MAGIC_64||h->cputype!=CPU_TYPE_ARM64||(h->cpusubtype&0x00ffffff)!=CPU_SUBTYPE_ARM64_ALL)return HLMachOFail(error,@"Expected ordinary little-endian ARM64 Mach-O.");
 if(!HLRewriteDependencies(output,imports,error))return nil;
 uint64_t end=sizeof(*h)+(uint64_t)h->sizeofcmds;if(end>output.length||h->ncmds>h->sizeofcmds/8)return HLMachOFail(error,@"Invalid Mach-O load-command region.");uint64_t position=sizeof(*h),linkStart=0,linkEnd=0;BOOL platform=NO;
 for(uint32_t i=0;i<h->ncmds;i++){
  if(position+8>end)return HLMachOFail(error,@"Truncated load command.");struct load_command *cmd=(void *)(bytes+position);if(cmd->cmdsize<8||cmd->cmdsize%8||cmd->cmdsize>end-position)return HLMachOFail(error,@"Invalid load-command length.");
  if(cmd->cmd==LC_BUILD_VERSION){if(platform||cmd->cmdsize<sizeof(struct build_version_command))return HLMachOFail(error,@"Invalid build version.");struct build_version_command *build=(void *)cmd;if(build->platform!=1||sizeof(*build)+(uint64_t)build->ntools*8>cmd->cmdsize)return HLMachOFail(error,@"Expected an original macOS build version.");build->platform=2;build->minos=17<<16;build->sdk=27<<16;platform=YES;}
  if(cmd->cmd==LC_VERSION_MIN_MACOSX)return HLMachOFail(error,@"Legacy deployment command requires a separate converter.");
  if(cmd->cmd==LC_SEGMENT_64){if(cmd->cmdsize<sizeof(struct segment_command_64))return HLMachOFail(error,@"Truncated segment command.");struct segment_command_64 *segment=(void *)cmd;if(sizeof(*segment)+(uint64_t)segment->nsects*sizeof(struct section_64)>cmd->cmdsize)return HLMachOFail(error,@"Truncated section table.");if(segment->fileoff>output.length||segment->filesize>output.length-segment->fileoff)return HLMachOFail(error,@"Segment extends outside file.");if(!strncmp(segment->segname,"__LINKEDIT",16)){if(linkEnd)return HLMachOFail(error,@"Duplicate LINKEDIT segment.");linkStart=segment->fileoff;linkEnd=linkStart+segment->filesize;}}
  position+=cmd->cmdsize;
 }
 if(position!=end||!platform )return HLMachOFail(error,@"Missing build version.");
 for(NSString *old in aliases){NSString *new=aliases[old];NSData *a=[old dataUsingEncoding:NSUTF8StringEncoding],*b=[new dataUsingEncoding:NSUTF8StringEncoding];if(!a.length||a.length!=b.length||memchr(a.bytes,0,a.length)||memchr(b.bytes,0,b.length)||linkEnd<=linkStart)return HLMachOFail(error,@"Invalid equal-length import alias.");NSUInteger count=0;
  for(uint64_t at=0;at+a.length<output.length;at++)if(!memcmp(bytes+at,a.bytes,a.length)&&bytes[at+a.length]==0){if(at<linkStart||at+a.length+1>linkEnd)return HLMachOFail(error,@"Alias found outside LINKEDIT.");memcpy(bytes+at,b.bytes,b.length);count++;at+=a.length;}
  if(count!=2)return HLMachOFail(error,@"Unexpected number of import alias records.");
 }
 return output;
}
