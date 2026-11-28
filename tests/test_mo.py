import sys, os
from lupa import LuaRuntime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # (run with -I)
from wow_harness import fake_wow

scratch = os.path.dirname(os.path.abspath(__file__))
mo_path = sys.argv[1]
lua = LuaRuntime(unpack_returned_tuples=True)
fake_wow(lua, scratch, extra_addons=[], rows_visible=True)

lua.execute(r'''
Baganator = { API = { RequestItemButtonsRefresh = function() end } }
CheapUpgrades = {}
SlashCmdList.PAWN_FOREVER = function(m) print("/pff " .. m) end
-- the NeverSell module's API (Modules\NeverSell.lua), faked: its own sync is tested in test_neversell.py
NS_LIST = { [2589] = true, [2770] = true, [4306] = true }
NS_SET = {}
MasterOptions_NeverSell = {
  List = function() local o = {} for id in pairs(NS_LIST) do o[#o + 1] = id end table.sort(o) return o end,
  Sources = function() return { "GearMatic", "Mastercraft" } end,
  Set = function(id, on) NS_SET[#NS_SET + 1] = tostring(id) .. "=" .. tostring(on); NS_LIST[id] = on or nil end,
  Sync = function() end,
}
C_Item = { GetItemInfo = function(id) if id == 2589 then return "Linen Cloth", "|cffffffff|Hitem:2589|h[Linen Cloth]|h|r" end end,
           GetItemIconByID = function() return 132889 end }
''')

loader = lua.eval("function(src, name) local f, e = load(src, '=' .. name); if not f then error(e) end; return f end")
errlog = os.path.join(os.path.dirname(mo_path), "ErrorLog.lua")
if os.path.exists(errlog):  # (loaded first, as the .toc does)
    loader(open(errlog, encoding="utf-8").read(), "ErrorLog.lua")("MasterOptions")
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, mo_path)
# (the module loader and its command registry, loaded before Shared.lua in the .toc; no modules here)
lua.eval("function(s) return load(s, '=Modules.lua') end")(open(_os.path.join(_os.path.dirname(_os.path.abspath(mo_path)), "Modules.lua"), encoding="utf-8").read())()
from shared_lua import load_master_options; load_master_options(lua, mo_path) # (MasterOptions.lua ... Startup.lua)
L = lua.execute
# a module whose addon loads after Master Options (not loaded when the modules start): it doesn't start
L('ENABLED.LateAddon = true; MasterOptions_Module("Test_Late", { "LateAddon" }, function() STARTED = true end)')
L('Fire("ADDON_LOADED", "MasterOptions")')
L('LOADED.LateAddon = true') # (it loads after)
# an error from a patch, so Problems has its error row (Copy / Clear get clicked below)
L('if MasterOptions_ReportError then MasterOptions_ReportError("MasterOptions_Mastercraft_Keep", "test", "Keep.lua:1: test error") end')
L('Fire("PLAYER_LOGIN")')
L('RunTimers(); RunTimers()')
# open the window and click every row
L(r'''
  MasterOptionsFrame:Show()
  ClickAndHoverAll()
  Fire("PLAYER_LOGOUT")
''')
# the Never sell section: its rows (clicking every button above pressed their Remove), the header, adding from the box
# Thanks: its own section, last, with every author
thanks = lua.eval('(function() for _, f in ipairs(FRAMES) do if type(f._text) == "string" and f._text:find("Shadowblade") and f._text:find("plusmouse") and f._text:find("Thank you") then return true end end end)()')
side = lua.eval('(function() for _, f in ipairs(FRAMES) do if f._text == "Thanks" then return true end end end)()')
print("thanks section:", thanks, "side button:", side)
if not (thanks and side):
    lua.execute('ERRORS[#ERRORS+1] = "Thanks section missing"')
