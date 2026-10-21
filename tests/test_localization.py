"""Language mapping, complete catalogs and Lua formatting regression checks."""
from pathlib import Path
import re
import unittest

from lupa import lua52

ROOT = Path(__file__).resolve().parents[1]


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        self.strings = self.lua.execute(
            (ROOT / 'Lua/RoundReport/Strings.lua').read_text(encoding='utf-8'))

    def test_all_catalogs_are_complete_and_format_correctly(self):
        english = dict(self.strings.en)
        pattern = r'%(?:\d+)?(?:\.\d+)?[sdgf]'
        for code in self.strings.languages.values():
            catalog = dict(self.strings[code])
            self.assertEqual(set(english), set(catalog), code)
            for key, value in catalog.items():
                with self.subTest(locale=code, key=key):
                    expected = re.findall(pattern, english[key])
                    self.assertEqual(expected, re.findall(pattern, value))
                    args = ['Crew' if token.endswith('s') else 2 for token in expected]
                    self.lua.eval('string.format')(value, *args)

    def test_game_identifiers_and_manual_overrides(self):
        for name, code in self.strings.languages.items():
            self.lua.globals().LANGUAGE = name.upper()
            self.lua.execute('Game={Settings={CurrentConfig={Language={Value=LANGUAGE}}}}')
            self.assertEqual(code, self.strings.resolveLanguage('auto'))
            self.assertEqual(code, self.strings.resolveLanguage(None))
            self.assertEqual(code, self.strings.resolveLanguage(code))
        self.assertEqual('uk', self.strings.resolveLanguage('uk'))

    def test_future_language_and_unavailable_settings_fall_back(self):
        self.lua.execute("Game={Settings={CurrentConfig={Language={Value='FutureLanguage'}}}}")
        self.assertEqual('en', self.strings.resolveLanguage('auto'))
        self.lua.execute('Game=nil')
        self.assertEqual('en', self.strings.resolveLanguage('auto'))
        self.lua.execute("Game=setmetatable({}, {__index=function() error('unavailable') end})")
        self.assertEqual('en', self.strings.resolveLanguage('auto'))
        self.assertEqual('uk', self.strings.resolveLanguage('uk'))

    def test_missing_key_falls_back_to_english(self):
        self.strings.de.close = None
        self.assertEqual('Close', self.strings.get('de', 'close'))
        self.assertEqual('Close', self.strings.get('future', 'close'))
        self.assertEqual('missing_key', self.strings.get('de', 'missing_key'))


if __name__ == '__main__':
    unittest.main()
