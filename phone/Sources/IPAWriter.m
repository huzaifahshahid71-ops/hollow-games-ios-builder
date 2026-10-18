#import <Foundation/Foundation.h>
#import <zlib.h>
#import <sys/stat.h>
#import <stdio.h>
#import <errno.h>
// Streaming ZIP32 writer. Final archive/individual entries must remain below 4 GiB.
// File data is never accumulated in memory. Caller retains source-folder access.
static BOOL HLZipFail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"HollowIPA" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return NO;}
static BOOL HLBytes(FILE *f,const void *bytes,size_t count){return !count||fwrite(bytes,1,count,f)==count;}
static BOOL HLU16F(FILE *f,uint16_t v){uint8_t b[]={v&255,v>>8};return HLBytes(f,b,2);}
static BOOL HLU32F(FILE *f,uint32_t v){return HLU16F(f,v&65535)&&HLU16F(f,v>>16);}
BOOL HLWriteIPAFromDirectory(NSURL *app,NSURL *destination,void(^progress)(NSUInteger,unsigned long long),NSError **error){
 NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[app URLByResolvingSymlinksInPath].path,*output=[destination URLByResolvingSymlinksInPath].path;
 if([output hasPrefix:[root stringByAppendingString:@"/"]]||[output isEqual:root])return HLZipFail(error,@"IPA destination must be outside the app folder.");
 NSString *temporary=[output stringByAppendingFormat:@".%@.partial",NSUUID.UUID.UUIDString];FILE *zip=fopen(temporary.fileSystemRepresentation,"wbx");if(!zip)return HLZipFail(error,@"Could not create temporary IPA.");
 NSMutableArray *central=[NSMutableArray new];BOOL okay=YES;unsigned long long processed=0;__block NSError *walkError=nil;
 NSDirectoryEnumerator *walker=[fm enumeratorAtURL:[NSURL fileURLWithPath:root isDirectory:YES] includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url,NSError *failure){walkError=failure;return NO;}];
 if(!walker){fclose(zip);[fm removeItemAtPath:temporary error:nil];return HLZipFail(error,@"Could not enumerate app folder.");}
 for(NSURL *file in walker){@autoreleasepool{
  NSDictionary *attrs=[fm attributesOfItemAtPath:file.path error:&walkError];if(!attrs){okay=NO;break;}
  NSString *type=attrs[NSFileType];if([type isEqual:NSFileTypeDirectory])continue;
  if(![type isEqual:NSFileTypeRegular]){walkError=[NSError errorWithDomain:@"HollowIPA" code:2 userInfo:@{NSLocalizedDescriptionKey:@"App must contain regular files and directories only; flatten framework symlinks before packaging."}];okay=NO;break;}
  NSString *resolved=[file URLByResolvingSymlinksInPath].path;if(![resolved hasPrefix:[root stringByAppendingString:@"/"]]){okay=NO;break;}
  NSString *relative=[[resolved substringFromIndex:root.length+1] precomposedStringWithCanonicalMapping];NSString *entry=[NSString stringWithFormat:@"Payload/%@/%@",app.lastPathComponent,relative];NSData *name=[entry dataUsingEncoding:NSUTF8StringEncoding];
  off_t at=ftello(zip);if(at<0||(uint64_t)at>=UINT32_MAX||name.length>UINT16_MAX||central.count>=UINT16_MAX||[attrs[NSFileSize] unsignedLongLongValue]>=UINT32_MAX){okay=NO;break;}
  uint32_t offset=(uint32_t)at;
  okay=HLU32F(zip,0x04034b50)&&HLU16F(zip,20)&&HLU16F(zip,0x808)&&HLU16F(zip,8)&&HLU16F(zip,0)&&HLU16F(zip,33)&&HLU32F(zip,0)&&HLU32F(zip,0)&&HLU32F(zip,0)&&HLU16F(zip,(uint16_t)name.length)&&HLU16F(zip,0)&&HLBytes(zip,name.bytes,name.length);if(!okay)break;
  FILE *input=fopen(file.path.fileSystemRepresentation,"rb");if(!input){okay=NO;break;}
  z_stream stream={0};if(deflateInit2(&stream,Z_DEFAULT_COMPRESSION,Z_DEFLATED,-MAX_WBITS,8,Z_DEFAULT_STRATEGY)!=Z_OK){fclose(input);okay=NO;break;}
  uint8_t in[65536],out[65536];uint32_t crc=0;uint64_t raw=0,compressed=0;BOOL finished=NO;
  while(okay&&!finished){size_t got=fread(in,1,sizeof(in),input);if(ferror(input)){okay=NO;break;}raw+=got;if(raw>=UINT32_MAX){okay=NO;break;}crc=(uint32_t)crc32(crc,in,(uInt)got);stream.next_in=in;stream.avail_in=(uInt)got;int flush=feof(input)?Z_FINISH:Z_NO_FLUSH;
   do{stream.next_out=out;stream.avail_out=sizeof(out);int status=deflate(&stream,flush);if(status!=Z_OK&&status!=Z_STREAM_END){okay=NO;break;}size_t n=sizeof(out)-stream.avail_out;compressed+=n;if(compressed>=UINT32_MAX||!HLBytes(zip,out,n)){okay=NO;break;}if(status==Z_STREAM_END){finished=YES;break;}}while(stream.avail_in||stream.avail_out==0||flush==Z_FINISH);
  }
  deflateEnd(&stream);fclose(input);if(!okay)break;
  if(raw!=[attrs[NSFileSize] unsignedLongLongValue]){okay=NO;break;}
  okay=HLU32F(zip,0x08074b50)&&HLU32F(zip,crc)&&HLU32F(zip,(uint32_t)compressed)&&HLU32F(zip,(uint32_t)raw);if(!okay)break;
  [central addObject:@{@"name":name,@"crc":@(crc),@"compressed":@(compressed),@"raw":@(raw),@"offset":@(offset),@"mode":@((0100000|[attrs[NSFilePosixPermissions] unsignedIntValue])<<16)}];processed+=raw;if(progress)progress(central.count,processed);
 }}
 if(walkError)okay=NO;
 off_t directory=ftello(zip);if(directory<0||(uint64_t)directory>=UINT32_MAX)okay=NO;
 if(okay)for(NSDictionary *item in central){NSData *name=item[@"name"];okay=HLU32F(zip,0x02014b50)&&HLU16F(zip,0x314)&&HLU16F(zip,20)&&HLU16F(zip,0x808)&&HLU16F(zip,8)&&HLU16F(zip,0)&&HLU16F(zip,33)&&HLU32F(zip,[item[@"crc"] unsignedIntValue])&&HLU32F(zip,[item[@"compressed"] unsignedIntValue])&&HLU32F(zip,[item[@"raw"] unsignedIntValue])&&HLU16F(zip,(uint16_t)name.length)&&HLU16F(zip,0)&&HLU16F(zip,0)&&HLU16F(zip,0)&&HLU16F(zip,0)&&HLU32F(zip,[item[@"mode"] unsignedIntValue])&&HLU32F(zip,[item[@"offset"] unsignedIntValue])&&HLBytes(zip,name.bytes,name.length);if(!okay)break;}
 off_t end=ftello(zip);if(end<directory||(uint64_t)end>=UINT32_MAX)okay=NO;
 if(okay)okay=HLU32F(zip,0x06054b50)&&HLU16F(zip,0)&&HLU16F(zip,0)&&HLU16F(zip,(uint16_t)central.count)&&HLU16F(zip,(uint16_t)central.count)&&HLU32F(zip,(uint32_t)(end-directory))&&HLU32F(zip,(uint32_t)directory)&&HLU16F(zip,0);
 if(fclose(zip))okay=NO;
 if(okay&&rename(temporary.fileSystemRepresentation,output.fileSystemRepresentation))okay=NO;
 if(!okay){[fm removeItemAtPath:temporary error:nil];return HLZipFail(error,walkError.localizedDescription?:@"IPA writing failed, input changed, or ZIP32 limits were exceeded.");}return YES;
}
