# Mastercraft_FarmTour: Mastercraft's farm session starts a ShortestPathForever walking tour of the zone's nodes
# worth it (Mastercraft's rule, by the skill each node's item needs), nearest first; stopping ends it; /mo farm.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, PRINTS, ERRS = {}, {}, 0
  function CreateFrame() local f = { ev = {} }
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    FRAMES[#FRAMES + 1] = f; return f end
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function Tick() for _, f in ipairs(FRAMES) do if f.OnUpdate then f.OnUpdate(f, 1) end end end
  function print(t) PRINTS[#PRINTS + 1] = t end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1 end
  function UnitGUID() return "Player-1" end
  COMBAT = false
  function InCombatLockdown() return COMBAT end
  -- the map: a subzone (1437) of the zone 1411, 1000 x 1000 yards, you at the middle
  C_Map = {
    GetBestMapForUnit = function() return 1437 end,
    GetMapInfo = function(id) if id == 1437 then return { mapType = 5, parentMapID = 1411, name = "Cave" } end
                              if id == 1411 then return { mapType = 3, parentMapID = 12, name = "Durotar" } end end,
    GetMapWorldSize = function() return 1000, 1000 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
  }
  -- you: Herbalism 120, Mining 60
  function GetProfessions() return 1, 2 end
  function GetProfessionInfo(i) if i == 1 then return "Herbalism", 0, 120, 300, 0, 0, 182 end return "Mining", 0, 60, 300, 0, 0, 186 end
  local function N(name, prof, item, x, y) return { n = name, p = prof, i = item, x = x, y = y } end
  MastercraftDB = { settings = { nodesFilter = "skillups" }, farm = {}, nodes = { [1411] = {
    N("Peacebloom", "Herbalism", 2447, 0.51, 0.5),     -- 1: 119 above it, no skill-up
    N("Bruiseweed", "Herbalism", 2453, 0.60, 0.5),     -- 100: a skill-up
    N("Kingsblood", "Herbalism", 3356, 0.52, 0.5),     -- 125: can't yet
    N("Copper Vein", "Mining", 2770, 0.55, 0.5),       -- 1: a skill-up at 60
    N("Tin Vein", "Mining", 2771, 0.53, 0.5),          -- 65: can't yet
    N("New Forever Herb", "Herbalism", 99999, 0.70, 0.5), -- unknown: counts
  } }, gmNodes = { [1411] = { [401] = { 5000005000 } } } }
  ROUTES, CANCELS = {}, 0
  ShortestPathForever = { API = {
    NavigateRoute = function(owner, stops, opt)
      if OLD_SPF and opt.tourLine ~= nil then return nil end -- (before 1.49: an option it doesn't know: invalid)
      ROUTES[#ROUTES + 1] = { owner = owner, stops = stops, policy = opt.policy, tourLine = opt.tourLine }
      CURRENT = owner; return true end,
    Cancel = function(owner) CANCELS = CANCELS + 1; if CURRENT == owner then CURRENT = nil end; return true end,
    CurrentStop = function(owner) if CURRENT == owner then return 1 end end,
    Active = function() return CURRENT ~= nil end } }
  function Titles(r) local t = {} for _, s in ipairs(r.stops) do t[#t + 1] = s.title end return table.concat(t, ", ") end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_Mastercraft_FarmTour")
E, L = lua.eval, lua.execute
L('Tick()')  # (the first look: not farming)
L('MastercraftDB.farm["Player-1"] = { start = 1 }; Tick()')
res = {
    "Mastercraft's farm start: a walking tour by Master Options": E("#ROUTES") == 1 and E("ROUTES[1].policy") == "walking" and E("ROUTES[1].owner") == "Master Options",
    "skill-ups only, nearest first, unknown item counts": E("Titles(ROUTES[1])") == "Copper Vein, Bruiseweed, New Forever Herb",
    "on the zone's map (not the cave's)": E("ROUTES[1].stops[1].map") == 1411,
}
L('MastercraftDB.farm["Player-1"] = false; Tick()')
res["Mastercraft's farm stop: the tour ends"] = E("CANCELS") == 1
L('MasterOptions_FarmTour.Command("herbs")')
res["/mo farm herbs: herbs only"] = E("Titles(ROUTES[2])") == "Bruiseweed, New Forever Herb"
L('MastercraftDB.settings.nodes = { Herbalism = false }; MasterOptions_FarmTour.Command("")')
res["Mastercraft's map switch for a profession off: none of it"] = E("Titles(ROUTES[3])") == "Copper Vein"
L('MastercraftDB.settings.nodes = nil; MastercraftDB.settings.nodesFilter = "all"; MasterOptions_FarmTour.Command("")')
res["Which nodes = all: every node, and GatherMate2's imports"] = E("#ROUTES[4].stops") == 7
L('MastercraftDB.settings.nodesFilter = "skillups"; COMBAT = true; MasterOptions_FarmTour.Command("")')
res["in combat: waits"] = E("#ROUTES") == 4
L('COMBAT = false; Fire("PLAYER_REGEN_ENABLED")')
res["...and starts after the fight"] = E("#ROUTES") == 5
L('MastercraftDB.nodes[1411] = {}; MastercraftDB.gmNodes = nil; n = #PRINTS; MasterOptions_FarmTour.Command("")')
res["nothing worth it: says so, no tour"] = E("#ROUTES") == 5 and "knows no nodes" in str(E("PRINTS[#PRINTS]"))
L('for i = 1, 70 do MastercraftDB.nodes[1411][i] = { n = "Copper Vein", p = "Mining", i = 2770, x = 0.5 + i / 1000, y = 0.5 } end; MasterOptions_FarmTour.Command("")')
res["more than 64: the nearest 64 (ShortestPathForever's limit)"] = E("#ROUTES[6].stops") == 64 and "nearest 64 of 70" in str(E("PRINTS[#PRINTS]"))
L('Fire("ZONE_CHANGED_NEW_AREA")')
res["a new zone during our tour: its own tour"] = E("#ROUTES") == 7 and E("CURRENT") == "Master Options"
L('CURRENT = "OpenMap:Pin"; Fire("ZONE_CHANGED_NEW_AREA")')
res["our tour replaced (a pin you follow): the next zone leaves your journey alone"] = E("#ROUTES") == 7 and E("CURRENT") == "OpenMap:Pin"
L('CURRENT = nil; MastercraftDB.farm["Player-1"] = { start = 2 }; Fire("ZONE_CHANGED_NEW_AREA")')
res["farming, no journey under way: a new zone gets a tour"] = E("#ROUTES") == 8
L('CURRENT = "TomTom"; Stop = nil; MasterOptions_FarmTour.Stop(true); n = #ROUTES; Fire("ZONE_CHANGED_NEW_AREA")')
res["farming, another journey under way: not replaced"] = E("#ROUTES") == E("n") and E("CURRENT") == "TomTom"
res["ShortestPathForever 1.49+: the tour asks for its calmer tour line"] = E("ROUTES[1].tourLine") is True
L('for i = 1, 3 do MastercraftDB.nodes[1411][i] = { n = "Copper Vein", p = "Mining", i = 2770, x = 0.5, y = 0.5 } end')
L('CURRENT = nil; OLD_SPF = true; n = #ROUTES; MasterOptions_FarmTour.Command("")')
res["older ShortestPathForever (doesn't know the option): the tour starts anyway, without it"] = (
    E("#ROUTES") == E("n") + 1 and E("ROUTES[#ROUTES].tourLine") is None)
L('OLD_SPF = nil')
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
