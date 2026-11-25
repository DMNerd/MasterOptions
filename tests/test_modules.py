import sys
from lupa import LuaRuntime

lua = LuaRuntime()
lua.execute(r'''
FR, REPORTED, RAN = {}, {}, {}
function CreateFrame() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:UnregisterEvent(e) self.ev[e] = nil end function f:SetScript(k, fn) self[k] = fn end FR[#FR+1] = f return f end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function UnitName() return "Testchar", "Doe" end
LOADED = { Mastercraft = true, GearMatic = true }
INSTALLED = { MasterOptions_GearMatic_Forever = true }   -- (an old patch folder still there and enabled)
C_AddOns = {
  IsAddOnLoaded = function(n) return LOADED[n] == true end,
  GetAddOnInfo = function(n) if INSTALLED[n] then return n, n, "", true, nil else return nil, nil, nil, nil, "MISSING" end end,
  GetAddOnEnableState = function(n) return INSTALLED[n] and 2 or 0 end,
}
function MasterOptions_ReportError(a, w, e) REPORTED[#REPORTED+1] = a .. "|" .. w end
''')
lua.eval("function(s) local f, e = load(s, '=Modules'); if not f then error(e) end; return f end")(open(sys.argv[1], encoding="utf-8").read())("MasterOptions")
L, E = lua.execute, lua.eval
L(r'''
MasterOptions_Module("Mastercraft_Keep", { "Mastercraft" }, function(ADDON) RAN.keep = ADDON end)
MasterOptions_Module("Mastercraft_Chattynator", { "Mastercraft", "Chattynator" }, function() RAN.chat = true end)
MasterOptions_Module("GearMatic_Forever", { "GearMatic" }, function() RAN.forever = true end)
MasterOptions_Module("Mastercraft_BankMats", { "Mastercraft" }, function() RAN.bank = true end)
MasterOptions_Module("Mastercraft_VendorSell", { "Mastercraft" }, function() error("boom") end)
MasterOptionsDB = { modulesOff = { Mastercraft_BankMats = true } }
''')
fails = []
def check(name, got, want):
    ok = got == want
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else "  got %r want %r" % (got, want)))
    if not ok: fails.append(name)

check("nothing runs before Master Options has loaded", E("next(RAN) == nil"), True)
L('Fire("ADDON_LOADED", "Mastercraft")')
check("another addon's load doesn't start them", E("next(RAN) == nil"), True)
L('Fire("ADDON_LOADED", "MasterOptions")')
M = "MasterOptions_Modules"
check("runs when its addons are loaded, named as the old patch", E("RAN.keep"), "MasterOptions_Mastercraft_Keep")
check("running", E(M + ".IsActive('MasterOptions_Mastercraft_Keep')"), True)
check("an addon it needs is missing: not run, says which", (E("RAN.chat"), E(M + ".State('Mastercraft_Chattynator')")), (None, "needs Chattynator"))
check("old patch folder installed: stands aside", (E("RAN.forever"), E(M + ".State('GearMatic_Forever')")), (None, "old folder"))
check("turned off in /mo: not run", (E("RAN.bank"), E(M + ".State('Mastercraft_BankMats')")), (None, "off"))
check("an error starting it: reported, marked", (E(M + ".State('Mastercraft_VendorSell')"), E("REPORTED[1]")), ("error", "MasterOptions_Mastercraft_VendorSell|starting"))
check("runs once", (L('Fire("ADDON_LOADED", "MasterOptions")'), E("RAN.keep"))[1], "MasterOptions_Mastercraft_Keep")
L(M + ".SetEnabled('Mastercraft_Keep', false)")
check("turning off: kept for the next load", (E(M + ".IsEnabled('Mastercraft_Keep')"), E("MasterOptionsDB.modulesOff.Mastercraft_Keep")), (False, True))
L(M + ".SetEnabled('Mastercraft_Keep', true)")
check("turning on again", E(M + ".IsEnabled('Mastercraft_Keep')"), True)

if fails:
    print("ERRORS: %d" % len(fails)); sys.exit(1)
print("ERRORS: 0")
