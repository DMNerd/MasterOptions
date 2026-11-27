-- Master Options module (was the addon MasterOptions_Mastercraft_VendorSell): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_VendorSell", { "Mastercraft" }, function(ADDON)

-- Mastercraft VENDOR advice -> sold by the addon that sells your junk.
--
-- At a vendor every bag slot's Mastercraft advice is read fresh (MasterOptions_Shared.MastercraftSlotAdvice), and what
-- says VENDOR is sold by whoever sells junk (Master Options > Vendor > Sell junk automatically):
--   * GearMatic: the items go on its "always sell" list for this visit only (GearMaticDB.moSell lists them,
--     taken off again when the vendor closes) and its own sell pass sells them, one at a time.
--   * Mastercraft: it only sells greys, so this patch sells them the way it does (one at a time, stops when
--     the vendor closes or a fight starts).
--   * Off: nothing is sold.
-- Never sold: greys (the junk seller has them), anything the Keep patch or GearMatic's never-sell list keeps,
-- items where Mastercraft says "Keep N for your guide", and in "goods and gear" mode upgrades (Pawn,
-- GearMatic), set and loadout pieces.
-- Between visits, WouldSell answers from what Mastercraft last said (the Mastercraft_Advice module) for the junk coins
-- in the bags; /mo vendor tells, item by item, what will be sold and why not.
--
-- MasterOptions_MastercraftVendorDB.mode: "off" | "goods" (materials, potions, food...) | "all" (also gear)

local S = MasterOptions_Shared
local DB

local _, Check = S.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)
local IsEquippable = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
local GetInfo = S.GetItemInfo
local numSlots = C_Container.GetContainerNumSlots
local slotInfo = C_Container.GetContainerItemInfo
local useItem = C_Container.UseContainerItem or UseContainerItem
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

local function Mode() return DB and DB.mode or "goods" end

-- who sells junk: the same reading as Master Options' "Sell junk automatically"
local function Seller()
    local p, gm = S.GearMaticProfile(), S.GearMatic()
    local va = gm and gm.VendorAutomation
    if p and p.autoSellJunk ~= false and va and va.SellJunk then return "gearmatic" end
    local mc = S.MastercraftSettings()
    if mc and mc.autoJunk == true then return "mastercraft" end
    return nil
end

-- what Mastercraft last said to VENDOR (the Mastercraft_Advice module; without it: nothing known)
local function Sells(itemID)
    local a = _G.MasterOptions_MastercraftAdvice
    return a ~= nil and a.Sells(itemID)
end

---------------------------------------------------------------------------
-- Gear that must stay (only asked in "all" mode): stays, and why
---------------------------------------------------------------------------
local loadoutCache, loadoutAt = nil, 0
local function Loadouts()
    if not loadoutCache or GetTime() - loadoutAt > 2 then loadoutCache, loadoutAt = S.GearMaticLoadoutIDs(), GetTime() end
    return loadoutCache
end

