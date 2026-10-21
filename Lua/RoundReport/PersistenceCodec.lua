-- Versioned, deterministic text codec for campaign totals and account mapping.
-- Pure module: it does not access the filesystem or game API.
local Codec = {}
Codec.FORMAT = "RRP1"

local function encode(value)
    return (tostring(value or ""):gsub("([^%w%-%._ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function decode(value)
    return (value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function columns(line)
    local out = {}
    for value in (line .. "\t"):gmatch("(.-)\t") do out[#out + 1] = value end
    return out
end

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

function Codec.encode(total, players, fields, version)
    local lines = { table.concat({ Codec.FORMAT, encode(version), tostring(players.nextId or 0) }, "\t") }
    for _, account in ipairs(sortedKeys(players.accounts)) do
        lines[#lines + 1] = table.concat({ "A", encode(account), encode(players.accounts[account]) }, "\t")
    end
    for _, key in ipairs(sortedKeys(total)) do
        local entry = total[key]
        local row = { "T", encode(key), encode(entry.label), entry.isBot and "1" or "0", encode(entry.job) }
        for _, field in ipairs(fields) do row[#row + 1] = tostring(tonumber(entry[field]) or 0) end
        lines[#lines + 1] = table.concat(row, "\t")
    end
    return table.concat(lines, "\n") .. "\n"
end

function Codec.decode(text, fields)
    if type(text) ~= "string" then return nil, "not text" end
    local result = { total = {}, accounts = {}, nextId = 0, version = "unknown" }
    local lineNumber = 0
    for line in text:gmatch("[^\r\n]+") do
        lineNumber = lineNumber + 1
        local row = columns(line)
        if lineNumber == 1 then
            if row[1] ~= Codec.FORMAT then return nil, "unsupported format" end
            result.version = decode(row[2] or "")
            result.nextId = math.max(0, math.floor(tonumber(row[3]) or 0))
        elseif row[1] == "A" and #row == 3 then
            result.accounts[decode(row[2])] = decode(row[3])
        elseif row[1] == "T" and #row == 5 + #fields then
            local key = decode(row[2])
            if key == "" then return nil, "empty key at line " .. lineNumber end
            local entry = { label = decode(row[3]), isBot = row[4] == "1" }
            local job = decode(row[5])
            if job ~= "" then entry.job = job end
            for index, field in ipairs(fields) do
                local value = tonumber(row[5 + index])
                if value == nil or value ~= value then return nil, "invalid number at line " .. lineNumber end
                entry[field] = value
            end
            result.total[key] = entry
        else
            return nil, "invalid row at line " .. lineNumber
        end
    end
    if lineNumber == 0 then return nil, "empty file" end
    return result
end

return Codec
