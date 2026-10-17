import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import sys
import urllib.request
import zipfile
from .common import ROOT, run, sha, write_json
from .inputs import inspect, resolve_input

ROSLYN_URL = 'https://api.nuget.org/v3-flatcontainer/microsoft.net.compilers.toolset/4.8.0/microsoft.net.compilers.toolset.4.8.0.nupkg'
ROSLYN_SHA = '37333f4f1e2ce55e621355d6da651dc23d4cb5f94a8f76b9478816e87f110ad9'


def fetch_tools(path):
    path.mkdir(parents=True, exist_ok=True)
    archive = path / 'roslyn-4.8.0.nupkg'
    if not archive.exists():
        print('Downloading Microsoft Roslyn 4.8.0 from NuGet (no game files sent)…', flush=True)
        candidate = archive.with_suffix('.download')
        urllib.request.urlretrieve(ROSLYN_URL, candidate)
        if sha(candidate) != ROSLYN_SHA:
            raise ValueError('Compiler download checksum mismatch')
        os.replace(candidate, archive)
    if sha(archive) != ROSLYN_SHA:
        raise ValueError('Compiler archive checksum mismatch')
    destination = path / 'roslyn'
    destination.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            prefix = 'tasks/net472/'
            if not name.startswith(prefix) or name.endswith('/'):
                continue
            rel = Path(name[len(prefix):])
            if '..' in rel.parts or rel.is_absolute():
                raise ValueError('Unsafe compiler archive member')
            target = destination / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
    print('Compiler ready: ' + str(destination), flush=True)
    return destination


def doctor():
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('Build on an Apple Silicon Mac using an ARM64 Python, not Rosetta.')
    for tool in ['clang', 'lipo', 'vtool', 'dyld_info']:
        run(['xcrun', '--find', tool])
    sdk = run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path']).strip()
    import UnityPy, lz4.block, dnfile  # noqa: F401
    print('Apple Silicon / iPhoneOS SDK / Python dependencies ready: ' + sdk, flush=True)


def icons(app, source, supplied=None):
    icon = supplied or source / 'Contents/Resources/PlayerIcon.icns'
    if icon.is_file():
        for size, name in [(120, 'AppIcon60x60@2x.png'), (180, 'AppIcon60x60@3x.png'), (1024, 'AppIcon1024.png')]:
            run(['sips', '-s', 'format', 'png', '-z', str(size), str(size), icon, '--out', app / name])


