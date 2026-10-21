"""Client regressions using real report logic and a minimal GUI widget tree."""
from pathlib import Path
import sys
import unittest

from lupa import lua52

MOD = Path(sys.argv.pop(1)).resolve() if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else Path(__file__).resolve().parents[1]


class ClientTests(unittest.TestCase):
    def load(self, width=1600, height=1000, lang='uk'):
        lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        lua.globals().MOD = MOD.as_posix()
        lua.globals().SCREEN_W, lua.globals().SCREEN_H = width, height
        lua.globals().LANG = lang
        lua.execute('''
            dofile(MOD .. '/tests/client_gui_mock.lua')
            local original = dofile
            dofile = function(path)
                local result = original(path)
                if path:match('/Config.lua$') then result.Language = LANG end
                return result
            end
            loadfile(MOD .. '/Lua/Autorun/RoundReportClient.lua')(MOD)
        ''')
        return lua

    def setUp(self):
        self.lua = self.load()

    def test_packet_opens_window_with_aggregates_and_mvp(self):
        self.lua.execute('''
            assert(not ROOT.comp.Visible)
            local st = sample(); show(st.round, st.total)
            assert(ROOT.comp.Visible)
            assert(findText('Підсумок експедиції'))
            assert(findText('Записів екіпажу: 3'))
            assert(findText('75') and findText('30') and findText('1'))
            assert(findText('20.0'))
            local rows = lists()[1].Content.RectTransform.children
            assert(#rows == 3 and findText('Alice', rows[1]))
            assert(rows[1].comp.Color.g == 57) -- current player's row
            assert(findText('Botty (бот)', rows[3]))
        ''')

    def test_period_switch_replaces_rows_and_totals(self):
        self.lua.execute('''
            local st = sample(); st:resetRound()
            st:add('p4', 'New crew', false, 'repair', 10)
            show(st.round, st.total)
            assert(not findText('Alice') and findText('10'))
            findText('Загалом').OnClicked()
            assert(findText('Підсумок з запуску сервера'))
            assert(findText('Alice') and findText('85'))
            assert(findText('Записів екіпажу: 4'))
            assert(findText('Загалом').Selected and not findText('Цей заплив').Selected)
            findText('Цей заплив').OnClicked()
            assert(not findText('Alice') and #lists()[1].Content.RectTransform.children == 1)
        ''')

    def test_empty_packet_clears_previous_report(self):
        self.lua.execute('''
            local st = sample(); show(st.round, st.total); show()
            assert(not findText('Alice'))
            assert(findText('Записів екіпажу: 0'))
            assert(findText('Поки нічого рахувати.'))
            assert(findText('Відзнак поки немає.'))
            assert(findText('Інцидентів не зафіксовано.'))
            assert(#lists()[1].Content.RectTransform.children == 1)
        ''')

    def test_negative_scores_and_incidents_remain_visible(self):
        self.lua.execute('''
            local st = sample(); show(st.round, st.total)
            local score = findText('-4.0')
            assert(score and score.TextColor.r == 245)
            local panels = lists()
            assert(findText('Найкращий механік: Alice', panels[2].Content.RectTransform))
            assert(not findText('Камікадзе: Botty (бот) (смертей: 2)', panels[2].Content.RectTransform))
            assert(findText('Камікадзе: Botty (бот) (смертей: 2)', panels[3].Content.RectTransform))
        ''')

    def test_close_stops_gui_updates_and_hello_repeats_at_round_start(self):
        self.lua.execute('''
            assert(#sent == 1 and sent[1] == 'roundreport.hello')
            show(); patches['Barotrauma.GameScreen']()
            assert(ROOT.comp.draws == 1)
            findText('Закрити').OnClicked()
            patches['Barotrauma.NetLobbyScreen']()
            assert(not ROOT.comp.Visible and ROOT.comp.draws == 1)
            show(); assert(ROOT.comp.Visible)
            hooks.roundStart(); assert(#sent == 2)
        ''')

    def test_ineligible_mvp_keeps_incident_and_omits_score_bar(self):
        self.lua.execute('''
            local st = dofile(MOD .. '/Lua/RoundReport/Stats.lua').new()
            st:add('p1', 'Alice', false, 'repair', 75)
            st:add('p1', 'Alice', false, 'meltdown', 1)
            show(st.round, st.total)
            assert(findText('Цього разу без MVP'))
            assert(findText('Підірвав реактор: Alice', lists()[3].Content.RectTransform))
            local row = lists()[1].Content.RectTransform.children[1]
            local cells = row.children[#row.children].children
            local scoreCell = cells[#cells]
            assert(#scoreCell.children == 1 and scoreCell.children[1].comp.Text == '-')
        ''')

    def test_english_and_unrecognized_tab_fallback(self):
        lua = self.load(lang='en')
        lua.execute('''
            local st = sample(); show(st.round, st.total, 'unexpected')
            assert(findText('Expedition debrief') and findText('This round').Selected)
            assert(findText('Commendations') and findText('Team total'))
            assert(findText('Botty (bot)'))
        ''')

    def test_long_names_have_full_tooltips_and_scaling(self):
        self.lua.execute('''
            local st = sample()
            local name = string.rep('Довге ім’я ', 12)
            st:add('p1', name, false, 'repair', 1)
            show(st.round, st.total)
            local cell = findText(name)
            assert(cell and cell.ToolTip == name)
            assert(cell.AutoScaleHorizontal and cell.AutoScaleVertical)
        ''')

    def test_layout_sections_fit_small_and_large_displays(self):
        for width, height in [(1280, 720), (1920, 1080), (2560, 1440)]:
            with self.subTest(resolution=(width, height)):
                lua = self.load(width, height)
                lua.execute('''
                    local st = sample(); show(st.round, st.total)
                    for _, c in ipairs(allWidgets()) do
                        if c.kind == 'LayoutGroup' then
                            local total, count = 0, #c.RectTransform.children
                            local limit = c.horizontal and c.Rect.Width or c.Rect.Height
                            for _, rt in ipairs(c.RectTransform.children) do
                                total = total + (c.horizontal and rt.Rect.Width or rt.Rect.Height)
                            end
                            total = total + math.max(0, count - 1) * (c.RelativeSpacing or 0) * limit
                            assert(total <= limit + 1, 'layout exceeds its available space')
                        end
                    end
                    assert(findText('Закрити').Rect.Height > 25)
                ''')


if __name__ == '__main__':
    unittest.main()
