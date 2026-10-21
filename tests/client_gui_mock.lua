-- A widget tree for client behavior tests, not a replacement for in-game testing.
CLIENT = true; SERVER = false
function print() end
dofile(MOD .. "/tests/mocks.lua")
patches, hooks, received, sent, widgets = {}, {}, {}, {}, {}
Hook = { HookMethodType = { After = 1 } }
function Hook.Patch(_, cls, _, fn) patches[cls] = fn end
function Hook.Add(event, _, fn) hooks[event] = fn end
Networking = {
    Receive = function(id, fn) received[id] = fn end,
    Start = function(id) local m = NewMsg(); m.id = id; return m end,
    Send = function(m) sent[#sent + 1] = m.id end,
}
Game = { IsMultiplayer = true, Client = { Name = "Alice" } }
function Point(x, y) return { x = x, y = y } end
function Vector2(x, y) return { x = x, y = y, relative = true } end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function Identifier(s) return s end
JobPrefab = { Prefabs = { mechanic = { Icon = "mechanic", UIColor = Color(100, 180, 220, 255) } } }
function JobPrefab.Prefabs.ContainsKey(k) return JobPrefab.Prefabs[k] ~= nil end

local function rect(size, parent, anchor)
    local w, h = SCREEN_W or 1600, SCREEN_H or 1000
    if parent then w, h = parent.Rect.Width, parent.Rect.Height end
    local r = { children = {}, size = size, anchor = anchor, Rect = {
        Width = size.relative and w * size.x or size.x,
        Height = size.relative and h * size.y or size.y,
    } }
    if parent then parent.children[#parent.children + 1] = r end
    ROOT = ROOT or r
    return r
end
local function component(kind)
    return function(rt, a, b, c, d)
        local o = { kind = kind, RectTransform = rt, Rect = rt.Rect, Visible = true }
        rt.comp = o; widgets[#widgets + 1] = o
        if kind == "Frame" then o.style = a; o.Color = b end
        if kind == "LayoutGroup" then o.horizontal = a end
        if kind == "TextBlock" then o.Text = a; o.TextColor = b end
        if kind == "Button" then o.Text = a; o.TextBlock = {} end
        if kind == "ListBox" then
            local crt = rect(Point(rt.Rect.Width - 20, rt.Rect.Height - 10))
            o.Content = { RectTransform = crt, Rect = crt.Rect, ClearChildren = function() crt.children = {} end }
            o.ContentBackground = {}
        end
        o.AddToGUIUpdateList = function() o.draws = (o.draws or 0) + 1 end
        return o
    end
end
GUI = { RectTransform = rect, Frame = component("Frame"), LayoutGroup = component("LayoutGroup"),
    TextBlock = component("TextBlock"), Button = component("Button"), Image = component("Image"),
    ListBox = component("ListBox"), IntScale = function(n) return n end,
    Anchor = { Center = "center", CenterLeft = "left", TopLeft = "topLeft" },
    Alignment = { Center = "center", CenterLeft = "left", CenterRight = "right" }, GUIStyle = {} }

-- Only walk attached children, so cleared list items cannot satisfy assertions.
function allWidgets(rt, out)
    rt = rt or ROOT; out = out or {}
    local c = rt.comp
    if c then
        out[#out + 1] = c
        if c.Content then allWidgets(c.Content.RectTransform, out) end
    end
    for _, child in ipairs(rt.children) do allWidgets(child, out) end
    return out
end
function findText(text, rt)
    for _, c in ipairs(allWidgets(rt)) do if c.Text == text then return c end end
end
function lists()
    local out = {}
    for _, c in ipairs(allWidgets()) do if c.kind == "ListBox" then out[#out + 1] = c end end
    return out
end
function show(round, total, tab)
    local Net = dofile(MOD .. "/Lua/RoundReport/Net.lua")
    local Stats = dofile(MOD .. "/Lua/RoundReport/Stats.lua")
    local m = NewMsg(); m.WriteString(tab or "round")
    Net.writeTable(m, round or {}, Stats.FIELDS); Net.writeTable(m, total or {}, Stats.FIELDS)
    received[Net.SHOW](m)
end
function sample()
    local st = dofile(MOD .. "/Lua/RoundReport/Stats.lua").new()
    st:add("p1", "Alice", false, "repair", 75, "mechanic")
    st:add("p1", "Alice", false, "heal", 30)
    st:add("p2", "Bob", false, "damage", 400, "unknownjob")
    st:add("p2", "Bob", false, "kills", 1)
    st:add("p2", "Bob", false, "deaths", 1)
    st:add("b1", "Botty", true, "deaths", 2)
    return st
end
