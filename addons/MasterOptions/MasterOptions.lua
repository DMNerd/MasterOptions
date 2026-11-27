-- Master Options: one window for the settings that overlap between installed addons.
-- It reads and writes each addon's own settings, so nothing here fights them: change a setting
-- in the addon itself and this window shows the new state next time it opens.

local _, MO = ... -- (MO: the addon's own table, shared by its files: AddonSettings.lua, Options.lua, Problems.lua,
-- Window.lua and Startup.lua follow this one, in the .toc's order)


local AddonLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
-- loaded: an addon - or one of our modules (Modules.lua: what were MasterOptions_* patch addons), running
local function Loaded(name)
    local m = _G.MasterOptions_Modules
    if m and type(name) == "string" and m.Has(name) then return m.IsActive(name) end
    return AddonLoaded(name)
end

---------------------------------------------------------------------------
-- Access to each addon's settings (nil when that addon isn't loaded)
---------------------------------------------------------------------------
local function GM()  -- GearMatic: AceDB profile
    local g = _G.GearMatic
    return Loaded("GearMatic") and type(g) == "table" and g.db and g.db.profile or nil
end
local function MC()  -- Mastercraft: MastercraftDB.settings (the same table it reads live)
    local db = _G.MastercraftDB
    return Loaded("Mastercraft") and type(db) == "table" and db.settings or nil
end
local function OMT() -- OpenMap_Tweaks
    local db = _G.OpenMapTweaksDB
    return Loaded("OpenMap_Tweaks") and type(db) == "table" and db or nil
end
local function CU()  -- CheapUpgrades
    local db = _G.CheapUpgradesDB
    return Loaded("CheapUpgrades") and type(db) == "table" and db or nil
end
local function AUC(key, value) -- Auctionator: through its own config (handles per-character config)
    local a = _G.Auctionator
    if not (Loaded("Auctionator") and type(a) == "table" and a.Config and a.Config.Get) then return nil end
    if value == nil then return a.Config.Get(key) and true or false end
    pcall(a.Config.Set, key, value)
end
local function SYN()
    local db = _G.SYNDICATOR_CONFIG
    return Loaded("Syndicator") and type(db) == "table" and db or nil
end
local function PAWN()
    local db = _G.PawnCommon
    return Loaded("Pawn") and type(db) == "table" and db or nil
end
local function SPK() -- Sparkles_Forever: SparklesDB (flat, account-wide; Sparkles reads it live)
    local db = _G.SparklesDB
    return Loaded("Sparkles_Forever") and type(db) == "table" and db or nil
end

-- GearMatic's bag icons after a look or size change: what its own settings page calls (Settings.lua, 6.10.1)
local function GMRefreshBagIcons()
    local gm = _G.GearMatic
    if not (Loaded("GearMatic") and type(gm) == "table") then return end
    local function try(t, k) if type(t) == "table" and type(t[k]) == "function" then pcall(t[k]) end end
    try(gm, "RefreshBoEBadgeTextures")
    try(gm, "RefreshBagIconSizes")
    try(gm.BagOverlay, "RepaintDecor")
    try(gm.BagOverlay, "RefreshAll")
    try(gm.QuestRewardHook, "RefreshVendorMarkers")
    try(gm.DisenchantWindow, "RequestRefresh")
    try(gm.Baganator, "RequestRefresh")
end
MasterOptions_GMRefreshBagIcons = GMRefreshBagIcons -- (for modules)

-- for the files after this one
MO.AUC = AUC
MO.CU = CU
MO.GM = GM
MO.GMRefreshBagIcons = GMRefreshBagIcons
MO.Loaded = Loaded
MO.MC = MC
MO.OMT = OMT
MO.PAWN = PAWN
MO.SPK = SPK
MO.SYN = SYN
