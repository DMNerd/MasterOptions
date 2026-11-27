-- Master Options module: runs when Mastercraft and ShortestPathForever are loaded.
MasterOptions_Module("Mastercraft_FarmTour", { "Mastercraft", "ShortestPathForever" }, function(ADDON)

-- Mastercraft -> ShortestPathForever: a walking tour of the zone's gathering nodes when you farm.
--
-- ShortestPathForever walks farming tours, but only through GatherMate2's recorded nodes - without GatherMate2
-- its tour does nothing. Mastercraft remembers every herb and vein you gather (MastercraftDB.nodes, by zone map;
-- GatherMate2's too once imported). So when you start farming in Mastercraft (its farm session: /mc farm or its
-- button), this hands ShortestPathForever a walking tour of this zone's nodes worth it to you, nearest first,
-- and ends it when you stop. "/mo farm" starts one without a Mastercraft session ("/mo farm herbs", "ores",
-- "stop"). A new zone while farming: its tour.
--
-- Worth it = Mastercraft's own rule (Settings > Nodes > Which nodes: skill-ups, all you can gather, or all; its
-- map switch per profession; professions you have), by the skill each node needs: from the herb or ore it gave
-- (SKILL_BY_ITEM, the game's fixed values). A node whose item isn't in the list counts, as in Mastercraft.
-- Imported GatherMate2 nodes carry no item, so they're in a tour only with "all".
-- Mastercraft and ShortestPathForever are only read (MastercraftDB, ShortestPathForever.API).

local Shared = MasterOptions_Shared
local Report = Shared.ErrorReporters(ADDON)
local HERB, MINE = Shared.HERB, Shared.MINE
local OWNER = "Master Options"
local MAX_STOPS = 64 -- (ShortestPathForever's limit for one route)

local SL_OF = { Mining = MINE, Herbalism = HERB }
local SKILL_BY_ITEM = {
    -- ores (and the stones veins give)
    [2770] = 1, [2771] = 65, [3340] = 65, [2775] = 75, [4278] = 75, [2772] = 125, [5833] = 150, [2776] = 155,
    [3858] = 175, [7911] = 230, [11370] = 230, [10620] = 245,
    -- herbs
    [2447] = 1, [765] = 1, [2449] = 15, [785] = 50, [2452] = 50, [2450] = 70, [3820] = 85, [2453] = 100,
    [3355] = 115, [3369] = 120, [3356] = 125, [3357] = 150, [3818] = 160, [3821] = 170, [3358] = 185,
    [3819] = 195, [4625] = 205, [8831] = 210, [8836] = 220, [8838] = 230, [8839] = 235, [8845] = 245,
    [8846] = 250, [13464] = 260, [13463] = 270, [13465] = 280, [13466] = 285, [13467] = 290, [13468] = 300,
}
local RICH_THORIUM = 275 -- (its vein gives Thorium Ore too: known by its name)

local function Print(text) print("|cffffd200Master Options:|r " .. text) end
local MC = Shared.MastercraftDB
local function API()
    local spf = _G.ShortestPathForever
    local api = type(spf) == "table" and spf.API
    return type(api) == "table" and type(api.NavigateRoute) == "function" and api or nil
end

-- the zone a map belongs to (Mastercraft keeps a zone's nodes together on its zone map)
local function Zone(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    while info and info.mapType and info.mapType > 3 and info.parentMapID and info.parentMapID > 0 do
        mapID = info.parentMapID
        info = C_Map.GetMapInfo(mapID)
    end
    return mapID
end

local function NodeSkill(node)
    if type(node.n) == "string" and node.n:find("Rich Thorium", 1, true) then return RICH_THORIUM end
    return node.i and SKILL_BY_ITEM[node.i] or nil
end

-- this zone's nodes worth it: { { x, y, title }, ... }, the zone's map, and its name
local function Candidates(only)
    local db = MC()
    local mapID = Zone(C_Map.GetBestMapForUnit("player"))
    if not (db and mapID) then return {}, mapID end
    local s = type(db.settings) == "table" and db.settings or {}
    local filter = s.nodesFilter or "skillups"
    local switch = type(s.nodes) == "table" and s.nodes or {}
    local ranks = Shared.GatheringRanks()
    local out = {}
    for _, node in ipairs(type(db.nodes) == "table" and db.nodes[mapID] or {}) do
        local sl = SL_OF[node.p]
        if sl and ranks[sl] and switch[node.p] ~= false and (not only or only == sl)
            and type(node.x) == "number" and type(node.y) == "number"
            and Shared.GatherWanted(filter, ranks[sl], NodeSkill(node)) then
            out[#out + 1] = { x = node.x, y = node.y, title = node.n or (sl == HERB and "Herb" or "Ore") }
        end
    end
    -- imported GatherMate2 nodes: no item, so no skill to judge by - only with "all"
    local gm = filter == "all" and s.nodesGM ~= false and type(db.gmNodes) == "table" and db.gmNodes[mapID]
    for id, coords in pairs(type(gm) == "table" and gm or {}) do
        local sl = id < 300 and MINE or HERB -- (GatherMate2: mining IDs below 300)
        if ranks[sl] and (not only or only == sl) then
            for _, c in ipairs(coords) do
                out[#out + 1] = { x = math.floor(c / 1000000) / 10000, y = math.floor(c % 1000000 / 100) / 10000,
                                  title = sl == HERB and "Herb" or "Ore" }
            end
        end
    end
    return out, mapID
end

-- nearest first from where you stand, each next stop the nearest left (yards: the zone's own size)
local function Order(nodes, mapID)
    local w, h = C_Map.GetMapWorldSize(mapID)
    if not (w and w > 0) then w, h = 1, 1 end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py = 0.5, 0.5
    if pos then px, py = pos:GetXY() end
    local left, out = {}, {}
    for i, n in ipairs(nodes) do left[i] = n end
    while #left > 0 and #out < MAX_STOPS do
        local best, bestD
        for i, n in ipairs(left) do
            local dx, dy = (n.x - px) * w, (n.y - py) * h
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then best, bestD = i, d end
        end
        local n = table.remove(left, best)
        out[#out + 1] = { map = mapID, x = n.x, y = n.y, title = n.title }
        px, py = n.x, n.y
    end
    return out
end

local touring = false -- (a tour of ours is running)
local pendingAfterCombat

local function Start(only, quiet)
    local api = API()
    if not api then if not quiet then Print("ShortestPathForever isn't ready.") end return false end
    if InCombatLockdown and InCombatLockdown() then
        pendingAfterCombat = { only = only, quiet = quiet }
        if not quiet then Print("in combat - the farming tour starts after the fight.") end
        return false
    end
    local nodes, mapID = Candidates(only)
    if #nodes == 0 then
        if not quiet then
            Print("Mastercraft knows no nodes here worth gathering for you yet. It learns every herb and vein you gather; GatherMate2's can be imported in Mastercraft's Settings > Nodes.")
        end
        return false
    end
    local stops = Order(nodes, mapID)
    local ok, started = pcall(api.NavigateRoute, OWNER, stops, { policy = "walking" })
    if not ok then Report("starting the farming tour", started) return false end
    if not started then
        if not quiet then Print("ShortestPathForever didn't take the tour (not ready yet, or no journey here).") end
        return false
    end
    touring = true
    local info = C_Map.GetMapInfo(mapID)
    Print(("farming tour: %d node%s in %s%s."):format(#stops, #stops == 1 and "" or "s", info and info.name or "this zone",
        #nodes > #stops and (" (the nearest " .. MAX_STOPS .. " of " .. #nodes .. ")") or ""))
    return true
end

local function Stop(quiet)
    pendingAfterCombat = nil
    local api = API()
    if not touring then return end
    touring = false
    if api and type(api.Cancel) == "function" then pcall(api.Cancel, OWNER) end
    if not quiet then Print("farming tour ended.") end
end

-- Mastercraft's farm session (MastercraftDB.farm[your GUID] = { start = ... } while you farm, false after)
local function Farming()
    local db = MC()
    local farm = db and type(db.farm) == "table" and db.farm[UnitGUID("player") or ""]
    return type(farm) == "table" and type(farm.start) == "number"
end

local wasFarming
local f = CreateFrame("Frame")
local wait = 0
f:SetScript("OnUpdate", function(_, dt)
    wait = wait + dt
    if wait < 1 then return end
    wait = 0
    local now = Farming()
    if wasFarming == nil then wasFarming = now return end -- (logging in mid-session: no tour by itself)
    if now == wasFarming then return end
    wasFarming = now
    if now then Start(nil, false) else Stop(false) end
end)
for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        local p = pendingAfterCombat
        pendingAfterCombat = nil
        if p then Start(p.only, p.quiet) end
    elseif touring or Farming() then
        Stop(true)
        Start(nil, false) -- (a new zone while farming: its own tour)
    end
end)

-- /mo farm [herbs | ores | stop]
local function Command(args)
    args = (args or ""):lower():match("^%s*(.-)%s*$")
    if args == "stop" or args == "off" then
        if touring then Stop(false) else Print("no farming tour running.") end
        return
    end
    local only = (args:find("^herb") and HERB) or ((args:find("^ore") or args:find("^min")) and MINE) or nil
    Stop(true)
    Start(only, false)
end

MasterOptions_FarmTour = { Command = Command, Start = Start, Stop = Stop, Candidates = Candidates }
end)
