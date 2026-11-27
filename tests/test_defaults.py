import sys, os
from lupa import LuaRuntime

scratch = os.path.dirname(os.path.abspath(__file__))
mo_path = sys.argv[1]
lua = LuaRuntime(unpack_returned_tuples=True)

# saved variables (copies)
for f in sorted(os.listdir(os.path.join(scratch, "fixtures", "sv"))):
    lua.execute(open(os.path.join(scratch, "fixtures", "sv", f), encoding="utf-8").read())

addons = open(os.path.join(scratch, "fixtures", "addons.txt"), encoding="utf-8").read().strip().split(",")
lua.globals().ADDON_LIST = lua.table_from(addons + ["FakeOutdated", "CheapUpgrades_Baganator", "ShortestPathForever"])

lua.execute(r'''
-- ---------- fake WoW ----------
ERRORS = {}
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end io.write("[chat] ", table.concat(t, " "), "\n") end
local loaded = {}
for _, n in ipairs(ADDON_LIST) do loaded[n] = true end
loaded["FakeOutdated"] = false; loaded["CheapUpgrades_Baganator"] = false -- an old copy: exists, enabled, not loaded
local enabled = {}
for _, n in ipairs(ADDON_LIST) do enabled[n] = true end
C_AddOns = {
  IsAddOnLoaded = function(n) return loaded[n] == true end,
  GetNumAddOns = function() return #ADDON_LIST end,
  GetAddOnInfo = function(i)
    local n = type(i) == "number" and ADDON_LIST[i] or i
    if n == "FakeOutdated" then return n, n, "", false, "INTERFACE_VERSION" end
    return n, n, "", true, nil
  end,
  GetAddOnDependencies = function(i) return end,
  IsAddOnLoadOnDemand = function(i) return false end,
  DoesAddOnExist = function(n) return enabled[n] ~= nil end,
  GetAddOnEnableState = function(n, who) return enabled[n] and 2 or 0 end,
  EnableAddOn = function(n) enabled[n] = true end,
  DisableAddOn = function(n) enabled[n] = false end,
}
PLAYER = { "Testchar", "Alpha", "ROGUE", 4 }
function UnitName() return PLAYER[1], PLAYER[2] end
function UnitClass() return PLAYER[3], PLAYER[3], PLAYER[4] end
function GetRealmName() return "" end
function IsModifierKeyDown() return false end
function ReloadUI() end
function GameTooltip_Hide() end
function hooksecurefunc(a, b, c) end
function tinsert(t, v) table.insert(t, v) end
function LibStub() return nil end
UISpecialFrames = {}
SlashCmdList = {}
PawnPlayerFullName = "Testchar Alpha"
local timers = {}
C_Timer = { After = function(d, fn) timers[#timers+1] = fn end }
function RunTimers() local i = 1 while i <= #timers do local fn = timers[i]; i = i + 1; local ok, e = pcall(fn); if not ok then ERRORS[#ERRORS+1] = "timer: " .. tostring(e) end end; timers = {} end

-- frames: any method is a no-op; a few return values
FRAMES = {}
local Frame = {}
local methods = {
  GetHeight = function() return 768 end, GetStringHeight = function() return 12 end, GetAlpha = function() return 1 end,
  GetChecked = function(self) return self._checked end, SetChecked = function(self, v) self._checked = v end,
  SetScript = function(self, k, fn) self.scripts[k] = fn end, GetScript = function(self, k) return self.scripts[k] end,
  RegisterEvent = function(self, e) self.events[e] = true end, UnregisterAllEvents = function(self) self.events = {} end,
  SetText = function(self, t) self._text = t end, GetText = function(self) return self._text end,
  IsShown = function(self) return self._shown end, Show = function(self) self._shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
  Hide = function(self) self._shown = false end, SetShown = function(self, v) self._shown = v end,
  CreateFontString = function(self) return NewFrame() end, CreateTexture = function(self) return NewFrame() end,
  IsVisible = function() return false end, GetName = function() return nil end,
}
Frame.__index = function(t, k) return methods[k] or function() end end
function NewFrame() local f = setmetatable({ scripts = {}, events = {} }, Frame); FRAMES[#FRAMES+1] = f; return f end
function CreateFrame(kind, name) local f = NewFrame(); if name then _G[name] = f end return f end
UIParent = NewFrame()
GameTooltip = NewFrame()
function Fire(ev, ...) for _, f in ipairs(FRAMES) do if f.events[ev] and f.scripts.OnEvent then local ok, e = pcall(f.scripts.OnEvent, f, ev, ...); if not ok then ERRORS[#ERRORS+1] = ev .. ": " .. tostring(e) end end end end

-- other addons' globals
local profile = GearMaticDB.profiles.Default
GearMatic = {
  db = { profile = profile },
  Compat = { CurrentCharKey = function() return "-Testchar Alpha" end },
  ScaleImport = {
    IsBuiltinChosen = function(k) local b = GearMaticDB.scales and GearMaticDB.scales[k]; return b and b._builtin == true or false end,
    UsePawnScale = function() print("GM: UsePawnScale") end, UseBuiltinScale = function() print("GM: UseBuiltinScale") end,
  },
  Pawn = { ImportAllScales = function() end },
}
Baganator = { API = { RequestItemButtonsRefresh = function() end } }
CheapUpgrades = {}
SlashCmdList.PAWN_FOREVER = function(m) print("/pff " .. m) end
-- Pawn: real saved scales + Pawn Forever's rogue scales as its first run leaves them (stock hidden, ours shown)
for i = 1, 3 do
  PawnCommon.Scales['"PawnForever":ROGUE' .. i] = { Provider = "PawnForever", ClassID = 4, SpecID = i, Values = { Agility = 1 },
    PerCharacterOptions = { ["Testchar Alpha"] = { Visible = true } } }
  PawnCommon.Scales['"Classic":ROGUE' .. i].PerCharacterOptions["Testchar Alpha"].Visible = nil
end
function PawnSetScaleVisible(name, v)
  local s = PawnCommon.Scales[name]; s.PerCharacterOptions = s.PerCharacterOptions or {}
  s.PerCharacterOptions[PawnPlayerFullName] = s.PerCharacterOptions[PawnPlayerFullName] or {}
  s.PerCharacterOptions[PawnPlayerFullName].Visible = v or nil
end
function ShownRogue() local o = {} for n, s in pairs(PawnCommon.Scales) do if s.ClassID == 4 and s.PerCharacterOptions and s.PerCharacterOptions[PawnPlayerFullName] and s.PerCharacterOptions[PawnPlayerFullName].Visible then o[#o+1] = n end end table.sort(o) return table.concat(o, ", ") end
''')