ns_header = lua.eval('(function() for _, f in ipairs(FRAMES) do if type(f._text) == "string" and f._text:find("never sold") then return f._text end end end)()')
ns_removed = lua.eval('table.concat(NS_SET, ",")')
print("never sell: header", repr((ns_header or "")[:60]), "| set calls:", ns_removed)
lua.execute(r'''
  NS_LIST[999] = nil
  for _, f in ipairs(FRAMES) do
    if f.scripts.OnEnterPressed and f.SetText then f:SetText("|cff9d9d9d|Hitem:999::::|h[Thing]|h|r"); f.scripts.OnEnterPressed(f) end
  end
''')
ns_added = lua.eval("NS_LIST[999] == true")
print("never sell: add from the box (item link)", ns_added)
# an item dragged onto the box (GetCursorInfo returns "item", itemID)
lua.execute(r'''
  CURSOR_CLEARED = false
  function GetCursorInfo() return "item", 777 end
  function ClearCursor() CURSOR_CLEARED = true end
  for _, f in ipairs(FRAMES) do if f.scripts.OnReceiveDrag then f.scripts.OnReceiveDrag(f) end end
  GetCursorInfo, ClearCursor = nil, nil
''')
ns_dragged = lua.eval("NS_LIST[777] == true and CURSOR_CLEARED")
print("never sell: item dragged onto the box", ns_dragged)
if not (ns_header and "item" in ns_header and "2589=false" in ns_removed and ns_added and ns_dragged):
    lua.execute('ERRORS[#ERRORS+1] = "Never sell section wrong"')

# Pawn without Pawn Forever shows up under Problems (not installed: no button; disabled: Enable)
lua.execute(r'''
  function ProblemText(pat)
    for _, f in ipairs(FRAMES) do if type(f._text) == "string" and f._text:find(pat) then return f end end
  end
  function Reopen() MasterOptionsFrame:Hide(); for _, f in ipairs(FRAMES) do f._text = nil end; MasterOptionsFrame:Show() end
  function ShowsProblem(pat) Reopen(); return ProblemText(pat) ~= nil end
''')
pf_before = lua.eval('ShowsProblem("Pawn Forever is disabled") or ShowsProblem("installed without Pawn Forever")')
lua.execute('LOADED.Pawn_Forever = nil; ENABLED.Pawn_Forever = nil')
pf_missing = lua.eval('ShowsProblem("installed without Pawn Forever")')
lua.execute('ENABLED.Pawn_Forever = false')
pf_off = lua.eval('ShowsProblem("Pawn Forever is disabled")')
print("Pawn Forever problem: installed+loaded", pf_before, "/ missing", pf_missing, "/ disabled", pf_off)
if pf_before or not pf_missing or not pf_off:
    lua.execute('ERRORS[#ERRORS+1] = "Pawn Forever problem row wrong"')
lua.execute('LOADED.Pawn_Forever = true; ENABLED.Pawn_Forever = true')
# Sparkles_Forever with Mastercraft: the bobber mark that can't show, and tracking switching under "While tracking" pins
lua.execute('LOADED.Sparkles_Forever = true; SparklesDB = { sparkleBobber = true, minimapResources = true, minimapAutoAlternate = false }; MastercraftDB.settings.fishMarker = true; MastercraftDB.settings.nodesWhen = nil')
sp_ok = not lua.eval('ShowsProblem("bobber isn\'t marked") or ShowsProblem("Switch Herbs and Ore")')
lua.execute('SparklesDB.sparkleBobber = false; SparklesDB.minimapAutoAlternate = true')
sp_bob = lua.eval('ShowsProblem("bobber isn\'t marked")')
sp_alt = lua.eval('ShowsProblem("Switch Herbs and Ore")')
lua.execute('MastercraftDB.settings.nodesWhen = "always"')
sp_alt_always = lua.eval('ShowsProblem("Switch Herbs and Ore")')
print("Sparkles problems: none when fine", sp_ok, "/ bobber", sp_bob, "/ switching", sp_alt, "/ switching with Always", sp_alt_always)
if not (sp_ok and sp_bob and sp_alt and not sp_alt_always):
    lua.execute('ERRORS[#ERRORS+1] = "Sparkles problem rows wrong"')
# Sparkles' corpse enemy plates while BetterBlizzPlates keeps enemy plates off in a toggle set (and picks changes up)
lua.execute('LOADED.BetterBlizzPlates = true; BBP_WAS = BetterBlizzPlatesDB; SparklesDB.corpseEnemyPlates = true; '
            'BetterBlizzPlatesDB = { nameplateToggles_pve = { nameplateShowEnemies = true }, nameplateToggles_pvp = { nameplateShowEnemies = true } }')
