-- Master Options module: runs when ShortestPathForever and OpenMap are loaded.
MasterOptions_Module("ShortestPathForever_OpenMapPins", { "ShortestPathForever", "OpenMap" }, function(ADDON)

-- ShortestPathForever -> OpenMap: clearing the journey to an OpenMap pin clears the pin.
--
-- A followed OpenMap pin is handed to ShortestPathForever (OpenMap's TomTom handoff: SPF's journey owner
-- "OpenMap:Pin"). Stopping it in OpenMap ends the journey; but clearing the journey in ShortestPathForever (its
-- tracker's clear button) left OpenMap following the pin, and the pin on the map (a player's report). Now, when
-- that journey ends because you cleared it (SPF's API.Ended reason "cleared" - not "cancelled", which is OpenMap's
-- own stop, nor arriving or another journey replacing it), OpenMap stops following the spot (its ClearPin), and the
-- map pin there goes too - unless you wrote a note on it (a pin you keep: it's only no longer followed).
--
-- Read: ShortestPathForever.API (Subscribe, Ended), OpenMap's worldmap module (WaypointPoint, PinAt, ClearPin,
-- db.pins.list, RefreshPins, DropSketches). The pin: the spot OpenMap was told to follow (Shared.OpenMapFollowed, a
-- hook on its TrackPoint) - the journey moves the game's waypoint along the way, so that alone can miss it.

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)
local OWNER = "OpenMap:Pin" -- (ShortestPathForever's owner for OpenMap's handoff: UI\OpenMap.lua's PinOwner)

local function API()
    local spf = _G.ShortestPathForever
    local api = type(spf) == "table" and spf.API
    if type(api) == "table" and type(api.Subscribe) == "function" and type(api.Ended) == "function" then return api end
end

local Shared = MasterOptions_Shared
local function WorldMap()
    local mod = Shared.OpenMapWorldMap()
    if mod and type(mod.ClearPin) == "function" and type(mod.WaypointPoint) == "function" then return mod end
end

-- a note you wrote (not empty, not one an addon wrote for its own pin)
local function YourNote(p)
    local note = type(p.note) == "string" and p.note or ""
    return note ~= "" and p.from == nil
end

local function ClearOpenMapPin()
    local mod = WorldMap()
    if not mod then return end
    -- the spot OpenMap was told to follow (the journey moved the game's waypoint along the way)
    local mapID, x, y = Shared.OpenMapFollowed()
    if not mapID then return end -- (OpenMap follows nothing: nothing to clear)
    local p = mod.PinAt and mod.PinAt(mapID, x, y)
    mod.ClearPin()
    local list = p and type(mod.db) == "table" and type(mod.db.pins) == "table" and mod.db.pins.list
    if type(list) == "table" and not YourNote(p) then
        for i = #list, 1, -1 do if list[i] == p then table.remove(list, i) end end
        if mod.DropSketches and p.id then pcall(mod.DropSketches, p.id) end
        -- (Dungeon Journal's pins: Master Options' own record of it goes too)
        local dj = _G.MasterOptions_DJOpenMapDB
        if type(dj) == "table" and type(dj.ours) == "table" and p.id then dj.ours[p.id] = nil end
    end
    if mod.RefreshPins then pcall(mod.RefreshPins) end
end

local seen -- (the time of the last end we looked at: each end handled once)
local function Changed()
    local api = API()
    if not api then return end
    local reason, at = api.Ended(OWNER)
    if not at or at == seen then return end
    seen = at
    if reason == "cleared" then ClearOpenMapPin() end
end

local subscribed = false
local function Subscribe()
    if subscribed then return true end
    local api = API()
    if not api then return false end
    local _, at = api.Ended(OWNER)
    seen = at -- (one from before we listened: not ours to act on)
    subscribed = true
    api.Subscribe(function() Check("clearing the OpenMap pin", pcall(Changed)) end)
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not Subscribe() then C_Timer.After(3, Subscribe) end
    Shared.WatchOpenMapFollow()
end)

MasterOptions_SPFOpenMapPins = { Changed = Changed } -- (for the tests)
end)
