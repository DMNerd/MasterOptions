-- Master Options module: runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_CheapDisenchants", { "Mastercraft" }, function(ADDON)

-- Cheap Disenchants: green (and if you like blue) gear on the auction house that disenchants into more than it costs.
--
-- A "Cheap Disenchants" tab of the auction house (next to Auctionator's and CheapUpgrades'), in the auction house's
-- own look. Scan reads the whole auction house at once (the
-- game's replicate list: the server allows it about every 15 minutes - and when another addon, e.g. CheapUpgrades,
-- has just read it, that list is used without asking again). For each item, its cheapest buyout; for each of those,
-- what Mastercraft says disenchanting it is worth - its tooltip's "Disenchant ~1g 20s" row (the materials it gives,
-- at their auction prices, after the cut), read through a hidden GameTooltip. Listed: what disenchants into more
-- than its buyout, the biggest profit first. A row's click searches for it in the auction house's own Browse, where
-- you buy it with the game's Buy Now (nothing is bought here). "Needs an enchanter": Mastercraft says your own
-- Enchanting can't disenchant it.
-- Nothing of Mastercraft is changed; its tooltip's Disenchant row (Settings > Tooltip) must be on.

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)
local DB -- MasterOptions_CheapDisenchantsDB: { blues = bool, lastScan = time() }

local SCAN_GAP = 15 * 60       -- (the server's: one full read of the auction house per 15 minutes)
local READ_STEP = 1500         -- listings read per frame
local VALUE_STEP = 30          -- items valued per frame (a tooltip each)
local GREEN, BLUE = 2, 3

local function Say(text) print("|cff4da6ffMaster Options|r: " .. text) end

---------------------------------------------------------------------------
-- Money in a tooltip: the game's money string (coin icons, "1,234" thousands) or "1g 20s 5c"
---------------------------------------------------------------------------
local function ParseMoney(text)
    if type(text) ~= "string" then return nil end
    local t = MasterOptions_Shared.StripColour(text):gsub(",", "")
    local total, found = 0, false
    for _, coin in ipairs({ { "Gold", "g", 10000 }, { "Silver", "s", 100 }, { "Copper", "c", 1 } }) do
        local n = t:match("(%d+)%s*|T[^|]-" .. coin[1] .. "Icon") or t:match("(%d+)" .. coin[2] .. "%f[%A]")
        if n then total, found = total + tonumber(n) * coin[3], true end
    end
    return found and total or nil
end

---------------------------------------------------------------------------
-- Mastercraft's disenchant value for an item (its tooltip's "Disenchant" row): value, partial, needs an enchanter
---------------------------------------------------------------------------
local Strip = MasterOptions_Shared.StripColour

local function ReadDisenchant(tip)
    local value, partial, enchanter
    local name = tip:GetName()
    for i = 1, tip:NumLines() do
        local left = Strip(_G[name .. "TextLeft" .. i] and _G[name .. "TextLeft" .. i]:GetText())
        if left:find("^Disenchant") and not left:find("^Disenchanting") then
            local right = _G[name .. "TextRight" .. i]
            value = ParseMoney(right and right:GetText())
            partial = left:find("some prices missing", 1, true) ~= nil
        elseif left:find("Needs an enchanter", 1, true) then
            enchanter = true
        end
    end
    return value, partial, enchanter
end

local function Disenchant(link)
    if not link then return nil end
    return MasterOptions_Shared.HiddenTooltip(ReadDisenchant, "SetHyperlink", link)
end

---------------------------------------------------------------------------
-- The auction house's replicate list: each green (and blue) item's cheapest buyout, then their value
---------------------------------------------------------------------------
local cheapest, results, busy = {}, {}, false
local Refresh, Sort -- (the window, below)

local function Wanted(quality) return quality == GREEN or (quality == BLUE and DB and DB.blues) end

