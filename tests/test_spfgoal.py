# ShortestPathForever_OpenMapMiniMap: SPF's minimap goal texture (made on Minimap itself) ignores the parent's
# alpha once SPF creates it - possibly well after login.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES = {}
  function CreateFrame() local f = { SetScript = function(self, k, fn) self[k] = fn end }; FRAMES[#FRAMES + 1] = f; return f end
  function Tick(dt) for _, f in ipairs(FRAMES) do if f.OnUpdate then f.OnUpdate(f, dt) end end end
  function MakeGoal()
    local goal = { ignore = false }
    function goal:SetIgnoreParentAlpha(v) self.ignore = v; CALLS = (CALLS or 0) + 1 end
    ShortestPathForeverMinimapRoute = { Goal = goal }
    return goal
  end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_ShortestPathForever_OpenMapMiniMap")
L, E = lua.execute, lua.eval
res = {}
L('Tick(1); Tick(1)')
res["no SPF frame yet: nothing happens, no error"] = E("CALLS == nil")
L('GOAL = MakeGoal(); Tick(0.5)')
res["checks only once a second"] = E("GOAL.ignore == false")
L('Tick(0.6)')
res["goal made later: ignores the minimap's alpha"] = E("GOAL.ignore == true")
L('Tick(1); Tick(1)')
res["then stops looking"] = E("CALLS == 1")
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
