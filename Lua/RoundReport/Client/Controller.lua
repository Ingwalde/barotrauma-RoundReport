-- Client transport and lifecycle. Rendering belongs to Window.
local Controller = {}

function Controller.install(window, Net, Stats)
    -- Draw on top of the game and the lobby while open.
    local addToUpdateList = window.update
    Hook.Patch("roundreport.gui.game", "Barotrauma.GameScreen", "AddToGUIUpdateList", addToUpdateList, Hook.HookMethodType.After)
    Hook.Patch("roundreport.gui.lobby", "Barotrauma.NetLobbyScreen", "AddToGUIUpdateList", addToUpdateList, Hook.HookMethodType.After)

    -- Networking -------------------------------------------------------------------------

    Networking.Receive(Net.SHOW, function(message)
        local tab = message.ReadString()
        local round = Net.readTable(message, Stats.FIELDS)
        local total = Net.readTable(message, Stats.FIELDS)
        window.show(round, total, tab)
    end)

    -- Tell the server we can show the window. Sent on load and at every round start,
    -- so reconnecting or joining mid-session is covered.
    local function hello()
        if not Game.IsMultiplayer then return end
        local ok, err = pcall(function()
            Networking.Send(Networking.Start(Net.HELLO))
        end)
        if not ok then print("[RoundReport] hello failed: " .. tostring(err)) end
    end

    hello()
    Hook.Add("roundStart", "roundreport.hello", hello)

end

return Controller
