-- Game event adapter: translates karma/death callbacks into stat deltas.
-- No ownership of identity, report delivery or persistent state.
local Tracking = {}

function Tracking.install(add)
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

end

return Tracking
