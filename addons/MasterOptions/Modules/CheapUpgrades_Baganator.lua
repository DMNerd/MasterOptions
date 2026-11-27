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

-- Asked for every bag slot on every Baganator redraw, and each answer runs CheapUpgrades' whole upgrade check: the
-- badge kept per link until CheapUpgrades re-evaluates (below). "Not ready yet" (nil) isn't kept.
local badges = {}

local function OnUpdate(fs, details)
    if not (CU.db and CU.db.bagBadges) then return false end
    local link = details and details.itemLink
    if not link then return false end
    local text = badges[link]
    if text == nil then
        text = MasterOptions_Shared.CheapUpgradesBadge(link)
        if text == nil then return nil end -- (CheapUpgrades not ready yet: Baganator asks again)
        badges[link] = text
    end
    if not text then return false end
    fs:SetText(text)
    return true
end

api.RegisterCornerWidget("CheapUpgrades badge", ID, OnUpdate, OnInit,
    { corner = "bottom_left", priority = 1 })

-- When CheapUpgrades re-evaluates (new gear, spec change, new prices): its badges anew, and Baganator redraws
if CU.Bags and type(CU.Bags.Refresh) == "function" then
    hooksecurefunc(CU.Bags, "Refresh", function()
        badges = {}
        MasterOptions_Shared.RefreshBagButtons()
    end)
end
end)
