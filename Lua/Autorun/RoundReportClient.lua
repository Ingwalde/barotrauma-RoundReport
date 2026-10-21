-- Client composition root. Builds the view and connects it to LuaCs events.
if SERVER then return end

local modPath = ...
local function load(name) return dofile(modPath .. "/Lua/RoundReport/" .. name .. ".lua") end
local Config, Strings, Stats = load("Config"), load("Strings"), load("Stats")
local Report, Net = load("Report"), load("Net")
local language = load("Language").resolveLanguage(Config.Language)
local window = load("Client/Window").new({
    Config = Config, Stats = Stats, Report = Report,
    T = function(key) return Strings.get(language, key) end,
})
load("Client/Controller").install(window, Net, Stats)

print("[RoundReport] client window loaded")
