-- Builds the report lines from a stats table. Pure function, no game API calls.
local Report = {}

-- Categories that count towards MVP, with the config key holding their noise threshold.
Report.POSITIVE = {
    { field = "repair", min = "MinRepair", title = "title_repair" },
    { field = "weld",   min = "MinWeld",   title = "title_weld" },
    { field = "heal",   min = "MinHeal",   title = "title_heal" },
    { field = "fire",   min = "MinFire",   title = "title_fire" },
    { field = "damage", min = "MinDamage", title = "title_damage" },
    { field = "kills",  min = nil,         title = nil },
}

local function minFor(cfg, cat)
    if cat.min == nil then return 0 end
    return cfg[cat.min] or 0
end

local function sortedEntries(tbl)
    local list = {}
    for key, e in pairs(tbl) do
        list[#list + 1] = { key = key, e = e }
    end
    table.sort(list, function(a, b) return a.e.label < b.e.label end)
    return list
end

-- MVP score: for every positive category, a player's share of the team total, times 10.
-- Unit-free, so repairing, healing and killing are worth the same at equal dominance.
function Report.scores(tbl, cfg)
    local scores = {}
    for _, cat in ipairs(Report.POSITIVE) do
        local total = 0
        for _, e in pairs(tbl) do
            if e[cat.field] >= minFor(cfg, cat) then total = total + e[cat.field] end
        end
        if total > 0 then
            for key, e in pairs(tbl) do
                if e[cat.field] >= minFor(cfg, cat) then
                    scores[key] = (scores[key] or 0) + e[cat.field] / total * 10
                end
            end
        end
    end
    -- penalties: each death costs 2 points, friendly fire costs up to 5 (by share of the
    -- team's friendly fire), and a reactor meltdown wipes out your claim to MVP
    local ffTotal = 0
    for _, e in pairs(tbl) do ffTotal = ffTotal + e.ff end
    for key, e in pairs(tbl) do
        if scores[key] then
            scores[key] = scores[key] - 2 * e.deaths
            if ffTotal > 0 then scores[key] = scores[key] - e.ff / ffTotal * 5 end
        end
        if e.meltdown > 0 then scores[key] = nil end
    end
    return scores
end

local function best(tbl, field, threshold)
    local bestKey, bestVal = nil, nil
    for key, e in pairs(tbl) do
        local v = e[field]
        if v > 0 and v >= threshold then
            if bestKey == nil or v > bestVal or (v == bestVal and e.label < tbl[bestKey].label) then
                bestKey, bestVal = key, v
            end
        end
    end
    return bestKey
end

local function displayName(e, T)
    if e.isBot then return e.label .. " (" .. T("bot") .. ")" end
    return e.label
end

-- opts.personal = true: only the stats line, no titles and no MVP.
function Report.build(tbl, cfg, T, header, opts)
    opts = opts or {}
    local lines = { T(header or "header") }
    if next(tbl) == nil then
        lines[#lines + 1] = T("no_data")
        return lines
    end

    -- per-player line
    for _, item in ipairs(sortedEntries(tbl)) do
        local e = item.e
        local parts = {}
        local function add(field, key, threshold)
            if e[field] >= (threshold or 1) and e[field] > 0 then
                parts[#parts + 1] = string.format(T(key), math.floor(e[field] + 0.5))
            end
        end
        add("repair", "stat_repair", cfg.MinRepair)
        add("weld", "stat_weld", cfg.MinWeld)
        add("heal", "stat_heal", cfg.MinHeal)
        add("fire", "stat_fire", cfg.MinFire)
        add("damage", "stat_damage", cfg.MinDamage)
        add("kills", "stat_kills")
        add("deaths", "stat_deaths")
        add("ff", "stat_ff")
        add("hull", "stat_hull")
        if e.meltdown > 0 then parts[#parts + 1] = T("stat_meltdown") end
        if #parts > 0 then
            lines[#lines + 1] = string.format(T("line"), displayName(e, T), table.concat(parts, ", "))
        end
    end

    if opts.personal then
        if #lines == 1 then lines[#lines + 1] = T("no_data") end
        return lines
    end

    local s = Report.summary(tbl, cfg)
    for _, title in ipairs(s.titles) do
        lines[#lines + 1] = Report.titleText(title, tbl, T)
    end
    if s.mvpKey then
        lines[#lines + 1] = string.format(T("mvp"), displayName(tbl[s.mvpKey], T), s.mvpScore)
    end
    return lines
end

Report.displayName = displayName

-- Text of one award entry from Report.summary().titles.
function Report.titleText(title, tbl, T)
    local e = tbl[title.key]
    if title.id == "title_deaths" then
        return string.format(T(title.id), displayName(e, T), e.deaths)
    end
    return string.format(T(title.id), displayName(e, T))
end

-- Structured result shared by the chat report and the GUI window:
--   rows      = list of { key, e, score } sorted by score (desc), then name
--   titles    = list of { id = string key, key = player key }
--   best      = field -> player key with the highest value (for highlighting)
--   mvpKey, mvpScore
function Report.summary(tbl, cfg)
    local out = { rows = {}, titles = {}, best = {} }
    local scores = Report.scores(tbl, cfg)

    for key, e in pairs(tbl) do
        out.rows[#out.rows + 1] = { key = key, e = e, score = scores[key] or 0 }
    end
    table.sort(out.rows, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.e.label < b.e.label
    end)

    for _, cat in ipairs(Report.POSITIVE) do
        local key = best(tbl, cat.field, minFor(cfg, cat))
        out.best[cat.field] = key
        if key and cat.title then out.titles[#out.titles + 1] = { id = cat.title, key = key } end
    end
    local deathKey = best(tbl, "deaths", 2)
    if deathKey then out.titles[#out.titles + 1] = { id = "title_deaths", key = deathKey } end
    local ffKey = best(tbl, "ff", 10)
    if ffKey then out.titles[#out.titles + 1] = { id = "title_ff", key = ffKey } end
    for _, item in ipairs(sortedEntries(tbl)) do
        if item.e.meltdown > 0 then out.titles[#out.titles + 1] = { id = "title_meltdown", key = item.key } end
    end

    for key, s in pairs(scores) do
        if s > 0 and (out.mvpKey == nil or s > out.mvpScore or (s == out.mvpScore and tbl[key].label < tbl[out.mvpKey].label)) then
            out.mvpKey, out.mvpScore = key, s
        end
    end
    return out
end

return Report
