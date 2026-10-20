-- Encoding of stats tables for LuaCs net messages (server -> client).
-- Format: UInt16 count, then per entry: String key, String label, String job, Boolean isBot,
-- and one Single per field in Stats.FIELDS order.
local Net = {}

Net.HELLO = "roundreport.hello" -- client -> server: "I can show the window"
Net.SHOW = "roundreport.show"   -- server -> client: open the window with this data

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
