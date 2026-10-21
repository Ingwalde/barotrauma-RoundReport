-- Player identity adapter. Persistent state is owned by the server entry point.
-- Account identifiers stay server-side; reports contain only opaque player keys.
local Players = {}

function Players.new(state, stats, config)
    local players, Config = state, config
    local function playerSession(client)
    local session = players.sessions[client.SessionId]
        if session == nil then
            local account = client.AccountId
            local accountKey = nil
            if account ~= nil then
                -- LuaCs may unwrap Option<AccountId> to SteamId (or nil) automatically.
                local wrapped, present = pcall(function() return account.IsSome() end)
                if not wrapped or present then accountKey = tostring(account) end
            end
            local key = accountKey and players.accounts[accountKey] or nil
            if key == nil then
                players.nextId = players.nextId + 1
                key = "player:" .. players.nextId
                if accountKey then players.accounts[accountKey] = key end
            end
            session = { key = key, window = false }
            players.sessions[client.SessionId] = session
        end
        -- Renaming must also update reports when no new stat event has arrived yet.
        for _, tbl in ipairs({ stats.round, stats.total }) do
            if tbl[session.key] then tbl[session.key].label = client.Name end
        end
        return session
    end

    local function refreshNames()
        for _, client in pairs(Client.ClientList) do playerSession(client) end
    end

    local function jobOf(character)
        local ok, job = pcall(function() return character.Info.Job.Prefab.Identifier.Value end)
        if ok then return job end
        return nil
    end

    -- Character -> (key, label, isBot, job), or nil if the character isn't tracked.
    local function resolve(character)
        if character == nil then return nil end
        for _, client in pairs(Client.ClientList) do
            if client.Character == character then
                return playerSession(client).key, client.Name, false, jobOf(character)
            end
        end
        if Config.IncludeBots and character.IsHuman and character.IsOnPlayerTeam then
            return "bot:" .. character.Name, character.Name, true, jobOf(character)
        end
        return nil
    end


    return {
        session = playerSession,
        refreshNames = refreshNames,
        resolve = resolve,
        disconnect = function(client)
            if client ~= nil then players.sessions[client.SessionId] = nil end
        end,
    }
end

return Players
