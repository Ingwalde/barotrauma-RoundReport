-- Native GUI view. Receives decoded reports; never reads network packets or registers hooks.
local Window = {}

function Window.new(deps)
    local Config, Stats, Report, T = deps.Config, deps.Stats, deps.Report, deps.T
    local scoring = Config
    local function scoreHelpFor(cfg)
        local title = T("score_help"):match("^[^\n]+") or T("col_score")
        local weights = cfg.ScoreWeights or {}
        local fields = {
            { "col_repair", "repair" }, { "col_weld", "weld" }, { "col_heal", "heal" },
            { "col_fire", "fire" }, { "col_damage", "damage" }, { "col_kills", "kills" },
        }
        local parts = {}
        for _, item in ipairs(fields) do
            parts[#parts + 1] = string.format("%s %g×share", T(item[1]), tonumber(weights[item[2]]) or 10)
        end
        return table.concat({
            title,
            table.concat(parts, " · "),
            string.format("%s −%g×count · FF −%g×share · %s: MVP = ∅",
                T("col_deaths"), tonumber(cfg.DeathPenalty) or 2,
                tonumber(cfg.FriendlyFirePenalty) or 5, T("stat_meltdown")),
            string.format("min: %s %g · %s %g · %s %g · %s %g · %s %g",
                T("col_repair"), cfg.MinRepair or 0, T("col_weld"), cfg.MinWeld or 0,
                T("col_heal"), cfg.MinHeal or 0, T("col_fire"), cfg.MinFire or 0,
                T("col_damage"), cfg.MinDamage or 0),
        }, "\n")
    end
    local scoreHelp = scoreHelpFor(scoring)

    -- Vanilla GUIStyle colours (GUIStyle.cs), copied as plain colours.
    local C = {
        text   = Color(228, 217, 167, 255), -- TextColorNormal
        bright = Color(255, 255, 255, 255), -- TextColorBright
        dim    = Color(153, 153, 153, 255), -- TextColorDim
        green  = Color(154, 213, 163, 255), -- Green
        red    = Color(245, 105, 105, 255), -- Red
        orange = Color(243, 162, 50, 255),  -- Orange
        own    = Color(37, 57, 48, 255),
        row    = Color(15, 29, 30, 255),
        stripe = Color(19, 35, 36, 255),
        panel  = Color(19, 36, 38, 255),
        border = Color(53, 78, 76, 255),
        base   = Color(10, 22, 24, 255),
        gold   = Color(37, 39, 31, 255),
        none   = Color(0, 0, 0, 0),
    }

    local COLUMNS = {
        { field = "job",    head = "",           width = 0.04 },
        { field = "name",   head = "col_player", width = 0.24 },
        { field = "repair", head = "col_repair", width = 0.09 },
        { field = "weld",   head = "col_weld",   width = 0.09 },
        { field = "heal",   head = "col_heal",   width = 0.09 },
        { field = "fire",   head = "col_fire",   width = 0.09 },
        { field = "damage", head = "col_damage", width = 0.09 },
        { field = "kills",  head = "col_kills",  width = 0.075 },
        { field = "deaths", head = "col_deaths", width = 0.075 },
        { field = "score",  head = "col_score",  width = 0.12 },
    }

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

    local function fitText(tb, tooltip)
        tb.AutoScaleHorizontal = true
        tb.AutoScaleVertical = true
        if tooltip then tb.ToolTip = tooltip end
        return tb
    end

    -- Plain GUIFrames use the game's drawing primitives; no new textures are needed.
    local function panel(size, parent, color, anchor)
        local frame = GUI.Frame(GUI.RectTransform(size, parent, anchor or GUI.Anchor.TopLeft), nil, color)
        frame.CanBeFocused = false
        frame.OutlineColor = C.border
        frame.OutlineThickness = 1
        return frame
    end

    local function label(size, parent, text, color, font, align)
        return fitText(GUI.TextBlock(GUI.RectTransform(size, parent), text, color,
            font or GUI.GUIStyle.SmallFont, align or GUI.Alignment.CenterLeft), text)
    end

    -- Relative heights include spacing, so the footer stays inside small displays.

    local root = GUI.Frame(GUI.RectTransform(Vector2(1, 1)), "GUIBackgroundBlocker")
    root.Visible = false

    local window = GUI.Frame(GUI.RectTransform(Vector2(0.92, 0.91), root.RectTransform, GUI.Anchor.Center), "GUIFrameLarge")
    local inner = panel(Vector2(0.975, 0.96), window.RectTransform, C.base, GUI.Anchor.Center)
    local content = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.95, 0.94), inner.RectTransform, GUI.Anchor.Center))
    content.RelativeSpacing = 0.01

    local titleRow = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.10), content.RectTransform), true, GUI.Anchor.CenterLeft)
    local heading = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.66, 1), titleRow.RectTransform))
    label(Vector2(1, 0.28), heading.RectTransform, T("log_label"), C.green)
    local title = label(Vector2(1, 0.70), heading.RectTransform, "", C.text, GUI.GUIStyle.LargeFont)
    local tabs = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.34, 0.50), titleRow.RectTransform), true)
    tabs.RelativeSpacing = 0.02
    local tabRound = GUI.Button(GUI.RectTransform(Vector2(0.49, 1), tabs.RectTransform), T("tab_round"), GUI.Alignment.Center, "GUITabButton")
    local tabTotal = GUI.Button(GUI.RectTransform(Vector2(0.49, 1), tabs.RectTransform), T("tab_total"), GUI.Alignment.Center, "GUITabButton")
    fitText(tabRound.TextBlock)
    fitText(tabTotal.TextBlock)

    local hero = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.17), content.RectTransform), true)
    hero.RelativeSpacing = 0.015
    local mvpPanel = panel(Vector2(0.43, 1), hero.RectTransform, C.gold)
    local accent = panel(Vector2(0.006, 1), mvpPanel.RectTransform, C.orange)
    accent.OutlineColor = C.none
    local mvpLayout = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.92, 0.84), mvpPanel.RectTransform, GUI.Anchor.Center), true)
    local mvpIdentity = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.72, 1), mvpLayout.RectTransform))
    label(Vector2(1, 0.24), mvpIdentity.RectTransform, T("mvp_label"), C.orange)
    local mvpText = label(Vector2(1, 0.50), mvpIdentity.RectTransform, "", C.text, GUI.GUIStyle.LargeFont)
    label(Vector2(1, 0.24), mvpIdentity.RectTransform, T("mvp_hint"), C.dim)
    local mvpPoints = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.28, 1), mvpLayout.RectTransform))
    local mvpScore = label(Vector2(1, 0.74), mvpPoints.RectTransform, "", C.orange, GUI.GUIStyle.LargeFont, GUI.Alignment.CenterRight)
    mvpScore.ToolTip = scoreHelp
    label(Vector2(1, 0.24), mvpPoints.RectTransform, T("col_score"), C.dim, nil, GUI.Alignment.CenterRight)

    local metrics = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.555, 1), hero.RectTransform), true)
    metrics.RelativeSpacing = 0.02
    local totals = {}
    for _, field in ipairs({ "repair", "heal", "kills" }) do
        local card = panel(Vector2(0.32, 1), metrics.RectTransform, C.panel)
        local body = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.86, 0.84), card.RectTransform, GUI.Anchor.Center))
        label(Vector2(1, 0.24), body.RectTransform, T("col_" .. field), C.green)
        totals[field] = label(Vector2(1, 0.50), body.RectTransform, "", C.text, GUI.GUIStyle.LargeFont)
        label(Vector2(1, 0.24), body.RectTransform, T("team_total"), C.dim)
    end

    local rosterHeading = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.045), content.RectTransform), true)
    label(Vector2(0.55, 1), rosterHeading.RectTransform, T("crew_heading"), C.text, GUI.GUIStyle.SubHeadingFont)
    local crewCount = label(Vector2(0.45, 1), rosterHeading.RectTransform, "", C.dim, nil, GUI.Alignment.CenterRight)

    -- Shared column widths keep crew values and their headers in the same order.
    -- Match the list's content width (scrollbar excluded), not its outer width.
    local headerRow = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.035), content.RectTransform), true)
    for _, col in ipairs(COLUMNS) do
        local header = label(Vector2(col.width, 1), headerRow.RectTransform, col.head ~= "" and T(col.head) or "", C.dim, nil,
            col.field == "name" and GUI.Alignment.CenterLeft or GUI.Alignment.Center)
        if col.field == "score" then header.ToolTip = scoreHelp end
    end

    local crewList = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.35), content.RectTransform))
    crewList.AutoHideScrollBar = false
    crewList.ContentBackground.Color = C.none

    -- Positive contributions and incidents have separate native panels and scroll areas.
    local debrief = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.18), content.RectTransform), true)
    debrief.RelativeSpacing = 0.01
    local function reportPanel(width, heading, color)
        local frame = panel(Vector2(width, 1), debrief.RectTransform, C.panel)
        local body = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.94, 0.86), frame.RectTransform, GUI.Anchor.Center))
        body.RelativeSpacing = 0.04
        fitText(GUI.TextBlock(GUI.RectTransform(Vector2(1, 0.22), body.RectTransform), heading, color, GUI.GUIStyle.SubHeadingFont, GUI.Alignment.CenterLeft))
        local list = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.74), body.RectTransform))
        list.ContentBackground.Color = C.none
        return list
    end
    local awardList = reportPanel(0.60, T("awards"), C.green)
    local incidentList = reportPanel(0.39, T("incidents"), C.orange)

    local buttonArea = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.05), content.RectTransform), true)
    label(Vector2(0.84, 1), buttonArea.RectTransform, T("report_hint"), C.dim)
    local closeButton = GUI.Button(GUI.RectTransform(Vector2(0.16, 1), buttonArea.RectTransform), T("close"), GUI.Alignment.Center)
    fitText(closeButton.TextBlock)

    -- Rendering ----------------------------------------------------------------------------

    local function fmt(v)
        v = math.floor((v or 0) + 0.5)
        if v == 0 then return "-" end
        return tostring(v)
    end

    local function cellText(parent, width, text, color, align, font)
        return fitText(GUI.TextBlock(GUI.RectTransform(Vector2(width, 1), parent.RectTransform), text, color, font or GUI.GUIStyle.SmallFont, align or GUI.Alignment.Center), text)
    end

    local function addRow(row, s, me, index)
        local h = GUI.IntScale(44)
        local isOwn = me ~= nil and row.e.label == me and not row.e.isBot
        local frame = panel(Point(crewList.Content.Rect.Width, h), crewList.Content.RectTransform,
            isOwn and C.own or (index % 2 == 0 and C.stripe or C.row))
        frame.OutlineColor = C.none
        if isOwn then
            local marker = panel(Vector2(0.003, 1), frame.RectTransform, C.green)
            marker.OutlineColor = C.none
        end

        local padded = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.9), frame.RectTransform, GUI.Anchor.Center), true)

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
                cellText(padded, col.width, name, C.text, GUI.Alignment.CenterLeft)
            elseif col.field == "score" then
                local text = row.score ~= 0 and string.format("%.1f", row.score) or "-"
                local color = row.score < 0 and C.red or (row.key == s.mvpKey and C.orange or (text == "-" and C.dim or C.text))
                local scoreCell = GUI.LayoutGroup(GUI.RectTransform(Vector2(col.width, 1), padded.RectTransform))
                local scoreLabel = label(Vector2(1, 0.80), scoreCell.RectTransform, text, color, GUI.GUIStyle.SubHeadingFont, GUI.Alignment.Center)
                scoreLabel.ToolTip = scoreHelp
                if row.score > 0 and s.mvpScore then
                    local track = panel(Vector2(0.80, 0.06), scoreCell.RectTransform, C.border)
                    track.OutlineColor = C.none
                    local bar = panel(Vector2(math.min(1, row.score / s.mvpScore), 1), track.RectTransform, color)
                    bar.OutlineColor = C.none
                end
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

    local function addNotice(list, text, color)
        fitText(GUI.TextBlock(GUI.RectTransform(Point(list.Content.Rect.Width, GUI.IntScale(28)), list.Content.RectTransform),
            text, color, GUI.GUIStyle.SmallFont, GUI.Alignment.CenterLeft), text)
    end

    local function render(tab)
        tabRound.Selected = tab == "round"
        tabTotal.Selected = tab == "total"
        title.Text = T(tab == "round" and "win_round" or "win_total")

        local tbl = data[tab] or {}
        local s = Report.summary(tbl, scoring)
        crewCount.Text = string.format(T("crew_count"), #s.rows)
        for field, value in pairs(totals) do
            local total = 0
            for _, entry in pairs(tbl) do total = total + (entry[field] or 0) end
            value.Text = tostring(math.floor(total + 0.5))
        end

        if s.mvpKey then
            mvpText.Text = Report.displayName(tbl[s.mvpKey], T)
            mvpText.TextColor = C.text
            mvpScore.Text = string.format("%.1f", s.mvpScore)
        else
            mvpText.Text = Stats.isEmpty(tbl) and T("no_data") or T("no_mvp")
            mvpText.TextColor = C.dim
            mvpScore.Text = "-"
        end
        mvpText.ToolTip = mvpText.Text

        crewList.Content.ClearChildren()
        headerRow.RectTransform.RelativeSize = Vector2(crewList.Content.Rect.Width / content.Rect.Width, 0.035)
        local me = ownName()
        for index, row in ipairs(s.rows) do addRow(row, s, me, index) end
        if #s.rows == 0 then addNotice(crewList, T("no_data"), C.dim) end

        awardList.Content.ClearChildren()
        incidentList.Content.ClearChildren()
        local awards, incidents = 0, 0
        for _, t in ipairs(s.titles) do
            if BAD[t.id] then
                addNotice(incidentList, Report.titleText(t, tbl, T), C.red)
                incidents = incidents + 1
            else
                addNotice(awardList, Report.titleText(t, tbl, T), C.green)
                awards = awards + 1
            end
        end
        if awards == 0 then addNotice(awardList, T("no_awards"), C.dim) end
        if incidents == 0 then addNotice(incidentList, T("no_incidents"), C.dim) end
    end

    local function open(tab)
        render(tab)
        root.Visible = true
    end

    tabRound.OnClicked = function() render("round"); return true end
    tabTotal.OnClicked = function() render("total"); return true end
    closeButton.OnClicked = function() root.Visible = false; return true end


    return {
        show = function(round, total, tab, serverScoring)
            data.round, data.total = round, total
            scoring = serverScoring or Config
            scoreHelp = scoreHelpFor(scoring)
            mvpScore.ToolTip = scoreHelp
            for _, child in ipairs(headerRow.RectTransform.children) do
                if child.comp and child.comp.Text == T("col_score") then child.comp.ToolTip = scoreHelp end
            end
            open(tab == "total" and "total" or "round")
        end,
        update = function()
            if root.Visible then root.AddToGUIUpdateList(false, 10) end
        end,
    }
end

return Window
