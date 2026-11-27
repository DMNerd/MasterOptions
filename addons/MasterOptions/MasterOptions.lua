-- Master Options: one window for the settings that overlap between installed addons.
-- It reads and writes each addon's own settings, so nothing here fights them: change a setting
-- in the addon itself and this window shows the new state next time it opens.

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

local function NonEmpty(t) return type(t) == "table" and next(t) ~= nil end

-- (the scales already widened)
local function PawnKeepsOne(link)
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    local ok2, up, _, best, second = pcall(_G.PawnIsItemAnUpgrade, item)
    return ok2 and (NonEmpty(up) or NonEmpty(best) or NonEmpty(second)) or false
end

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

---------------------------------------------------------------------------
-- Bag icon size: every icon any addon puts in a corner of Baganator's bag slots, one size
-- Baganator hands each corner widget, as it creates it, to its skin listeners (API.Skins.RegisterListener,
-- regionType "CornerWidget", tags = { widget id }): an icon (texture or frame) is scaled there. Text (item
-- level, counts, "+23%") is left alone - Baganator sizes it by its own font size (the sizeFont ones). GearMatic's
-- widgets are sized by GearMatic itself (its bagIconSize, also for its bottom-left badge, which isn't a widget):
-- the row sets that instead, so nothing is scaled twice.
---------------------------------------------------------------------------
local ICON_SCALE = { Large = 1, Medium = 23 / 28, Small = 18 / 28 } -- (GearMatic's steps: its badge 28 / 23 / 18)
local GM_ICON_SIZE = { Large = "large", Medium = "medium", Small = "small" }

local function BagIconSize() return MasterOptionsDB and MasterOptionsDB.bagIconSize or "Large" end

local function ScaleCornerIcon(details)
    if type(details) ~= "table" or details.regionType ~= "CornerWidget" then return end
    local r, id = details.region, type(details.tags) == "table" and details.tags[1]
    if type(r) ~= "table" or type(r.SetScale) ~= "function" or r.sizeFont then return end
    if r.GetObjectType and r:GetObjectType() == "FontString" then return end
    if type(id) == "string" and id:find("^gearmatic") then return end
    r:SetScale(ICON_SCALE[BagIconSize()] or 1)
end

local function ApplyBagIconSize()
    local api = _G.Baganator and _G.Baganator.API and _G.Baganator.API.Skins
    if api and api.GetAllFrames then
        for _, details in ipairs(api.GetAllFrames() or {}) do pcall(ScaleCornerIcon, details) end
    end
    local s = Loaded("GearMatic") and GM()
    local gmSize = GM_ICON_SIZE[BagIconSize()]
    -- (only once you've picked a size here: until then GearMatic keeps its own)
    if s and MasterOptionsDB and MasterOptionsDB.bagIconSize and s.bagIconSize ~= gmSize then
        s.bagIconSize = gmSize
        GMRefreshBagIcons()
    end
end

do
    local api = Loaded("Baganator") and _G.Baganator and _G.Baganator.API and _G.Baganator.API.Skins
    if api and api.RegisterListener then
        api.RegisterListener(function(details) pcall(ScaleCornerIcon, details) end)
    end
end

---------------------------------------------------------------------------
-- Baganator and Chattynator settings: the active profile table (written directly; they read it on reload)
---------------------------------------------------------------------------
local function ProfileOf(addon, config, current)
    local c = _G[config]
    if not (Loaded(addon) and type(c) == "table" and type(c.Profiles) == "table") then return nil end
    return c.Profiles[_G[current] or "DEFAULT"] or c.Profiles.DEFAULT
end
local function BAG()  return ProfileOf("Baganator", "BAGANATOR_CONFIG", "BAGANATOR_CURRENT_PROFILE") end
local function CHAT() return ProfileOf("Chattynator", "CHATTYNATOR_CONFIG", "CHATTYNATOR_CURRENT_PROFILE") end

local CORNERS = { "icon_top_left_corner_array", "icon_top_right_corner_array",
                  "icon_bottom_left_corner_array", "icon_bottom_right_corner_array" }
local function CornerHas(p, id)
    for _, k in ipairs(CORNERS) do
        if type(p[k]) == "table" then
            for _, v in ipairs(p[k]) do if v == id then return true end end
        end
    end
    return false
end
local function CornerRemove(p, id)
    for _, k in ipairs(CORNERS) do
        local arr = p[k]
        if type(arr) == "table" then
            for i = #arr, 1, -1 do if arr[i] == id then table.remove(arr, i) end end
        end
    end
end
local function CornerAdd(p, id, key)
    if CornerHas(p, id) then return end
    p[key] = type(p[key]) == "table" and p[key] or {}
    table.insert(p[key], 1, id)
end

-- DeleteCheapestItem: its AceDB profile (found through AceDB's registry, as its own table is private)
local function DCIProfile()
    if not Loaded("DeleteCheapestItem") or type(_G.DCI_ProfilesDB) ~= "table" then return nil end
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if not (AceDB and AceDB.db_registry) then return nil end
    for db in pairs(AceDB.db_registry) do
        if db.sv == _G.DCI_ProfilesDB then return db.profile end
    end
end

-- Baganator switches to a plugin as it registers whenever the chosen one isn't a registered plugin ("Greys only"
-- = "poor_quality" and "Off" = "none" never are) unless that plugin is on its *_plugin_ignored list (API\Main.lua
-- AutoSet). Its own settings window fills that list on every change; writing the choice directly didn't - so
-- "Greys only" came back as GearMatic's coins after a reload. Every plugin we know of goes on the list, the
-- chosen one off it.
local KNOWN_PLUGINS = {
    junk = { "gearmatic", "mastercraft", "selljunk", "scrap", "vendor", "dejunk", "peddler", "enhanceqol_vendor" },
    upgrade = { "pawn", "gearmatic_upgrade", "simple_item_levels" },
}
local function SetBagPlugin(p, kind, id)
    p[kind .. "_plugin"] = id
    local key = kind .. "_plugin_ignored"
    p[key] = type(p[key]) == "table" and p[key] or {}
    for _, other in ipairs(KNOWN_PLUGINS[kind]) do p[key][other] = true end
    p[key][id] = nil
end

-- Baganator: the two bag-icon rows, on any profile
local function ApplyUpgradeArrow(p, v)
    if v == "Pawn" and not Loaded("Pawn") then return end
    if v == "GearMatic" and not Loaded("GearMatic") then return end
    CornerRemove(p, "pawn"); CornerRemove(p, "gearmatic_upgrade_corner")
    if v == "Pawn" then CornerAdd(p, "pawn", CORNERS[1])
    elseif v == "GearMatic" then CornerAdd(p, "gearmatic_upgrade_corner", CORNERS[1]) end
    SetBagPlugin(p, "upgrade", (v == "Pawn" and "pawn") or (v == "GearMatic" and "gearmatic_upgrade") or "none")
end
local function ApplyJunk(p, v)
    if v == "GearMatic" and Loaded("MasterOptions_GearMatic_Baganator") then SetBagPlugin(p, "junk", "gearmatic")
    elseif v == "Mastercraft" and Loaded("MasterOptions_Mastercraft_VendorSell") then SetBagPlugin(p, "junk", "mastercraft")
    else SetBagPlugin(p, "junk", "poor_quality") end -- (Mastercraft without the VendorSell patch sells greys only)
end
local function ArrowState(p)
    local pw, gm = CornerHas(p, "pawn"), CornerHas(p, "gearmatic_upgrade_corner")
    if pw and gm then return "Both (conflict)" end
    return pw and "Pawn" or gm and "GearMatic" or "Off"
end
local function JunkState(p)
    return (p.junk_plugin == "gearmatic" and "GearMatic") or (p.junk_plugin == "mastercraft" and "Mastercraft") or "Greys only"
end

---------------------------------------------------------------------------
-- UI style: each addon's own skin setting, WoW (Blizzard-like) or Dark. nil = leave that addon as it is.
---------------------------------------------------------------------------
local function DetailsInstances()
    local d = _G.Details
    if not (Loaded("Details") and type(d) == "table" and d.GetAllInstances) then return {} end
    local out = {}
    for _, inst in ipairs(d:GetAllInstances() or {}) do
        if type(inst) == "table" and inst.ativa and inst.ChangeSkin then out[#out + 1] = inst end
    end
    return out
end

-- Town NPCs (auctioneer, banker, innkeeper ...): the game's minimap tracking and Questie's townsfolk show the
-- same kinds. TOWN: the kinds both have, under the same (English) name.
local TOWN = { "Auctioneer", "Banker", "Battlemaster", "Innkeeper", "Mailbox", "Repair", "Stable Master", "Flight Master" }

-- the game's tracking list: name -> { index, active }
local function TownTracking()
    local out = {}
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return out end
    local okN, n = pcall(C_Minimap.GetNumTrackingTypes)
    for i = 1, (okN and n or 0) do
        local ok, a, _, c = pcall(C_Minimap.GetTrackingInfo, i)
        if ok then
            local name, active
            if type(a) == "table" then name, active = a.name, a.active else name, active = a, c end -- (table on newer clients)
            if type(name) == "string" then out[name] = { index = i, active = active == true } end
        end
    end
    return out
end
local function QuestieTown()
    local q = Loaded("Questie") and type(_G.Questie) == "table" and _G.Questie.db and _G.Questie.db.profile
    if not q then return nil end
    q.townsfolkConfig = type(q.townsfolkConfig) == "table" and q.townsfolkConfig or {}
    return q.townsfolkConfig
end
-- Questie draws its townsfolk again from its settings (its own login pass: off first, then what's ticked)
local function QuestieTownRefresh()
    local ql = _G.QuestieLoader
    if not (type(ql) == "table" and ql.ImportModule) then return end
    local ok, menu = pcall(ql.ImportModule, ql, "QuestieMenu")
    if ok and type(menu) == "table" and menu.OnLogin then pcall(menu.OnLogin, menu, true) end
end
-- OpenMap draws some of the same kinds on the world map (Map\Townsfolk.lua, from Questie's database; all off
-- by default): with Questie's on too, each shows twice there. (Not on the minimap, so the game's tracking and
-- OpenMap's don't double.) Questie's name -> OpenMap's key.
local TOWN_OPENMAP = { Auctioneer = "auctioneer", Banker = "banker", Innkeeper = "innkeeper", Mailbox = "mailbox",
                       Repair = "repair", ["Stable Master"] = "stable" }
local function OpenMapTown()
    local om = Loaded("OpenMap") and _G.OpenMap
    local mod = type(om) == "table" and om.GetModule and om:GetModule("worldmap")
    if mod and type(mod.db) == "table" and type(mod.db.townsfolk) == "table" then return mod.db.townsfolk, mod end
end
local function TownGet()
    local t, q = TownTracking(), QuestieTown()
    if not q then return "Questie" end
    local o = OpenMapTown() or {}
    local game, questie = false, false
    for _, k in ipairs(TOWN) do
        local g, qq = t[k] and t[k].active, q[k] == true
        if g and qq then return "Both (conflict)" end
        if qq and TOWN_OPENMAP[k] and o[TOWN_OPENMAP[k]] == true then return "Both (conflict)" end
        game, questie = game or g, questie or qq
    end
    return (game and not questie) and "Game's tracking" or "Questie"
end
-- the kinds you have on (in either) move to the one picked; the other turns them off
local function TownSet(v)
    local t, q = TownTracking(), QuestieTown()
    if not q then return end
    local o, omMod = OpenMapTown()
    local setTracking = C_Minimap and C_Minimap.SetTracking
    local omChanged = false
    for _, k in ipairs(TOWN) do
        local g = t[k]
        local ok = o and TOWN_OPENMAP[k]
        local on = (g and g.active) or q[k] == true or (ok and o[ok] == true)
        if v == "Questie" then
            if on then q[k] = true end
            if g and g.active and setTracking then pcall(setTracking, g.index, false) end
            -- (Questie's own world map icons: OpenMap's of the same kind off, else each shows twice there)
            if ok and o[ok] == true then o[ok] = false; omChanged = true end
        elseif g then -- (a kind the game's list doesn't have stays with Questie)
            if on and not g.active and setTracking then pcall(setTracking, g.index, true) end
            if q[k] then q[k] = false end
        end
    end
    if omChanged and omMod and omMod.RefreshTownsfolk then pcall(omMod.RefreshTownsfolk, omMod) end
    QuestieTownRefresh()
end

-- OpenMap_MiniMap: the profile in use - this character's own (OpenMap keys it on the first name), or the shared one
local function OMM()
    local db = _G.OpenMapMiniMapDB
    if not (Loaded("OpenMap_MiniMap") and type(db) == "table") then return nil end
    local first = UnitName("player")
    local c = first and type(db.char) == "table" and db.char[first .. "-" .. (GetRealmName() or "")]
    if type(c) == "table" and c.own and type(c.profile) == "table" then return c.profile end
    return type(db.profile) == "table" and db.profile or nil
end

local STYLES = {
    -- (OpenMap's minimap, square either way: WoW = its gold frame round map and zone bar, Dark = the thin
    -- dark border, its default)
    { name = "OpenMap_MiniMap", label = "OpenMap minimap (shape / border)", wow = "square / gold", dark = "square / dark", reload = true,
      get = function()
          local p = OMM(); if not p then return nil end
          return (p.shape or "square") .. " / " .. (p.border or "dark")
      end,
      set = function(v)
          local p = OMM(); if not p then return end
          local shape, border = v:match("^(%a+) / (%a+)$")
          if shape then p.shape, p.border = shape, border end
      end },
    { name = "Baganator", wow = "blizzard", dark = "dark", reload = true,
      get = function() local p = BAG(); return p and p.current_skin end,
      set = function(v) local p = BAG(); if p then p.current_skin = v end end },
    { name = "Chattynator", wow = "blizzard", dark = "dark", reload = true,
      get = function() local p = CHAT(); return p and p.current_skin end,
      set = function(v) local p = CHAT(); if p then p.current_skin = v end end },
    { name = "Details", wow = "WoW Interface", dark = "Minimalistic",
      get = function()
          local list = DetailsInstances()
          if #list == 0 then return nil end
          local s = list[1].skin
          for _, inst in ipairs(list) do if inst.skin ~= s then return "mixed" end end
          return s
      end,
      set = function(v) for _, inst in ipairs(DetailsInstances()) do pcall(inst.ChangeSkin, inst, v) end end },
    { name = "Mastercraft", wow = "wow", dark = "midnight", reload = true,
      get = function() local m = MC(); return m and (m.theme or "wow") end,
      set = function(v) local m = MC(); if m then m.theme = v end end },
    { name = "BetterBlizzFrames", label = "BetterBlizzFrames dark mode", wow = false, dark = true, reload = true,
      get = function()
          local db = _G.BetterBlizzFramesDB
          if not (Loaded("BetterBlizzFrames") and type(db) == "table") then return nil end
          return db.darkModeUi == true
      end,
      set = function(v) local db = _G.BetterBlizzFramesDB; if type(db) == "table" then db.darkModeUi = v end end },
    -- Forever's own bronze window frame is the WoW look; its alternative is a plain Blizzard frame, not a dark
    -- one, so Dark leaves it alone.
    { name = "DeleteCheapestItem", label = "DeleteCheapestItem bronze frame", wow = false, dark = nil, reload = true,
      get = function() local p = DCIProfile(); if p then return p.HideBronzeTheme == true end end,
      set = function(v) local p = DCIProfile(); if p then p.HideBronzeTheme = v end end },
}

local function StyleAvailable(s) return Loaded(s.name) and s.get() ~= nil end

local UIStyleGet, UIStyleSet, UIStyleTip
local function styleMatches(look)
    local any = false
    for _, s in ipairs(STYLES) do
        local want = s[look]
        if want ~= nil and StyleAvailable(s) then
            any = true
            if s.get() ~= want then return false end
        end
    end
    return any
end
UIStyleGet = function()
    if styleMatches("wow") then return "WoW" end
    if styleMatches("dark") then return "Dark" end
    return "Mixed"
end
UIStyleSet = function(v)
    local look = (v == "Dark") and "dark" or "wow"
    for _, s in ipairs(STYLES) do
        local want = s[look]
        if want ~= nil and StyleAvailable(s) and s.get() ~= want then pcall(s.set, want) end
    end
end
UIStyleTip = function()
    local lines = { "Switches every addon that has its own skin to the Blizzard-like look (WoW) or its dark one. Baganator, Chattynator, Mastercraft, BetterBlizzFrames and OpenMap's minimap (square either way - WoW: the gold frame; Dark: the thin dark border) change after a reload; Details at once. Addons without a skin setting (Auctionator, Questie, OpenMap, Pawn, GearMatic, CheapUpgrades) already use Blizzard frames.", " " }
    for _, s in ipairs(STYLES) do
        if StyleAvailable(s) then
            local cur = s.get()
            local tag = (cur == s.wow) and "|cff88ff88WoW|r" or (s.dark ~= nil and cur == s.dark) and "|cffaaaaffDark|r" or ("|cffffcc00" .. tostring(cur) .. "|r")
            lines[#lines + 1] = (s.label or s.name) .. ": " .. tag
        end
    end
    return table.concat(lines, "\n")
end

local function GMBuiltinChosen()
    local gm = _G.GearMatic
    local key = type(gm) == "table" and gm.Compat and gm.Compat.CurrentCharKey and gm.Compat.CurrentCharKey()
    return key and gm.ScaleImport and gm.ScaleImport.IsBuiltinChosen and gm.ScaleImport.IsBuiltinChosen(key) or false
end

-- GearMatic treats nil as "on" (it only checks == false)
local function gmOn(key) local s = GM(); return s ~= nil and s[key] ~= false end
local function mcOn(key) local s = MC(); return s ~= nil and s[key] == true end
local function mcNotOff(key) local s = MC(); return s ~= nil and s[key] ~= false end
-- Mastercraft's Settings > Modules (2.1.2): settings.modules[key] = false turns a whole part off ("tip": every
-- tooltip line, "loot": the KEEP / VENDOR advice, "ah": the Scan prices button)
local function mcModule(key)
    local s = MC(); local m = s and s.modules
    return s ~= nil and not (type(m) == "table" and m[key] == false)
end
local function mcModuleOn(key) local s = MC(); if s and type(s.modules) == "table" then s.modules[key] = nil end end
-- a Mastercraft tooltip line: its own switch and Tooltip extras both on
local function mcTip(key) return mcNotOff(key) and mcModule("tip") end
local function mcSetTip(key, on)
    local m = MC(); if not m then return end
    m[key] = on
    if on then mcModuleOn("tip") end
end

---------------------------------------------------------------------------
-- Bag icons that follow your other choices (MasterOptionsDB.iconsMatch = { arrow = true, junk = true }):
--   upgrade arrow = whose upgrade judgement is in use (Stat weights: GearMatic on Pawn -> Pawn's arrow,
--                   GearMatic's own weights -> GearMatic's chevron)
--   junk coin     = what your junk seller will sell (Vendor: GearMatic's rules, or Mastercraft's greys and
--                   the VENDOR advice it sells with the VendorSell patch)
---------------------------------------------------------------------------
local MATCH_ARROW, MATCH_JUNK = "Match stat weights", "Match junk seller"

local function MatchedArrow()
    local g = GM()
    if g and not (g.usePawnWeights and not GMBuiltinChosen()) then return "GearMatic" end
    if Loaded("Pawn") then return "Pawn" end
    return g and "GearMatic" or "Off"
end
local function MatchedJunk()
    if gmOn("autoSellJunk") and GM() then return "GearMatic" end
    if mcOn("autoJunk") then return "Mastercraft" end
    return "Greys only"
end
local function IconsMatch() return MasterOptionsDB and MasterOptionsDB.iconsMatch or {} end

-- brings the matched icons up to date; true when Baganator's settings changed (they apply after a reload)
local function SyncIcons()
    local m, p = IconsMatch(), BAG()
    if not p then return false end
    local changed = false
    if m.arrow then
        local want = MatchedArrow()
        if ArrowState(p) ~= want then ApplyUpgradeArrow(p, want); changed = true end
    end
    if m.junk then
        local before = p.junk_plugin
        ApplyJunk(p, MatchedJunk())
        if p.junk_plugin ~= before then changed = true end
    end
    return changed
end

local function SetOMT(key, slashArg, want)
    local db = OMT(); if not db then return end
    if (db[key] and true or false) ~= want then
        -- the slash command toggles and refreshes the pins; fall back to writing it
        if SlashCmdList and SlashCmdList.OPENMAPTWEAKS then
            SlashCmdList.OPENMAPTWEAKS(slashArg)
        end
        if (db[key] and true or false) ~= want then db[key] = want end
    end
end

---------------------------------------------------------------------------
-- The options. "choice" rows: who handles it. "toggle" rows: on/off.
---------------------------------------------------------------------------
-- A "who shows this" row over any number of addons. sources: { name, get(), set(on) }.
-- Choosing one turns the others off; two or more on shows as a conflict.
local function Multi(label, rec, since, tip, sources, offLabel)
    local choices = {}
    for _, src in ipairs(sources) do choices[#choices + 1] = src[1] end
    choices[#choices + 1] = offLabel
    return {
        kind = "choice", label = label, rec = rec, since = since, tip = tip, choices = choices, off = offLabel,
        get = function()
            local on = {}
            for _, src in ipairs(sources) do
                if Loaded(src[1]) and src[2]() then on[#on + 1] = src[1] end
            end
            if #on > 1 then return "Both (conflict)" end
            return on[1] or offLabel
        end,
        set = function(v)
            for _, src in ipairs(sources) do
                if Loaded(src[1]) then pcall(src[3], v == src[1]) end
            end
        end,
    }
end

local SeedShared -- set below: copies this character's per-character choices to the account
local OPTIONS = {
    { header = "This account" },
    {
        kind = "toggle", label = "Same choices on every character", rec = true, since = 8,
        tip = "Most settings here are saved for your whole account already. The ones marked (per char) are saved per character (or per profile) by their addon. With this on, Master Options keeps your choice for those once, for the account, and applies it on every character at login - so a new character starts with your choices, not the recommended ones. Turning it on takes this character's current choices.",
        get = function() return MasterOptionsDB and MasterOptionsDB.syncChars and true or false end,
        set = function(v)
            MasterOptionsDB.syncChars = v or nil
            -- take this character's choices - after the rest of a login's setup, or at once from a click
            MasterOptionsDB.seedPending = v or nil
        end,
    },

    { header = "Vendor and bank" },
    {
        kind = "choice", label = "Sell junk automatically", rec = "GearMatic",
        tip = "GearMatic and Mastercraft both sell junk at every vendor. When both are on they sell the same items and the game can say \"item busy\".",
        choices = { "GearMatic", "Mastercraft", "Off" },
        get = function()
            local g, m = gmOn("autoSellJunk") and GM(), mcOn("autoJunk")
            if g and m then return "Both (conflict)" end
            return g and "GearMatic" or m and "Mastercraft" or "Off"
        end,
        set = function(v)
            local g, m = GM(), MC()
            if g then g.autoSellJunk = (v == "GearMatic") end
            if m then m.autoJunk = (v == "Mastercraft") end
        end,
    },
    {
        kind = "choice", label = "Also sell what Mastercraft says to VENDOR", rec = "Goods", since = 17,
        needs = "MasterOptions_Mastercraft_VendorSell", choices = { "Goods", "Goods and gear", "Off" },
        tip = "At a vendor, items whose Mastercraft advice is VENDOR are sold by the addon picked above (GearMatic: with its \"always sell\" list, for that visit only; Mastercraft: sold by the patch, as Mastercraft sells greys). Goods: materials, potions, food and other non-gear. Goods and gear: also gear, but never Pawn or GearMatic upgrades, set or loadout pieces. Never sold: what Mastercraft says to KEEP (or keep some of for a guide), AUCTION or DISENCHANT, and GearMatic's never-sell list. Nothing is sold when junk selling is Off. Needs the MasterOptions_Mastercraft_VendorSell patch.",
        get = function()
            local d = _G.MasterOptions_MastercraftVendorDB
            local m = type(d) == "table" and d.mode or "goods"
            return (m == "all" and "Goods and gear") or (m == "off" and "Off") or "Goods"
        end,
        set = function(v)
            MasterOptions_MastercraftVendorDB = MasterOptions_MastercraftVendorDB or {}
            MasterOptions_MastercraftVendorDB.mode = (v == "Goods and gear" and "all") or (v == "Off" and "off") or "goods"
        end,
    },
    {
        kind = "choice", label = "At the bank: guide materials go in", rec = "Guide mats", since = 18,
        needs = "MasterOptions_Mastercraft_BankMats", choices = { "Guide mats", "Guide and tracked mats", "Off" },
        tip = "When you open the bank, what Mastercraft keeps for your profession guides (\"... guide still needs\", \"... guide uses all you have\") goes into it, so you collect it there - Mastercraft's Grab mats brings it back to craft. What Mastercraft says to VENDOR or AUCTION stays in your bags to be sold, and so do tools, fishing gear, food, items you keep some of for a guide, and Mastercraft's \"Never in the bank\" list. Guide and tracked mats: your Mastercraft item tracker's items too. Needs the MasterOptions_Mastercraft_BankMats patch.",
        get = function()
            local d = _G.MasterOptions_MastercraftBankDB
            local m = type(d) == "table" and d.mode or "guide"
            return (m == "tracked" and "Guide and tracked mats") or (m == "off" and "Off") or "Guide mats"
        end,
        set = function(v)
            MasterOptions_MastercraftBankDB = MasterOptions_MastercraftBankDB or {}
            MasterOptions_MastercraftBankDB.mode = (v == "Guide and tracked mats" and "tracked") or (v == "Off" and "off") or "guide"
        end,
    },
    {
        kind = "choice", label = "Repair automatically", rec = "Mastercraft",
        tip = "Mastercraft repairs from the guild bank first when your rank allows it. GearMatic uses your own gold.",
        choices = { "Mastercraft", "GearMatic", "Off" },
        get = function()
            local g, m = gmOn("autoRepair") and GM(), mcOn("autoRepair")
            if g and m then return "Both (conflict)" end
            return g and "GearMatic" or m and "Mastercraft" or "Off"
        end,
        set = function(v)
            local g, m = GM(), MC()
            if g then g.autoRepair = (v == "GearMatic") end
            if m then m.autoRepair = (v == "Mastercraft") end
        end,
    },
    {
        kind = "toggle", label = "Mastercraft: repair from guild bank first", rec = true,
        needs = "Mastercraft",
        get = function() return mcNotOff("repairGuild") end,
        set = function(v) local m = MC(); if m then m.repairGuild = v end end,
    },

    { header = "Gathering nodes (ore and herbs)" },
    {
        kind = "choice", label = "World map pins from", rec = "OpenMap_Tweaks",
        tip = "Mastercraft and OpenMap_Tweaks both draw spawn points. Pick one to avoid two pins per node.",
        choices = { "Mastercraft", "OpenMap_Tweaks", "Off" },
        get = function()
            local m = MC() and mcNotOff("nodesWorldMap")
            local o = OMT() and OMT().gather
            if m and o then return "Both (conflict)" end
            return m and "Mastercraft" or o and "OpenMap_Tweaks" or "Off"
        end,
        set = function(v)
            local m = MC()
            if m then m.nodesWorldMap = (v == "Mastercraft") end
            SetOMT("gather", "gather", v == "OpenMap_Tweaks")
        end,
    },
    {
        kind = "choice", label = "Minimap pins from", rec = "OpenMap_Tweaks",
        tip = "OpenMap_Tweaks can only show minimap pins while its world map pins are on.",
        choices = { "Mastercraft", "OpenMap_Tweaks", "Off" },
        get = function()
            local m = MC() and mcNotOff("nodesMinimap")
            local o = OMT() and OMT().gather and OMT().gatherMinimap
            if m and o then return "Both (conflict)" end
            return m and "Mastercraft" or o and "OpenMap_Tweaks" or "Off"
        end,
        set = function(v)
            local m = MC()
            if m then m.nodesMinimap = (v == "Mastercraft") end
            if v == "OpenMap_Tweaks" then SetOMT("gather", "gather", true) end
            SetOMT("gatherMinimap", "gather minimap", v == "OpenMap_Tweaks")
        end,
    },

    {
        kind = "choice", label = "Which nodes show", rec = "Skill-ups only", since = 2,
        tip = "Mastercraft's node rule. With the MasterOptions_OpenMapTweaks_Mastercraft patch it also filters OpenMap_Tweaks' pins.",
        needs = "Mastercraft",
        choices = { "Skill-ups only", "Gatherable", "All" },
        get = function()
            local f = (MC() or {}).nodesFilter or "skillups"
            return f == "all" and "All" or f == "gatherable" and "Gatherable" or "Skill-ups only"
        end,
        set = function(v)
            local m = MC(); if not m then return end
            m.nodesFilter = v == "All" and "all" or v == "Gatherable" and "gatherable" or "skillups"
        end,
    },
    {
        kind = "choice", label = "When nodes show", rec = "While tracking", since = 2,
        tip = "While tracking: with Find Minerals / Find Herbs on (or while farming), not in towns, instances or combat. While farming: only after Mastercraft's Start farming (/mc farm). Never: no nodes at all.",
        needs = "Mastercraft",
        choices = { "While tracking", "While farming", "Always", "Never" },
        get = function()
            local w = (MC() or {}).nodesWhen or "tracking"
            return w == "always" and "Always" or w == "never" and "Never" or w == "farming" and "While farming" or "While tracking"
        end,
        set = function(v)
            local m = MC(); if not m then return end
            m.nodesWhen = v == "Always" and "always" or v == "Never" and "never" or v == "While farming" and "farming" or "tracking"
        end,
    },

    { header = "Maps" },
    {
        -- OpenMap and Dungeon Journal both show a map inside a dungeon; MasterOptions_DungeonJournal_OpenMap
        -- (which replaces OpenMap_NoDungeonMap) turns OpenMap's off and opens Dungeon Journal's from OpenMap's
        -- entrance icons instead. Read as that patch loads, so a change needs a reload.
        kind = "choice", label = "Map inside dungeons", rec = "Dungeon Journal", since = 11, reload = true,
        needs = { "OpenMap", "ForeverDungeonJournal", "MasterOptions_DungeonJournal_OpenMap" },
        choices = { "Dungeon Journal", "OpenMap" },
        tip = "OpenMap and Dungeon Journal both put a map of the dungeon on the world map when you're inside one. Dungeon Journal: OpenMap's own \"Dungeon maps inside dungeons\" is off (the rest of OpenMap's dungeon features stay). OpenMap: its own dungeon map. What an entrance click opens: the next row.",
        get = function() return (MasterOptionsDB and MasterOptionsDB.dungeonMap == "openmap") and "OpenMap" or "Dungeon Journal" end,
        set = function(v) MasterOptionsDB.dungeonMap = (v == "OpenMap") and "openmap" or nil end,
    },
    {
        -- OpenMap has its own "Clicking a dungeon entrance opens" (its map / Dungeon Journal's page:
        -- worldmap.entranceClick); MasterOptions_DungeonJournal_OpenMap adds Dungeon Journal's map of the dungeon.
        -- One choice for the three, written to OpenMap's option too. (No `since`: recommended for a new
        -- character only - an update keeps what your entrances open now.)
        kind = "choice", label = "Dungeon entrance click", rec = "Dungeon Journal map", reload = true,
        needs = { "OpenMap", "ForeverDungeonJournal", "MasterOptions_DungeonJournal_OpenMap" },
        choices = { "Dungeon Journal map", "Dungeon Journal page", "OpenMap's map" },
        tip = "What clicking a dungeon entrance on OpenMap's world map opens. Dungeon Journal map: Dungeon Journal's map of that dungeon on the world map (a list when several share the entrance; right-click or Esc back). Dungeon Journal page: its journal page (OpenMap's own option). OpenMap's map: OpenMap's map of the dungeon.",
        get = function()
            local v = MasterOptionsDB and MasterOptionsDB.entranceClick
            if v == nil then v = (MasterOptionsDB and MasterOptionsDB.dungeonMap == "openmap") and "openmap" or "djmap" end
            return (v == "djpage" and "Dungeon Journal page") or (v == "openmap" and "OpenMap's map") or "Dungeon Journal map"
        end,
        set = function(v)
            MasterOptionsDB.entranceClick = (v == "Dungeon Journal page" and "djpage") or (v == "OpenMap's map" and "openmap") or "djmap"
        end,
    },
    {
        kind = "choice", label = "Town NPC icons", rec = "Questie", since = 21, scope = "character",
        needs = "Questie", choices = { "Questie", "Game's tracking" },
        tip = "Auctioneer, banker, battlemaster, innkeeper, mailbox, repair, stable master and flight master icons: the game's minimap tracking menu and Questie's townsfolk menu both draw them, so a kind ticked in both shows twice. Questie: on the world map and the minimap (pick the kinds in Questie's menu). Game's tracking: on the minimap only. Switching moves the kinds you have on to the one you pick; trainers and the rest stay as they are. OpenMap can draw some of the same kinds on the world map too (its Townsfolk menu): Questie turns those off (else they show twice there); with Game's tracking they can stay - the game's are on the minimap only.",
        get = TownGet, set = TownSet,
    },

    { header = "Nameplates" },
    {
        kind = "choice", label = "Quest icons on nameplates", rec = "BetterBlizzPlates", since = 13, reload = true,
        choices = { "BetterBlizzPlates", "Questie", "Off" },
        tip = "Questie and BetterBlizzPlates can both mark the mobs your quests need with an icon on their nameplate, so a mob gets two. BetterBlizzPlates reads the game's own quest data (Forever's own quests too, and in dungeons); Questie uses its quest database (and has no nameplate icons in Forever's dungeons).",
        get = function()
            local q = Loaded("Questie") and type(_G.Questie) == "table" and _G.Questie.db and _G.Questie.db.profile
            local b = Loaded("BetterBlizzPlates") and type(_G.BetterBlizzPlatesDB) == "table" and _G.BetterBlizzPlatesDB
            local qOn = q and q.nameplateEnabled ~= false
            local bOn = b and b.questIndicator == true
            if qOn and bOn then return "Both (conflict)" end
            return bOn and "BetterBlizzPlates" or qOn and "Questie" or "Off"
        end,
        set = function(v)
            local q = Loaded("Questie") and type(_G.Questie) == "table" and _G.Questie.db and _G.Questie.db.profile
            if q then q.nameplateEnabled = (v == "Questie") end
            local b = Loaded("BetterBlizzPlates") and type(_G.BetterBlizzPlatesDB) == "table" and _G.BetterBlizzPlatesDB
            if b then b.questIndicator = (v == "BetterBlizzPlates") end
        end,
    },

    {
        kind = "choice", label = "Quest icon on your target's frame", rec = "BetterBlizzFrames", since = 15, reload = true,
        choices = { "BetterBlizzFrames", "Questie", "Off" },
        tip = "BetterBlizzFrames and Questie can both put a quest icon on the target (and focus) frame of a mob your quests need, so it gets two.",
        get = function()
            local q = Loaded("Questie") and type(_G.Questie) == "table" and _G.Questie.db and _G.Questie.db.profile
            local b = Loaded("BetterBlizzFrames") and type(_G.BetterBlizzFramesDB) == "table" and _G.BetterBlizzFramesDB
            local qOn = q and q.nameplateEnabled ~= false and q.nameplateTargetFrameEnabled ~= false
            local bOn = b and b.questIndicator == true
            if qOn and bOn then return "Both (conflict)" end
            return bOn and "BetterBlizzFrames" or qOn and "Questie" or "Off"
        end,
        set = function(v)
            local q = Loaded("Questie") and type(_G.Questie) == "table" and _G.Questie.db and _G.Questie.db.profile
            if q then q.nameplateTargetFrameEnabled = (v == "Questie") end
            local b = Loaded("BetterBlizzFrames") and type(_G.BetterBlizzFramesDB) == "table" and _G.BetterBlizzFramesDB
            if b then b.questIndicator = (v == "BetterBlizzFrames") end
        end,
    },

    { header = "Tooltips" },
    Multi("Auction price", "Auctionator", 4,
        "Auctionator, Mastercraft and CheapUpgrades can each add an auction house price line.", {
        { "Auctionator",
          function() return AUC("auction_tooltips") end,
          function(on)
              AUC("auction_tooltips", on)
              -- Mastercraft can hide Auctionator's lines at every login: don't let it undo this choice
              local m = MC(); if on and m then m.hideAuctionatorTips = false end
          end },
        { "Mastercraft",
          function() return mcTip("tipPrice") end,
          function(on) mcSetTip("tipPrice", on) end },
        { "CheapUpgrades",
          function() local c = CU(); return c and c.tooltip ~= false and c.tooltipPrice ~= false end,
          -- (its master switch "Item tooltips" too: off, the line would never show)
          function(on) local c = CU(); if c then c.tooltipPrice = on; if on then c.tooltip = true end end end },
    }, "Off"),
    Multi("Vendor sell price", "Game's own line", 4,
        "The game already shows \"Sell Price\" on every item. Auctionator and Mastercraft can add a second vendor line.", {
        { "Auctionator",
          function() return AUC("vendor_tooltips") end,
          function(on)
              AUC("vendor_tooltips", on)
              local m = MC(); if on and m then m.hideAuctionatorTips = false end
          end },
        { "Mastercraft",
          function() return mcTip("tipVendor") end,
          function(on) mcSetTip("tipVendor", on) end },
    }, "Game's own line"),
    Multi("Upgrade % per spec", "Pawn", 4,
        "Pawn, GearMatic and CheapUpgrades can each list an upgrade size for every spec. With \"Stat weights\" below set to Pawn they all value items with Pawn's scales; Pawn's own line is the most compact and matches Baganator's bag arrows.", {
        { "Pawn",
          function() local pw = PAWN(); return pw and pw.ShowUpgradesOnTooltips and true or false end,
          function(on) local pw = PAWN(); if pw then pw.ShowUpgradesOnTooltips = on end end },
        { "GearMatic",
          -- (its item tooltip line: autoDetectTooltip, shown while autoDetect is on too - ItemTooltipHook.lua.
          -- showInTooltip, used here before 2.3.2, is only its summary on a character's mouseover tooltip)
          function() local g = GM(); return g ~= nil and g.autoDetect ~= false and g.autoDetectTooltip ~= false end,
          function(on) local g = GM(); if g then g.autoDetectTooltip = on; if on then g.autoDetect = true end end end },
        { "CheapUpgrades",
          function() local c = CU(); return c and c.tooltip ~= false and c.tooltipUpgrades ~= false end,
          function(on) local c = CU(); if c then c.tooltipUpgrades = on; if on then c.tooltip = true end end end },
    }, "Off"),
    {
        kind = "choice", label = "Counts on your characters", since = 3, rec = "Syndicator",
        tip = "Syndicator (used by Baganator) and Mastercraft both list how many each of your characters has.",
        choices = { "Syndicator", "Mastercraft", "Off" },
        get = function()
            local sy = SYN() and SYN().show_inventory_tooltips ~= false
            local m = mcTip("tipOwnersList")
            if sy and m then return "Both (conflict)" end
            return sy and "Syndicator" or m and "Mastercraft" or "Off"
        end,
        set = function(v)
            local sy = SYN(); if sy then sy.show_inventory_tooltips = (v == "Syndicator") end
            mcSetTip("tipOwnersList", v == "Mastercraft")
        end,
    },

    { header = "Stat weights" },
    {
        -- (since 16: applied again - before, it switched with /pff, which left a stock scale with no spec,
        -- "Rogue: Off Hand", shown next to Pawn Forever's)
        kind = "choice", label = "Pawn scales", rec = "Pawn Forever", since = 16, scope = "character",
        needs = { "Pawn", "Pawn_Forever" }, choices = { "Pawn Forever", "Pawn stock" },
        tip = "Which Pawn scales this character shows: Pawn Forever's (weights for WoW Forever, leveling and level 60) or Pawn's stock Classic ones. Pawn keeps this per character. GearMatic, CheapUpgrades and the quest reward pick follow whatever Pawn shows.",
        get = function()
            local pw = PAWN(); if not (pw and type(pw.Scales) == "table") then return "Pawn Forever" end
            local _, _, classID = UnitClass("player")
            local forever, stock = false, false
            for _, s in pairs(pw.Scales) do
                if type(s) == "table" and s.ClassID == classID and PawnShows(s) then
                    if s.Provider == "PawnForever" then forever = true elseif s.Provider == "Classic" then stock = true end
                end
            end
            if forever and stock then return "Both (conflict)" end
            return stock and "Pawn stock" or "Pawn Forever"
        end,
        set = function(v) SetPawnScales(v ~= "Pawn stock"); pcall(FollowSpec) end,
    },
    {
        kind = "choice", label = "Spec for Pawn and CheapUpgrades", rec = "Follow GearMatic", since = 26,
        needs = "GearMatic", choices = { "Follow GearMatic", "Your own choice" },
        tip = "GearMatic works out your spec from your talents (and its own Cat / Bear choice for Feral). Follow GearMatic: Pawn shows only that spec's scale (of the set you use - Pawn Forever's or stock; scales for no particular spec stay as they are), and CheapUpgrades' spec and ticked specs are that spec - so upgrade arrows, tooltips, quest rewards and the auction house all judge by one spec, and follow a talent change. Your own choice: Pawn shows the scales you tick (upgrades for any of them, off-spec too), CheapUpgrades the specs you pick. Either way, selling and deleting (vendor selling, GearMatic's sell guard, DeleteCheapestItem) keep Pawn's upgrades and best items for every spec of the set you use - following, the other specs are counted for that check only.",
        get = function() return FollowSpecOn() and "Follow GearMatic" or "Your own choice" end,
        set = function(v)
            -- (not `(v ~= ...) and false or nil`: that is always nil)
            if v == "Follow GearMatic" then MasterOptionsDB.specFollow = nil else MasterOptionsDB.specFollow = false end
            pcall(FollowSpec)
        end,
    },
    {
        kind = "choice", label = "GearMatic stat weights", rec = "Pawn", since = 5, scope = "character",
        needs = { "GearMatic", "Pawn" }, off = "GearMatic's own",
        tip = "Pawn: GearMatic scores, marks and auto-equips with the Pawn scale this character shows in Pawn (Pawn Forever's, once it has swapped them in), and Pawn itself works out each item's value, so GearMatic agrees with Pawn. Show or hide scales in Pawn to change it. GearMatic's own: its Icy Veins guide weights.",
        choices = { "Pawn", "GearMatic's own" },
        get = function()
            local g = GM()
            if not (g and g.usePawnWeights) or GMBuiltinChosen() then return "GearMatic's own" end
            return "Pawn"
        end,
        set = function(v)
            local g = GM(); if not g then return end
            local si = _G.GearMatic and _G.GearMatic.ScaleImport
            local pawn = (v == "Pawn")
            g.usePawnWeights = pawn
            g.pawnAutoImport = pawn -- copies of Pawn's scales are refreshed at every login
            SyncPawnHidden()
            if pawn then
                -- back off GearMatic's built-in guide and any pinned scale, so Pawn's is picked
                if si and si.UsePawnScale then pcall(si.UsePawnScale) end
            elseif si and si.UseBuiltinScale then
                pcall(si.UseBuiltinScale)
            end
            RefreshGearMatic()
        end,
    },
    {
        kind = "toggle", label = "CheapUpgrades: use Pawn's weights", rec = true, since = 5,
        needs = { "CheapUpgrades", "Pawn" },
        tip = "CheapUpgrades asks Pawn what each item is worth, with the Pawn scale shown for your spec. A weights profile of your own in CheapUpgrades still comes first, and a Pawn scale picked for a spec in CheapUpgrades' Stat weights is used instead of the one Pawn shows.",
        get = function() local c = CU(); return c ~= nil and c.usePawn == true end,
        set = function(v)
            local c = CU(); if not c then return end
            c.usePawn = v
            local cu = _G.CheapUpgrades
            if type(cu) == "table" then
                if v and cu.Engine and cu.Engine.NotePawnLinks then pcall(cu.Engine.NotePawnLinks) end
                if cu.Refresh and cu.SafeCall then pcall(cu.SafeCall, cu, cu.Refresh, cu) end
            end
        end,
    },

    { header = "Upgrade markers" },
    {
        kind = "toggle", label = "CheapUpgrades: \"+23%\" badges in bags", needs = "CheapUpgrades", rec = true,
        get = function() local c = CU(); return c and c.bagBadges ~= false end,
        set = function(v)
            local c = CU(); if c then c.bagBadges = v end
            local cu = _G.CheapUpgrades
            if cu and cu.Bags and cu.Bags.Refresh then pcall(cu.Bags.Refresh, cu.Bags) end
            if _G.Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
                Baganator.API.RequestItemButtonsRefresh()
            end
        end,
    },
    {
        kind = "toggle", label = "GearMatic: auto-equip upgrades", needs = "GearMatic", rec = false,
        tip = "GearMatic equips gear it scores as better on its own. Turn off if you'd rather decide with Pawn or CheapUpgrades.",
        get = function() return gmOn("autoEquipUpgrades") and GM() ~= nil end,
        set = function(v) local g = GM(); if g then g.autoEquipUpgrades = v end end,
    },

    { header = "Bags (Baganator)" },
    {
        -- (since 17: "Match stat weights" added, and recommended)
        kind = "choice", label = "Upgrade arrow in bags", rec = MATCH_ARROW, since = 17, reload = true,
        needs = "Baganator", choices = { MATCH_ARROW, "Pawn", "GearMatic", "Off" },
        tip = "Pawn's arrow and GearMatic's chevron both sit in the top-left corner of Baganator's bag slots. Match stat weights: the arrow of whoever judges upgrades under Stat weights - Pawn's while GearMatic uses Pawn's weights, GearMatic's chevron (which also marks upgrades for your alts) when it uses its own. Follows when you change that. Also sets Baganator's \"Upgrade\" plugin (its Upgrades category and search).",
        get = function()
            local p = BAG(); if not p then return "Off" end
            if IconsMatch().arrow then return MATCH_ARROW end
            return ArrowState(p)
        end,
        set = function(v)
            local p = BAG(); if not p then return end
            MasterOptionsDB.iconsMatch = MasterOptionsDB.iconsMatch or {}
            MasterOptionsDB.iconsMatch.arrow = (v == MATCH_ARROW) or nil
            ApplyUpgradeArrow(p, v == MATCH_ARROW and MatchedArrow() or v)
        end,
        scope = "Baganator profile",
    },
    {
        kind = "choice", label = "Junk coin in bags", rec = MATCH_JUNK, since = 17, reload = true,
        needs = "Baganator", choices = { MATCH_JUNK, "GearMatic", "Mastercraft", "Greys only" }, off = "Greys only",
        tip = "Which items Baganator marks with its junk coin (and sorts to the end). Match junk seller: exactly what the addon picked under Vendor > Sell junk automatically will sell - follows when you change that. GearMatic: greys, your GearMatic junk and marked items, outgrown gear and low-value items when turned on in GearMatic (needs MasterOptions_GearMatic_Baganator). Mastercraft: greys (with MasterOptions_Mastercraft_VendorSell also what Mastercraft says to VENDOR). With the VendorSell patch, VENDOR items get the coin under GearMatic too. Greys only: Baganator's own rule.",
        get = function()
            local p = BAG(); if not p then return "Greys only" end
            if IconsMatch().junk then return MATCH_JUNK end
            return JunkState(p)
        end,
        set = function(v)
            local p = BAG(); if not p then return end
            MasterOptionsDB.iconsMatch = MasterOptionsDB.iconsMatch or {}
            MasterOptionsDB.iconsMatch.junk = (v == MATCH_JUNK) or nil
            ApplyJunk(p, v == MATCH_JUNK and MatchedJunk() or v)
        end,
        scope = "Baganator profile",
    },
    {
        -- (GearMatic's skull is Baganator's corner widget "gearmatic_bis", top right; Baganator auto-inserts a
        -- widget once only, so taking it out sticks)
        kind = "toggle", label = "Best-in-slot skull in bags", reload = true,
        needs = { "Baganator", "GearMatic" },
        tip = "GearMatic's skull in the top-right corner of Baganator's bag slots, on items that are best in slot for you. GearMatic has no switch for it in the bags (only for the character sheet).",
        get = function() local p = BAG(); return p ~= nil and CornerHas(p, "gearmatic_bis") end,
        set = function(v)
            local p = BAG(); if not p then return end
            if v then CornerAdd(p, "gearmatic_bis", CORNERS[2]) else CornerRemove(p, "gearmatic_bis") end
        end,
        scope = "Baganator profile",
    },
    {
        kind = "choice", label = "GearMatic vendor badge", needs = "GearMatic",
        choices = { "Gold $", "Gold coin", "Off" }, off = "Off",
        tip = "GearMatic's badge in the bottom-left corner of gear you don't need, when a vendor pays the most for it. Gold coin looks like Baganator's junk coin, which means \"will be sold\" - Gold $ keeps the two apart.",
        get = function()
            local s = GM(); if not s then return "Off" end
            if s.bestGoldShowVendor == false then return "Off" end
            return s.vendorMarkerStyle == "coin" and "Gold coin" or "Gold $"
        end,
        set = function(v)
            local s = GM(); if not s then return end
            s.bestGoldShowVendor = v ~= "Off"
            if v ~= "Off" then s.vendorMarkerStyle = (v == "Gold coin") and "coin" or "dollar" end
            GMRefreshBagIcons()
        end,
    },
    {
        kind = "choice", label = "Bag icon size", needs = "Baganator",
        choices = { "Large", "Medium", "Small" },
        tip = "One size for every icon on Baganator's bag slots, whichever addon adds it: Pawn's arrow, the junk coin, GearMatic's arrow, skull and badge, and any other addon's corner icons. Text (item level, counts, CheapUpgrades' \"+23%\") keeps Baganator's font size. Large: each addon's own size. Also sets GearMatic's Bag icon size.",
        get = function() return BagIconSize() end,
        set = function(v)
            MasterOptionsDB.bagIconSize = ICON_SCALE[v] and v or "Large"
            ApplyBagIconSize()
        end,
    },

    { header = "Quests" },
    {
        kind = "choice", label = "Pre-select best quest reward", rec = "Pawn", since = 7,
        needs = "MasterOptions_DialogKey_Pawn", choices = { "Pawn", "GearMatic", "Off" },
        tip = "On the quest reward screen the best choice is selected for you, so DialogKey's key (or Complete Quest) takes it. Pawn: the biggest upgrade by the Pawn scales you show. GearMatic: the choice GearMatic marks as an upgrade for this character. With no upgrade, the one worth most at a vendor. Needs the MasterOptions_DialogKey_Pawn patch.",
        get = function()
            local d = _G.MasterOptions_DialogKeyPawnDB
            local m = type(d) == "table" and d.mode or "pawn"
            return (m == "gearmatic" and "GearMatic") or (m == "off" and "Off") or "Pawn"
        end,
        set = function(v)
            MasterOptions_DialogKeyPawnDB = MasterOptions_DialogKeyPawnDB or {}
            MasterOptions_DialogKeyPawnDB.mode = (v == "GearMatic" and "gearmatic") or (v == "Off" and "off") or "pawn"
        end,
    },
    {
        -- Pawn (PawnUI.lua: its arrow, bottom-left of the reward icon) and GearMatic (QuestRewardHook.lua: its
        -- chevron top-right, or a gold $ on the best vendor choice) both mark rewards - on the same buttons, and with
        -- GearMatic's own weights not always the same one. Only the markers: GearMatic's autoDetect (bag arrows,
        -- tooltips) and the pre-select above stay as they are.
        kind = "choice", label = "Quest reward marker", rec = "Pawn", since = 23,
        needs = { "Pawn", "GearMatic" }, choices = { "Pawn", "GearMatic", "Both", "Off" },
        tip = "Pawn and GearMatic both mark the best quest reward, so the same reward button can get two markers (and, with GearMatic's own weights, on different rewards). Pick one - the same as Pre-select best quest reward above, so the selected reward and its marker agree. Pawn's setting is its \"quest upgrade advisor\" (also its world quest upgrade marks); GearMatic's only its quest reward marks.",
        get = function()
            local pw, g = PAWN(), GM()
            local p = pw ~= nil and pw.ShowQuestUpgradeAdvisor ~= false
            local m = g ~= nil and g.autoDetectQuestReward ~= false
            return (p and m and "Both") or (p and "Pawn") or (m and "GearMatic") or "Off"
        end,
        set = function(v)
            local pw, g = PAWN(), GM()
            if pw then pw.ShowQuestUpgradeAdvisor = (v == "Pawn" or v == "Both") end
            if g then g.autoDetectQuestReward = (v == "GearMatic" or v == "Both") end
        end,
    },

    { header = "Fishing" },
    {
        -- Sparkles_Forever: its bobber effect off also turns the bobber's nameplate off (SoftTargetNameplateInteract 0,
        -- SoftTarget.lua SetNameplateGate) - and Mastercraft's mark sits on that nameplate. So "Mastercraft only"
        -- isn't offered: with Sparkles installed it wouldn't show (Problems says so if it's set that way).
        kind = "choice", label = "Fishing bobber mark", rec = "Sparkles", since = 23,
        needs = { "Mastercraft", "Sparkles_Forever" },
        choices = { "Sparkles", "Both", "Off" },
        tip = "Sparkles and Mastercraft both mark your fishing bobber. Sparkles: its effect only. Both: its effect and Mastercraft's mark above it. Mastercraft's mark alone isn't offered while Sparkles is installed: turning Sparkles' bobber effect off also turns off the bobber's nameplate, which Mastercraft's mark sits on.",
        get = function()
            local s, m = SPK(), MC()
            local sp = s and s.sparkleBobber ~= false
            local mc = m and m.fishMarker ~= false
            if sp and mc then return "Both" end
            return sp and "Sparkles" or "Off"
        end,
        set = function(v)
            local s, m = SPK(), MC()
            if s then s.sparkleBobber = (v ~= "Off") end
            if m then m.fishMarker = (v == "Both") end
        end,
    },

    { header = "Look" },
    {
        kind = "choice", label = "UI style", rec = "WoW", reload = true, scope = "character",
        needs = "MasterOptions", choices = { "WoW", "Dark" },
        tip = UIStyleTip, get = UIStyleGet, set = UIStyleSet,
    },
    {
        -- BetterBlizzFrames' minimap options move, re-skin or hide the same Minimap / MinimapCluster pieces
        -- OpenMap_MiniMap does (its classic minimap is applied as it loads: forever\modules\classicMinimap.lua)
        -- (shown, and recommended, only while both are loaded - when they fight: picking BetterBlizzFrames disables
        -- OpenMap_MiniMap, and after the reload this row is gone; turn it on again in the AddOns list)
        kind = "choice", label = "Minimap", rec = "OpenMap_MiniMap", since = 23, reload = true,
        needs = { "BetterBlizzFrames", "OpenMap_MiniMap" }, choices = { "OpenMap_MiniMap", "BetterBlizzFrames classic" },
        tip = "OpenMap_MiniMap and BetterBlizzFrames' minimap options (Classic minimap, Minimap tweaks, Hide minimap buttons, Hide minimap) work on the same frames and fight. OpenMap_MiniMap: those BetterBlizzFrames options off. BetterBlizzFrames classic: its classic minimap on and the OpenMap_MiniMap addon disabled (turn it on again in the AddOns list). Takes a reload.",
        get = function()
            local b = type(_G.BetterBlizzFramesDB) == "table" and _G.BetterBlizzFramesDB or {}
            local AO = C_AddOns or {}
            local state = AO.GetAddOnEnableState and AO.GetAddOnEnableState("OpenMap_MiniMap", UnitName("player"))
            if state == 0 and b.classicMinimap == true then return "BetterBlizzFrames classic" end -- (after the reload)
            local bbfOn = b.classicMinimap == true or b.foreverMinimapTweaks == true or b.hideMinimapButtons == true or b.hideMinimap == true
            return bbfOn and "Both (conflict)" or "OpenMap_MiniMap"
        end,
        set = function(v)
            local b = _G.BetterBlizzFramesDB
            local AO = C_AddOns or {}
            local enable, disable = AO.EnableAddOn or EnableAddOn, AO.DisableAddOn or DisableAddOn
            if v == "BetterBlizzFrames classic" then
                if type(b) == "table" then b.classicMinimap = true; b.SkipMinimapForeverTint = nil end
                if disable then pcall(disable, "OpenMap_MiniMap") end
            else
                if type(b) == "table" then
                    b.classicMinimap, b.foreverMinimapTweaks, b.hideMinimapButtons, b.hideMinimap = false, false, false, false
                    -- (BBF.TintForeverMinimap, at every login whatever the options: the minimap buttons' rings
                    -- tinted bronze - on OpenMap_MiniMap's map, its own look instead. A BetterBlizzFrames key with no
                    -- checkbox of its own.)
                    b.SkipMinimapForeverTint = true
                end
                if enable then pcall(enable, "OpenMap_MiniMap") end
            end
        end,
    },
    {
        kind = "choice", label = "Minimap border", rec = "Action bar", since = 19,
        needs = "MasterOptions_OpenMapMiniMap_Border", choices = { "Action bar", "OpenMap's own" }, off = "OpenMap's own",
        tip = "Action bar: OpenMap's square minimap and its zone bar framed with the same border as your action bar buttons. OpenMap's own: its thin dark border or gold frame (UI style picks which). Square minimap only. Needs the MasterOptions_OpenMapMiniMap_Border patch.",
        get = function()
            local d = _G.MasterOptions_MinimapBorderDB
            return (type(d) == "table" and d.on == false) and "OpenMap's own" or "Action bar"
        end,
        set = function(v)
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            MasterOptions_MinimapBorderDB.on = (v == "Action bar")
            local b = _G.MasterOptions_MinimapBorder
            if b and b.Apply then pcall(b.Apply) end
        end,
    },
    {
        kind = "choice", label = "Minimap border thickness", rec = "Thick", since = 20,
        needs = "MasterOptions_OpenMapMiniMap_Border", choices = { "As on buttons", "Thick", "Thicker" },
        tip = "How thick the action-bar border round the minimap is: as on the action buttons themselves, or thicker (it's a much bigger frame). Changes at once.",
        get = function()
            local d = _G.MasterOptions_MinimapBorderDB
            local s = type(d) == "table" and d.scale or 1.6
            return (s <= 1.1 and "As on buttons") or (s >= 2 and "Thicker") or "Thick"
        end,
        set = function(v)
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            MasterOptions_MinimapBorderDB.scale = (v == "As on buttons" and 1) or (v == "Thicker" and 2.2) or 1.6
            local b = _G.MasterOptions_MinimapBorder
            if b and b.Apply then pcall(b.Apply) end
        end,
    },
    {
        kind = "choice", label = "Minimap coordinates", rec = "Top center", since = 22,
        needs = "MasterOptions_OpenMapMiniMap_Border",
        choices = { "Top left", "Top center", "Top right", "Bottom left", "Bottom center", "Bottom right", "Game's place" },
        tip = "The coordinates in a small tab sticking out of the minimap's frame, like the zone bar (same background and border): on its top or bottom edge, at the left, centre or right. Shown while the game's coordinates setting is on (Edit Mode's minimap \"show coordinates\", or OpenMap's \"Coordinates under the map\"). Game's place: the game's own line on the map's bottom edge, where OpenMap's bottom row of addon buttons covers it. Changes at once.",
        get = function()
            local d = _G.MasterOptions_MinimapBorderDB
            local m = type(d) == "table" and d.coords or nil
            if m == "game" then return "Game's place" end
            if m == nil or m == "top" then return "Top center" end
            local side, align = m:match("^(%a+)%-(%a+)$")
            if not side then return "Top center" end
            return side:sub(1, 1):upper() .. side:sub(2) .. " " .. align
        end,
        set = function(v)
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            MasterOptions_MinimapBorderDB.coords = (v == "Game's place") and "game" or v:lower():gsub(" ", "-")
            local b = _G.MasterOptions_MinimapBorder
            if b and b.PlaceCoords then pcall(b.PlaceCoords) end
        end,
    },

    { header = "Modules (on / off takes effect after a reload)" },
}
-- MasterOptions' own compatibility patches (each is a separate addon named MasterOptions_<Addon>_<Addon>)
local PATCH_SINCE = { MasterOptions_OpenMapTweaks_Mastercraft = 2, MasterOptions_GearMatic_Baganator = 6,
                      MasterOptions_GearMatic_Forever = 7, MasterOptions_DialogKey_Pawn = 7,
                      MasterOptions_Mastercraft_Auctionator = 9,
                      MasterOptions_DeleteCheapestItem_Protect = 10, MasterOptions_Mastercraft_Keep = 10,
                      MasterOptions_DungeonJournal_OpenMap = 11, MasterOptions_Mastercraft_FishingView = 12,
                      MasterOptions_Mastercraft_Chattynator = 14, MasterOptions_Mastercraft_VendorSell = 17,
                      MasterOptions_Mastercraft_BankMats = 18,
                      MasterOptions_OpenMapMiniMap_Border = 19,
                      MasterOptions_ShortestPathForever_OpenMapMiniMap = 23,
                      MasterOptions_NeverSell = 24, MasterOptions_GearMatic_SellGuard = 25 }
local PATCH_TIP = {
    MasterOptions_Mastercraft_FishingView = "While Mastercraft's fishing view hides the interface: Baganator's bags, DeleteCheapestItem's window, confirmation pop-ups and loot rolls stay visible, and Chattynator's chat follows Mastercraft's chat setting. Replaces MasterOptions_Mastercraft_Baganator.",
    MasterOptions_CheapUpgrades_Baganator = "CheapUpgrades' \"+23%\" badges on Baganator's bag slots.",
    MasterOptions_OpenMapTweaks_Mastercraft = "Mastercraft's node rule also filters OpenMap_Tweaks' gathering pins.",
    MasterOptions_GearMatic_Baganator = "Baganator junk coins from GearMatic's vendor rules, and GearMatic loadouts shown as equipment sets on bag slots (GearMatic has loadouts on Vanilla / TBC clients only - not on Forever).",
    MasterOptions_GearMatic_Forever = "Keeps GearMatic's data apart for characters that share a first name (Forever reports no realm, so GearMatic saved them as one). Turning it off later makes GearMatic go back to the shared record.",
    MasterOptions_DialogKey_Pawn = "Pre-selects the best quest reward so DialogKey's key takes it (pick whose choice under Quests).",
    MasterOptions_Mastercraft_Auctionator = "Mastercraft's Scan prices button on Auctionator's page (next to Full Scan) instead of the tab row or the bottom corner, where it covered Buyout.",
    MasterOptions_DeleteCheapestItem_Protect = "DeleteCheapestItem never offers upgrades (Pawn, GearMatic), best-in-slot items, set or loadout pieces, profession tools or materials Mastercraft says you need. Kept as entries in its ignore list; only those it added are removed again.",
    MasterOptions_Mastercraft_Keep = "Materials on your Mastercraft item tracker, or that Mastercraft's tooltip says a guide still needs, go on GearMatic's never-sell list (and are protected from DeleteCheapestItem with the Protect patch).",
    MasterOptions_Mastercraft_Chattynator = "Mastercraft's own /played request (it records your play time) stays out of Chattynator's chat, as it already does in the game's chat. Your own /played still shows.",
    MasterOptions_Mastercraft_VendorSell = "At a vendor, what Mastercraft's advice says to VENDOR is sold by your junk seller (GearMatic or Mastercraft). Pick what under Vendor and bank.",
    MasterOptions_Mastercraft_BankMats = "When you open the bank, the materials Mastercraft keeps for your guides go into it; VENDOR and AUCTION items stay in your bags. Pick what under Vendor and bank.",
    MasterOptions_OpenMapMiniMap_Border = "OpenMap's square minimap framed with the action bar buttons' border (Look > Minimap border).",
    MasterOptions_GearMatic_SellGuard = "GearMatic's gear and low-value selling keeps what Master Options protects: the never-sell list, materials your Mastercraft guides need, and gear Pawn calls an upgrade or already your best for a spec (through GearMatic's own sell guard).",
    MasterOptions_NeverSell = "One never-sell list, kept the same in GearMatic (never auto-sold), Mastercraft (no VENDOR / AUCTION advice) and DeleteCheapestItem (never offered for deletion): add or remove an item in any of them, or with /mo never <item>, and it changes in all. /mo never lists it.",
    MasterOptions_ShortestPathForever_OpenMapMiniMap = "Shortest Path's journey goal on the minimap stays visible over OpenMap's painted minimap (it faded with the game's terrain, and was gone at far zoom).",
    MasterOptions_DungeonJournal_OpenMap = "Dungeon Journal's Show on Map also puts a blue OpenMap pin there (named, followed like a pin you drop), gone again when Dungeon Journal clears its mark. And the map inside dungeons (Maps > Map inside dungeons). Replaces OpenMap_NoDungeonMap.",
}
-- the modules (Modules\*.lua, once separate addons): on / off for the next load, and what each is doing now
local MODULE_STATE_TEXT = { on = "|cff66dd66running|r", off = "|cff9d9d9doff|r", error = "|cffff5555stopped by an error (Problems)|r",
    ["old folder"] = "|cffffd200standing aside: the old separate addon of the same name is still installed (Problems)|r" }
local MODULE_ORDER = { "Mastercraft_FishingView", "CheapUpgrades_Baganator", "OpenMapTweaks_Mastercraft", "GearMatic_Baganator",
    "GearMatic_Forever", "DialogKey_Pawn", "Mastercraft_Auctionator", "DeleteCheapestItem_Protect", "Mastercraft_Keep",
    "DungeonJournal_OpenMap", "Mastercraft_Chattynator", "Mastercraft_VendorSell", "Mastercraft_BankMats", "OpenMapMiniMap_Border",
    "ShortestPathForever_OpenMapMiniMap", "NeverSell", "GearMatic_SellGuard" }
for _, short in ipairs(MODULE_ORDER) do
    local name = "MasterOptions_" .. short
    local function M() return _G.MasterOptions_Modules end
    OPTIONS[#OPTIONS + 1] = {
        kind = "toggle", label = short:gsub("_", " / "), reload = true, rec = true, since = PATCH_SINCE[name] or 1,
        tip = function()
            local m = M()
            local state = m and m.State(short)
            local now = state and (MODULE_STATE_TEXT[state] or ("|cff9d9d9dnot running: " .. state .. "|r")) or "?"
            local needs = m and table.concat(m.Needs(short), ", ") or ""
            return (PATCH_TIP[name] or "") .. "\n\nWorks with: " .. needs .. "\nNow: " .. now
        end,
        get = function() local m = M(); return m == nil or m.IsEnabled(short) end,
        set = function(v) local m = M(); if m then m.SetEnabled(short, v) end end,
    }
end

---------------------------------------------------------------------------
-- Health check: addons that can't load, leftover copies of our patches, and settings that point at
-- addons which aren't there. Shown at the top of /mo (with a fix where there is one) and once at login.
---------------------------------------------------------------------------
local AO = C_AddOns or {}
local NumAddOns   = AO.GetNumAddOns or GetNumAddOns
local AddOnInfo   = AO.GetAddOnInfo or GetAddOnInfo
local AddOnDeps   = AO.GetAddOnDependencies or GetAddOnDependencies
local IsLOD       = AO.IsAddOnLoadOnDemand or IsAddOnLoadOnDemand
local function Exists(name)
    if AO.DoesAddOnExist then return AO.DoesAddOnExist(name) end
    local ok, _, _, _, _, reason = pcall(AddOnInfo, name)
    return ok and reason ~= "MISSING"
end
local function AddonEnabled(name)
    local who = UnitName("player")
    local state = AO.GetAddOnEnableState and AO.GetAddOnEnableState(name, who)
    if state == nil and GetAddOnEnableState then state = GetAddOnEnableState(who, name) end
    return (state or 0) > 0
end
local function SetAddonEnabled(name, on)
    local fn = on and (AO.EnableAddOn or EnableAddOn) or (AO.DisableAddOn or DisableAddOn)
    if fn then fn(name) end
end

-- our patches before they got the MasterOptions_ prefix: an old copy left installed loads twice
local RENAMED = { "Mastercraft_Baganator", "CheapUpgrades_Baganator", "OpenMapTweaks_Mastercraft", "GearMatic_Baganator" }

-- Baganator plugin ids -> the addon(s) that register them
local BAG_JUNK_OWNER = {
    gearmatic = "MasterOptions_GearMatic_Baganator", mastercraft = "MasterOptions_Mastercraft_VendorSell", enhanceqol_vendor = { "EnhanceQoL", "EnhanceQoLVendor" },
    selljunk = "SellJunk", scrap = "Scrap", vendor = "Vendor", dejunk = "Dejunk", peddler = "Peddler",
}
local BAG_UPGRADE_OWNER = { pawn = "Pawn", gearmatic_upgrade = "GearMatic", simple_item_levels = "SimpleItemLevel" }
local function OwnerLoaded(o)
    if type(o) == "table" then
        for _, n in ipairs(o) do if Loaded(n) then return true end end
        return false
    end
    return Loaded(o)
end

local ShowErrorText -- (the copy window, made with the window below)

local function Problems()
    local ignored = (MasterOptionsDB and MasterOptionsDB.ignoredProblems) or {}
    local out = {}
    local function add(id, text, fixLabel, fix)
        if not ignored[id] then out[#out + 1] = { id = id, text = text, fixLabel = fixLabel, fix = fix } end
    end

    -- 0. errors in Master Options or our patches (ErrorLog.lua): Copy for a bug report, Clear when done
    local log = _G.MasterOptions_ErrorLog
    local errs = log and log.List() or {}
    if #errs > 0 then
        local lines = {}
        for i = 1, math.min(3, #errs) do
            local e = errs[i]
            local msg = (e.msg or "?"):gsub("^.-AddOns[/\\][^/\\]+[/\\]", ""):gsub("\n.*", "")
            if #msg > 110 then msg = msg:sub(1, 107) .. "..." end
            lines[#lines + 1] = ("|cffffd200%s|r%s: %s%s"):format(e.addon or "?", e.where and (" (" .. e.where .. ")") or "",
                msg, (e.count or 1) > 1 and ("  |cff9d9d9dx" .. e.count .. "|r") or "")
        end
        if #errs > 3 then lines[#lines + 1] = ("|cff9d9d9d+%d more|r"):format(#errs - 3) end
        out[#out + 1] = {
            id = "errors", fixLabel = "Copy", noReload = true, ignoreLabel = "Clear",
            text = ("%d error%s in Master Options' patches (Copy gives the full text for a bug report):\n%s"):format(
                #errs, #errs > 1 and "s" or "", table.concat(lines, "\n")),
            fix = function() if ShowErrorText then ShowErrorText() end end,
            onIgnore = function() log.Clear() end,
        }
    end

    -- 1. enabled addons that didn't load
    for i = 1, (NumAddOns and NumAddOns() or 0) do
        local name, _, _, _, reason = AddOnInfo(i)
        if name and not name:find("^Blizzard_") and AddonEnabled(name) and not Loaded(name)
            and not (IsLOD and IsLOD(i)) then
            local missing, off = {}, {}
            if AddOnDeps then
                for _, dep in ipairs({ AddOnDeps(i) }) do
                    if not Exists(dep) then missing[#missing + 1] = dep
                    elseif not AddonEnabled(dep) then off[#off + 1] = dep end
                end
            end
            local disable = function() SetAddonEnabled(name, false) end
            if #missing > 0 then
                add("missing:" .. name, ("%s needs %s, which isn't installed."):format(name, table.concat(missing, ", ")), "Disable", disable)
            elseif #off > 0 then
                add("depoff:" .. name, ("%s needs %s, which is disabled."):format(name, table.concat(off, ", ")), "Enable",
                    function() for _, d in ipairs(off) do SetAddonEnabled(d, true) end end)
            elseif reason == "INTERFACE_VERSION" then
                add("outdated:" .. name, ("%s is out of date for this game version and doesn't load."):format(name), "Disable", disable)
            elseif reason and reason ~= "DEMAND_LOADED" and reason ~= "DISABLED" then
                add("noload:" .. name, ("%s didn't load (%s)."):format(name, _G["ADDON_" .. reason] or reason), "Disable", disable)
            end
        end
    end

    -- 2. old copies of our patches
    for _, old in ipairs(RENAMED) do
        if Exists(old) then
            add("old:" .. old, ("Old copy %s is still installed (now built into Master Options). Delete its folder from Interface\\AddOns."):format(old),
                AddonEnabled(old) and "Disable" or nil, function() SetAddonEnabled(old, false) end)
        end
    end

    -- 2b. our patch addons from before they became modules of Master Options: while one is installed and
    -- enabled its module stands aside (else every hook ran twice)
    local mods = _G.MasterOptions_Modules
    for _, short in ipairs(mods and mods.Names() or {}) do
        local old = "MasterOptions_" .. short
        if Exists(old) then
            add("oldmodule:" .. old, ("%s is now built into Master Options. Disable the old addon (then delete its folder from Interface\\AddOns) so its module can take over after a reload."):format(old),
                AddonEnabled(old) and "Disable" or nil, function() SetAddonEnabled(old, false) end)
        end
    end

    -- 3. entries a protection patch added, left behind after the patch was turned off or removed
    local dci = _G.DCI_CharDB
    if Loaded("DeleteCheapestItem") and not Loaded("MasterOptions_DeleteCheapestItem_Protect")
        and type(dci) == "table" and type(dci.moProtected) == "table" and next(dci.moProtected) then
        add("leftover:dci", "DeleteCheapestItem still ignores items the Protect patch added (it's off now).", "Remove", function()
            local list = dci.IgnoredItems or {}
            for id in pairs(dci.moProtected) do
                for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
            end
            dci.moProtected = nil
        end)
    end
    local gdb = _G.GearMaticDB
    if Loaded("GearMatic") and not Loaded("MasterOptions_Mastercraft_Keep")
        and type(gdb) == "table" and type(gdb.moKeep) == "table" and next(gdb.moKeep) then
        add("leftover:gmkeep", "GearMatic's never-sell list still has materials the Mastercraft Keep patch added (it's off now).", "Remove", function()
            for id in pairs(gdb.moKeep) do if gdb.sellIgnore then gdb.sellIgnore[id] = nil end end
            gdb.moKeep = nil
        end)
    end
    if Loaded("GearMatic") and not Loaded("MasterOptions_Mastercraft_VendorSell")
        and type(gdb) == "table" and type(gdb.moSell) == "table" and next(gdb.moSell) then
        add("leftover:gmsell", "GearMatic's \"always sell\" list still has items the Mastercraft VENDOR patch added for a vendor visit (it's off now).", "Remove", function()
            for id in pairs(gdb.moSell) do if gdb.sellMark then gdb.sellMark[id] = nil end end
            gdb.moSell = nil
        end)
    end

    -- Details in a chat tab: it hooks the game's chat tabs (FCF_SetWindowName, FCF_Close), which Chattynator
    -- replaces with its own - the two can't work together
    local det = _G.Details
    if Loaded("Details") and Loaded("Chattynator") and type(det) == "table" and type(det.chat_tab_embed) == "table"
        and det.chat_tab_embed.enabled then
        add("details:chatembed", "Details is set to sit in a chat tab, but Chattynator replaces the game's chat tabs. Turn Details' chat tab off.", "Turn off", function()
            if det.chat_embed and det.chat_embed.SetTabSettings then
                pcall(det.chat_embed.SetTabSettings, det.chat_embed, det.chat_tab_embed.tab_name or "", false)
            end
            det.chat_tab_embed.enabled = false
        end)
    end

    -- BetterBlizzFrames options that move the same minimap / chat pieces as OpenMap_MiniMap / Chattynator
    local bbf = _G.BetterBlizzFramesDB
    if Loaded("BetterBlizzFrames") and type(bbf) == "table" then
        local clashes = {
            { "classicMinimap", "OpenMap_MiniMap", "its classic minimap re-skin" },
            { "foreverMinimapTweaks", "OpenMap_MiniMap", "its minimap tweaks (scale, position, title, mail)" },
            { "hideMinimapButtons", "OpenMap_MiniMap", "hiding minimap buttons (OpenMap_MiniMap's tray holds them)" },
            { "hideMinimap", "OpenMap_MiniMap", "hiding the minimap" },
            { "hideChatButtons", "Chattynator", "hiding the chat buttons (Chattynator moves them into its own bar)" },
        }
        for _, c in ipairs(clashes) do
            local key, other, what = c[1], c[2], c[3]
            if bbf[key] == true and Loaded(other) then
                add("bbf:" .. key, ("BetterBlizzFrames' %s works on the same frames as %s - the two will fight. Turn it off in BetterBlizzFrames."):format(what, other),
                    "Turn off", function() bbf[key] = false end)
            end
        end
    end

    -- addons a newer patch of ours now does the job of
    -- (the ones without the MasterOptions_ prefix are older "local patch" addons: the loader doesn't
    -- see them, so their module would run as well)
    for old, new in pairs({ OpenMap_NoDungeonMap = "MasterOptions_DungeonJournal_OpenMap",
                            OpenMapTweaks_Mastercraft = "MasterOptions_OpenMapTweaks_Mastercraft",
                            CheapUpgrades_Baganator = "MasterOptions_CheapUpgrades_Baganator",
                            Mastercraft_Baganator = "MasterOptions_Mastercraft_FishingView",
                            MasterOptions_Mastercraft_Baganator = "MasterOptions_Mastercraft_FishingView" }) do
        local mods2 = _G.MasterOptions_Modules
        if Exists(old) and (Exists(new) or (mods2 and mods2.Has(new))) then
            add("replaced:" .. old, ("%s is no longer needed: %s does the same. Disable it, then delete its folder."):format(old, new),
                AddonEnabled(old) and "Disable" or nil,
                function() SetAddonEnabled(old, false); if Exists(new) then SetAddonEnabled(new, true) end end)
        end
    end

    -- Pawn without Pawn Forever: GearMatic's weights, CheapUpgrades' badges, the quest reward pick and Baganator's
    -- upgrade arrow all follow the scales Pawn shows, and Pawn's stock Classic scales aren't made for WoW Forever
    -- (enabled but not loaded yet is left to the "didn't load" check above, or to the reload after Enable)
    if Loaded("Pawn") and not Exists("Pawn_Forever") then
        add("pawnforever:missing", "Pawn is installed without Pawn Forever, so stat weights (GearMatic, CheapUpgrades, quest rewards, bag upgrade arrows) come from Pawn's stock Classic scales. Install Pawn Forever for weights made for WoW Forever.")
    elseif Loaded("Pawn") and not AddonEnabled("Pawn_Forever") then
        add("pawnforever:off", "Pawn Forever is disabled, so stat weights (GearMatic, CheapUpgrades, quest rewards, bag upgrade arrows) come from Pawn's stock Classic scales.",
            "Enable", function() SetAddonEnabled("Pawn_Forever", true) end)
    end

    -- Sparkles_Forever with Mastercraft
    local spk, mcs = SPK(), MC()
    if spk and mcs then
        -- Mastercraft's bobber mark on, Sparkles' bobber effect off: Sparkles then turns the bobber's nameplate off,
        -- and Mastercraft's mark sits on it - so neither shows
        if spk.sparkleBobber == false and mcs.fishMarker ~= false then
            add("sparkles:bobber", "Mastercraft's fishing bobber mark is on but Sparkles' bobber effect is off - Sparkles then turns off the bobber's nameplate that Mastercraft's mark sits on, so your bobber isn't marked at all.",
                "Use Sparkles'", function() spk.sparkleBobber = true; mcs.fishMarker = false end)
        end
        -- "Switch Herbs and Ore for me" swaps your tracking every few seconds: with nodes shown "While tracking",
        -- Mastercraft's (and OpenMap_Tweaks', through the module) node pins blink in and out with it
        if spk.masterEnabled ~= false and spk.minimapAutoAlternate == true and spk.minimapResources == true
            and (mcs.nodesWhen or "tracking") == "tracking" then
            add("sparkles:alternate", "Sparkles' \"Switch Herbs and Ore for me\" swaps your tracking every few seconds, so gathering node pins shown \"While tracking\" blink in and out. Turn the switching off, or set When nodes show to Always.",
                "Turn off", function() spk.minimapAutoAlternate = false end)
        end
    end

    -- 4. Baganator settings pointing at addons that aren't loaded
    local p = BAG()
    if p then
        local j = p.junk_plugin
        if BAG_JUNK_OWNER[j] and not OwnerLoaded(BAG_JUNK_OWNER[j]) then
            add("bagjunk:" .. j, ("Baganator's junk coin is set to \"%s\", whose addon isn't loaded (so only greys are marked)."):format(j), "Reset",
                function() SetBagPlugin(p, "junk", Loaded("MasterOptions_GearMatic_Baganator") and "gearmatic" or "poor_quality") end)
        end
        local u = p.upgrade_plugin
        if BAG_UPGRADE_OWNER[u] and not OwnerLoaded(BAG_UPGRADE_OWNER[u]) then
            add("bagupgrade:" .. u, ("Baganator's upgrade plugin is set to \"%s\", whose addon isn't loaded."):format(u), "Reset",
                function() SetBagPlugin(p, "upgrade", Loaded("Pawn") and "pawn" or "none") end)
        end
        -- GearMatic 6.10's "Gold coin" vendor badge is the same icon as Baganator's junk coin ("will be sold")
        local gs = GM()
        if gs and gs.vendorMarkerStyle == "coin" and gs.bestGoldShowVendor ~= false and p.junk_plugin ~= "none" then
            add("bagcoin:gearmatic", "GearMatic's vendor badge is the gold coin, the same icon as Baganator's junk coin - so a coin in your bags may mean \"sold\" or only \"worth most at a vendor\". Switch GearMatic's badge to the gold $.",
                "Use Gold $", function() gs.vendorMarkerStyle = "dollar"; GMRefreshBagIcons() end)
        end
    end
    return out
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local rows = {}
local needsReload = false
local reloadBtn
local RefreshProblems -- set once the window exists

local function RefreshAll()
    -- (every change in the window or Options ends here: matched bag icons follow it)
    local ok, changed = pcall(SyncIcons)
    if ok and changed then needsReload = true end
    for _, r in ipairs(rows) do r:Refresh() end
    if RefreshProblems then RefreshProblems() end
    if reloadBtn then reloadBtn:SetShown(needsReload) end
end

local Available

-- Recommended setup, applied once per character on first load (and by the button).
-- Skips anything whose addon isn't loaded; returns how many rows it set.
local DEFAULTS_VERSION = 26
local Remember -- set below
local function ApplyRecommended(after, manual) -- after: only options added after this defaults version
    local n = 0
    for _, opt in ipairs(OPTIONS) do
        if opt.rec ~= nil and Available(opt) and (opt.since or 1) > (after or 0) then
            local want = opt.rec
            if opt.kind == "choice" and not opt.needs and want ~= "Off" and want ~= opt.off and not Loaded(want) then want = nil end
            if want ~= nil and opt.get() ~= want then
                local ok = pcall(opt.set, want)
                if ok then
                    n = n + 1
                    if opt.reload then needsReload = true end
                    if manual and Remember then Remember(opt) end
                end
            end
        end
    end
    RefreshAll()
    return n
end

-- Per-character rows kept the same on every character (MasterOptionsDB.shared[label] = value)
local function SharedStore()
    MasterOptionsDB.shared = MasterOptionsDB.shared or {}
    return MasterOptionsDB.shared
end
Remember = function(opt) -- after the player changed a row: keep it for the account
    if MasterOptionsDB and MasterOptionsDB.seedPending then
        MasterOptionsDB.seedPending = nil
        SeedShared()
    end
    if not (opt.scope and MasterOptionsDB and MasterOptionsDB.syncChars) then return end
    local ok, v = pcall(opt.get)
    if ok and v ~= nil and v ~= "Both (conflict)" and v ~= "Mixed" then SharedStore()[opt.label] = v end
end
SeedShared = function(onlyMissing)
    local store = SharedStore()
    for _, opt in ipairs(OPTIONS) do
        if opt.scope and Available(opt) and not (onlyMissing and store[opt.label] ~= nil) then
            local ok, v = pcall(opt.get)
            if ok and v ~= nil and v ~= "Both (conflict)" and v ~= "Mixed" then store[opt.label] = v end
        end
    end
end
-- at login: make this character match the account's choices; returns how many rows changed
local function ApplyShared()
    if not (MasterOptionsDB and MasterOptionsDB.syncChars) then return 0 end
    if MasterOptionsDB.seedPending then
        MasterOptionsDB.seedPending = nil
        SeedShared() -- just turned on: this character (after its recommended setup) is the template
        return 0
    end
    SeedShared(true) -- rows added since: start from this character
    local store, n = SharedStore(), 0
    for _, opt in ipairs(OPTIONS) do
        local want = opt.scope and store[opt.label]
        if want ~= nil and Available(opt) then
            local ok, cur = pcall(opt.get)
            if ok and cur ~= want and pcall(opt.set, want) then
                n = n + 1
                if opt.reload then needsReload = true end
            end
        end
    end
    if n > 0 then RefreshAll() end
    return n
end

function Available(opt)
    if type(opt.needs) == "table" then
        for _, n in ipairs(opt.needs) do if not Loaded(n) then return false end end
    elseif opt.needs and not Loaded(opt.needs) then
        return false
    end
    if opt.kind == "choice" and opt.needs then return true end
    if opt.kind == "choice" then
        for _, c in ipairs(opt.choices) do
            if c ~= "Off" and Loaded(c) then return true end
        end
        return false
    end
    return true
end

local function Tooltip(frame, opt)
    if not opt.tip then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(opt.label, 1, 1, 1)
        local text = opt.tip
        if type(text) == "function" then
            local ok, t = pcall(text); text = ok and t or nil
        end
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        if opt.scope then
            local synced = MasterOptionsDB and MasterOptionsDB.syncChars
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("Saved per %s by its addon. %s"):format(opt.scope,
                synced and "\"Same choices on every character\" is on: your choice is applied on every character at login."
                    or "Turn on \"Same choices on every character\" to keep it the same everywhere."), 0.44, 0.66, 0.86, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------
-- The window (/mo): sections on the left, the chosen section's settings on the right.
-- Each setting: its name, a short description, and a dropdown (choices) or a tick box.
-- A conflict ("Both (conflict)") tints the row red and marks its section; Problems is its own section.
---------------------------------------------------------------------------
local WIN_W, WIN_H = 680, 500
local SIDE_W = 160
local PANE_W = WIN_W - SIDE_W - 52
local CTRL_W = 160
local RED = { 1, 0.33, 0.33 }

local function ShortDesc(opt)
    if opt.desc then return opt.desc end
    local t = opt.tip
    if type(t) ~= "string" then return nil end
    local s = t:match("^(.-[%.!?])%s") or t
    if #s > 120 then s = s:sub(1, 117):gsub("%s+%S*$", "") .. "..." end
    return s
end

local function IsConflict(opt)
    if opt.kind ~= "choice" or not Available(opt) then return false end
    local ok, v = pcall(opt.get)
    return ok and v == "Both (conflict)"
end

-- Standalone window
local win = CreateFrame("Frame", "MasterOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
win:SetSize(WIN_W, WIN_H)
win:SetPoint("CENTER")
win:SetMovable(true)
win:SetClampedToScreen(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if MasterOptionsDB then MasterOptionsDB.winPos = { point, relPoint, x, y } end
end)
win:SetFrameStrata("DIALOG")
win:Hide()
tinsert(UISpecialFrames, "MasterOptionsFrame")
win.title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
win.title:SetPoint("TOP", 0, -5)
win.title:SetText("Master Options")

-- left: the sections
local side = CreateFrame("Frame", nil, win)
side:SetPoint("TOPLEFT", 10, -30)
side:SetPoint("BOTTOMLEFT", 10, 44)
side:SetWidth(SIDE_W)
local sideBg = side:CreateTexture(nil, "BACKGROUND")
sideBg:SetAllPoints()
sideBg:SetColorTexture(0, 0, 0, 0.25)
local divider = win:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 0.82, 0, 0.25)
divider:SetPoint("TOPLEFT", side, "TOPRIGHT", 4, 0)
divider:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 4, 0)
divider:SetWidth(1)

-- right: the chosen section, scrolling when long
local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", side, "TOPRIGHT", 12, 0)
scroll:SetPoint("BOTTOMRIGHT", -30, 44)
local body = CreateFrame("Frame", nil, scroll)
body:SetSize(PANE_W, 10)
scroll:SetScrollChild(body)

local sections = {}     -- { name, opts = {}, pane, button, height }
local current           -- the section shown

---------------------------------------------------------------------------
-- The choice menu: a small list under a dropdown button
---------------------------------------------------------------------------
local okMenu, menu = pcall(CreateFrame, "Frame", "MasterOptionsMenu", UIParent, "TooltipBackdropTemplate")
if not okMenu then
    -- (a client without that template: a plain dark box)
    menu = CreateFrame("Frame", "MasterOptionsMenu", UIParent)
    local bg = menu:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.95)
end
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:EnableMouse(true)
menu:Hide()
menu.rows = {}
tinsert(UISpecialFrames, "MasterOptionsMenu")
local menuWatch = CreateFrame("Frame", nil, menu)
pcall(menuWatch.RegisterEvent, menuWatch, "GLOBAL_MOUSE_DOWN")
menuWatch:SetScript("OnEvent", function()
    if menu:IsShown() and not menu:IsMouseOver() and not (menu.owner and menu.owner:IsMouseOver()) then menu:Hide() end
end)
win:HookScript("OnHide", function() menu:Hide() end)

local function Choose(opt, value)
    menu:Hide()
    pcall(opt.set, value)
    if opt.reload then needsReload = true end
    Remember(opt)
    RefreshAll()
end

local function OpenMenu(owner, opt)
    if menu:IsShown() and menu.owner == owner then menu:Hide() return end
    local cur = select(2, pcall(opt.get))
    local list = {}
    for _, c in ipairs(opt.choices) do
        if c == "Off" or c == opt.off or opt.needs or Loaded(c) then list[#list + 1] = c end
    end
    local width = CTRL_W
    for i, c in ipairs(list) do
        local r = menu.rows[i]
        if not r then
            r = CreateFrame("Button", nil, menu)
            r:SetHeight(20)
            r:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 20)
            r:SetPoint("RIGHT", -8, 0)
            r.hl = r:CreateTexture(nil, "HIGHLIGHT")
            r.hl:SetAllPoints()
            r.hl:SetColorTexture(1, 0.82, 0, 0.15)
            r.check = r:CreateTexture(nil, "ARTWORK")
            r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            r.check:SetSize(16, 16)
            r.check:SetPoint("LEFT", 0, 0)
            r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", 20, 0)
            r.text:SetJustifyH("LEFT")
            menu.rows[i] = r
        end
        r.text:SetText(c .. (c == opt.rec and "  |cff9d9d9d(recommended)|r" or ""))
        r.check:SetShown(c == cur)
        r:SetScript("OnClick", function() Choose(opt, c) end)
        width = math.max(width, (r.text:GetStringWidth() or 0) + 40)
        r:Show()
    end
    for i = #list + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(width, #list * 20 + 16)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
    menu.owner = owner
    menu:Show()
end

---------------------------------------------------------------------------
-- A setting's row
---------------------------------------------------------------------------
local function BuildRow(parent, opt, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:EnableMouse(true)
    Tooltip(row, opt)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 8, -7)
    label:SetPoint("RIGHT", row, "RIGHT", -(CTRL_W + 16), 0)
    label:SetJustifyH("LEFT")
    local tags = ""
    if opt.scope then tags = tags .. "  |cff6fa8dc(per char)|r" end
    if opt.reload then tags = tags .. "  |cffd8a44c(reload)|r" end
    label:SetText(opt.label .. tags)

    local desc = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", row, "RIGHT", -(CTRL_W + 16), 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(ShortDesc(opt) or "")

    local h = 14 + (label:GetStringHeight() or 12) + ((desc:GetText() or "") ~= "" and (desc:GetStringHeight() or 10) + 3 or 0)
    row:SetHeight(math.max(36, h))

    if opt.kind == "choice" then
        local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btn:SetSize(CTRL_W, 22)
        btn:SetPoint("RIGHT", -6, 0)
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        arrow:SetSize(12, 12)
        arrow:SetPoint("RIGHT", -6, 0)
        arrow:SetRotation(-math.pi / 2)
        btn:SetScript("OnClick", function(self) OpenMenu(self, opt) end)
        Tooltip(btn, opt)
        function row:Refresh()
            local ok = Available(opt)
            btn:SetEnabled(ok)
            local v = ok and select(2, pcall(opt.get)) or "not installed"
            v = tostring(v)
            local text = v == opt.rec and (v .. " *") or v
            btn:SetText(v == "Both (conflict)" and ("|cffff5555" .. text .. "|r") or text)
            label:SetFontObject(ok and "GameFontHighlight" or "GameFontDisable")
            row.bg:SetColorTexture(RED[1], RED[2], RED[3], (ok and v == "Both (conflict)") and 0.12 or 0)
        end
    else
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("RIGHT", -6 - (CTRL_W - 26) / 2, 0)
        cb:SetScript("OnClick", function(self)
            pcall(opt.set, self:GetChecked() and true or false)
            if opt.reload then needsReload = true end
            Remember(opt)
            RefreshAll()
        end)
        local recText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        recText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        if opt.rec ~= nil then recText:SetText(opt.rec and "rec: on" or "rec: off") end
        function row:Refresh()
            local ok = Available(opt)
            cb:SetEnabled(ok)
            cb:SetChecked(ok and select(2, pcall(opt.get)) or false)
            label:SetFontObject(ok and "GameFontHighlight" or "GameFontDisable")
        end
    end
    rows[#rows + 1] = row
    return row:GetHeight()
end

---------------------------------------------------------------------------
-- Problems: its own section, first
---------------------------------------------------------------------------
local probPane = CreateFrame("Frame", nil, body)
probPane:SetPoint("TOPLEFT")
probPane:SetSize(PANE_W, 50) -- (a real size: a frame without one may not draw what's in it)
local probHeader = probPane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
probHeader:SetPoint("TOPLEFT", 8, -6)
probHeader:SetPoint("RIGHT", probPane, "RIGHT", -8, 0)
probHeader:SetJustifyH("LEFT")
local probLines = {}
local function ProbLine(i)
    local l = probLines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, probPane)
    l.bg = l:CreateTexture(nil, "BACKGROUND")
    l.bg:SetAllPoints()
    l.bg:SetColorTexture(RED[1], RED[2], RED[3], 0.08)
    l.text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    l.text:SetJustifyH("LEFT")
    l.text:SetPoint("TOPLEFT", 8, -6)
    l.text:SetPoint("RIGHT", l, "RIGHT", -146, 0)
    l.fix = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.fix:SetSize(70, 22)
    l.fix:SetPoint("RIGHT", -70, 0)
    l.ignore = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.ignore:SetSize(60, 22)
    l.ignore:SetPoint("RIGHT", -6, 0)
    l.ignore:SetText("Ignore")
    probLines[i] = l
    return l
end

local probCount, probHeight = 0, 50
local function FillProblems()
    local list = Problems()
    probCount = #list
    for _, l in ipairs(probLines) do l:Hide() end
    if #list == 0 then
        probHeader:SetText("|cff66dd66No problems found.|r  |cff9d9d9dErrors in our patches, addons that don't load, leftovers of old patches and settings pointing at missing addons show up here.|r")
        probHeight = 50
        probPane:SetHeight(probHeight)
        return
    end
    probHeader:SetText(("|cffff5555%d problem%s|r  |cff9d9d9d- fix (most take a reload) or ignore.|r"):format(#list, #list > 1 and "s" or ""))
    local y = -30
    for i, p in ipairs(list) do
        local l = ProbLine(i)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 0, y)
        l:SetPoint("RIGHT", probPane, "RIGHT", 0, 0)
        l.text:SetText(p.text)
        local h = math.max(34, (l.text:GetStringHeight() or 12) + 14)
        l:SetHeight(h)
        l.fix:SetShown(p.fix ~= nil and p.fixLabel ~= nil)
        l.fix:SetText(p.fixLabel or "")
        l.fix:SetScript("OnClick", function()
            pcall(p.fix)
            if not p.noReload then needsReload = true end
            RefreshAll()
        end)
        l.ignore:SetText(p.ignoreLabel or "Ignore")
        l.ignore:SetScript("OnClick", function()
            if p.onIgnore then
                pcall(p.onIgnore)
            else
                MasterOptionsDB.ignoredProblems = MasterOptionsDB.ignoredProblems or {}
                MasterOptionsDB.ignoredProblems[p.id] = true
            end
            RefreshAll()
        end)
        l:Show()
        y = y - h - 4
    end
    probHeight = -y + 6
    probPane:SetHeight(probHeight)
end

---------------------------------------------------------------------------
-- Never sell: its own section - the shared list of Modules\NeverSell.lua (MasterOptions_NeverSell)
---------------------------------------------------------------------------
local nsPane = CreateFrame("Frame", nil, body)
nsPane:SetPoint("TOPLEFT")
nsPane:SetSize(PANE_W, 50)
local nsSec -- set in BuildWindow
local nsHeader = nsPane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nsHeader:SetPoint("TOPLEFT", 8, -6)
nsHeader:SetPoint("RIGHT", nsPane, "RIGHT", -8, 0)
nsHeader:SetJustifyH("LEFT")
local ItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local ItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local FillNeverSell -- (below)

-- the add box: an item ID, a shift-clicked item link, or an item dragged onto it
local nsBox = CreateFrame("EditBox", nil, nsPane, "InputBoxTemplate")
nsBox:SetSize(260, 22)
nsBox:SetAutoFocus(false)
local nsAdd = CreateFrame("Button", nil, nsPane, "UIPanelButtonTemplate")
nsAdd:SetSize(70, 22)
nsAdd:SetPoint("LEFT", nsBox, "RIGHT", 8, 0)
nsAdd:SetText("Add")
local nsHint = nsPane:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
nsHint:SetPoint("LEFT", nsAdd, "RIGHT", 10, 0)
nsHint:SetPoint("RIGHT", nsPane, "RIGHT", -8, 0)
nsHint:SetJustifyH("LEFT")
nsHint:SetText("Shift-click or drag an item here, or type its ID.")
local function NeverSellAddFromBox()
    local ns = _G.MasterOptions_NeverSell
    local text = nsBox:GetText()
    if type(text) ~= "string" then text = "" end
    local id = tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
    if ns and id then
        ns.Set(id, true)
        nsBox:SetText("")
        nsBox:ClearFocus()
        FillNeverSell()
    end
end
nsAdd:SetScript("OnClick", NeverSellAddFromBox)
nsBox:SetScript("OnEnterPressed", NeverSellAddFromBox)
nsBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local function DropItem()
    if not GetCursorInfo then return end
    local kind, id = GetCursorInfo() -- (not `GetCursorInfo and GetCursorInfo()`: that keeps only the first value)
    if kind == "item" and id then
        nsBox:SetText(tostring(id))
        if ClearCursor then ClearCursor() end
        NeverSellAddFromBox()
    end
end
nsBox:SetScript("OnReceiveDrag", DropItem)
nsBox:SetScript("OnMouseDown", function() if GetCursorInfo and GetCursorInfo() == "item" then DropItem() end end)
-- shift-click an item while the box has the cursor: its link goes in (the game only fills the chat box)
local function InsertLink(link)
    if nsBox:HasFocus() and type(link) == "string" then nsBox:SetText(link); return true end
end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", InsertLink) end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", InsertLink) end

local nsLines = {}
local function NeverSellLine(i)
    local l = nsLines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, nsPane)
    l:SetHeight(24)
    l.bg = l:CreateTexture(nil, "BACKGROUND")
    l.bg:SetAllPoints()
    l.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(20, 20)
    l.icon:SetPoint("LEFT", 8, 0)
    l.text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    l.text:SetPoint("LEFT", l.icon, "RIGHT", 6, 0)
    l.text:SetPoint("RIGHT", l, "RIGHT", -86, 0)
    l.text:SetJustifyH("LEFT")
    l.remove = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.remove:SetSize(70, 20)
    l.remove:SetPoint("RIGHT", -6, 0)
    l.remove:SetText("Remove")
    -- the item's tooltip on hover
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    nsLines[i] = l
    return l
end

local nsWaiting = false -- (an item's name not in the client's cache yet: shown once it arrives)
FillNeverSell = function()
    local ns = _G.MasterOptions_NeverSell
    for _, l in ipairs(nsLines) do l:Hide() end
    if not ns then
        nsHeader:SetText("|cff9d9d9dThe NeverSell module is off - turn it on under Modules (takes a reload).|r")
        nsBox:Hide(); nsAdd:Hide(); nsHint:Hide()
        if nsSec then nsSec.height = 50 end
        nsPane:SetHeight(50)
        return
    end
    nsBox:Show(); nsAdd:Show(); nsHint:Show()
    local list, where = ns.List(), ns.Sources()
    nsHeader:SetText(("|cffffd200%d item%s|r  |cff9d9d9dnever sold, never suggested for selling or deletion - the same list in %s. Add or remove one there, or here.|r")
        :format(#list, #list == 1 and "" or "s", #where > 0 and table.concat(where, ", ") or "no installed addon (GearMatic, Mastercraft, DeleteCheapestItem)"))
    local y = -6 - (nsHeader:GetStringHeight() or 14) - 8
    nsBox:ClearAllPoints()
    nsBox:SetPoint("TOPLEFT", 14, y)
    y = y - 30
    -- by name; items not cached yet last, by ID
    local items = {}
    for _, id in ipairs(list) do
        local name, link
        if ItemInfo then name, link = ItemInfo(id) end
        if not name then nsWaiting = true end
        items[#items + 1] = { id = id, name = name, link = link }
    end
    table.sort(items, function(a, b)
        if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
        if a.name and b.name and a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for i, r in ipairs(items) do
        local l = NeverSellLine(i)
        l.id = r.id
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 0, y)
        l:SetPoint("RIGHT", nsPane, "RIGHT", 0, 0)
        l.icon:SetTexture(ItemIcon and ItemIcon(r.id) or 134400)
        l.text:SetText((r.link or r.name or "item") .. "  |cff6a6a6a" .. r.id .. "|r")
        l.remove:SetScript("OnClick", function() ns.Set(r.id, false); FillNeverSell() end)
        l:Show()
        y = y - 25
    end
    local h = -y + 6
    if nsSec then nsSec.height = h end
    nsPane:SetHeight(h)
    if current == nsSec then body:SetHeight(math.max(10, h)) end
end

local nsEvents = CreateFrame("Frame")
nsEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
nsEvents:SetScript("OnEvent", function()
    if nsWaiting and nsPane:IsVisible() then nsWaiting = false; FillNeverSell() end
end)

---------------------------------------------------------------------------
-- The error log as text to copy (Problems > Copy, /mo errors)
---------------------------------------------------------------------------
local errWin
ShowErrorText = function()
    if not errWin then
        errWin = CreateFrame("Frame", "MasterOptionsErrorFrame", UIParent, "BasicFrameTemplateWithInset")
        errWin:SetSize(560, 380)
        errWin:SetPoint("CENTER")
        errWin:SetFrameStrata("DIALOG")
        errWin:SetMovable(true)
        errWin:EnableMouse(true)
        errWin:RegisterForDrag("LeftButton")
        errWin:SetScript("OnDragStart", errWin.StartMoving)
        errWin:SetScript("OnDragStop", errWin.StopMovingOrSizing)
        tinsert(UISpecialFrames, "MasterOptionsErrorFrame") -- (Escape closes it)
        local title = errWin:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
        title:SetText("Master Options - errors (Ctrl+C to copy)")
        local sf = CreateFrame("ScrollFrame", nil, errWin, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -32)
        sf:SetPoint("BOTTOMRIGHT", -32, 12)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(500)
        eb:SetScript("OnEscapePressed", function() errWin:Hide() end)
        -- (read-only: typing puts the text back)
        eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(errWin.text or "") self:HighlightText() end end)
        sf:SetScrollChild(eb)
        errWin.eb = eb
    end
    local log = _G.MasterOptions_ErrorLog
    errWin.text = log and log.Text() or "No error log."
    errWin.eb:SetText(errWin.text)
    errWin:Show()
    errWin.eb:SetFocus()
    errWin.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Sections and the side list
---------------------------------------------------------------------------
local function ShowSection(sec)
    current = sec
    for _, s in ipairs(sections) do
        s.pane:SetShown(s == sec)
        s.button.selected:SetShown(s == sec)
    end
    if sec.neverSell then FillNeverSell() end
    body:SetHeight(math.max(10, (sec.problems and probHeight or sec.height) or 10))
    scroll:SetVerticalScroll(0)
    menu:Hide()
    if MasterOptionsDB then MasterOptionsDB.lastSection = sec.name end
end

local function SideButton(sec, i)
    local b = CreateFrame("Button", nil, side)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", 2, -4 - (i - 1) * 25)
    b:SetPoint("RIGHT", side, "RIGHT", -2, 0)
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetColorTexture(1, 0.82, 0, 0.18)
    b.selected:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -22, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(sec.name)
    b.badge = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.badge:SetPoint("RIGHT", -6, 0)
    b:SetScript("OnClick", function() ShowSection(sec) end)
    sec.button = b
end

local function BuildWindow()
    -- Problems first
    local probSec = { name = "Problems", pane = probPane, problems = true }
    sections[1] = probSec
    -- then a section for every header of OPTIONS
    local sec
    for _, opt in ipairs(OPTIONS) do
        if opt.header then
            sec = { name = (opt.header:gsub("%s*%(.-%)%s*$", "")), opts = {} }
            sections[#sections + 1] = sec
        elseif sec then
            sec.opts[#sec.opts + 1] = opt
        end
    end
    -- Never sell: right after Vendor and bank (or last)
    nsSec = { name = "Never sell", pane = nsPane, neverSell = true, height = 50, opts = {} }
    local at = #sections + 1
    for i, s in ipairs(sections) do if s.name == "Vendor and bank" then at = i + 1 end end
    table.insert(sections, at, nsSec)
    for i, s in ipairs(sections) do
        if not s.problems and not s.neverSell then
            s.pane = CreateFrame("Frame", nil, body)
            s.pane:SetPoint("TOPLEFT")
            s.pane:SetSize(PANE_W, 10)
            local y = -2
            for _, opt in ipairs(s.opts) do y = y - BuildRow(s.pane, opt, y) - 2 end
            s.height = -y + 4
            s.pane:SetHeight(s.height) -- (a real size: a frame without one may not draw what's in it)
        end
        s.pane:Hide()
        SideButton(s, i)
    end
    local want = MasterOptionsDB and MasterOptionsDB.lastSection
    local first = sections[2] or sections[1]
    for _, s in ipairs(sections) do if s.name == want then first = s end end
    -- the list changed (in another addon, or by /mo never): shown again if it's open
    local ns = _G.MasterOptions_NeverSell
    if ns then ns.OnChange = function() if nsPane:IsVisible() then FillNeverSell() end end end
    ShowSection(first)
    -- the window where it was left
    local pos = MasterOptionsDB and MasterOptionsDB.winPos
    if type(pos) == "table" and pos[1] then
        win:ClearAllPoints()
        win:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    end
end

RefreshProblems = function()
    FillProblems()
    for _, s in ipairs(sections) do
        local b = s.button
        if b then
            if s.problems then
                b.badge:SetText(probCount > 0 and ("|cffff5555" .. probCount .. "|r") or "")
            elseif s.neverSell then
                local ns = _G.MasterOptions_NeverSell
                local n = ns and #ns.List() or 0
                b.badge:SetText(n > 0 and ("|cff9d9d9d" .. n .. "|r") or "")
            else
                local n = 0
                for _, opt in ipairs(s.opts) do if IsConflict(opt) then n = n + 1 end end
                b.badge:SetText(n > 0 and ("|cffff5555" .. n .. "|r") or "")
            end
        end
    end
    if current then body:SetHeight(math.max(10, (current.problems and probHeight or current.height) or 10)) end
end
-- a new error while the window is open: shown at once
if _G.MasterOptions_ErrorLog then
    MasterOptions_ErrorLog.OnChange = function() if win:IsShown() then RefreshProblems() end end
end

-- footer
reloadBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
reloadBtn:SetSize(110, 24)
reloadBtn:SetPoint("BOTTOMRIGHT", -12, 12)
reloadBtn:SetText("Reload UI")
reloadBtn:SetScript("OnClick", ReloadUI)
reloadBtn:Hide()
local recBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
recBtn:SetSize(140, 24)
recBtn:SetPoint("BOTTOMLEFT", 12, 12)
recBtn:SetText("Use recommended")
recBtn:SetScript("OnClick", function()
    local n = ApplyRecommended(nil, true)
    print("|cffffd200Master Options:|r recommended setup applied (" .. n .. " changed).")
end)
local note = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("LEFT", recBtn, "RIGHT", 12, 0)
note:SetPoint("RIGHT", reloadBtn, "LEFT", -12, 0)
note:SetJustifyH("LEFT")
note:SetText("|cffff5555Red|r = two addons doing the same job.  * = recommended.  Hover a setting for more.")

win:SetScript("OnShow", RefreshAll)

local function OpenWindow()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    win:Show()
end

---------------------------------------------------------------------------
-- Options > AddOns > Master Options: every row of the window as the game's own checkbox or dropdown
-- (the same get/set as the window, so both always show the same). The page's Defaults button applies
-- the recommended setup. Rows whose addons aren't loaded are left out, as the window greys them.
---------------------------------------------------------------------------
local settingsCategory
local function IsChoice(opt, v)
    for _, c in ipairs(opt.choices or {}) do if c == v then return true end end
    return false
end
local function SafeGet(opt)
    local ok, v = pcall(opt.get)
    if ok then return v end
end
local reloadSaid = false
local function RegisterSettingsPanel()
    if settingsCategory or not (Settings and Settings.RegisterAddOnCategory) then return end
    if not (Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting and Settings.VarType) then
        -- a client without the list-style pages: a page with a button that opens the window
        if not Settings.RegisterCanvasLayoutCategory then return end
        local panel = CreateFrame("Frame")
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(200, 26)
        b:SetPoint("TOPLEFT", 16, -16)
        b:SetText("Open Master Options")
        b:SetScript("OnClick", OpenWindow)
        settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Master Options")
        Settings.RegisterAddOnCategory(settingsCategory)
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("Master Options")
    local function Header(text)
        if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
            pcall(layout.AddInitializer, layout, CreateSettingsListSectionHeaderInitializer(text))
        end
    end
    local function Button(label, text, fn, tip)
        if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
            pcall(layout.AddInitializer, layout, CreateSettingsButtonInitializer(label, text, fn, tip, true))
        end
    end
    Button("Master Options window", "Open", OpenWindow,
        "The same settings in Master Options' own window (/mo), with the Problems list.")
    Button("Some changes need a reload", "Reload", ReloadUI,
        "Skins, bag icons and compatibility patches take effect after a reload.")

    local function Changed(opt)
        if opt.reload then
            needsReload = true
            if not reloadSaid then
                reloadSaid = true
                print("|cffffd200Master Options:|r reload to finish (the Reload button at the top of the page, or /reload).")
            end
        end
        Remember(opt)
        RefreshAll()
    end

    local header
    for i, opt in ipairs(OPTIONS) do
        if opt.header then
            header = opt.header
        elseif Available(opt) then
            if header then Header(header); header = nil end
            local variable = "MasterOptions_Row" .. i
            local name = opt.label .. (opt.scope and " (per char)" or "")
            local tip = opt.tip
            if type(tip) == "function" then local ok, t = pcall(tip); tip = ok and t or nil end
            if opt.kind == "toggle" then
                local default = opt.rec
                if default == nil then default = SafeGet(opt) and true or false end
                local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, default,
                    function() return Available(opt) and SafeGet(opt) and true or false end,
                    function(v)
                        v = v and true or false
                        if Available(opt) and (SafeGet(opt) and true or false) ~= v then
                            pcall(opt.set, v)
                            Changed(opt)
                        end
                    end)
                Settings.CreateCheckbox(category, setting, tip)
            else
                local default = opt.rec
                if default == nil or not IsChoice(opt, default) then default = opt.choices[1] end
                local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.String, name, default,
                    function() return tostring(SafeGet(opt) or default) end,
                    function(v)
                        if IsChoice(opt, v) and Available(opt) and SafeGet(opt) ~= v then
                            pcall(opt.set, v)
                            Changed(opt)
                        end
                    end)
                Settings.CreateDropdown(category, setting, function()
                    local c = Settings.CreateControlTextContainer()
                    for _, choice in ipairs(opt.choices) do
                        -- (as the window's button: choices whose addon isn't loaded are left out)
                        if choice == "Off" or choice == opt.off or opt.needs or Loaded(choice) then
                            c:Add(choice, choice == opt.rec and (choice .. " *") or choice)
                        end
                    end
                    -- a state that isn't a choice ("Both (conflict)", "Mixed") is shown, in red
                    local cur = SafeGet(opt)
                    if cur ~= nil and not IsChoice(opt, cur) then c:Add(tostring(cur), "|cffff5555" .. tostring(cur) .. "|r") end
                    return c:GetData()
                end, tip)
            end
        end
    end
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

local function OpenSettingsPage()
    if settingsCategory and Settings and Settings.OpenToCategory then
        local id = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID
        if pcall(Settings.OpenToCategory, id) then return end
    end
    win:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    MasterOptionsDB = MasterOptionsDB or {}
    BuildWindow()

    -- Options > AddOns > Master Options: the same settings as the game's own controls
    pcall(RegisterSettingsPanel)

    -- WoW Forever: UnitName gives first and last name and the realm name is empty, so "Name-Realm"
    -- was the same key ("Testchar-") for every character sharing a first name. Key on the full name;
    -- a character with no record yet takes over the old shared key's version.
    local first, last = UnitName("player")
    local realm = GetRealmName() or ""
    local legacy = (first or "?") .. "-" .. realm
    local char = (first or "?") .. ((last and last ~= "") and (" " .. last) or "") .. "-" .. realm
    MasterOptionsDB.applied = MasterOptionsDB.applied or {}
    C_Timer.After(2, function()
        local prev = MasterOptionsDB.applied[char] or MasterOptionsDB.applied[legacy] or 0
        local n = 0
        if prev < DEFAULTS_VERSION then
            MasterOptionsDB.applied[char] = DEFAULTS_VERSION
            -- first run: everything; later versions: only the rows added since (your own choices stay)
            n = ApplyRecommended(prev)
        end
        -- then your account-wide choices for the per-character rows (they win over "recommended")
        local s = ApplyShared()
        -- matched bag icons: a choice changed in the addon itself (GearMatic's weights, its junk selling)
        local okI, icons = pcall(SyncIcons)
        if okI and icons then
            needsReload = true
            print("|cffffd200Master Options:|r bag icons matched to your stat weights / junk seller - /reload to show them.")
        end
        if n > 0 or s > 0 then
            local parts = {}
            if n > 0 then parts[#parts + 1] = "recommended setup applied (" .. n .. " changed)" end
            if s > 0 then parts[#parts + 1] = s .. " per-character setting" .. (s > 1 and "s" or "") .. " matched to your other characters" end
            print("|cffffd200Master Options:|r " .. table.concat(parts, "; ") .. ". /mo to review." .. (needsReload and " Reload to finish." or ""))
        end
    end)

    -- Minimap button (LibDBIcon: drag it round the edge; OpenMap_MiniMap's tray collects it)
    MasterOptionsDB.minimap = MasterOptionsDB.minimap or {}
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and DBI then
        local obj = LDB:NewDataObject("MasterOptions", {
            type = "launcher",
            label = "Master Options",
            icon = "Interface\\AddOns\\MasterOptions\\Minimap",
            OnClick = function(_, button)
                if button == "RightButton" then
                    MasterOptionsDB.minimap.hide = true
                    DBI:Hide("MasterOptions")
                    print("|cffffd200Master Options:|r minimap button hidden. /mo minimap brings it back.")
                else
                    win:SetShown(not win:IsShown())
                end
            end,
            OnTooltipShow = function(tt)
                tt:AddLine("Master Options")
                local n = 0
                for _, opt in ipairs(OPTIONS) do
                    if opt.kind == "choice" and Available(opt) and opt.get() == "Both (conflict)" then n = n + 1 end
                end
                if n > 0 then
                    tt:AddLine(n .. " setting" .. (n > 1 and "s" or "") .. " doubled up", 1, 0.33, 0.33)
                else
                    tt:AddLine("No doubled-up settings", 0.4, 1, 0.4)
                end
                local np = #Problems()
                if np > 0 then tt:AddLine(np .. " addon problem" .. (np > 1 and "s" or ""), 1, 0.33, 0.33) end
                tt:AddLine("|cffffffffClick|r to open, |cffffffffRight-click|r to hide this button", 0.7, 0.7, 0.7)
            end,
        })
        DBI:Register("MasterOptions", obj, MasterOptionsDB.minimap)
    end

    -- Health check once per login
    C_Timer.After(4, function()
        local list = Problems()
        if #list == 0 then return end
        print(("|cffffd200Master Options:|r %d addon problem%s found - %s Type /mo to fix or ignore.")
            :format(#list, #list > 1 and "s" or "", list[1].text:match("^[^\n]*") .. (#list > 1 and (" (+" .. (#list - 1) .. " more)") or "")))
    end)

    -- Warn once per login if anything is doubled up
    local conflicts = {}
    for _, opt in ipairs(OPTIONS) do
        if opt.kind == "choice" and Available(opt) and opt.get() == "Both (conflict)" then
            conflicts[#conflicts + 1] = opt.label
        end
    end
    if #conflicts > 0 then
        C_Timer.After(3, function()
            conflicts = {}
            for _, opt in ipairs(OPTIONS) do
                if opt.kind == "choice" and Available(opt) and opt.get() == "Both (conflict)" then conflicts[#conflicts + 1] = opt.label end
            end
            if #conflicts == 0 then return end
            print("|cffffd200Master Options:|r two addons doing the same job: " .. table.concat(conflicts, ", ") .. ". Type /mo to pick one.")
        end)
    end
end)

-- Pawn -> GearMatic bridge events (see SyncPawnHidden)
local bridge = CreateFrame("Frame")
bridge:RegisterEvent("PLAYER_LOGIN")
bridge:RegisterEvent("PLAYER_LOGOUT")
bridge:RegisterEvent("PLAYER_LEVEL_UP")
-- druids: a talent change can change which Pawn scale GearMatic should use (see DruidPawnSpec)
for _, e in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(bridge.RegisterEvent, bridge, e) end
local resyncPending, specPending = false, false
local function Resync()
    resyncPending = false
    SyncPawnHidden()
    if GMUsesPawn() then RefreshGearMatic() end
end
bridge:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Pawn (an optional dependency, so loaded first) has set up its scales by now, and
        -- GearMatic copies them 2 s after login: flag them before that, and again to be sure.
        SyncPawnHidden()
        C_Timer.After(1, SyncPawnHidden)
        C_Timer.After(3, function() if GMUsesPawn() then Resync() end end)
        -- Pawn and CheapUpgrades follow GearMatic's spec (after GearMatic and Pawn are set up)
        C_Timer.After(3.5, function() pcall(FollowSpec) end)
        -- showing or hiding a scale in Pawn (or /pff stock|forever) changes what GearMatic uses
        local function QueueResync()
            if resyncPending then return end
            resyncPending = true
            C_Timer.After(0.2, Resync)
        end
        if type(_G.PawnSetScaleVisible) == "function" then hooksecurefunc("PawnSetScaleVisible", QueueResync) end
        -- GearMatic's Cat/Bear choice (/gm feral) picks the druid's Feral scale
        local gm = _G.GearMatic
        if type(gm) == "table" and type(gm.SetFeralRole) == "function" then
            hooksecurefunc(gm, "SetFeralRole", QueueResync)
            hooksecurefunc(gm, "SetFeralRole", function() C_Timer.After(0.3, function() pcall(FollowSpec) end) end)
        end
    elseif event == "PLAYER_LEVEL_UP" then
        -- Pawn Forever switches to its level-60 values 1 s after the level-up
        if GMUsesPawn() then C_Timer.After(2, RefreshGearMatic) end
    elseif event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        if select(2, UnitClass("player")) == "DRUID" and GMUsesPawn() and not resyncPending then
            resyncPending = true
            C_Timer.After(0.5, Resync)
        end
        -- a spec change: Pawn and CheapUpgrades follow (once GearMatic has seen the new talents)
        if not specPending then
            specPending = true
            C_Timer.After(0.6, function() specPending = false; pcall(FollowSpec) end)
        end
    elseif event == "PLAYER_LOGOUT" then
        ClearPawnHidden()
    end
end)

SLASH_MASTEROPTIONS1 = "/mo"
SLASH_MASTEROPTIONS2 = "/masteroptions"
-- /mo never [remove] <item link or ID>, /mo never: the shared never-sell list (Modules\NeverSell.lua)
local function NeverSellCommand(rest)
    local ns = _G.MasterOptions_NeverSell
    local head = "|cffffd200Master Options:|r "
    if not ns then print(head .. "the NeverSell module is off (/mo > Modules).") return end
    local function Name(id)
        local name, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
        return link or name or ("item " .. id)
    end
    local remove, item = rest:match("^(remove)%s+(.+)$")
    item = item or rest
    local id = tonumber(item:match("item:(%d+)") or item:match("^(%d+)$"))
    if id then
        ns.Set(id, not remove)
        local where = ns.Sources()
        print(head .. Name(id) .. (remove and " taken off" or " put on") .. " the never-sell list"
            .. (#where > 0 and (" (" .. table.concat(where, ", ") .. ")") or "") .. ".")
        return
    end
    if item ~= "" then print(head .. "/mo never <item link or ID> adds, /mo never remove <item> takes off, /mo never lists.") return end
    ns.Sync()
    local list = ns.List()
    local where = ns.Sources()
    print(head .. #list .. " item" .. (#list == 1 and "" or "s") .. " on the never-sell list, kept in sync with "
        .. (#where > 0 and table.concat(where, ", ") or "no installed addon") .. ":")
    for i, itemID in ipairs(list) do
        if i > 40 then print(("  ... and %d more"):format(#list - 40)) break end
        print("  " .. Name(itemID))
    end
end

SlashCmdList.MASTEROPTIONS = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local never = msg:match("^[Nn][Ee][Vv][Ee][Rr]%s*(.*)$")
    if never then NeverSellCommand(never) return end
    msg = msg:lower()
    if msg == "minimap" then
        local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
        MasterOptionsDB.minimap = MasterOptionsDB.minimap or {}
        local hide = not MasterOptionsDB.minimap.hide
        MasterOptionsDB.minimap.hide = hide
        if DBI then if hide then DBI:Hide("MasterOptions") else DBI:Show("MasterOptions") end end
        print("|cffffd200Master Options:|r minimap button " .. (hide and "hidden" or "shown") .. ".")
        return
    end
    if msg == "options" or msg == "settings" then
        OpenSettingsPage()
        return
    end
    if msg == "errors" then
        ShowErrorText()
        return
    end
    win:SetShown(not win:IsShown())
end
