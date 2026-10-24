-- Server report delivery, chat commands and round lifecycle.
local Delivery = {}

function Delivery.install(deps)
    local stats, players = deps.stats, deps.players
    local Config, Stats, Report, Net, T = deps.Config, deps.Stats, deps.Report, deps.Net, deps.T
    local Version, persistence = deps.Version, deps.persistence
    local payouts = deps.payouts
    local playerSession, refreshNames = players.session, players.refreshNames
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
        players.disconnect(client)
    end)

    local function sendWindow(client, tab)
        local msg = Networking.Start(Net.SHOW)
        msg.WriteString(tab)
        Net.writeScoring(msg, Config)
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
        persistence.ensure()
        local m = string.lower(message)
        if m == Config.CommandStats then
            refreshNames()
            persistence.markDirty()
            deliver(client, "round")
            return true
        elseif m == Config.CommandMe then
            sendLines(Report.build(personal(client), Config, T, "header", { personal = true }), client)
            return true
        elseif m == Config.CommandTotal then
            refreshNames()
            persistence.markDirty()
            deliver(client, "total")
            return true
        elseif m == Config.CommandVersion then
            local status = persistence.status()
            local line = string.format("Round Report v%s | campaign persistence: %s | records: %d",
                Version, status.enabled and "on" or "off", status.records)
            sendLines({ line }, client)
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
        if payouts then payouts.payout() end
        stats:resetRound()
        persistence.flush()
    end)

    Hook.Add("roundStart", "roundreport.persistence", function()
        persistence.ensure()
        if payouts then payouts.captureStart() end
    end)

end

return Delivery
