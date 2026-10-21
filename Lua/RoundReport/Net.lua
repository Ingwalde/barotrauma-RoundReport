-- Encoding of stats tables for LuaCs net messages (server -> client).
-- Format: UInt16 count, then per entry: String key, String label, String job, Boolean isBot,
-- and one Single per field in Stats.FIELDS order.
local Net = {}

-- Versioned message IDs make mixed mod versions fall back to chat instead of
-- decoding an incompatible payload.
Net.HELLO = "roundreport.hello.v2" -- client -> server: "I can decode protocol v2"
Net.SHOW = "roundreport.show.v2"   -- server -> client: scoring rules + report data

local SCORE_FIELDS = { "repair", "weld", "heal", "fire", "damage", "kills" }

function Net.writeScoring(msg, config)
    local weights = config.ScoreWeights or {}
    for _, field in ipairs(SCORE_FIELDS) do msg.WriteSingle(tonumber(weights[field]) or 10) end
    msg.WriteSingle(tonumber(config.DeathPenalty) or 2)
    msg.WriteSingle(tonumber(config.FriendlyFirePenalty) or 5)
    msg.WriteBoolean(config.MeltdownDisqualifies ~= false)
    for _, field in ipairs({ "MinRepair", "MinWeld", "MinHeal", "MinFire", "MinDamage" }) do
        msg.WriteSingle(tonumber(config[field]) or 0)
    end
end

function Net.readScoring(msg)
    local config = { ScoreWeights = {} }
    for _, field in ipairs(SCORE_FIELDS) do config.ScoreWeights[field] = msg.ReadSingle() end
    config.DeathPenalty = msg.ReadSingle()
    config.FriendlyFirePenalty = msg.ReadSingle()
    config.MeltdownDisqualifies = msg.ReadBoolean()
    for _, field in ipairs({ "MinRepair", "MinWeld", "MinHeal", "MinFire", "MinDamage" }) do
        config[field] = msg.ReadSingle()
    end
    return config
end

function Net.writeTable(msg, tbl, fields)
    local keys = {}
    for key in pairs(tbl) do keys[#keys + 1] = key end
    table.sort(keys)
    msg.WriteUInt16(#keys)
    for _, key in ipairs(keys) do
        local e = tbl[key]
        msg.WriteString(key)
        msg.WriteString(e.label)
        msg.WriteString(e.job or "")
        msg.WriteBoolean(e.isBot)
        for _, f in ipairs(fields) do msg.WriteSingle(e[f] or 0) end
    end
end

function Net.readTable(msg, fields)
    local tbl = {}
    local count = msg.ReadUInt16()
    for _ = 1, count do
        local key = msg.ReadString()
        local label = msg.ReadString()
        local job = msg.ReadString()
        local e = { label = label, job = job ~= "" and job or nil, isBot = msg.ReadBoolean() }
        for _, f in ipairs(fields) do e[f] = msg.ReadSingle() end
        tbl[key] = e
    end
    return tbl
end

return Net
