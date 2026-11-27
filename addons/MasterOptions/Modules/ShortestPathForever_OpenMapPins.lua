-- Master Options module: runs when ShortestPathForever and OpenMap are loaded.
MasterOptions_Module("ShortestPathForever_OpenMapPins", { "ShortestPathForever", "OpenMap" }, function(ADDON)

-- One trip, one pin: the same way to place and clear a destination, however a trip started.
--
-- A trip is ShortestPathForever's journey (Shift-click on the map, OpenMap's Ctrl-click pin it follows, Dungeon
-- Journal's Show on Map, a waypoint from Questie / Mastercraft / WhatsTraining ...):
--   * it has an OpenMap pin at its destination: OpenMap's own pin there if there is one (Ctrl-click, Dungeon
--     Journal), else one placed for it - gold, its note the journey's title. Every destination shows the same
--     way on the world map and the minimap, in OpenMap's pin list, cleared the same way.
--   * ShortestPathForever's own goal marker is hidden meanwhile (world map, and the minimap while the goal is on
--     it - at the rim it stays: it points the way), so one pin marks the spot. A route's numbered stops stay.
--   * any end clears it - arrived, cleared in ShortestPathForever, stopped in OpenMap, replaced by another
--     journey: the pin goes, and OpenMap stops following it if it still did. A pin you wrote a note on stays
--     (no longer followed): that's a pin you keep.
-- Nothing in either addon is changed: their own settings and functions are used (OpenMap's pin list as Dungeon
-- Journal's pins use it; ShortestPathForever.API Journey / Ended / Subscribe).

local Shared = MasterOptions_Shared
local _, Check = Shared.ErrorReporters(ADDON)
local OPENMAP_OWNER = "OpenMap:Pin" -- (ShortestPathForever's owner for OpenMap's handoff: UI\OpenMap.lua's PinOwner)
local GOLD = 1                       -- (OpenMap's pin colours: 1 gold, 2 red, 3 green, 4 blue, 5 purple)
local FROM = "Master Options"        -- (a trip pin's `from`: OpenMap shows where a pin came from)
local Pins = Shared.OpenMapPins      -- (OpenMap's pin list, as every module of ours uses it)
local WorldMap, Near = Pins.Module, Pins.Near

local function API()
    local spf = _G.ShortestPathForever
    local api = type(spf) == "table" and spf.API
    if type(api) == "table" and type(api.Subscribe) == "function" and type(api.Journey) == "function"
        and type(api.Ended) == "function" then return api end
end

-- the pins placed for trips (saved: after a reload a trip still has its pin, and a leftover one is cleaned up)
local function Ours()
    MasterOptionsDB = MasterOptionsDB or {}
    MasterOptionsDB.tripPins = type(MasterOptionsDB.tripPins) == "table" and MasterOptionsDB.tripPins or {}
    return MasterOptionsDB.tripPins
end
Pins.OnRemove(function(id) Ours()[id] = nil end) -- (removed by any module of ours: no longer a trip pin)

-- a note you wrote: not empty, and not the one an addon (or we) gave the pin
local function YourNote(p)
    local note = type(p.note) == "string" and p.note or ""
    if note == "" then return false end
    local ours = Ours()[p.id]
    if ours ~= nil then return note ~= ours end
    return p.from == nil
end

---------------------------------------------------------------------------
-- The trip under way: { key, owner, map, x, y, pin, multi }
---------------------------------------------------------------------------
local trip

local RemovePin = Pins.Remove -- (out of OpenMap's list and every module's record - Dungeon Journal's too)

local function Followed(p)
    local m, x, y = Shared.OpenMapFollowed()
    return p and m == p.map and Near(x, p.x) and Near(y, p.y)
end

local function EndTrip(t)
    local mod = WorldMap()
    if not mod then return end
    local p = t.pin
    -- OpenMap stops following it - only if it still follows this spot (a new pin it follows now stays followed)
    if Followed(p) and type(mod.ClearPin) == "function" then mod.ClearPin() end
    if p and not YourNote(p) then RemovePin(mod, p) end
    if mod.RefreshPins then pcall(mod.RefreshPins) end
end

local function StartTrip(t, title)
    local mod = WorldMap()
    if not mod then return end
    local p = Pins.Find(mod, t.map, t.x, t.y)
    if not p then
        local note = Pins.Note(title or "Journey")
        if note == "" then note = "Journey" end
        p = Pins.Add(mod, t.map, t.x, t.y, note, GOLD, FROM)
        Ours()[p.id] = p.note
    end
    t.pin = p
end

local HideGoals -- (below)

local function Changed()
    local api = API()
    if not api then return end
    local j, why = api.Journey()
    if j == nil and why ~= "none" then return end -- (loading, or no answer yet: nothing has changed)
    local goal = j and type(j.goal) == "table" and j.goal
    local now
    if goal and j.owner and type(goal.map) == "number" and type(goal.x) == "number" and type(goal.y) == "number" then
        now = { key = ("%s|%d|%.4f|%.4f"):format(j.owner, goal.map, goal.x, goal.y), owner = j.owner,
                map = goal.map, x = goal.x, y = goal.y }
    end
    -- (a corpse run has no owner: not a trip of yours - the one waiting behind it keeps its pin)
    if j and not j.owner and trip then return end
    -- the same spot, another owner (you clicked the trip's pin in OpenMap and it follows it now; a guide handing over):
    -- the same trip, its pin kept - ending it would stop OpenMap following the spot it just took
    if now and trip and now.key ~= trip.key and now.map == trip.map and Near(now.x, trip.x) and Near(now.y, trip.y) then
        trip.key, trip.owner = now.key, now.owner
        HideGoals()
        return
    end
    if trip and (not now or now.key ~= trip.key) then
        local t = trip
        trip = nil
        EndTrip(t)
    end
    if now and not trip then
        trip = now
        StartTrip(trip, goal.title)
    end
    HideGoals()
end

-- After a reload: a trip pin of ours that no journey leads to any more (it ended while we weren't looking) goes
local function Tidy()
    local mod = WorldMap()
    if not mod then return end
    local changed = false
    for i = #mod.db.pins.list, 1, -1 do
        local p = mod.db.pins.list[i]
        if Ours()[p.id] ~= nil and p ~= (trip and trip.pin) and not YourNote(p) then
            RemovePin(mod, p)
            changed = true
        end
    end
    for id in pairs(Ours()) do
        local there = false
        for _, p in ipairs(mod.db.pins.list) do if p.id == id then there = true break end end
        if not there then Ours()[id] = nil end
    end
    if changed and mod.RefreshPins then pcall(mod.RefreshPins) end
end

---------------------------------------------------------------------------
-- ShortestPathForever's goal marker hidden while the trip's OpenMap pin marks the spot
---------------------------------------------------------------------------
-- asked every frame the minimap goal is shown: the answer kept for half a second (and worked out again whenever the
-- trip changes - HideGoals)
local marks, marksAt = false, -1
local function PinMarks()
    local now = GetTime and GetTime() or 0
    if now ~= 0 and marksAt >= 0 and now - marksAt < 0.5 then return marks end
    marksAt = now
    marks = false
    if trip and trip.pin then
        local mod = WorldMap()
        if mod then
            for _, p in ipairs(mod.db.pins.list) do if p == trip.pin then marks = true break end end
        end
    end
    return marks
end

-- the minimap: its goal texture (UI\Route.lua: ShortestPathForeverMinimapRoute.Goal), shown every frame it's on
-- the map; at the rim it only points the way, and stays. Which is which: route.goalEdge until 1.49; since 1.49.1 that
-- is a local of its drawing, which shows the goal at the rim faded (EDGE_ALPHA 0.6) and on the map at full alpha
local goalHooked
local function AtRim(goal, route)
    if route.goalEdge ~= nil then return route.goalEdge == true end
    return type(goal.GetAlpha) == "function" and goal:GetAlpha() < 0.99
end
local function MinimapGoal()
    local route = _G.ShortestPathForeverMinimapRoute
    local goal = type(route) == "table" and route.Goal
    if type(goal) ~= "table" or type(goal.Hide) ~= "function" then return nil end
    if not goalHooked and hooksecurefunc then
        goalHooked = true
        hooksecurefunc(goal, "Show", function(self)
            if PinMarks() and not AtRim(self, route) then self:Hide() end
        end)
    end
    return goal, route
end

-- the world map: its goal pins (UI\StopPin.lua's GoalPin: pressRegions, SetStopAlpha), on the map's canvas; a lone
-- destination's (no stop numbers) - a route's numbered stops stay
local hookedPins = setmetatable({}, { __mode = "k" })
local function IsGoalPin(f)
    return type(f) == "table" and type(f.pressRegions) == "table" and type(f.SetStopAlpha) == "function"
end
local function HideIfMarked(f)
    if PinMarks() and not f.stopNumbers then f:Hide() end
end
local function WorldGoals()
    local map = _G.WorldMapFrame
    local canvas = map and map.GetCanvas and map:GetCanvas()
    if not (canvas and canvas.GetChildren) then return end
    for _, f in ipairs({ canvas:GetChildren() }) do
        if IsGoalPin(f) then
            if not hookedPins[f] and hooksecurefunc then
                hookedPins[f] = true
                hooksecurefunc(f, "Show", HideIfMarked)
                if f.SetShown then hooksecurefunc(f, "SetShown", function(self, on) if on then HideIfMarked(self) end end) end
            end
            if f:IsShown() then HideIfMarked(f) end
        end
    end
end

HideGoals = function()
    marksAt = -1 -- (the trip changed)
    local goal, route = MinimapGoal()
    if goal and PinMarks() and not AtRim(goal, route) then goal:Hide() end
    if _G.WorldMapFrame and WorldMapFrame:IsShown() then WorldGoals() end
end

---------------------------------------------------------------------------
-- Watching
---------------------------------------------------------------------------
local subscribed = false
local function Subscribe()
    if subscribed then return true end
    local api = API()
    if not api then return false end
    subscribed = true
    api.Subscribe(function() Check("keeping the trip's pin", pcall(Changed)) end)
    Check("keeping the trip's pin", pcall(Changed))
    Check("tidying trip pins", pcall(Tidy))
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    Shared.WatchOpenMapFollow()
    if not Subscribe() then C_Timer.After(3, Subscribe) end
    -- the world map: its goal pins are made as it opens and as you zoom - looked at while it's open. A pin found once
    -- hides itself (its Show is hooked): later, only when the canvas has new frames (every map pin is one, Questie's
    -- too - no list of them all built twice a second)
    local map = _G.WorldMapFrame
    if map and map.HookScript then
        local wait, seen = 0, -1
        map:HookScript("OnShow", function() seen = -1; Check("hiding the journey's goal pin", pcall(WorldGoals)) end)
        map:HookScript("OnUpdate", function(_, dt)
            wait = wait + dt
            if wait < 0.5 then return end
            wait = 0
            if not PinMarks() then return end
            local canvas = map.GetCanvas and map:GetCanvas()
            local n = canvas and canvas.GetNumChildren and canvas:GetNumChildren() or 0
            if n ~= seen then
                seen = n
                Check("hiding the journey's goal pin", pcall(WorldGoals))
            end
        end)
    end
end)

end)
