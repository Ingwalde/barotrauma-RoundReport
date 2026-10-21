-- Round Report configuration. Edit and run `reloadlua` in the server console.
return {
    -- "auto": use this game's language; unknown/new languages fall back to English.
    -- Override with a locale code from Strings.lua (e.g. "uk", "de", "zh-CN").
    -- Reload Lua after changing the game language.
    Language = "auto",

    -- Count AI crew members of the player team as well (shown with a "bot" suffix).
    IncludeBots = true,

    -- Send the report to chat automatically when the round ends.
    ReportOnRoundEnd = true,

    -- Chat commands (case-insensitive). Players type them in normal chat.
    CommandStats = "!stats",   -- current round, everyone
    CommandMe = "!mystats",    -- current round, only yourself
    CommandTotal = "!total",   -- persisted totals for the current campaign
    CommandVersion = "!rrversion", -- version, persistence state and stored record count

    -- Persist totals beside each campaign save as <save>.roundreport.tsv.
    -- Round stats intentionally start fresh after a server restart.
    PersistenceEnabled = true,
    PersistenceSuffix = ".roundreport.tsv",
    PersistenceSaveDelay = 5, -- seconds; repeated events are batched

    -- Each category awards its configured number of points according to the
    -- player's share of the qualifying team total. Set a weight to 0 to disable it.
    ScoreWeights = {
        repair = 10,
        weld = 10,
        heal = 10,
        fire = 10,
        damage = 10,
        kills = 10,
    },
    DeathPenalty = 2,
    FriendlyFirePenalty = 5,
    MeltdownDisqualifies = true,

    -- Values below these thresholds are treated as noise and not shown.
    MinRepair = 1,     -- item condition points
    MinWeld = 1,       -- wall health points
    MinHeal = 1,       -- vitality points healed on others
    MinFire = 0.5,     -- seconds of extinguishing
    MinDamage = 1,     -- damage dealt to enemies
}
