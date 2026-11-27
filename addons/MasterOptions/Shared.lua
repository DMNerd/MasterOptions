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
-- Small helpers every part uses
---------------------------------------------------------------------------
-- An addon of someone else's, loaded (true / false)
local function AddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    return f and f(name) and true or false
end
S.AddOnLoaded = AddOnLoaded

-- fn once, a moment after the first of any number of calls: soon = Debounce(fn, 1); soon() / soon(0.2)
function S.Debounce(fn, defaultDelay)
    local pending = false
    return function(delay)
        if pending then return end
        pending = true
        C_Timer.After(delay or defaultDelay or 0, function()
            pending = false
            fn()
        end)
    end
end

-- A module's own ADDON_LOADED, run now: Master Options starts a module after the saved variables are in, so the
-- setup it did on that event as a separate addon happens here. (frame.OnEvent: the sandbox tests' frames)
function S.ReplayAddonLoaded(frame, addon)
    local h = frame.GetScript and frame:GetScript("OnEvent") or frame.OnEvent
    if h then h(frame, "ADDON_LOADED", addon) end
end

-- This character, as Master Options keys it in its saves: "First Last-Realm" (WoW Forever: first and last name,
-- and an empty realm name)
function S.CharacterKey()
    local first, last = UnitName("player")
    return (first or "?") .. ((last and last ~= "") and (" " .. last) or "") .. "-" .. (GetRealmName() or "")
end

-- Master Options' own version and author, from its .toc (one place: the window title, /mo > Thanks, the game's
-- Options page and the minimap button all show them)
function S.About()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local function Get(key)
        local ok, v = pcall(meta, "MasterOptions", key)
        return ok and type(v) == "string" and v ~= "" and v or nil
    end
    local version, author = meta and Get("Version") or "?", meta and Get("Author") or "DMNerd"
    return version, author, ("Master Options %s  |cff9d9d9dby %s|r"):format(version, author)
end

-- Mastercraft's saved data (MastercraftDB), or nil
function S.MastercraftDB()
    local db = _G.MastercraftDB
    return type(db) == "table" and db or nil
end

-- One of Questie's modules (QuestieLoader:ImportModule), or nil
function S.QuestieModule(name)
    local ql = _G.QuestieLoader
    if not (type(ql) == "table" and type(ql.ImportModule) == "function") then return nil end
    local ok, m = pcall(ql.ImportModule, ql, name)
    return ok and type(m) == "table" and m or nil
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
-- Gathering (Herbalism, Mining): your skill, and which nodes are worth it by Mastercraft's rule
---------------------------------------------------------------------------
S.HERB, S.MINE = 182, 186 -- (skill line IDs)
local HERB, MINE = S.HERB, S.MINE
local MAX_GATHER_SKILL = 300
local PROF_NAMES = {
    [HERB] = { Herbalism = true, Herboristerie = true, ["Kr\195\164uterkunde"] = true, ["Herborister\195\173a"] = true, Erbalismo = true, Herborismo = true },
    [MINE] = { Mining = true, Minage = true, Bergbau = true, ["Miner\195\173a"] = true, Estrazione = true, ["Minera\195\167\195\163o"] = true },
}

-- { [S.HERB] = rank, [S.MINE] = rank } for the gathering professions you have
function S.GatheringRanks()
    local found = {}
    if GetProfessions and GetProfessionInfo then
        local res = { pcall(GetProfessions) }
        if res[1] then
            for i = 2, 6 do
                local idx = res[i]
                if idx then
                    local ok, _, _, rank, _, _, _, sl = pcall(GetProfessionInfo, idx)
                    if ok and (sl == HERB or sl == MINE) then found[sl] = rank or 0 end
                end
            end
        end
    end
    if next(found) == nil and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank = GetSkillLineInfo(i)
            if name and not header then
                for sl, names in pairs(PROF_NAMES) do
                    if names[name] then found[sl] = rank or 0 end
                end
            end
        end
    end
    return found
end

-- Mastercraft's Settings > Nodes > Which nodes (settings.nodesFilter: "skillups" (its default), "gatherable", "all"):
-- is a node needing req skill worth it at skill? No req known: yes. At the top (300) there are no skill-ups left:
-- then all you can gather.
function S.GatherWanted(filter, skill, req)
    if filter == "all" then return true end
    if not skill then return false end
    if not req then return true end
    if skill < req then return false end
    if filter == "gatherable" or skill >= MAX_GATHER_SKILL then return true end
    return skill - req < 100
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

