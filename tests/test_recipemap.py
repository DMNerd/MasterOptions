# Mastercraft_RecipeMap: vendors selling patterns for recipes you haven't learned (Mastercraft's save + QuestieDB)
# and your profession's trainers near your cap get map markers (HereBeDragons pins), your faction only.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, TIMERS, ERRS = {}, {}, 0
  local function Region() local r = {} for _, k in ipairs({ "SetSize", "SetPoint", "SetTexture", "SetVertexColor",
    "SetAllPoints", "EnableMouse", "SetScript", "Hide", "Show" }) do r[k] = function() end end return r end
  function CreateFrame() local f = Region(); f.ev = {}
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    function f:CreateTexture() return Region() end
    FRAMES[#FRAMES + 1] = f; return f end
  UIParent = {}
  C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = fn end }
  function RunTimers() for _ = 1, 20 do local t = TIMERS; TIMERS = {}; if #t == 0 then return end for _, fn in ipairs(t) do fn() end end end
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; print("ERR", e) end
  function UnitGUID() return "Player-1" end
  FACTION, LEVEL, COMBAT = "Alliance", 25, false
  function InCombatLockdown() return COMBAT end
  function UnitFactionGroup() return FACTION end
  function UnitLevel() return LEVEL end
  -- Mastercraft's save
  MastercraftDB = {
    recipes = { ["Player-1"] = { Leatherworking = { list = {
      { name = "Heavy Armor Kit", learned = false },
      { name = "Light Leather", learned = true },
      { name = "Nothing Sells This", learned = false } } } } },
    chars = { ["Player-1"] = { professions = { { name = "Leatherworking", skill = 140, max = 150 }, { name = "Cooking", skill = 100, max = 225 } } } },
  }
  -- QuestieDB
  local NPC = {
    [501] = { name = "Alliance Vendor", friendlyToFaction = "A", spawns = { [1519] = { { 50, 60 } } } },
    [502] = { name = "Horde Vendor", friendlyToFaction = "H", spawns = { [1637] = { { 10, 10 } } } },
    [601] = { name = "LW Trainer", friendlyToFaction = "AH", spawns = { [1519] = { { 20, 30 }, { -1, -1 } } } },
    [701] = { name = "Cook Trainer", friendlyToFaction = "A", spawns = { [1519] = { { 70, 70 } } } },
  }
  INDEX_STEPS = 0
  LibQuestieDB = {
    Item = { IdsByName = function(n) if n == "Pattern: Heavy Armor Kit" then return { 9001 } end end,
             Get = function(id, k) if id == 9001 and k == "vendors" then return { 501, 502 } end end,
             BuildNameIndexAsync = function() INDEX_STEPS = INDEX_STEPS + 1; coroutine.yield(); INDEX_STEPS = INDEX_STEPS + 1 end },
    Npc = { Get = function(id, k) return NPC[id] and NPC[id][k] end } }
  QuestieLoader = { ImportModule = function(_, name)
    if name == "Townsfolk" then return { professionTrainers = { [165] = { 601 }, [185] = { 701 } } } end
    if name == "ZoneDB" then return { GetUiMapIdByAreaId = function(_, a) return ({ [1519] = 84, [1637] = 85 })[a] end } end end }
  -- HereBeDragons-Pins
  WORLD, MINI = {}, {}
  local pins = {
    AddWorldMapIconMap = function(_, ref, icon, map, x, y) WORLD[#WORLD + 1] = { icon = icon, map = map, x = x, y = y } end,
    AddMinimapIconMap = function(_, ref, icon, map, x, y) MINI[#MINI + 1] = { icon = icon } end,
    RemoveAllWorldMapIcons = function() WORLD = {}; REDRAWS = (REDRAWS or 0) + 1 end, RemoveAllMinimapIcons = function() MINI = {} end }
  function LibStub(name) if name == "HereBeDragons-Pins-2.0" then return pins end end
  function Marks() local o = {} for _, w in ipairs(WORLD) do o[#o + 1] = w.icon.title .. "@" .. w.map .. ":" .. w.x .. "," .. w.y end table.sort(o) return table.concat(o, " | ") end
  function Lines(title) for _, w in ipairs(WORLD) do if w.icon.title == title then return table.concat(w.icon.lines, "; ") end end end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_Mastercraft_RecipeMap")
E, L = lua.eval, lua.execute
L('Fire("PLAYER_LOGIN"); RunTimers()')
res = {
    "QuestieDB's name index built in steps first": E("INDEX_STEPS") == 2,
    "vendor (your faction) and trainer near the cap marked, at the map's 0-1 spot": E("Marks()") == "Alliance Vendor@84:0.5,0.6 | LW Trainer@84:0.2,0.3",
    "the vendor's tooltip: the recipe it has for you": E('Lines("Alliance Vendor")') == "Heavy Armor Kit (Leatherworking)",
    "the trainer's tooltip: the rank to train": E('Lines("LW Trainer")') == "Train Expert Leatherworking (140 / 150)",
    "minimap too": E("#MINI") == 2,
}
L('LEVEL = 15; Fire("PLAYER_LEVEL_UP"); RunTimers()')
res["level too low for Expert: no trainer marker, nothing left over"] = E("Marks()") == "Alliance Vendor@84:0.5,0.6"
L('LEVEL = 25; MastercraftDB.recipes["Player-1"].Leatherworking.list[1].learned = true; Fire("NEW_RECIPE_LEARNED"); RunTimers()')
res["the recipe learned: its vendor no longer marked"] = E("Marks()") == "LW Trainer@84:0.2,0.3"
L('FACTION = "Horde"; MastercraftDB.recipes["Player-1"].Leatherworking.list[1].learned = false; Fire("TRADE_SKILL_CLOSE"); RunTimers()')
res["Horde: the Horde vendor instead (its own map)"] = E("Marks()") == "Horde Vendor@85:0.1,0.1 | LW Trainer@84:0.2,0.3"
# drops: GearMatic's rates (a creature and a chest), one marker per source and zone; world drops not marked
L(r"""
  FACTION = "Alliance"
  local list = MastercraftDB.recipes["Player-1"].Leatherworking.list
  list[1].learned = true
  list[#list + 1] = { name = "Dropped Cloak", learned = false }    -- GearMatic: 2 sources
  list[#list + 1] = { name = "World Thing", learned = false }      -- GearMatic: 7 sources, a world drop
  list[#list + 1] = { name = "Questie Drop", learned = false }     -- no GearMatic rate: QuestieDB's npcDrops
  list[#list + 1] = { name = "Questie World", learned = false }    -- QuestieDB: 20 creatures
  local items = { ["Pattern: Dropped Cloak"] = 9002, ["Pattern: World Thing"] = 9003, ["Pattern: Questie Drop"] = 9004,
                  ["Pattern: Questie World"] = 9005, ["Pattern: Heavy Armor Kit"] = 9001 }
  local many = {} for i = 1, 20 do many[i] = 900 + i end
  local itemFields = { [9001] = { vendors = { 501, 502 } }, [9004] = { npcDrops = { 802 } }, [9005] = { npcDrops = many } }
  LibQuestieDB.Item.IdsByName = function(n) return items[n] and { items[n] } end
  LibQuestieDB.Item.Get = function(id, k) return itemFields[id] and itemFields[id][k] end
  local NPC2 = { [801] = { name = "Ogre Mage", spawns = { [1519] = { { 10, 10 }, { 30, 30 } } } },
                 [802] = { name = "Questie Mob", spawns = { [1519] = { { 60, 40 } } } } }
  local oldGet = LibQuestieDB.Npc.Get
  LibQuestieDB.Npc.Get = function(id, k) if NPC2[id] then return NPC2[id][k] end return oldGet(id, k) end
  LibQuestieDB.Npc.IdsByName = function(n) if n == "Ogre Mage" then return { 801 } end end
  LibQuestieDB.Object = { IdsByName = function(n) if n == "Old Chest" then return { 950 } end end,
                          Get = function(id, k) if id == 950 then return ({ name = "Old Chest", spawns = { [1519] = { { 40, 40 } } } })[k] end end }
  local seven = {} for i = 1, 7 do seven[i] = { name = "Mob " .. i, kind = "c", percent = 1 } end
  GearMatic = { DropRates = { ForItem = function(id)
    if id == 9002 then return { { name = "Ogre Mage", kind = "c", percent = 2.44 }, { name = "Old Chest", kind = "o", percent = 10, estimate = true },
                                { name = "Collecting", kind = "c", progress = true } } end
    if id == 9003 then return seven end
    return {} end } }
  Fire("NEW_RECIPE_LEARNED"); RunTimers()
""")
m = E("Marks()")
print("  drops:", m)
res["GearMatic's sources marked once each (a mob at the middle of its spawns, a chest)"] = "Ogre Mage@84:0.2,0.2" in m and "Old Chest@84:0.4,0.4" in m
res["the drop's tooltip: the pattern and GearMatic's chance (estimate said)"] = (E('Lines("Ogre Mage")') == "Dropped Cloak (Leatherworking): 2.4%"
    and E('Lines("Old Chest")') == "Dropped Cloak (Leatherworking): 10.0% - a Classic estimate")
res["no GearMatic rate: QuestieDB's creature"] = "Questie Mob@84:0.6,0.4" in m and E('Lines("Questie Mob")') == "Questie Drop (Leatherworking): drops here"
res["world drops (7 GearMatic sources, 20 QuestieDB creatures) not marked"] = "Mob 1" not in m and "NPC 901" not in m and E("#WORLD") == 4
# redrawn only when something it depends on changed; not in a fight; patterns looked up once a session
L('REDRAWS = 0; LOOKUPS = 0; local f = LibQuestieDB.Item.IdsByName; LibQuestieDB.Item.IdsByName = function(n) LOOKUPS = LOOKUPS + 1; return f(n) end')
L('Fire("SKILL_LINES_CHANGED"); RunTimers()')
res["a skill point elsewhere (same state): nothing worked out or drawn again"] = E("REDRAWS") == 0 and E("LOOKUPS") == 0
L('MastercraftDB.chars["Player-1"].professions[1].skill = 145; Fire("SKILL_LINES_CHANGED"); RunTimers()')
res["a profession's skill changed: drawn again, patterns from the session's cache"] = E("REDRAWS") == 1 and E("LOOKUPS") == 0
L('COMBAT = true; LEVEL = 26; Fire("PLAYER_LEVEL_UP"); RunTimers()')
res["in a fight: waits"] = E("REDRAWS") == 1
L('COMBAT = false; Fire("PLAYER_REGEN_ENABLED"); RunTimers()')
res["...drawn after it"] = E("REDRAWS") == 2
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
