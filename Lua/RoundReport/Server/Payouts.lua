-- Hands a configurable cut of a voyage's net profit to the crew, weighted by round score.
-- The rest of the profit stays in the campaign bank. Campaign mode only; a no-op otherwise
-- (sandbox/mission multiplayer has no Campaign, so GameMain.GameSession.Campaign is nil).
--
-- Needs native verification: this has not yet been confirmed to run early enough, relative to
-- the game's own round-end reward payout, to affect the round that just ended rather than the
-- next one. If it fires too late, profit() below simply reads 0 and nothing happens that round.
local ServerPayouts = {}

function ServerPayouts.new(deps)
    local stats, players, Config, Report, Payouts =
        deps.stats, deps.players, deps.Config, deps.Report, deps.Payouts
    local startMoney = nil

    -- Total money currently held by the crew and the bank together, or nil outside a campaign.
    local function partyMoney()
        local ok, campaign = pcall(function() return GameMain.GameSession.Campaign end)
        if not ok or campaign == nil then return nil, nil end
        local sum = campaign.Bank.Balance
        for _, client in pairs(Client.ClientList) do
            if client.Character ~= nil then sum = sum + client.Character.Wallet.Balance end
        end
        return sum, campaign
    end

    local function captureStart()
        startMoney = partyMoney()
    end

    local function payout()
        if not Config.PayoutEnabled or startMoney == nil then return end
        local endMoney, campaign = partyMoney()
        if endMoney == nil then return end

        local profit = endMoney - startMoney
        if profit <= 0 then return end

        local percent = tonumber(Config.PayoutPercent) or 0
        local pool = math.floor(profit * percent / 100)
        if pool <= 0 then return end
        pool = math.min(pool, campaign.Bank.Balance)
        if pool <= 0 then return end

        local byKey = {}
        for _, client in pairs(Client.ClientList) do
            if client.Character ~= nil then
                local key = players.resolve(client.Character)
                if key then byKey[key] = client end
            end
        end

        local scores = Report.scores(stats.round, Config)
        local shares, given = Payouts.shares(scores, pool)
        for key, amount in pairs(shares) do
            local client = byKey[key]
            if client then client.Character.Wallet.Give(amount) end
        end
        if given > 0 then campaign.Bank.Deduct(given) end
    end

    return { captureStart = captureStart, payout = payout }
end

return ServerPayouts
