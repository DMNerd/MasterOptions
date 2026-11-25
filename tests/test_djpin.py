import sys
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end io.write(table.concat(t, " "), "\n") end
FRAMES, TIMERS = {}, {}
function CreateFrame() local f = { ev = {} }
  function f:RegisterEvent(e) self.ev[e] = true end
  function f:SetScript(k, fn) self[k] = fn end
  FRAMES[#FRAMES+1] = f; return f end
C_Timer = { After = function(d, fn) TIMERS[#TIMERS+1] = fn end }
function Fire(e, ...) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function time() return 1000 end
function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = { orig(...) }; fn(...); return table.unpack(r) end end
-- OpenMap's world map module (only what the patch uses)
FOLLOWED = nil
local mod = { db = { pins = { list = { { id = 1, map = 1429, x = 0.5, y = 0.5, note = "my own pin", color = 1 } }, nextId = 2 } } }
function mod.PinAt(m, x, y) for _, p in ipairs(mod.db.pins.list) do if p.map == m and math.abs(p.x - x) < 5e-4 and math.abs(p.y - y) < 5e-4 then return p end end end
function mod.TrackPoint(m, x, y, title) FOLLOWED = { m, x, y, title } end
function mod.WaypointPoint() if FOLLOWED then return FOLLOWED[1], FOLLOWED[2], FOLLOWED[3] end end
function mod.ClearPin() FOLLOWED = nil end
function mod.RefreshPins() end
OpenMap = { GetModule = function(_, n) return n == "worldmap" and mod or nil end }
OM = mod
-- Dungeon Journal's two arrow functions (its own bodies do nothing here)
ForeverDungeonJournal_NS = { SetWaypointArrow = function() end, ClearWaypointArrow = function() end }
function Pins() local o = {} for _, p in ipairs(OM.db.pins.list) do o[#o+1] = ("#%d %s (%.3f,%.3f) colour %d"):format(p.id, p.note, p.x, p.y, p.color) end return table.concat(o, " | ") end
''')
load = lua.eval("function(src) local f, e = load(src, '=djpin'); if not f then error(e) end; return f end")
load(open(sys.argv[1], encoding="utf-8").read())("MasterOptions_DungeonJournal_OpenMap")
L = lua.execute
L('Fire("ADDON_LOADED", "MasterOptions_DungeonJournal_OpenMap"); Fire("PLAYER_LOGIN")')
spot = r'local s ={ mapID = 1436, x = 0.5612, y = 0.4721, label = "Gryan Stoutmantle \226\128\148 Sentinel Hill", markerType = "quest", questTitle = "The Defias Brotherhood" }'
L(spot + '; ForeverDungeonJournal_NS.SetWaypointArrow(s); SPOT = s')
print("after Show on Map:", lua.eval("Pins()"))
print("followed:", lua.eval("FOLLOWED and (FOLLOWED[1] .. ' ' .. FOLLOWED[4]) or 'nothing'"))
L('ForeverDungeonJournal_NS.SetWaypointArrow(SPOT)')
print("Show on Map again (no duplicate):", lua.eval("#OM.db.pins.list"), "pins")
L('ForeverDungeonJournal_NS.ClearWaypointArrow(SPOT)')
print("after the Journal clears it:", lua.eval("Pins()"), "| followed:", lua.eval("FOLLOWED and 'yes' or 'nothing'"))
# a pin you wrote your own note on stays
L('ForeverDungeonJournal_NS.SetWaypointArrow(SPOT); OM.PinAt(1436, 0.5612, 0.4721).note = "Defias quest - go at night"; ForeverDungeonJournal_NS.ClearWaypointArrow(SPOT)')
print("renamed by you, then cleared:", lua.eval("Pins()"))
