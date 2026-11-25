# DungeonJournal_OpenMap, "Map inside dungeons": Dungeon Journal's map is chosen through OpenMap's own switch
# (worldmap.dungeonInside = false) - OpenMap's SetupDungeons, which does much more since OpenMap 0.8 (Zephras
# Isle's map, dungeons entered, wing hand-off ...), must stay. Choosing OpenMap again undoes only what we set.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
res = {}


def run(mode, db, store=None):
    lua = LuaRuntime()
    lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
    lua.execute(r'''
      FRAMES = {}
      function CreateFrame() local f = { RegisterEvent = function() end, SetScript = function(self, k, fn) self[k] = fn end }; FRAMES[#FRAMES + 1] = f; return f end
      C_Timer = { After = function() end }
      C_AddOns = { GetAddOnEnableState = function() return 0 end }
      function UnitName() return "Testchar", "Alpha" end
      function hooksecurefunc() end
      ORIG_SETUP = function() return "openmap dungeon map" end
      local mod = { SetupDungeons = ORIG_SETUP, HoldDungeonHere = ORIG_SETUP }
      OpenMap = { GetModule = function(_, n) return mod end, MapStitch = { BuildDungeonPins = function() return { { instances = { { 1, "Deadmines" } } } } end } }
      OM = mod
      ForeverDungeonJournal_NS = { RefreshWorldMapOverlay = function() end, DB = { Deadmines = {} } }
    ''')
    lua.execute("OM.db = %s" % db)
    lua.execute("MasterOptions_DJOpenMapDB = %s" % (store or "nil"))
    lua.execute("MasterOptionsDB = { dungeonMap = %s }" % ("nil" if mode == "journal" else '"openmap"'))
    lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_DungeonJournal_OpenMap")
    lua.execute('for _, f in ipairs(FRAMES) do if f.OnEvent then f.OnEvent(f, "PLAYER_LOGIN") end end')
    return lua


lua = run("journal", "{}")
res["journal: OpenMap's SetupDungeons left alone"] = lua.eval("OM.SetupDungeons == ORIG_SETUP")
res["journal: OpenMap's own 'map inside dungeons' off"] = lua.eval("OM.db.dungeonInside == false")
res["journal: entrance clicks open Dungeon Journal"] = lua.eval("OpenMap.MapStitch.BuildDungeonPins()[1].OnClick ~= nil")
res["journal: remembers it set the switch"] = lua.eval("MasterOptions_DJOpenMapDB.setInside == true")
lua = run("openmap", "{ dungeonInside = false }", "{ setInside = true, ours = {} }")
res["openmap after journal: our switch undone"] = lua.eval("OM.db.dungeonInside == nil and MasterOptions_DJOpenMapDB.setInside == nil")
lua = run("openmap", "{ dungeonInside = false }", "{ ours = {} }")
res["openmap: your own OpenMap setting (off) left as you set it"] = lua.eval("OM.db.dungeonInside == false")
lua = run("journal", "nil")
res["journal, OpenMap's settings not loaded yet: no error, SetupDungeons left"] = lua.eval("OM.SetupDungeons == ORIG_SETUP")
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
