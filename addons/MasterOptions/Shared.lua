-- Master Options: checks used by more than one file (MasterOptions.lua and the modules). Loaded before them.
-- Each reads another addon only, and answers false / nil when that addon isn't there.
local S = {}
MasterOptions_Shared = S

---------------------------------------------------------------------------
-- Errors: a module's caught errors go to Master Options' error log (/mo > Problems)
--   local Report, Check = MasterOptions_Shared.ErrorReporters(ADDON)
--   Report(where, err)             logs err
--   Check(where, pcall(fn, ...))   logs the error when the call failed; passes the call's results through
---------------------------------------------------------------------------
function S.ErrorReporters(addon)
    local function Report(where, ...)
        local r = _G.MasterOptions_ReportError
        if r then r(addon, where, ...) end
    end
    local function Check(where, ok, ...)
        if not ok then Report(where, ...) end
        return ok, ...
    end
    return Report, Check
end

---------------------------------------------------------------------------
-- Gear to keep (selling, deleting)
---------------------------------------------------------------------------
local function NonEmpty(t) return type(t) == "table" and next(t) ~= nil end

-- Pawn, with the scales as they are: an upgrade for a scale you show, or already your best or second-best item
-- for one (Pawn's 3rd / 4th returns: an off-spec piece you keep in your bags is never "an upgrade", but it is
-- your best). False without Pawn.
function S.PawnSaysKeep(link)
    if type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return false end
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    local ok2, up, _, best, second = pcall(_G.PawnIsItemAnUpgrade, item)
    return ok2 and (NonEmpty(up) or NonEmpty(best) or NonEmpty(second)) or false
end

-- Pawn or GearMatic: Master Options' MasterOptions_GearKeeps (Pawn with every spec's scale while it follows
-- GearMatic's spec, or GearMatic's best / 2nd best for any spec); Pawn alone where that isn't loaded.
function S.KeepsGear(link)
    if type(_G.MasterOptions_GearKeeps) == "function" then return _G.MasterOptions_GearKeeps(link) end
    return S.PawnSaysKeep(link)
end

local function GM() local g = _G.GearMatic; return type(g) == "table" and g or nil end

-- GearMatic's own verdict on a bag slot: an upgrade (for you or an alt), best in slot, or in an equipment set
function S.GearMaticKeeps(link, bag, slot, itemID)
    local gm = GM()
    if not gm then return false end
    local bo = gm.BagOverlay
    if bo and bo.MarkerVerdict then
        local ok, v = pcall(bo.MarkerVerdict, link, bag, slot)
        if ok and type(v) == "table" and (v.upgrade or v.alt or v.skull) then return true end
    end
    local va = gm.VendorAutomation
    if va and va.InEquipmentSet then
        local ok, inSet = pcall(va.InEquipmentSet, bag, slot, itemID)
        if ok and inSet then return true end
    end
    return false
end

-- GearMatic loadouts: { [itemID] = true } for every item in them
function S.GearMaticLoadoutIDs()
    local ids = {}
    local gm = GM()
    local store = gm and gm.Loadouts and gm.Loadouts.Store
    if not (store and store.List and store.Get) then return ids end
    local ok, names = pcall(store.List)
    for _, name in ipairs(ok and names or {}) do
        local e = store.Get(name)
        for _, s in pairs(type(e) == "table" and e.slots or {}) do
            if type(s) == "table" and s.itemID then ids[s.itemID] = true end
        end
    end
    return ids
end

---------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------
local function AddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    return f and f(name) and true or false
end

-- Who judges upgrades, for every choice that involves Pawn (one judge, so the stat weights, bag arrows,
-- CheapUpgrades, quest rewards and Dungeon Journal's loot marks agree): "Pawn" with Pawn Forever installed
-- (weights made for WoW Forever), otherwise "GearMatic", whose own weights are simulated for WoW Forever - Pawn
-- without Pawn Forever only has its stock Classic scales. Pawn alone (no GearMatic) is still Pawn.
function S.UpgradeJudge()
    if AddOnLoaded("Pawn") and (AddOnLoaded("Pawn_Forever") or not AddOnLoaded("GearMatic")) then return "Pawn" end
    return "GearMatic"
end

-- Pawn: the biggest upgrade % across the scales Pawn shows for this character (nil = not an upgrade, or no Pawn;
-- false = Pawn hasn't got the item yet)
function S.PawnUpgradePercent(link)
    if type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return nil end
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    local ok2, list = pcall(_G.PawnIsItemAnUpgrade, item)
    if not ok2 or type(list) ~= "table" then return nil end
    local best
    for _, u in pairs(list) do
        if type(u) == "table" and type(u.PercentUpgrade) == "number" and (not best or u.PercentUpgrade > best) then
            best = u.PercentUpgrade
        end
    end
    return best
end

-- Same rule as CheapUpgrades' own Bigger(): an empty slot (no %) beats any %.
local function Bigger(a, b)
    if not b then return true end
    if not a.pct then return b.pct ~= nil end
    return b.pct ~= nil and a.pct > b.pct
end

-- CheapUpgrades' badge for an item ("+23%" in its colour, or "NEW" for an empty slot): the text, false when it
-- isn't an upgrade for a spec you watch, nil while CheapUpgrades isn't ready (ask again later)
function S.CheapUpgradesBadge(link)
    local cu = _G.CheapUpgrades
    if type(cu) ~= "table" or type(cu.WatchedInfo) ~= "function" then return false end
    if not cu.ctx then return nil end
    if type(link) ~= "string" or link == "" then return false end
    local ok, list = pcall(cu.WatchedInfo, cu, link)
    if not ok or type(list) ~= "table" then return nil end
    local best
    for _, e in ipairs(list) do
        if e.info and e.info.state == "upgrade" and Bigger(e.info, best) then best = e.info end
    end
    if not best then return false end
    local textOk, text = pcall(cu.Bags and cu.Bags.BadgeText, best)
    if not textOk or type(text) ~= "string" or text == "" then return false end
    return text
end

---------------------------------------------------------------------------
-- Mastercraft's Settings > Modules (2.1.2): MastercraftDB.settings.modules[key] = false turns a whole part off
-- ("tip": every tooltip line, "loot": the KEEP / VENDOR advice, "ah": the Scan prices button). On otherwise,
-- also before Mastercraft's saved settings are there.
---------------------------------------------------------------------------
function S.MastercraftModuleOn(key)
    local db = _G.MastercraftDB
    local m = type(db) == "table" and type(db.settings) == "table" and db.settings.modules
    return not (type(m) == "table" and m[key] == false)
end

---------------------------------------------------------------------------
-- OpenMap_MiniMap: the profile in use - this character's own (OpenMap keys it on the first name), or the shared one
---------------------------------------------------------------------------
function S.OpenMapMiniMapProfile()
    local db = _G.OpenMapMiniMapDB
    if type(db) ~= "table" then return nil end
    local first = UnitName("player")
    local c = first and type(db.char) == "table" and db.char[first .. "-" .. (GetRealmName() or "")]
    if type(c) == "table" and c.own and type(c.profile) == "table" then return c.profile end
    return type(db.profile) == "table" and db.profile or nil
end
