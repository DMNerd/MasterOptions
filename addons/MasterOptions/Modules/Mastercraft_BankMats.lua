-- Master Options module (was the addon MasterOptions_Mastercraft_BankMats): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_BankMats", { "Mastercraft" }, function(ADDON)

-- Mastercraft guide materials -> the bank, when you open it.
--
-- Mastercraft's own "Deposit mats" (its pop-up at the bank) works by kind: profession materials go, and by
-- default what your guides still need stays in your bags. This does the other half, on its own: what
-- Mastercraft keeps FOR A GUIDE goes into the bank, so you collect it there - and everything it says to VENDOR
-- or AUCTION stays in your bags, to be sold.
--
-- What goes is what Mastercraft's advice says, read fresh for each bag item through a hidden GameTooltip (as
-- MasterOptions_Mastercraft_VendorSell does): KEEP with the reason "... guide still needs N" or "... guide
-- uses all N you have" (and, in "guide and tracked" mode, "You're tracking it"). Never moved:
--   * other KEEP items - tools, fishing gear, food and drink (Mastercraft's own keep rules)
--   * "Keep 5 for your guide, the other 3 can go": VENDOR/AUCTION with some to keep - it stays, for selling
--   * what you put on Mastercraft's "Never in the bank" list (its pop-up's gear > Choose)
--   * what the open bank tab can't take (bound items in the account bank)
-- Once per bank visit, a stack at a time, stopping when the bank is full or closes or a fight starts.
-- Mastercraft's Grab mats brings them back when you want to craft.
--
-- MasterOptions_MastercraftBankDB.mode: "guide" | "tracked" (guide and tracked) | "off"

local DB
local numSlots = C_Container.GetContainerNumSlots
local slotInfo = C_Container.GetContainerItemInfo
local numFree = C_Container.GetContainerNumFreeSlots
local useItem = C_Container.UseContainerItem or UseContainerItem

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local function Mode() return DB and DB.mode or "guide" end

---------------------------------------------------------------------------
-- Mastercraft's advice for a bag slot: the verdict and the reason line under it
---------------------------------------------------------------------------
local function Strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- Mastercraft's KEEP reasons (Loot.lua): only ever written under a KEEP verdict
local KEEP_REASONS = { "guide still needs", "guide uses all", "^You're tracking it:" }
local function KeepReason(t)
    for _, p in ipairs(KEEP_REASONS) do if t:find(p) then return true end end
end

local function ReadTooltip(tip)
    local name = tip:GetName()
    local header
    for i = 1, tip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local text = left and left:GetText()
        if type(text) == "string" then
            if not header and text:find("Mastercraft", 1, true) then
                header = i
                local right = _G[name .. "TextRight" .. i]
                local r = right and right:IsShown() and right:GetText()
                if type(r) == "string" and r ~= "" then
                    local reason = _G[name .. "TextLeft" .. (i + 1)]
                    reason = reason and reason:GetText()
                    return Strip(r):upper(), type(reason) == "string" and Strip(reason) or ""
                end
            elseif header then
                -- an item you track: Mastercraft's header comes first, without the verdict (its "Tracking" row
                -- under it), and the advice's reason line further down - known by its wording
                local t = Strip(text)
                if KeepReason(t) then return "KEEP", t end
            end
        end
    end
end

local function SlotAdvice(bag, slot)
    local tip = GameTooltip
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    local ok = pcall(tip.SetBagItem, tip, bag, slot)
    local okR, verdict, reason = false
    if ok then okR, verdict, reason = Check("reading Mastercraft's advice", pcall(ReadTooltip, tip)) end
    tip:Hide()
    if okR then return verdict, reason end
end

-- true: a guide (or, in "tracked" mode, your tracker) is what keeps it
local function ForGuide(verdict, reason)
    if verdict ~= "KEEP" or not reason then return false end
    if reason:find("guide still needs", 1, true) or reason:find("guide uses all", 1, true) then return true end
    return Mode() == "tracked" and reason:find("tracking it", 1, true) ~= nil
end

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

local function BankFree(bankType)
    local free = 0
    for _, b in ipairs(BankBags(bankType)) do free = free + (numFree(b) or 0) end
    return free
end

local function Allowed(bankType, bag, slot)
    local allowed = C_Bank and C_Bank.IsItemAllowedInBankType
    if not (allowed and bankType ~= nil and ItemLocation and ItemLocation.CreateFromBagAndSlot) then return true end
    local ok, yes = pcall(allowed, bankType, ItemLocation:CreateFromBagAndSlot(bag, slot))
    return not ok or yes ~= false
end

---------------------------------------------------------------------------
-- What goes, and moving it
---------------------------------------------------------------------------
local function Never()
    local s = type(_G.MastercraftDB) == "table" and _G.MastercraftDB.settings
    return type(s) == "table" and type(s.depositNever) == "table" and s.depositNever or {}
end

local function Candidates(bankType)
    local out, byID, never = {}, {}, Never()
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = slotInfo(bag, slot)
            local id = info and info.itemID
            if id and not info.isLocked and not never[id] then
                local go = byID[id]
                if go == nil then -- (one read per item: the advice is per item)
                    go = ForGuide(SlotAdvice(bag, slot))
                    byID[id] = go
                end
                if go and Allowed(bankType, bag, slot) then
                    out[#out + 1] = { bag = bag, slot = slot, itemID = id }
                end
            end
        end
    end
    return out
end

local bankOpen, run = false, 0

local function Deposit(list, bankType)
    run = run + 1
    local me, moved, full = run, 0, false
    local function Done()
        if moved > 0 then
            print(("|cff4da6ffMaster Options|r: moved %d stack%s of guide materials to your bank%s."):format(
                moved, moved == 1 and "" or "s", full and " - your bank is full" or ""))
        end
    end
    local function Step()
        if me ~= run or not bankOpen or (InCombatLockdown and InCombatLockdown()) then return Done() end
        local c = table.remove(list, 1)
        if not c then return Done() end
        if BankFree(bankType) == 0 then full = true; return Done() end
        local now = slotInfo(c.bag, c.slot)
        if now and now.itemID == c.itemID and not now.isLocked then
            useItem(c.bag, c.slot, nil, bankType, false)
            moved = moved + 1
        end
        C_Timer.After(0.15, Step)
    end
    Step()
end

local function OnBank(tries)
    if not bankOpen or Mode() == "off" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- an item's tooltip on screen: reading through GameTooltip would take it away - a moment later
    tries = tries or 0
    if tries < 6 and GameTooltip:IsShown() and GameTooltip:GetOwner() ~= WorldFrame and GameTooltip:GetItem() then
        C_Timer.After(0.5, function() Check("at the bank", pcall(OnBank, tries + 1)) end)
        return
    end
    local bankType = BankType()
    local ok, list = Check("finding guide materials", pcall(Candidates, bankType))
    if ok and #list > 0 then Deposit(list, bankType) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftBankDB = MasterOptions_MastercraftBankDB or {}
        DB = MasterOptions_MastercraftBankDB
        DB.mode = DB.mode or "guide"
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        -- (after the bank window - Baganator's too - is up, and Mastercraft's pop-up has looked at the bags)
        C_Timer.After(0.8, function() Check("at the bank", pcall(OnBank)) end)
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        run = run + 1
    end
end)

-- (Master Options runs this after the saved variables are in: the setup this did on its own ADDON_LOADED as a
-- separate addon, now)
local h = f.GetScript and f:GetScript("OnEvent") or f.OnEvent -- (f.OnEvent: the sandbox tests' frames)
if h then h(f, "ADDON_LOADED", ADDON) end
end)
