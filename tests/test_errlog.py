import sys
from lupa import LuaRuntime

lua = LuaRuntime()

lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
FR, PRINTS, PREV = {}, {}, {}
function CreateFrame() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:UnregisterEvent(e) self.ev[e] = nil end function f:SetScript(k, fn) self[k] = fn end FR[#FR+1] = f return f end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function print(s) PRINTS[#PRINTS+1] = s end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
time, date = os.time, os.date
function GetBuildInfo() return "1.16.1", "9999" end
C_AddOns = { GetAddOnMetadata = function(a, f) return "1.0.0" end }
local handler = function(msg) PREV[#PREV+1] = msg end
function geterrorhandler() return handler end
function seterrorhandler(fn) handler = fn end
function RaiseUncaught(msg) handler(msg) end
function debugstack() return "[string \"@Interface/AddOns/SomeAddon/x.lua\"]:1: in function <...>" end
''')
lua.eval("function(s) local f, e = load(s, '=ErrorLog'); if not f then error(e) end; return f end")(open(sys.argv[1], encoding="utf-8").read())()
L, E = lua.execute, lua.eval
fails = []
def check(name, cond):
    print(("ok   " if cond else "FAIL ") + name)
    if not cond: fails.append(name)

# before MasterOptionsDB exists: kept, then moved in
L('MasterOptions_ReportError("MasterOptions_Mastercraft_Keep", "learning", "Keep.lua:10: boom")')
check("early report kept until the DB loads", E("MasterOptions_ErrorLog.Count()") == 1)
L('Fire("ADDON_LOADED", "MasterOptions")')
check("moved into MasterOptionsDB.errors", E("#MasterOptionsDB.errors") == 1)

# the same error counted, not repeated
L('MasterOptions_ReportError("MasterOptions_Mastercraft_Keep", "learning", "Keep.lua:10: boom")')
check("same error counted", E("#MasterOptionsDB.errors") == 1 and E("MasterOptionsDB.errors[1].count") == 2)
check("one chat line", E("#PRINTS") == 1)

# uncaught errors: ours recorded, others only passed on
L('RaiseUncaught("Interface/AddOns/MasterOptions_Mastercraft_VendorSell/MasterOptions_Mastercraft_VendorSell.lua:42: attempt to index nil")')
L('RaiseUncaught("Interface/AddOns/Questie/Questie.lua:5: not ours")')
check("our uncaught error recorded", E("MasterOptionsDB.errors[1].addon") == "MasterOptions_Mastercraft_VendorSell")
check("another addon's error not recorded", E("#MasterOptionsDB.errors") == 2)
check("every error still reaches the previous handler", E("#PREV") == 2)
check("still one chat line per session", E("#PRINTS") == 1)

# cap
L('for i = 1, 50 do MasterOptions_ReportError("MasterOptions_X", nil, "err " .. i) end')
check("at most 30 kept", E("#MasterOptionsDB.errors") == 30)
check("latest first", E("MasterOptionsDB.errors[1].msg") == "err 50")

text = E("MasterOptions_ErrorLog.Text()")
check("copy text has header and entries", text.startswith("Master Options 1.0.0") and "err 50" in text)

calls = []
L('CHANGED = 0; MasterOptions_ErrorLog.OnChange = function() CHANGED = CHANGED + 1 end')
L('MasterOptions_ErrorLog.Clear()')
check("clear empties it and tells the window", E("MasterOptions_ErrorLog.Count()") == 0 and E("CHANGED") == 1)

if fails:
    print("ERRORS: %d" % len(fails)); sys.exit(1)
print("ERRORS: 0")
