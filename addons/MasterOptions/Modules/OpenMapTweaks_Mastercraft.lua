-- Master Options module (was the addon MasterOptions_OpenMapTweaks_Mastercraft): runs when OpenMap_Tweaks and Mastercraft are loaded.
MasterOptions_Module("OpenMapTweaks_Mastercraft", { "OpenMap_Tweaks", "Mastercraft" }, function(ADDON)

-- OpenMap_Tweaks <-> Mastercraft compatibility patch.
--
-- Both addons can draw ore and herb spawn points. OpenMap_Tweaks' pins are built for OpenMap's
-- stitched map and painted minimap; Mastercraft's have the smarter filter. This patch keeps
-- OpenMap_Tweaks as the one drawing pins, and applies Mastercraft's own node settings to them:
--   Settings > Nodes "Show" filter : skillups (default) / gatherable / all
--   Settings > Nodes "When"        : tracking (default) / farming / always / never
--   the profession's own map switch (settings.nodes.Mining / .Herbalism = false)
-- Change those in Mastercraft (or Master Options) and the OpenMap_Tweaks pins follow.
-- Turn Mastercraft's own map/minimap pins off to avoid two pins per node (Master Options does this).

local Shared = MasterOptions_Shared
local HERB, MINE = Shared.HERB, Shared.MINE
local TRACK_SPELL = { [MINE] = 2580, [HERB] = 2383 }             -- Find Minerals, Find Herbs
local TRACK_ICON  = { [MINE] = 136025, [HERB] = 133939 }
local function MC() local db = Shared.MastercraftDB(); return db and type(db.settings) == "table" and db.settings or {} end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------
local ranks = {}
local function ScanRanks() ranks = Shared.GatheringRanks() end

local trackName = {}
local function SpellName(id)
    if trackName[id] == nil then
        local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
        trackName[id] = n or false
    end
    return trackName[id] or nil
end

local function Tracking(sl)
    local id = TRACK_SPELL[sl]
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        local name = SpellName(id)
        for i = 1, C_Minimap.GetNumTrackingTypes() or 0 do
            local info = C_Minimap.GetTrackingInfo(i)
            if type(info) == "table" and info.active
                and (info.spellID == id or (name and info.name == name)) then return true end
        end
    end
    if GetTrackingTexture then
        local tex = GetTrackingTexture()
        if tex == TRACK_ICON[sl] then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Mastercraft's rules (Nodes.lua: ns.NodesActive and Wanted), applied to an OpenMap_Tweaks node
---------------------------------------------------------------------------
local PROF_KEY = { [MINE] = "Mining", [HERB] = "Herbalism" } -- (Mastercraft's settings.nodes[prof] keys)

-- Mastercraft's farm session (Farm.lua: saved per character GUID while it runs, cleared at a real login)
local function Farming()
    local farm = type(_G.MastercraftDB) == "table" and _G.MastercraftDB.farm
    local s = type(farm) == "table" and UnitGUID and farm[UnitGUID("player") or ""]
    return type(s) == "table" and type(s.start) == "number"
end

local function Active(sl)
    local s = MC()
    if type(s.nodes) == "table" and s.nodes[PROF_KEY[sl]] == false then return false end -- (the profession's map switch)
    local when = s.nodesWhen or "tracking"
    if when == "never" then return false end
    if when == "always" then return true end
    if (IsResting and IsResting()) or (IsInInstance and IsInInstance()) or InCombatLockdown() then return false end
    if when == "farming" then return Farming() end -- (after Start farming only)
    return Tracking(sl) or Farming()
end

-- Active per profession, worked out twice a second and on the events below (RefreshAll), not per pin:
-- OpenMap_Tweaks calls Show on every minimap pin every frame, and each Show asks Wanted - Active's tracking scan
-- (GetTrackingInfo makes a table per type) for each pin each frame was a steady cost while moving.
local activeNow = {}
local function ActiveNow(sl)
    local a = activeNow[sl]
    if a == nil then a = Active(sl); activeNow[sl] = a end
    return a
end

local function Wanted(e)
    if type(e) ~= "table" or (e.sl ~= HERB and e.sl ~= MINE) then return true end
    if not ActiveNow(e.sl) then return false end
    return Shared.GatherWanted(MC().nodesFilter or "skillups", ranks[e.sl], tonumber(e.l))
end

local function SpotWanted(spot)
    for _, item in ipairs(spot and spot.list or {}) do
        if Wanted(item.e) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- World map: filter each pin as OpenMap_Tweaks acquires it
---------------------------------------------------------------------------
local Mixin = _G.OpenMapTweaksNodePinMixin
if type(Mixin) == "table" and type(Mixin.OnAcquired) == "function" then
    local orig = Mixin.OnAcquired
    Mixin.OnAcquired = function(self, spot, x, y)
        orig(self, spot, x, y)
        self:SetShown(SpotWanted(spot))
    end
end

---------------------------------------------------------------------------
-- World map with OpenMap's stitched map on: OpenMap_Tweaks skips the data provider above and adds its
-- pins through OpenMap.MapStitch.AddPin to the pin set "omt_gather" (each pin's .data is the spot).
-- AddPin shows the pin last and nothing after it shows it again, so hiding it right after sticks.
---------------------------------------------------------------------------
local STITCH_SET = "omt_gather"
local stitchHooked = false
local function Stitch()
    local om = rawget(_G, "OpenMap")
    local S = type(om) == "table" and om.MapStitch
    if type(S) == "table" and type(S.AddPin) == "function" and type(S.GetPinSet) == "function" then return S end
end
local function HookStitch()
    if stitchHooked then return end
    local S = Stitch()
    if not S then return end
    stitchHooked = true
    hooksecurefunc(S, "AddPin", function(set, u, v, look, data)
        if set ~= S.GetPinSet(STITCH_SET) then return end
        local pin = set.pins and set.pins[#set.pins]
        if pin and pin.data == data and not SpotWanted(data) then pin:Hide() end
    end)
end
local function RefreshStitched()
    local S = stitchHooked and Stitch()
    local set = S and S.GetPinSet(STITCH_SET)
    for _, pin in ipairs(set and set.pins or {}) do
        if type(pin.data) == "table" then pin:SetShown(SpotWanted(pin.data)) end
    end
end
HookStitch()

-- OpenMap's stitched map up: OpenMap_Tweaks draws its pins there (RefreshStitched), its Blizzard-map provider
-- does nothing, so refreshing every provider (Questie's pins rebuilt with them) was work for nothing - on each
-- fight's start and end while the map was open. Not in a fight either (OpenMap leaves Blizzard's map be then).
local function Stitched()
    local api = _G.OpenMapAPI
    if not (type(api) == "table" and type(api.IsStitched) == "function") then return false end
    local ok, on = pcall(api.IsStitched)
    return ok and on == true
end

local function RefreshWorldMap()
    if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.RefreshAllDataProviders
        and not Stitched() and not InCombatLockdown() then
        pcall(WorldMapFrame.RefreshAllDataProviders, WorldMapFrame)
    end
    RefreshStitched()
end

---------------------------------------------------------------------------
-- Minimap: OpenMap_Tweaks calls :Show() on each pin every update; hide the unwanted ones
---------------------------------------------------------------------------
local hooked, hiddenByUs = {}, {}
local childCount = 0

local function IsOMTPin(f)
    return type(f) == "table" and f.Icon and f.mode ~= nil and f.e ~= nil
end

local ourHide = false
local function HideOurs(f)
    ourHide = true
    f:Hide()
    ourHide = false
    hiddenByUs[f] = true
end

local function CheckPin(f)
    if Wanted(f.e) then
        if hiddenByUs[f] then hiddenByUs[f] = nil; f:Show() end
    elseif f:IsShown() then
        HideOurs(f)
    end
end

local function HookNewPins()
    if not Minimap then return end
    local n = Minimap:GetNumChildren()
    if n == childCount then return end
    childCount = n
    for _, f in ipairs({ Minimap:GetChildren() }) do
        if not hooked[f] and IsOMTPin(f) then
            hooked[f] = true
            hooksecurefunc(f, "Show", function(self)
                hiddenByUs[self] = nil
                if not Wanted(self.e) then HideOurs(self) end
            end)
            -- OpenMap_Tweaks retiring a pin: it's no longer ours to bring back
            hooksecurefunc(f, "Hide", function(self)
                if not ourHide then hiddenByUs[self] = nil end
            end)
            CheckPin(f)
        end
    end
end

local function RefreshMinimap()
    for f in pairs(hooked) do
        -- a pin OpenMap_Tweaks itself retired (not ours to bring back) stays hidden
        if f:IsShown() or hiddenByUs[f] then CheckPin(f) end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- what decides which pins show, as it was at the last refresh (compared value by value: the twice-a-second
-- look builds nothing)
local last, seenOnce = {}, false
local function Same(i, v)
    if last[i] == v then return true end
    last[i] = v
    return false
end

local function RefreshAll()
    local s = MC()
    local same = seenOnce
    if not Same(1, s.nodesFilter) then same = false end
    if not Same(2, s.nodesWhen) then same = false end
    if not Same(3, Farming()) then same = false end
    activeNow[MINE], activeNow[HERB] = Active(MINE), Active(HERB)
    if not Same(4, activeNow[MINE]) then same = false end
    if not Same(5, activeNow[HERB]) then same = false end
    if not Same(6, ranks[MINE]) then same = false end
    if not Same(7, ranks[HERB]) then same = false end
    if same then return end
    seenOnce = true
    RefreshMinimap()
    RefreshWorldMap()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "MINIMAP_UPDATE_TRACKING", "PLAYER_UPDATE_RESTING",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "SKILL_LINES_CHANGED" then ScanRanks() end
    RefreshAll()
end)

-- New minimap pins appear as you move; settings can change in Mastercraft's window. A light look twice a second.
local wait = 0
ev:SetScript("OnUpdate", function(_, dt)
    wait = wait + dt
    if wait < 0.5 then return end
    wait = 0
    HookStitch() -- (OpenMap builds its stitched map late: hooked once it exists)
    HookNewPins()
    RefreshAll()
end)
end)
