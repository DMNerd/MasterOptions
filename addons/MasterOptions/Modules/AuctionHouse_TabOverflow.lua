-- Master Options module: runs always (the game's auction house, and every addon's tab on it).
MasterOptions_Module("AuctionHouse_TabOverflow", {}, function(ADDON)

-- The auction house's tab row kept to the window's width: what doesn't fit goes into a "More" tab.
--
-- Under the auction house hang the game's tabs (Buy, Sell, Auctions) and every addon's, made through LibAHTab
-- (Auctionator's Shopping, Selling, Cancelling, Auctionator; CheapUpgrades' Upgrades, Alts; Master Options' Cheap
-- Disenchants): ten in a row, wider than the window. A last tab, "More", lists the ones not in the row: a click on
-- one there opens it, as its own tab would; while one of them is open, the More tab bears its name and shows chosen.
--
-- Which tab goes where (More's list, "Arrange tabs"; kept in MasterOptionsDB.ahTabs by the tab's frame name):
--   Auto            - in the row while there's room, in their order (the default)
--   Always in row   - in the row whatever the room
--   Always in More  - never in the row
-- The tabs in the row are chained left to right again (a tab put away leaves no gap). Laid out again as the auction
-- house opens, when a tab is added, and when you change where one goes.

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)

local MORE = "More"
local GAP = 3          -- (LibAHTab's gap between tabs)
local ROW_H = 20       -- a line of the More list
local PLACES = { "auto", "row", "more" }
local PLACE_TEXT = { auto = "|cff9d9d9dAuto|r", row = "|cff4dff4dAlways in row|r", more = "|cffffd100Always in More|r" }

local more, menu
local arranging = false -- (the list shows every tab and where it goes)
local overflow = {}    -- the tabs in the More list, in order
local hidden = {}      -- [tab] = true: hidden here (shown again before each layout)
local origin = {}      -- [tab] = its first anchor as it was made: { point, relativeTo, relativePoint, x, y }
local chosen           -- the tab last chosen (LibAHTab's SetSelected, or the game's own display mode: nil)

local function Lib() return LibStub and LibStub("LibAHTab-1-0", true) end

local function Places()
    if type(MasterOptionsDB) ~= "table" then return {} end
    MasterOptionsDB.ahTabs = MasterOptionsDB.ahTabs or {}
    return MasterOptionsDB.ahTabs
end

local function TabText(t)
    local text = t.GetText and t:GetText()
    if text and text ~= "" then return text end
    local fs = type(t.Text) == "table" and t.Text
    return (fs and fs.GetText and fs:GetText()) or "?"
end
local function Key(t) return (t.GetName and t:GetName()) or TabText(t) end
local function Place(t) return Places()[Key(t)] or "auto" end

-- every tab in its order: the game's, then LibAHTab's (those another addon hid left out)
local function Tabs()
    local ah = _G.AuctionHouseFrame
    local list = {}
    local function Add(t)
        if not origin[t] and t.GetPoint then origin[t] = { t:GetPoint(1) } end
        if t:IsShown() or hidden[t] then list[#list + 1] = t end
    end
    for _, t in ipairs(ah and ah.Tabs or {}) do if t ~= more then Add(t) end end
    local lib = Lib()
    local state = lib and lib.internalState
    for _, t in ipairs(state and state.Tabs or {}) do if t ~= more then Add(t) end end
    return list
end
local isTab = {}

local function Open(t) -- (as a click on the tab itself)
    local click = t:GetScript("OnClick")
    if click then click(t, "LeftButton") end
end

local function HideMenu() if menu then menu:Hide() end end

local Layout, ShowMenu

local function MenuRow(i)
    local r = menu.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, menu)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.18)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.text:SetPoint("LEFT", 8, 0)
    r.place = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.place:SetPoint("RIGHT", -8, 0)
    r:SetScript("OnClick", function(self)
        if self.action then return self.action() end
        if arranging then -- (where it goes: Auto, Always in row, Always in More, round)
            local now = Place(self.tab)
            local nextPlace = PLACES[1]
            for k, p in ipairs(PLACES) do if p == now then nextPlace = PLACES[k % #PLACES + 1] end end
            Places()[Key(self.tab)] = nextPlace ~= "auto" and nextPlace or nil
            Check("the auction house tabs", pcall(Layout))
            Check("the More tab", pcall(ShowMenu))
            return
        end
        HideMenu()
        if self.tab then Check("opening an auction house tab", pcall(Open, self.tab)) end
    end)
    menu.rows[i] = r
    return r
end

ShowMenu = function()
    if not menu then
        menu = CreateFrame("Frame", "MasterOptionsAHTabMore", more)
        menu:SetFrameStrata("DIALOG")
        menu:EnableMouse(true)
        local edge = menu:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", 1, -1)
        edge:SetColorTexture(0.55, 0.45, 0.2, 1)
        local bg = menu:CreateTexture(nil, "BORDER", nil, 1)
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.05, 0.04, 0.96)
        menu.rows = {}
        menu:Hide()
    end
    -- the lines: the tabs not in the row (or, arranging, every tab and where it goes), then the switch between
    local lines = {}
    if arranging then
        for _, t in ipairs(Tabs()) do lines[#lines + 1] = { tab = t, text = TabText(t), place = PLACE_TEXT[Place(t)] } end
        lines[#lines + 1] = { text = "|cff9d9d9dDone|r", action = function() arranging = false; Check("the More tab", pcall(ShowMenu)) end }
    else
        for _, t in ipairs(overflow) do lines[#lines + 1] = { tab = t, text = TabText(t), white = t == chosen } end
        lines[#lines + 1] = { text = "|cff9d9d9dArrange tabs...|r", action = function() arranging = true; Check("the More tab", pcall(ShowMenu)) end }
    end
    local width = arranging and 230 or 150
    for i, line in ipairs(lines) do
        local r = MenuRow(i)
        r.tab, r.action = line.tab, line.action
        r.text:SetText(line.text)
        if line.white then r.text:SetTextColor(1, 1, 1) else r.text:SetTextColor(1, 0.82, 0) end
        r.place:SetText(line.place or "")
        width = math.max(width, (r.text.GetStringWidth and r.text:GetStringWidth() or 100) + (line.place and 130 or 24))
        r:Show()
    end
    for i = #lines + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(width, #lines * ROW_H + 8)
    menu:ClearAllPoints()
    -- below the tab, or above it where the screen ends first
    local bottom = more:GetBottom()
    if bottom and bottom < #lines * ROW_H + 20 then menu:SetPoint("BOTTOMLEFT", more, "TOPLEFT", 4, 2)
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
    -- (in a holder of its own: the tab template puts every tab made with it into its parent's Tabs - made on the
    -- auction house, More was one of its tabs, the others chained after it and it after them: a loop the game refuses)
    local holder = CreateFrame("Frame", nil, ah)
    holder:SetAllPoints()
    local ok, b = pcall(CreateFrame, "Button", "MasterOptionsAHTabMore_Tab", holder, "AuctionHouseFrameDisplayModeTabTemplate")
    if not ok or not b then b = CreateFrame("Button", "MasterOptionsAHTabMore_Tab", holder, "UIPanelButtonTemplate"); b:SetSize(90, 24) end
    b:SetScript("OnClick", function()
        if menu and menu:IsShown() then HideMenu() return end
        arranging = #overflow == 0 -- (nothing in More: straight to where each tab goes)
        Check("the More tab", pcall(ShowMenu))
    end)
    b:SetScript("OnHide", function() HideMenu(); arranging = false end)
    b:Hide()
    more = b
    return b
end

-- a tab's place in the chain: after `prev` as it was after its own neighbour (the game's tabs keep their spacing), or
-- at the row's start where the first tab was
local function Anchor(t, prev, first)
    local o = origin[t] or {}
    t:ClearAllPoints()
    if not prev then
        local f = origin[first] or {}
        if f[1] then t:SetPoint(f[1], f[2], f[3], f[4] or 0, f[5] or 0) end
    elseif o[2] and isTab[o[2]] then
        t:SetPoint(o[1], prev, o[3], o[4] or 0, o[5] or 0)
    else
        t:SetPoint("TOPLEFT", prev, "TOPRIGHT", GAP, 0)
    end
end

Layout = function()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    local tabs = Tabs()
    for t in pairs(hidden) do t:Show() end
    hidden = {}
    overflow = {}
    isTab = {}
    for _, t in ipairs(tabs) do isTab[t] = true end
    local edge, left = ah:GetRight(), tabs[1] and tabs[1].GetLeft and tabs[1]:GetLeft()
    if not edge or #tabs == 0 then return end
    MakeMore(ah)
    MoreLook()
    local moreW = (more:GetWidth() or 90) + GAP
    local function W(t) return (t:GetWidth() or 0) + GAP end
    -- which go in the row: Always in row; then Auto ones in order while there's room (with the More tab after them)
    local inRow, used = {}, 0
    for _, t in ipairs(tabs) do if Place(t) == "row" then inRow[t] = true; used = used + W(t) end end
    local room = edge - (left or edge)
    for _, t in ipairs(tabs) do
        if Place(t) == "auto" and used + W(t) + moreW <= room then inRow[t] = true; used = used + W(t) end
    end
    -- (left unknown yet - the window not drawn: everything in the row, as it was)
    if not left then for _, t in ipairs(tabs) do if Place(t) ~= "more" then inRow[t] = true end end end
    -- the row chained again, the rest put away into More's list
    local prev
    for _, t in ipairs(tabs) do
        if inRow[t] then Anchor(t, prev, tabs[1]); prev = t
        else overflow[#overflow + 1] = t; hidden[t] = true; t:Hide() end
    end
    more:ClearAllPoints()
    if prev then more:SetPoint("TOPLEFT", prev, "TOPRIGHT", GAP, 0)
    else local f = origin[tabs[1]] or {}; if f[1] then more:SetPoint(f[1], f[2], f[3], f[4] or 0, f[5] or 0) end end
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
