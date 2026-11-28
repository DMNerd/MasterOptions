-- Master Options module: runs always (the game's auction house, and every addon's tab on it).
MasterOptions_Module("AuctionHouse_SideTabs", {}, function(ADDON)

-- The auction house's tabs down its side, not in a row under it.
--
-- Under the auction house hang the game's tabs (Buy, Sell, Auctions) and every addon's, made through LibAHTab
-- (Auctionator's Shopping, Selling, Cancelling, Auctionator; CheapUpgrades' Upgrades, Alts; Master Options' Cheap
-- Disenchants): ten in a row, wider than the window. Here they're stacked one under another beside the window -
-- on its right, or on its left when the right is off the screen - all of one width. Each keeps its own look and
-- click; only where it sits changes. Laid out again as the auction house opens, when a tab is added or chosen, and
-- when the game sizes a tab again (its own PanelTemplates_TabResize).

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)

local TOP = 32       -- below the window's title bar
local MIN_W = 120    -- a tab's width, at least (else its longest name and a margin)
local PAD = 32

local width
local ours = {} -- [tab] = true: the tabs laid out here

local function Lib() return LibStub and LibStub("LibAHTab-1-0", true) end

local function Tabs()
    local ah = _G.AuctionHouseFrame
    local list = {}
    for _, t in ipairs(ah and ah.Tabs or {}) do list[#list + 1] = t end
    local lib = Lib()
    local state = lib and lib.internalState
    for _, t in ipairs(state and state.Tabs or {}) do list[#list + 1] = t end
    return list
end

local function TextWidth(t)
    local fs = t.Text or (t.GetFontString and t:GetFontString())
    return fs and fs.GetStringWidth and fs:GetStringWidth() or 60
end

local function Layout()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    local shown = {}
    for _, t in ipairs(Tabs()) do if t:IsShown() then shown[#shown + 1] = t end end
    if #shown == 0 then return end
    width = MIN_W
    for _, t in ipairs(shown) do width = math.max(width, math.ceil(TextWidth(t)) + PAD) end
    -- right of the window, unless that's off the screen
    local right, screen = ah:GetRight(), UIParent and UIParent:GetRight()
    local onLeft = right and screen and right + width > screen
    local step = math.max(20, (shown[1]:GetHeight() or 32) - 4)
    for i, t in ipairs(shown) do
        ours[t] = true
        t:ClearAllPoints()
        t:SetWidth(width)
        if onLeft then t:SetPoint("TOPRIGHT", ah, "TOPLEFT", 2, -(TOP + (i - 1) * step))
        else t:SetPoint("TOPLEFT", ah, "TOPRIGHT", -2, -(TOP + (i - 1) * step)) end
    end
end

-- now, and a moment later: tabs other addons add as the auction house opens come after this one's turn
local function Soon()
    Check("laying out the auction house tabs", pcall(Layout))
    C_Timer.After(0, function() Check("laying out the auction house tabs", pcall(Layout)) end)
    C_Timer.After(0.5, function() Check("laying out the auction house tabs", pcall(Layout)) end)
end

local hooked, libHooked = false, nil
local function Hook()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    if not hooked then
        hooked = true
        ah:HookScript("OnShow", Soon)
        if ah.SetDisplayMode then hooksecurefunc(ah, "SetDisplayMode", function() Check("laying out the auction house tabs", pcall(Layout)) end) end
        if _G.PanelTemplates_TabResize then
            hooksecurefunc("PanelTemplates_TabResize", function(tab)
                if ours[tab] and width then tab:SetWidth(width) end -- (the game sized it again: ours back)
            end)
        end
    end
    -- LibAHTab: hooked on the copy in use (a newer one, Auctionator's, may have replaced ours), once each
    local lib = Lib()
    if lib and lib ~= libHooked and lib.CreateTab then
        libHooked = lib
        hooksecurefunc(lib, "CreateTab", function() Check("laying out the auction house tabs", pcall(Layout)) end)
        if lib.SetSelected then hooksecurefunc(lib, "SetSelected", function() Check("laying out the auction house tabs", pcall(Layout)) end) end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    Check("the auction house tabs", pcall(Hook))
    Soon()
end)

MasterOptions_AuctionHouseSideTabs = { Layout = Layout } -- (for the tests)
end)
