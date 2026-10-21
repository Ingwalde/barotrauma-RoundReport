-- Round Report: per-player stats for each round and an MVP at the end.
-- Server-side only. Stats come from the game's karma callbacks (KarmaManager.On*),
-- which the server calls for every repair, weld, heal, attack and extinguish,
-- whether or not karma is enabled in the server settings.

if CLIENT then return end

local modPath = ...
local function load(name) return dofile(modPath .. "/Lua/RoundReport/" .. name .. ".lua") end

local Config = load("Config")
local Strings = load("Strings")
local Stats = load("Stats")
local Report = load("Report")
local Net = load("Net")

local function T(key) return Strings.get(Config.Language, key) end

RoundReport = RoundReport or {}
RoundReport.stats = RoundReport.stats or Stats.new() -- survives `reloadlua`

local stats = RoundReport.stats

-- Keep account lookup private: only opaque, server-lifetime keys go over the wire.
-- Session IDs can be reused after disconnect, so they must not key accumulated stats.
RoundReport.players = RoundReport.players or { accounts = {}, sessions = {}, nextId = 0 }
local players = RoundReport.players

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

local function add(character, field, amount)
    local key, label, isBot, job = resolve(character)
    if key then stats:add(key, label, isBot, field, amount, job) end
end

local function sameTeam(a, b)
    return tostring(a.TeamID) == tostring(b.TeamID)
end

-- Item repairs (wrench, screwdriver, etc.). repairAmount is condition gained this frame.
Hook.Patch("roundreport.repair", "Barotrauma.KarmaManager", "OnItemRepaired", function(_, p)
    local amount = p["repairAmount"]
    if amount and amount > 0 then add(p["character"], "repair", amount) end
end, Hook.HookMethodType.Before)

-- Wall damage/repair. Negative damageAmount = welding. Only our own submarine counts.
Hook.Patch("roundreport.structure", "Barotrauma.KarmaManager", "OnStructureHealthChanged", function(_, p)
    local attacker, structure, amount = p["attacker"], p["structure"], p["damageAmount"]
    if attacker == nil or structure == nil or amount == nil then return end
    local sub = structure.Submarine
    if sub == nil or tostring(sub.TeamID) ~= tostring(attacker.TeamID) then return end
    if amount < 0 then
        add(attacker, "weld", -amount)
    elseif amount > 0 then
        add(attacker, "hull", amount)
    end
end, Hook.HookMethodType.Before)

-- Attacks and healing. Negative damage = healing (treatments, CPR).
Hook.Patch("roundreport.health", "Barotrauma.KarmaManager", "OnCharacterHealthChanged", function(_, p)
    local target, attacker, damage = p["target"], p["attacker"], p["damage"]
    if target == nil or attacker == nil or damage == nil then return end
    if target == attacker or target.IsDead or target.Removed then return end
    if damage < 0 then
        if sameTeam(target, attacker) then add(attacker, "heal", -damage) end
    elseif damage > 0 then
        if sameTeam(target, attacker) then
            add(attacker, "ff", damage)
        else
            add(attacker, "damage", damage)
        end
    end
end, Hook.HookMethodType.Before)

-- Extinguishing fires: deltaTime per frame of spraying an actual fire.
Hook.Patch("roundreport.fire", "Barotrauma.KarmaManager", "OnExtinguishingFire", function(_, p)
    add(p["character"], "fire", p["deltaTime"] or 0)
end, Hook.HookMethodType.Before)

Hook.Patch("roundreport.meltdown", "Barotrauma.KarmaManager", "OnReactorMeltdown", function(_, p)
    local reactor, character = p["reactor"], p["character"]
    if reactor == nil or character == nil or reactor.Submarine == nil then return end
    if tostring(reactor.Submarine.TeamID) == tostring(character.TeamID) then
        add(character, "meltdown", 1)
    end
end, Hook.HookMethodType.Before)

-- Deaths and kills.
Hook.Add("character.death", "roundreport.death", function(character)
    if character == nil then return end
    add(character, "deaths", 1)
    local cause = character.CauseOfDeath
    local killer = (cause and cause.Killer) or character.LastAttacker
    if killer ~= nil and killer ~= character and not sameTeam(killer, character) then
        add(killer, "kills", 1)
    end
end)

-- Chat output -----------------------------------------------------------------

local COLOR = Color(255, 215, 90, 255)

local function sendLines(lines, client)
    for _, line in ipairs(lines) do
        local targets = client and { client } or Client.ClientList
        for _, c in pairs(targets) do
            -- a ChatMessage can't be reused, create one per recipient
            local msg = ChatMessage.Create("", line, ChatMessageType.Server, nil, nil)
            msg.Color = COLOR
            Game.SendDirectChatMessage(msg, c)
        end
    end
end

local function personal(client)
    local key = playerSession(client).key
    local one = {}
    if stats.round[key] then one[key] = stats.round[key] end
    return one
end

-- Window (GUI) delivery ---------------------------------------------------------
-- Clients with client-side LuaCs announce themselves with a HELLO message; only they get
-- the window message (a vanilla client would not understand it). Everyone else gets chat.

Networking.Receive(Net.HELLO, function(message, client)
    if client ~= nil then playerSession(client).window = true end
end)

Hook.Add("client.disconnected", "roundreport.disconnected", function(client)
    if client ~= nil then players.sessions[client.SessionId] = nil end
end)

local function sendWindow(client, tab)
    local msg = Networking.Start(Net.SHOW)
    msg.WriteString(tab)
    Net.writeTable(msg, stats.round, Stats.FIELDS)
    Net.writeTable(msg, stats.total, Stats.FIELDS)
    Networking.Send(msg, client.Connection)
end

-- tab: "round" or "total"
local function deliver(client, tab)
    if playerSession(client).window then
        sendWindow(client, tab)
    elseif tab == "total" then
        sendLines(Report.build(stats.total, Config, T, "header_total"), client)
    else
        sendLines(Report.build(stats.round, Config, T, "header"), client)
    end
end

Hook.Add("chatMessage", "roundreport.commands", function(message, client)
    if client == nil or message == nil then return end
    local m = string.lower(message)
    if m == Config.CommandStats then
        refreshNames()
        deliver(client, "round")
        return true
    elseif m == Config.CommandMe then
        sendLines(Report.build(personal(client), Config, T, "header", { personal = true }), client)
        return true
    elseif m == Config.CommandTotal then
        refreshNames()
        deliver(client, "total")
        return true
    end
end)

-- roundEnd can fire twice (EndRound and LoadPreviousSave), so only report when there is data.
Hook.Add("roundEnd", "roundreport.roundEnd", function()
    if Stats.isEmpty(stats.round) then return end
    refreshNames()
    if Config.ReportOnRoundEnd then
        for _, client in pairs(Client.ClientList) do deliver(client, "round") end
        for _, line in ipairs(Report.build(stats.round, Config, T, "header")) do
            print("[RoundReport] " .. line)
        end
    end
    stats:resetRound()
end)

print("[RoundReport] loaded")
