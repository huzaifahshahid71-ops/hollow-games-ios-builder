#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "../Vendor/lz4/lz4.h"
#import "../Vendor/lz4/lz4hc.h"
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#define HL_UNITY_BLOCK 131072
#define HL_UNITY_MAX_INFO (32*1024*1024)
static BOOL HLUFail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"HollowUnityArchive" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return NO;}
static void HLUBE16(NSMutableData *data,uint16_t value){uint8_t b[]={value>>8,value&255};[data appendBytes:b length:2];}
static void HLUBE32(NSMutableData *data,uint32_t value){HLUBE16(data,value>>16);HLUBE16(data,value&65535);}
static void HLUBE64(NSMutableData *data,uint64_t value){HLUBE32(data,(uint32_t)(value>>32));HLUBE32(data,(uint32_t)value);}
static uint16_t HLURead16(const uint8_t *b){return (uint16_t)b[0]<<8|b[1];}
static uint32_t HLURead32(const uint8_t *b){return (uint32_t)HLURead16(b)<<16|HLURead16(b+2);}
static uint64_t HLURead64(const uint8_t *b){return (uint64_t)HLURead32(b)<<32|HLURead32(b+4);}
static BOOL HLUWrite(FILE *file,const void *bytes,size_t size){return !size||fwrite(bytes,1,size,file)==size;}
static NSData *HLUFileHash(NSString *path){FILE *file=fopen(path.fileSystemRepresentation,"rb");if(!file)return nil;CC_SHA256_CTX hash;CC_SHA256_Init(&hash);uint8_t bytes[65536];size_t size;while((size=fread(bytes,1,sizeof(bytes),file)))CC_SHA256_Update(&hash,bytes,(CC_LONG)size);BOOL okay=!ferror(file);fclose(file);if(!okay)return nil;uint8_t digest[32];CC_SHA256_Final(digest,&hash);return [NSData dataWithBytes:digest length:32];}
static BOOL HLUWriteBlock(FILE *file,const uint8_t *raw,int size,void *state,uint8_t *packed,NSMutableData *records){
 int compressed=LZ4_compress_HC_extStateHC(state,(const char *)raw,(char *)packed,size,LZ4_compressBound(HL_UNITY_BLOCK),12);if(compressed<=0)return NO;BOOL use=compressed<size;HLUBE32(records,size);HLUBE32(records,use?compressed:size);HLUBE16(records,use?3:0);return HLUWrite(file,use?packed:raw,use?compressed:size);
}
static BOOL HLUFinishNodes(NSArray *nodes,NSUInteger *index,uint64_t *remaining,CC_SHA256_CTX *hash){
 while(*index<nodes.count&&!*remaining){uint8_t digest[32];CC_SHA256_Final(digest,hash);NSDictionary *node=nodes[*index];NSData *actual=[NSData dataWithBytes:digest length:32];if(![actual isEqual:node[@"sha256"]]||![actual isEqual:HLUFileHash(node[@"source"])])return NO;(*index)++;CC_SHA256_Init(hash);if(*index<nodes.count)*remaining=[nodes[*index][@"size"] unsignedLongLongValue];}return YES;
}
// Independent read-back path parses metadata from disk and hashes decoded bytes per node.
static BOOL HLUVerifyArchive(NSString *path,NSArray *nodes,NSError **error){
 FILE *file=fopen(path.fileSystemRepresentation,"rb");if(!file)return HLUFail(error,@"Cannot open archive for verification.");BOOL okay=YES;uint8_t header[512];size_t got=fread(header,1,sizeof(header),file);NSUInteger cursor=8;
 if(got<64||memcmp(header,"UnityFS\0",8)||HLURead32(header+cursor)!=8){fclose(file);return HLUFail(error,@"Invalid UnityFS header.");}cursor+=4;
 for(int i=0;i<2;i++){while(cursor<got&&header[cursor])cursor++;if(cursor>=got){okay=NO;break;}cursor++;}
 if(cursor+20>got)okay=NO;uint64_t total=0;uint32_t packedSize=0,infoSize=0,flags=0;
 if(okay){total=HLURead64(header+cursor);packedSize=HLURead32(header+cursor+8);infoSize=HLURead32(header+cursor+12);flags=HLURead32(header+cursor+16);cursor=(cursor+20+15)&~(NSUInteger)15;if(fseeko(file,0,SEEK_END)||ftello(file)<0||(uint64_t)ftello(file)!=total||!packedSize||!infoSize||infoSize>HL_UNITY_MAX_INFO||packedSize>HL_UNITY_MAX_INFO||total<packedSize||total-packedSize<cursor||flags!=0xc3)okay=NO;}
 NSMutableData *packed=nil,*info=nil;
 if(okay){packed=[NSMutableData dataWithLength:packedSize];info=[NSMutableData dataWithLength:infoSize];if(fseeko(file,total-packedSize,SEEK_SET)||fread(packed.mutableBytes,1,packedSize,file)!=packedSize||LZ4_decompress_safe(packed.bytes,info.mutableBytes,(int)packedSize,(int)infoSize)!=(int)infoSize)okay=NO;}
 uint32_t blocks=0;NSUInteger at=20;const uint8_t *meta=info.bytes;
 if(okay){if(infoSize<24)okay=NO;else {blocks=HLURead32(meta+16);if((uint64_t)blocks*10+24>infoSize)okay=NO;else at=20+(NSUInteger)blocks*10;}}
 if(okay){uint32_t count=HLURead32(meta+at);at+=4;if(count!=nodes.count)okay=NO;
  for(NSUInteger i=0;okay&&i<nodes.count;i++){if(at+20>infoSize){okay=NO;break;}NSDictionary *node=nodes[i];uint64_t offset=HLURead64(meta+at),size=HLURead64(meta+at+8);uint32_t nodeFlags=HLURead32(meta+at+16);at+=20;NSUInteger begin=at;while(at<infoSize&&meta[at])at++;if(at>=infoSize){okay=NO;break;}NSString *name=[[NSString alloc]initWithBytes:meta+begin length:at-begin encoding:NSUTF8StringEncoding];at++;if(offset!=[node[@"offset"] unsignedLongLongValue]||size!=[node[@"size"] unsignedLongLongValue]||nodeFlags!=[node[@"flags"] unsignedIntValue]||![name isEqual:node[@"name"]])okay=NO;}
  if(at!=infoSize)okay=NO;
 }
 uint8_t *input=malloc(LZ4_compressBound(HL_UNITY_BLOCK)),*raw=malloc(HL_UNITY_BLOCK);if(!input||!raw)okay=NO;
 if(okay&&fseeko(file,cursor,SEEK_SET))okay=NO;NSUInteger nodeIndex=0;uint64_t remaining=nodes.count?[nodes[0][@"size"] unsignedLongLongValue]:0;CC_SHA256_CTX hash;CC_SHA256_Init(&hash);if(okay&&!HLUFinishNodes(nodes,&nodeIndex,&remaining,&hash))okay=NO;
 for(uint32_t i=0;okay&&i<blocks;i++){const uint8_t *record=meta+20+(NSUInteger)i*10;uint32_t usize=HLURead32(record),csize=HLURead32(record+4);uint16_t type=HLURead16(record+8);off_t position=ftello(file);
  if(!usize||usize>HL_UNITY_BLOCK||!csize||csize>(uint32_t)LZ4_compressBound(HL_UNITY_BLOCK)||position<0||(uint64_t)position>total-packedSize||csize>total-packedSize-(uint64_t)position||fread(input,1,csize,file)!=csize){okay=NO;break;}
  if(type==0){if(csize!=usize){okay=NO;break;}memcpy(raw,input,usize);}else if(type==3){if(LZ4_decompress_safe((char *)input,(char *)raw,csize,usize)!=(int)usize){okay=NO;break;}}else {okay=NO;break;}
  NSUInteger used=0;while(okay&&used<usize){if(nodeIndex>=nodes.count){okay=NO;break;}NSUInteger take=(NSUInteger)MIN(remaining,(uint64_t)usize-used);CC_SHA256_Update(&hash,raw+used,(CC_LONG)take);used+=take;remaining-=take;if(!HLUFinishNodes(nodes,&nodeIndex,&remaining,&hash))okay=NO;}
 }
 if(okay&&(nodeIndex!=nodes.count||(uint64_t)ftello(file)!=total-packedSize))okay=NO;free(input);free(raw);fclose(file);return okay?YES:HLUFail(error,@"Lossless Unity archive verification failed; originals were preserved.");
}
BOOL HLBuildHollowKnightDataArchive(NSURL *sourceData,NSURL *destination,void(^progress)(NSUInteger,NSUInteger,unsigned long long),NSDictionary **report,NSError **error){
 NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[sourceData URLByResolvingSymlinksInPath].path,*target=[destination URLByResolvingSymlinksInPath].path;
 if([target isEqual:root]||[target hasPrefix:[root stringByAppendingString:@"/"]])return HLUFail(error,@"Archive output must be outside the original Data folder.");
 NSArray *children=[fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:root isDirectory:YES] includingPropertiesForKeys:nil options:0 error:error];if(!children)return NO;NSMutableArray *names=[NSMutableArray new];
 for(NSURL *file in children){NSString *name=file.lastPathComponent;if(![name.pathExtension isEqual:@"resource"]&&([name hasPrefix:@"level"]||[name hasPrefix:@"sharedassets"]||[name hasPrefix:@"resources.assets"]||[name hasPrefix:@"globalgamemanagers"]))[names addObject:name];}
 NSString *builtin=@"Resources/unity_builtin_extra";if([fm fileExistsAtPath:[root stringByAppendingPathComponent:builtin]])[names addObject:builtin];[names sortUsingComparator:^NSComparisonResult(NSString *a,NSString *b){return [a compare:b options:NSLiteralSearch];}];
 if(!names.count||names.count>100000||[fm fileExistsAtPath:[root stringByAppendingPathComponent:@"data.unity3d"]])return HLUFail(error,@"Expected original loose Hollow Knight Data files.");
 NSMutableArray *nodes=[NSMutableArray new];uint64_t offset=0;
 for(NSString *name in names){NSString *path=[root stringByAppendingPathComponent:name];NSDictionary *attrs=[fm attributesOfItemAtPath:path error:error];uint64_t size=[attrs[NSFileSize] unsignedLongLongValue];if(!attrs||![attrs[NSFileType] isEqual:NSFileTypeRegular]||![[NSURL fileURLWithPath:path].URLByResolvingSymlinksInPath.path hasPrefix:[root stringByAppendingString:@"/"]]||size>INT64_MAX-offset)return HLUFail(error,@"Invalid, changed or escaping asset input.");BOOL serialized=[name.pathExtension isEqual:@"assets"]||(([name hasPrefix:@"level"]||[name hasPrefix:@"globalgamemanagers"])&&![name.pathExtension isEqual:@"resS"]);[nodes addObject:[@{@"source":path,@"name":name,@"size":@(size),@"offset":@(offset),@"flags":@(serialized?4:0)} mutableCopy]];offset+=size;}
 NSString *temporary=[target stringByAppendingFormat:@".%@.partial",NSUUID.UUID.UUIDString];FILE *file=fopen(temporary.fileSystemRepresentation,"wbx");if(!file)return HLUFail(error,@"Could not create archive working file.");NSDate *started=NSDate.date;NSMutableData *header=[NSMutableData dataWithBytes:"UnityFS\0" length:8];HLUBE32(header,8);[header appendBytes:"6000.0.61f1\0" length:12];[header appendBytes:"6000.0.61f1\0" length:12];NSUInteger patch=header.length;[header increaseLengthBy:20];[header increaseLengthBy:(16-header.length%16)%16];
 NSMutableData *records=[NSMutableData new];uint8_t *buffer=malloc(HL_UNITY_BLOCK),*packed=malloc(LZ4_compressBound(HL_UNITY_BLOCK));void *state=malloc(LZ4_sizeofStateHC());BOOL okay=buffer&&packed&&state&&HLUWrite(file,header.bytes,header.length);NSUInteger filled=0,finished=0;uint64_t processed=0;
 for(NSMutableDictionary *node in nodes){if(!okay)break;FILE *input=fopen([node[@"source"] fileSystemRepresentation],"rb");if(!input){okay=NO;break;}CC_SHA256_CTX hash;CC_SHA256_Init(&hash);uint64_t readBytes=0;
  while(okay){size_t got=fread(buffer+filled,1,HL_UNITY_BLOCK-filled,input);if(ferror(input)){okay=NO;break;}if(got){CC_SHA256_Update(&hash,buffer+filled,(CC_LONG)got);readBytes+=got;processed+=got;filled+=got;}if(filled==HL_UNITY_BLOCK){okay=HLUWriteBlock(file,buffer,(int)filled,state,packed,records);filled=0;}if(!got)break;}
  fclose(input);uint8_t digest[32];CC_SHA256_Final(digest,&hash);node[@"sha256"]=[NSData dataWithBytes:digest length:32];if(readBytes!=[node[@"size"] unsignedLongLongValue])okay=NO;finished++;if(progress)progress(finished,nodes.count,processed);
 }
 if(okay&&filled)okay=HLUWriteBlock(file,buffer,(int)filled,state,packed,records);NSMutableData *info=[NSMutableData dataWithLength:16];HLUBE32(info,(uint32_t)(records.length/10));[info appendData:records];HLUBE32(info,(uint32_t)nodes.count);
 for(NSDictionary *node in nodes){HLUBE64(info,[node[@"offset"] unsignedLongLongValue]);HLUBE64(info,[node[@"size"] unsignedLongLongValue]);HLUBE32(info,[node[@"flags"] unsignedIntValue]);NSData *name=[node[@"name"] dataUsingEncoding:NSUTF8StringEncoding];[info appendData:name];uint8_t zero=0;[info appendBytes:&zero length:1];}
 uint64_t total=0;int infoCompressed=0;
 if(okay){if(info.length>HL_UNITY_MAX_INFO)okay=NO;else {int bound=LZ4_compressBound((int)info.length);NSMutableData *output=[NSMutableData dataWithLength:bound];infoCompressed=LZ4_compress_HC_extStateHC(state,info.bytes,output.mutableBytes,(int)info.length,bound,12);if(infoCompressed<=0||!HLUWrite(file,output.bytes,infoCompressed)||ftello(file)<0)okay=NO;else {total=(uint64_t)ftello(file);NSMutableData *fields=[NSMutableData new];HLUBE64(fields,total);HLUBE32(fields,(uint32_t)infoCompressed);HLUBE32(fields,(uint32_t)info.length);HLUBE32(fields,0xc3);if(fseeko(file,patch,SEEK_SET)||!HLUWrite(file,fields.bytes,fields.length))okay=NO;}}}
 free(buffer);free(packed);free(state);if(fclose(file))okay=NO;
 if(okay)okay=HLUVerifyArchive(temporary,nodes,error);
 if(okay&&rename(temporary.fileSystemRepresentation,target.fileSystemRepresentation))okay=NO;
 if(!okay){[fm removeItemAtPath:temporary error:nil];if(error&&!*error)HLUFail(error,@"Could not build lossless data archive; originals were preserved.");return NO;}
 if(report){NSMutableArray *entries=[NSMutableArray new];for(NSDictionary *node in nodes)[entries addObject:@{@"name":node[@"name"],@"bytes":node[@"size"]}];*report=@{@"nodes":@(nodes.count),@"blocks":@(records.length/10),@"original_bytes":@(offset),@"archive_bytes":@(total),@"all_nodes_sha256_identical":@YES,@"elapsed_seconds":@(-started.timeIntervalSinceNow),@"included_files":entries,@"format":@"UnityFS8 / LZ4HC12 / 128 KiB"};}return YES;
}
