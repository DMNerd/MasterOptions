-- Master Options module (was the addon MasterOptions_Mastercraft_BankMats): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_BankMats", { "Mastercraft" }, function(ADDON)

-- Mastercraft guide materials into and out of the bank: two buttons under the bank window (the game's or
-- Baganator's), and if you like the storing done by itself when you open the bank.
--
-- How many of each item is Mastercraft's advice for it, read by item through a hidden GameTooltip (its advice counts
-- what you have everywhere, bank too). A stack is split when only part of it goes.
--   Store mats    click: what a guide needs - "... guide still needs N" / "... guide uses all N you have": all you
--                 carry; "Keep K for your ... guide - you have H, the other G can go": the K not in the bank yet
--                 (the other G stay in your bags, to be sold)
--                 Shift-click: what you track too ("You're tracking it")
--   Take mats     click: what guides need and what you track, less what's in your bags already ("Keep K ...": K)
--                 Shift-click: what Mastercraft says to AUCTION - for "Keep K ...", only the other G
-- Never stored: other KEEP items (tools, fishing gear, food), what Mastercraft says to VENDOR or AUCTION, what you
-- put on Mastercraft's "Never in the bank" list, what the open bank tab can't take (bound items in the account bank).
-- A stack at a time, stopping when the bank or your bags are full, the bank closes or a fight starts.
-- Mastercraft's own Grab mats / Deposit mats move whole stacks by kind, from its bank pop-up (off by default).
--
-- MasterOptions_MastercraftBankDB.mode: storing by itself at the bank - "off" (the default) | "guide" | "tracked"

local DB
local numSlots = C_Container.GetContainerNumSlots
local slotInfo = C_Container.GetContainerItemInfo
local numFree = C_Container.GetContainerNumFreeSlots
local useItem = C_Container.UseContainerItem or UseContainerItem

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local function Mode() return DB and DB.mode or "off" end

