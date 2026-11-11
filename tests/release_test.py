"""Release packaging tests; no downloads, publishing, or REAPER required."""
import hashlib
import importlib.util
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_release', ROOT / 'scripts/build_release.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class ReleaseTests(unittest.TestCase):
    def test_reproducible_payload_and_pinned_installer(self):
        with tempfile.TemporaryDirectory() as temporary:
            first, payload = builder.build('v1.2.3', Path(temporary) / 'first')
            second, other = builder.build('v1.2.3', Path(temporary) / 'second')
            self.assertEqual(payload.read_bytes(), other.read_bytes())
            self.assertEqual(first.read_bytes(), second.read_bytes())
            text = first.read_text()
            self.assertIn("RELEASE_TAG='v1.2.3'", text)
            self.assertIn("RELEASE_SHA256='" + hashlib.sha256(payload.read_bytes()).hexdigest() + "'", text)
            with tarfile.open(payload) as archive:
                self.assertEqual(archive.getnames(), builder.FILES)
                self.assertTrue(all(member.isfile() for member in archive))
                for member in archive:
                    self.assertEqual(archive.extractfile(member).read(), (ROOT / member.name).read_bytes())

    def test_rejects_invalid_release_tags(self):
        with tempfile.TemporaryDirectory() as temporary:
            for tag in ['main', '../escape', 'v1.2.3;echo bad', 'latest', 'v1.0']:
                with self.subTest(tag=tag), self.assertRaises(ValueError):
                    builder.build(tag, temporary)


if __name__ == '__main__':
    unittest.main()
