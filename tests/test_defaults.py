import sys, os
from lupa import LuaRuntime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # (run with -I)
from wow_harness import fake_wow, fake_settings, fake_pawn_forever

scratch = os.path.dirname(os.path.abspath(__file__))
mo_path = sys.argv[1]
lua = LuaRuntime(unpack_returned_tuples=True)
fake_wow(lua, scratch, extra_addons=['ShortestPathForever'], rows_visible=False)
fake_settings(lua)
fake_pawn_forever(lua)

lua.execute(r'''
Baganator = { API = { RequestItemButtonsRefresh = function() end } }
CheapUpgrades = {}
SlashCmdList.PAWN_FOREVER = function(m) print("/pff " .. m) end
''')

# Upgrade path: a character last set up at defaults version 22 gets only the rows added since (the Fishing bobber
# mark, since 23) - its own older choices stay as they are.
lua.execute(r'''
  MasterOptionsDB.applied["Testchar Alpha-"] = 22
  SparklesDB = { sparkleBobber = true }
  MastercraftDB.settings.fishMarker = true      -- both marks on: the new row's recommendation (Sparkles) applies
  MastercraftDB.settings.nodesWhen = "always"   -- an older row (since 2), recommended "While tracking": must stay
  -- BetterBlizzFrames' classic minimap and minimap tweaks on, with OpenMap_MiniMap loaded: the new Minimap row applies
  BetterBlizzFramesDB.classicMinimap = true; BetterBlizzFramesDB.foreverMinimapTweaks = true
  -- Pawn's and GearMatic's quest reward markers both on: the new Quest reward marker row (Pawn) applies
  PawnCommon.ShowQuestUpgradeAdvisor = true; GearMaticDB.profiles.Default.autoDetectQuestReward = true
''')
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, mo_path)
from shared_lua import load_master_options; load_master_options(lua, mo_path) # (MasterOptions.lua ... Startup.lua)
L = lua.execute
L('Fire("ADDON_LOADED", "MasterOptions")')
L('Fire("PLAYER_LOGIN")')
L('RunTimers(); RunTimers()')
res = {
    "new row applied: Sparkles' bobber effect on": lua.eval("SparklesDB.sparkleBobber") is True,
    "new row applied: Mastercraft's bobber mark off": lua.eval("MastercraftDB.settings.fishMarker") is False,
    "older row left alone (When nodes show stays Always)": lua.eval("MastercraftDB.settings.nodesWhen") == "always",
    "character moved up to the current defaults version": lua.eval('MasterOptionsDB.applied["Testchar Alpha-"]') > 22,
    "Quest reward marker applied: Pawn's on, GearMatic's off (its autoDetect untouched)": lua.eval(
        "PawnCommon.ShowQuestUpgradeAdvisor == true and GearMaticDB.profiles.Default.autoDetectQuestReward == false and GearMaticDB.profiles.Default.autoDetect ~= false") is True,
    "Minimap row applied: BetterBlizzFrames' minimap options off, its button tint skipped": lua.eval("BetterBlizzFramesDB.classicMinimap == false and BetterBlizzFramesDB.foreverMinimapTweaks == false and BetterBlizzFramesDB.SkipMinimapForeverTint == true") is True,
}
# picking BetterBlizzFrames' classic minimap in the row: its classic on, OpenMap_MiniMap disabled for the next load
lua.execute(r'''
  for _, s in ipairs(SETTINGS) do if s.name == "Minimap" then MINIMAP = s end end
  if MINIMAP then MINIMAP.set("BetterBlizzFrames classic") end
''')
res["Minimap row: BetterBlizzFrames classic -> its classic on, OpenMap_MiniMap disabled, row reads it back"] = lua.eval(
    'MINIMAP ~= nil and BetterBlizzFramesDB.classicMinimap == true and C_AddOns.GetAddOnEnableState("OpenMap_MiniMap") == 0 and MINIMAP.get() == "BetterBlizzFrames classic"') is True
lua.execute('if MINIMAP then MINIMAP.set("OpenMap_MiniMap") end')
res["Minimap row: back to OpenMap_MiniMap -> enabled again, BetterBlizzFrames' classic off"] = lua.eval(
    'C_AddOns.GetAddOnEnableState("OpenMap_MiniMap") == 2 and BetterBlizzFramesDB.classicMinimap == false and MINIMAP.get() == "OpenMap_MiniMap"') is True
