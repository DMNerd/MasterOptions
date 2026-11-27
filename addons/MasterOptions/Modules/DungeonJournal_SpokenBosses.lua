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

local function MapID(m) return type(m.CurrentMapID) == "function" and m.CurrentMapID() or nil end

local function Clear()
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
    if id and mapID and m.ShowDungeon(mapID, id) then shownID = id end
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
    if found and mapID and type(m.ShowBoss) == "function" and m.ShowBoss(mapID, found) then shownID = id end
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
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not Hook() then C_Timer.After(2, Hook) end
end)

MasterOptions_DJSpoken = { InstanceOf = InstanceOf } -- (for the tests)
end)
