# OpenMap_QuestieTownsfolk: the kinds Questie's townsfolk menu has too are taken out of OpenMap's list of kinds (its
# Townsfolk menu, search and drawing all read it), in place; a kind on in OpenMap moves to Questie's menu; with "Town
# NPC icons" on OpenMap + game's tracking they're all back, in OpenMap's order.
import sys
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test, module_source, fake_frames
src = module_source(sys.argv[1])
lua = module_test(sys.argv[1])
fake_frames(lua, timers_now=True)
lua.execute(r'''
  unpack = unpack or table.unpack
  function UnitName() return "Test", "Char" end
  function GetRealmName() return "" end
  MasterOptionsDB = {}

  -- OpenMap: its kinds (Townsfolk.lua's KINDS = mod.TOWNSFOLK), their settings, pin sets and refreshes
  KINDS = {}
  for _, k in ipairs({ "vendor", "repair", "innkeeper", "banker", "mailbox", "auctioneer", "stable", "classTrainer", "profTrainer", "spirit", "rare" }) do
    KINDS[#KINDS + 1] = { key = k }
  end
  TF_REFRESH, PANEL = 0, 0
  WM = { TOWNSFOLK = KINDS, db = { townsfolk = { banker = true, vendor = true } } }
  function WM:RefreshTownsfolk() TF_REFRESH = TF_REFRESH + 1 end
  function WM:RefreshPanel() PANEL = PANEL + 1 end
  SETS = {}
  OpenMap = { GetModule = function(_, n) if n == "worldmap" then return WM end end,
              MapStitch = { GetPinSet = function(n) SETS[n] = SETS[n] or { on = true }; return SETS[n] end,
                            SetPinSetOn = function(set, on) set.on = on end } }
  -- Questie: its townsfolk settings and its redraw
  Questie = { db = { profile = { townsfolkConfig = { Repair = true } } } }
  QCFG = Questie.db.profile.townsfolkConfig
  REDRAWS = 0
  QuestieLoader = { ImportModule = function(_, n) if n == "QuestieMenu" then return { OnLogin = function() REDRAWS = REDRAWS + 1 end } end end }
  function Keys() local t = {}; for _, k in ipairs(KINDS) do t[#t + 1] = k.key end; return table.concat(t, ",") end
''')
lua.eval("function(s) return load(s, '=omtownsfolk') end")(src)("MasterOptions_OpenMap_QuestieTownsfolk")
E, L = lua.eval, lua.execute
res = {}

res["Questie's kinds out of OpenMap's list (vendors, profession trainers, rare mobs stay), in its order"] = E("Keys()") == "vendor,profTrainer,rare"
res["the same table OpenMap's files hold (changed in place)"] = E("WM.TOWNSFOLK == KINDS")
res["a kind on in OpenMap (banker): on in Questie's menu instead, off in OpenMap, its pins hidden"] = E(
    'QCFG.Banker == true and WM.db.townsfolk.banker == false and SETS.tf_banker.on == false')
res["...Questie redrawn, OpenMap's townsfolk and menu refreshed"] = E("REDRAWS") == 1 and E("TF_REFRESH") >= 1 and E("PANEL") >= 1
res["OpenMap's own kinds left as they were (vendors on)"] = E("WM.db.townsfolk.vendor == true")

L('Fire("PLAYER_LOGIN")')
res["login: nothing changes twice (no second redraw)"] = E("REDRAWS") == 1 and E("Keys()") == "vendor,profTrainer,rare"

# Town NPC icons on OpenMap + game's tracking: OpenMap's are the ones in use - all back
L('MasterOptionsDB.townOpenMap = { ["Test Char-"] = true }; MasterOptions_OpenMapTownsfolk.Apply()')
res["OpenMap + game's tracking: every kind back, in OpenMap's order"] = E("Keys()") == "vendor,repair,innkeeper,banker,mailbox,auctioneer,stable,classTrainer,profTrainer,spirit,rare"
res["...not hidden"] = E("MasterOptions_OpenMapTownsfolk.Hidden()") is False
L('MasterOptionsDB.townOpenMap = {}; MasterOptions_OpenMapTownsfolk.Apply()')
res["another choice: taken out again"] = E("Keys()") == "vendor,profTrainer,rare" and E("MasterOptions_OpenMapTownsfolk.Hidden()") is True
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
