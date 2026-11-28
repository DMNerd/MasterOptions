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

-- One read at a time: a newer one (another scan's rows) starts over, and the chain running stops (generation)
local generation = 0
local reading = false   -- (rows being taken in and their items loaded: until the valuing starts)
local lastFinish = 0    -- (GetTime() when the last read was through)
local lastReadCount     -- (the replicate list's row count when it was last read: the same list isn't read twice)
local source            -- what the list shown came from ("Auctionator's quick scan" ...) and when: { name, at }

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
                lastFinish = GetTime and GetTime() or 0
                Rank()
                if Refresh then Refresh() end
            end)
    end)
end

---------------------------------------------------------------------------
-- Where the rows come from (as CheapUpgrades' Scanner does it):
--   * Auctionator, when it's installed: its quick scan (one browse search for everything - each item's lowest price,
--     no 15-minute limit; its Scan button, and its scan when the auction house opens) and its full scan (the replicate
--     list, every item's data loaded by Auctionator) both hand their rows over when they're complete (its EventBus).
--     Scan AH starts its quick scan: your Auctionator prices are updated with it, and nothing is read twice.
--   * without it, the replicate list ourselves (one full read per 15 minutes): read once when the server answers. The
--     game sends REPLICATE_ITEM_LIST_UPDATE again for every row whose item data comes in (CheapUpgrades counted
--     179,597 in 6 minutes) - restarting on each (2.20.0) never got to the end. Another addon's read is picked up
--     once those have stopped for a few seconds (one timer, not one per event), never the same list twice.
-- Each row offers its item at its price per item; then the items' data (quality, link) is filled in - loaded first
-- where the client hasn't got it yet, with a time limit - and the list is valued (Value, above).
---------------------------------------------------------------------------
local LOAD_TIMEOUT = 10       -- seconds to wait for items' data
local RESPONSE_TIMEOUT = 20   -- seconds without an answer to our own read: the server's limit
local QUICK_TIMEOUT = 180     -- Auctionator's quick scan, at most
local OTHER_SETTLE = 3        -- another addon's replicate read: picked up when its events stopped this long
local ECHO = 10               -- seconds after our own read in which its events are ours

local function Instant(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if f then return f(id) end
end
local function ItemInfo(id)
    local f = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if f then return f(id) end
end

-- a row: its item at its price per item (copper); quality when the row knows it. Only gear that can be disenchanted
local function Offer(itemID, each, quality)
    if not itemID or not each or each <= 0 then return end
    if quality and quality >= 0 and not Wanted(quality) then return end
    local _, _, _, equipLoc, _, classID = Instant(itemID)
    if classID and ((classID ~= 2 and classID ~= 4) or NOT_DE[equipLoc or ""]) then return end
    each = math.floor(each + 0.5)
    local e = cheapest[itemID]
    if not e then cheapest[itemID] = { itemID = itemID, buyout = each }
    elseif each < e.buyout then e.buyout = each end
end

local function Begin(name)
    generation = generation + 1
    busy, reading, cheapest = true, true, {}
    source = { name = name, at = time() }
    return generation
end

-- the items' data filled in (loaded first where it isn't there yet), what isn't wanted dropped, then valued
local function Resolve(gen)
    if gen ~= generation then return end
    local list, missing = {}, {}
    for _, e in pairs(cheapest) do list[#list + 1] = e end
    local function Fill(e)
        local name, link, quality, _, _, _, _, _, _, texture = ItemInfo(e.itemID)
        if name then e.link, e.quality, e.texture = link, quality, texture end
        return name ~= nil
    end
    local finished = false
    local function Finish()
        if finished or gen ~= generation then return end
        finished = true
        reading = false
        local wanted = {}
        for id, e in pairs(cheapest) do
            if e.link and Wanted(e.quality) then wanted[#wanted + 1] = e else cheapest[id] = nil end
        end
        Value(wanted, gen)
    end
    Work(gen, list, function(e) if not Fill(e) then missing[#missing + 1] = e end end,
        function(k, n) return ("Looking at %d / %d items..."):format(k, n) end, function()
            local waiting = 0
            local Item = _G.Item
            for _, e in ipairs(missing) do
                if Item and Item.CreateFromItemID then
                    waiting = waiting + 1
                    Item:CreateFromItemID(e.itemID):ContinueOnItemLoad(function()
                        if gen ~= generation then return end
                        Fill(e)
                        waiting = waiting - 1
                        if waiting == 0 then Finish() end
                    end)
                end
            end
            if waiting == 0 then return Finish() end
            if Refresh then Refresh(("Loading %d items..."):format(waiting)) end
            C_Timer.After(LOAD_TIMEOUT, Finish)
        end)
end

-- The replicate list in the client (ours, or another addon's read): its rows offered, a few milliseconds a frame
local waitingOwn = false
local function ReadReplicate(name)
    local AH = C_AuctionHouse
    local n = AH and AH.GetNumReplicateItems and AH.GetNumReplicateItems() or 0
    if n <= 0 then busy = false; if Refresh then Refresh() end return end
    lastReadCount = n
    local gen = Begin(name)
    local me = UnitName("player")
    local rows = {}
    for i = 0, n - 1 do rows[#rows + 1] = i end
    Work(gen, rows, function(k)
        local _, _, count, quality, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = AH.GetReplicateItemInfo(k)
        if owner ~= me then Offer(itemID, (buyout or 0) / math.max(1, count or 1), quality) end -- (not your own)
    end, function(k, total) return ("Reading the auction house: %d / %d..."):format(k, total) end, function() Resolve(gen) end)
end

-- Auctionator's rows: its full scan ({ replicateInfo = GetReplicateItemInfo's, itemLink, timeLeft }) or its quick scan
-- (browse results: { itemKey = { itemID, ... }, minPrice, totalQuantity, ... })
local waitingQuick = false
local function TakeAuctionator(rows, full)
    if type(rows) ~= "table" then return end
    waitingQuick = false
    if full then
        local AH = C_AuctionHouse
        lastReadCount = AH and AH.GetNumReplicateItems and AH.GetNumReplicateItems() or nil -- (the same list, read)
    end
    local gen = Begin(full and "Auctionator's full scan" or "Auctionator's quick scan")
    local me = UnitName("player")
    Work(gen, rows, function(r)
        if full then
            local info = type(r.replicateInfo) == "table" and r.replicateInfo
            if info and info[14] ~= me then Offer(info[17], (info[10] or 0) / math.max(1, info[3] or 1), info[4]) end
        elseif type(r.itemKey) == "table" and (r.totalQuantity or 1) > 0 then
            Offer(r.itemKey.itemID, r.minPrice)
        end
    end, function(k, n) return ("Reading Auctionator's scan: %d / %d..."):format(k, n) end, function() Resolve(gen) end)
end

-- Auctionator's scans as they complete: taken while our tab is open or we asked for one; else kept for when it opens
local host -- (the tab's frame: the window, below)
local held -- { rows, full }: the last one that came while the tab was closed
local function Shown() return host and host:IsShown() end
local hookedAuctionator = false
local function HookAuctionator()
    if hookedAuctionator then return true end
    local A = _G.Auctionator
    local bus = A and A.EventBus
    local quick = A and A.IncrementalScan and A.IncrementalScan.Events
    local full = A and A.FullScan and A.FullScan.Events
    if not (bus and bus.Register and ((quick and quick.ScanComplete) or (full and full.ScanComplete))) then return false end
    hookedAuctionator = true
    local wanted = {}
    if quick and quick.ScanComplete then wanted[#wanted + 1] = quick.ScanComplete end
    if full and full.ScanComplete then wanted[#wanted + 1] = full.ScanComplete end
    bus:Register({
        ReceiveEvent = function(_, eventName, rows)
            local isFull = full and eventName == full.ScanComplete
            if not (isFull or (quick and eventName == quick.ScanComplete)) then return end
            if Shown() or waitingQuick then
                held = nil
                Check("reading Auctionator's scan", pcall(TakeAuctionator, rows, isFull))
            else
                held = { rows = rows, full = isFull }
            end
        end,
    }, wanted)
    return true
end
local function TakeHeld()
    if held and not busy then
        local h = held
        held = nil
        Check("reading Auctionator's scan", pcall(TakeAuctionator, h.rows, h.full))
    end
end

local function AuctionatorQuick()
    local A = _G.Auctionator
    local ref = A and A.State and A.State.IncrementalScanFrameRef
    return HookAuctionator() and type(ref) == "table" and type(ref.InitiateScan) == "function" and ref or nil
end

local function Scan()
    if busy then return end
    -- with Auctionator: its quick scan (no 15-minute limit), its rows handed over when it's complete
    local quick = AuctionatorQuick()
    if quick then
        busy, waitingQuick = true, true
        if Refresh then Refresh("Auctionator is scanning the auction house...") end
        if pcall(quick.InitiateScan, quick) then
            local gen = generation
            C_Timer.After(QUICK_TIMEOUT, function()
                if waitingQuick and gen == generation then
                    waitingQuick, busy = false, false
                    if Refresh then Refresh("Auctionator's scan didn't finish - try Scan AH again.") end
                end
            end)
            return
        end
        busy, waitingQuick = false, false
    end
    -- without it: the replicate list ourselves
    local AH = C_AuctionHouse
    if not (AH and AH.ReplicateItems) then Say("this game's auction house can't be read all at once.") return end
    local wait = DB and DB.lastScan and (DB.lastScan + SCAN_GAP - time()) or 0
    if wait > 0 and (AH.GetNumReplicateItems and AH.GetNumReplicateItems() or 0) > 0 then
        -- (the server answers one full read per 15 minutes: what's read already, valued again - values are kept)
        Say(("the auction house can be read again in %d min - showing the last read."):format(math.ceil(wait / 60)))
        ReadReplicate(source and source.name or "the last scan")
        return
    end
    busy, waitingOwn = true, true
    if DB then DB.lastScan = time() end
    if Refresh then Refresh("Asking the auction house...") end
    AH.ReplicateItems()
    local gen = generation
    C_Timer.After(RESPONSE_TIMEOUT, function()
        if waitingOwn and gen == generation then
            waitingOwn = false
            if (AH.GetNumReplicateItems() or 0) > 0 then ReadReplicate("the last scan")
            else busy = false; if Refresh then Refresh("No answer - the server's 15 minutes may not be over yet.") end end
        end
    end)
end

-- REPLICATE_ITEM_LIST_UPDATE: the answer to ours (read at once, once), or another addon's read (one timer: read
-- when the events stopped, not the same list twice, not our own read's echoes)
local otherToken, settlePending = 0, false
local function OnReplicate()
    local AH = C_AuctionHouse
    if waitingOwn then
        if (AH.GetNumReplicateItems() or 0) == 0 then return end -- (an empty answer is no answer yet)
        waitingOwn = false
        ReadReplicate("your scan")
        return
    end
    if busy or not Shown() then return end
    if GetTime and GetTime() - lastFinish < ECHO then return end
    otherToken = otherToken + 1
    if settlePending then return end
    settlePending = true
    local function Look(seen)
        if busy or not Shown() then settlePending = false return end
        if otherToken ~= seen then local now = otherToken; return C_Timer.After(OTHER_SETTLE, function() Look(now) end) end
        settlePending = false
        local A = _G.Auctionator
        local fs = A and A.State and A.State.FullScanFrameRef
        if type(fs) == "table" and fs.inProgress then return end -- (Auctionator's own: its rows come when it's done)
        local n = AH.GetNumReplicateItems() or 0
        if n == 0 or n == lastReadCount then return end
        if DB then DB.lastScan = time() end -- (the server's 15 minutes run from another addon's read too)
        ReadReplicate("another addon's scan")
    end
    C_Timer.After(OTHER_SETTLE, function() Look(otherToken) end)
end

-- The max price changed (the tab's field, as CheapUpgrades'): the last read listed again at once - what's newly under
-- it valued (values are kept: only what wasn't valued yet is read), what's over it dropped. No new scan.
local function SetMaxPrice(copper)
    if not DB then return end
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if copper == (tonumber(DB.maxPrice) or 0) then return end
    DB.maxPrice = copper > 0 and copper or nil
    if reading then return end -- (the rows still coming in: valued with the new max price when they're in)
    local list = {}
    for _, e in pairs(cheapest) do if e.link then list[#list + 1] = e end end
    if #list == 0 then if Refresh then Refresh() end return end
    busy = true
    generation = generation + 1
    Value(list, generation)
end

---------------------------------------------------------------------------
-- The window: a "Cheap Disenchants" tab of the auction house, in its own look (as CheapUpgrades' tabs): the
-- auction house's background and column headers, rows like its lists. The tab through LibAHTab (the tab row Auctionator
-- and CheapUpgrades share).
---------------------------------------------------------------------------
local offset, sortKey = 0, "profit"
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
        elseif left > 0 and not AuctionatorQuick() then -- (Auctionator's quick scan has no 15 minutes)
            scan:SetText(("|cff9d9d9dScan AH (%d:%02d)|r"):format(math.floor(left / 60), left % 60))
        else
            scan:SetText("Scan AH")
        end
    end
    h:SetScript("OnShow", function()
        local a = _G.AuctionHouseFrame
        if a and a.SetTitle then pcall(a.SetTitle, a, "Cheap Disenchants") end
        if Refresh then Refresh() end
        TakeHeld() -- (an Auctionator scan that finished while the tab was closed - the one as the auction house opened)
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
    local from = ""
    if source and not busy then
        local ago = math.floor((time() - (source.at or time())) / 60)
        from = ("  -  %s, %s"):format(source.name, ago < 1 and "just now" or (ago .. " min ago"))
    end
    host.count:SetText((#results > 0 and ("%d-%d of %d"):format(offset + 1, offset + shown, #results) or "") .. from)
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
        Check("listening to Auctionator's scans", pcall(HookAuctionator)) -- (its scan as the auction house opens)
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        Check("reading the auction house", pcall(OnReplicate))
    end
end)
Check("listening to Auctionator's scans", pcall(HookAuctionator))

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)

MasterOptions_CheapDisenchants = { -- (for the tests)
    ParseMoney = ParseMoney, Disenchant = Disenchant, Scan = Scan, Open = Open, SetMaxPrice = SetMaxPrice,
    Results = function() return results end,
}
end)
