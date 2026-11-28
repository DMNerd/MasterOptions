# Share setup (Share.lua): every choice Master Options shows, and the never-sell list, as one code (AceSerializer +
# LibDeflate, Master Options' own copies) - made, read back and applied; a choice that can't be set here skipped; a code
# that isn't one, or is cut short, refused with why.
import sys, os
from lupa import LuaRuntime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # (run with -I)
from wow_harness import fake_wow

here = os.path.dirname(os.path.abspath(__file__))
mo_path = sys.argv[1]
mo_dir = os.path.dirname(os.path.abspath(mo_path))
lua = LuaRuntime(unpack_returned_tuples=True)
fake_wow(lua, here)
lua.execute(r'''
Baganator = { API = { RequestItemButtonsRefresh = function() end } }
CheapUpgrades = {}
SlashCmdList.PAWN_FOREVER = function() end
NS_LIST = { [2589] = true }
MasterOptions_NeverSell = {
  List = function() local o = {} for id in pairs(NS_LIST) do o[#o + 1] = id end table.sort(o) return o end,
  Sources = function() return { "GearMatic" } end,
  Set = function(id, on) NS_LIST[id] = on or nil end, Sync = function() end,
}
LibStub = nil -- (the fake game's stand-in: Master Options' own LibStub below)
''')
load = lua.eval("function(s, n) local f, e = load(s, '=' .. n); if not f then error(e) end; return f end")
for lib in ("LibStub.lua", "AceSerializer-3.0.lua", "LibDeflate.lua"):
    load(open(os.path.join(mo_dir, "Libs", lib), encoding="utf-8").read(), lib)()
load(open(os.path.join(mo_dir, "ErrorLog.lua"), encoding="utf-8").read(), "ErrorLog.lua")("MasterOptions")
load(open(os.path.join(mo_dir, "Modules.lua"), encoding="utf-8").read(), "Modules.lua")()
from shared_lua import load_shared, load_master_options
load_shared(lua, mo_path)
ns = load_master_options(lua, mo_path)
lua.globals().MO = ns
L, E = lua.execute, lua.eval
L('Fire("ADDON_LOADED", "MasterOptions"); Fire("PLAYER_LOGIN"); RunTimers(); RunTimers()')
L('''
  function Row(name) for _, o in ipairs(MO.OPTIONS) do if o.label == name then return o end end end
  CODE = MO.Share.Export()
''')
res = {}
res["a code: one line, Master Options' prefix"] = (E("CODE") or "").startswith("MO1!") and "\n" not in E("CODE")
res["...read back: the choices by row name, and the never-sell list"] = E('''(function() local d = MO.Share.Decode(CODE)
  return d and d.rows["Gathering pin size"] ~= nil and d.neverSell[1] == 2589 end)()''') is True
L('''GPS = Row("Gathering pin size"); WAS = GPS.get(); GPS.set(WAS == "Large" and "Small" or "Large")''')
L('NS_LIST = {}; R = MO.Share.Import(CODE)')
res["used: a choice changed since is set back, the rest already so"] = E("GPS.get() == WAS and R.set >= 1 and R.same > 10") is True
res["...the never-sell list's items added"] = E("NS_LIST[2589] == true and R.neverSell == 1") is True
# a code from elsewhere: a row this setup doesn't have, a value no longer a choice
L('''
  local ser, def = LibStub("AceSerializer-3.0"), LibStub("LibDeflate")
  local data = { v = 1, rows = { ["A row from the future"] = "Yes", ["Gathering pin size"] = "Enormous" } }
  OTHER = "MO1!" .. def:EncodeForPrint(def:CompressDeflate(ser:Serialize(data)))
  R2 = MO.Share.Import(OTHER)
''')
res["a row not here and a value no longer a choice: both skipped, nothing changed"] = E("R2.set == 0 and R2.skipped == 2 and GPS.get() == WAS") is True
L('R3, WHY3 = MO.Share.Import("hello")')
res["not a Master Options code: refused, says so"] = E("R3 == nil and WHY3:find('MO1!') ~= nil") is True
L('R4, WHY4 = MO.Share.Import(CODE:sub(1, #CODE - 12))')
res["cut short: refused, says so"] = E("R4 == nil and type(WHY4) == 'string'") is True
L('R5, WHY5 = MO.Share.Import("MO1!" .. string.rep("a", 40))')
res["garbage after the prefix: refused, says so"] = E("R5 == nil and type(WHY5) == 'string'") is True
res["no errors"] = E("#ERRORS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
