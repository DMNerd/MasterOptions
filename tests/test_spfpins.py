# ShortestPathForever_OpenMapPins: the journey to a followed OpenMap pin cleared in ShortestPathForever -> OpenMap
# stops following it and the pin goes (kept, unfollowed, when you wrote a note on it); OpenMap's own stop,
# arriving and a replaced journey leave it alone; an end is acted on once.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, ERRS = {}, 0
  function CreateFrame() local f = { ev = {} }
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    FRAMES[#FRAMES + 1] = f; return f end
  C_Timer = { After = function(d, fn) fn() end }
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; print("ERR", e) end
  -- ShortestPathForever
  ENDED, SUBS, T = {}, {}, 0
  ShortestPathForever = { API = {
    Subscribe = function(fn) SUBS[#SUBS + 1] = fn end,
    Ended = function(owner) local e = ENDED[owner]; if e then return e.reason, e.at end end,
  } }
  function End(reason) T = T + 1; ENDED["OpenMap:Pin"] = { reason = reason, at = T }; for _, fn in ipairs(SUBS) do fn({ ended = true }) end end
  -- OpenMap
  FOLLOWED, CLEARS, REFRESH = nil, 0, 0
  WM = { db = { pins = { list = {} } } }
  function WM.WaypointPoint() if FOLLOWED then return FOLLOWED.map, FOLLOWED.x, FOLLOWED.y end end
  function WM.PinAt(m, x, y) for _, p in ipairs(WM.db.pins.list) do if p.map == m and p.x == x and p.y == y then return p end end end
  function WM.ClearPin() FOLLOWED = nil; CLEARS = CLEARS + 1 end
  function WM.RefreshPins() REFRESH = REFRESH + 1 end
  function WM.TrackPoint(m, x, y) FOLLOWED = { map = m, x = x, y = y } end
  OpenMap = { GetModule = function(_, n) if n == "worldmap" then return WM end end }
  function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = orig(...); fn(...); return r end end
  MasterOptions_DJOpenMapDB = { ours = { [6] = true } }
  function Pin(id, note, from) local p = { id = id, map = 1434, x = 0.1 * id, y = 0.5, note = note, from = from }
    table.insert(WM.db.pins.list, p); return p end
  function Follow(p) FOLLOWED = { map = p.map, x = p.x, y = p.y } end
  function Has(id) for _, p in ipairs(WM.db.pins.list) do if p.id == id then return true end end return false end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_ShortestPathForever_OpenMapPins")
E, L = lua.eval, lua.execute
res = {}
L('ENDED["OpenMap:Pin"] = { reason = "cleared", at = 0 }; Fire("PLAYER_LOGIN")')
res["subscribed at login"] = E("#SUBS") == 1
L('P1 = Pin(1, ""); Follow(P1); for _, fn in ipairs(SUBS) do fn({}) end')
res["an end from before login: left alone"] = E("CLEARS") == 0 and E("Has(1)")
L('End("cleared")')
res["journey cleared in ShortestPathForever: OpenMap stops following, the pin goes"] = E("CLEARS") == 1 and not E("Has(1)") and E("REFRESH") >= 1
L('for _, fn in ipairs(SUBS) do fn({}) end')
res["the same end told again: nothing more"] = E("CLEARS") == 1
L('P2 = Pin(2, "my farm spot"); Follow(P2); End("cleared")')
res["a pin with your own note: unfollowed, kept"] = E("CLEARS") == 2 and E("Has(2)")
L('P3 = Pin(3, "Dungeon Journal: Ragefire Chasm", "Dungeon Journal"); Follow(P3); End("cleared")')
res["an addon's pin (Dungeon Journal's): goes"] = E("CLEARS") == 3 and not E("Has(3)")
L('P4 = Pin(4, ""); Follow(P4); End("cancelled"); End("arrived"); End("replaced")')
res["OpenMap's own stop, arriving, replaced: pin and following kept"] = E("CLEARS") == 3 and E("Has(4)")
L('FOLLOWED = nil; End("cleared")')
res["OpenMap following nothing: nothing to clear"] = E("CLEARS") == 3 and E("Has(4)")
L('FOLLOWED = { map = 1434, x = 0.77, y = 0.2 }; End("cleared")')
res["a waypoint with no map pin (a plain waypoint): unfollowed"] = E("CLEARS") == 4 and E("Has(4)") and E("ERRS") == 0
L('P5 = Pin(5, ""); WM.TrackPoint(P5.map, P5.x, P5.y); FOLLOWED = { map = 1434, x = 0.31, y = 0.42 }; End("cleared")')
res["the journey moved the game's waypoint along the way: still the pin OpenMap was told to follow goes"] = not E("Has(5)")
L('P6 = Pin(6, "Dungeon Journal: Deadmines", "Dungeon Journal"); WM.TrackPoint(P6.map, P6.x, P6.y); End("cleared")')
res["a Dungeon Journal pin: Master Options' own record of it goes too"] = not E("Has(6)") and E("MasterOptions_DJOpenMapDB.ours[6]") is None
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