---------------------------------------------------------------------------
-- OpenMap: the spot it was last told to follow (its TrackPoint: a pin followed, Dungeon Journal's Show on Map),
-- until its ClearPin. OpenMap itself defines "followed" by where the game's waypoint is, but ShortestPathForever's
-- journey moves that waypoint along the way - so a pin's clearing was missed when matched by the waypoint
-- (Dungeon Journal's mark removed, the journey cleared). Watched from login (S.WatchOpenMapFollow).
---------------------------------------------------------------------------
local followed, followHooked
local NEAR = 5e-4

local function OpenMapWorldMap()
    local om = _G.OpenMap
    local mod = type(om) == "table" and type(om.GetModule) == "function" and om:GetModule("worldmap")
    return type(mod) == "table" and mod or nil
end
S.OpenMapWorldMap = OpenMapWorldMap

function S.WatchOpenMapFollow()
    if followHooked then return true end
    local mod = OpenMapWorldMap()
    if not (mod and type(mod.TrackPoint) == "function") then return false end
    followHooked = true
    hooksecurefunc(mod, "TrackPoint", function(mapID, x, y) followed = { mapID, x, y } end)
    if type(mod.ClearPin) == "function" then hooksecurefunc(mod, "ClearPin", function() followed = nil end) end
    return true
end

local function Same(mapID, x, y, m2, x2, y2)
    return mapID ~= nil and mapID == m2 and x and x2 and y and y2
        and math.abs(x - x2) < NEAR and math.abs(y - y2) < NEAR or false
end

-- whether OpenMap follows the spot now: the one it was told to follow, and either the game's waypoint still on it
-- or ShortestPathForever's journey for it (owner "OpenMap:Pin") still under way. Not followed any more (another
-- journey took over, OpenMap stopped it itself): false, so clearing it can't clear someone else's waypoint
function S.OpenMapFollows(mapID, x, y)
    local mod = OpenMapWorldMap()
    if not mod then return false end
    local wm, wx, wy = nil, nil, nil
    if type(mod.WaypointPoint) == "function" then wm, wx, wy = mod.WaypointPoint() end
    if Same(mapID, x, y, wm, wx, wy) then return true end
    if not (followed and Same(mapID, x, y, followed[1], followed[2], followed[3])) then return false end
    local spf = _G.ShortestPathForever
    local api = type(spf) == "table" and spf.API
    if not (type(api) == "table" and type(api.CurrentStop) == "function") then return false end
    local ok, stop = pcall(api.CurrentStop, "OpenMap:Pin")
    return ok and stop ~= nil
end

-- the spot OpenMap was last told to follow (map, x, y), else where the game's waypoint is
function S.OpenMapFollowed()
    if followed then return followed[1], followed[2], followed[3] end
    local mod = OpenMapWorldMap()
    if mod and type(mod.WaypointPoint) == "function" then return mod.WaypointPoint() end
end

---------------------------------------------------------------------------
-- Master Options' look for its own frames on others' maps (the minimap's zone bar and coordinates tab, the dungeon
-- chooser): the /mo window's header (the game's BasicFrameTemplate title bar - Details' title bar matches it),
-- else a grey gradient like it, darker at the top
---------------------------------------------------------------------------
local HEAD_TOP, HEAD_BOTTOM = { 0.06, 0.06, 0.06 }, { 0.18, 0.18, 0.175 }
-- a texture filled as the /mo window's header: its texture copied (atlas, or file and coords), else a gradient
local function TitleLike(tex)
    local src = _G.MasterOptionsFrame and _G.MasterOptionsFrame.TitleBg
    if not src then return false end
    local atlas = src.GetAtlas and src:GetAtlas()
    if atlas and tex.SetAtlas then
        tex:SetAtlas(atlas, false)
        if tex.SetHorizTile and src.GetHorizTile then tex:SetHorizTile(src:GetHorizTile() and true or false) end
        return true
    end
    local file = src.GetTexture and src:GetTexture()
    if not file then return false end
    tex:SetTexture(file)
    if src.GetTexCoord then tex:SetTexCoord(src:GetTexCoord()) end
    if src.GetVertexColor then tex:SetVertexColor(src:GetVertexColor()) end
    return true
end

function S.HeaderFill(tex)
    if TitleLike(tex) then return end
    tex:SetColorTexture(1, 1, 1, 1)
    local t, b = HEAD_TOP, HEAD_BOTTOM
    if _G.CreateColor and tex.SetGradient
        and pcall(tex.SetGradient, tex, "VERTICAL", _G.CreateColor(b[1], b[2], b[3], 1), _G.CreateColor(t[1], t[2], t[3], 1)) then
        return
    end
    if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, "VERTICAL", b[1], b[2], b[3], 1, t[1], t[2], t[3], 1) then
        return
    end
    tex:SetColorTexture((t[1] + b[1]) / 2, (t[2] + b[2]) / 2, (t[3] + b[3]) / 2, 1)
end


-- a map marker's tooltip, as OpenMap's and Questie's: the name in gold, its lines in white, a hint in grey, and
-- whose marker it is last, small and grey
function S.MarkerTooltip(owner, title, lines, hint, source)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title or "", 1, 0.82, 0)
    for _, l in ipairs(lines or {}) do GameTooltip:AddLine(l, 1, 1, 1, true) end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true) end
    GameTooltip:AddLine(source and ("Master Options - " .. source) or "Master Options", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end
