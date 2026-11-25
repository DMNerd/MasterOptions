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

-- Same rule as CheapUpgrades' own Bigger(): an empty slot (no %) beats any %.
local function Bigger(a, b)
    if not b then return true end
    if not a.pct then return b.pct ~= nil end
    return b.pct ~= nil and a.pct > b.pct
end

local function OnInit(itemButton)
    local fs = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    fs.sizeFont = true
    return fs
end

local function OnUpdate(fs, details)
    if not (CU.db and CU.db.bagBadges) then return false end
    if not CU.ctx then return nil end -- CheapUpgrades not ready yet
    local link = details and details.itemLink
    if not link or link == "" then return false end
    local ok, list = pcall(CU.WatchedInfo, CU, link)
    if not ok or type(list) ~= "table" then return nil end
    local best
    for _, e in ipairs(list) do
        if e.info and e.info.state == "upgrade" and Bigger(e.info, best) then best = e.info end
    end
    if not best then return false end
    local textOk, text = pcall(CU.Bags.BadgeText, best)
    if not textOk or not text or text == "" then return false end
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
