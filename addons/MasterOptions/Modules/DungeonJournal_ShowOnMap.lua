-- Master Options module: runs when ForeverDungeonJournal and OpenMap are loaded.
MasterOptions_Module("DungeonJournal_ShowOnMap", { "ForeverDungeonJournal", "OpenMap" }, function(ADDON)

-- Dungeon Journal's Show on Map -> an OpenMap pin.
--
-- Dungeon Journal's "Show on Map" (quest givers, turn-ins, dungeon entrances, objectives...) marks the spot
-- with its own marker on the world map. This also puts an OpenMap pin there - blue, its note the Journal's
-- name for the spot - so it is in OpenMap's pin list, on OpenMap's map and minimap, and followed (Blizzard's
-- waypoint and arrow, TomTom's) the way a pin you drop is (OpenMap's "follow new pins" setting decides).
-- When Dungeon Journal removes its mark (right-click, or by itself once the quest is picked up or handed in)
-- the pin goes too. Pins you dropped yourself, or kept by editing the note, are never removed.
-- (Until 2.13.0 part of DungeonJournal_OpenMap, which keeps the map inside dungeons and the entrance clicks.)
--
-- Hooks: every Show on Map ends in ForeverDungeonJournal_NS.SetWaypointArrow(spot), and every removed mark
-- in .ClearWaypointArrow(spot) - both looked up on its table each time, so post-hooks see them all.
-- Pins go straight into OpenMap's pin list (OpenMapDB: worldmap -> pins), in OpenMap's own format.

local S = MasterOptions_Shared
local _, Check = S.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local BLUE = 4                -- OpenMap's pin colours: 1 gold, 2 red, 3 green, 4 blue, 5 purple
local NOTE_MAX = 160
local DB                       -- MasterOptions_DJOpenMapDB: { ours = { [pin id] = true } } (ShortestPathForever_OpenMapPins reads it)

local function WorldMap()
    local mod = S.OpenMapWorldMap()
    if mod and mod.db and type(mod.db.pins) == "table" and type(mod.db.pins.list) == "table" then return mod end
end

local function Round(v) return math.floor(v * 1e4 + 0.5) / 1e4 end

local function Note(spot)
    local text = spot.label or spot.questTitle or ""
    if spot.questTitle and spot.label and spot.questTitle ~= spot.label then text = spot.label .. " (" .. spot.questTitle .. ")" end
    text = ("Dungeon Journal: " .. tostring(text)):gsub("%c", " "):gsub("|", "/")
    text = text:gsub("%s*\226\128\148%s*", " - "):gsub("%s*\226\128\147%s*", " - ") -- (long dashes: " - ")
    if #text > NOTE_MAX then text = text:sub(1, NOTE_MAX):gsub("[\192-\255][\128-\191]*$", "") end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Spot(spot)
    if type(spot) ~= "table" then return end
    local mapID, x, y = tonumber(spot.mapID), tonumber(spot.x), tonumber(spot.y)
    if not (mapID and x and y) or x < 0 or x > 1 or y < 0 or y > 1 then return end
    return mapID, x, y
end

local function Shown(spot)
    local mod = WorldMap()
    local mapID, x, y = Spot(spot)
    if not (mod and mapID) then return end
    local pins = mod.db.pins
    local p = mod.PinAt and mod.PinAt(mapID, x, y)
    if not p then
        if mod.db.pinsHidden and mod.SetPinsHidden then pcall(mod.SetPinsHidden, false) end -- (else it would be out of sight)
        pins.nextId = pins.nextId or 1
        p = { id = pins.nextId, map = mapID, x = Round(x), y = Round(y), note = Note(spot), color = BLUE,
              from = "Dungeon Journal", at = time() }
        pins.nextId = pins.nextId + 1
        table.insert(pins.list, p)
        DB.ours[p.id] = true
    end
    if mod.db.pinsFollowNew ~= false and mod.TrackPoint then pcall(mod.TrackPoint, p.map, p.x, p.y, p.note) end
    if mod.RefreshPins then pcall(mod.RefreshPins) end
end

local function Cleared(spot)
    local mod = WorldMap()
    local mapID, x, y = Spot(spot)
    if not (mod and mapID) then return end
    local p = mod.PinAt and mod.PinAt(mapID, x, y)
    if not (p and DB.ours[p.id]) then return end
    -- kept: you wrote your own note on it
    if p.note ~= Note(spot) then DB.ours[p.id] = nil return end
    -- still followed: no longer (by the spot OpenMap was told to follow - ShortestPathForever's journey moves the
    -- game's waypoint along the way, so that alone missed it)
    if mod.ClearPin and S.OpenMapFollows(p.map, p.x, p.y) then pcall(mod.ClearPin) end
    local list = mod.db.pins.list
    for i = #list, 1, -1 do if list[i] == p then table.remove(list, i) end end
    DB.ours[p.id] = nil
    if mod.RefreshPins then pcall(mod.RefreshPins) end
end

local hooked = false
local function Hook()
    if hooked then return true end
    local fdj = _G.ForeverDungeonJournal_NS
    if not (type(fdj) == "table" and type(fdj.SetWaypointArrow) == "function") then return false end
    hooksecurefunc(fdj, "SetWaypointArrow", function(spot) Check("adding the OpenMap pin", pcall(Shown, spot)) end)
    if type(fdj.ClearWaypointArrow) == "function" then
        hooksecurefunc(fdj, "ClearWaypointArrow", function(spot) Check("removing the OpenMap pin", pcall(Cleared, spot)) end)
    end
    hooked = true
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            MasterOptions_DJOpenMapDB = MasterOptions_DJOpenMapDB or {}
            DB = MasterOptions_DJOpenMapDB
            DB.ours = DB.ours or {}
        end
    elseif event == "PLAYER_LOGIN" then
        -- (Dungeon Journal sets its arrow functions up as it loads; again a moment later to be sure)
        if not Hook() then C_Timer.After(2, Hook) end
        S.WatchOpenMapFollow()
    end
end)

S.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
