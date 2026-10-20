-- Pure stat bookkeeping, no game API calls (so it can be tested outside the game).
local Stats = {}
Stats.__index = Stats

Stats.FIELDS = { "repair", "weld", "heal", "fire", "damage", "kills", "deaths", "ff", "hull", "meltdown" }

local function newEntry(label, isBot)
    local e = { label = label, isBot = isBot and true or false }
    for _, f in ipairs(Stats.FIELDS) do e[f] = 0 end
    return e
end

function Stats.new()
    return setmetatable({ round = {}, total = {} }, Stats)
end

local function addTo(tbl, key, label, isBot, field, amount, job)
    local e = tbl[key]
    if e == nil then
        e = newEntry(label, isBot)
        tbl[key] = e
    end
    -- keep the latest label (a player may rename or respawn as a new character)
    e.label = label
    if job ~= nil and job ~= "" then e.job = job end
    e[field] = e[field] + amount
end

-- job: job identifier (e.g. "mechanic"), used for the job icon in the window. Optional.
function Stats:add(key, label, isBot, field, amount, job)
    if key == nil or amount == nil or amount ~= amount then return end -- skip nil and NaN
    if amount == 0 then return end
    addTo(self.round, key, label, isBot, field, amount, job)
    addTo(self.total, key, label, isBot, field, amount, job)
end

function Stats:resetRound()
    self.round = {}
end

function Stats.isEmpty(tbl)
    return next(tbl) == nil
end

return Stats
