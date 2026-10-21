"""Build a clean Workshop folder and ZIP from the explicit runtime manifest."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import shutil
from uuid import uuid4
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


def build():
    manifest = ET.parse(ROOT / 'filelist.xml').getroot()
    version = manifest.attrib['modversion']
    if not version or any(c not in '0123456789.-' for c in version):
        raise ValueError('Unsafe package version')
    files = {'filelist.xml', 'preview.png', 'LICENSE'}
    for entry in manifest:
        raw = entry.attrib.get('file', '')
        if entry.tag != 'None' or not raw.startswith('%ModDir%/Lua/'):
            raise ValueError(f'Unexpected runtime entry: {raw}')
        relative = PurePosixPath(raw.removeprefix('%ModDir%/'))
        if '..' in relative.parts or '\\' in raw or relative.suffix != '.lua':
            raise ValueError(f'Unsafe runtime path: {raw}')
        files.add(str(relative))
    declared = {p for p in files if p.startswith('Lua/')}
    actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'Lua').rglob('*.lua')}
    if declared != actual:
        raise ValueError('Manifest does not match runtime Lua files')
    for name in files:
        source = (ROOT / name).resolve()
        if not source.is_relative_to(ROOT.resolve()) or not source.is_file():
            raise ValueError(f'Missing or external package file: {name}')
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    # Unique staging folders avoid deleting or overwriting previous release folders.
    staging = dist / f'workshop-{version}-{uuid4().hex[:12]}'
    staging.mkdir()
    package = staging / 'RoundReport'
    hashes = {}
    for name in sorted(files):
        destination = package / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, destination)
        hashes[name] = hashlib.sha256(destination.read_bytes()).hexdigest()
    archive = staging / f'RoundReport-{version}.zip'
    with ZipFile(archive, 'w', ZIP_DEFLATED) as output:
        for name in sorted(files):
            output.write(package / name, f'RoundReport/{name}')
    with ZipFile(archive) as output:
        if output.testzip() is not None:
            raise ValueError('Archive integrity check failed')
        assert set(output.namelist()) == {f'RoundReport/{name}' for name in files}
    (staging / 'SHA256.json').write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
    print(f'Folder: {package}\nArchive: {archive}\nFiles: {len(files)}')
    return package


if __name__ == '__main__':
    build()
