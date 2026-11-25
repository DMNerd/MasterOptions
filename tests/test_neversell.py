# NeverSell: one never-sell list kept the same in GearMatic (sellIgnore), Mastercraft (lootNever) and
# DeleteCheapestItem (IgnoredItems, per character) - both ways, our own modules' automatic entries left out.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, TIMERS = {}, {}
  function CreateFrame() local f = { RegisterEvent = function() end, SetScript = function(self, k, fn) self[k] = fn end }; FRAMES[#FRAMES + 1] = f; return f end
  C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = fn end }
  function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
  function Fire(ev) for _, f in ipairs(FRAMES) do if f.OnEvent then f.OnEvent(f, ev) end end end
  function Tick() for _, f in ipairs(FRAMES) do if f.OnUpdate then f.OnUpdate(f, 3) end end end
  function InCombatLockdown() return false end
  CHAR = "Testchar Alpha"
  function UnitName() local a, b = CHAR:match("^(%S+) (%S+)$"); return a, b end
  LOADED = { GearMatic = true, Mastercraft = true, DeleteCheapestItem = true }
  C_AddOns = { IsAddOnLoaded = function(n) return LOADED[n] == true end }
  REFRESHED = 0
  GearMatic = { RefreshSellIgnoreSurfaces = function() REFRESHED = REFRESHED + 1 end }
  -- 101: yours in GearMatic; 102: Mastercraft_Keep's automatic entry; 201: yours in Mastercraft
  GearMaticDB = { sellIgnore = { [101] = true, [102] = true }, moKeep = { [102] = true } }
  MastercraftDB = { settings = { lootNever = { [201] = true } } }
  -- 301: yours in DeleteCheapestItem; 302: the Protect module's automatic entry
  CHARDB = { ["Testchar Alpha"] = { IgnoredItems = { 301, 302 }, moProtected = { [302] = true } },
             ["Testchar Beta"] = { IgnoredItems = { 401 } } }
  DCI_CharDB = CHARDB[CHAR]
  function Has(list, id) for _, v in ipairs(list) do if v == id then return true end end return false end
  function Everywhere(id)
    return GearMaticDB.sellIgnore[id] == true and MastercraftDB.settings.lootNever[id] == true and Has(DCI_CharDB.IgnoredItems, id)
  end
  function Nowhere(id)
    return not GearMaticDB.sellIgnore[id] and not MastercraftDB.settings.lootNever[id] and not Has(DCI_CharDB.IgnoredItems, id)
  end
  function Login(char) CHAR = char; DCI_CharDB = CHARDB[char]; Fire("PLAYER_LOGIN"); RunTimers() end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_NeverSell")
L, E = lua.execute, lua.eval
res = {}
L('Login("Testchar Alpha")')
res["first sync: union of your entries, everywhere"] = E("Everywhere(101) and Everywhere(201) and Everywhere(301)")
res["Keep's and Protect's automatic entries not taken in"] = E("MasterOptionsDB.neverSell[102] == nil and MasterOptionsDB.neverSell[302] == nil and not MastercraftDB.settings.lootNever[102] and not MastercraftDB.settings.lootNever[302]")
res["their automatic entries left where they were"] = E("GearMaticDB.sellIgnore[102] == true and GearMaticDB.moKeep[102] == true and Has(DCI_CharDB.IgnoredItems, 302)")
res["GearMatic's surfaces refreshed after a change"] = E("REFRESHED > 0")
L('GearMaticDB.sellIgnore[500] = true; Tick()')
res["added in GearMatic -> everywhere"] = E("Everywhere(500)")
L('MastercraftDB.settings.lootNever[201] = nil; Tick()')
res["removed in Mastercraft -> removed everywhere"] = E("Nowhere(201) and MasterOptionsDB.neverSell[201] == nil")
L('for i = #DCI_CharDB.IgnoredItems, 1, -1 do if DCI_CharDB.IgnoredItems[i] == 101 then table.remove(DCI_CharDB.IgnoredItems, i) end end; Tick()')
res["removed in DeleteCheapestItem -> removed everywhere"] = E("Nowhere(101)")
L('MasterOptions_NeverSell.Set(600, true)')
res["/mo never <item> -> everywhere at once"] = E("Everywhere(600)")
L('MasterOptions_NeverSell.Set(102, true)')
res["you add Keep's item yourself: yours now (Keep lets go of it)"] = E("Everywhere(102) and GearMaticDB.moKeep[102] == nil")
L('MasterOptions_NeverSell.Set(600, false)')
res["/mo never remove -> gone everywhere"] = E("Nowhere(600)")
L('Tick(); Tick()')
res["steady: nothing changes by itself"] = E("Everywhere(500) and Everywhere(102) and Everywhere(301) and Nowhere(201)")
# another character: its own DeleteCheapestItem list catches up; its own entry joins in
L('Login("Testchar Beta")')
res["other character: its list catches up and its entry (401) joins everywhere"] = E("Everywhere(500) and Everywhere(301) and Everywhere(401) and Nowhere(201)")
L('Login("Testchar Alpha")')
res["back on the first character: Beta's entry arrives in its list"] = E("Has(DCI_CharDB.IgnoredItems, 401)")
# DeleteCheapestItem 1.9's one-time migration replaces a character's list (schemaVersion appears): the entries
# that vanish must not be taken as removals everywhere
L('DCI_CharDB.IgnoredItems = { 301 }; DCI_CharDB.schemaVersion = 1; Tick()')
res["DeleteCheapestItem migration: its replaced list isn't read as removals"] = E("Everywhere(500) and Everywhere(102) and Everywhere(401) and Has(DCI_CharDB.IgnoredItems, 500)")
L('LOADED.Mastercraft = false; MastercraftDB.settings.lootNever = { }; GearMaticDB.sellIgnore[700] = true; Tick()')
res["an addon not loaded is left alone (not wiped, not read)"] = E("Everywhere == Everywhere and GearMaticDB.sellIgnore[700] == true and next(MastercraftDB.settings.lootNever) == nil")
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
