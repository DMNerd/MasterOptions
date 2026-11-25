-- Master Options module (was the addon MasterOptions_Mastercraft_Chattynator): runs when Mastercraft and Chattynator are loaded.
MasterOptions_Module("Mastercraft_Chattynator", { "Mastercraft", "Chattynator" }, function(ADDON)

-- Mastercraft <-> Chattynator compatibility patch.
--
-- Mastercraft asks the server for your played time now and then (it records it per character). So the answer
-- doesn't land in chat, it unregisters TIME_PLAYED_MSG from the game's ChatFrame1..N just before its
-- RequestTimePlayed() and gives it back after (Mastercraft\Data.lua, ns.RequestPlayed). Chattynator listens
-- for that event on its own frame, so the "Total time played" lines showed anyway.
--
-- Fix: Chattynator's own switch, Chattynator.API.FilterTimePlayed - turned on only for Mastercraft's request
-- (ChatFrame1 losing the event in the same moment as RequestTimePlayed is called), and off again once the
-- answer is in (or after 10 s). A /played you type yourself is not touched.

local api = type(Chattynator) == "table" and Chattynator.API
if not (api and api.FilterTimePlayed and ChatFrame1) then return end

local mutedAt     -- GetTime() when ChatFrame1 lost TIME_PLAYED_MSG
local filtering = false

local function Stop()
    if not filtering then return end
    filtering = false
    pcall(api.FilterTimePlayed, false)
end

hooksecurefunc(ChatFrame1, "UnregisterEvent", function(_, event)
    if event == "TIME_PLAYED_MSG" then mutedAt = GetTime() end
end)

hooksecurefunc("RequestTimePlayed", function()
    -- Mastercraft's request: the chat frames were muted this very moment
    if mutedAt and GetTime() - mutedAt < 0.05 then
        mutedAt = nil
        if not filtering then
            filtering = true
            pcall(api.FilterTimePlayed, true)
            C_Timer.After(10, Stop) -- (no answer from the server: don't leave /played silent)
        end
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("TIME_PLAYED_MSG")
f:SetScript("OnEvent", function()
    if filtering then C_Timer.After(0.2, Stop) end
end)
end)
