#!/usr/bin/env python3
"""Refuse private artifacts/identifiers in the distributable source tree."""
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parent.parent
blocked = {'.pkg', '.ipa', '.dll', '.dylib', '.nupkg', '.mobileprovision', '.p12', '.cer', '.ips', '.log',
           '.o', '.s', '.bundle', '.assets', '.resS', '.resource', '.metallib', '.dat', '.sav'}
issues = []
for p in ROOT.rglob('*'):
    if any(part in {'.git', '.venv', '__pycache__'} for part in p.relative_to(ROOT).parts):
        continue
    if p.is_symlink():
        issues.append(f'symlink: {p.relative_to(ROOT)}')
    if not p.is_file():
        continue
    if p.suffix in blocked or p.stat().st_size > 5_000_000:
        issues.append(f'private/large artifact: {p.relative_to(ROOT)}')
    if p.suffix not in {'.png'}:
        text = p.read_text(errors='replace')
        if re.search(r'/' + r'Users/[^\s"\']+|000081[0-9A-Fa-f-]{16,}|BEGIN (?:RSA |EC )?PRIVATE KEY', text):
            issues.append(f'private path/identifier: {p.relative_to(ROOT)}')
if issues:
    print('\n'.join(issues))
    sys.exit(1)
print('Public source audit passed: no game binaries, packages, saves, signing files or private absolute paths.')
