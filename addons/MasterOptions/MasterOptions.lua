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

---------------------------------------------------------------------------
-- Pawn's weights in GearMatic
---------------------------------------------------------------------------
-- With "Use Pawn weights" on, GearMatic asks Pawn itself what an item is worth, but it picks the
-- scale from EVERY Pawn scale of the class, shown in Pawn or not, taking the first by name when two
-- fit the spec. So Pawn's stock "Classic":ROGUE2 always beat "PawnForever":ROGUE2, whatever Pawn
-- showed. GearMatic skips a scale flagged Hidden (a flag Pawn itself no longer reads on its scales),
-- so while GearMatic uses Pawn, every scale this character doesn't show in Pawn gets that flag.
-- The flags are cleared at logout: nothing of this is saved into Pawn's settings.
-- Who judges upgrades, for every recommendation that involves Pawn: Pawn with Pawn Forever, else GearMatic
-- (the rule and why: Shared.lua, UpgradeJudge)
local Judge = MasterOptions_Shared.UpgradeJudge
local function PawnElseGearMatic() return Judge() end

local function GMUsesPawn()
    local g = GM()
    return g ~= nil and g.usePawnWeights == true and PAWN() ~= nil
end

local function PawnShows(s)
    local who = _G.PawnPlayerFullName
    local o = who and type(s.PerCharacterOptions) == "table" and s.PerCharacterOptions[who]
    return type(o) == "table" and o.Visible and true or false
end

