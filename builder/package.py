from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import zipfile
from .common import sha

MAGICS = {b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe'}


def package(app, destination):
    candidate = destination.with_suffix('.ipa.building')
    with tempfile.TemporaryDirectory(prefix='hollow-unsigned-') as td, zipfile.ZipFile(
            candidate, 'w', zipfile.ZIP_DEFLATED, compresslevel=9, allowZip64=True) as z:
        for p in sorted(app.rglob('*')):
            if not p.is_file() or '_CodeSignature' in p.parts or p.name == 'embedded.mobileprovision':
                continue
            source = p
            with p.open('rb') as f:
                magic = f.read(4)
            if magic in MAGICS:
                source = Path(td) / 'binary'
                shutil.copy2(p, source)
                # Native helpers may already be unsigned; a missing signature is acceptable.
                subprocess.run(['codesign', '--remove-signature', str(source)], capture_output=True)
            z.write(source, 'Payload/' + app.name + '/' + p.relative_to(app).as_posix())
    with zipfile.ZipFile(candidate) as z:
        bad = z.testzip()
        if bad:
            raise RuntimeError('IPA CRC check failed: ' + bad)
    os.replace(candidate, destination)
    return {'ipa_bytes': destination.stat().st_size, 'ipa_sha256': sha(destination), 'zip_crc_verified': True}
