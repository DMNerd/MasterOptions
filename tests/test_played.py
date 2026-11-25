import sys
from lupa import LuaRuntime
lua = LuaRuntime()
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
NOW = 10; function GetTime() return NOW end
TIMERS = {}; C_Timer = { After = function(d, fn) TIMERS[#TIMERS+1] = fn end }
function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
function hooksecurefunc(a, b, c) if type(a) == "string" then local o = _G[a]; _G[a] = function(...) local r = o(...); b(...); return r end else local o = a[b]; a[b] = function(...) local r = o(...); c(...); return r end end end
FILTER = false
Chattynator = { API = { FilterTimePlayed = function(on) FILTER = on end } }
ChatFrame1 = { UnregisterEvent = function() end, RegisterEvent = function() end }
function RequestTimePlayed() end
EV = {}
function CreateFrame() local f = {} function f:RegisterEvent() end function f:SetScript(_, fn) EV[#EV+1] = fn end return f end
function Answer() for _, fn in ipairs(EV) do fn() end; RunTimers() end
''')
lua.eval("function(s) return load(s, '=p') end")(open(sys.argv[1], encoding="utf-8").read())()
L = lua.execute
L("RequestTimePlayed()"); print("you type /played:          filtered =", lua.eval("FILTER"))
L("NOW = 20; ChatFrame1:UnregisterEvent('TIME_PLAYED_MSG')"); print("Chattynator setup alone:   filtered =", lua.eval("FILTER"))
L("NOW = 30; ChatFrame1:UnregisterEvent('TIME_PLAYED_MSG'); RequestTimePlayed()"); print("Mastercraft's request:     filtered =", lua.eval("FILTER"))
L("Answer()"); print("after the server answers:  filtered =", lua.eval("FILTER"))