local function GearStays(link, bag, slot, itemID)
    if Loadouts()[itemID] then return true, "in a GearMatic loadout" end
    local keeps, why = S.KeepsGear(link) -- (Pawn, or GearMatic's best for one of your specs)
    if keeps then return true, why end
    return S.GearMaticKeeps(link, bag, slot, itemID)
end

---------------------------------------------------------------------------
-- One bag slot: sold? fresh = Mastercraft's advice read now, otherwise what it last said. sell, price - and when it
-- isn't sold, why (for /mo vendor). The cheap checks first: WouldSell asks for every bag slot on every Baganator redraw.
---------------------------------------------------------------------------
local function SlotSells(bag, slot, info, fresh, readCache)
    local id, link = info and info.itemID, info and info.hyperlink
    if not (id and link) then return false, nil, "no item" end
    if info.hasNoValue or (info.quality or 1) <= 0 then return false, nil, "grey or no vendor price (the junk seller's)" end
    if not fresh and not Sells(id) then return false, nil, "Mastercraft doesn't say VENDOR" end
    local gdb = S.GearMaticDB()
    if gdb and type(gdb.sellIgnore) == "table" and gdb.sellIgnore[id] then return false, nil, "on GearMatic's never-sell list" end
    local keep = _G.MasterOptions_MastercraftKeep
    if keep and keep.IsNeeded(id) then return false, nil, "kept (Mastercraft Keep: guide, tracker or KEEP)" end
    local price = select(11, GetInfo(link))
    if not price then return false, nil, "item info not loaded yet" end
    if price <= 0 then return false, nil, "no vendor price" end
    local gear = IsEquippable(link) and true or false
    if gear and Mode() ~= "all" then return false, price, "gear (sell mode is Goods)" end
    if fresh then
        local sell = readCache and readCache[id]
        if sell == nil then
            local verdict, _, keepSome = S.MastercraftSlotAdvice(bag, slot)
            sell = verdict == "VENDOR" and not keepSome
            if readCache then readCache[id] = sell end
        end
        if not sell then return false, price, "Mastercraft doesn't say VENDOR" end
    end
    if gear then
        local stays, why = GearStays(link, bag, slot, id)
        if stays then return false, price, "kept gear - " .. (why or "GearMatic / Pawn keeps it") end
    end
    return true, price
end

-- For the junk coins in the bags (Baganator_Mastercraft, GearMatic_Baganator): no tooltip reads, what's known.
-- info: the slot's C_Container info when the caller has it already
local function WouldSell(bag, slot, itemID, info)
    if not (bag and slot) or Mode() == "off" then return false end
    if itemID and not Sells(itemID) then return false end -- (most slots end here)
    if not Seller() then return false end
    info = info or slotInfo(bag, slot)
    if not info or (itemID and info.itemID ~= itemID) then return false end
    local ok, sell = Check("bag icon", pcall(SlotSells, bag, slot, info, false))
    return ok and sell == true
end

---------------------------------------------------------------------------
-- /mo vendor: every bag item Mastercraft says (or last said) to VENDOR, and whether it's sold - or the rule that
-- stops it. Reads each item's advice fresh, like a vendor visit does; prints, sells nothing.
---------------------------------------------------------------------------
local function Explain()
    local head = "|cffffd200Master Options:|r "
    local seller = Seller()
    local gm, p = S.GearMatic(), S.GearMaticProfile()
    local why
    if not seller then
        if not gm then why = "GearMatic isn't loaded, and Mastercraft's own junk selling is off"
        elseif not p then why = "GearMatic's settings aren't readable (GearMatic.db.profile)"
        elseif p.autoSellJunk == false then why = "GearMatic's Sell junk is off, and so is Mastercraft's"
        elseif not (gm.VendorAutomation and gm.VendorAutomation.SellJunk) then why = "GearMatic has no VendorAutomation.SellJunk"
        else why = "?" end
    end
    print(head .. ("sell mode %s, junk seller %s%s."):format(Mode(), seller or "none", why and (" (" .. why .. ")") or ""))
    local bag2 = _G.Baganator and _G.Baganator.API
    local plugin
    if bag2 and bag2.IsJunkPluginActive then
        for _, id in ipairs({ "gearmatic", "mastercraft" }) do
            if bag2.IsJunkPluginActive(id) then plugin = id end
        end
        print(head .. "Baganator's junk coin: " .. (plugin or "another plugin (not GearMatic or Mastercraft)"))
    end
    if not _G.MasterOptions_MastercraftAdvice then
        print(head .. "the Mastercraft / Advice module is off: no junk coins for VENDOR items between visits.")
    end
    if GameTooltip:IsShown() then GameTooltip:Hide() end
    local shown, seen = 0, {}
    for bag = 0, LAST_BAG do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] and (info.quality or 1) > 0 and not info.hasNoValue then
                seen[id] = true
                local verdict, _, keepSome = S.MastercraftSlotAdvice(bag, slot)
                if verdict == "VENDOR" or Sells(id) then
                    local okS, sell, _, reason = pcall(SlotSells, bag, slot, info, true, nil)
                    if not okS then sell, reason = false, "error: " .. tostring(sell) end
                    if verdict == "VENDOR" and keepSome and not sell then reason = "your guide uses some of them" end
                    if sell and Mode() == "off" then sell, reason = false, "sell mode is Off" end
                    if sell and not seller then sell, reason = false, "no junk seller" end
                    local icon = ""
                    if plugin == "gearmatic" or plugin == "mastercraft" then
                        icon = WouldSell(bag, slot, id, info) and "  |cff9d9d9d(junk coin)|r" or "  |cff9d9d9d(no junk coin)|r"
                    end
                    local said = verdict and (verdict .. (keepSome and ", keep some for a guide" or "")) or "no advice now"
                    print(("  %s - Mastercraft: %s - %s%s"):format(info.hyperlink or ("item " .. id), said,
                        sell and "|cff40ff40sold at the vendor|r" or ("|cffff6060not sold:|r " .. tostring(reason)), icon))
                    shown = shown + 1
                end
            end
        end
    end
    if shown == 0 then print(head .. "nothing in your bags that Mastercraft says to VENDOR.") end
