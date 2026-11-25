-- Master Options module (was the addon MasterOptions_Mastercraft_Auctionator): runs when Mastercraft and Auctionator are loaded.
MasterOptions_Module("Mastercraft_Auctionator", { "Mastercraft", "Auctionator" }, function(ADDON)

-- Mastercraft <-> Auctionator compatibility patch.
--
-- Problem: Mastercraft puts its "Scan prices" button after the auction house's tabs; Auctionator's tabs fill
-- that row, so Mastercraft falls back to a button inside the window at the bottom right - where, with the
-- WoW skin, it covers Buyout and the other buttons there.
--
-- Fix: both of Mastercraft's buttons (flagged isMastercraft) are kept hidden, and a "Scan prices" button
-- goes on Auctionator's own page (the "Auctionator" tab), left of its Options and Full Scan buttons. It clicks
-- Mastercraft's real button, so the scan, its "Scanning 12 / 134" text and its tooltip are Mastercraft's own.
-- /mc scan keeps working too. Nothing in either addon is changed.

local ours, main, inside

local function KeepHidden(b)
    if not b or b.moHidden then return end
    b.moHidden = true
    b:Hide()
    hooksecurefunc(b, "Show", function(self) self:Hide() end)
end

-- Mastercraft's buttons: children (or grandchildren, for its Controller UI holder) flagged isMastercraft.
-- The main one is the tab-styled button (it has minWidth); the other is its "inside the window" twin.
local function FindMastercraft(ah)
    local function scan(frame, depth)
        for _, child in ipairs({ frame:GetChildren() }) do
            if child.isMastercraft and child.minWidth then return child end
            if depth < 2 then
                local found = scan(child, depth + 1)
                if found then return found end
            end
        end
    end
    return scan(ah, 1)
end

local function Setup()
    local ah = AuctionHouseFrame or AuctionFrame
    local cfg = _G.AuctionatorConfigFrame
    if not (ah and cfg and cfg.OptionsButton) then return end -- Auctionator's page not there: leave Mastercraft's
    local m = FindMastercraft(ah)
    if not m then return end
    if m ~= main then
        main = m
        KeepHidden(main)
        -- mirror its text ("Scan prices", "Scanning 12 / 134", ...)
        hooksecurefunc(main, "SetText", function(_, text) if ours then ours:SetText(text or "") end end)
    end
    if main.inside then
        inside = main.inside
        KeepHidden(inside)
    end
    if not ours then
        ours = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
        ours:SetSize(140, cfg.OptionsButton:GetHeight() or 22)
        ours:SetPoint("TOPRIGHT", cfg.OptionsButton, "TOPLEFT", -3, 0)
        ours:SetScript("OnClick", function() if main then main:Click() end end)
        ours:SetScript("OnEnter", function(self) if main and main.mcTip then main.mcTip(self) end end)
        ours:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    ours:SetText(main:GetText() or "Scan prices")
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    -- Mastercraft makes its button when the auction house opens and places it again 0.5 s and 2 s later
    Setup()
    C_Timer.After(0.1, Setup)
    C_Timer.After(0.7, Setup)
    C_Timer.After(2.2, Setup)
end)
end)
