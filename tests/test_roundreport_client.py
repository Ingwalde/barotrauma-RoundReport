import sys, os
from lupa import lua52
L = lua52.LuaRuntime(unpack_returned_tuples=True)
L.globals().MOD = sys.argv[1]
L.globals().MOCKS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mocks.lua')
L.execute(r'''
dofile(MOCKS)
CLIENT = true; SERVER = false
local realprint = print
realprint2 = print
print = function(s) realprint("LOG> " .. s) end
patches, hooks, netRecv, netSent = {}, {}, {}, {}
Hook = { HookMethodType = { Before = 1, After = 2 } }
function Hook.Patch(id, cls, m, fn, kind) patches[cls] = fn end
function Hook.Add(ev, n, fn) hooks[ev] = fn end
Networking = { Receive = function(id, fn) netRecv[id] = fn end, Start = function(id) local m = NewMsg(); m.id = id; return m end,
  Send = function(m) netSent[#netSent+1] = m.id end }
Game = { IsMultiplayer = true, Client = { Name = "Alice" } }
function Point(x, y) return { x = x, y = y } end
function Identifier(s) return s end
LuaUserData = { CreateEnumTable = function() return { Yes = "UPPER" } end }
JobPrefab = { Prefabs = { ContainsKey = function(k) return k == "mechanic" end } }
setmetatable(JobPrefab.Prefabs, { __index = function(t, k) if k == "mechanic" then return { Icon = "mech.png", UIColor = "#jobcolor" } end end })
function Color(r,g,b,a) return string.format("#%02x%02x%02x", r, g, b) end
function Vector2(x, y) return { x = x, y = y } end
-- GUI mock: components remember text, color and children
local function newRT(size, parent) local rt = { children = {}, size = size }; if parent then parent.children[#parent.children+1] = rt end; return rt end
local function comp(kind)
  return function(rt, a, b, c, d)
    local o = { kind = kind, RectTransform = rt, Visible = true }
    rt.comp = o
    if kind == "TextBlock" then o.Text, o.TextColor = a, b end
    if kind == "Button" then o.Text = a; o.TextBlock = {} end
    if kind == "Image" then o.Text = "[icon " .. tostring(a) .. "]" end
    if kind == "ListBox" then
      local crt = newRT(nil, nil)
      o.Content = { RectTransform = crt, Rect = { Width = 800 }, ClearChildren = function() crt.children = {} end }
      o.ContentBackground = {}
    end
    o.AddToGUIUpdateList = function() end
    return o
  end
end
GUI = { RectTransform = function(size, parent) local r = newRT(size, parent); ROOT = ROOT or r; return r end,
  Frame = comp("Frame"), LayoutGroup = comp("LayoutGroup"), TextBlock = comp("TextBlock"), Button = comp("Button"), ListBox = comp("ListBox"), Image = comp("Image"), IntScale = function(v) return v end,
  Anchor = {}, Alignment = {}, GUIStyle = {} }
''')
L.execute('loadfile(MOD .. "/Lua/Autorun/RoundReportClient.lua")(MOD)')
L.execute(r'''
local Net = dofile(MOD .. "/Lua/RoundReport/Net.lua")
local Stats = dofile(MOD .. "/Lua/RoundReport/Stats.lua")
local st = Stats.new()
st:add("client:Alice", "Alice", false, "repair", 75, "mechanic"); st:add("client:Alice", "Alice", false, "heal", 30)
st:add("client:Bob", "Bob", false, "damage", 400); st:add("client:Bob", "Bob", false, "kills", 1); st:add("client:Bob", "Bob", false, "deaths", 1)
st:add("bot:Botty", "Botty", true, "deaths", 2)
local m = NewMsg(); m.WriteString("round"); Net.writeTable(m, st.round, Stats.FIELDS); Net.writeTable(m, st.total, Stats.FIELDS)
netRecv["roundreport.show"](m)
-- dump the visible tree
local function texts(rt, depth, out)
  for _, ch in ipairs(rt.children) do
    local c = ch.comp
    if c and (c.kind == "TextBlock" or c.kind == "Button") and c.Text ~= "" and c.Text ~= nil then out[#out+1] = tostring(c.Text) .. (c.TextColor and (" " .. tostring(c.TextColor)) or "") end
    local allText = #ch.children > 3 and not (c and c.kind == "Button")
    for _, x in ipairs(ch.children) do if not (x.comp and (x.comp.kind == "TextBlock" or x.comp.kind == "Image")) then allText = false end end
    if c and c.kind == "LayoutGroup" and allText then
      local row = {}
      for _, cell in ipairs(ch.children) do row[#row+1] = tostring(cell.comp.Text) .. "(" .. tostring(cell.comp.TextColor) .. ")" end
      out[#out+1] = "ROW | " .. table.concat(row, " | ")
    else
      texts(ch, depth + 1, out)
      if c and c.kind == "ListBox" then texts(c.Content.RectTransform, depth + 1, out) end
    end
  end
end
local out = {}
-- root is the first RectTransform created; find via patches not needed: walk from a known global-less root
texts(ROOT, 0, out)
for _, l in ipairs(out) do realprint2(l) end
realprint2('netSent: ' .. table.concat(netSent, ','))
realprint2('root visible: ' .. tostring(ROOT.comp.Visible))
''')
