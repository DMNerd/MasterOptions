-- Master Options module (was the addon MasterOptions_CheapUpgrades_Baganator): runs when CheapUpgrades and Baganator are loaded.
MasterOptions_Module("CheapUpgrades_Baganator", { "CheapUpgrades", "Baganator" }, function(ADDON)

-- CheapUpgrades <-> Baganator compatibility patch.
--
-- CheapUpgrades draws its "+23%" bag badges on Blizzard's bags, Bagnon and EllesmereUI only.
-- This registers the same badge as a Baganator corner widget, so Baganator owns its position
-- (Baganator settings > Icons) and show/hide.

local CU = _G.CheapUpgrades
local api = _G.Baganator and _G.Baganator.API
if type(CU) ~= "table" or type(api) ~= "table" or not api.RegisterCornerWidget then return end

local ID = "cheapupgrades_badge"

local function OnInit(itemButton)
    local fs = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    fs.sizeFont = true
    return fs
end

local function OnUpdate(fs, details)
    if not (CU.db and CU.db.bagBadges) then return false end
    local text = MasterOptions_Shared.CheapUpgradesBadge(details and details.itemLink)
    if not text then return text end -- (nil: CheapUpgrades not ready yet; false: no badge)
    fs:SetText(text)
    return true
end

api.RegisterCornerWidget("CheapUpgrades badge", ID, OnUpdate, OnInit,
    { corner = "bottom_left", priority = 1 })

-- When CheapUpgrades re-evaluates (new gear, spec change, new prices), ask Baganator to redraw.
if CU.Bags and type(CU.Bags.Refresh) == "function" then
    hooksecurefunc(CU.Bags, "Refresh", function()
        if api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
    end)
end
end)
