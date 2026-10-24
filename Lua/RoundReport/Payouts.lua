-- Pure payout math, no game API calls (so it can be tested outside the game).
-- Splits a money pool among players with a positive round score, proportional to that score.
local Payouts = {}

-- scores: key -> score (from Report.scores; nil/non-positive entries are ignored).
-- pool: integer amount to distribute.
-- Returns (shares, given): shares is key -> positive integer amount; given is the sum actually
-- handed out (<= pool; rounding down means it can be a little less).
function Payouts.shares(scores, pool)
    local shares, given = {}, 0
    if pool == nil or pool <= 0 then return shares, 0 end

    local weightSum = 0
    for _, score in pairs(scores) do
        if score and score > 0 then weightSum = weightSum + score end
    end
    if weightSum <= 0 then return shares, 0 end

    for key, score in pairs(scores) do
        if score and score > 0 then
            local amount = math.floor(pool * score / weightSum)
            if amount > 0 then
                shares[key] = amount
                given = given + amount
            end
        end
    end
    return shares, given
end

return Payouts
