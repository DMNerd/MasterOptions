# ShortestPathForever_OpenMapMiniMap: SPF's minimap goal texture (made on Minimap itself) ignores the parent's
# alpha once SPF creates it - possibly well after login.
import sys
from lupa import LuaRuntime
import os as _os
sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared
src = open(sys.argv[1], encoding="utf-8").read()
STUBS = r'''
  FRAMES, TM = {}, {}
  C_Timer = { After = function(d, fn) TM[#TM + 1] = fn end }
  function RunTimers() local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end
  function CreateFrame() local f = { ev = {}, SetScript = function(self, k, fn) self[k] = fn end,
    RegisterEvent = function(self, e) self.ev[e] = true end }; FRAMES[#FRAMES + 1] = f; return f end
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function Tick(dt) for _, f in ipairs(FRAMES) do if f.OnUpdate then f.OnUpdate(f, dt) end end end
  function hooksecurefunc(t, k, fn) local o = t[k]; t[k] = function(...) local r = o(...); fn(...); return r end end
  function MakeGoal()
    local goal = { ignore = false }
    function goal:SetIgnoreParentAlpha(v) self.ignore = v; CALLS = (CALLS or 0) + 1 end
    ShortestPathForeverMinimapRoute = { Goal = goal, SetIgnoreParentAlpha = function(self, v) self.ignore = v end }
    return goal
  end
'''
def runtime(with_api):
    lua = LuaRuntime()
    load_shared(lua, sys.argv[1])
    lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
    lua.execute(STUBS)
    if with_api:
        lua.execute("SUBS = {}; ShortestPathForever = { API = { Subscribe = function(fn) SUBS[#SUBS + 1] = fn end } }"
                    "; function Journey() for _, fn in ipairs(SUBS) do fn() end end")
    lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_ShortestPathForever_OpenMapMiniMap")
    return lua

res = {}
# ShortestPathForever's API there: looked for at login and when a journey starts - no polling
lua = runtime(True)
L, E = lua.execute, lua.eval
L('Fire("PLAYER_LOGIN"); RunTimers(); Tick(5)')
res["with SPF's API: no goal yet, nothing polled, no error"] = E("CALLS == nil")
L('GOAL = MakeGoal(); Journey()')
res["a journey starts (the goal is made): it ignores the minimap's alpha"] = E("GOAL.ignore == true")
L('Journey(); Tick(5)')
res["...once"] = E("CALLS == 1")
# without the API (an older ShortestPathForever): once a second until the goal is there
lua = runtime(False)
L, E = lua.execute, lua.eval
L('Tick(1); Tick(1)')
res["no SPF frame yet: nothing happens, no error"] = E("CALLS == nil")
L('GOAL = MakeGoal(); Tick(0.5)')
res["checks only once a second"] = E("GOAL.ignore == false")
L('Tick(0.6)')
res["goal made later: ignores the minimap's alpha"] = E("GOAL.ignore == true")
L('Tick(1); Tick(1)')
res["then stops looking"] = E("CALLS == 1")

L('ShortestPathForeverMinimapRoute:SetIgnoreParentAlpha(false)')
res["OpenMap_MiniMap hides the route while you drag the map: the goal hides with it"] = E("GOAL.ignore == false")
L('ShortestPathForeverMinimapRoute:SetIgnoreParentAlpha(true)')
res["...and shows again with it"] = E("GOAL.ignore == true")
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
