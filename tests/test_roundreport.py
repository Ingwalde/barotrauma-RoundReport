import sys
from lupa import lua52
L = lua52.LuaRuntime(unpack_returned_tuples=True)
MOD = sys.argv[1]
import os
L.globals().MOCKS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mocks.lua')
L.execute(r'''
CLIENT = false; SERVER = true
patches, hooks, sent, printed = {}, {}, {}, {}
Hook = { HookMethodType = { Before = "Before", After = "After" } }
function Hook.Patch(id, cls, method, fn, kind) patches[method] = fn end
function Hook.Add(ev, name, fn) hooks[ev] = fn end
function Color(r,g,b,a) return {r,g,b,a} end
ChatMessageType = { Server = "Server" }
ChatMessage = { Create = function(s, text, t, a, b) return { text = text } end }
dofile(MOCKS)
netRecv, netSent = {}, {}
Networking = { Receive = function(id, fn) netRecv[id] = fn end,
  Start = function(id) local m = NewMsg(); m.id = id; return m end,
  Send = function(m, conn) netSent[#netSent+1] = { msg = m, conn = conn } end }
Game = { SendDirectChatMessage = function(msg, client) sent[#sent+1] = client.Name .. "|" .. msg.text end }
local realprint = print
print2 = print
print = function(s) printed[#printed+1] = s end
function team(n) return { tostring = n } end
local function char(name, teamid, human)
  return setmetatable({ Name = name, TeamID = teamid, IsHuman = human ~= false, IsOnPlayerTeam = teamid == "Team1", IsDead = false, Removed = false }, {__tostring=function() return name end})
end
alice = char("AliceChar", "Team1"); bob = char("BobChar", "Team1"); botty = char("Botty", "Team1")
crawler = char("Crawler", "None", false)
Client = { ClientList = { { Name = "Alice", SessionId = 1, Character = alice, Connection = "connA" }, { Name = "Bob", SessionId = 2, Character = bob, Connection = "connB" } } }
''')
L.globals().MODPATH = MOD
L.execute('chunk = loadfile(MODPATH .. "/Lua/Autorun/RoundReport.lua"); chunk(MODPATH)')
L.execute(r'''
local P = patches
-- Alice repairs 40 + 35, welds 120 of own sub, heals Bob 30
for i=1,75 do P.OnItemRepaired(nil, { character = alice, repairAmount = 1 }) end
P.OnStructureHealthChanged(nil, { attacker = alice, structure = { Submarine = { TeamID = "Team1" } }, damageAmount = -120 })
P.OnStructureHealthChanged(nil, { attacker = alice, structure = { Submarine = { TeamID = "None" } }, damageAmount = -999 }) -- ruin, ignored
P.OnCharacterHealthChanged(nil, { target = bob, attacker = alice, damage = -30 })
-- Bob shoots crawler 400, hits Alice 15, kills crawler, extinguishes 12s
P.OnCharacterHealthChanged(nil, { target = crawler, attacker = bob, damage = 400 })
P.OnCharacterHealthChanged(nil, { target = alice, attacker = bob, damage = 15 })
for i=1,720 do P.OnExtinguishingFire(nil, { character = bob, deltaTime = 1/60 }) end
crawler.CauseOfDeath = { Killer = bob }; hooks["character.death"](crawler)
-- bot dies twice; heals self (ignored)
botty.CauseOfDeath = { Killer = crawler }; hooks["character.death"](botty); hooks["character.death"](botty)
P.OnCharacterHealthChanged(nil, { target = botty, attacker = botty, damage = -50 })
netRecv["roundreport.hello.v2"](NewMsg(), Client.ClientList[1])
-- !mystats from Bob
assert(hooks.chatMessage("!MyStats", Client.ClientList[2]) == true)
assert(hooks.chatMessage("hello", Client.ClientList[2]) == nil)
hooks.roundEnd()
hooks.roundEnd() -- second call must be a no-op
hooks.chatMessage("!total", Client.ClientList[1])
''')
for s in L.globals().sent.values(): print(s)
print('--- net'); L.execute('for _, s in ipairs(netSent) do print2(s.msg.id .. " -> " .. s.conn) end')
print('--- console'); [print(s) for s in L.globals().printed.values()]
