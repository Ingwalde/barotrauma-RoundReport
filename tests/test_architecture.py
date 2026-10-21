"""Runtime packaging and side-effect-free adapter import contracts."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

from lupa import lua52

ROOT = Path(__file__).resolve().parents[1]


class ArchitectureTests(unittest.TestCase):
    def test_manifest_covers_every_runtime_module(self):
        manifest = ET.parse(ROOT / 'filelist.xml')
        files = {node.attrib['file'].replace('%ModDir%/', '')
                 for node in manifest.findall('None')}
        runtime = {path.relative_to(ROOT).as_posix()
                   for path in (ROOT / 'Lua').rglob('*.lua')}
        self.assertEqual(runtime, files)

    def test_modules_load_without_game_or_registration_side_effects(self):
        lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            local unavailable = setmetatable({}, {
                __index=function() error('Game API accessed during import') end
            })
            Hook=unavailable; Networking=unavailable; GUI=unavailable
            Game=unavailable; Client=unavailable
        ''')
        for path in (ROOT / 'Lua/RoundReport').rglob('*.lua'):
            with self.subTest(module=path.name):
                module = lua.execute(path.read_text(encoding='utf-8'))
                self.assertIsNotNone(module)

    def test_manifest_and_runtime_versions_match(self):
        manifest_version = ET.parse(ROOT / 'filelist.xml').getroot().attrib['modversion']
        lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        runtime_version = lua.execute(
            (ROOT / 'Lua/RoundReport/Version.lua').read_text(encoding='utf-8'))
        self.assertEqual('0.5.0', manifest_version)
        self.assertEqual(manifest_version, runtime_version)


if __name__ == '__main__':
    unittest.main()
