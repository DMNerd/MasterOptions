# GearMatic_SellGuard: Master Options' guard in GearMatic's VendorAutomation.RegisterSellGuard keeps the
# never-sell list, Mastercraft_Keep's needed materials and Pawn's upgrades / best items; an error keeps too.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  GUARDS = {}
  GearMatic = { VendorAutomation = { RegisterSellGuard = function(name, fn) GUARDS[name] = fn; return true end } }
  MasterOptions_NeverSell = { Has = function(id) return id == 100 end }
  MasterOptions_MastercraftKeep = { IsNeeded = function(id) return id == 200 end }
  -- Pawn: 300 an upgrade, 400 already your best (3rd return), 500 nothing, 666 errors
  function PawnGetItemData(link) return { id = tonumber(link:match("item:(%d+)")) } end
  function PawnIsItemAnUpgrade(item)
    if item.id == 300 then return { { "s", "S", 0.1 } } end
    if item.id == 400 then return nil, nil, { s = true } end
    if item.id == 666 then error("boom") end
  end
  ERRS = 0
  function MasterOptions_ReportError() ERRS = ERRS + 1 end
  function Link(id) return "|cff|Hitem:" .. id .. "::::|h[x]|h|r" end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_GearMatic_SellGuard")
E = lua.eval
res = {
    "registered with GearMatic as 'MasterOptions'": E("GUARDS.MasterOptions ~= nil"),
    "never-sell list kept": E("GUARDS.MasterOptions(Link(100)) == true"),
    "Mastercraft_Keep's needed material kept": E("GUARDS.MasterOptions(Link(200)) == true"),
    "Pawn upgrade kept": E("GUARDS.MasterOptions(Link(300)) == true"),
    "Pawn's best item for a scale kept": E("GUARDS.MasterOptions(Link(400)) == true"),
    "anything else left to GearMatic": E("GUARDS.MasterOptions(Link(500)) == false"),
}
res["Pawn erroring: no error out of the guard (Pawn's call is caught), item left to GearMatic"] = E("GUARDS.MasterOptions(Link(666)) == false")
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