-- results: what disenchants into more than its buyout, the biggest profit first
local function Rank()
    local out = {}
    for _, e in pairs(cheapest) do
        if e.value and e.value > e.buyout then
            e.profit = e.value - e.buyout
            out[#out + 1] = e
        end
    end
    results = out
    if Sort then Sort() end
end

local function Value(list, i)
    if not list then return end
    if MasterOptions_Shared.ItemTooltipShown() then -- (your mouse on an item: its tooltip stays; a moment later)
        C_Timer.After(0.3, function() Check("valuing disenchants", pcall(Value, list, i)) end)
        return
    end
    local last = math.min(#list, i + VALUE_STEP - 1)
    for k = i, last do
        local e = list[k]
        e.value, e.partial, e.enchanter = Disenchant(e.link)
    end
    if last < #list then
        if Refresh then Refresh(("Valuing %d / %d items..."):format(last, #list)) end
        C_Timer.After(0, function() Check("valuing disenchants", pcall(Value, list, last + 1)) end)
        return
    end
    busy = false
    Rank()
    if Refresh then Refresh() end
end

local function Read(i, n)
    local AH = C_AuctionHouse
    local me = UnitName("player")
    local last = math.min(n - 1, i + READ_STEP - 1)
    for k = i, last do
        local _, texture, count, quality, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = AH.GetReplicateItemInfo(k)
        if itemID and Wanted(quality) and (buyout or 0) > 0 and owner ~= me then -- (not your own auctions)
            local each = math.floor(buyout / math.max(1, count or 1) + 0.5) -- (per item, in whole copper)
            local e = cheapest[itemID]
            if not e or each < e.buyout then
                local link = AH.GetReplicateItemLink and AH.GetReplicateItemLink(k)
                cheapest[itemID] = { itemID = itemID, link = link, texture = texture, quality = quality, buyout = each }
            end
        end
    end
    if last < n - 1 then
        if Refresh then Refresh(("Reading the auction house: %d / %d..."):format(last + 1, n)) end
        C_Timer.After(0, function() Check("reading the auction house", pcall(Read, last + 1, n)) end)
        return
    end
    local list = {}
    for _, e in pairs(cheapest) do if e.link then list[#list + 1] = e end end
    Value(list, 1)
end

-- the replicate list is in (ours, or another addon's scan): read it all again
local function OnList()
    local AH = C_AuctionHouse
    local n = AH and AH.GetNumReplicateItems and AH.GetNumReplicateItems() or 0
    if n <= 0 then busy = false; if Refresh then Refresh() end return end
    busy, cheapest = true, {}
    if DB then DB.lastScan = time() end
    Read(0, n)
end

local function Scan()
    local AH = C_AuctionHouse
    if busy then return end
    if not (AH and AH.ReplicateItems) then Say("this game's auction house can't be read all at once.") return end
    local wait = DB and DB.lastScan and (DB.lastScan + SCAN_GAP - time()) or 0
    if wait > 0 and (AH.GetNumReplicateItems and AH.GetNumReplicateItems() or 0) > 0 then
        -- (the server answers one full read per 15 minutes: what's read already, valued again)
        Say(("the auction house can be read again in %d min - showing the last read."):format(math.ceil(wait / 60)))
        OnList()
        return
    end
    busy = true
    if Refresh then Refresh("Asking the auction house...") end
    AH.ReplicateItems()
end

---------------------------------------------------------------------------
-- The window: a "Cheap Disenchants" tab of the auction house, in its own look (as CheapUpgrades' tabs): the
-- auction house's background and column headers, rows like its lists. The tab through LibAHTab (Auctionator's, the
-- tab row Auctionator and CheapUpgrades share), else one of our own next to the game's tabs.
---------------------------------------------------------------------------
local host, offset, sortKey = nil, 0, "profit"
local TITLE_H, TOP_H, FOOT_H, LIST_ROW = 22, 34, 22, 30
local COLS = { -- key, title, width (the item: the rest)
    { "name", "Item" }, { "buyout", "Buyout", 130 }, { "value", "Disenchants into", 150 }, { "profit", "Profit", 130 },
}

local function Money(c)
    if GetMoneyString then return GetMoneyString(math.floor(c + 0.5), true) end
    return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, math.floor(c) % 100)
end
local function Name(e) return e.link and e.link:match("%[(.-)%]") or "?" end

-- the auction house's own Buy view, searching for the item by its exact name: bought there with Buy Now
local function SearchFor(e)
    local ah = _G.AuctionHouseFrame
    if not (e.link and ah) then return end
    if ah.SetDisplayMode and _G.AuctionHouseFrameDisplayMode then
        pcall(ah.SetDisplayMode, ah, _G.AuctionHouseFrameDisplayMode.Buy)
    end
    local bar = ah.SearchBar
    if bar and bar.SearchBox then
        bar.SearchBox:SetText('"' .. Name(e) .. '"')
        if bar.StartSearch then pcall(bar.StartSearch, bar) end
    end
end

-- the list in the order picked by a column header (a second click on it: the other way)
Sort = function()
    local key, desc = sortKey, true
    if key:sub(1, 1) == "-" then key, desc = key:sub(2), false end
    table.sort(results, function(a, b)
        local x, y = a[key], b[key]
        if key == "name" then x, y = Name(a), Name(b); return desc == (x < y) end
        if x == y then return Name(a) < Name(b) end
        return desc == ((x or 0) > (y or 0))
    end)
end

local function RowTooltip(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if e.link then pcall(GameTooltip.SetHyperlink, GameTooltip, e.link) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Buyout", Money(e.buyout), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Disenchants into" .. (e.partial and " (some prices missing)" or ""), "~" .. Money(e.value), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Profit", Money(e.profit), 1, 0.82, 0, 0.3, 1, 0.3)
    if e.enchanter then GameTooltip:AddLine("Needs an enchanter - your Enchanting can't disenchant it yet.", 1, 0.4, 0.4, true) end
    GameTooltip:AddLine("Click: open it in Buy, where you buy it.  Shift-click: link in chat.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function RowClick(self)
    local e = self.entry
    if not e then return end
    if IsShiftKeyDown and IsShiftKeyDown() and e.link then
        local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
        if insert then insert(e.link) end
        return
    end
    SearchFor(e)
end

-- the auction house's panel look: its background in an inset, its column header buttons
local function Inset(parent)
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if not ok or not f then f = CreateFrame("Frame", nil, parent) end
    local bg = f.Bg or f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if not (bg.SetAtlas and pcall(bg.SetAtlas, bg, "auctionhouse-background-index")) then bg:SetColorTexture(0, 0, 0, 0.45) end
    return f
end
local function ColumnHeader(parent, text)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "ColumnDisplayButtonShortTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate") end
    b:SetHeight(19)
    b:SetText(text)
    return b
end

local function Build()
    local ah = _G.AuctionHouseFrame
    if host or not ah then return host end
    local h = CreateFrame("Frame", "MasterOptionsCheapDisenchants", ah)
    h:SetPoint("TOPLEFT", ah, "TOPLEFT", 4, 0)
    h:SetPoint("BOTTOMRIGHT", ah, "BOTTOMRIGHT", -4, 27)
    h:SetFrameLevel((ah:GetFrameLevel() or 1) + 10)
    h:EnableMouse(true) -- (clicks don't fall through to the game's view underneath)
    if h.SetHitRectInsets then h:SetHitRectInsets(0, 0, TITLE_H, 0) end -- (the title bar still moves the window)
    local bg = h:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 0, -TITLE_H)
    bg:SetPoint("BOTTOMRIGHT")
    bg:SetColorTexture(0.05, 0.05, 0.05, 1)

    -- top: Scan AH (its countdown while the server's 15 minutes run), Blues too, the best find
    local scan = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    scan:SetSize(120, 22)
    scan:SetPoint("TOPLEFT", 8, -(TITLE_H + 6))
    scan:SetScript("OnClick", function() Check("scanning", pcall(Scan)) end)
    h.scan = scan
    local blues = CreateFrame("CheckButton", nil, h, "UICheckButtonTemplate")
    blues:SetSize(24, 24)
    blues:SetPoint("LEFT", scan, "RIGHT", 10, 0)
    blues:SetChecked(DB and DB.blues)
    blues:SetScript("OnClick", function(self) DB.blues = self:GetChecked() and true or false end)
    local bl = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bl:SetPoint("LEFT", blues, "RIGHT", 0, 0)
    bl:SetText("Blues too (next scan)")
    h.status = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.status:SetPoint("LEFT", bl, "RIGHT", 16, 0)
    h.status:SetPoint("RIGHT", h, "RIGHT", -10, 0)
    h.status:SetJustifyH("RIGHT")
    h.status:SetWordWrap(false)

    -- the list: column headers, rows
    local inset = Inset(h)
    inset:SetPoint("TOPLEFT", 4, -(TITLE_H + TOP_H))
    inset:SetPoint("BOTTOMRIGHT", -4, FOOT_H)
    h.inset = inset
    local x, prev = 0, nil
    h.headers = {}
    for i = #COLS, 1, -1 do -- (from the right: the item takes what's left)
        local c = COLS[i]
        local b = ColumnHeader(inset, c[2])
        if c[3] then
            b:SetWidth(c[3])
            if prev then b:SetPoint("TOPRIGHT", prev, "TOPLEFT", 0, 0) else b:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -4, -2) end
            x = x + c[3]
        else
            b:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -2)
            b:SetPoint("TOPRIGHT", prev, "TOPLEFT", 0, 0)
        end
        b:SetScript("OnClick", function()
            sortKey = (sortKey == c[1]) and ("-" .. c[1]) or c[1]
            Sort()
            if Refresh then Refresh() end
        end)
        h.headers[c[1]] = b
        prev = b
    end
    h.rows = {}
    local function Cell(row, key, justify)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH(justify)
        fs:SetWordWrap(false)
        local head = h.headers[key]
        fs:SetPoint("LEFT", head, "LEFT", 6, 0)
        fs:SetPoint("RIGHT", head, "RIGHT", -6, 0)
        fs:SetPoint("TOP", row, "TOP")
        fs:SetPoint("BOTTOM", row, "BOTTOM")
        return fs
    end
    for i = 1, 24 do
        local r = CreateFrame("Button", nil, inset)
        r:SetHeight(LIST_ROW - 2)
        r:SetPoint("TOPLEFT", 4, -24 - (i - 1) * LIST_ROW)
        r:SetPoint("RIGHT", inset, "RIGHT", -4, 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.14)
        r.border = r:CreateTexture(nil, "BORDER")
        r.border:SetSize(28, 28)
        r.border:SetPoint("LEFT", 2, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(26, 26)
        r.icon:SetPoint("CENTER", r.border, "CENTER")
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("TOPLEFT", r.border, "TOPRIGHT", 8, -2)
        r.name:SetPoint("RIGHT", h.headers.name, "RIGHT", -6, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.sub:SetPoint("BOTTOMLEFT", r.border, "BOTTOMRIGHT", 8, 2)
        r.sub:SetJustifyH("LEFT")
        r.buyout = Cell(r, "buyout", "RIGHT")
        r.value = Cell(r, "value", "RIGHT")
        r.profit = Cell(r, "profit", "RIGHT")
        r:SetScript("OnEnter", RowTooltip)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", RowClick)
        h.rows[i] = r
    end
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 3
        if Refresh then Refresh() end
    end)

    -- the footer: how to buy, and how many shown
    h.hint = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h.hint:SetPoint("BOTTOMLEFT", 10, 6)
    h.hint:SetText("|cffffd100Click|r an item to open it in Buy, where you buy it.  |cffffd100Shift-click|r: link in chat.")
    h.count = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h.count:SetPoint("BOTTOMRIGHT", -10, 6)

    local tick = 0
    h:SetScript("OnUpdate", function(_, dt) -- (the Scan button's countdown, once a second)
        tick = tick + dt
        if tick >= 1 then tick = 0; if h.UpdateScan then h.UpdateScan() end end
    end)
    h.UpdateScan = function()
        local left = DB and DB.lastScan and (DB.lastScan + SCAN_GAP - time()) or 0
        if busy then
            scan:SetText("|cff9d9d9dScanning...|r")
        elseif left > 0 then
            scan:SetText(("|cff9d9d9dScan AH (%d:%02d)|r"):format(math.floor(left / 60), left % 60))
        else
            scan:SetText("Scan AH")
        end
    end
    h:SetScript("OnShow", function()
        local a = _G.AuctionHouseFrame
        if a and a.SetTitle then pcall(a.SetTitle, a, "Cheap Disenchants") end
        if Refresh then Refresh() end
    end)
    h:Hide()
    host = h
    return h
end

local QUALITY_BORDER = { [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 } }

Refresh = function(statusText)
    if not (host and host:IsShown()) then return end
    local shown = 0
    local listH = host.inset:GetHeight() or 0
    local fit = math.max(1, math.floor((listH - 26) / LIST_ROW))
    offset = math.max(0, math.min(offset, math.max(0, #results - fit)))
    for i, r in ipairs(host.rows) do
        local e = i <= fit and results[offset + i] or nil
        r.entry = e
        if e then
            local c = QUALITY_BORDER[e.quality] or { 1, 1, 1 }
            r.border:SetColorTexture(c[1], c[2], c[3], 0.9)
            r.icon:SetTexture(e.texture)
            r.name:SetText(e.link or "?")
            if e.ilvl == nil then
                local lvl = C_Item and C_Item.GetDetailedItemLevelInfo and e.link and C_Item.GetDetailedItemLevelInfo(e.link)
                e.ilvl = lvl or false
            end
            r.sub:SetText((e.ilvl and ("Item level " .. e.ilvl) or "") .. (e.enchanter and "  |cffff6666needs an enchanter|r" or ""))
            r.buyout:SetText(Money(e.buyout))
            r.value:SetText("~" .. Money(e.value) .. (e.partial and "|cffff6666*|r" or ""))
            r.profit:SetText("|cff4dff4d+" .. Money(e.profit) .. "|r")
            r:Show()
            shown = shown + 1
        else
            r:Hide()
        end
    end
    if statusText then
        host.status:SetText(statusText)
    elseif results[1] then
        local best = results[1]
        for _, e in ipairs(results) do if e.profit > best.profit then best = e end end
        host.status:SetText(("%d worth disenchanting.  Best: %s  |cff4dff4d+%s|r"):format(#results, best.link or Name(best), Money(best.profit)))
    elseif DB and DB.lastScan then
        host.status:SetText("Nothing on the auction house disenchants into more than it costs right now.")
    else
        host.status:SetText("Scan AH reads the whole auction house: what disenchants into more than it costs.")
    end
    host.count:SetText(#results > 0 and ("%d-%d of %d"):format(offset + 1, offset + shown, #results) or "")
    if host.UpdateScan then host.UpdateScan() end
end

-- the tab: LibAHTab's (shared with Auctionator and CheapUpgrades), else one of our own after the game's tabs
local TAB_ID = "MasterOptions_CheapDisenchants"
local ownTab
local function OwnTab(h)
    local ah = _G.AuctionHouseFrame
    local tabs = type(ah.Tabs) == "table" and ah.Tabs or {}
    local ok, tab = pcall(CreateFrame, "Button", "MasterOptionsCheapDisenchantsTab", ah, "AuctionHouseFrameDisplayModeTabTemplate")
    if not ok or not tab then tab = CreateFrame("Button", "MasterOptionsCheapDisenchantsTab", ah, "UIPanelButtonTemplate"); tab:SetSize(130, 24) end
    tab:SetText("Cheap Disenchants")
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
    if tabs[#tabs] then tab:SetPoint("TOPLEFT", tabs[#tabs], "TOPRIGHT", 3, 0) end
    local function Deselect(t) if PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, t) end end
    Deselect(tab)
    tab:SetScript("OnClick", function()
        pcall(ah.SetDisplayMode, ah, {})
        ah.displayMode = nil
        for _, t in ipairs(tabs) do Deselect(t) end
        if PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, tab) end
        h:Show()
    end)
    -- (the game's tabs, or anything that sets a real view, put ours away)
    hooksecurefunc(ah, "SetDisplayMode", function(_, mode)
        if type(mode) == "table" and #mode > 0 then h:Hide(); Deselect(tab) end
    end)
    ownTab = tab
end

local tabbed = false
local function AddTab()
    if tabbed or not _G.AuctionHouseFrame then return end
    local h = Build()
    if not h then return end
    tabbed = true
    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    if lib and not lib:DoesIDExist(TAB_ID) then
        lib:CreateTab(TAB_ID, h, "Cheap Disenchants", "Cheap Disenchants")
    else
        OwnTab(h)
    end
end

local function Open() -- (the tab, chosen)
    AddTab()
    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    if lib and lib:DoesIDExist(TAB_ID) then lib:SetSelected(TAB_ID)
    elseif ownTab then ownTab:GetScript("OnClick")(ownTab) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_SHOW")
pcall(f.RegisterEvent, f, "REPLICATE_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            MasterOptions_CheapDisenchantsDB = MasterOptions_CheapDisenchantsDB or {}
            DB = MasterOptions_CheapDisenchantsDB
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        Check("the Cheap Disenchants tab", pcall(AddTab))
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        -- (ours, or another addon's full read: only while our panel is open, else it's theirs alone)
        if host and host:IsShown() or busy then Check("reading the auction house", pcall(OnList)) end
    end
end)

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)

MasterOptions_CheapDisenchants = { -- (for the tests)
    ParseMoney = ParseMoney, Disenchant = Disenchant, Scan = Scan, Open = Open,
    Results = function() return results end,
}
end)
