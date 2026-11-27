-- Master Options module: runs when Questie and OpenMap are loaded.
MasterOptions_Module("Questie_OpenMapTownsfolk", { "Questie", "OpenMap" }, function(ADDON)

-- Questie's townsfolk menu and OpenMap's Townsfolk menu, kept in step, each icon drawn once ("Town NPC icons":
-- "Questie + OpenMap, synced"):
--   * a kind ticked (or unticked) in either menu is ticked in the other too - repair, innkeepers, bankers, mailboxes,
--     auctioneers, stable masters, class trainers, spirit healers (the kinds both have)
--   * OpenMap draws them on its world map, Questie on the minimap: Questie's own world map icons of those kinds are
--     held back (Questie's FakeHide - HereBeDragons can't show them again) while OpenMap's stitched map is up. Where it
--     isn't (a map OpenMap doesn't stitch, Blizzard's map in a fight), Questie's come back.
-- Kinds only one of them has (Questie's vendors by goods, battlemasters, meeting stones ...; OpenMap's vendors, rare
-- mobs) stay each its own. Flight masters have their own row ("Flight masters"). Only their settings and Questie's
-- own redraw (QuestieMenu:OnLogin, as Master Options' other rows use it) are used.

local S = MasterOptions_Shared
local _, Check = S.ErrorReporters(ADDON)

-- Questie's key -> OpenMap's
local PAIRS = {
    { "Repair", "repair" }, { "Innkeeper", "innkeeper" }, { "Banker", "banker" }, { "Mailbox", "mailbox" },
    { "Auctioneer", "auctioneer" }, { "Stable Master", "stable" }, { "Class Trainer", "classTrainer" },
    { "Spirit Healer", "spirit" },
}
local SYNCED = {} -- Questie's keys that are synced
for _, p in ipairs(PAIRS) do SYNCED[p[1]] = true end

-- on for this character ("Town NPC icons" row)
local function On()
    local t = MasterOptionsDB and MasterOptionsDB.townSync
    return type(t) == "table" and t[S.CharacterKey()] == true
end

local function QuestieCfg()
    local q = _G.Questie
    local p = type(q) == "table" and q.db and q.db.profile
    if type(p) ~= "table" then return nil end
    p.townsfolkConfig = type(p.townsfolkConfig) == "table" and p.townsfolkConfig or {}
    return p.townsfolkConfig
end

local function OpenMapMod()
    local mod = S.OpenMapWorldMap()
    if mod and type(mod.db) == "table" and type(mod.db.townsfolk) == "table" then return mod end
end

local function QuestieMap() return S.QuestieModule("QuestieMap") end

---------------------------------------------------------------------------
-- Questie's world map icons of the synced kinds: held back while OpenMap draws them
---------------------------------------------------------------------------
local function OpenMapDraws()
    local api = _G.OpenMapAPI
    if not (type(api) == "table" and type(api.IsStitched) == "function") then return false end
    local ok, on = pcall(api.IsStitched)
    return ok and on == true
end

local function HideNow() return On() and OpenMapDraws() end

-- one of Questie's icon frames: its world map one held back (hide) or given back - only one we held back
local function Hold(frame, hide)
    if type(frame) ~= "table" or frame.miniMapIcon ~= false then return end -- (the minimap's stays: Questie's there)
    if hide then
        if not frame.hidden and type(frame.FakeHide) == "function" then
            frame:FakeHide()
            frame.moHeld = true
        end
    elseif frame.moHeld then
        frame.moHeld = nil
        if frame.hidden and type(frame.FakeShow) == "function" then frame:FakeShow() end
    end
end

-- every icon of the synced kinds (a few hundred at most: on a change, and once a second with the world map open)
local function Apply()
    local qm = QuestieMap()
    local frames = qm and type(qm.manualFrames) == "table" and qm.manualFrames
    if not frames then return end
    local hide = HideNow()
    for key in pairs(SYNCED) do
        for _, names in pairs(type(frames[key]) == "table" and frames[key] or {}) do
            for _, name in ipairs(type(names) == "table" and names or {}) do Hold(_G[name], hide) end
        end
    end
end

---------------------------------------------------------------------------
-- The two menus in step
---------------------------------------------------------------------------
local last = {} -- [i] = the state both had at the last look
local function Sync()
    if not On() then return end
    local cfg, mod = QuestieCfg(), OpenMapMod()
    if not (cfg and mod) then return end
    local om = mod.db.townsfolk
    local qChanged, oChanged = false, false
    for i, p in ipairs(PAIRS) do
        local q, o, was = cfg[p[1]] == true, om[p[2]] == true, last[i]
        local want
        if was == nil then want = q or o            -- (first look: what either had on)
        elseif q ~= was and o == was then want = q  -- (ticked in Questie's menu)
        elseif o ~= was and q == was then want = o  -- (ticked in OpenMap's)
        else want = q or o end
        if q ~= want then cfg[p[1]] = want; qChanged = true end
        if o ~= want then om[p[2]] = want; oChanged = true end
        last[i] = want
    end
    if oChanged and type(mod.RefreshTownsfolk) == "function" then pcall(mod.RefreshTownsfolk, mod) end
    if qChanged then
        local menu = S.QuestieModule("QuestieMenu")
        if menu and menu.OnLogin then pcall(menu.OnLogin, menu, true) end -- (Questie draws them anew from its settings)
    end
    if qChanged or oChanged then Apply() end
end

-- turned on or off ("Town NPC icons"): in step from what both have now, or Questie's icons all given back
local function Changed()
    last = {}
    Check("syncing the townsfolk menus", pcall(Sync))
    Check("syncing the townsfolk menus", pcall(Apply))
end

---------------------------------------------------------------------------
-- Watching
---------------------------------------------------------------------------
local function Hook()
    local qm = QuestieMap()
    if qm and type(qm.DrawManualIcon) == "function" and hooksecurefunc then
        -- a new icon of a synced kind (Questie draws them a few dozen a frame): its world map one held back at once
        hooksecurefunc(qm, "DrawManualIcon", function(_, data, _, _, _, typ)
            if not (typ and SYNCED[typ] and type(data) == "table" and HideNow()) then return end
            local names = qm.manualFrames and qm.manualFrames[typ] and qm.manualFrames[typ][data.id]
            if type(names) ~= "table" then return end
            for i = math.max(1, #names - 1), #names do Hold(_G[names[i]], true) end
        end)
    end
    local mod = OpenMapMod()
    if mod and type(mod.RefreshTownsfolk) == "function" and hooksecurefunc then
        -- (OpenMap's menu: a kind ticked there refreshes its townsfolk)
        hooksecurefunc(mod, "RefreshTownsfolk", function() Check("syncing the townsfolk menus", pcall(Sync)) end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- (after Questie has drawn its townsfolk: it does a few seconds into the session)
    C_Timer.After(6, function()
        Check("watching the townsfolk menus", pcall(Hook))
        Check("syncing the townsfolk menus", pcall(Sync))
    end)
    -- Questie's menu has nothing to hook (its toggles are its own): looked at once a second - eight settings compared.
    -- With the world map open, Questie's icons there checked too (an icon Questie showed again on its own - explored
    -- ground - held back again; OpenMap's map gone - a fight, a map it doesn't stitch - Questie's given back)
    local wait = 0
    f:SetScript("OnUpdate", function(_, dt)
        wait = wait + dt
        if wait < 1 then return end
        wait = 0
        if not On() then return end
        Check("syncing the townsfolk menus", pcall(Sync))
        local map = _G.WorldMapFrame
        if map and map.IsShown and map:IsShown() then Check("syncing the townsfolk menus", pcall(Apply)) end
    end)
end)

MasterOptions_TownSync = { On = On, Changed = Changed, Sync = Sync, Apply = Apply, PAIRS = PAIRS }
end)
