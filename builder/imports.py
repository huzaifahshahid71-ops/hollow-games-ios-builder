"""Guarded, equal-length import-name aliases, confined to Mach-O __LINKEDIT."""
import struct
from pathlib import Path


def alias(path, old, new, count=2):
    if len(old) != len(new) or not old.endswith(b'\0') or not new.endswith(b'\0'):
        raise ValueError('Aliases must be equal-length NUL-terminated names')
    p = Path(path)
    data = bytearray(p.read_bytes())
    if len(data) < 32 or data[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected thin arm64 Mach-O')
    pos = 32
    end = 32 + struct.unpack_from('<I', data, 20)[0]
    link = None
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        if pos + 8 > end:
            raise ValueError('Truncated commands')
        cmd, size = struct.unpack_from('<II', data, pos)
        if size < 8 or pos + size > end or end > len(data):
            raise ValueError('Invalid commands')
        if cmd == 25 and size >= 72 and data[pos+8:pos+24].rstrip(b'\0') == b'__LINKEDIT':
            offset, length = struct.unpack_from('<QQ', data, pos+40)
            link = (offset, offset + length)
        pos += size
    hits = []
    pos = 0
    while (pos := data.find(old, pos)) >= 0:
        if not link or not link[0] <= pos < pos + len(old) <= link[1]:
            raise ValueError('Import name found outside __LINKEDIT; refusing change')
        hits.append(pos)
        pos += len(old)
    if len(hits) != count:
        raise ValueError(f'Expected {count} import records for {old!r}, found {len(hits)}')
    for pos in hits:
        data[pos:pos+len(old)] = new
    p.write_bytes(data)
    return {'old': old[:-1].decode(), 'new': new[:-1].decode(), 'locations': hits}