end

MasterOptions_MastercraftVendorSell = { WouldSell = WouldSell, Explain = Explain }
S.Command("vendor", Explain, "vendor - what Mastercraft says to VENDOR in your bags, and why each is (not) sold")

---------------------------------------------------------------------------
-- The bags: every slot Mastercraft says to VENDOR (read fresh)
---------------------------------------------------------------------------
local function Candidates()
    local out, byID = {}, {} -- one tooltip read per item: the advice is per item
    for bag = 0, LAST_BAG do
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
-- Selling
---------------------------------------------------------------------------
local merchantOpen, run = false, 0

-- GearMatic: on its "always sell" list for this visit, then into its sell pass
local function ClearGearMaticMarks()
    local gdb = S.GearMaticDB()
    if not gdb or type(gdb.moSell) ~= "table" then return end
    for id in pairs(gdb.moSell) do
        if type(gdb.sellMark) == "table" then gdb.sellMark[id] = nil end
    end
    gdb.moSell = nil
end

local function SellWithGearMatic(list)
    local gdb = S.GearMaticDB()
    local va = S.GearMatic().VendorAutomation
    if not gdb then return end
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
    Check("GearMatic's sell pass", pcall(va.SellJunk))
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

-- a grey with a vendor price still in the bags: Mastercraft's own junk pass isn't done
local function GreysLeft()
    for bag = 0, LAST_BAG do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            -- (a locked one is a sale on its way: still waiting)
            if info and info.quality == 0 and not info.hasNoValue then return true end
        end
    end
    return false
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
    -- an item's tooltip on screen: reading through GameTooltip would take it away - a moment later (at most a few
    -- seconds, then anyway)
    tries = tries or 0
    if tries < 6 and S.ItemTooltipShown() then
        C_Timer.After(0.5, function() Check("at the vendor", pcall(OnMerchant, tries + 1)) end)
        return
    end
    local ok, list = Check("finding what to sell", pcall(Candidates))
    if not ok or #list == 0 then return end
    if seller == "gearmatic" then
        SellWithGearMatic(list)
    else
        -- after Mastercraft's own grey sales (different items, but the server drops sales sent at once): since
        -- 2.1.2 it sells them in up to 3 passes, 0.15 s apart - so wait until no grey with a price is left in the
        -- bags (checked every 0.5 s, at most ~8 s)
        local waited = 0
        local function AfterGreys()
            if not merchantOpen then return end
            if GreysLeft() and waited < 16 then
                waited = waited + 1
                return C_Timer.After(0.5, AfterGreys)
            end
            SellOurselves(list)
        end
        C_Timer.After(1, AfterGreys)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftVendorDB = MasterOptions_MastercraftVendorDB or {}
        DB = MasterOptions_MastercraftVendorDB
        DB.mode = DB.mode or "goods"
    elseif event == "PLAYER_LOGIN" then
        ClearGearMaticMarks() -- (a visit cut short by a disconnect)
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

S.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
