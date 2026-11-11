#!/usr/bin/env python3
"""Build a standalone installer and its matching, deterministic runtime archive.

Maintainer tool only: python scripts/build_release.py v1.0.0 --output dist
Publish both generated assets in the GitHub Release with the SAME tag.
"""
import argparse
import gzip
import hashlib
import io
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ['Song Mapper.lua', 'song_mapper/model.lua', 'song_mapper/codec.lua',
         'song_mapper/project.lua', 'song_mapper/session.lua', 'song_mapper/ui.lua',
         'song_mapper/compat.lua', 'installer/register.lua']


def build(tag, output):
    if not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?', tag):
        raise ValueError('Use a release tag such as v1.0.0 or v1.1.0-beta.1')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    payload = io.BytesIO()
    with gzip.GzipFile(fileobj=payload, mode='wb', filename='', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            for name in FILES:
                data = (ROOT / name).read_bytes()
                info = tarfile.TarInfo(name)
                info.size, info.mode, info.mtime = len(data), 0o644, 0
                archive.addfile(info, io.BytesIO(data))
    data = payload.getvalue()
    digest = hashlib.sha256(data).hexdigest()
    template = (ROOT / 'Install Song Mapper.command').read_text()
    # Replace assignment values only: keep the sentinel comparison intact.
    installer = template.replace("RELEASE_TAG='__SONG_MAPPER_RELEASE_TAG__'", f"RELEASE_TAG='{tag}'")
    installer = installer.replace("RELEASE_SHA256='__SONG_MAPPER_RELEASE_SHA256__'", f"RELEASE_SHA256='{digest}'")
    archive_path = output / 'song-mapper-runtime.tar.gz'
    archive_path.write_bytes(data)
    installer_path = output / 'Install Song Mapper.command'
    installer_path.write_text(installer)
    installer_path.chmod(0o755)
    lines = [f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}'
             for p in (archive_path, installer_path)]
    (output / 'SHA256SUMS').write_text('\n'.join(lines) + '\n')
    return installer_path, archive_path


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tag')
    parser.add_argument('--output', default='dist')
    args = parser.parse_args()
    build(args.tag, args.output)
