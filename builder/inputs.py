"""Never launch installers or the supplied game. Match known inputs before conversion."""
from pathlib import Path
import json
import plistlib
from .common import ROOT, run, sha


def find_app(path):
    path = Path(path).resolve()
    if (path / 'Contents/Info.plist').is_file():
        return path
    candidates = [p.parent.parent for p in path.rglob('Info.plist')
                  if p.parent.name == 'Contents' and (p.parent / 'Resources/Data/Managed/mscorlib.dll').is_file()]
    if len(candidates) != 1:
        raise ValueError('Select one complete Mac .app, or a folder containing exactly one game .app.')
    return candidates[0]


def resolve_input(path, work):
    path = Path(path).expanduser().resolve()
    if path.is_file() and path.suffix.lower() == '.pkg':
        expanded = work / 'extracted-package'
        # pkgutil expands payloads without running install scripts. No sudo or installer command.
        if not expanded.exists():
            print('Extracting package as data only…', flush=True)
            run(['pkgutil', '--expand-full', path, expanded], log=work / 'extract.log')
        return find_app(expanded)
    if not path.is_dir():
        raise ValueError('Supply the GOG Mac .pkg or a complete Mac game folder. APK/Linux/Windows inputs are not supported.')
    return find_app(path)


def inspect(app, requested=None):
    app = app.resolve()
    for p in app.rglob('*'):
        if p.is_symlink() and not p.resolve().is_relative_to(app):
            raise ValueError('The game contains an external symlink; supply a self-contained Mac app.')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    candidates = [requested] if requested else ['hollow-knight', 'silksong']
    for key in candidates:
        profile = json.loads((ROOT / 'profiles' / key / 'manifest.json').read_text())
        if info.get('CFBundleExecutable') != profile['executable']:
            continue
        errors = []
        for rel, expected in profile['native_sha256'].items():
            p = app / 'Contents' / rel
            if not p.is_file() or sha(p) != expected:
                errors.append(rel)
        managed = app / 'Contents/Resources/Data/Managed'
        found = {p.name for p in managed.glob('*.dll')}
        if found != set(profile['managed_sha256']):
            errors.append('managed assembly list')
        for name, expected in profile['managed_sha256'].items():
            p = managed / name
            if not p.is_file() or sha(p) != expected:
                errors.append(name)
        if errors:
            raise ValueError('Unsupported or modified game build: ' + ', '.join(errors[:8]) +
                             f'. This recipe requires {key} {profile["version"]}.')
        return profile
    raise ValueError('No matching game profile. Supported: GOG Mac Hollow Knight 1.5.12620 / Silksong 1.0.30000.')
