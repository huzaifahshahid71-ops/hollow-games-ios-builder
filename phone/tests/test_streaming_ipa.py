#!/usr/bin/env python3
"""Cross-check native ZIP writer against Python's independent ZIP reader (Mac/Xcode)."""
from pathlib import Path
import tempfile,subprocess,zipfile,os
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='hollow-ipa-test-') as temp:
 work=Path(temp);driver=work/'driver.m'
 driver.write_text('''#import <Foundation/Foundation.h>
extern BOOL HLWriteIPAFromDirectory(NSURL *,NSURL *,void(^)(NSUInteger,unsigned long long),NSError **);
int main(int argc,char **argv){@autoreleasepool{NSError *e=nil;return HLWriteIPAFromDirectory([NSURL fileURLWithPath:@(argv[1]) isDirectory:YES],[NSURL fileURLWithPath:@(argv[2])],nil,&e)?0:1;}}
''')
 executable=work/'test';subprocess.run(['xcrun','--sdk','macosx','clang','-fobjc-arc','-framework','Foundation','-lz',str(ROOT/'Sources/IPAWriter.m'),str(driver),'-o',str(executable)],check=True)
 app=work/'Test.app';(app/'nested').mkdir(parents=True)
 for name,data in {'empty':b'','repeat':b'game assets'*200000,'nested/ü.dat':os.urandom(200000),'runner':b'project authored placeholder'}.items():(app/name).write_bytes(data)
 (app/'runner').chmod(0o755);archive=work/'test.ipa'
 subprocess.run([str(executable),str(app),str(archive)],check=True)
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for file in app.rglob('*'):
   if file.is_file():assert z.read('Payload/Test.app/'+file.relative_to(app).as_posix())==file.read_bytes()
  assert (z.getinfo('Payload/Test.app/runner').external_attr>>16)&0o777==0o755
 (app/'link').symlink_to('/etc/hosts');bad=work/'bad.ipa'
 assert subprocess.run([str(executable),str(app),str(bad)]).returncode!=0 and not bad.exists()
 assert subprocess.run([str(executable),str(app),str(app/'inside.ipa')]).returncode!=0
 assert not list(work.glob('*.partial'))
print('Native streaming IPA cross-checks passed.')
