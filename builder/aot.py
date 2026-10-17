"""Generate native companions with the exact Mono shipped in the user's game."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import os
import shutil
import struct
from xml.sax.saxutils import escape
from .common import ROOT, run, write_json

FLAGS = 'full,interp,nopagetrampolines,asmonly'
POOLS = ',ntrampolines=65536,nrgctx-trampolines=16384,nimt-trampolines=8192,nunbox-arbitrary-trampolines=8192'


def filter_core(original, destination):
    import dnfile
    data = bytearray(original.read_bytes())
    pe = dnfile.dnPE(str(original))
    changes = []
    for t in pe.net.mdtables.TypeDef:
        if str(t.TypeName) == 'UnsafeUtility' and str(t.TypeNamespace) == 'Unity.Collections.LowLevel.Unsafe':
            for index in t.MethodList:
                method = index.row
                if str(method.Name) == 'EnumEquals':
                    off = method.struct.get_field_absolute_offset('Flags')
                    old = struct.unpack_from('<H', data, off)[0]
                    struct.pack_into('<H', data, off, old | 0x400)
                    changes.append({'offset': off, 'before': old, 'after': old | 0x400})
    pe.close()
    if len(changes) != 1:
        raise ValueError('Unknown CoreModule layout; compiler-only workaround refused')
    destination.write_bytes(data)
    return changes


def type_bridge(assembly):
    guard = json.loads((ROOT / 'native/type_bridge_guard.json').read_text())
    text = assembly.read_text()
    i = text.index(guard['method']) + len(guard['method'])
    j = text.index('\nLme_', i)
    if hashlib.sha256(text[i:j].encode()).hexdigest() != guard['generated_body_sha256']:
        raise ValueError('Unexpected Mono-generated type dispatch; refusing bridge')
    body = '''
stp x29, x30, [sp, #-0x30]!
mov x29, sp
stp x23, x24, [x29, #0x10]
stp x25, x26, [x29, #0x20]
bl _SilksongTypeAssignable
ldp x23, x24, [x29, #0x10]
ldp x25, x26, [x29, #0x20]
ldp x29, x30, [sp], #0x30
ret
'''
    assembly.write_text(text[:i] + body + text[j:])


def build(app, source, work, profile, csc=None, jobs=2):
    aot = work / 'aot'
    aot.mkdir(exist_ok=True)
    filtered = aot / 'compiler-filter'
    filtered.mkdir(exist_ok=True)
    original = source / 'Contents/Resources/Data/Managed'
    destination = app / 'Mac/Contents/Resources/Data/Managed'
    env = dict(os.environ, MONO_PATH=str(filtered) + ':' + str(aot) + ':' + str(original))
    runtime = aot / 'mono-compiler.dylib'
    if not runtime.exists():
        run(['lipo', source / 'Contents/Frameworks/libmonobdwgc-2.0.dylib', '-thin', 'arm64', '-output', runtime])
        run(['codesign', '-f', '-s', '-', runtime])
    host = aot / 'mono_host'
    run(['xcrun', '--sdk', 'macosx', 'clang', ROOT / 'native/mono_host.c', '-o', host])
    fix = aot / 'libAOTOptionFix.dylib'
    run(['xcrun', '--sdk', 'macosx', 'clang', '-dynamiclib', ROOT / 'native/aot_option_fix.c', '-o', fix])
    env['DYLD_INSERT_LIBRARIES'] = str(fix)  # Host compiler only. Never copied into the IPA.
    changes = filter_core(original / 'UnityEngine.CoreModule.dll', filtered / 'UnityEngine.CoreModule.dll')
    write_json(aot / 'compiler-filter-report.json', changes)
    sources = sorted(original.glob('*.dll'))
    if profile['id'] == 'hollow-knight':
        if not csc or not (csc / 'csc.exe').is_file():
            raise ValueError('Hollow Knight requires --csc-directory (see README / fetch-tools command)')
        config = aot / 'host-mono.config'
        frameworks = source / 'Contents/Frameworks'
        config.write_text('<configuration>' + ''.join(
            f'<dllmap dll="{name}" target="{escape(str(frameworks / target), {chr(34): "&quot;"})}"/>'
            for name, target in [('System.Native', 'libmono-native.dylib'), ('mono-native', 'libmono-native.dylib'),
                                 ('MonoPosixHelper', 'libMonoPosixHelper.dylib')]) + '</configuration>')
        bridge = aot / 'HKInputBridge.dll'
        command = [host, runtime, '--config', config, csc / 'csc.exe', '-nologo', '-noconfig', '-nostdlib',
                   '-target:library', '-out:' + str(bridge)]
        for name in ['mscorlib.dll', 'System.dll', 'System.Core.dll', 'netstandard.dll',
                     'UnityEngine.CoreModule.dll', 'Unity.InputSystem.dll']:
            command.append('-r:' + str(original / name))
        command.append(ROOT / 'native/HKInputBridge.cs')
        compile_env = dict(env, MONO_PATH=str(csc) + ':' + str(original))
        run(command, env=compile_env, log=aot / 'bridge-compile.log')
        shutil.copy2(bridge, destination / bridge.name)
        sources.append(bridge)

    def one(source_dll):
        name = source_dll.name
        if name in profile['interpreted_only']:
            return {'assembly': name, 'status': 'interpreted-only (known compiler limitation)'}
        staged = filtered / name if name == 'UnityEngine.CoreModule.dll' else aot / name
        if staged != source_dll and staged.parent != filtered:
            shutil.copy2(source_dll, staged)
        target = destination / (name + '.dylib')
        flags = FLAGS
        if name == 'mscorlib.dll':
            flags += POOLS
            if profile['id'] == 'silksong':
                flags += ',ngsharedvt-trampolines=32768,nftnptr-arg-trampolines=8192'
        run([host, runtime, '--aot=' + flags, staged], env=env, log=aot / (name + '.compile.log'))
        assembly = Path(str(staged) + '.s')
        extra = []
        if name == 'mscorlib.dll' and profile['id'] == 'silksong':
            type_bridge(assembly)
            extra = [ROOT / 'native/type_dispatch.c']
        run(['xcrun', '--sdk', 'iphoneos', 'clang', '-target', 'arm64-apple-ios17.0', '-dynamiclib',
             '-Wl,-undefined,dynamic_lookup', '-install_name', '@rpath/' + target.name,
             assembly, *extra, '-o', target], log=aot / (name + '.link.log'))
        print('Native helper: ' + name, flush=True)
        return {'assembly': name, 'status': 'built', 'flags': flags, 'bytes': target.stat().st_size}

    # Core first; bounded parallelism for the independent modules that follow.
    rows = [one(original / 'mscorlib.dll')]
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        rows.extend(pool.map(one, [p for p in sources if p.name != 'mscorlib.dll']))
    write_json(work / 'aot-report.json', rows)
    return rows
