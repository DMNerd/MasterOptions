-- Master Options module: runs when Baganator and Mastercraft are loaded.
MasterOptions_Module("Baganator_Mastercraft", { "Baganator", "Mastercraft" }, function(ADDON)

-- Mastercraft in Baganator's bags:
--   * the junk plugin "Mastercraft (+ VENDOR advice)": what Mastercraft sells (greys), and with the VendorSell module
--     what it sells with them (Master Options > Bags > Junk coin in bags)
--   * a corner icon with Mastercraft's advice on every slot it has advice for (Mastercraft_Advice): a green tick for
--     KEEP, the vendor's bag for VENDOR, the auctioneer for AUCTION, the disenchant icon for DISENCHANT
--   * one verdict per slot: while the advice icons show, GearMatic's three "best gold" badges (vendor $, auction
--     price tag, disenchant marker - the same verdicts, often disagreeing) and its Bind on Equip badge (the same price
--     tag, which it falls back to) stay off, checked at every login

local S = MasterOptions_Shared
local _, Check = S.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)
local api = _G.Baganator and _G.Baganator.API
if type(api) ~= "table" then return end
local slotInfo = C_Container.GetContainerItemInfo

local function Advice(itemID)
    local a = _G.MasterOptions_MastercraftAdvice
    return a and a.Get(itemID) or nil
end

---------------------------------------------------------------------------
-- Junk coin "Mastercraft"
---------------------------------------------------------------------------
if api.RegisterJunkPlugin then
    api.RegisterJunkPlugin("Mastercraft (+ VENDOR advice)", "mastercraft", function(bagID, slotID, itemID)
        if not (bagID and slotID) then return false end
        local info = slotInfo(bagID, slotID)
        if not info or (itemID and info.itemID ~= itemID) then return false end
        local gdb = S.GearMaticDB()
        if gdb and type(gdb.sellIgnore) == "table" and gdb.sellIgnore[info.itemID] then return false end
        if info.quality == 0 then return not info.hasNoValue end
        local vs = _G.MasterOptions_MastercraftVendorSell
        return vs ~= nil and vs.WouldSell(bagID, slotID, info.itemID, info)
    end)
end

---------------------------------------------------------------------------
-- Advice icons (top right, after the never-sell lock and GearMatic's skull)
---------------------------------------------------------------------------
local ICONS = {
    KEEP = "Interface\\RaidFrame\\ReadyCheck-Ready",
    VENDOR = "Interface\\GossipFrame\\VendorGossipIcon",
    AUCTION = "Interface\\Minimap\\Tracking\\Auctioneer",
    DISENCHANT = "Interface\\Icons\\INV_Enchant_Disenchant",
}
local WIDGET = "masteroptions_mc_advice"
if api.RegisterCornerWidget then
    local ok, err = pcall(api.RegisterCornerWidget, "Mastercraft advice (Master Options)", WIDGET,
        function(tex, details)
            local id = type(details) == "table" and details.itemID
            local advice = id and Advice(id)
            local path = advice and ICONS[advice]
            if not path then return false end
            -- the junk coin (and grey) already says it goes at the next vendor: no second icon for it, whatever the
            -- advice (VENDOR; DISENCHANT on a soulbound piece you can't disenchant, sold too)
            if details.isJunk == true then return false end
            tex:SetTexture(path)
            return true
        end,
        function(button)
            local t = button:CreateTexture(nil, "OVERLAY")
            t:SetSize(14, 14)
            return t
        end, { corner = "top_right", priority = 3 })
    if not ok then Check("adding the advice icons to Baganator", false, err) end
end

---------------------------------------------------------------------------
-- One verdict per slot
---------------------------------------------------------------------------
local BEST_GOLD = { "bestGoldShowVendor", "bestGoldShowAuction", "bestGoldShowDisenchant" }
-- GearMatic's badges off (force: also while the icons aren't on yet - the /mo row turning them on)
local function OneVerdictPerSlot(force)
    if not force and not (api.IsCornerWidgetActive and api.IsCornerWidgetActive(WIDGET)) then return end
    local p = S.GearMaticProfile()
    if not p then return end
    local changed = false
    for _, k in ipairs(BEST_GOLD) do
        if p[k] ~= false then p[k] = false; changed = true end
    end
    -- with the best-gold badges off, GearMatic falls back to its Bind on Equip badge - a gold price tag on every piece
    -- still BoE, next to the AUCTION icon (Baganator's own "BoE" corner text still tells the binding, if you want it)
    if p.boeBadgeMode ~= "off" then p.boeBadgeMode = "off"; changed = true end
    if changed and type(_G.MasterOptions_GMRefreshBagIcons) == "function" then pcall(_G.MasterOptions_GMRefreshBagIcons) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- (after Baganator has put its corner settings in: it does at its own login)
    C_Timer.After(1, function() Check("turning GearMatic's badges off", pcall(OneVerdictPerSlot)) end)
end)

MasterOptions_BaganatorMastercraft = { OneVerdictPerSlot = OneVerdictPerSlot, ICONS = ICONS }
end)
