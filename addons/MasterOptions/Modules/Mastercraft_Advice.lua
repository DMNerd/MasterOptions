-- Master Options module: runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_Advice", { "Mastercraft" }, function(ADDON)

-- Mastercraft's advice per item (KEEP / VENDOR / AUCTION / DISENCHANT), remembered: what VendorSell's bag icons and
-- Baganator's advice icons show without a tooltip read. Learned from every tooltip GameTooltip shows of an item you
-- have (yours, and the hidden reads of the modules that read bag slots - MasterOptions_Shared.ReadMastercraftAdvice;
-- not the auction house's, a chat link's or a quest reward's), and for new items in your bags in the background, a
-- few at a time when no tooltip is on screen and out of combat.
-- Selling never trusts this: at a vendor every item is read again.
--
-- MasterOptions_MastercraftAdviceDB.advice[itemID] = "KEEP" (also "VENDOR, but keep some for a guide") | "VENDOR" |
-- "AUCTION" | "DISENCHANT" | "NO PRICES"; nil = no advice known.

local S = MasterOptions_Shared
local DB
local numSlots = C_Container.GetContainerNumSlots
local slotID = C_Container.GetContainerItemID
local slotInfo = C_Container.GetContainerItemInfo
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

-- a change redraws Baganator's icons - once when a background batch ends, else a moment after
local filling, dirty = false, false
local function Changed()
    if filling then dirty = true else S.RefreshBagButtons() end
end

local function Remember(itemID, verdict, _, keepSome)
    if not (DB and itemID) then return end
    local advice = verdict and ((verdict == "VENDOR" and keepSome) and "KEEP" or verdict) or nil
    if DB.advice[itemID] ~= advice then
        DB.advice[itemID] = advice
        Changed()
    end
end
S.OnMastercraftAdvice(ADDON, Remember)

---------------------------------------------------------------------------
-- New items in the bags, read in the background (each item once per session: what was remembered from last time is
-- brought up to date; a hover keeps it so after that)
---------------------------------------------------------------------------
local fillPending, tried, merchantOpen = false, {}, false
local Fill
local function FillSoon(delay)
    if fillPending then return end
    fillPending = true
    C_Timer.After(delay or 0.5, Fill)
end

Fill = function()
    fillPending = false
    if not DB or merchantOpen then return end
    if (InCombatLockdown and InCombatLockdown()) or GameTooltip:IsShown() then return FillSoon(2) end
    filling = true
    local reads = 0
    for bag = 0, LAST_BAG do
        for slot = 1, (numSlots(bag) or 0) do
            local id = slotID(bag, slot) -- (no table: most slots were tried already)
            if id and not tried[id] then
                tried[id] = true
                local info = slotInfo(bag, slot)
                if info and (info.quality or 1) > 0 and not info.hasNoValue then
                    if reads >= 15 then
                        tried[id] = nil
                        filling = false
                        return FillSoon(0.5)
                    end
                    reads = reads + 1
                    Remember(id, S.MastercraftSlotAdvice(bag, slot))
                end
            end
        end
    end
    filling = false
    if dirty then dirty = false; S.RefreshBagButtons() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftAdviceDB = MasterOptions_MastercraftAdviceDB or {}
        DB = MasterOptions_MastercraftAdviceDB
        DB.advice = DB.advice or {}
        -- (2.13.0: was MasterOptions_MastercraftVendorDB.advice / .sell, kept by the VendorSell module)
        local old = _G.MasterOptions_MastercraftVendorDB
        if type(old) == "table" then
            if type(old.advice) == "table" then
                for id, a in pairs(old.advice) do if DB.advice[id] == nil then DB.advice[id] = a end end
            end
            old.advice, old.sell = nil, nil
        end
    elseif event == "PLAYER_LOGIN" then
        FillSoon(5) -- (after Mastercraft has its prices and guides in)
    elseif event == "BAG_UPDATE_DELAYED" then
        FillSoon(0.5)
    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true -- (selling: the bags change all the time, and VendorSell reads them itself)
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        FillSoon(1)
    end
end)

local function Get(itemID) return DB and DB.advice[itemID] or nil end
MasterOptions_MastercraftAdvice = {
    Get = Get,
    Sells = function(itemID) return Get(itemID) == "VENDOR" end, -- (VENDOR, none of it kept for a guide)
}

S.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
