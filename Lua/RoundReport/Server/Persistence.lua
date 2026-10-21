-- Campaign-scoped persistence coordinator. Totals are stored beside the .save file.
local Persistence = {}

local function fileExists(path)
    local file = io.open(path, "rb")
    if file == nil then return false end
    file:close()
    return true
end

local function readFile(path)
    local file, err = io.open(path, "rb")
    if file == nil then return nil, err end
    local content = file:read("*a")
    file:close()
    return content
end

local function writeAtomic(path, content)
    local temporary, backup = path .. ".tmp", path .. ".bak"
    local file, err = io.open(temporary, "wb")
    if file == nil then return false, err end
    local ok, writeError = file:write(content)
    file:flush()
    file:close()
    if not ok then os.remove(temporary); return false, writeError end

    os.remove(backup)
    if fileExists(path) then
        local moved, moveError = os.rename(path, backup)
        if not moved then os.remove(temporary); return false, moveError end
    end
    local replaced, replaceError = os.rename(temporary, path)
    if not replaced then
        if fileExists(backup) then os.rename(backup, path) end
        os.remove(temporary)
        return false, replaceError
    end
    return true
end

local function campaignSavePath()
    local ok, path = pcall(function() return Game.GameSession.DataPath.SavePath end)
    if not ok or path == nil or tostring(path) == "" then return nil end
    return tostring(path)
end

local function defaultAdapter()
    return {
        campaignPath = campaignSavePath,
        read = readFile,
        exists = fileExists,
        writeAtomic = writeAtomic,
        schedule = function(seconds, callback) Timer.Wait(callback, seconds * 1000) end,
        log = function(message) print("[RoundReport] " .. message) end,
    }
end

function Persistence.new(stats, players, config, codec, fields, version, adapter)
    local defaults = defaultAdapter()
    for key, value in pairs(adapter or {}) do defaults[key] = value end
    adapter = defaults
    local state = { path = nil, dirty = false, scheduled = false, loaded = false }

    local function storagePath(savePath)
        return savePath and savePath .. (config.PersistenceSuffix or ".roundreport.tsv") or nil
    end

    local function countRecords()
        local count = 0
        for _ in pairs(stats.total) do count = count + 1 end
        return count
    end

    local function flushCurrent()
        if not config.PersistenceEnabled or state.path == nil or not state.dirty then return true end
        local content = codec.encode(stats.total, players, fields, version)
        local ok, err = adapter.writeAtomic(storagePath(state.path), content)
        if ok then
            state.dirty = false
        else
            adapter.log("persistence save failed: " .. tostring(err))
        end
        return ok
    end

    local function loadCurrent()
        local sameRuntimeCampaign = players.campaignPath == state.path and state.path ~= nil
        local activeRound, activeSessions = stats.round, players.sessions
        stats.round, stats.total = {}, {}
        players.accounts, players.sessions, players.nextId = {}, {}, 0
        players.campaignPath = state.path
        state.loaded = state.path ~= nil
        local function restoreRuntimeState()
            if sameRuntimeCampaign then
                stats.round, players.sessions = activeRound, activeSessions
            end
        end
        if not config.PersistenceEnabled or state.path == nil then restoreRuntimeState(); return end
        local primary = storagePath(state.path)
        local decoded, lastError
        for _, source in ipairs({ primary, primary .. ".bak" }) do
            if adapter.exists(source) then
                local text, readError = adapter.read(source)
                if text ~= nil then decoded, lastError = codec.decode(text, fields) else lastError = readError end
                if decoded ~= nil then break end
            end
        end
        if decoded == nil then
            if lastError ~= nil then adapter.log("persistence ignored: " .. tostring(lastError)) end
            restoreRuntimeState()
            return
        end
        stats.total = decoded.total
        players.accounts = decoded.accounts
        players.nextId = decoded.nextId
        restoreRuntimeState()
        adapter.log("loaded " .. countRecords() .. " campaign record(s)")
    end

    local function ensureCampaign()
        local path = adapter.campaignPath()
        if path == state.path and state.loaded == (path ~= nil) then return path end
        flushCurrent()
        state.path, state.dirty, state.scheduled = path, false, false
        loadCurrent()
        return path
    end

    local function flush()
        ensureCampaign()
        state.scheduled = false
        return flushCurrent()
    end

    local function markDirty()
        if ensureCampaign() == nil or not config.PersistenceEnabled then return end
        state.dirty = true
        if state.scheduled then return end
        state.scheduled = true
        adapter.schedule(tonumber(config.PersistenceSaveDelay) or 5, flush)
    end

    local function status()
        ensureCampaign()
        return {
            enabled = config.PersistenceEnabled and state.path ~= nil,
            records = countRecords(),
            dirty = state.dirty,
            path = state.path,
        }
    end

    return { ensure = ensureCampaign, markDirty = markDirty, flush = flush, status = status }
end

return Persistence
