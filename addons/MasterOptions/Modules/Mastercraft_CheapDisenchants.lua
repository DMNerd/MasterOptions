-- Master Options module: runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_CheapDisenchants", { "Mastercraft" }, function(ADDON)

-- Cheap Disenchants: green (and if you like blue) gear on the auction house that disenchants into more than it costs.
--
-- A "Cheap Disenchants" tab of the auction house (next to Auctionator's and CheapUpgrades', through LibAHTab), in the
-- auction house's own look. Scan reads the whole auction house at once (the
-- game's replicate list: the server allows it about every 15 minutes - and when another addon, e.g. CheapUpgrades,
-- has just read it, that list is used without asking again). For each item, its cheapest buyout; for each of those,
-- what Mastercraft says disenchanting it is worth - its tooltip's "Disenchant ~1g 20s" row (the materials it gives,
-- at their auction prices, after the cut), read through a hidden GameTooltip. Two lists: Profitable - what
-- disenchants into more than its buyout, the biggest profit first; Cheapest - everything that can be disenchanted,
-- the cheapest first (materials or skill-ups for little, a small loss included). A row's click searches for it in the auction house's own Browse, where
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

-- Two lists (DB.mode): "profit" - what disenchants into more than its buyout, the biggest profit first; "cheap" -
-- everything that can be disenchanted, the cheapest first (materials, or Enchanting skill, for little: what it gives
-- beside what it costs - a small loss is fine there)
local function Cheap() return DB and DB.mode == "cheap" end
local function Rank()
    local out = {}
    local cheap = Cheap()
    for _, e in pairs(cheapest) do
        if e.value and e.value > 0 and (cheap or e.value > e.buyout) and UnderCap(e)
            and not (DB and DB.hideEnchanter and e.enchanter) then
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
local announceGen       -- the read whose finds are said in chat when it's through (one done in the background)

-- the heads-up in chat after a read in the background: how many disenchant into more than they cost, and the best
-- (whichever list the tab shows; nothing said when nothing was found, or with "Tell me in chat" unticked)
local function Announce()
    if not DB or DB.noChat then return end
    local n, best = 0, nil
    for _, e in pairs(cheapest) do
        if e.value and e.value > e.buyout and UnderCap(e) and not (DB.hideEnchanter and e.enchanter) then
            n = n + 1
            if not best or e.value - e.buyout > best.value - best.buyout then best = e end
        end
    end
    if n == 0 then return end
    Say(("Cheap Disenchants: %d item%s on the auction house disenchant%s into more than %s. Best: %s +%s - see the Cheap Disenchants tab.")
        :format(n, n == 1 and "" or "s", n == 1 and "s" or "", n == 1 and "it costs" or "they cost",
            best.link or "?", MasterOptions_Shared.Money(best.value - best.buyout)))