def build(args):
    doctor()
    if args.icon:
        args.icon = args.icon.expanduser().resolve()
        if not args.icon.is_file():
            raise ValueError('The custom icon file does not exist')
    if args.controls:
        args.controls = args.controls.expanduser().resolve()
        if not args.controls.is_dir():
            raise ValueError('The controls folder does not exist')
    work = args.work.expanduser().resolve()
    source_path = args.input.expanduser().resolve()
    if work == ROOT or work == source_path or work.is_relative_to(source_path) or source_path.is_relative_to(work):
        raise ValueError('Use a separate work directory outside the input and repository root.')
    work.mkdir(parents=True, exist_ok=True)
    if args.output and args.output.expanduser().resolve().is_relative_to(source_path):
        raise ValueError('Output must be outside the original game folder')
    source = resolve_input(source_path, work)
    profile = inspect(source, args.game)
    key = profile['id']
    print(f'Validated {key} {profile["version"]}: {len(profile["managed_sha256"])} original DLLs', flush=True)
    state_path = work / 'build-state.json'
    identity = {'profile': key, 'version': profile['version'], 'source': str(source),
                'source_native_hashes': profile['native_sha256'], 'builder_version': 1,
                'icon': str(args.icon) if args.icon else None,
                'controls': str(args.controls) if args.controls else None}
    if state_path.exists():
        state = json.loads(state_path.read_text())
        if state['input'] != identity:
            raise ValueError('Work directory belongs to different inputs/options; choose a new directory.')
    else:
        # Partial extraction is acceptable; never adopt arbitrary app/build leftovers.
        if (work / 'Game.app').exists():
            raise ValueError('Untracked build app in work directory; choose a new directory.')
        state = {'input': identity, 'completed': []}
        write_json(state_path, state)
    def step(name, action):
        if name not in state['completed']:
            print('STEP: ' + name, flush=True)
            action()
            state['completed'].append(name)
            write_json(state_path, state)
    converter = ROOT / 'profiles' / key / 'converter'
    app = work / 'Game.app'
    csc = args.csc_directory.expanduser().resolve() if args.csc_directory else None
    if key == 'hollow-knight' and not csc:
        csc = fetch_tools(args.tool_cache.expanduser().resolve())
    step('convert', lambda: run([sys.executable, converter / 'tools/convert_app.py', source, app,
                                 profile['bundle_id'], '--no-controller-replay', '--no-metal-hud'],
                                log=work / 'conversion.log'))
    from .imports import alias
    def imports():
        rows = [alias(app / 'Mac/Contents/Frameworks/libmonobdwgc-2.0.dylib', b'_mmap\0', b'_smmp\0')]
        if key == 'silksong':
            rows.append(alias(app / 'Mac/Contents/Frameworks/libmonobdwgc-2.0.dylib', b'_sigaction\0', b'_SKsigactX\0'))
        else:
            rows.append(alias(app / 'Mac/Contents/Frameworks/UnityPlayer.dylib', b'_dlsym\0', b'_HKsym\0'))
        write_json(work / 'import-aliases.json', rows)
    step('import aliases', imports)
    from .aot import build as build_aot
    step('native companions', lambda: build_aot(app, source, work, profile, csc, args.jobs))
    from .compression import compress
    step('lossless compression', lambda: compress(app / 'Mac/Contents/Resources/Data', key, work / 'compression-report.json'))
    def configure():
        controls = app / 'SilksongControls'
        controls.mkdir(exist_ok=True)
        for p in (ROOT / 'assets' / key).glob('*.png'):
            shutil.copy2(p, controls / p.name)
        if args.controls:
            for p in args.controls.glob('*.png'):
                shutil.copy2(p, controls / p.name)
        icons(app, source, args.icon)
        p = app / 'Info.plist'
        info = plistlib.loads(p.read_bytes())
        info.update(CFBundleDisplayName=profile['title'], CFBundleName=profile['title'],
                    CFBundleShortVersionString=profile['version'], CFBundleVersion='1',
                    CADisableMinimumFrameDurationOnPhone=True, SKFrameRateOptions=True,
                    UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
                    CFBundleIcons={'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60']}})
        info.pop('SHIMPathRedirects', None)
        p.write_bytes(plistlib.dumps(info))
        managed = app / 'Mac/Contents/Resources/Data/Managed'
        for name, expected in profile['managed_sha256'].items():
            if sha(managed / name) != expected:
                raise RuntimeError('Original managed assembly changed: ' + name)
    step('controls and metadata', configure)
    from .package import package
    destination = args.output.expanduser().resolve() if args.output else work / f'{key}-{profile["version"]}-Unsigned.ipa'
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Repackage on demand even when the build steps were already complete.
    result = package(app, destination)
    result.update(game=key, version=profile['version'], original_managed_dlls_unchanged=len(profile['managed_sha256']),
                  installed_app_bytes=sum(p.stat().st_size for p in app.rglob('*') if p.is_file()),
                  jit_required=False, automated_device_tested=False, full_campaign_verified=False)
    write_json(destination.with_suffix('.json'), result)
    print(f'READY: {destination}\nIPA: {result["ipa_bytes"]/1e9:.2f} GB. Import into LiveContainer with JIT disabled.', flush=True)


def main():
    parser = argparse.ArgumentParser(description='Build a private unsigned iPhone IPA from your own supported GOG Mac game.')
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('doctor')
    fetch = sub.add_parser('fetch-tools')
    fetch.add_argument('--destination', type=Path, default=Path.home() / 'Library/Caches/hollow-ios-builder')
    command = sub.add_parser('build')
    command.add_argument('--input', required=True, type=Path)
    command.add_argument('--work', required=True, type=Path)
    command.add_argument('--game', choices=['hollow-knight', 'silksong'])
    command.add_argument('--output', type=Path)
    command.add_argument('--icon', type=Path)
    command.add_argument('--controls', type=Path, help='Optional folder of your own control PNGs')
    command.add_argument('--csc-directory', type=Path)
    command.add_argument('--tool-cache', type=Path, default=Path.home() / 'Library/Caches/hollow-ios-builder')
    command.add_argument('--jobs', type=int, choices=range(1, 5), default=2)
    args = parser.parse_args()
    try:
        if args.command == 'doctor':
            doctor()
        elif args.command == 'fetch-tools':
            fetch_tools(args.destination.expanduser().resolve())
        else:
            build(args)
    except (ValueError, RuntimeError, OSError) as e:
        print('ERROR: ' + str(e), file=sys.stderr)
        return 1
    return 0
