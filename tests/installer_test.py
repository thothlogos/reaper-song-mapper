"""macOS installer tests; only disposable resource folders, no REAPER launch/network."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
import plistlib
import shutil
import importlib.util
import shlex
import hashlib
import io
import tarfile

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(sys.platform == 'darwin', 'requires macOS system tools')
class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='song mapper test ')
        self.base = Path(self.tmp.name)
        self.resource = self.base / 'REAPER resources'
        self.resource.mkdir()
        (self.resource / 'reaper.ini').write_text('[REAPER]\n')
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        # Do not stop or launch the user's REAPER. Simulate the closed-process preflight.
        mock = self.bin / 'pgrep'
        mock.write_text('#!/bin/bash\nexit 1\n')
        mock.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.app = self.base / 'REAPER.app'
        (self.app / 'Contents/MacOS').mkdir(parents=True)
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '7.82.0'}))
        shutil.copy('/bin/bash', self.app / 'Contents/MacOS/REAPER')
        self.arch = subprocess.check_output(['uname', '-m'], text=True).strip()
        self.api = self.resource / 'Scripts/ReaTeam Extensions/API'
        self.native = self.resource / ('UserPlugins/reaper_imgui-' + self.arch + '.dylib')
        self.dest = self.resource / 'Scripts/Song Mapper'

    def tearDown(self):
        self.tmp.cleanup()

    def existing(self):
        self.api.mkdir(parents=True)
        self.native.parent.mkdir()
        # Registration is deliberately deferred; fixture content must remain untouched.
        self.native.write_bytes(b'existing extension fixture')
        (self.api / 'imgui.lua').write_text('-- existing shim fixture\n')

    def run_installer(self, *args):
        return subprocess.run(['bash', str(getattr(self, 'installer', ROOT / 'Install Song Mapper.command')),
            '--resource-path', str(self.resource), '--reaper-app', str(self.app), '--no-launch', *args],
            env=self.env, text=True, capture_output=True)

    def standalone(self):
        spec = importlib.util.spec_from_file_location('build_release', ROOT / 'scripts/build_release.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        installer, self.payload = module.build('v1.0.0-test', self.base / 'release')
        isolated = self.base / 'download'; isolated.mkdir()
        self.installer = isolated / installer.name
        shutil.copy(installer, self.installer)
        mock = self.bin / 'curl'
        mock.write_text('#!/bin/bash\nwhile [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then shift; exec /bin/cp ' + shlex.quote(str(self.payload)) + ' "$1"; fi; shift; done\nexit 1\n')
        mock.chmod(0o755)

    def test_standalone_downloads_matching_release_and_is_repeatable(self):
        self.existing(); self.standalone()
        for _ in range(2):
            result = self.run_installer()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Downloading Song Mapper v1.0.0-test', result.stdout)
        self.assertEqual((self.dest / 'Song Mapper.lua').read_bytes(), (ROOT / 'Song Mapper.lua').read_bytes())
        self.assertFalse(list((self.resource / 'Scripts').glob('.song-mapper-backup.*/runtime')))

    def test_standalone_checksum_failure_leaves_previous_install_intact(self):
        self.existing()
        self.assertEqual(self.run_installer().returncode, 0)
        before = (self.dest / 'Song Mapper.lua').read_bytes()
        self.standalone(); self.payload.write_bytes(b'corrupt download')
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checksum mismatch', result.stderr)
        self.assertEqual((self.dest / 'Song Mapper.lua').read_bytes(), before)

    def test_standalone_rejects_unsafe_archive_before_extraction(self):
        self.existing(); self.standalone()
        payload = io.BytesIO()
        with tarfile.open(fileobj=payload, mode='w:gz') as archive:
            info = tarfile.TarInfo('../escaped'); info.size = 4
            archive.addfile(info, io.BytesIO(b'evil'))
        data = payload.getvalue()
        old_hash = hashlib.sha256(self.payload.read_bytes()).hexdigest()
        self.payload.write_bytes(data)
        self.installer.write_text(self.installer.read_text().replace(old_hash, hashlib.sha256(data).hexdigest()))
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unexpected release archive contents', result.stderr)
        self.assertFalse(self.dest.exists())

    def test_standalone_rejects_link_with_otherwise_valid_manifest(self):
        self.existing(); self.standalone()
        old_hash = hashlib.sha256(self.payload.read_bytes()).hexdigest()
        payload = io.BytesIO()
        with tarfile.open(self.payload) as source, tarfile.open(fileobj=payload, mode='w:gz') as archive:
            for index, member in enumerate(source):
                if index == 0:
                    member.type, member.linkname, member.size = tarfile.SYMTYPE, '../escaped', 0
                    archive.addfile(member)
                else:
                    archive.addfile(member, source.extractfile(member))
        data = payload.getvalue(); self.payload.write_bytes(data)
        self.installer.write_text(self.installer.read_text().replace(old_hash, hashlib.sha256(data).hexdigest()))
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('link or non-regular file', result.stderr)
        self.assertFalse(self.dest.exists())

    def test_dry_run_missing_dependency_has_no_writes(self):
        result = self.run_installer('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.resource.iterdir()), [self.resource / 'reaper.ini'])

    def test_version_range_is_open_ended(self):
        for version in ['7.82', '7.83.0', '7.84', '7.85', '7.82.0_3385784u', '7.100', '8.0']:
            with self.subTest(version=version):
                (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': version}))
                result = self.run_installer('--dry-run')
                self.assertEqual(result.returncode, 0, result.stderr)
        for version in ['7.81', '7.9', '6.99', 'unknown']:
            with self.subTest(version=version):
                (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': version}))
                self.assertNotEqual(self.run_installer('--dry-run').returncode, 0)

    def test_bad_download_is_rejected_before_install(self):
        mock = self.bin / 'curl'
        mock.write_text('#!/bin/bash\nwhile [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then shift; echo corrupt > "$1"; exit 0; fi; shift; done\nexit 1\n')
        mock.chmod(0o755)
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checksum mismatch', result.stderr)
        self.assertFalse(self.dest.exists())
        self.assertFalse(self.native.exists())
        self.assertFalse((self.resource / '.song-mapper-install-lock').exists())

    def test_repeat_install_preserves_dependencies_and_backs_up_runtime(self):
        self.existing()
        for _ in range(2):
            result = self.run_installer()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.dest / 'song_mapper/ui.lua').is_file())
        self.assertTrue((self.dest / 'Finish Installation.lua').is_file())
        self.assertEqual(self.native.read_bytes(), b'existing extension fixture')
        self.assertEqual((self.api / 'imgui.lua').read_text(), '-- existing shim fixture\n')
        backups = list((self.resource / 'Scripts').glob('.song-mapper-backup.*/runtime'))
        self.assertEqual(len(backups), 0)

    def test_unmanaged_install_is_preserved(self):
        self.existing(); self.dest.mkdir()
        (self.dest / 'keep.txt').write_text('custom work')
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual((self.dest / 'keep.txt').read_text(), 'custom work')

    def test_concurrent_lock_is_preserved(self):
        self.existing()
        lock = self.resource / '.song-mapper-install-lock'; lock.mkdir()
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertTrue(lock.is_dir())
        self.assertFalse(self.dest.exists())

    def test_conflicting_architecture_refuses_install(self):
        self.existing()
        (self.native.parent / 'reaper_imgui-other.dylib').write_bytes(b'conflict')
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertFalse(self.dest.exists())

    def test_symlink_destination_is_not_followed(self):
        self.existing()
        elsewhere = self.base / 'elsewhere'; elsewhere.mkdir()
        self.dest.symlink_to(elsewhere, target_is_directory=True)
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_copy_failure_restores_previous_runtime(self):
        self.existing()
        self.assertEqual(self.run_installer().returncode, 0)
        (self.dest / 'keep.txt').write_text('previous version')
        # Fail the second move (staged runtime -> destination), after the original
        # runtime was backed up. Subsequent restore must use the real mv.
        counter = self.base / 'moves'
        mock = self.bin / 'mv'
        mock.write_text('#!/bin/bash\nn=0\n[ ! -f "' + str(counter) + '" ] || n=$(cat "' + str(counter) + '")\nn=$((n+1))\necho "$n" > "' + str(counter) + '"\n[ "$n" != 2 ] || exit 1\nexec /bin/mv "$@"\n')
        mock.chmod(0o755)
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual((self.dest / 'keep.txt').read_text(), 'previous version')

if __name__ == '__main__':
    unittest.main()
