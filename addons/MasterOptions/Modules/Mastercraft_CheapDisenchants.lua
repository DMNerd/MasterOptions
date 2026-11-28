-- Master Options module: runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_CheapDisenchants", { "Mastercraft" }, function(ADDON)

-- Cheap Disenchants: green (and if you like blue) gear on the auction house that disenchants into more than it costs.
--
-- A "Cheap Disenchants" tab of the auction house (next to Auctionator's and CheapUpgrades', through LibAHTab), in the
-- auction house's own look. Scan reads the whole auction house at once (the
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
local FRAME_MS = 6             -- work per frame, at most (reading the list, valuing items): no hitch
local VALUE_KEEP = 10 * 60     -- a disenchant value is good for 10 minutes (a scan again re-reads only new items)
local GREEN, BLUE = 2, 3

local function Say(text) print("|cff4da6ffMaster Options|r: " .. text) end

local ParseMoney = MasterOptions_Shared.ParseMoney

-- Mastercraft's disenchant value from its tooltip rows (Shared.ReadMastercraftValues): value, partial, needs an enchanter
local function ReadDisenchant(tip)
    local v = MasterOptions_Shared.ReadMastercraftValues(tip)
    return v.disenchant, v.partial, v.enchanter
end

-- (quiet: an auction house item isn't yours - nothing is learned from it; values kept a while by link)
local valueCache = {}
local function Disenchant(link)
    if not link then return nil end
    local hit = valueCache[link]
    if hit and time() - hit[1] < VALUE_KEEP then return hit[2], hit[3], hit[4] end
    local value, partial, enchanter = MasterOptions_Shared.QuietTooltip(ReadDisenchant, "SetHyperlink", link)
    valueCache[link] = { time(), value, partial, enchanter }
    return value, partial, enchanter
end

-- milliseconds since a mark (debugprofilestop), for the per-frame budget; without it, a fixed count
local clock = _G.debugprofilestop
local function Spent(since) return clock and (clock() - since) or 0 end

---------------------------------------------------------------------------
-- The auction house's replicate list: each green (and blue) item's cheapest buyout, then their value
---------------------------------------------------------------------------
local cheapest, results, busy = {}, {}, false
local Refresh, Sort -- (the window, below)

local function Wanted(quality) return quality == GREEN or (quality == BLUE and DB and DB.blues) end

-- the max price per item (DB.maxPrice, copper; 0 or none: no max), as CheapUpgrades' "Max price:" in its tab: what
-- costs more isn't listed - nor valued, so a scan reads less
local function Cap()
    local c = DB and tonumber(DB.maxPrice)
    return c and c > 0 and c or nil
end
local function UnderCap(e) local c = Cap(); return not c or e.buyout <= c end

-- results: what disenchants into more than its buyout, the biggest profit first
local function Rank()
    local out = {}
    for _, e in pairs(cheapest) do
        if e.value and e.value > e.buyout and UnderCap(e) then
            e.profit = e.value - e.buyout
            out[#out + 1] = e
        end
    end
    results = out
    if Sort then Sort() end
end

-- One read of the list at a time: a list arriving again mid-way (REPLICATE_ITEM_LIST_UPDATE more than once, another
-- addon's scan) starts over, and the chain running stops - two chains at once each did the whole work
local generation = 0
local reading = false -- (the replicate list being read: OnList until Read is through)

-- `list` worked through a few milliseconds a frame: fn(entry) on each, then done(); status(k, n) says how far.
-- Stops when a newer read has started (gen)
local function Work(gen, list, fn, status, done, i)
    i = i or 1
    if gen ~= generation then return end
    if MasterOptions_Shared.ItemTooltipShown() then -- (your mouse on an item: its tooltip stays; a moment later)
        C_Timer.After(0.3, function() Check("valuing disenchants", pcall(Work, gen, list, fn, status, done, i)) end)
        return
    end
    local start, last = clock and clock() or 0, i - 1
    for k = i, math.min(#list, i + (clock and #list or 30) - 1) do
        fn(list[k])
        last = k
        if Spent(start) > FRAME_MS then break end
    end
    if last < #list then
        if Refresh then Refresh(status(last, #list)) end
        C_Timer.After(0, function() Check("valuing disenchants", pcall(Work, gen, list, fn, status, done, last + 1)) end)
        return
    end
    done()
end

-- What an item disenchants into is the same for every item of one quality and item level, weapon or armour
-- (Mastercraft's DisenchantResults(quality, itemLevel, isWeapon), its materials at their prices). Each such group's
-- value is read once, from one of its items' tooltip (each full tooltip runs every addon's tooltip hooks: a few
-- milliseconds each, and a scan had thousands - the game lagged for a minute). Then only what costs less than its
-- group's value is read on its own, to be sure: an item that can't be disenchanted, one Mastercraft says to keep,
-- "needs an enchanter". The same list as reading every item, in a fraction of the reads.
local NOT_DE = { INVTYPE_BODY = true, INVTYPE_TABARD = true, [""] = true } -- (shirts, tabards: Mastercraft's)
local groupCache = {} -- [key] = { time, value, partial }
local function ItemLevel(link)
    local lvl = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
    local info = not lvl and ((C_Item and C_Item.GetItemInfo) or _G.GetItemInfo)
    if info then lvl = select(4, info(link)) end
    return lvl
end
-- the group's key, or false: never disenchanted (a shirt, a tabard), or nil: its item level isn't known yet (read alone)
local function GroupKey(e)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if not instant then return nil end
    local _, _, _, equipLoc, _, classID = instant(e.link)
    if NOT_DE[equipLoc or ""] or (classID ~= 2 and classID ~= 4) then return false end
    local lvl = ItemLevel(e.link)
    if not lvl then return nil end
    return e.quality .. ":" .. lvl .. ":" .. (classID == 2 and "w" or "a")
end

local function Value(list, gen)
    -- 1. into groups
    local groups, order = {}, {}
    for _, e in ipairs(list) do
        local key = UnderCap(e) and GroupKey(e) -- (over the max price: not valued)
        if not key and key ~= nil then e.value = nil end
        if key ~= false then
            key = key or e.link -- (item level not known: a group of its own)
            local g = groups[key]
            if not g then g = { key = key }; groups[key] = g; order[#order + 1] = g end
            g[#g + 1] = e
        end
    end
    -- 2. each group's value: kept a while, else one of its items read (the next one if it gives none - an item that
    -- can't be disenchanted, or one to keep)
    local function GroupValue(g)
        local hit = groupCache[g.key]
        if hit and time() - hit[1] < VALUE_KEEP then g.value, g.partial = hit[2], hit[3] return end
        for i = 1, math.min(#g, 3) do
            local v, partial = Disenchant(g[i].link)
            if v then g.value, g.partial = v, partial break end
        end
        groupCache[g.key] = { time(), g.value, g.partial }
    end
    Work(gen, order, GroupValue, function(k, n) return ("Valuing %d / %d kinds of item..."):format(k, n) end, function()
        -- 3. what costs less than its group's value: read on its own
        local maybe = {}
        for _, g in ipairs(order) do
            for _, e in ipairs(g) do
                if g.value and g.value > e.buyout then maybe[#maybe + 1] = e else e.value = nil end
            end
        end
        Work(gen, maybe, function(e) e.value, e.partial, e.enchanter = Disenchant(e.link) end,
            function(k, n) return ("Checking %d / %d finds..."):format(k, n) end, function()
                busy = false
                Rank()
                if Refresh then Refresh() end
            end)
    end)
end

local function Read(i, n, gen)
    if gen ~= generation then return end
    local AH = C_AuctionHouse
    local me = UnitName("player")
    local start, last = clock and clock() or 0, i - 1
    for k = i, math.min(n - 1, i + (clock and n or 1500) - 1) do
        last = k
        local _, texture, count, quality, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = AH.GetReplicateItemInfo(k)
        if itemID and Wanted(quality) and (buyout or 0) > 0 and owner ~= me then -- (not your own auctions)
            local each = math.floor(buyout / math.max(1, count or 1) + 0.5) -- (per item, in whole copper)
            local e = cheapest[itemID]
            if not e or each < e.buyout then
                local link = AH.GetReplicateItemLink and AH.GetReplicateItemLink(k)
                cheapest[itemID] = { itemID = itemID, link = link, texture = texture, quality = quality, buyout = each }
            end
        end
        if k % 200 == 0 and Spent(start) > FRAME_MS then break end
    end
    if last < n - 1 then
        if Refresh then Refresh(("Reading the auction house: %d / %d..."):format(last + 1, n)) end
        C_Timer.After(0, function() Check("reading the auction house", pcall(Read, last + 1, n, gen)) end)
        return
    end
    reading = false
    local list = {}
    for _, e in pairs(cheapest) do if e.link then list[#list + 1] = e end end
    Value(list, gen)
end

-- the replicate list is in (ours, or another addon's scan): read it all again
local function OnList()
    local AH = C_AuctionHouse
    local n = AH and AH.GetNumReplicateItems and AH.GetNumReplicateItems() or 0
    if n <= 0 then busy = false; if Refresh then Refresh() end return end
    busy, cheapest, reading = true, {}, true
    if DB then DB.lastScan = time() end
    generation = generation + 1 -- (a read already going stops: this one starts over)
    Read(0, n, generation)
end

-- The max price changed (the tab's field, as CheapUpgrades'): the last read listed again at once - what's newly under
-- it valued (values are kept: only what wasn't valued yet is read), what's over it dropped. No new scan.
local function SetMaxPrice(copper)
    if not DB then return end
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if copper == (tonumber(DB.maxPrice) or 0) then return end
    DB.maxPrice = copper > 0 and copper or nil
    if reading then return end -- (the list still being read: it's valued with the new max price when it's in)
    local list = {}
    for _, e in pairs(cheapest) do if e.link then list[#list + 1] = e end end
    if #list == 0 then if Refresh then Refresh() end return end
    busy = true
    generation = generation + 1
    Value(list, generation)
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
-- auction house's background and column headers, rows like its lists. The tab through LibAHTab (the tab row Auctionator
-- and CheapUpgrades share).
---------------------------------------------------------------------------
local host, offset, sortKey = nil, 0, "profit"
local TITLE_H, TOP_H, FOOT_H, LIST_ROW = 22, 34, 22, 30
local COLS = { -- key, title, width (the item: the rest)
    { "name", "Item" }, { "buyout", "Buyout", 130 }, { "value", "Disenchants into", 150 }, { "profit", "Profit", 130 },
}

local Money = MasterOptions_Shared.Money
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
    -- Max price (as CheapUpgrades' tab: the game's own gold / silver / copper input, the auction house Sell tab's;
    -- applied a moment after typing stops, or at Enter; 0: no max). Our own box where the client has no such input.
    local ml = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ml:SetPoint("LEFT", bl, "RIGHT", 16, 0)
    ml:SetText("Max price:")
    local function PriceHelp(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Max price per item")
        GameTooltip:AddLine("What costs more isn't listed, nor valued when scanning (a lighter scan). 0: no max. Changing it lists the last scan again - no new scan.", 1, 1, 1, true)
        GameTooltip:Show()
    end
    local token = 0
    local function Later(get)
        token = token + 1
        local t = token
        C_Timer.After(0.35, function() if t == token then Check("setting the max price", pcall(SetMaxPrice, get())) end end)
    end
    local priceEnd
    local ok, mf = pcall(CreateFrame, "Frame", nil, h, "LargeMoneyInputFrameTemplate")
    if ok and mf and type(mf.GoldBox) == "table" and mf.GetAmount and mf.SetAmount then
        mf:SetSize(200, 30)
        mf:SetPoint("LEFT", ml, "RIGHT", 6, 0)
        local setting = false
        h.SetPriceShown = function(c) setting = true; mf:SetAmount(c or 0); setting = false end
        if mf.SetOnValueChangedCallback then
            mf:SetOnValueChangedCallback(function() if not setting then Later(function() return mf:GetAmount() end) end end)
        end
        for _, box in ipairs({ mf.GoldBox, mf.SilverBox, mf.CopperBox }) do
            box:HookScript("OnEnterPressed", function(b) token = token + 1; Check("setting the max price", pcall(SetMaxPrice, mf:GetAmount())); b:ClearFocus() end)
            box:HookScript("OnEscapePressed", function(b) token = token + 1; h.SetPriceShown(Cap()); b:ClearFocus() end)
            box:HookScript("OnEnter", PriceHelp)
            box:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        priceEnd = mf
    else
        -- "25" (gold), "25g", "1g 50s", "5s": as CheapUpgrades reads its /cu max
        local box = CreateFrame("EditBox", nil, h, "InputBoxTemplate")
        box:SetSize(90, 20)
        box:SetPoint("LEFT", ml, "RIGHT", 8, 0)
        box:SetAutoFocus(false)
        local function Amount()
            local s = (box:GetText() or ""):lower():gsub("%s", "")
            if s == "" or s == "0" then return 0 end
            local g = tonumber(s)
            if g then return math.floor(g * 10000) end
            local total = 0
            local rest = s:gsub("([%d%.]+)([gsc])", function(n, unit)
                total = total + (tonumber(n) or 0) * (unit == "g" and 10000 or unit == "s" and 100 or 1)
                return ""
            end)
            return rest == "" and math.floor(total) or nil
        end
        h.SetPriceShown = function(c)
            c = c or 0
            local g, s = math.floor(c / 10000), math.floor(c % 10000 / 100)
            box:SetText(c == 0 and "0" or ((g > 0 and (g .. "g") or "") .. (s > 0 and (" " .. s .. "s") or "")):gsub("^ ", ""))
        end
        box:SetScript("OnEnterPressed", function(b)
            local c = Amount()
            if c then Check("setting the max price", pcall(SetMaxPrice, c)) end
            h.SetPriceShown(Cap()); b:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(b) h.SetPriceShown(Cap()); b:ClearFocus() end)
        box:SetScript("OnEnter", PriceHelp)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
        priceEnd = box
    end
    h.SetPriceShown(Cap())
    h.status = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.status:SetPoint("LEFT", priceEnd, "RIGHT", 16, 0)
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
        host.status:SetText(Cap() and ("Nothing up to %s disenchants into more than it costs right now."):format(Money(Cap()))
            or "Nothing on the auction house disenchants into more than it costs right now.")
    else
        host.status:SetText("Scan AH reads the whole auction house: what disenchants into more than it costs.")
    end
    host.count:SetText(#results > 0 and ("%d-%d of %d"):format(offset + 1, offset + shown, #results) or "")
    if host.UpdateScan then host.UpdateScan() end
end

-- the tab: LibAHTab's (Master Options ships it, Libs\LibAHTab.lua - Auctionator's, if newer, is the one in use): one
-- tab row shared with Auctionator and CheapUpgrades, and no taint (a tab made with the game's own tab functions spreads
-- it to your bags, even in combat after the auction house)
local TAB_ID = "MasterOptions_CheapDisenchants"
local function Lib() return LibStub and LibStub("LibAHTab-1-0", true) end

local tabbed = false
local function AddTab()
    local lib = Lib()
    if tabbed or not (lib and _G.AuctionHouseFrame) then return end
    local h = Build()
    if not h then return end
    tabbed = true
    if not lib:DoesIDExist(TAB_ID) then lib:CreateTab(TAB_ID, h, "Cheap Disenchants", "Cheap Disenchants") end
end

local function Open() -- (the tab, chosen)
    AddTab()
    local lib = Lib()
    if lib and lib:DoesIDExist(TAB_ID) then lib:SetSelected(TAB_ID) end
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
    ParseMoney = ParseMoney, Disenchant = Disenchant, Scan = Scan, Open = Open, SetMaxPrice = SetMaxPrice,
    Results = function() return results end,
}
end)