cp_on_everywhere = lua.eval('ShowsProblem("lends enemy nameplates")')
lua.execute('BetterBlizzPlatesDB.nameplateToggles_pve.nameplateShowEnemies = false')
cp_off_somewhere = lua.eval('ShowsProblem("lends enemy nameplates")')
lua.execute('BetterBlizzPlatesDB.avoidCVarPickup = true')
cp_no_pickup = lua.eval('ShowsProblem("lends enemy nameplates")')
lua.execute('BetterBlizzPlatesDB = BBP_WAS')
print("Sparkles corpse plates vs BetterBlizzPlates: enemy plates on everywhere", cp_on_everywhere, "/ off in a set", cp_off_somewhere, "/ BBP not picking changes up", cp_no_pickup)
if not (not cp_on_everywhere and cp_off_somewhere and not cp_no_pickup):
    lua.execute('ERRORS[#ERRORS+1] = "Sparkles corpse plates problem wrong"')
lua.execute('SparklesDB = nil; MastercraftDB.settings.nodesWhen = nil')
# GearMatic's gold coin vendor badge next to Baganator's junk coin: a problem, fixed by "Use Gold $"
lua.execute('GearMatic.db.profile.vendorMarkerStyle = "dollar"; GearMatic.db.profile.bestGoldShowVendor = nil')
coin_ok = not lua.eval('ShowsProblem("same icon as Baganator")')
lua.execute('GearMatic.db.profile.vendorMarkerStyle = "coin"')
coin_on = lua.eval('ShowsProblem("same icon as Baganator")')
lua.execute('GearMatic.db.profile.bestGoldShowVendor = false')
coin_hidden = lua.eval('ShowsProblem("same icon as Baganator")')
print("vendor coin problem: none with $", coin_ok, "/ coin", coin_on, "/ badge off", coin_hidden)
if not (coin_ok and coin_on and not coin_hidden):
    lua.execute('ERRORS[#ERRORS+1] = "Vendor coin problem row wrong"')
lua.execute('GearMatic.db.profile.vendorMarkerStyle = nil; GearMatic.db.profile.bestGoldShowVendor = nil')
# companion addons made for one version of the addon they extend: BetterBetterBlizzPlates, QuestieDB
lua.execute(r"""
  META = { BetterBetterBlizzPlates = { ["X-BetterBlizzPlates-Version"] = "2.2.5c" }, BetterBlizzPlates = { Version = "v2.2.5c" },
           Questie = { ["X-QuestieDB-Contract"] = "4" }, QuestieDB = { Version = "1.1.6" } }
  C_AddOns.GetAddOnMetadata = function(n, k) return META[n] and META[n][k] end
  LOADED.BetterBetterBlizzPlates, LOADED.BetterBlizzPlates = true, true
  ENABLED.BetterBetterBlizzPlates, ENABLED.BetterBlizzPlates = true, true
  LOADED.Questie, LOADED.QuestieDB, ENABLED.Questie, ENABLED.QuestieDB = true, true, true, true
  CONTRACT_OK = true
  LibQuestieDB = { RequireContract = function(n) if CONTRACT_OK and n == 4 then return true end return false, "nope" end }
""")
comp = {}
comp["matching versions: nothing to say"] = not lua.eval('ShowsProblem("made for BetterBlizzPlates") or ShowsProblem("QuestieDB")')
lua.execute('META.BetterBlizzPlates.Version = "v2.2.6"')
comp["BetterBlizzPlates updated first: its companion's window stays closed, said so"] = lua.eval('ShowsProblem("made for BetterBlizzPlates 2.2.5c, and you have 2.2.6")') is True
lua.execute('META.BetterBlizzPlates.Version = "v2.2.5c"; CONTRACT_OK = false')
comp["QuestieDB without Questie's contract: said so"] = lua.eval('ShowsProblem("data contract 4, which QuestieDB 1.1.6")') is True
lua.execute('CONTRACT_OK = true; LOADED.QuestieDB = false; ENABLED.QuestieDB = false')
comp["QuestieDB turned off: said so"] = lua.eval('ShowsProblem("QuestieDB is turned off")') is True
lua.execute('ENABLED.QuestieDB = nil')
comp["QuestieDB not installed: said so"] = lua.eval('ShowsProblem("QuestieDB isn.t installed")') is True
lua.execute(r"""
  LOADED.QuestieDB, ENABLED.QuestieDB = true, true
  LOADED.BetterBetterBlizzPlates, LOADED.BetterBlizzPlates, LOADED.Questie = nil, nil, nil
  C_AddOns.GetAddOnMetadata, LibQuestieDB = nil, nil
""")
lua.execute('MasterOptionsDB.ignoredProblems["latemodule:Test_Late"] = nil') # (every button was clicked above, Ignore too)
comp["a module whose addon loaded after Master Options: said so"] = (lua.eval('STARTED') is None
    and lua.eval('ShowsProblem("Test_Late didn.t start: LateAddon loaded after")') is True)
