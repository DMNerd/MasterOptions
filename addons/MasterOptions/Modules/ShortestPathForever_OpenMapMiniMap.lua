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
-- Fix: the goal texture ignores its parent's alpha too, as OpenMap_MiniMap does for child frames. Nothing in
-- either addon is changed. ShortestPathForever makes the frame when its route first draws, so this looks for it
-- once a second until it's there, then stops.

local done = false
local function Apply()
    local route = _G.ShortestPathForeverMinimapRoute
    local goal = type(route) == "table" and route.Goal
    if type(goal) ~= "table" or type(goal.SetIgnoreParentAlpha) ~= "function" then return false end
    local ok, err = pcall(goal.SetIgnoreParentAlpha, goal, true)
    if not ok and _G.MasterOptions_ReportError then MasterOptions_ReportError(ADDON, "keeping the goal visible", err) end
    return true
end

local f = CreateFrame("Frame")
local wait = 0
f:SetScript("OnUpdate", function(self, dt)
    wait = wait + dt
    if wait < 1 then return end
    wait = 0
    if done then return end
    if Apply() then
        done = true
        self:SetScript("OnUpdate", nil)
    end
end)
end)
