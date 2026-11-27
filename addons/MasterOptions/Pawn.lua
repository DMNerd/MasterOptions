-- Master Options: Pawn. Everything that knows Pawn's scales, in one file (loaded after MasterOptions.lua, before
-- the settings that use it):
--   * who judges upgrades (UpgradeJudge: Pawn with Pawn Forever, else GearMatic)
--   * Pawn's weights in GearMatic (its scales flagged for GearMatic), Pawn Forever's or stock scales
--   * "Spec for Pawn and CheapUpgrades": both follow GearMatic's spec
--   * gear to keep: Pawn's word, widened to every spec's scale (MasterOptions_PawnKeeps / _GearKeeps)
-- For the modules: MasterOptions_Pawn (Judge, UpgradePercent, SaysKeep) and MasterOptions_GearKeeps(Many) - they
-- never read Pawn themselves, and Shared.lua knows nothing of it.

local _, MO = ...
local Loaded, GM, PAWN = MO.Loaded, MO.GM, MO.PAWN
local function RawLoaded(name) -- (an addon itself, not one of our modules)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    return f ~= nil and f(name) and true or false
end
local function NonEmpty(t) return type(t) == "table" and next(t) ~= nil end

-- Pawn, with the scales as they are: an upgrade for a scale you show, or already your best or second-best item
-- for one (Pawn's 3rd / 4th returns: an off-spec piece you keep in your bags is never "an upgrade", but it is
-- your best). False without Pawn.
local function PawnSaysKeep(link)
    if type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return false end
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    local ok2, up, _, best, second = pcall(_G.PawnIsItemAnUpgrade, item)
    return ok2 and (NonEmpty(up) or NonEmpty(best) or NonEmpty(second)) or false
end

-- Who judges upgrades, for every choice that involves Pawn (one judge, so the stat weights, bag arrows,
-- CheapUpgrades, quest rewards and Dungeon Journal's loot marks agree): "Pawn" with Pawn Forever installed
-- (weights made for WoW Forever), otherwise "GearMatic", whose own weights are simulated for WoW Forever - Pawn
-- without Pawn Forever only has its stock Classic scales. Pawn alone (no GearMatic) is still Pawn.
local function UpgradeJudge()
    if RawLoaded("Pawn") and (RawLoaded("Pawn_Forever") or not RawLoaded("GearMatic")) then return "Pawn" end
    return "GearMatic"
end

-- Pawn: the biggest upgrade % across the scales Pawn shows for this character (nil = not an upgrade, or no Pawn;
-- false = Pawn hasn't got the item yet)
local function PawnUpgradePercent(link)
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
-- (the rule and why: UpgradeJudge, above)
local Judge = UpgradeJudge
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
local PawnKeepsOne = PawnSaysKeep

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

-- Asked for every bag slot on every Baganator redraw, every vendor pass and every bag update: the answer kept per
-- link until anything it depends on can have changed - your bags and gear (best / 2nd best among what you own), your
-- level, talents or spec - and for 5 s at most (Pawn's scales turned on or off fire nothing).
local keepCache, keepCacheAt = {}, 0
local keepCacheFrame = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE",
                     "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED" }) do
    pcall(keepCacheFrame.RegisterEvent, keepCacheFrame, e)
end
keepCacheFrame:SetScript("OnEvent", function() keepCache = {} end)

local function GearKeepsNow(link)
    if MasterOptions_PawnKeeps(link) then return true, "Pawn: an upgrade, or your best / 2nd best for a scale" end
    local m = SpecKeep()
    if not m then return false end
    local ok, out = pcall(m.KeepsMany, { link })
    if ok and type(out) == "table" and out[link] == true then return true, "GearMatic: your best for one of your specs" end
    return false
end

-- true, and why (for /mo vendor) - or false
function MasterOptions_GearKeeps(link)
    if type(link) ~= "string" then return false end
    local now = GetTime and GetTime() or 0 -- (the tests' sandbox has no clock: no cache there beyond the events)
    if now == 0 or now - keepCacheAt > 5 then keepCache, keepCacheAt = {}, now end
    local hit = keepCache[link]
    if hit == nil then
        local keeps, why = GearKeepsNow(link)
        hit = keeps and (why or true) or false
        keepCache[link] = hit
    end
    if hit then return true, hit ~= true and hit or nil end
    return false
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

---------------------------------------------------------------------------
-- Events (see SyncPawnHidden)
---------------------------------------------------------------------------
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


-- for the files after this one
MO.ClearPawnHidden = ClearPawnHidden
MO.FollowSpec = FollowSpec
MO.FollowSpecOn = FollowSpecOn
MO.GMUsesPawn = GMUsesPawn
MO.Judge = Judge
MO.PawnElseGearMatic = PawnElseGearMatic
MO.PawnShows = PawnShows
MO.RefreshGearMatic = RefreshGearMatic
MO.SetPawnScales = SetPawnScales
MO.SyncPawnHidden = SyncPawnHidden

-- for the modules
MasterOptions_Pawn = {
    Judge = UpgradeJudge,               -- "Pawn" or "GearMatic"
    UpgradePercent = PawnUpgradePercent, -- the biggest upgrade % across the scales Pawn shows (nil: none; false: not yet)
    SaysKeep = PawnSaysKeep,             -- an upgrade, or your best / 2nd best, for a scale you show
}
