-- Round Report window (client side). Needs the client-side LuaCs patch on this player's game.
-- The server sends the stats after every round (and on !stats / !total); this script draws
-- them as a window that copies the look of the vanilla round summary (RoundSummary.cs):
-- GUIBackgroundBlocker behind, a default frame with an "InnerFrame" inside, column headers
-- made of "GUIButtonSmallFreeScale" buttons in HotkeyFont, rows in "ListBoxElement" frames
-- 45 px high with the job icon and the name in the job colour, and the vanilla text colours.

if SERVER then return end

local modPath = ...
local function load(name) return dofile(modPath .. "/Lua/RoundReport/" .. name .. ".lua") end

local Config = load("Config")
local Strings = load("Strings")
local Stats = load("Stats")
local Report = load("Report")
local Net = load("Net")

local function T(key) return Strings.get(Config.Language, key) end

-- Vanilla GUIStyle colours (GUIStyle.cs), copied as plain colours.
local C = {
    text   = Color(228, 217, 167, 255), -- TextColorNormal
    bright = Color(255, 255, 255, 255), -- TextColorBright
    dim    = Color(153, 153, 153, 255), -- TextColorDim
    green  = Color(154, 213, 163, 255), -- Green
    red    = Color(245, 105, 105, 255), -- Red
    orange = Color(243, 162, 50, 255),  -- Orange
    own    = Color(178, 150, 0, 178),   -- TabMenu.OwnCharacterBGColor (Gold * 0.7)
    none   = Color(0, 0, 0, 0),
}

local COLUMNS = {
    { field = "job",    head = "",           width = 0.06 },
    { field = "name",   head = "col_player", width = 0.20 },
    { field = "repair", head = "col_repair", width = 0.0925 },
    { field = "weld",   head = "col_weld",   width = 0.0925 },
    { field = "heal",   head = "col_heal",   width = 0.0925 },
    { field = "fire",   head = "col_fire",   width = 0.0925 },
    { field = "damage", head = "col_damage", width = 0.0925 },
    { field = "kills",  head = "col_kills",  width = 0.0925 },
    { field = "deaths", head = "col_deaths", width = 0.0925 },
    { field = "score",  head = "col_score",  width = 0.0925 },
}

local upperCase = nil
pcall(function() upperCase = LuaUserData.CreateEnumTable("Barotrauma.ForceUpperCase").Yes end)

local function jobPrefab(id)
    if id == nil then return nil end
    local ok, prefab = pcall(function()
        local key = Identifier(id)
        if JobPrefab.Prefabs.ContainsKey(key) then return JobPrefab.Prefabs[key] end
        return nil
    end)
    if ok then return prefab end
    return nil
end

local function ownName()
    local ok, name = pcall(function() return Game.Client.Name end)
    if ok then return name end
    return nil
end

local data = { round = {}, total = {} }

-- Layout (built once) ---------------------------------------------------------------

local root = GUI.Frame(GUI.RectTransform(Vector2(1, 1)), "GUIBackgroundBlocker")
root.Visible = false

local window = GUI.Frame(GUI.RectTransform(Vector2(0.56, 0.68), root.RectTransform, GUI.Anchor.Center, nil, Point(720, 480)))
local inner = GUI.Frame(GUI.RectTransform(Vector2(0.96, 0.94), window.RectTransform, GUI.Anchor.Center), "InnerFrame")
local content = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.95, 0.95), inner.RectTransform, GUI.Anchor.Center))
content.RelativeSpacing = 0.012

-- title row: big header on the left, tab buttons on the right
local titleRow = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.08), content.RectTransform), true, GUI.Anchor.CenterLeft)
local title = GUI.TextBlock(GUI.RectTransform(Vector2(0.6, 1), titleRow.RectTransform), "", C.text, GUI.GUIStyle.LargeFont, GUI.Alignment.CenterLeft)
local tabRound = GUI.Button(GUI.RectTransform(Vector2(0.2, 0.8), titleRow.RectTransform), T("tab_round"), GUI.Alignment.Center, "GUITabButton")
local tabTotal = GUI.Button(GUI.RectTransform(Vector2(0.2, 0.8), titleRow.RectTransform), T("tab_total"), GUI.Alignment.Center, "GUITabButton")

GUI.Frame(GUI.RectTransform(Vector2(1, 0.01), content.RectTransform), "HorizontalLine")

local mvpText = GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.06), content.RectTransform), "", C.orange, GUI.GUIStyle.SubHeadingFont, GUI.Alignment.CenterLeft)

-- column headers, styled like the vanilla crew list headers
local headerRow = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.05), content.RectTransform), true)
headerRow.AbsoluteSpacing = 2
headerRow.Stretch = true
for _, col in ipairs(COLUMNS) do
    local b = GUI.Button(GUI.RectTransform(Vector2(col.width, 1), headerRow.RectTransform), col.head ~= "" and T(col.head) or "", GUI.Alignment.Center, "GUIButtonSmallFreeScale")
    b.CanBeFocused = false
    pcall(function() b.TextBlock.Font = GUI.GUIStyle.HotkeyFont end)
    if upperCase ~= nil then pcall(function() b.ForceUpperCase = upperCase end) end
end

local crewList = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.46), content.RectTransform))
pcall(function()
    crewList.AutoHideScrollBar = false
    crewList.ContentBackground.Color = C.none
end)

GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.055), content.RectTransform), T("awards"), C.text, GUI.GUIStyle.SubHeadingFont, GUI.Alignment.CenterLeft)
local awardList = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.17), content.RectTransform))
pcall(function() awardList.ContentBackground.Color = C.none end)

local buttonArea = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.07), content.RectTransform), true, GUI.Anchor.CenterRight)
local closeButton = GUI.Button(GUI.RectTransform(Vector2(0.22, 1), buttonArea.RectTransform), T("close"), GUI.Alignment.Center)

-- Rendering ----------------------------------------------------------------------------

local function fmt(v)
    v = math.floor((v or 0) + 0.5)
    if v == 0 then return "-" end
    return tostring(v)
end

local function cellText(parent, width, text, color, align, font)
    local tb = GUI.TextBlock(GUI.RectTransform(Vector2(width, 1), parent.RectTransform), text, color, font, align or GUI.Alignment.Center)
    tb.CanBeFocused = false
    return tb
end

local function addRow(row, s, me)
    local h = GUI.IntScale(45)
    local frame = GUI.Frame(GUI.RectTransform(Point(crewList.Content.Rect.Width, h), crewList.Content.RectTransform), "ListBoxElement")
    frame.CanBeFocused = false
    frame.Color = (me ~= nil and row.e.label == me and not row.e.isBot) and C.own or C.none

    local padded = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.9), frame.RectTransform, GUI.Anchor.Center), true)
    padded.AbsoluteSpacing = 2
    padded.Stretch = true

    local job = jobPrefab(row.e.job)
    for _, col in ipairs(COLUMNS) do
        if col.field == "job" then
            if job ~= nil and job.Icon ~= nil then
                local img = GUI.Image(GUI.RectTransform(Vector2(col.width, 1), padded.RectTransform), job.Icon, true)
                img.Color = job.UIColor
                img.CanBeFocused = false
            else
                cellText(padded, col.width, "", C.text)
            end
        elseif col.field == "name" then
            local name = Report.displayName(row.e, T)
            local color = job and job.UIColor or C.text
            if row.key == s.mvpKey then name = name .. "  *" end
            cellText(padded, col.width, name, color, GUI.Alignment.Center)
        elseif col.field == "score" then
            local text = row.score > 0 and string.format("%.1f", row.score) or "-"
            cellText(padded, col.width, text, row.key == s.mvpKey and C.orange or (text == "-" and C.dim or C.text))
        else
            local text = fmt(row.e[col.field])
            local color = C.text
            if text == "-" then
                color = C.dim
            elseif col.field == "deaths" then
                color = C.red
            elseif s.best[col.field] == row.key then
                color = C.green
            end
            cellText(padded, col.width, text, color)
        end
    end
end

local BAD = { title_deaths = true, title_ff = true, title_meltdown = true }

local function render(tab)
    tabRound.Selected = tab == "round"
    tabTotal.Selected = tab == "total"
    title.Text = T(tab == "round" and "win_round" or "win_total")

    local tbl = data[tab] or {}
    local s = Report.summary(tbl, Config)

    if s.mvpKey then
        mvpText.Text = string.format(T("mvp_banner"), Report.displayName(tbl[s.mvpKey], T))
        mvpText.TextColor = C.orange
    else
        mvpText.Text = Stats.isEmpty(tbl) and T("no_data") or T("no_mvp")
        mvpText.TextColor = C.dim
    end

    crewList.Content.ClearChildren()
    local me = ownName()
    for _, row in ipairs(s.rows) do addRow(row, s, me) end

    awardList.Content.ClearChildren()
    for _, t in ipairs(s.titles) do
        local tb = GUI.TextBlock(GUI.RectTransform(Point(awardList.Content.Rect.Width, GUI.IntScale(26)), awardList.Content.RectTransform),
            Report.titleText(t, tbl, T), BAD[t.id] and C.red or C.green, nil, GUI.Alignment.CenterLeft)
        tb.CanBeFocused = false
    end
end

local function open(tab)
    render(tab)
    root.Visible = true
end

tabRound.OnClicked = function() render("round"); return true end
tabTotal.OnClicked = function() render("total"); return true end
closeButton.OnClicked = function() root.Visible = false; return true end

-- Draw on top of the game and the lobby while open.
local function addToUpdateList()
    if root.Visible then root.AddToGUIUpdateList(false, 10) end
end
Hook.Patch("roundreport.gui.game", "Barotrauma.GameScreen", "AddToGUIUpdateList", addToUpdateList, Hook.HookMethodType.After)
Hook.Patch("roundreport.gui.lobby", "Barotrauma.NetLobbyScreen", "AddToGUIUpdateList", addToUpdateList, Hook.HookMethodType.After)

-- Networking -------------------------------------------------------------------------

Networking.Receive(Net.SHOW, function(message)
    local tab = message.ReadString()
    data.round = Net.readTable(message, Stats.FIELDS)
    data.total = Net.readTable(message, Stats.FIELDS)
    open(tab == "total" and "total" or "round")
end)

-- Tell the server we can show the window. Sent on load and at every round start,
-- so reconnecting or joining mid-session is covered.
local function hello()
    if not Game.IsMultiplayer then return end
    local ok, err = pcall(function()
        Networking.Send(Networking.Start(Net.HELLO))
    end)
    if not ok then print("[RoundReport] hello failed: " .. tostring(err)) end
end

hello()
Hook.Add("roundStart", "roundreport.hello", hello)

print("[RoundReport] client window loaded")