lua.execute('BetterBlizzFramesDB.hideMinimapAuto = true')
res["Minimap row: BetterBlizzFrames' hide-in-arena on (it hides the whole minimap area) -> a conflict"] = lua.eval('MINIMAP.get() == "Both (conflict)"') is True
lua.execute('MINIMAP.set("OpenMap_MiniMap")')
res["...OpenMap_MiniMap picked: its arena hiding off too"] = lua.eval('BetterBlizzFramesDB.hideMinimapAuto == false and MINIMAP.get() == "OpenMap_MiniMap"') is True
# Baganator: picking "Greys only" junk coins must survive a plugin registering later (its AutoSet) - so
# the other plugins go on its junk_plugin_ignored list, as its own settings window does
lua.execute(r'''
  for _, s in ipairs(SETTINGS) do if s.name:find("^Junk coin in bags") then JUNK = s end end
  local p = BAGANATOR_CONFIG.Profiles[BAGANATOR_CURRENT_PROFILE or "DEFAULT"] or BAGANATOR_CONFIG.Profiles.DEFAULT
  BAGP = p
  if JUNK then JUNK.set("Greys only") end
''')
res["Junk coin 'Greys only': poor_quality chosen, GearMatic's and Mastercraft's plugins ignored by Baganator"] = lua.eval(
    'JUNK ~= nil and BAGP.junk_plugin == "poor_quality" and type(BAGP.junk_plugin_ignored) == "table" and BAGP.junk_plugin_ignored.gearmatic == true and BAGP.junk_plugin_ignored.mastercraft == true') is True
# Town NPC icons: OpenMap's world-map townsfolk are a third source - Questie + OpenMap on the same kind is a
# conflict; picking Questie turns OpenMap's off (the kinds move to Questie); Game's tracking leaves OpenMap's
lua.execute(r'''
  OMTOWN = { banker = true, mailbox = false, vendor = true }
  OM_REFRESHED = 0
  local wm = { db = { townsfolk = OMTOWN }, RefreshTownsfolk = function() OM_REFRESHED = OM_REFRESHED + 1 end }
  OpenMap = { GetModule = function() return wm end }
  Questie = { db = { profile = { townsfolkConfig = { Banker = true } } } }
  QTOWN = Questie.db.profile.townsfolkConfig
  for _, s in ipairs(SETTINGS) do if s.name:find("^Town NPC icons") then TOWN = s end end
''')
res["Town NPC icons: Questie + OpenMap on the same kind (Banker) = conflict"] = lua.eval('TOWN ~= nil and TOWN.get() == "Both (conflict)"')
lua.execute('if TOWN then TOWN.set("Questie") end')
res["Town NPC icons -> Questie: OpenMap's banker off, Questie keeps it; OpenMap's own kinds (vendors) untouched; OpenMap redrawn"] = lua.eval(
    'OMTOWN.banker == false and QTOWN.Banker == true and OMTOWN.vendor == true and OM_REFRESHED > 0 and TOWN.get() == "Questie"')
lua.execute('OMTOWN.mailbox = true')
res["Town NPC icons: a kind on only in OpenMap (not doubled) is no conflict, left as it is"] = lua.eval('TOWN.get() == "Questie" and OMTOWN.mailbox == true')
# 2.9.0's rows for things two addons both do (maps, routes, minimap)
lua.execute(r'''
  function Row(name) for _, s in ipairs(SETTINGS) do if s.name == name or s.name == name .. " (per char)" then return s end end end
  local wm = OpenMap.GetModule()
  wm.db.flight, wm.db.coords = true, true
  FLIGHTSET = { on = true }
  OpenMap.MapStitch = { GetPinSet = function(n) if n == "flight" then return FLIGHTSET end end, SetPinSetOn = function(set, on) set.on = on end }
  QTOWN["Flight Master"] = true
  Questie.db.profile.mapCoordinatesEnabled = true
  ShortestPathForeverDB = { arrow = true, arrowLabel = "distance" }
  OpenMapMiniMapDB = { profile = { gatherPins = true, pinFlights = true } }
  OMMP = OpenMapMiniMapDB.profile
  TRACK = { { name = "Flight Master", active = true }, { name = "Banker", active = false }, { name = "Mailbox", active = false } }
  C_Minimap = C_Minimap or {}
  C_Minimap.GetNumTrackingTypes = function() return #TRACK end
  C_Minimap.GetTrackingInfo = function(i) return TRACK[i] end
  C_Minimap.SetTracking = function(i, on) TRACK[i].active = on end
''')
E = lua.eval
res["Flight masters: OpenMap's and Questie's both on = conflict"] = E('Row("Flight masters").get() == "Both (conflict)"')
lua.execute('Row("Flight masters").set("OpenMap")')
res["Flight masters -> OpenMap: Questie's off, OpenMap's (and OpenMap_MiniMap's) on, the game's tracking off"] = E(
    'QTOWN["Flight Master"] == false and OpenMap.GetModule().db.flight == true and FLIGHTSET.on and OMMP.pinFlights == true and TRACK[1].active == false and Row("Flight masters").get() == "OpenMap"')
lua.execute('Row("Flight masters").set("Questie")')
res["Flight masters -> Questie: OpenMap's set hidden, OpenMap_MiniMap's off"] = E(
    'QTOWN["Flight Master"] == true and OpenMap.GetModule().db.flight == false and not FLIGHTSET.on and OMMP.pinFlights == false and Row("Flight masters").get() == "Questie"')
