import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
for mode in ("journal", "openmap"):
    lua = LuaRuntime()
    lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
    lua.execute(r'''
      function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
      C_Timer = { After = function() end }
      C_AddOns = { GetAddOnEnableState = function() return 0 end }
      function UnitName() return "Testchar", "Alpha" end
      ORIG_SETUP = function() return "openmap dungeon map" end
      local mod = { SetupDungeons = ORIG_SETUP, HoldDungeonHere = ORIG_SETUP }
      OpenMap = { GetModule = function(_, n) return mod end, MapStitch = { BuildDungeonPins = function() return { { instances = { { 1, "Deadmines" } } } } end } }
      OM = mod
      ForeverDungeonJournal_NS = { RefreshWorldMapOverlay = function() end, DB = { Deadmines = {} } }
    ''')
    lua.execute("MasterOptionsDB = { dungeonMap = %s }" % ("nil" if mode == "journal" else '"openmap"'))
    lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_DungeonJournal_OpenMap")
    print(mode + ":", "OpenMap dungeon map off =", lua.eval("OM.SetupDungeons ~= ORIG_SETUP"),
          "| entrance click handled =", lua.eval("OpenMap.MapStitch.BuildDungeonPins()[1].OnClick ~= nil"))