lua.execute(r'''
SETTINGS, HEADERS, BUTTONS = {}, {}, {}
Settings = {
  VarType = { Boolean = "boolean", String = "string" },
  RegisterVerticalLayoutCategory = function(name) return { GetID = function() return 42 end, name = name }, { AddInitializer = function() end } end,
  RegisterProxySetting = function(cat, var, typ, name, def, get, set)
    local s = { var = var, typ = typ, name = name, def = def, get = get, set = set }
    SETTINGS[#SETTINGS + 1] = s; return s end,
  CreateCheckbox = function(cat, s, tip) s.kind = "checkbox" end,
  CreateDropdown = function(cat, s, options, tip) s.kind = "dropdown"; s.options = options end,
  CreateControlTextContainer = function() local d = {} return { Add = function(_, v, l) d[#d+1] = { v, l } end, GetData = function() return d end } end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function(id) OPENED = id end,
}
function CreateSettingsListSectionHeaderInitializer(t) HEADERS[#HEADERS+1] = t; return t end
function CreateSettingsButtonInitializer(l) BUTTONS[#BUTTONS+1] = l; return l end
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
# Questie + OpenMap, synced: what's on anywhere on in both menus, the game's tracking off, the sync module told
lua.execute(r'''
  SYNC_CHANGED = 0
  MasterOptions_TownSync = { Changed = function() SYNC_CHANGED = SYNC_CHANGED + 1 end }
  TRACK[2].active = true
  Row("Town NPC icons").set("Questie + OpenMap, synced")
''')
res["Town NPC icons -> synced: the kinds on anywhere (mailbox, banker) on in Questie's and OpenMap's menus, the game's tracking off"] = E(
    'QTOWN.Mailbox == true and OMTOWN.mailbox == true and QTOWN.Banker == true and OMTOWN.banker == true and TRACK[2].active == false and TRACK[3].active == false')
res["Town NPC icons -> synced: remembered for this character, the sync module told, shown as synced (no conflict)"] = E(
    'SYNC_CHANGED == 1 and Row("Town NPC icons").get() == "Questie + OpenMap, synced"')
lua.execute('Row("Town NPC icons").set("Questie")')
res["Town NPC icons -> Questie again: sync off (told), OpenMap's copies off"] = E(
    'SYNC_CHANGED == 2 and OMTOWN.mailbox == false and QTOWN.Mailbox == true and Row("Town NPC icons").get() == "Questie"')
res["World map coordinates: both on = conflict"] = E('Row("World map coordinates").get() == "Both (conflict)"')
lua.execute('Row("World map coordinates").set("OpenMap")')
res["World map coordinates -> OpenMap: Questie's off"] = E('Questie.db.profile.mapCoordinatesEnabled == false and Row("World map coordinates").get() == "OpenMap"')
lua.execute('Row("Navigation arrow").set("Game\'s marker only"); Row("Arrow text").set("Both")')
res["Navigation arrow / Arrow text: ShortestPathForever's settings"] = E(
    'ShortestPathForeverDB.arrow == false and ShortestPathForeverDB.arrowLabel == "both" and Row("Arrow text").get() == "Both" and Row("Navigation arrow").get() == "Game\'s marker only"')
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