-- Druids: Pawn (stock and Pawn Forever) numbers the specs Balance 1, Feral/Cat 2, Bear 3, Resto 4, while
-- GearMatic matches a scale to the talent tab (Balance 1, Feral 2, Resto 3), so a Resto druid got the Bear
-- scale. For druids GearMatic only sees the shown scale of the current spec (by Pawn's numbering, with
-- GearMatic's own Cat/Bear choice for Feral). Every other class numbers both the same way.
local function DruidPawnSpec()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end
    local gm = _G.GearMatic
    local si = type(gm) == "table" and gm.ScaleImport
    local ok, tab = pcall(function() return si and si.GetActiveSpecIndex and si.GetActiveSpecIndex() end)
    if not ok or not tab then return nil end
    if tab == 2 then
        local role = gm.GetFeralRole and select(2, pcall(gm.GetFeralRole))
        return role == "tank" and 3 or 2
    end
    if tab == 3 then return 4 end
    return tab
end

local function SyncPawnHidden()
    local pw = PAWN()
    if not (pw and type(pw.Scales) == "table") then return end
    local on = GMUsesPawn()
    if on and not _G.PawnPlayerFullName then return end -- Pawn not set up yet: don't hide everything
    local _, _, classID = UnitClass("player")
    local spec = on and DruidPawnSpec()
    if spec then -- only narrow it down when a shown scale fits the spec
        local fits = false
        for _, s in pairs(pw.Scales) do
            if type(s) == "table" and s.ClassID == classID and s.SpecID == spec and PawnShows(s) then fits = true end
        end
        if not fits then spec = nil end
    end
    for _, s in pairs(pw.Scales) do
        if type(s) == "table" then
            local hide = on and (not PawnShows(s) or (spec ~= nil and s.ClassID == classID and s.SpecID ~= spec))
            s.Hidden = hide or nil
        end
    end
end

-- Pawn scales for this character's class: Pawn Forever's or Pawn's stock ("Classic") ones. Pawn Forever's
-- own /pff only swaps per-spec scales, so a stock scale with no spec (like "Classic":ROGUE) stayed shown
-- next to Pawn Forever's. This swaps every scale of the class: what was shown of the other set is hidden and
-- the same specs are shown from this set; if none would be, all of this set's per-spec scales are shown.
local function SetPawnScales(useForever)
    local pw = PAWN()
    if not (pw and type(pw.Scales) == "table" and type(_G.PawnSetScaleVisible) == "function") then return end
    local _, _, classID = UnitClass("player")
    local ours = useForever and "PawnForever" or "Classic"
    local theirs = useForever and "Classic" or "PawnForever"
    local specs, anyOurs = {}, false
    for name, s in pairs(pw.Scales) do
        if type(s) == "table" and s.ClassID == classID and s.Provider == theirs and PawnShows(s) then
            if s.SpecID then specs[s.SpecID] = true end
            pcall(_G.PawnSetScaleVisible, name, false)
        end
    end
    for name, s in pairs(pw.Scales) do
        if type(s) == "table" and s.ClassID == classID and s.Provider == ours then
            if s.SpecID and specs[s.SpecID] and not PawnShows(s) then pcall(_G.PawnSetScaleVisible, name, true) end
            if PawnShows(s) then anyOurs = true end
        end
    end
    if not anyOurs then
        for name, s in pairs(pw.Scales) do
            if type(s) == "table" and s.ClassID == classID and s.Provider == ours and s.SpecID then
                pcall(_G.PawnSetScaleVisible, name, true)
            end
        end
    end
end

-- "Spec for Pawn and CheapUpgrades" (MasterOptionsDB.specFollow ~= false: Follow GearMatic). GearMatic works the
-- spec out from your talents (ScaleImport.GetActiveSpecIndex, the talent tab; its own Cat/Bear choice for Feral);
-- Pawn has no spec (it judges by every scale you show) and CheapUpgrades uses the one picked in its settings.
-- Following: Pawn shows only that spec's scale of each set in use, and CheapUpgrades' spec (and ticked specs)
-- is that one. Pawn and CheapUpgrades number druids Balance 1, Cat 2, Bear 3, Resto 4 (DruidPawnSpec).
local function GMSpec()
    local gm = _G.GearMatic
    local si = Loaded("GearMatic") and type(gm) == "table" and gm.ScaleImport
    if not (si and si.GetActiveSpecIndex) then return nil end
    local ok, tab = pcall(si.GetActiveSpecIndex)
    if not ok or type(tab) ~= "number" then return nil end
    local _, class = UnitClass("player")
    return (class == "DRUID") and DruidPawnSpec() or tab, tab
end
local function FollowSpecOn() return not (MasterOptionsDB and MasterOptionsDB.specFollow == false) end

local function FollowSpecPawn(spec)
    local pw = PAWN()
    if not (pw and type(pw.Scales) == "table" and type(_G.PawnSetScaleVisible) == "function" and _G.PawnPlayerFullName) then return end
    local _, _, classID = UnitClass("player")
    -- per set (provider) in use - one with a shown scale of this class - and only if it has this spec's scale
    local inUse, hasSpec = {}, {}
    for _, s in pairs(pw.Scales) do
        if type(s) == "table" and s.ClassID == classID and s.Provider then
            if PawnShows(s) then inUse[s.Provider] = true end
            if s.SpecID == spec then hasSpec[s.Provider] = true end
        end
    end
    for name, s in pairs(pw.Scales) do
        if type(s) == "table" and s.ClassID == classID and s.SpecID and inUse[s.Provider] and hasSpec[s.Provider] then
            local want = (s.SpecID == spec)
            if PawnShows(s) ~= want then pcall(_G.PawnSetScaleVisible, name, want) end
        end
    end
end

local function FollowSpecCheapUpgrades(spec, tab)
    local cu = _G.CheapUpgrades
    if not (Loaded("CheapUpgrades") and type(cu) == "table" and type(cu.chardb) == "table" and cu.Scoring
        and type(cu.Scoring.SPECS) == "table" and cu.GetClass) then return end
    local okC, class = pcall(cu.GetClass, cu)
    local list = okC and cu.Scoring.SPECS[class]
    if type(list) ~= "table" then return end
    local _, myClass = UnitClass("player")
    local key
    if myClass == "DRUID" then key = list[spec] and list[spec].key
    else
        key = list[tab] and list[tab].key
        -- (hunters: Survival has a melee build too - kept if that's the one picked)
        if myClass == "HUNTER" and tab == 3 and cu.chardb.spec == "SVMELEE" then key = "SVMELEE" end
    end
    if not key then return end
    local watch = cu.chardb.watchSpecs
    local onlyThis = type(watch) == "table" and watch[key] and next(watch, next(watch)) == nil
    if cu.chardb.spec == key and onlyThis then return end
    cu.chardb.watchSpecs = { [key] = true }
    if cu.SetSpec then pcall(cu.SetSpec, cu, key) else cu.chardb.spec = key end
end

local function FollowSpec()
    if not FollowSpecOn() then return end
    local spec, tab = GMSpec()
    if not spec then return end
    FollowSpecPawn(spec)
    FollowSpecCheapUpgrades(spec, tab)
end

-- Should an item be kept (not sold, not deleted) because of Pawn? An upgrade, or already your best or
-- second-best item, for a scale you show. While Pawn follows GearMatic's spec it shows one spec - then the
-- other specs' scales of the same sets count too, so off-spec gear stays kept: for the check only, their
-- Visible flags are set (Pawn's best-item scan reads that flag itself) and put back right after. Nothing is
-- shown differently; Pawn drops best-item data of hidden scales at logout anyway.
-- Used by Mastercraft_VendorSell, DeleteCheapestItem_Protect and GearMatic_SellGuard.
-- (MasterOptions_PawnKeepsMany: the same for many links at once, the scales widened once for all of them)
local function PawnReady()
    return type(_G.PawnGetItemData) == "function" and type(_G.PawnIsItemAnUpgrade) == "function"
end

-- (fills widened as it goes, so a stop half-way is still put back)
local function WidenPawn(widened)
    local pw, who = PAWN(), _G.PawnPlayerFullName
    if FollowSpecOn() and GMSpec() and pw and type(pw.Scales) == "table" and who then
        local _, _, classID = UnitClass("player")
        local inUse = {}
        for _, s in pairs(pw.Scales) do
            if type(s) == "table" and s.ClassID == classID and s.Provider and PawnShows(s) then inUse[s.Provider] = true end
        end
        for _, s in pairs(pw.Scales) do
            if type(s) == "table" and s.ClassID == classID and s.SpecID and inUse[s.Provider] and not PawnShows(s) then
                -- (an entry made here stays, with the best-item data Pawn works out in it, so the next check
                -- doesn't scan again; Pawn removes hidden scales' entries at logout)
                s.PerCharacterOptions = type(s.PerCharacterOptions) == "table" and s.PerCharacterOptions or {}
                local o = s.PerCharacterOptions[who]
                if type(o) ~= "table" then o = {}; s.PerCharacterOptions[who] = o end
                widened[#widened + 1] = { o = o, was = o.Visible }
                o.Visible = true
            end
        end
    end
end

local function RestorePawn(widened)
    for _, w in ipairs(widened) do w.o.Visible = w.was end
end

-- (the scales already widened)
local PawnKeepsOne = MasterOptions_Shared.PawnSaysKeep

function MasterOptions_PawnKeeps(link)
    if not PawnReady() then return false end
    local widened = {}
    pcall(WidenPawn, widened)
    local keeps = PawnKeepsOne(link)
    RestorePawn(widened)
    return keeps
end

-- links: a list of item links -> { [link] = true } for each one kept
function MasterOptions_PawnKeepsMany(links)
    local out = {}
    if not PawnReady() or #links == 0 then return out end
    local widened = {}
    pcall(WidenPawn, widened)
    for _, link in ipairs(links) do
        if PawnKeepsOne(link) then out[link] = true end
    end
    RestorePawn(widened)
    return out
end

-- Should an item be kept, by Pawn or by GearMatic? Pawn's check above (when Pawn is installed), or GearMatic's
-- best / 2nd best for any of your specs (Modules\GearMatic_SpecKeep.lua, when GearMatic is loaded) - either
-- one keeps it. Used by Mastercraft_VendorSell, DeleteCheapestItem_Protect and GearMatic_SellGuard.
local function SpecKeep()
    local m = _G.MasterOptions_GearMaticSpecKeeps
    return type(m) == "table" and type(m.KeepsMany) == "function" and m or nil
end

function MasterOptions_GearKeeps(link)
    if MasterOptions_PawnKeeps(link) then return true end
    local m = SpecKeep()
    if not m then return false end
    local ok, out = pcall(m.KeepsMany, { link })
    return ok and type(out) == "table" and out[link] == true
end

function MasterOptions_GearKeepsMany(links)
    local out = MasterOptions_PawnKeepsMany(links)
    local m = SpecKeep()
    if m then
        local rest = {}
        for _, link in ipairs(links) do if not out[link] then rest[#rest + 1] = link end end
        if #rest > 0 then
            local ok, more = pcall(m.KeepsMany, rest)
            if ok and type(more) == "table" then for link in pairs(more) do out[link] = true end end
        end
    end
    return out
end

local function ClearPawnHidden()
    local pw = PAWN()
    if not (pw and type(pw.Scales) == "table") then return end
    for _, s in pairs(pw.Scales) do
        if type(s) == "table" then s.Hidden = nil end
    end
end

-- GearMatic copies Pawn's scales on import and caches its scores: copy again and redraw.
local function RefreshGearMatic()
    local gm = _G.GearMatic
    if not (Loaded("GearMatic") and type(gm) == "table") then return end
    local function try(t, k, ...) if type(t) == "table" and type(t[k]) == "function" then pcall(t[k], ...) end end
    if GMUsesPawn() then try(gm.Pawn, "ImportAllScales", false) end
    try(gm.ScaleImport, "InvalidateSpecLogicCache")
    try(gm.Scoring2 and gm.Scoring2.BestItems, "Invalidate")
    try(gm.GearMap and gm.GearMap.Engine, "InvalidateScores")
    try(gm, "ItemTooltipHook_InvalidateHover")
    try(gm.BagOverlay, "Refresh")
    try(gm.Paperdoll, "Refresh")
    try(gm.Baganator, "RequestRefresh")
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
MO.ClearPawnHidden = ClearPawnHidden
MO.FollowSpec = FollowSpec
MO.FollowSpecOn = FollowSpecOn
MO.GM = GM
MO.GMRefreshBagIcons = GMRefreshBagIcons
MO.GMUsesPawn = GMUsesPawn
MO.Judge = Judge
MO.Loaded = Loaded
MO.MC = MC
MO.OMT = OMT
MO.PAWN = PAWN
MO.PawnElseGearMatic = PawnElseGearMatic
MO.PawnShows = PawnShows
MO.RefreshGearMatic = RefreshGearMatic
MO.SPK = SPK
MO.SYN = SYN
MO.SetPawnScales = SetPawnScales
MO.SyncPawnHidden = SyncPawnHidden
