-- Master Options module (was the addon MasterOptions_Mastercraft_VendorSell): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_VendorSell", { "Mastercraft" }, function(ADDON)

-- Mastercraft VENDOR advice -> sold by the addon that sells your junk.
--
-- Mastercraft's tooltip advice (KEEP / VENDOR / AUCTION / DISENCHANT) is worked out in private functions, but
-- Mastercraft writes it onto GameTooltip - and it supports another addon reading items through a hidden
-- GameTooltip (Tooltip.lua, patch-479). So at a vendor every bag slot is read that way, fresh, and what says
-- VENDOR is sold by whoever sells junk (Master Options > Vendor > Sell junk automatically):
--   * GearMatic: the items go on its "always sell" list for this visit only (GearMaticDB.moSell lists them,
--     taken off again when the vendor closes) and its own sell pass sells them, one at a time.
--   * Mastercraft: it only sells greys, so this patch sells them the way it does (one at a time, stops when
--     the vendor closes or a fight starts).
--   * Off: nothing is sold.
-- Never sold: greys (the junk seller has them), anything the Keep patch or GearMatic's never-sell list keeps,
-- items where Mastercraft says "Keep N for your guide", and in "goods and gear" mode upgrades (Pawn,
-- GearMatic), set and loadout pieces.
--
-- MasterOptions_MastercraftVendorDB.mode: "off" | "goods" (materials, potions, food...) | "all" (also gear)

local DB

