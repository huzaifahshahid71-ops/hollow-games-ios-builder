from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def run(args, *, env=None, log=None):
    if log:
        with Path(log).open('w') as f:
            result = subprocess.run(list(map(str, args)), env=env, stdout=f, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f'Build step failed; see {log}')
        return ''
    return subprocess.check_output(list(map(str, args)), env=env, text=True, stderr=subprocess.STDOUT)


def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + '\n')