print("companion versions:", comp)
if not all(comp.values()):
    lua.execute('ERRORS[#ERRORS+1] = "Companion version problems wrong"')
# one judge for every Pawn-or-GearMatic recommendation: Pawn with Pawn Forever, GearMatic without it
lua.execute(r"""
  function CountText(t) Reopen(); local n = 0 for _, f in ipairs(FRAMES) do if f._text == t then n = n + 1 end end return n end
  GM_WAS = GearMatic.db.profile.usePawnWeights
  GearMatic.db.profile.usePawnWeights = false
  LOADED.Pawn, LOADED.Pawn_Forever = true, true
  WITH_PF = CountText("GearMatic's own *") .. "/" .. CountText("GearMatic's own")
  LOADED.Pawn_Forever = nil
  WITHOUT_PF = CountText("GearMatic's own *") .. "/" .. CountText("GearMatic's own")
  LOADED.Pawn_Forever = true
  GearMatic.db.profile.usePawnWeights = GM_WAS
""")
judge_with, judge_without = lua.eval("WITH_PF"), lua.eval("WITHOUT_PF")
print("one judge: GearMatic's own weights recommended (starred/plain) with Pawn Forever", judge_with, "/ without", judge_without)
if not (judge_with == "0/1" and judge_without == "1/0"):
    lua.execute('ERRORS[#ERRORS+1] = "Recommendations not following the judge"')

print("synced:", lua.eval("MasterOptionsDB.syncChars"), "shared:", lua.eval("(function() local o = {} for k, v in pairs(MasterOptionsDB.shared or {}) do o[#o+1] = k .. '=' .. tostring(v) end table.sort(o) return table.concat(o, '; ') end)()"))
print("errlog rows:", lua.eval("MasterOptions_ErrorLog and MasterOptions_ErrorLog.Count()"), "copy window:", lua.eval("MasterOptionsErrorFrame ~= nil"))
# /mo <word>: a module's own command (registered while it runs), /mo help, an unknown word
lua.execute(r"""
  GOT = nil
  MasterOptions_Shared.Command("testcmd", function(rest) GOT = rest end, "testcmd <x> - a test")
  local p = print; SAID = {}; print = function(...) SAID[#SAID + 1] = table.concat({ ... }, " ") end
  SlashCmdList.MASTEROPTIONS("TestCmd  some thing")
  SlashCmdList.MASTEROPTIONS("help")
  HELP = table.concat(SAID, "\n"); SAID = {}
  WAS_SHOWN = MasterOptionsFrame:IsShown()
  SlashCmdList.MASTEROPTIONS("nosuchword")
  UNKNOWN = table.concat(SAID, "\n")
  STILL = MasterOptionsFrame:IsShown() == WAS_SHOWN
  print = p
""")
cmds = {
    "a module's command gets the rest of the line": lua.eval("GOT") == "some thing",
    "/mo help lists it and the core ones": "/mo testcmd <x> - a test" in lua.eval("HELP") and "/mo arrow" in lua.eval("HELP"),
    "an unknown word says so (the window left as it was)": "no command" in lua.eval("UNKNOWN") and lua.eval("STILL") is True,
}
print("commands:", cmds)
if not all(cmds.values()):
    lua.execute('ERRORS[#ERRORS+1] = "/mo commands wrong"')
errs = lua.eval("ERRORS")
print("ERRORS:", len(errs))
for i in range(1, len(errs) + 1):
    print("  ", errs[i])
