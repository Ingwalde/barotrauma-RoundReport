"""Pure payout-splitting math (RoundReport/Payouts.lua)."""
from pathlib import Path
import unittest

from lupa import lua52

ROOT = Path(__file__).resolve().parents[1]


class PayoutsTests(unittest.TestCase):
    def setUp(self):
        self.lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().MOD = ROOT.as_posix()

    def test_splits_pool_proportionally_to_positive_scores(self):
        self.lua.execute('''
            local Payouts = dofile(MOD .. '/Lua/RoundReport/Payouts.lua')
            local scores = { a = 30, b = 10 }
            local shares, given = Payouts.shares(scores, 100)
            assert(shares.a == 75 and shares.b == 25, "expected 75/25, got "..tostring(shares.a).."/"..tostring(shares.b))
            assert(given == 100)
        ''')

    def test_ignores_zero_and_negative_scores(self):
        self.lua.execute('''
            local Payouts = dofile(MOD .. '/Lua/RoundReport/Payouts.lua')
            local scores = { a = 10, b = 0, c = -5, d = nil }
            local shares, given = Payouts.shares(scores, 50)
            assert(shares.a == 50 and shares.b == nil and shares.c == nil and shares.d == nil)
            assert(given == 50)
        ''')

    def test_no_eligible_players_gives_nothing(self):
        self.lua.execute('''
            local Payouts = dofile(MOD .. '/Lua/RoundReport/Payouts.lua')
            local shares, given = Payouts.shares({ a = 0, b = -1 }, 100)
            assert(next(shares) == nil and given == 0)
        ''')

    def test_zero_or_nil_pool_gives_nothing(self):
        self.lua.execute('''
            local Payouts = dofile(MOD .. '/Lua/RoundReport/Payouts.lua')
            local shares1, given1 = Payouts.shares({ a = 10 }, 0)
            local shares2, given2 = Payouts.shares({ a = 10 }, nil)
            assert(next(shares1) == nil and given1 == 0)
            assert(next(shares2) == nil and given2 == 0)
        ''')

    def test_rounds_down_so_given_never_exceeds_pool(self):
        self.lua.execute('''
            local Payouts = dofile(MOD .. '/Lua/RoundReport/Payouts.lua')
            local shares, given = Payouts.shares({ a = 1, b = 1, c = 1 }, 10)
            assert(given <= 10)
            local sum = 0
            for _, v in pairs(shares) do sum = sum + v end
            assert(sum == given)
        ''')


if __name__ == "__main__":
    unittest.main()
