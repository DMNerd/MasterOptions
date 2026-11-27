-- Master Options module: runs when ForeverDungeonJournal and Spoken_Bosses are loaded.
MasterOptions_Module("DungeonJournal_SpokenBosses", { "ForeverDungeonJournal", "Spoken_Bosses" }, function(ADDON)

-- Dungeon Journal's world-map dungeon view -> Spoken_Bosses' stories.
--
-- Spoken_Bosses tells a dungeon's story beside the world map when OpenMap or Leatrix Maps shows that dungeon,
-- and a boss's when you click it there. Dungeon Journal's own map on the world map (its "Show on world map",
-- and Master Options' Map inside dungeons / Dungeon entrance click) it doesn't know. This tells it: the
-- dungeon's story when Dungeon Journal's map goes up on the world map, a boss's when you click the boss there,
-- and the story goes when the map does (only one this showed).
--
-- Hooks (all post-hooks, looked up on Dungeon Journal's table each time):
--   FDJ.SetMapDungeon(name)        - every dungeon map it draws names its dungeon (wings: "Stratholme: Living")
--   FDJ.RefreshWorldMapOverlay()   - afterwards, FDJ.IsWorldMapOverlayAttached(): on the world map or not
--   FDJ.OpenBossFromWorldMap(dungeon, index) - a boss clicked on that map (FDJ.DB[dungeon].bosses[index].name)
-- Spoken_Bosses: SpokenBossesAddon.MapLore (ShowDungeon, ShowBoss, ClearStory, BossByName...), the helper its
-- own OpenMap and Leatrix bridges use - not part of Spoken's public API, so every call is guarded.

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)

local function Lore()
    local b = _G.SpokenBossesAddon
    local m = type(b) == "table" and b.MapLore
    if type(m) == "table" and type(m.ShowDungeon) == "function" and type(m.ClearStory) == "function" then return m end
end

-- Dungeon Journal's names -> Spoken's (English) where they differ
local ALIAS = {
    ["the stockade"] = "stormwind stockade",
    ["upper blackrock spire"] = "blackrock spire",
    ["lower blackrock spire"] = "blackrock spire",
    ["shaper's terrace"] = "the shaper's terrace",
}
local function Plain(name) return (tostring(name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")) end

-- Spoken's instance for one of Dungeon Journal's dungeons: by its English name (Spoken's [1]; Dungeon
-- Journal's keys are English on every client), without "The", or without the wing (": Living")
local byName
local function InstanceOf(key)
    if not byName then
        byName = {}
        local d = _G.SpokenDungeons
        for id, dungeon in pairs(type(d) == "table" and type(d.dungeons) == "table" and d.dungeons or {}) do
            if type(dungeon) == "table" and type(dungeon[1]) == "string" then
                local p = Plain(dungeon[1])
                byName[p] = id
                byName[(p:gsub("^the ", ""))] = byName[(p:gsub("^the ", ""))] or id
            end
        end
    end
    local p = Plain(key)
    local id = byName[p] or byName[ALIAS[p] or ""] or byName[(p:gsub("^the ", ""))] or byName[(p:gsub("%s*:.*$", ""))]
    if id then return id end
    local m = Lore()
    return m and type(m.DungeonInstanceByName) == "function" and m.DungeonInstanceByName(key) or nil
end

local FDJ
local drawn   -- the dungeon Dungeon Journal's map last drew
local shownID -- the instance whose story we put up (nil: none of ours is up)

local last    -- the last try, for /mo story: { drawn, id, mapID, shown }

local function MapID(m) return type(m.CurrentMapID) == "function" and m.CurrentMapID() or nil end

local shownBoss -- the boss whose story we put up after it ({ map, key, boss }), else nil: the dungeon's

local function Clear()
    shownBoss = nil
    if not shownID then return end
    shownID = nil
    local m = Lore()
    if m then m.ClearStory() end
end

local function Refreshed()
    if not (FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached()) then return Clear() end
    local id = drawn and InstanceOf(drawn)
    if id == shownID then return end -- (same dungeon: a boss's story stays)
    Clear()
    local m, mapID = Lore(), nil
    if m then mapID = MapID(m) end
    local shown = id and mapID and m.ShowDungeon(mapID, id) or false
    last = { drawn = drawn, id = id, mapID = mapID, shown = shown }
    if shown then shownID = id end
end

local function BossOpened(dungeon, index)
    local m = Lore()
    if not (m and FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached()) then return end
    local entry = FDJ.DB and FDJ.DB[dungeon]
    local boss = type(entry) == "table" and type(entry.bosses) == "table" and entry.bosses[index]
    local id = InstanceOf(dungeon)
    if not (type(boss) == "table" and boss.name and id and type(m.BossByName) == "function") then return end
    local key = type(m.BossNameKey) == "function" and m.BossNameKey(boss.name) or boss.name
    local found = m.BossByName(key, function(map) return map == id end)
    local mapID = MapID(m)
    if found and mapID and type(m.ShowBoss) == "function" and m.ShowBoss(mapID, found) then
        shownID, shownBoss = id, found
    end
end

-- Spoken picked a place while Dungeon Journal's map is up: what we last showed (the boss's story, else the
-- dungeon's) goes back
local function ShowAgain()
    if not (FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached()) then return end
    local m = Lore()
    local mapID = m and MapID(m)
    if shownBoss and mapID and type(m.ShowBoss) == "function" and m.ShowBoss(mapID, shownBoss) then return end
    shownID, shownBoss = nil, nil
    Refreshed()
end

local hooked = false
local function Hook()
    if hooked then return true end
    FDJ = _G.ForeverDungeonJournal_NS
    if not (type(FDJ) == "table" and type(FDJ.RefreshWorldMapOverlay) == "function") then return false end
    hooked = true
    if type(FDJ.SetMapDungeon) == "function" then
        hooksecurefunc(FDJ, "SetMapDungeon", function(name) drawn = name end)
    end
    hooksecurefunc(FDJ, "RefreshWorldMapOverlay", function() Check("showing the dungeon's story", pcall(Refreshed)) end)
    if type(FDJ.OpenBossFromWorldMap) == "function" then
        hooksecurefunc(FDJ, "OpenBossFromWorldMap", function(dungeon, index)
            Check("showing the boss's story", pcall(BossOpened, dungeon, index))
        end)
    end
    if WorldMapFrame and WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnHide", function() Check("clearing the story", pcall(Clear)) end)
    end
    -- Spoken Places drops a story put up from outside on every change to another map (its panel then shows that
    -- map's own). Dungeon Journal moves the map about while it opens a dungeon, so the story we showed was gone
    -- while we still counted it as up - and "same dungeon" never put it back. After a map change: forgotten, and
    -- shown again (a moment later, after Spoken's own refresh) while Dungeon Journal's map is still up.
    -- On OpenMap's map a click anywhere in a zone picks that zone's story (Spoken Places' SelectMap / SelectSubzone,
    -- from its map-click handler) - the entrance click that opened this map is one, and so is any click on Dungeon
    -- Journal's map, which covers the zone. Its pick drops our story: while that map is up, ours goes back after it.
    local sp = _G.SpokenPlaces
    for _, fn in ipairs({ "SelectMap", "SelectSubzone" }) do
        if type(sp) == "table" and type(sp[fn]) == "function" then
            hooksecurefunc(sp, fn, function()
                if not (FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached()) then return end
                C_Timer.After(0, function() Check("showing the dungeon's story", pcall(ShowAgain)) end)
            end)
        end
    end
    if WorldMapFrame and type(WorldMapFrame.OnMapChanged) == "function" then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            shownID, shownBoss = nil, nil
            C_Timer.After(0, function() Check("showing the dungeon's story", pcall(Refreshed)) end)
        end)
    end
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not Hook() then C_Timer.After(2, Hook) end
end)

-- /mo story: what happened the last time Dungeon Journal's map went up, step by step
local function Explain()
    local head = "|cffffd200Master Options:|r "
    local sp = _G.SpokenPlaces
    print(head .. ("Dungeon Journal's map on the world map: %s; Spoken's story helper: %s; Spoken's panel: %s."):format(
        (FDJ and FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached()) and "up" or "not up",
        Lore() and "found" or "MISSING",
        (type(sp) == "table" and sp.IsMapPanelOpen and sp:IsMapPanelOpen()) and "open" or "closed"))
    if not last then print(head .. "no dungeon map has gone up since the last reload.") return end
    print(head .. ("last try: dungeon %s -> Spoken's instance %s, on map %s -> %s."):format(tostring(last.drawn),
        tostring(last.id or "NOT FOUND"), tostring(last.mapID), last.shown and "story shown" or "Spoken showed nothing"))
    if type(sp) == "table" and sp.selected then
        print(head .. "Spoken has a place picked now (that replaces an outside story): map " .. tostring(sp.selected.mapID)
            .. (sp.selected.areaName and (", " .. sp.selected.areaName) or ""))
    end
end

MasterOptions_DJSpoken = { InstanceOf = InstanceOf, Explain = Explain } -- (for the tests)
MasterOptions_Shared.Command("story", Explain, "story - why a dungeon's story did or didn't show beside the world map")
end)