-- (a caught error goes to Master Options' error log: /mo > Problems)
local function Check(where, ok, ...)
    local r = not ok and _G.MasterOptions_ReportError
    if r then r(ADDON, where, ...) end
    return ok, ...
end
local IsEquippable = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local numSlots = C_Container.GetContainerNumSlots
local slotInfo = C_Container.GetContainerItemInfo
local useItem = C_Container.UseContainerItem or UseContainerItem

local function Mode() return DB and DB.mode or "goods" end

local function GM() local g = _G.GearMatic; return type(g) == "table" and g or nil end
local function GMProfile() local g = GM(); return g and g.db and g.db.profile or nil end

-- who sells junk: the same reading as Master Options' "Sell junk automatically"
local function Seller()
    local p = GMProfile()
    local va = GM() and GM().VendorAutomation
    if p and p.autoSellJunk ~= false and va and va.SellJunk then return "gearmatic" end
    local mc = type(_G.MastercraftDB) == "table" and _G.MastercraftDB.settings
    if type(mc) == "table" and mc.autoJunk == true then return "mastercraft" end
    return nil
end

---------------------------------------------------------------------------
-- What Mastercraft says about one bag slot (read through the hidden GameTooltip)
---------------------------------------------------------------------------
local function Strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- verdict ("VENDOR", "KEEP" ...) and whether the advice keeps some for a guide
local function ReadTooltip(tip)
    local name = tip:GetName()
    local verdict, keepSome
    for i = 1, tip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local text = left and left:GetText()
        if type(text) == "string" then
            if not verdict and text:find("Mastercraft", 1, true) then
                local right = _G[name .. "TextRight" .. i]
                local r = right and right:IsShown() and right:GetText()
                if type(r) == "string" and r ~= "" then verdict = Strip(r):upper() end
            elseif verdict then
                local t = Strip(text)
                -- "Keep 5 for your Tailoring guide - you have 8, the other 3 can go." / "... guide needs 4 more"
                if t:find("^Keep %d+ for") or t:find("guide needs") or t:find("guide uses") then keepSome = true end
            end
        end
    end
    return verdict, keepSome
end

local function SlotVerdict(bag, slot)
    local tip = GameTooltip
    if not (tip and tip.SetBagItem) then return nil end
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    local ok = pcall(tip.SetBagItem, tip, bag, slot)
    local okR, verdict, keepSome = false, nil, nil
    if ok then okR, verdict, keepSome = Check("reading Mastercraft's advice", pcall(ReadTooltip, tip)) end
    tip:Hide()
    if not okR then return nil end
    return verdict, keepSome
end

---------------------------------------------------------------------------
-- Gear that must stay (only asked in "all" mode)
---------------------------------------------------------------------------
local function PawnUpgrade(link)
    if type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return false end
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    local ok2, up = pcall(_G.PawnIsItemAnUpgrade, item)
    return ok2 and type(up) == "table" and next(up) ~= nil
end

local function LoadoutIDs()
    local ids = {}
    local store = GM() and GM().Loadouts and GM().Loadouts.Store
    if not (store and store.List and store.Get) then return ids end
    local ok, names = pcall(store.List)
    for _, n in ipairs(ok and names or {}) do
        local e = store.Get(n)
        for _, s in pairs(type(e) == "table" and e.slots or {}) do
            if type(s) == "table" and s.itemID then ids[s.itemID] = true end
        end
    end
    return ids
end

local function GearStays(link, bag, slot, itemID, loadouts)
    if loadouts[itemID] or PawnUpgrade(link) then return true end
    local gm = GM()
    local bo = gm and gm.BagOverlay
    if bo and bo.MarkerVerdict then
        local ok, v = pcall(bo.MarkerVerdict, link, bag, slot)
        if ok and type(v) == "table" and (v.upgrade or v.alt or v.skull) then return true end
    end
    local va = gm and gm.VendorAutomation
    if va and va.InEquipmentSet then
        local ok, inSet = pcall(va.InEquipmentSet, bag, slot, itemID)
        if ok and inSet then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- What Mastercraft last said per item (DB.sell[itemID] = true: VENDOR, false: anything else), for the bag
-- icons - learned from every item tooltip GameTooltip shows (yours and the hidden reads below). Selling
-- itself never trusts this: at the vendor every item is read again.
---------------------------------------------------------------------------
local Changed -- (below: redraws Baganator's junk coins)

local function Remember(itemID, verdict, keepSome)
    if not (DB and itemID) then return end
    local sell
    if verdict then sell = verdict == "VENDOR" and not keepSome end
    if DB.sell[itemID] ~= sell then
        DB.sell[itemID] = sell
        if Changed then Changed() end
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    -- (registered after Mastercraft's - it's a dependency - so its lines are on the tooltip by now)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
        if tip ~= GameTooltip then return end
        local id = data and type(data.id) == "number" and data.id
        if not id then return end
        local ok, verdict, keepSome = Check("reading Mastercraft's advice", pcall(ReadTooltip, tip))
        if ok then Remember(id, verdict, keepSome) end
    end)
end

---------------------------------------------------------------------------
-- One bag slot: would it be sold? fresh = read Mastercraft's advice now, otherwise what it last said
---------------------------------------------------------------------------
local loadoutCache, loadoutAt = nil, 0
local function Loadouts()
    if not loadoutCache or GetTime() - loadoutAt > 2 then loadoutCache, loadoutAt = LoadoutIDs(), GetTime() end
    return loadoutCache
end

local function SlotSells(bag, slot, info, fresh, readCache)
    local id, link = info and info.itemID, info and info.hyperlink
    if not (id and link) or info.hasNoValue or (info.quality or 1) <= 0 then return false end
    local gdb = _G.GearMaticDB
    if type(gdb) == "table" and type(gdb.sellIgnore) == "table" and gdb.sellIgnore[id] then return false end
    local keep = _G.MasterOptions_MastercraftKeep
    if keep and keep.IsNeeded and keep.IsNeeded(id) then return false end
    local price = select(11, GetInfo(link))
    if not price or price <= 0 then return false end
    local gear = IsEquippable(link) and true or false
    if gear and Mode() ~= "all" then return false end
    local sell
    if fresh then
        sell = readCache and readCache[id]
        if sell == nil then
            local verdict, keepSome = SlotVerdict(bag, slot)
            sell = verdict == "VENDOR" and not keepSome
            if readCache then readCache[id] = sell end
        end
    else
        sell = DB and DB.sell[id] == true
    end
    if sell and gear and GearStays(link, bag, slot, id, Loadouts()) then sell = false end
    return sell, price
end

-- For the bag icons (MasterOptions_GearMatic_Baganator's junk coin): no tooltip reads, just what's known
local function WouldSell(bag, slot, itemID)
    if Mode() == "off" or not Seller() or not (bag and slot) then return false end
    local info = slotInfo(bag, slot)
    if not info or (itemID and info.itemID ~= itemID) then return false end
    local ok, sell = Check("bag icon", pcall(SlotSells, bag, slot, info, false))
    return ok and sell == true
end
MasterOptions_MastercraftVendorSell = { WouldSell = WouldSell }

-- Baganator junk coin "Mastercraft": what Mastercraft sells (greys) and what this patch sells with it
local bagAPI = _G.Baganator and _G.Baganator.API
if bagAPI and bagAPI.RegisterJunkPlugin then
    bagAPI.RegisterJunkPlugin("Mastercraft (+ VENDOR advice)", "mastercraft", function(bagID, slotID, itemID)
        if not (bagID and slotID) then return false end
        local info = slotInfo(bagID, slotID)
        if not info or (itemID and info.itemID ~= itemID) then return false end
        local gdb = _G.GearMaticDB
        if type(gdb) == "table" and type(gdb.sellIgnore) == "table" and gdb.sellIgnore[info.itemID] then return false end
        if info.quality == 0 then return not info.hasNoValue end
        return WouldSell(bagID, slotID, info.itemID)
    end)
end

---------------------------------------------------------------------------
-- The bags: every slot Mastercraft says to VENDOR (read fresh)
---------------------------------------------------------------------------
local function Candidates()
    local out, byID = {}, {} -- one tooltip read per item: the advice is per item
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            if info and not info.isLocked then
                local sell, price = SlotSells(bag, slot, info, true, byID)
                if sell then
                    out[#out + 1] = { bag = bag, slot = slot, itemID = info.itemID, stack = info.stackCount or 1,
                        value = price * (info.stackCount or 1) }
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- New items get their icon without a hover: what's in the bags and not known yet is read through the hidden
-- tooltip - only when no tooltip is on screen and out of combat, a few at a time
---------------------------------------------------------------------------
local fillPending, tried = false, {}
local function Fill()
    fillPending = false
    if not DB or Mode() == "off" or not Seller() then return end
    if (InCombatLockdown and InCombatLockdown()) or GameTooltip:IsShown() then
        fillPending = true
        C_Timer.After(2, Fill)
        return
    end
    local reads = 0
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            local id = info and info.itemID
            -- (each item once per session, so what was remembered from last time is brought up to date)
            if id and not tried[id] and (info.quality or 1) > 0 and not info.hasNoValue then
                if reads >= 15 then
                    fillPending = true
                    C_Timer.After(0.5, Fill)
                    return
                end
                tried[id] = true -- (a hover keeps it up to date after this)
                reads = reads + 1
                local verdict, keepSome = SlotVerdict(bag, slot)
                Remember(id, verdict, keepSome)
            end
        end
    end
end
local function FillSoon(delay)
    if fillPending then return end
    fillPending = true
    C_Timer.After(delay or 0.5, Fill)
end

local refreshPending = false
Changed = function()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.3, function()
        refreshPending = false
        local api = _G.Baganator and _G.Baganator.API
        if api and api.RequestItemButtonsRefresh then pcall(api.RequestItemButtonsRefresh) end
    end)
end

---------------------------------------------------------------------------
-- Selling
---------------------------------------------------------------------------
local merchantOpen, run = false, 0

-- GearMatic: on its "always sell" list for this visit, then into its sell pass
local function ClearGearMaticMarks()
    local gdb = _G.GearMaticDB
    if type(gdb) ~= "table" or type(gdb.moSell) ~= "table" then return end
    for id in pairs(gdb.moSell) do
        if type(gdb.sellMark) == "table" then gdb.sellMark[id] = nil end
    end
    gdb.moSell = nil
end

local function SellWithGearMatic(list)
    local gdb = _G.GearMaticDB
    local va = GM().VendorAutomation
    if type(gdb) ~= "table" then return end
    gdb.sellMark = gdb.sellMark or {}
    gdb.moSell = gdb.moSell or {}
    for _, c in ipairs(list) do
        if not gdb.sellMark[c.itemID] then
            gdb.sellMark[c.itemID] = true
            gdb.moSell[c.itemID] = true
        end
    end
    -- a new pass picks the marked items up; when GearMatic's own pass is still running, it skips the call -
    -- then they join that pass's queue (it sells marked entries after checking the list again)
    pcall(va.SellJunk)
    local q = va._Queue and va._Queue()
    if type(q) ~= "table" then return end
    local queued = {}
    for _, e in ipairs(q) do queued[e.bag .. ":" .. e.slot] = true end
    for _, c in ipairs(list) do
        if not queued[c.bag .. ":" .. c.slot] then
            q[#q + 1] = { bag = c.bag, slot = c.slot, itemID = c.itemID, stack = c.stack, marked = true }
        end
    end
end

-- Mastercraft (greys only): sold here, one at a time
local function Money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return ("%dg %ds %dc"):format(c / 10000, (c / 100) % 100, c % 100)
end

local function SellOurselves(list)
    run = run + 1
    local me, i, sold, value = run, 0, 0, 0
    local function Done()
        if sold > 0 then
            print(("|cff4da6ffMaster Options|r: sold %d item%s Mastercraft says to vendor, for %s."):format(
                sold, sold == 1 and "" or "s", Money(value)))
        end
    end
    local function Step()
        if me ~= run or not merchantOpen or (InCombatLockdown and InCombatLockdown()) then return Done() end
        i = i + 1
        local c = list[i]
        if not c then return Done() end
        local now = slotInfo(c.bag, c.slot)
        if now and now.itemID == c.itemID and not now.isLocked then
            useItem(c.bag, c.slot)
            sold, value = sold + 1, value + c.value
        end
        C_Timer.After(0.2, Step)
    end
    Step()
end

local function OnMerchant(tries)
    if not merchantOpen or Mode() == "off" then return end
    local seller = Seller()
    if not seller then return end
    -- an item's tooltip is on screen (the mouse on a bag slot): reading through GameTooltip would take it
    -- away - a moment later (at most a few seconds, then anyway)
    tries = tries or 0
    if tries < 6 and GameTooltip:IsShown() and GameTooltip:GetOwner() ~= WorldFrame and GameTooltip:GetItem() then
        C_Timer.After(0.5, function() Check("at the vendor", pcall(OnMerchant, tries + 1)) end)
        return
    end
    local ok, list = Check("finding what to sell", pcall(Candidates))
    if not ok or #list == 0 then return end
    if seller == "gearmatic" then
        SellWithGearMatic(list)
    else
        -- after Mastercraft's own grey pass has started (different items, but the server drops sales sent at once)
        C_Timer.After(1, function() if merchantOpen then SellOurselves(list) end end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftVendorDB = MasterOptions_MastercraftVendorDB or {}
        DB = MasterOptions_MastercraftVendorDB
        DB.mode = DB.mode or "goods"
        DB.sell = DB.sell or {}
    elseif event == "PLAYER_LOGIN" then
        ClearGearMaticMarks() -- (a visit cut short by a disconnect)
        FillSoon(5) -- (after Mastercraft has its prices and guides in)
    elseif event == "BAG_UPDATE_DELAYED" then
        if not merchantOpen then FillSoon(0.5) end
    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true
        -- (in Forever the vendor window can show a moment after MERCHANT_SHOW; GearMatic's pass is running by then)
        C_Timer.After(0.3, function() Check("at the vendor", pcall(OnMerchant)) end)
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        run = run + 1
        C_Timer.After(0.5, function() if not merchantOpen then ClearGearMaticMarks() end end)
    end
end)

-- (Master Options runs this after the saved variables are in: the setup this did on its own ADDON_LOADED as a
-- separate addon, now)
local h = f.GetScript and f:GetScript("OnEvent") or f.OnEvent -- (f.OnEvent: the sandbox tests' frames)
if h then h(f, "ADDON_LOADED", ADDON) end
end)
