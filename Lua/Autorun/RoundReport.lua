-- Server composition root. Only this file owns reload-persistent server state.
if CLIENT then return end

local modPath = ...
local function load(name) return dofile(modPath .. "/Lua/RoundReport/" .. name .. ".lua") end
local Config, Strings, Stats = load("Config"), load("Strings"), load("Stats")
local Report, Net = load("Report"), load("Net")
local Version, Codec = load("Version"), load("PersistenceCodec")
local language = load("Language").resolveLanguage(Config.Language)
local function T(key) return Strings.get(language, key) end

RoundReport = RoundReport or {}
RoundReport.stats = RoundReport.stats or Stats.new()
RoundReport.players = RoundReport.players or { accounts = {}, sessions = {}, nextId = 0 }
if RoundReport.persistence and RoundReport.persistence.flush then
    pcall(RoundReport.persistence.flush) -- preserve debounced changes before reloadlua
end
local stats = RoundReport.stats
local persistence = load("Server/Persistence").new(
    stats, RoundReport.players, Config, Codec, Stats.FIELDS, Version)
RoundReport.persistence = persistence
persistence.ensure()
local players = load("Server/Players").new(RoundReport.players, stats, Config)

load("Server/Tracking").install(function(character, field, amount)
    persistence.ensure()
    local key, label, isBot, job = players.resolve(character)
    if key then
        stats:add(key, label, isBot, field, amount, job)
        persistence.markDirty()
    end
end)
load("Server/Delivery").install({
    stats = stats, players = players, Config = Config, Stats = Stats,
    Report = Report, Net = Net, T = T, Version = Version, persistence = persistence,
})

print("[RoundReport] loaded")
