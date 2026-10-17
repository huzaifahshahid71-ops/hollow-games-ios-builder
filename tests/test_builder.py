import hashlib
from pathlib import Path
import struct
import tempfile
import unittest

from builder.imports import alias
from builder.compression import pack_flat, repack_bundle


class ImportSafety(unittest.TestCase):
    def fixture(self, outside=False):
        data = bytearray(400)
        struct.pack_into('<8I', data, 0, 0xfeedfacf, 0x100000c, 0, 6, 1, 72, 0, 0)
        struct.pack_into('<II16sQQQQ', data, 32, 25, 72, b'__LINKEDIT', 0, 200, 200, 200)
        data[210:216] = b'_mmap\0'
        data[250:256] = b'_mmap\0'
        if outside:
            data[120:126] = b'_mmap\0'
        return data

    def test_alias_preserves_other_bytes(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'mono'
            original = self.fixture()
            p.write_bytes(original)
            alias(p, b'_mmap\0', b'_smmp\0')
            actual = p.read_bytes()
            expected = original.replace(b'_mmap\0', b'_smmp\0')
            self.assertEqual(actual, expected)

    def test_outside_linkedit_refuses_without_writing(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'mono'
            original = self.fixture(True)
            p.write_bytes(original)
            with self.assertRaises(ValueError):
                alias(p, b'_mmap\0', b'_smmp\0')
            self.assertEqual(p.read_bytes(), original)

    def test_count_mismatch_refuses(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'mono'
            p.write_bytes(self.fixture())
            with self.assertRaises(ValueError):
                alias(p, b'_mmap\0', b'_smmp\0', count=3)


class CompressionRoundTrip(unittest.TestCase):
    def test_flat_multiblock_empty_and_external(self):
        import UnityPy
        with tempfile.TemporaryDirectory() as t:
            data = Path(t)
            raw = {'level0': b'A' * 200000, 'sharedassets0.assets.resS': bytes(range(256)) * 2000,
                   'level1': b'', 'Resources/unity_builtin_extra': b'builtin' * 100}
            for name, content in raw.items():
                p = data / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(content)
            (data / 'sharedassets0.resource').write_bytes(b'external audio')
            result = pack_flat(data)
            self.assertTrue(result['all_nodes_sha256_identical'])
            self.assertEqual((data / 'sharedassets0.resource').read_bytes(), b'external audio')
            bundle = next(iter(UnityPy.load(str(data / 'data.unity3d')).files.values()))
            decoded = {name: n.reader.bytes if hasattr(n, 'reader') else n.bytes for name, n in bundle.files.items()}
            self.assertEqual(decoded, raw)
            # Repack the same synthetic archive through the Silksong path.
            archive = data / 'data.unity3d'
            repack_bundle(archive)
            bundle = next(iter(UnityPy.load(str(archive)).files.values()))
            decoded = {name: n.reader.bytes if hasattr(n, 'reader') else n.bytes for name, n in bundle.files.items()}
            self.assertEqual(decoded, raw)


if __name__ == '__main__':
    unittest.main()
