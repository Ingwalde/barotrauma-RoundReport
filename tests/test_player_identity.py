"""Regression tests for server player identity and GUI capability lifetime."""
from pathlib import Path
import unittest

from lupa import lua52

MOD = Path(__file__).resolve().parents[1].as_posix()


class PlayerIdentityTests(unittest.TestCase):
    def setUp(self):
        self.lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().MOD = MOD
        self.lua.execute('''
            CLIENT=false; SERVER=true
            patches, hooks, received, sent, chat = {}, {}, {}, {}, {}
            Hook = {HookMethodType={Before=1, After=2}}
            function Hook.Patch(id, cls, method, fn) patches[method]=fn end
            function Hook.Add(event, id, fn) hooks[event]=fn end
            function Color() return {} end
            function print() end
            dofile(MOD .. '/tests/mocks.lua')
            ChatMessageType={Server=1}
            ChatMessage={Create=function(_, text) return {text=text} end}
            Game={SendDirectChatMessage=function(msg, client) chat[#chat+1]=msg.text end}
            Game.Settings={CurrentConfig={Language={Value='Ukrainian'}}}
            Networking={
                Receive=function(id, fn) received[id]=fn end,
                Start=function(id) local m=NewMsg(); m.id=id; return m end,
                Send=function(msg, connection) sent[#sent+1]=msg end
            }
            function newClient(name, sessionId, account)
                local option=setmetatable({IsSome=function() return account~=nil end}, {
                    __tostring=function() return account and ('Some<AccountId>('..account..')') or 'None<AccountId>' end
                })
                return {Name=name, SessionId=sessionId, AccountId=option,
                    Connection='conn'..sessionId,
                    Character={Name=name..'Char', TeamID='Team1', IsHuman=true, IsOnPlayerTeam=true}}
            end
            alice=newClient('Alice',1,'STEAM_1:1:1')
            Client={ClientList={alice}}
            function reload() loadfile(MOD..'/Lua/Autorun/RoundReport.lua')(MOD) end
            function repair(client, amount)
                patches.OnItemRepaired(nil,{character=client.Character,repairAmount=amount})
            end
            function hello(client) received['roundreport.hello'](NewMsg(),client) end
            function request(client, command)
                chat, sent = {}, {}
                assert(hooks.chatMessage(command,client)==true)
            end
            function count(tbl) local n=0; for _ in pairs(tbl) do n=n+1 end; return n end
            function only(tbl) assert(count(tbl)==1); return select(2,next(tbl)) end
            reload()
        ''')

    def check(self, code):
        self.lua.execute(code)

    def test_rename_combines_stats(self):
        self.check(r'''
            repair(alice,10); alice.Name='Renamed'; repair(alice,5)
            request(alice,'!mystats')
            assert(table.concat(chat,'\n'):find('ремонт 15',1,true))
            assert(only(RoundReport.stats.round).repair==15)
            assert(only(RoundReport.stats.total).repair==15)
        ''')

    def test_rename_without_new_activity_updates_labels(self):
        self.check('''
            repair(alice,10); alice.Name='Renamed'
            request(alice,'!mystats')
            assert(only(RoundReport.stats.round).label=='Renamed')
            assert(only(RoundReport.stats.total).label=='Renamed')
        ''')

    def test_other_player_request_refreshes_names(self):
        self.check('''
            repair(alice,10); alice.Name='Renamed'
            bob=newClient('Bob',2,'STEAM_1:1:2'); Client.ClientList={alice,bob}
            request(bob,'!stats')
            assert(only(RoundReport.stats.round).label=='Renamed')
        ''')

    def test_rename_keeps_window_delivery(self):
        self.check('''
            hello(alice); repair(alice,10); alice.Name='Renamed'
            request(alice,'!stats')
            assert(#sent==1 and #chat==0)
            assert(sent[1].ReadString()=='round')
            local Net=dofile(MOD..'/Lua/RoundReport/Net.lua')
            local Stats=dofile(MOD..'/Lua/RoundReport/Stats.lua')
            local rows=Net.readTable(sent[1],Stats.FIELDS)
            assert(only(rows).label=='Renamed' and only(rows).repair==10)
            for key in pairs(rows) do assert(not key:find('STEAM',1,true)) end
        ''')

    def test_same_name_different_accounts_remain_separate(self):
        self.check('''
            bob=newClient('Alice',2,'STEAM_1:1:2'); Client.ClientList={alice,bob}
            repair(alice,10); repair(bob,5); hello(alice)
            assert(count(RoundReport.stats.round)==2)
            request(bob,'!stats'); assert(#sent==0 and #chat>0)
        ''')

    def test_unwrapped_account_survives_reconnect(self):
        self.check('''
            local function steamId()
                return setmetatable({}, {
                    __index=function() error('cannot access field on SteamId') end,
                    __tostring=function() return 'STEAM_1:1:1' end
                })
            end
            alice.AccountId=steamId(); hello(alice); repair(alice,10)
            request(alice,'!stats'); assert(#sent==1)
            hooks['client.disconnected'](alice)
            alice=newClient('Back',2,nil); alice.AccountId=steamId()
            Client.ClientList={alice}; repair(alice,5)
            assert(only(RoundReport.stats.round).repair==15)
        ''')

    def test_reconnect_keeps_stats_but_requires_new_hello(self):
        self.check('''
            hello(alice); repair(alice,10); alice.Name='Renamed'
            hooks['client.disconnected'](alice)
            alice=newClient('Back',2,'STEAM_1:1:1'); Client.ClientList={alice}
            repair(alice,5); assert(only(RoundReport.stats.round).repair==15)
            request(alice,'!stats'); assert(#sent==0 and #chat>0)
            hello(alice); request(alice,'!stats'); assert(#sent==1 and #chat==0)
        ''')

    def test_reused_session_does_not_inherit_stats_or_window(self):
        self.check('''
            repair(alice,10); hello(alice); hooks['client.disconnected'](alice)
            bob=newClient('Alice',1,'STEAM_1:1:2'); Client.ClientList={bob}
            repair(bob,5); assert(count(RoundReport.stats.total)==2)
            request(bob,'!stats'); assert(#sent==0 and #chat>0)
        ''')

    def test_unauthenticated_clients_have_separate_connection_ids(self):
        self.check('''
            alice=newClient('Alice',1,nil); bob=newClient('Alice',2,nil)
            Client.ClientList={alice,bob}
            repair(alice,10); repair(bob,5); assert(count(RoundReport.stats.round)==2)
            alice.Name='Renamed'; repair(alice,3); assert(count(RoundReport.stats.round)==2)
            hooks['client.disconnected'](alice)
            alice=newClient('Renamed',1,nil); Client.ClientList={alice,bob}
            repair(alice,1); assert(count(RoundReport.stats.round)==3)
        ''')

    def test_reload_retains_identity_stats_and_window(self):
        self.check('''
            hello(alice); repair(alice,10); alice.Name='Renamed'; reload(); repair(alice,5)
            assert(only(RoundReport.stats.total).repair==15)
            request(alice,'!stats'); assert(#sent==1 and #chat==0)
        ''')

    def test_round_end_retains_totals_and_identity(self):
        self.check('''
            hello(alice); repair(alice,10); alice.Name='Renamed'; hooks.roundEnd()
            assert(count(RoundReport.stats.round)==0 and #sent==1)
            assert(only(RoundReport.stats.total).label=='Renamed')
            hooks.roundEnd(); assert(#sent==1)
            repair(alice,5)
            assert(only(RoundReport.stats.round).repair==5)
            assert(only(RoundReport.stats.total).repair==15)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
