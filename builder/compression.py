"""Lossless content compression, independently decoded and hash-checked before replacement."""
from pathlib import Path
import hashlib
import os
import struct
import lz4.block
from .common import sha, write_json


def pack_flat(data):
    files = sorted([p for p in data.rglob('*') if p.is_file() and (
        (p.parent == data and p.suffix != '.resource' and p.name.startswith(
            ('level', 'sharedassets', 'resources.assets', 'globalgamemanagers'))) or
        p.relative_to(data).as_posix() == 'Resources/unity_builtin_extra')],
        key=lambda p: p.relative_to(data).as_posix())
    if not files or (data / 'data.unity3d').exists():
        raise ValueError('Expected original loose Hollow Knight content')
    dst = data / 'data.unity3d.building'
    header = b'UnityFS\0' + struct.pack('>I', 8) + b'6000.0.61f1\0' * 2
    patch = len(header)
    header += b'\0' * 20
    header += b'\0' * (-len(header) % 16)
    nodes, blocks, buffer, offset = [], [], bytearray(), 0
    with dst.open('wb') as w:
        w.write(header)
        def block(raw):
            packed = lz4.block.compress(raw, mode='high_compression', compression=12, store_size=False)
            flag = 3
            if len(packed) >= len(raw):
                packed, flag = raw, 0
            blocks.append((len(raw), len(packed), flag))
            w.write(packed)
        for number, p in enumerate(files):
            size = p.stat().st_size
            flag = 4 if p.suffix == '.assets' or (p.name.startswith(('level', 'globalgamemanagers')) and p.suffix != '.resS') else 0
            nodes.append((offset, size, flag, p.relative_to(data).as_posix()))
            offset += size
            with p.open('rb') as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b''):
                    buffer.extend(chunk)
                    while len(buffer) >= 131072:
                        block(bytes(buffer[:131072]))
                        del buffer[:131072]
            if (number + 1) % 100 == 0:
                print(f'Packed {number+1}/{len(files)} loose files; verification follows', flush=True)
        if buffer:
            block(bytes(buffer))
        info = bytearray(16) + struct.pack('>I', len(blocks))
        for row in blocks:
            info += struct.pack('>IIH', *row)
        info += struct.pack('>I', len(nodes))
        for off, size, flag, name in nodes:
            info += struct.pack('>qqI', off, size, flag) + name.encode() + b'\0'
        packed = lz4.block.compress(bytes(info), mode='high_compression', compression=12, store_size=False)
        w.write(packed)
        total = w.tell()
        w.seek(patch)
        w.write(struct.pack('>QIII', total, len(packed), len(info), 0xC3))
    # Independent reader verifies archive metadata and every full node against source.
    with dst.open('rb') as f:
        f.seek(-len(packed), 2)
        if lz4.block.decompress(f.read(), uncompressed_size=len(info)) != info:
            raise RuntimeError('Archive metadata verification failed')
        f.seek(len(header))
        i, remaining, digest = 0, nodes[0][1], hashlib.sha256()
        def finish_empty():
            nonlocal i, remaining, digest
            while i < len(files) and remaining == 0:
                if digest.hexdigest() != sha(files[i]):
                    raise RuntimeError(f'Lossless check failed: {files[i].name}')
                i += 1
                digest = hashlib.sha256()
                if i < len(files):
                    remaining = nodes[i][1]
        finish_empty()
        for usize, csize, flag in blocks:
            raw = f.read(csize)
            raw = lz4.block.decompress(raw, uncompressed_size=usize) if flag else raw
            if len(raw) != usize:
                raise RuntimeError('Truncated block')
            while raw:
                take = min(remaining, len(raw))
                digest.update(raw[:take])
                raw = raw[take:]
                remaining -= take
                finish_empty()
        if i != len(nodes):
            raise RuntimeError('Missing archive nodes')
    os.replace(dst, data / 'data.unity3d')
    for p in files:
        p.unlink()  # Converted working copy only, after all hashes pass.
    return {'nodes': len(nodes), 'original_bytes': offset, 'compressed_bytes': total,
            'all_nodes_sha256_identical': True, 'format': 'UnityFS LZ4HC12 / 128 KiB'}


def repack_bundle(path):
    import UnityPy
    from UnityPy.streams import EndianBinaryReader
    UnityPy.config.FALLBACK_UNITY_VERSION = '6000.0.50f1'
    bundle = next(iter(UnityPy.load(str(path)).files.values()))
    original = {}
    for name, node in list(bundle.files.items()):
        raw = node.reader.bytes if hasattr(node, 'reader') else node.bytes
        original[name] = hashlib.sha256(raw).hexdigest()
        reader = EndianBinaryReader(raw)
        reader.flags = node.flags
        bundle.files[name] = reader
    candidate = path.with_suffix(path.suffix + '.building')
    candidate.write_bytes(bundle.save(packer='lz4hc'))
    check = next(iter(UnityPy.load(str(candidate)).files.values()))
    actual = {name: hashlib.sha256(n.reader.bytes if hasattr(n, 'reader') else n.bytes).hexdigest()
              for name, n in check.files.items()}
    if actual != original:
        raise RuntimeError(f'Lossless bundle verification failed: {path.name}')
    before, after = path.stat().st_size, candidate.stat().st_size
    os.replace(candidate, path)
    return {'nodes': len(original), 'original_bytes': before, 'compressed_bytes': after,
            'all_nodes_sha256_identical': True}


def compress(data, key, report):
    if key == 'hollow-knight':
        result = pack_flat(data)
    else:
        rows = []
        bundles = sorted((data / 'StreamingAssets').rglob('*.bundle'))
        if not bundles:
            raise ValueError('No Silksong bundles found')
        for i, p in enumerate(bundles):
            row = repack_bundle(p)
            row['path'] = str(p.relative_to(data))
            rows.append(row)
            if (i + 1) % 100 == 0:
                print(f'Losslessly verified {i+1}/{len(bundles)} bundles', flush=True)
        result = {'bundles': rows, 'all_nodes_sha256_identical': True,
                  'original_bytes': sum(r['original_bytes'] for r in rows),
                  'compressed_bytes': sum(r['compressed_bytes'] for r in rows)}
    write_json(report, result)
    return result