end

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
        if Refresh then Refresh(status(last, #list), last / #list) end
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
        if hit and time() - hit[1] < VALUE_KEEP then g.value, g.partial, g.enchanter = hit[2], hit[3], hit[4] return end
        for i = 1, math.min(#g, 3) do
            local v, partial, enchanter = Disenchant(g[i].link)
            if v then g.value, g.partial, g.enchanter = v, partial, enchanter break end
        end
        groupCache[g.key] = { time(), g.value, g.partial, g.enchanter }
    end
    Work(gen, order, GroupValue, function(k, n) return ("Valuing each kind of item (3/4): %d / %d"):format(k, n) end, function()
        -- 3. what costs less than its group's value: read on its own; the rest keeps its group's value (the Cheapest
        -- list shows it - none of them disenchants into more than it costs)
        local maybe = {}
        for _, g in ipairs(order) do
            for _, e in ipairs(g) do
                if g.value and g.value > e.buyout then maybe[#maybe + 1] = e
                else e.value, e.partial, e.enchanter = g.value, g.partial, g.enchanter end
            end
        end
        Work(gen, maybe, function(e) e.value, e.partial, e.enchanter = Disenchant(e.link) end,
            function(k, n) return ("Checking the finds (4/4): %d / %d"):format(k, n) end, function()
                busy = false
                lastFinish = GetTime and GetTime() or 0
                Rank()
                if Refresh then Refresh() end
                if announceGen == gen then announceGen = nil; Announce() end
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
local FULL_TIMEOUT = 600      -- Auctionator's full scan, at most (it loads every item's data)
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

-- a row: its item at its price per item (copper); quality when the row knows it; yours: one of your own auctions may
-- be among it (Auctionator's quick scan can't say which price is whose). Only gear that can be disenchanted
local function Offer(itemID, each, quality, yours)
    if not itemID or not each or each <= 0 then return end
    if quality and quality >= 0 and not Wanted(quality) then return end
    local _, _, _, equipLoc, _, classID = Instant(itemID)
    if classID and ((classID ~= 2 and classID ~= 4) or NOT_DE[equipLoc or ""]) then return end
    each = math.floor(each + 0.5)
    local e = cheapest[itemID]
    if not e then cheapest[itemID] = { itemID = itemID, buyout = each, yours = yours or nil }
    elseif each < e.buyout then e.buyout, e.yours = each, yours or nil end
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
        function(k, n) return ("Looking at the items (2/4): %d / %d"):format(k, n) end, function()
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
            if Refresh then Refresh(("Loading the items the game hasn't sent yet (2/4): %d"):format(waiting)) end
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
    end, function(k, total) return ("Reading the auction house (1/4): %d / %d"):format(k, total) end, function() Resolve(gen) end)
end

-- Auctionator's rows: its full scan ({ replicateInfo = GetReplicateItemInfo's, itemLink, timeLeft }) or its quick scan
-- (browse results: { itemKey = { itemID, ... }, minPrice, totalQuantity, ... })
local waitingAuctionator = false
local function TakeAuctionator(rows, full)
    if type(rows) ~= "table" then return end
    waitingAuctionator = false
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
            -- (containsOwnerItem: one of yours is among them - only yours, a single one: not offered at all; with
            -- others, its lowest price may be yours: marked)
            local yours = r.containsOwnerItem == true
            if not (yours and (r.totalQuantity or 0) <= 1) then Offer(r.itemKey.itemID, r.minPrice, nil, yours) end
        end
    end, function(k, n) return ("Reading Auctionator's scan (1/4): %d / %d"):format(k, n) end, function() Resolve(gen) end)
end

-- Auctionator's scans as they complete (its Scan button, its scan as the auction house opens, ours): read at once -
-- with the tab closed too, in the background (a few milliseconds a frame), and what's found said in chat (as
-- CheapUpgrades does; the tab's "Tell me in chat" option). Kept for later while a read is still going on.
local host -- (the tab's frame: the window, below)
local held -- { rows, full }: the last one that came while a read was going on
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
            if waitingAuctionator or not busy then
                held = nil
                -- (asked for, or watched: no word in chat needed; else the read about to start - TakeAuctionator's
                -- Begin - is said in chat when it's through)
                announceGen = not (Shown() or waitingAuctionator) and generation + 1 or nil
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

local function AuctionatorFull()
    local A = _G.Auctionator
    local ref = A and A.State and A.State.FullScanFrameRef
    return HookAuctionator() and type(ref) == "table" and type(ref.InitiateScan) == "function" and ref or nil
end

-- seconds until a full read of the auction house can be asked for again (the server's 15 minutes: Auctionator's own
-- count when it's the one to ask, else ours); 0: now
local function FullWait()
    local ref = AuctionatorFull()
    if ref then
        if ref.inProgress then return 0 end
        local last = type(ref.state) == "table" and ref.state.TimeOfLastReplicateScan
        return last and math.max(0, last + SCAN_GAP - time()) or 0
    end
    return DB and DB.lastScan and math.max(0, DB.lastScan + SCAN_GAP - time()) or 0
end

-- waiting for Auctionator's scan to say it's complete (at most `limit` seconds)
local function WaitForAuctionator(limit, what)
    busy, waitingAuctionator = true, true
    if Refresh then Refresh(("%s - waiting for Auctionator..."):format(what)) end
    local gen = generation
    C_Timer.After(limit, function()
        if waitingAuctionator and gen == generation then
            waitingAuctionator, busy = false, false
            if Refresh then Refresh(("Auctionator's %s didn't finish - try again."):format(what:lower())) end
        end
    end)
end

-- Quick scan: Auctionator's (one browse search for everything: each item's lowest price; no 15-minute wait)
local function ScanQuick()
    if busy then return end
    local quick = AuctionatorQuick()
    if not quick then return false end
    WaitForAuctionator(QUICK_TIMEOUT, "Quick scan")
    if not pcall(quick.InitiateScan, quick) then busy, waitingAuctionator = false, false; return false end
    return true
end

-- Full scan: every listing ("of the ..." variants, and whose they are: yours left out), once per 15 minutes -
-- Auctionator's full scan when it's installed (its prices updated too), else the game's replicate list ourselves
local function ScanFull()
    if busy then return end
    local AH = C_AuctionHouse
    local full = AuctionatorFull()
    if full then
        if full.CanInitiate and not full:CanInitiate() then
            Say(("a full scan can run again in %d min."):format(math.ceil(FullWait() / 60)))
            return
        end
        WaitForAuctionator(FULL_TIMEOUT, "Full scan")
        if not pcall(full.InitiateScan, full) then busy, waitingAuctionator = false, false end
        return
    end
    if not (AH and AH.ReplicateItems) then Say("this game's auction house can't be read all at once.") return end
    local wait = FullWait()
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

-- the main scan: Auctionator's quick scan when it's there, else the full read
local function Scan()
    if not ScanQuick() then ScanFull() end
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
local offset = 0
local function DefaultSort() return Cheap() and "-buyout" or "profit" end
local sortKey = "profit"
local TITLE_H, TOP_H, FOOT_H, LIST_ROW = 22, 60, 22, 30
local LEFT = 62 -- (the auction house's portrait, top left, covers the first row up to here)
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
    if e.profit >= 0 then GameTooltip:AddDoubleLine("Profit", Money(e.profit), 1, 0.82, 0, 0.3, 1, 0.3)
    else GameTooltip:AddDoubleLine("Loss", Money(-e.profit), 1, 0.82, 0, 1, 0.4, 0.4) end
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

    -- top, two rows: the scans and the max price; the options and what's going on, a progress bar under them
    local function Tip(owner, title, text)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(title)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end
    local function Button(width, onClick, title, text)
        local b = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self) Tip(self, title, type(text) == "function" and text() or text) end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    local quick = Button(104, function() Check("scanning", pcall(ScanQuick)) end, "Quick scan",
        "Auctionator's quick scan: one search for everything, each item's lowest price. No 15-minute wait, and your Auctionator prices are updated too.")
    quick:SetPoint("TOPLEFT", LEFT, -(TITLE_H + 6))
    quick:SetText("Quick scan")
    h.quick = quick
    local full = Button(126, function() Check("scanning", pcall(ScanFull)) end, "Full scan", function()
        return (AuctionatorFull() and "Auctionator's full scan" or "The whole auction house")
            .. ": every listing, \"of the ...\" variants too, and your own auctions left out. The server allows it once every 15 minutes."
    end)
    full:SetPoint("LEFT", quick, "RIGHT", 6, 0) -- (without Auctionator in its place: UpdateScan)
    h.scan = full
    -- which list: two buttons side by side, the one shown lit
    local ll = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ll:SetPoint("LEFT", full, "RIGHT", 22, 0)
    ll:SetText("List:")
    local function ModeButton(mode, text, help)
        local b = Button(96, function()
            if DB.mode == mode or (not DB.mode and mode == "profit") then return end
            DB.mode = mode ~= "profit" and mode or nil
            sortKey, offset = DefaultSort(), 0
            Rank()
            if Refresh then Refresh() end
        end, text, help)
        b:SetText(text)
        return b
    end
    h.modeProfit = ModeButton("profit", "Profitable",
        "What disenchants into more than it costs, the biggest profit first. Buy it, disenchant it, sell the materials.")
    h.modeProfit:SetPoint("LEFT", ll, "RIGHT", 6, 0)
    h.modeCheap = ModeButton("cheap", "Cheapest",
        "Everything that can be disenchanted, the cheapest first - what it disenchants into beside what it costs, a small loss included. For materials or Enchanting skill-ups for little gold.")
    h.modeCheap:SetPoint("LEFT", h.modeProfit, "RIGHT", 2, 0)
    -- (the options: what's read, what's listed)
    local function Option(anchor, gap, text, key, title, help, now)
        local c = CreateFrame("CheckButton", nil, h, "UICheckButtonTemplate")
        c:SetSize(22, 22)
        c:SetPoint("TOPLEFT", anchor, gap, -(TITLE_H + 31))
        -- ("!key": on unless DB[key] is set - an option on by default)
        local off = key:sub(1, 1) == "!"
        if off then key = key:sub(2) end
        c:SetChecked(DB and ((DB[key] and true or false) ~= off))
        c:SetScript("OnClick", function(self)
            local on = self:GetChecked() and true or false
            DB[key] = (on ~= off) or nil
            if now then now() end
        end)
        c:SetScript("OnEnter", function(self) Tip(self, title, help) end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local l = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("LEFT", c, "RIGHT", 0, 0)
        l:SetText(text)
        return c, l
    end
    local _, bl = Option(h, 8, "Blues too", "blues", "Blues too",
        "Blue gear as well as green, from the next scan. Blues disenchant into shards.")
    local _, el = Option(h, 8 + 22 + ((bl.GetStringWidth and bl:GetStringWidth()) or 60) + 16, "Hide \"needs an enchanter\"",
        "hideEnchanter", "Hide \"needs an enchanter\"",
        "Leave out what your own Enchanting can't disenchant yet (Mastercraft's word). Shown again when you untick it.",
        function() Rank(); if Refresh then Refresh() end end)
    local _, cl = Option(h, 8 + 22 + ((bl.GetStringWidth and bl:GetStringWidth()) or 60) + 16 + 22
        + ((el.GetStringWidth and el:GetStringWidth()) or 140) + 16, "Tell me in chat", "!noChat", "Tell me in chat",
        "When Auctionator scans the auction house (its Scan button, or as the auction house opens) with this tab closed, the scan is read here too, in the background, and what disenchants into more than it costs is said in chat.")
    h.optionsEnd = cl
    -- Max price (as CheapUpgrades' tab: the game's own gold / silver / copper input, the auction house Sell tab's;
    -- applied a moment after typing stops, or at Enter; 0: no max). Our own box where the client has no such input.
    -- (row two, at the right)
    local ml = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ml:SetText("Max price:")
    local ROW2 = -(TITLE_H + 42)
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
    local ok, mf = pcall(CreateFrame, "Frame", nil, h, "LargeMoneyInputFrameTemplate")
    if ok and mf and type(mf.GoldBox) == "table" and mf.GetAmount and mf.SetAmount then
        mf:SetSize(200, 30)
        mf:SetPoint("RIGHT", h, "TOPRIGHT", -8, ROW2)
        ml:SetPoint("RIGHT", mf, "LEFT", -8, 0)
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
    else
        -- "25" (gold), "25g", "1g 50s", "5s": as CheapUpgrades reads its /cu max
        local box = CreateFrame("EditBox", nil, h, "InputBoxTemplate")
        box:SetSize(90, 20)
        box:SetPoint("RIGHT", h, "TOPRIGHT", -14, ROW2)
        ml:SetPoint("RIGHT", box, "LEFT", -10, 0)
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
    end
    h.SetPriceShown(Cap())
    -- what's going on (row one, after the list buttons), and a thin bar for how far a step is
    h.status = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.status:SetPoint("LEFT", h.modeCheap, "RIGHT", 16, 0)
    h.status:SetPoint("RIGHT", h, "RIGHT", -10, 0)
    h.status:SetJustifyH("RIGHT")
    h.status:SetWordWrap(false)
    local bar = CreateFrame("StatusBar", nil, h)
    bar:SetHeight(3)
    bar:SetPoint("TOPLEFT", 6, -(TITLE_H + TOP_H - 5))
    bar:SetPoint("TOPRIGHT", -6, -(TITLE_H + TOP_H - 5))
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.3, 0.65, 1)
    bar:SetMinMaxValues(0, 1)
    bar:Hide()
    h.bar = bar


    -- the list: column headers, rows
    local inset = Inset(h)
    inset:SetPoint("TOPLEFT", 4, -(TITLE_H + TOP_H))
    inset:SetPoint("BOTTOMRIGHT", -4, FOOT_H)
    h.inset = inset
    -- a message in the list itself when it's empty (what to do, or that nothing was found)
    h.empty = inset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    h.empty:SetWidth(560)
    h.empty:SetJustifyH("CENTER")
    h.empty:SetPoint("CENTER", inset, "CENTER", 0, 10)
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
        if i % 2 == 0 then -- (every other row a shade lighter: a long list reads across)
            local stripe = r:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, 0.035)
        end
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
        -- Quick scan only with Auctionator (its quick scan); the full scan's button then beside it, else in its place
        local hasQuick = AuctionatorQuick() ~= nil
        if hasQuick then quick:Show() else quick:Hide() end
        full:ClearAllPoints()
        if hasQuick then full:SetPoint("LEFT", quick, "RIGHT", 6, 0) else full:SetPoint("TOPLEFT", LEFT, -(TITLE_H + 6)) end
        -- the list shown: its button lit, its name white; the other's grey
        local cheap = Cheap()
        for b, on in pairs({ [h.modeProfit] = not cheap, [h.modeCheap] = cheap }) do
            if on then b:LockHighlight() else b:UnlockHighlight() end
            local fs = b.GetFontString and b:GetFontString()
            if fs then fs:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6) end
        end
        local label, wait = hasQuick and "Full scan" or "Scan AH", FullWait()
        if busy then
            quick:SetText("|cff9d9d9dScanning...|r")
            full:SetText(hasQuick and ("|cff9d9d9d" .. label .. "|r") or "|cff9d9d9dScanning...|r")
        else
            quick:SetText("Quick scan")
            full:SetText(wait > 0 and ("|cff9d9d9d%s (%d:%02d)|r"):format(label, math.floor(wait / 60), wait % 60) or label)
        end
        if quick.SetEnabled then quick:SetEnabled(not busy); full:SetEnabled(not busy) end
    end
    h:SetScript("OnShow", function()
        local a = _G.AuctionHouseFrame
        if a and a.SetTitle then pcall(a.SetTitle, a, "Cheap Disenchants") end
        if Refresh then Refresh() end
        TakeHeld() -- (an Auctionator scan that finished while the tab was closed - the one as the auction house opened)
    end)
    sortKey = DefaultSort()
    h:Hide()
    host = h
    return h
end

local QUALITY_BORDER = { [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 } }

Refresh = function(statusText, fraction)
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
            local notes = {}
            if e.ilvl then notes[#notes + 1] = "Item level " .. e.ilvl end
            if e.enchanter then notes[#notes + 1] = "|cffff6666needs an enchanter|r" end
            if e.yours then notes[#notes + 1] = "|cffbbbbbbyou have one listed - the cheapest may be yours|r" end
            r.sub:SetText(table.concat(notes, "  -  "))
            r.buyout:SetText(Money(e.buyout))
            r.value:SetText("~" .. Money(e.value) .. (e.partial and "|cffff6666*|r" or ""))
            -- (the profit, and what it is of the price: a 2g find on a 50c item beats one on a 40g item)
            local pct = e.buyout > 0 and math.floor(e.profit / e.buyout * 100 + 0.5) or 0
            r.profit:SetText(("|cff%s%s%s|r |cff9d9d9d%d%%|r"):format(e.profit >= 0 and "4dff4d" or "ff6666",
                e.profit >= 0 and "+" or "-", Money(math.abs(e.profit)), pct))
            r:Show()
            shown = shown + 1
        else
            r:Hide()
        end
    end
    -- the bar: how far the step is (shown while something's going on)
    if host.bar then
        if busy and fraction then host.bar:SetValue(math.max(0, math.min(1, fraction))); host.bar:Show()
        elseif not busy then host.bar:Hide() end
    end
    -- the empty list says what to do, or that nothing was found
    local empty
    local cheap = Cheap()
    local what = cheap and "nothing that can be disenchanted" or "nothing that disenchants into more than it costs"
    if #results == 0 then
        if busy then empty = statusText or "Scanning..."
        elseif source then
            empty = Cap() and ("Up to %s, the auction house has %s right now."):format(Money(Cap()), what)
                or ("The auction house has %s right now."):format(what)
        else
            empty = (AuctionatorQuick() and "Press Quick scan: Auctionator looks through the auction house"
                or "Press Scan AH: the whole auction house is read")
                .. (cheap and ", and what can be disenchanted is listed here, the cheapest first."
                    or ", and what disenchants into more than it costs is listed here.")
        end
    end
    host.empty:SetText(empty or "")
    if empty then host.empty:Show() else host.empty:Hide() end
    if statusText then
        host.status:SetText(statusText)
    elseif results[1] and cheap then
        local low = results[1]
        for _, e in ipairs(results) do if e.buyout < low.buyout then low = e end end
        host.status:SetText(("%d to disenchant, from %s"):format(#results, Money(low.buyout)))
    elseif results[1] then
        local best = results[1]
        for _, e in ipairs(results) do if e.profit > best.profit then best = e end end
        host.status:SetText(("%d worth it.  Best: |cff4dff4d+%s|r"):format(#results, Money(best.profit)))
    else
        host.status:SetText("")
    end
    local parts = {}
    if #results > 0 then parts[1] = ("%d-%d of %d"):format(offset + 1, offset + shown, #results) end
    if source and not busy then
        local ago = math.floor((time() - (source.at or time())) / 60)
        parts[#parts + 1] = ("%s, %s"):format(source.name, ago < 1 and "just now" or (ago .. " min ago"))
    end
    host.count:SetText(table.concat(parts, "  -  "))
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
    ScanFull = ScanFull, ScanQuick = ScanQuick, Rerank = function() Rank(); if Refresh then Refresh() end end,
    Results = function() return results end,
}
end)
