-- Master Options module (was the addon MasterOptions_GearMatic_Baganator): runs when GearMatic and Baganator are loaded.
MasterOptions_Module("GearMatic_Baganator", { "GearMatic", "Baganator" }, function(ADDON)

-- GearMatic <-> Baganator compatibility patch.
--
-- GearMatic already gives Baganator its upgrade chevron, BiS skull and upgrade plugin. Two things it has
-- that Baganator can't see:
--
-- 1. Junk: GearMatic's vendor sweep sells more than greys (its junk list, marked items, outgrown gear and
--    low-value items when turned on). Registered as a Baganator junk plugin "GearMatic", so the junk coin
--    (and junk sorting) shows exactly what GearMatic will sell. Pick it in Baganator > Junk, or in /mo.
-- 2. Loadouts: GearMatic's own gear loadouts registered as a Baganator equipment-set source, so their
--    items get Baganator's equipment-set border and icon like Blizzard set items.
--
-- Only GearMatic's public tables are read (GearMatic = its namespace); nothing in GearMatic is changed.

local gm = _G.GearMatic
local api = _G.Baganator and _G.Baganator.API
if type(gm) ~= "table" or type(api) ~= "table" then return end

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local function Settings() return gm.db and gm.db.profile end

---------------------------------------------------------------------------
-- 1. Junk: the same rules as GearMatic's VendorAutomation.SellJunk, item by item
---------------------------------------------------------------------------
local GetQuality = (C_Item and C_Item.GetItemQualityByID) or function(id) return select(3, GetItemInfo(id)) end

if api.RegisterJunkPlugin then
    api.RegisterJunkPlugin("GearMatic", "gearmatic", function(bagID, slotID, itemID)
        local VA, s = gm.VendorAutomation, Settings()
        if not (VA and s and itemID) then return false end
        if VA.IsSellIgnored and VA.IsSellIgnored(itemID) then return false end
        -- greys and the junk list (kept when the item is in an equipment set)
        if GetQuality(itemID) == 0 or (VA.IsJunk and VA.IsJunk(itemID)) then
            return not (VA.InEquipmentSet and VA.InEquipmentSet(bagID, slotID, itemID))
        end
        -- what Mastercraft says to VENDOR, when the MasterOptions_Mastercraft_VendorSell patch will sell it
        local vs = _G.MasterOptions_MastercraftVendorSell
        if vs and vs.WouldSell and vs.WouldSell(bagID, slotID, itemID) then return true end
        -- items you marked to sell
        if VA.MarkSellCheck and VA.MarkSellCheck(bagID, slotID, itemID) then return true end
        if VA.IsSellMarked and VA.IsSellMarked(itemID) then return false end
        -- outgrown gear (only with GearMatic's "sell gear" on) and the low-value rule (has its own threshold)
        if s.autoSellGear == true and VA.GearSellCheck and VA.GearSellCheck(bagID, slotID) then return true end
        if VA.ValueSellCheck and VA.ValueSellCheck(bagID, slotID) then return true end
        return false
    end)
end

---------------------------------------------------------------------------
-- 2. Loadouts as an equipment-set source
---------------------------------------------------------------------------
local byItem, names -- built on first use, dropped when a loadout changes

local function Build()
    byItem, names = {}, {}
    local store = gm.Loadouts and gm.Loadouts.Store
    if not (store and store.List and store.Get) then return end
    for _, name in ipairs(store.List()) do
        local e = store.Get(name)
        if type(e) == "table" then
            names[#names + 1] = name
            for slotID, s in pairs(e.slots or {}) do
                if type(s) == "table" and s.itemID and not (e.ignore and e.ignore[slotID]) then
                    local list = byItem[s.itemID] or {}
                    byItem[s.itemID] = list
                    local seen = false
                    for _, r in ipairs(list) do if r.name == name then seen = true end end
                    if not seen then list[#list + 1] = { name = name, iconTexture = e.icon } end
                end
            end
        end
    end
end

local function Changed()
    byItem, names = nil, nil
    if api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
end

if api.RegisterItemSetSource then
    api.RegisterItemSetSource("GearMatic loadouts", "gearmatic_loadouts", function(_, _, itemLink)
        if not itemLink then return end
        local itemID = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(itemLink)
        if not itemID then return end
        if not byItem then Check("reading GearMatic loadouts", pcall(Build)) end
        return byItem and byItem[itemID]
    end, function()
        if not names then Check("reading GearMatic loadouts", pcall(Build)) end
        return names or {}
    end)

    local store = gm.Loadouts and gm.Loadouts.Store
    if store then
        for _, fn in ipairs({ "Save", "Delete", "Rename", "SetIgnore", "SetIcon", "Import" }) do
            if type(store[fn]) == "function" then hooksecurefunc(store, fn, Changed) end
        end
    end
end
end)