lua.execute('QTOWN.Banker = false; QTOWN.Mailbox = true; Row("Town NPC icons").set("OpenMap + game\'s tracking")')
res["Town NPC icons -> OpenMap + game's tracking: OpenMap's mailbox on the world map, the game's on the minimap, Questie's off"] = E(
    'OMTOWN.mailbox == true and TRACK[3].active == true and QTOWN.Mailbox == false and Row("Town NPC icons").get() == "OpenMap + game\'s tracking"')
res["Town NPC icons: flight masters left to their own row"] = E('QTOWN["Flight Master"] == true')
res["Town NPC icons -> OpenMap + game's tracking: remembered for this character (OpenMap's kinds kept in its menu)"] = E(
    '(function() for _, v in pairs(MasterOptionsDB.townOpenMap or {}) do if v == true then return true end end return false end)()')
lua.execute('Row("Town NPC icons").set("Questie")')
res["Town NPC icons -> Questie: no longer remembered (Questie's kinds out of OpenMap's menu again)"] = E('next(MasterOptionsDB.townOpenMap or {}) == nil')
res["World map coordinates: both on = conflict"] = E('Row("World map coordinates").get() == "Both (conflict)"')
lua.execute('Row("World map coordinates").set("OpenMap")')
res["World map coordinates -> OpenMap: Questie's off"] = E('Questie.db.profile.mapCoordinatesEnabled == false and Row("World map coordinates").get() == "OpenMap"')
lua.execute('Row("Navigation arrow").set("Destination pin only"); Row("Arrow text").set("Both")')
res["Navigation arrow / Arrow text: ShortestPathForever's settings"] = E(
    'ShortestPathForeverDB.arrow == false and ShortestPathForeverDB.arrowLabel == "both" and Row("Arrow text").get() == "Both" and Row("Navigation arrow").get() == "Destination pin only"')
res["Navigation arrow -> Destination pin only: its pin over the destination on (its arrow off hides the game's marker since 1.49.4)"] = E(
    'ShortestPathForeverDB.destinationPin == true and MasterOptionsDB.spfPinOurs == true')
lua.execute('Row("Navigation arrow").set("Shortest Path\'s arrow")')
res["Navigation arrow -> Shortest Path's arrow: its arrow back, the pin we turned on off again"] = E(
    'ShortestPathForeverDB.arrow == true and ShortestPathForeverDB.destinationPin == false and MasterOptionsDB.spfPinOurs == nil')
lua.execute('ShortestPathForeverDB.destinationPin = true; Row("Navigation arrow").set("Game\'s marker only"); Row("Navigation arrow").set("Shortest Path\'s arrow")')
res["Navigation arrow: the old choice's name still works; a pin you had on yourself stays on"] = E(
    'ShortestPathForeverDB.destinationPin == true and ShortestPathForeverDB.arrow == true')
lua.execute('Row("Quest and recipe waypoints").set("Game\'s waypoint")')
res["Quest and recipe waypoints -> game's: ShortestPathForever's TomTom stand-in off"] = E('ShortestPathForeverDB.tomtom == false')
lua.execute('Row("Minimap buttons").set("In a tray")')
res["Minimap buttons -> in a tray"] = E('OMMP.buttonTray == true and Row("Minimap buttons").get() == "In a tray"')
res["Minimap pins from: OpenMap_MiniMap's gathered spots count (a third pin)"] = E('Row("Minimap pins from").get() ~= "Off"')
lua.execute('Row("Minimap pins from").set("OpenMap_Tweaks")')
lua.execute('MastercraftDB.settings.nodesMapSize = 1; Row("Gathering pin size").set("Small")')
res["Gathering pin size -> Small: Mastercraft's pins 12 / 10 pixels"] = E(
    'math.abs(MastercraftDB.settings.nodesMapSize * 16 - 12) < 0.01 and math.abs(MastercraftDB.settings.nodesMiniSize * 14 - 10) < 0.01 and Row("Gathering pin size").get() == "Small"')
res["Minimap pins from -> OpenMap_Tweaks: OpenMap_MiniMap's gathered spots off"] = E('OMMP.gatherPins == false and Row("Minimap pins from").get() ~= "Both (conflict)"')
L('RunTimers()')
lua.execute(r'''
  SparklesDB.sparkleBobber = true; MastercraftDB.settings.fishMarker = true -- you pick Both afterwards
  Fire("PLAYER_LOGIN"); RunTimers(); RunTimers()
''')
res["next login: your own choice (Both) stays"] = lua.eval("MastercraftDB.settings.fishMarker") is True
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
errs = lua.eval("ERRORS")
for i in range(1, len(errs) + 1):
    print("  ", errs[i])
print("ERRORS:", sum(1 for v in res.values() if not v) + len(errs))
