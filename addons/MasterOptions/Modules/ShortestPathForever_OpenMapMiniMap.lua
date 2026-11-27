-- Master Options module: runs when ShortestPathForever and OpenMap_MiniMap are loaded.
MasterOptions_Module("ShortestPathForever_OpenMapMiniMap", { "ShortestPathForever", "OpenMap_MiniMap" }, function(ADDON)

-- ShortestPathForever <-> OpenMap_MiniMap compatibility patch.
--
-- Problem: OpenMap_MiniMap paints its own map under the minimap and fades the game's terrain with
-- Minimap:SetAlpha (down to 0 at far zoom). It keeps other addons' minimap frames visible (Frame.ScanOthers:
-- SetIgnoreParentAlpha on each child frame of Minimap) - but ShortestPathForever's journey goal on the minimap
-- is a texture made on Minimap itself (UI\Route.lua: ShortestPathForeverMinimapRoute.Goal =
-- Minimap:CreateTexture), not a child frame, so it fades with the terrain and is gone at far zoom. Its route
-- line and transport pins are child frames and stay visible already.
--
-- Fix: the goal texture ignores its parent's alpha too, as OpenMap_MiniMap does for child frames - and follows the
-- route frame when OpenMap_MiniMap hides it again (while you drag the map to look round it sets the route frame
-- back to the terrain's alpha; the goal stayed, collapsed onto your arrow). Nothing in either addon is changed.
-- ShortestPathForever makes the frame when its route first draws: looked for at login and whenever a journey changes
-- (its API's Subscribe), until it's there - once a second only where that API is missing.

local Report = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)
local done = false
local function Apply()
    local route = _G.ShortestPathForeverMinimapRoute
    local goal = type(route) == "table" and route.Goal
    if type(goal) ~= "table" or type(goal.SetIgnoreParentAlpha) ~= "function" then return false end
    local ok, err = pcall(goal.SetIgnoreParentAlpha, goal, true)
    if not ok then Report("keeping the goal visible", err) end
    -- (the route frame's own setting, as OpenMap_MiniMap sets it: visible over the faded terrain, or hidden while
    -- the map is dragged)
    if type(route.SetIgnoreParentAlpha) == "function" and hooksecurefunc then
        hooksecurefunc(route, "SetIgnoreParentAlpha", function(_, on)
            pcall(goal.SetIgnoreParentAlpha, goal, on and true or false)
        end)
    end
    return true
end

local function Try() if not done then done = Apply() end end

local f = CreateFrame("Frame")
local function Poll()
    local wait = 0
    f:SetScript("OnUpdate", function(self, dt)
        wait = wait + dt
        if wait < 1 then return end
        wait = 0
        Try()
        if done then self:SetScript("OnUpdate", nil) end
    end)
end

local spf = _G.ShortestPathForever
local api = type(spf) == "table" and spf.API
if type(api) == "table" and type(api.Subscribe) == "function" then
    api.Subscribe(function() pcall(Try) end) -- (a journey starts: its route draws, the goal is made)
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() C_Timer.After(1, Try) end)
else
    Poll()
end
end)
