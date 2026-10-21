"""Persistence, configurable scoring and protocol regressions for version 0.5."""
from pathlib import Path
import unittest

from lupa import lua52

ROOT = Path(__file__).resolve().parents[1]


class Version05Tests(unittest.TestCase):
    def setUp(self):
        self.lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().MOD = ROOT.as_posix()
        self.lua.execute("dofile(MOD .. '/tests/mocks.lua')")

    def test_totals_are_isolated_by_campaign_and_restore_accounts(self):
        self.lua.execute('''
            local Stats = dofile(MOD .. '/Lua/RoundReport/Stats.lua')
            local Codec = dofile(MOD .. '/Lua/RoundReport/PersistenceCodec.lua')
            local Persistence = dofile(MOD .. '/Lua/RoundReport/Server/Persistence.lua')
            files, callbacks, campaign = {}, {}, nil
            local adapter = {
                campaignPath=function() return campaign end,
                exists=function(path) return files[path] ~= nil end,
                read=function(path) return files[path] end,
                writeAtomic=function(path, content) files[path]=content; return true end,
                schedule=function(_, callback) callbacks[#callbacks+1]=callback end,
                log=function() end,
            }
            config={PersistenceEnabled=true,PersistenceSuffix='.rr',PersistenceSaveDelay=5}
            stats=Stats.new(); players={accounts={},sessions={},nextId=0}
            persistence=Persistence.new(stats,players,config,Codec,Stats.FIELDS,'0.5.0',adapter)

            campaign='alpha.save'; persistence.ensure()
            stats:add('player:1','Alex',false,'repair',12,'mechanic')
            players.accounts['steam:1']='player:1'; players.nextId=1
            persistence.markDirty(); assert(#callbacks==1); callbacks[1]()
            assert(files['alpha.save.rr']:find('Alex',1,true))

            campaign='beta.save'; persistence.ensure()
            assert(next(stats.total)==nil and next(players.accounts)==nil)
            stats:add('player:1','Morgan',false,'heal',7,'medicaldoctor')
            players.accounts['steam:2']='player:1'; players.nextId=1
            persistence.markDirty(); persistence.flush()

            campaign='alpha.save'; persistence.ensure()
            assert(stats.total['player:1'].label=='Alex')
            assert(stats.total['player:1'].repair==12 and stats.total['player:1'].heal==0)
            assert(players.accounts['steam:1']=='player:1' and players.accounts['steam:2']==nil)
            assert(persistence.status().records==1)
        ''')

    def test_corrupt_primary_uses_backup(self):
        self.lua.execute('''
            local Stats = dofile(MOD .. '/Lua/RoundReport/Stats.lua')
            local Codec = dofile(MOD .. '/Lua/RoundReport/PersistenceCodec.lua')
            local Persistence = dofile(MOD .. '/Lua/RoundReport/Server/Persistence.lua')
            local source=Stats.new(); source:add('p','Backup crew',false,'kills',3)
            local good=Codec.encode(source.total,{accounts={},nextId=0},Stats.FIELDS,'0.5.0')
            local files={['save.rr']='broken',['save.rr.bak']=good}
            local adapter={campaignPath=function() return 'save' end,
              exists=function(p) return files[p]~=nil end,read=function(p) return files[p] end,
              writeAtomic=function() return true end,schedule=function() end,log=function() end}
            local stats=Stats.new(); local players={accounts={},sessions={},nextId=0}
            Persistence.new(stats,players,{PersistenceEnabled=true,PersistenceSuffix='.rr'},
              Codec,Stats.FIELDS,'0.5.0',adapter).ensure()
            assert(stats.total.p.label=='Backup crew' and stats.total.p.kills==3)
        ''')

    def test_reload_same_campaign_keeps_round_and_window_sessions(self):
        self.lua.execute('''
            local Stats = dofile(MOD .. '/Lua/RoundReport/Stats.lua')
            local Codec = dofile(MOD .. '/Lua/RoundReport/PersistenceCodec.lua')
            local Persistence = dofile(MOD .. '/Lua/RoundReport/Server/Persistence.lua')
            local files={}; local adapter={campaignPath=function() return 'same.save' end,
              exists=function(p) return files[p]~=nil end,read=function(p) return files[p] end,
              writeAtomic=function(p,c) files[p]=c; return true end,
              schedule=function() end,log=function() end}
            local cfg={PersistenceEnabled=true,PersistenceSuffix='.rr'}
            local stats=Stats.new(); local players={accounts={},sessions={},nextId=0}
            local first=Persistence.new(stats,players,cfg,Codec,Stats.FIELDS,'0.5.0',adapter)
            first.ensure(); stats:add('p','Alex',false,'repair',9)
            players.sessions[7]={key='p',window=true}; first.markDirty(); first.flush()
            local second=Persistence.new(stats,players,cfg,Codec,Stats.FIELDS,'0.5.0',adapter)
            second.ensure()
            assert(stats.round.p.repair==9 and stats.total.p.repair==9)
            assert(players.sessions[7].window==true)
        ''')

    def test_custom_weights_penalties_and_meltdown_switch(self):
        self.lua.execute('''
            local Stats=dofile(MOD .. '/Lua/RoundReport/Stats.lua')
            local Report=dofile(MOD .. '/Lua/RoundReport/Report.lua')
            local st=Stats.new()
            st:add('a','Alex',false,'repair',75); st:add('b','Morgan',false,'repair',25)
            st:add('a','Alex',false,'deaths',1); st:add('a','Alex',false,'ff',20)
            st:add('b','Morgan',false,'ff',20); st:add('a','Alex',false,'meltdown',1)
            local cfg={MinRepair=1,MinWeld=1,MinHeal=1,MinFire=.5,MinDamage=1,
              ScoreWeights={repair=20,weld=0,heal=0,fire=0,damage=0,kills=0},
              DeathPenalty=3,FriendlyFirePenalty=8,MeltdownDisqualifies=false}
            local scores=Report.scores(st.total,cfg)
            assert(math.abs(scores.a-8)<.001 and math.abs(scores.b-1)<.001)
            cfg.MeltdownDisqualifies=true
            assert(Report.scores(st.total,cfg).a==nil)
        ''')

    def test_scoring_configuration_round_trips_over_network(self):
        self.lua.execute('''
            local Net=dofile(MOD .. '/Lua/RoundReport/Net.lua')
            local msg=NewMsg()
            local cfg={ScoreWeights={repair=1,weld=2,heal=3,fire=4,damage=5,kills=6},
              DeathPenalty=7,FriendlyFirePenalty=8,MeltdownDisqualifies=false,
              MinRepair=9,MinWeld=10,MinHeal=11,MinFire=12,MinDamage=13}
            Net.writeScoring(msg,cfg); local out=Net.readScoring(msg)
            assert(out.ScoreWeights.repair==1 and out.ScoreWeights.kills==6)
            assert(out.DeathPenalty==7 and out.FriendlyFirePenalty==8)
            assert(out.MeltdownDisqualifies==false and out.MinDamage==13)
        ''')


if __name__ == '__main__':
    unittest.main()
