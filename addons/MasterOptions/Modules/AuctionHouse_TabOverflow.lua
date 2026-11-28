-- Master Options module: runs always (the game's auction house, and every addon's tab on it).
MasterOptions_Module("AuctionHouse_TabOverflow", {}, function(ADDON)

-- The auction house's tab row kept to the window's width: what doesn't fit goes into a "More" tab.
--
-- Under the auction house hang the game's tabs (Buy, Sell, Auctions) and every addon's, made through LibAHTab
-- (Auctionator's Shopping, Selling, Cancelling, Auctionator; CheapUpgrades' Upgrades, Alts; Master Options' Cheap
-- Disenchants): ten in a row, wider than the window. The ones that would reach past the window's right edge are
-- hidden, and a last tab, "More", lists them: a click on one there opens it, as its own tab would. While one of them
-- is open, the More tab bears its name and shows chosen. Nothing is moved: the tabs that fit stay where they are.
-- Laid out again as the auction house opens and when a tab is added.

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)

local MORE = "More"
local GAP = 3          -- (LibAHTab's gap between tabs)
local ROW_H = 20       -- a line of the More list

local more, menu
local overflow = {}    -- the tabs in the More list, in order
local hidden = {}      -- [tab] = true: hidden here (shown again before each layout)
local chosen           -- the tab last chosen (LibAHTab's SetSelected, or the game's own display mode: nil)

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

local function TabText(t)
    local text = t.GetText and t:GetText()
    if text and text ~= "" then return text end
    local fs = type(t.Text) == "table" and t.Text
    return (fs and fs.GetText and fs:GetText()) or "?"
end

local function Open(t) -- (as a click on the tab itself)
    local click = t:GetScript("OnClick")
    if click then click(t, "LeftButton") end
end

local function HideMenu() if menu then menu:Hide() end end

local function ShowMenu()
    if not menu then
        menu = CreateFrame("Frame", "MasterOptionsAHTabMore", more)
        menu:SetFrameStrata("DIALOG")
        menu:EnableMouse(true)
        local bg = menu:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.05, 0.04, 0.96)
        local edge = menu:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", 1, -1)
        edge:SetColorTexture(0.55, 0.45, 0.2, 1)
        bg:SetDrawLayer("BORDER", 1)
        menu.rows = {}
        menu:Hide()
    end
    local width = 140
    for i, t in ipairs(overflow) do
        local r = menu.rows[i]
        if not r then
            r = CreateFrame("Button", nil, menu)
            r:SetHeight(ROW_H)
            r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
            r:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
            local hl = r:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0, 0.18)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.text:SetPoint("LEFT", 8, 0)
            r:SetScript("OnClick", function(self)
                HideMenu()
                if self.tab then Check("opening an auction house tab", pcall(Open, self.tab)) end
            end)
            menu.rows[i] = r
        end
        r.tab = t
        r.text:SetText(TabText(t))
        if t == chosen then r.text:SetTextColor(1, 1, 1) else r.text:SetTextColor(1, 0.82, 0) end
        width = math.max(width, (r.text.GetStringWidth and r.text:GetStringWidth() or 100) + 24)
        r:Show()
    end
    for i = #overflow + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(width, #overflow * ROW_H + 8)
    menu:ClearAllPoints()
    -- below the tab, or above it where the screen ends first
    local bottom = more:GetBottom()
    if bottom and bottom < #overflow * ROW_H + 20 then menu:SetPoint("BOTTOMLEFT", more, "TOPLEFT", 4, 2)
    else menu:SetPoint("TOPLEFT", more, "BOTTOMLEFT", 4, -2) end
    menu:Show()
end

-- the More tab's look: chosen (with that tab's name) while one of its tabs is open
local function MoreLook()
    if not more then return end
    local inside = false
    for _, t in ipairs(overflow) do if t == chosen then inside = true end end
    more:SetText((inside and TabText(chosen) or MORE) .. " \194\187") -- (" »": a list behind it)
    if _G.PanelTemplates_TabResize then pcall(_G.PanelTemplates_TabResize, more, 20, nil, 70) end
    local fn = inside and _G.PanelTemplates_SelectTab or _G.PanelTemplates_DeselectTab
    if fn then pcall(fn, more) end
end

local function MakeMore(ah)
    if more then return more end
    local ok, b = pcall(CreateFrame, "Button", "MasterOptionsAHTabMore_Tab", ah, "AuctionHouseFrameDisplayModeTabTemplate")
    if not ok or not b then b = CreateFrame("Button", "MasterOptionsAHTabMore_Tab", ah, "UIPanelButtonTemplate"); b:SetSize(90, 24) end
    b:SetScript("OnClick", function()
        if menu and menu:IsShown() then HideMenu() else Check("the More tab", pcall(ShowMenu)) end
    end)
    b:SetScript("OnHide", HideMenu)
    b:Hide()
    more = b
    return b
end

local function Layout()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    for t in pairs(hidden) do t:Show() end
    hidden = {}
    overflow = {}
    local edge = ah:GetRight()
    local tabs = {}
    for _, t in ipairs(Tabs()) do if t:IsShown() then tabs[#tabs + 1] = t end end
    if not edge or #tabs == 0 then return end
    MakeMore(ah)
    MoreLook()
    local moreW = (more:GetWidth() or 90) + GAP
    local function Right(t) return t:GetRight() end
    if (Right(tabs[#tabs]) or 0) <= edge then -- (all fit: no More)
        more:Hide()
        return
    end
    -- keep what fits with the More tab after it; the rest into the list
    local last = 0
    for i, t in ipairs(tabs) do
        local r = Right(t)
        if r and r + moreW <= edge then last = i else break end
    end
    last = math.max(last, 1)
    for i = last + 1, #tabs do
        overflow[#overflow + 1] = tabs[i]
        hidden[tabs[i]] = true
        tabs[i]:Hide()
    end
    more:ClearAllPoints()
    more:SetPoint("TOPLEFT", tabs[last], "TOPRIGHT", GAP, 0)
    more:Show()
    MoreLook()
end

local function Soon()
    Check("the auction house tabs", pcall(Layout))
    C_Timer.After(0, function() Check("the auction house tabs", pcall(Layout)) end)
    C_Timer.After(0.5, function() Check("the auction house tabs", pcall(Layout)) end)
end

local hooked, libHooked = false, nil
local function Hook()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    if not hooked then
        hooked = true
        ah:HookScript("OnShow", Soon)
        if ah.SetDisplayMode then
            hooksecurefunc(ah, "SetDisplayMode", function(_, mode)
                if type(mode) == "table" and #mode > 0 then chosen = nil; HideMenu(); MoreLook() end -- (the game's own view)
            end)
        end
    end
    -- LibAHTab: hooked on the copy in use (a newer one, Auctionator's, may have replaced ours), once each
    local lib = Lib()
    if lib and lib ~= libHooked and lib.CreateTab then
        libHooked = lib
        hooksecurefunc(lib, "CreateTab", function() Check("the auction house tabs", pcall(Layout)) end)
        if lib.SetSelected and lib.GetButton then
            hooksecurefunc(lib, "SetSelected", function(self, id)
                chosen = self:GetButton(id)
                HideMenu()
                Check("the auction house tabs", pcall(MoreLook))
            end)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    Check("the auction house tabs", pcall(Hook))
    Soon()
end)

MasterOptions_AuctionHouseTabOverflow = { Layout = Layout, More = function() return more end, Overflow = function() return overflow end } -- (for the tests)
end)
