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

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)
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
local Shared = MasterOptions_Shared
local PawnUpgrade = Shared.KeepsGear          -- (Pawn or GearMatic: Master Options' shared check)
local LoadoutIDs = Shared.GearMaticLoadoutIDs -- (GearMatic loadouts: every item ID in them)

local function GearStays(link, bag, slot, itemID, loadouts)
    return loadouts[itemID] or PawnUpgrade(link) or Shared.GearMaticKeeps(link, bag, slot, itemID)
end

-- which of those keeps it (for /mo vendor)
local function GearStaysWhy(link, bag, slot, itemID, loadouts)
    if loadouts[itemID] then return "in a GearMatic loadout" end
    if type(_G.MasterOptions_PawnKeeps) == "function" and _G.MasterOptions_PawnKeeps(link) then
        return "Pawn: an upgrade, or your best / 2nd best for a scale"
    end
    local sk = _G.MasterOptions_GearMaticSpecKeeps
    if type(sk) == "table" and type(sk.KeepsMany) == "function" then
        local ok, out = pcall(sk.KeepsMany, { link })
        if ok and type(out) == "table" and out[link] then return "GearMatic: your best / 2nd best for one of your specs" end
    end
    local gm = GM()
    local bo = gm and gm.BagOverlay
    if bo and bo.MarkerVerdict then
        local ok, v = pcall(bo.MarkerVerdict, link, bag, slot)
        if ok and type(v) == "table" then
            if v.upgrade then return "GearMatic: an upgrade for you" end
            if v.alt and Shared.Soulbound(bag, slot, link) ~= true then return "GearMatic: an upgrade for one of your alts (not soulbound)" end
            if v.skull then return "GearMatic: best in slot" end
        end
    end
    local va = gm and gm.VendorAutomation
    if va and va.InEquipmentSet then
        local ok, inSet = pcall(va.InEquipmentSet, bag, slot, itemID)
        if ok and inSet then return "in an equipment set" end
    end
    if PawnUpgrade(link) then return "Pawn / GearMatic keeps it" end
    return nil
end

---------------------------------------------------------------------------
-- What Mastercraft last said per item (DB.sell[itemID] = true: VENDOR, false: anything else), for the bag
-- icons - learned from every item tooltip GameTooltip shows (yours and the hidden reads below). Selling
-- itself never trusts this: at the vendor every item is read again.
---------------------------------------------------------------------------
local Changed -- (below: redraws Baganator's junk coins)

-- DB.advice[itemID]: the verdict itself, for Baganator's advice icons ("KEEP" also when VENDOR keeps some for a guide)
local function Remember(itemID, verdict, keepSome)
    if not (DB and itemID) then return end
    local sell
    if verdict then sell = verdict == "VENDOR" and not keepSome end
    local advice = verdict and ((verdict == "VENDOR" and keepSome) and "KEEP" or verdict) or nil
    local changed = false
    if DB.sell[itemID] ~= sell then DB.sell[itemID] = sell; changed = true end
    if DB.advice[itemID] ~= advice then DB.advice[itemID] = advice; changed = true end
    if changed and Changed then Changed() end
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

-- sell, price - and when it isn't sold, why (for /mo vendor)
local function SlotSells(bag, slot, info, fresh, readCache)
    local id, link = info and info.itemID, info and info.hyperlink
    if not (id and link) then return false, nil, "no item" end
    if info.hasNoValue or (info.quality or 1) <= 0 then return false, nil, "grey or no vendor price (the junk seller's)" end
    local gdb = _G.GearMaticDB
    if type(gdb) == "table" and type(gdb.sellIgnore) == "table" and gdb.sellIgnore[id] then
        return false, nil, "on GearMatic's never-sell list"
    end
    local keep = _G.MasterOptions_MastercraftKeep
    if keep and keep.IsNeeded and keep.IsNeeded(id) then return false, nil, "kept (Mastercraft Keep: guide, tracker or KEEP)" end
    local price = select(11, GetInfo(link))
    if not price then return false, nil, "item info not loaded yet" end
    if price <= 0 then return false, nil, "no vendor price" end
    local gear = IsEquippable(link) and true or false
    if gear and Mode() ~= "all" then return false, price, "gear (sell mode is Goods)" end
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
    if not sell then return false, price, "Mastercraft doesn't say VENDOR" end
    if gear and GearStays(link, bag, slot, id, Loadouts()) then
        return false, price, "kept gear - " .. (GearStaysWhy(link, bag, slot, id, Loadouts()) or "GearMatic / Pawn keeps it")
    end
    return true, price
end

-- For the bag icons (MasterOptions_GearMatic_Baganator's junk coin): no tooltip reads, just what's known
local function WouldSell(bag, slot, itemID)
    if Mode() == "off" or not Seller() or not (bag and slot) then return false end
    local info = slotInfo(bag, slot)
    if not info or (itemID and info.itemID ~= itemID) then return false end
    local ok, sell = Check("bag icon", pcall(SlotSells, bag, slot, info, false))
    return ok and sell == true
end
-- /mo vendor: every bag item Mastercraft says (or last said) to VENDOR, and whether it's sold - or the rule that
-- stops it. Reads each item's advice fresh, like a vendor visit does; prints, sells nothing.
local function Explain()
    local head = "|cffffd200Master Options:|r "
    local seller = Seller()
    local p, va = GMProfile(), GM() and GM().VendorAutomation
    local why
    if not seller then
        if not GM() then why = "GearMatic isn't loaded, and Mastercraft's own junk selling is off"
        elseif not p then why = "GearMatic's settings aren't readable (GearMatic.db.profile)"
        elseif p.autoSellJunk == false then why = "GearMatic's Sell junk is off, and so is Mastercraft's"
        elseif not (va and va.SellJunk) then why = "GearMatic has no VendorAutomation.SellJunk"
        else why = "?" end
    end
    print(head .. ("sell mode %s, junk seller %s%s."):format(Mode(), seller or "none",
        why and (" (" .. why .. ")") or ""))
    local bagAPI2 = _G.Baganator and _G.Baganator.API
    local plugin
    if bagAPI2 and bagAPI2.IsJunkPluginActive then
        for _, id in ipairs({ "gearmatic", "mastercraft" }) do
            if bagAPI2.IsJunkPluginActive(id) then plugin = id end
        end
        print(head .. "Baganator's junk coin: " .. (plugin or "another plugin (not GearMatic or Mastercraft)"))
    end
    if GameTooltip:IsShown() then GameTooltip:Hide() end
    local shown, seen = 0, {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] and (info.quality or 1) > 0 and not info.hasNoValue then
                seen[id] = true
                local verdict, keepSome = SlotVerdict(bag, slot)
                if verdict == "VENDOR" or (DB and DB.sell[id] == true) then
                    local okS, sell, _, reason = pcall(SlotSells, bag, slot, info, true, nil)
                    if not okS then sell, reason = false, "error: " .. tostring(sell) end
                    if verdict == "VENDOR" and keepSome and not sell then reason = "your guide uses some of them" end
                    if sell and Mode() == "off" then sell, reason = false, "sell mode is Off" end
                    if sell and not seller then sell, reason = false, "no junk seller" end
                    local icon = ""
                    if plugin == "gearmatic" or plugin == "mastercraft" then
                        local cb = WouldSell(bag, slot, id)
                        icon = cb and "  |cff9d9d9d(junk coin)|r" or "  |cff9d9d9d(no junk coin)|r"
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

-- Baganator corner icon: Mastercraft's advice on every bag slot it has advice for (Baganator > Icons, or /mo >
-- Bags: "Mastercraft advice in bags"). Top right, after the never-sell lock and GearMatic's skull.
local ADVICE_ICONS = {
    KEEP = "Interface\\RaidFrame\\ReadyCheck-Ready",
    VENDOR = "Interface\\GossipFrame\\VendorGossipIcon",
    AUCTION = "Interface\\Minimap\\Tracking\\Auctioneer",
    DISENCHANT = "Interface\\Icons\\INV_Enchant_Disenchant",
}
MasterOptions_MastercraftVendorSell.ADVICE_ICONS = ADVICE_ICONS
MasterOptions_MastercraftVendorSell.Advice = function(itemID) return DB and DB.advice and DB.advice[itemID] end
if bagAPI and bagAPI.RegisterCornerWidget then
    local okR, err = pcall(bagAPI.RegisterCornerWidget, "Mastercraft advice (Master Options)", "masteroptions_mc_advice",
        function(tex, details)
            local id = type(details) == "table" and details.itemID
            local advice = id and DB and DB.advice and DB.advice[id]
            local path = advice and ADVICE_ICONS[advice]
            if not path then return false end
            -- the junk coin (and grey) already says it goes at the next vendor: no second icon for it
            if advice == "VENDOR" and details.isJunk == true then return false end
            tex:SetTexture(path)
            return true
        end,
        function(button)
            local t = button:CreateTexture(nil, "OVERLAY")
            t:SetSize(14, 14)
            return t
        end, { corner = "top_right", priority = 3 })
    if not okR then Check("adding the advice icons to Baganator", false, err) end
end

-- One verdict per bag slot: while the advice icons show, GearMatic's three "best gold" badges (vendor $, auction
-- price tag, disenchant marker) stay off - they say the same, and often disagree. Checked at every login.
local BEST_GOLD = { "bestGoldShowVendor", "bestGoldShowAuction", "bestGoldShowDisenchant" }
local function OneVerdictPerSlot()
    local api = _G.Baganator and _G.Baganator.API
    if not (api and api.IsCornerWidgetActive and api.IsCornerWidgetActive("masteroptions_mc_advice")) then return end
    local p = GMProfile()
    if type(p) ~= "table" then return end
    local changed = false
    for _, k in ipairs(BEST_GOLD) do
        if p[k] ~= false then p[k] = false; changed = true end
    end
    if changed and type(_G.MasterOptions_GMRefreshBagIcons) == "function" then pcall(_G.MasterOptions_GMRefreshBagIcons) end
end
MasterOptions_MastercraftVendorSell.OneVerdictPerSlot = OneVerdictPerSlot

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
    -- (also with selling off: the advice icons in the bags need the verdicts too)
    if not DB then return end
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

Changed = MasterOptions_Shared.Debounce(function()
    local api = _G.Baganator and _G.Baganator.API
    if api and api.RequestItemButtonsRefresh then pcall(api.RequestItemButtonsRefresh) end
end, 0.3)

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

-- a grey with a vendor price still in the bags: Mastercraft's own junk pass isn't done
local function GreysLeft()
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
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
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftVendorDB = MasterOptions_MastercraftVendorDB or {}
        DB = MasterOptions_MastercraftVendorDB
        DB.mode = DB.mode or "goods"
        DB.sell = DB.sell or {}
        DB.advice = DB.advice or {}
    elseif event == "PLAYER_LOGIN" then
        ClearGearMaticMarks() -- (a visit cut short by a disconnect)
        -- (after Baganator has put its corner settings in: it does at its own login)
        C_Timer.After(1, function() Check("turning GearMatic's badges off", pcall(OneVerdictPerSlot)) end)
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

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