---------------------------------------------------------------------------
-- The bank (as Mastercraft does it: the tab type open in the bank window, yours or the account's)
---------------------------------------------------------------------------
local function BankWindow()
    if BankFrame and BankFrame:IsVisible() then return BankFrame end
    local skins = _G.Baganator and Baganator.API and Baganator.API.Skins
    local ok, skin = false, nil
    if skins and skins.GetCurrentSkin then ok, skin = pcall(skins.GetCurrentSkin) end
    if ok and type(skin) == "string" then
        for _, view in ipairs({ "Single", "Category" }) do
            local f = _G["Baganator_" .. view .. "ViewBankViewFrame" .. skin]
            if type(f) == "table" and f.IsVisible and f:IsVisible() then return f end
        end
    end
end

local function BankType()
    local win = BankWindow()
    for _, w in ipairs({ win ~= BankFrame and win or nil, BankFrame }) do
        if w and w.GetBankType then
            local ok, t = pcall(w.GetBankType, w)
            if ok and t ~= nil then return t end
        elseif w and w.GetActiveBankType then
            local ok, t = pcall(w.GetActiveBankType, w)
            if ok and t ~= nil then return t end
        end
    end
    return Enum and Enum.BankType and Enum.BankType.Character
end

local function BankBags(bankType)
    if bankType ~= nil and C_Bank and C_Bank.FetchPurchasedBankTabIDs then
        local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
        if ok and type(ids) == "table" and #ids > 0 then return ids end
    end
    local bags = { BANK_CONTAINER or -1 }
    local first = (NUM_BAG_SLOTS or 4) + 1
    for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do bags[#bags + 1] = b end
    return bags
end

local function Allowed(bankType, bag, slot)
    local allowed = C_Bank and C_Bank.IsItemAllowedInBankType
    if not (allowed and bankType ~= nil and ItemLocation and ItemLocation.CreateFromBagAndSlot) then return true end
    local ok, yes = pcall(allowed, bankType, ItemLocation:CreateFromBagAndSlot(bag, slot))
    return not ok or yes ~= false
end

---------------------------------------------------------------------------
-- How many of each item, by Mastercraft's advice (read by item: it counts what you have everywhere, bank too)
---------------------------------------------------------------------------
local split = C_Container.SplitContainerItem
local pickup = C_Container.PickupContainerItem
local function Count(itemID, withBank)
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    return count and count(itemID, withBank) or 0
end
local function BagCount(itemID) return Count(itemID, false) end
local function BankCount(itemID) return math.max(0, Count(itemID, true) - Count(itemID, false)) end

local function NeedsAll(verdict, reason)
    return verdict == "KEEP" and (reason:find("guide still needs %d+") or reason:find("guide uses all %d+ you have")) ~= nil
end
local function KeepSome(reason)
    local keep, _, extra = reason:match("^Keep (%d+) for .- you have (%d+), the other (%d+) can go")
    return tonumber(keep), tonumber(extra)
end
local function Tracked(reason) return tonumber(reason:match("You're tracking it: %d+ / (%d+)")) end

-- into the bank, of `inBags`: what a guide needs (all of it, or of "Keep K ..." the K not in the bank yet - the
-- other G stay in your bags, to be sold); with `tracked`, what you track too
local function HowManyIn(verdict, reason, inBags, inBank, tracked)
    reason = reason or ""
    local n = 0
    if NeedsAll(verdict, reason) then
        n = inBags
    else
        local keep = KeepSome(reason)
        if keep then n = keep - inBank
        elseif tracked and Tracked(reason) then n = inBags end
    end
    return math.max(0, math.min(n, inBags))
end

-- out of the bank, of `inBank`: what guides need and what you track, less what's in your bags; with `auction`,
-- what Mastercraft says to AUCTION (for "Keep K ...": only the other G, less those you carry already)
local function HowMany(verdict, reason, inBank, inBags, auction)
    reason = reason or ""
    local keep, extra = KeepSome(reason)
    local n = 0
    if auction then
        if verdict == "AUCTION" then n = keep and (extra - math.max(0, inBags - keep)) or inBank end
    elseif NeedsAll(verdict, reason) then
        n = inBank
    elseif keep then
        n = keep - inBags
    else
        local want = Tracked(reason)
        if want then n = want - inBags end
    end
    return math.max(0, math.min(n, inBank))
end

---------------------------------------------------------------------------
-- The lists, and moving them: a stack at a time, split when only part of it goes
---------------------------------------------------------------------------
local function Never()
    local s = MasterOptions_Shared.MastercraftSettings()
    return s and type(s.depositNever) == "table" and s.depositNever or {}
end

local function BagIDs()
    local out = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do out[#out + 1] = bag end
    return out
end

-- the items in `bags`: { { itemID, count, slots = { { bag, slot } } } } - `leave(id, bag, slot)` true: not that one
local function Gather(bags, leave)
    local byID, order = {}, {}
    for _, bag in ipairs(bags) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            local id = info and info.itemID
            if id and not (leave and leave(id, bag, slot)) then
                local e = byID[id]
                if not e then e = { itemID = id, count = 0, slots = {} }; byID[id] = e; order[#order + 1] = e end
                e.count = e.count + (info.stackCount or 1)
                e.slots[#e.slots + 1] = { bag = bag, slot = slot }
            end
        end
    end
    return order
end

-- each item with `want` set by `howMany(verdict, reason, count, itemID)`, the ones with some to move
local function Wanted(items, howMany)
    local out = {}
    for _, e in ipairs(items) do
        local verdict, reason = MasterOptions_Shared.MastercraftItemAdvice(e.itemID)
        e.want = howMany(verdict, reason, e.count, e.itemID)
        if e.want > 0 then out[#out + 1] = e end
    end
    return out
end

local function StoreList(bankType, tracked)
    local never = Never()
    return Wanted(Gather(BagIDs(), function(id, bag, slot) return never[id] or not Allowed(bankType, bag, slot) end),
        function(verdict, reason, count, id) return HowManyIn(verdict, reason, count, BankCount(id), tracked) end)
end

local function TakeList(bankType, auction)
    return Wanted(Gather(BankBags(bankType)),
        function(verdict, reason, count, id) return HowMany(verdict, reason, count, BagCount(id), auction) end)
end

-- where `n` of an item can go in `bags`: a free slot (in a bag that takes anything), or a stack of it with room
local function Spot(bags, itemID, n)
    for _, bag in ipairs(bags) do
        local free, family = numFree(bag)
        if (free or 0) > 0 and (family or 0) == 0 then
            for slot = 1, (numSlots(bag) or 0) do
                if not slotInfo(bag, slot) then return bag, slot end
            end
        end
    end
    local max = C_Item and C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID)
    for _, bag in ipairs(bags) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            if info and info.itemID == itemID and not info.isLocked and max and (info.stackCount or 0) + n <= max then
                return bag, slot
            end
        end
    end
end

local bankOpen, run = false, 0
local function Say(text) print("|cff4da6ffMaster Options|r: " .. text) end

-- move `list` (Wanted's) into the bank (`toBank`) or out of it; `what` names it in the line said at the end
-- ("your guides need"), `quiet`: nothing said when nothing moved
local function Move(list, toBank, bankType, what, quiet)
    run = run + 1 -- (one move at a time: a running one stops)
    local me, moved, full = run, 0, false
    local into = toBank and BankBags(bankType) or BagIDs()
    local function Done()
        local where = toBank and "into your bank" or "out of your bank"
        if moved > 0 then
            Say(("moved %d item%s %s %s%s."):format(moved, moved == 1 and "" or "s", what, where,
                full and (toBank and " - your bank is full" or " - your bags are full") or ""))
        elseif full then
            Say(toBank and "your bank is full - nothing moved." or "your bags are full - nothing moved.")
        elseif not quiet then
            Say(("nothing %s to move %s."):format(what, where))
        end
    end
    local function Step()
        if me ~= run or not bankOpen or (InCombatLockdown and InCombatLockdown()) then return Done() end
        local e = list[1]
        if not e then return Done() end
        local from = e.slots[1]
        if e.want <= 0 or not from then table.remove(list, 1); return Step() end
        local info = slotInfo(from.bag, from.slot)
        if not info or info.itemID ~= e.itemID or info.isLocked then table.remove(e.slots, 1); return Step() end
        local n = math.min(info.stackCount or 1, e.want)
        local bag, slot = Spot(into, e.itemID, n)
        if not bag then full = true; return Done() end
        if n == (info.stackCount or 1) then
            -- (the whole stack: the game puts it away, stacking it with what's there)
            if toBank then useItem(from.bag, from.slot, nil, bankType, false) else useItem(from.bag, from.slot) end
            table.remove(e.slots, 1)
        else
            split(from.bag, from.slot, n) -- (part of it: split off, put down)
            pickup(bag, slot)
            if CursorHasItem and CursorHasItem() then ClearCursor() end
        end
        e.want, moved = e.want - n, moved + n
        C_Timer.After(0.2, Step)
    end
    Step()
end

-- a button's action: not in a fight, not with something on the cursor (it would be put down somewhere)
local function Ready()
    if not bankOpen then return false end
    if InCombatLockdown and InCombatLockdown() then Say("not in a fight.") return false end
    if CursorHasItem and CursorHasItem() then Say("put down what you're holding first.") return false end
    return true
end

local function Store(tracked, quiet)
    if not quiet and not Ready() then return end
    local bankType = BankType()
    Move(StoreList(bankType, tracked), true, bankType, tracked and "your guides need or you track" or "your guides need", quiet)
end

local function Take(auction)
    if not Ready() then return end
    local bankType = BankType()
    Move(TakeList(bankType, auction), false, bankType, auction and "to sell on the auction house" or "your guides need")
end

-- automatically, at the bank (the setting: off, guide, guide and tracked)
local function OnBank(tries)
    if not bankOpen or Mode() == "off" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- an item's tooltip on screen: reading through GameTooltip would take it away - a moment later
    tries = tries or 0
    if tries < 6 and MasterOptions_Shared.ItemTooltipShown() then
        C_Timer.After(0.5, function() Check("at the bank", pcall(OnBank, tries + 1)) end)
        return
    end
    Store(Mode() == "tracked", true)
end

---------------------------------------------------------------------------
-- The buttons: under the bank window, while the bank is open
---------------------------------------------------------------------------
local buttons
local function Button(name, label, action, lines)
    local b = CreateFrame("Button", name, UIParent, "UIPanelButtonTemplate")
    b:SetSize(100, 22)
    b:SetText(label)
    b:SetScript("OnClick", function()
        GameTooltip:Hide()
        Check(label, pcall(action, IsShiftKeyDown and IsShiftKeyDown()))
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(label, 1, 0.82, 0)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
        GameTooltip:AddLine("Master Options - Mastercraft's advice", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function ShowButtons()
    local win = BankWindow()
    if not win then return end
    if not buttons then
        local take = Button("MasterOptionsTakeMats", "Take mats", Take, {
            "Click: what your guides still need and what you track - only as many as you don't carry already.",
            "Shift-click: what Mastercraft says to auction - for a material a guide needs some of, only the rest." })
        local store = Button("MasterOptionsStoreMats", "Store mats", Store, {
            "Click: what your guides need - for a material you have more of, only what they need (the rest stays to be sold).",
            "Shift-click: what you track too." })
        buttons = { take = take, store = store } -- (only once they're whole)
    end
    local strata = win.GetFrameStrata and win:GetFrameStrata() or "HIGH"
    buttons.take:ClearAllPoints()
    buttons.take:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, -2)
    buttons.store:ClearAllPoints()
    buttons.store:SetPoint("TOPRIGHT", buttons.take, "TOPLEFT", -4, 0)
    for _, b in pairs(buttons) do b:SetFrameStrata(strata); b:Show() end
end
local function HideButtons() if buttons then for _, b in pairs(buttons) do b:Hide() end end end

MasterOptions_MastercraftBank = { Take = Take, Store = Store, HowMany = HowMany, HowManyIn = HowManyIn } -- (for the tests)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftBankDB = MasterOptions_MastercraftBankDB or {}
        DB = MasterOptions_MastercraftBankDB
        DB.mode = DB.mode or "off"
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        -- (after the bank window - Baganator's too - is up, and Mastercraft's pop-up has looked at the bags)
        C_Timer.After(0.8, function()
            Check("the bank buttons", pcall(ShowButtons))
            Check("at the bank", pcall(OnBank))
        end)
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        run = run + 1
        HideButtons()
    end
end)

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
