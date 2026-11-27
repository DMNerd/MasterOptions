import sys, os
from lupa import LuaRuntime

scratch = os.path.dirname(os.path.abspath(__file__))
mo_path = sys.argv[1]
lua = LuaRuntime(unpack_returned_tuples=True)

# saved variables (copies)
for f in sorted(os.listdir(os.path.join(scratch, "fixtures", "sv"))):
    lua.execute(open(os.path.join(scratch, "fixtures", "sv", f), encoding="utf-8").read())

addons = open(os.path.join(scratch, "fixtures", "addons.txt"), encoding="utf-8").read().strip().split(",")
lua.globals().ADDON_LIST = lua.table_from(addons + ["FakeOutdated", "CheapUpgrades_Baganator"])

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
-- (Skins: the skin listener API, which Bag icon size hooks; CORNER_FRAMES = what Baganator has made so far)
SKIN_LISTENERS, CORNER_FRAMES = {}, {}
Baganator = { API = { RequestItemButtonsRefresh = function() end,
  Skins = { RegisterListener = function(fn) SKIN_LISTENERS[#SKIN_LISTENERS + 1] = fn end,
            GetAllFrames = function() return CORNER_FRAMES end } } }
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
chunk = lua.eval("function(src) local f, e = load(src, '=MasterOptions.lua'); if not f then error(e) end; return f end")(open(mo_path, encoding="utf-8").read())
chunk("MasterOptions")
L = lua.execute
L('Fire("ADDON_LOADED", "MasterOptions")')
L('Fire("PLAYER_LOGIN")')
print("shown at start:", lua.eval("ShownRogue()"))
L('RunTimers(); RunTimers()')
print("shown after login:", lua.eval("ShownRogue()"))
print("hidden from GearMatic:", lua.eval("(function() local o={} for n,s in pairs(PawnCommon.Scales) do if s.ClassID==4 and s.Hidden then o[#o+1]=n end end table.sort(o) return table.concat(o, ', ') end)()"))
# druid mapping: a Resto druid (talent tab 3) should leave only Pawn's spec 4 for GearMatic
lua.execute(r'''
  PLAYER = { "Testchar", "Alpha", "DRUID", 11 }
  GearMatic.ScaleImport.GetActiveSpecIndex = function() return 3 end
  for i = 1, 4 do
    PawnCommon.Scales['"PawnForever":DRUID' .. i] = { Provider = "PawnForever", ClassID = 11, SpecID = i, Values = { Intellect = 1 },
      PerCharacterOptions = { ["Testchar Alpha"] = { Visible = true } } }
  end
  GearMaticDB.profiles.Default.usePawnWeights = true
  Fire("CHARACTER_POINTS_CHANGED")
  RunTimers()
''')
print("druid scales GearMatic can see:", lua.eval("(function() local o={} for n,s in pairs(PawnCommon.Scales) do if s.ClassID==11 and not s.Hidden and s.Provider=='PawnForever' then o[#o+1]=n end end table.sort(o) return table.concat(o, ', ') end)()"))
lua.execute('PLAYER = { "Testchar", "Alpha", "ROGUE", 4 }')
# open the window and click every row
L(r'''
  MasterOptionsFrame:Show()
  local clicked = 0
  for _, f in ipairs(FRAMES) do
    local fn = f.scripts.OnClick
    if fn and f ~= nil then
      local ok, e = pcall(fn, f)
      clicked = clicked + 1
      if not ok then ERRORS[#ERRORS+1] = "click: " .. tostring(e) end
    end
  end
  print("clicked " .. clicked .. " buttons")
  MasterOptionsFrame:Show()
  -- tooltips
  for _, f in ipairs(FRAMES) do
    if f.scripts.OnEnter then local ok, e = pcall(f.scripts.OnEnter, f); if not ok then ERRORS[#ERRORS+1] = "tooltip: " .. tostring(e) end end
  end
  Fire("PLAYER_LOGOUT")
  -- the Options page: read every control, open every dropdown, then "Defaults" (every setter with its default)
  local cb, dd = 0, 0
  for _, s in ipairs(SETTINGS) do
    local ok, v = pcall(s.get)
    if not ok then ERRORS[#ERRORS+1] = "get " .. s.name .. ": " .. tostring(v) end
    if s.kind == "checkbox" then cb = cb + 1 else dd = dd + 1 end
    if s.options then local ok2, e = pcall(s.options); if not ok2 then ERRORS[#ERRORS+1] = "options " .. s.name .. ": " .. tostring(e) end end
  end
  for _, s in ipairs(SETTINGS) do local ok, e = pcall(s.set, s.def); if not ok then ERRORS[#ERRORS+1] = "set " .. s.name .. ": " .. tostring(e) end end
  print(("settings page: %d checkboxes, %d dropdowns, %d headers, buttons: %s"):format(cb, dd, #HEADERS, table.concat(BUTTONS, " / ")))
  SlashCmdList.MASTEROPTIONS("options")
  print("/mo options opened category id:", tostring(OPENED))
''')
# Spec for Pawn and CheapUpgrades: following GearMatic's spec (rogue, talent tab 2 = Combat)
lua.execute(r'''
  PLAYER = { "Testchar", "Alpha", "ROGUE", 4 }
  GearMatic.ScaleImport.GetActiveSpecIndex = function() return 2 end
  for i = 1, 3 do PawnSetScaleVisible('"PawnForever":ROGUE' .. i, true) end
  CU_SET = nil
  CheapUpgrades = { chardb = { spec = "ASSA", watchSpecs = { ASSA = true, SUB = true } },
                    Scoring = { SPECS = { ROGUE = { { key = "ASSA" }, { key = "COMBAT" }, { key = "SUB" } } } },
                    GetClass = function() return "ROGUE" end,
                    SetSpec = function(self, k) self.chardb.spec = k; CU_SET = k end }
  for _, s in ipairs(SETTINGS) do if s.name:find("^Spec for Pawn and CheapUpgrades") then FOLLOW = s end end
  -- (Follow GearMatic is the default: it runs at login, a moment after the rest)
  Fire("PLAYER_LOGIN"); RunTimers(); RunTimers()
''')
follow = {
    "row on the Options page": lua.eval("FOLLOW ~= nil"),
    "Pawn: only Combat (spec 2) of Pawn Forever's shown": lua.eval('ShownRogue()') == '"PawnForever":ROGUE2',
    "CheapUpgrades: spec and ticked specs = COMBAT": lua.eval('CheapUpgrades.chardb.spec == "COMBAT" and CU_SET == "COMBAT" and CheapUpgrades.chardb.watchSpecs.COMBAT and not CheapUpgrades.chardb.watchSpecs.ASSA') is True,
}
lua.execute(r'''
  GearMatic.ScaleImport.GetActiveSpecIndex = function() return 3 end
  Fire("PLAYER_TALENT_UPDATE"); RunTimers(); RunTimers()
''')
follow["talent change to Subtlety: both follow"] = (lua.eval('ShownRogue()') == '"PawnForever":ROGUE3' and lua.eval('CheapUpgrades.chardb.spec') == "SUB")
# keeping (selling / deleting / GearMatic's guard): while following, the other specs' scales count too - an
# Assassination upgrade (spec 1, hidden now) is kept, and nothing stays shown afterwards
lua.execute(r'''
  function PawnGetItemData(link) return { Link = link } end
  function PawnIsItemAnUpgrade(item)
    local o = PawnCommon.Scales['"PawnForever":ROGUE1'].PerCharacterOptions[PawnPlayerFullName]
    if o and o.Visible then return { { '"PawnForever":ROGUE1', "Assassination", 0.12 } } end
  end
  KEEPS = MasterOptions_PawnKeeps("item:1234")
''')
follow["keeping while following: an off-spec (Assassination) upgrade is still kept"] = lua.eval("KEEPS") is True
follow["keeping: nothing left shown after the check (still only Subtlety)"] = lua.eval('ShownRogue()') == '"PawnForever":ROGUE3'
# many at once (DeleteCheapestItem_Protect's bag scan): the same answers, scales widened once, nothing left shown
lua.execute(r'''
  local real = PawnIsItemAnUpgrade
  function PawnIsItemAnUpgrade(item) if item.Link == "item:9999" then return nil end return real(item) end
  MANY = MasterOptions_PawnKeepsMany({ "item:1234", "item:9999", "item:5678" })
  MANY_EMPTY = next(MasterOptions_PawnKeepsMany({})) == nil
  PawnIsItemAnUpgrade = real
''')
follow["keeping many: off-spec upgrades kept, the rest not"] = (lua.eval('MANY["item:1234"]') is True and lua.eval('MANY["item:5678"]') is True
    and lua.eval('MANY["item:9999"]') is None and lua.eval("MANY_EMPTY") is True)
follow["keeping many: nothing left shown afterwards"] = lua.eval('ShownRogue()') == '"PawnForever":ROGUE3'
lua.execute('FOLLOW.set("Your own choice"); PawnSetScaleVisible(\'"PawnForever":ROGUE1\', true); GearMatic.ScaleImport.GetActiveSpecIndex = function() return 2 end; Fire("PLAYER_TALENT_UPDATE"); RunTimers(); RunTimers()')
follow["'Your own choice': nothing follows"] = lua.eval('ShownRogue()') == '"PawnForever":ROGUE1, "PawnForever":ROGUE3'
lua.execute('PawnSetScaleVisible(\'"PawnForever":ROGUE1\', false); KEEPS2 = MasterOptions_PawnKeeps("item:1234")')
follow["'Your own choice' with Assassination hidden: only what you show counts (not kept)"] = lua.eval("KEEPS2") is False
print("spec follow:", follow)
if not all(follow.values()):
    lua.execute('ERRORS[#ERRORS+1] = "Spec follow wrong"')
lua.execute('CheapUpgrades = {}; GearMatic.ScaleImport.GetActiveSpecIndex = nil')

# the Fishing bobber mark row (Sparkles_Forever + Mastercraft), through the Options page's own control
lua.execute('SparklesDB = { sparkleBobber = true }; MastercraftDB.settings.fishMarker = true')
lua.execute(r'''
  for _, s in ipairs(SETTINGS) do if s.name == "Fishing bobber mark" then BOBBER = s end end
''')
if lua.eval("BOBBER") is None:
    print("bobber row: not on the Options page")
    lua.execute('ERRORS[#ERRORS+1] = "Fishing bobber mark row missing"')
else:
    got = [lua.eval("BOBBER.get()")]
    for v in ("Sparkles", "Off", "Both"):
        lua.execute('BOBBER.set("%s")' % v)
        got.append((v, lua.eval("BOBBER.get()"), lua.eval("SparklesDB.sparkleBobber"), lua.eval("MastercraftDB.settings.fishMarker")))
    print("bobber row:", got)
    if got != ["Both", ("Sparkles", "Sparkles", True, False), ("Off", "Off", False, False), ("Both", "Both", True, True)]:
        lua.execute('ERRORS[#ERRORS+1] = "Fishing bobber mark row wrong"')
# bag icon rows (2.6.0): GearMatic's skull in Baganator, its vendor badge, its bag icon size
lua.execute(r'''
  for _, s in ipairs(SETTINGS) do
    if s.name:find("Best-in-slot skull in bags", 1, true) == 1 then SKULL = s end
    if s.name == "GearMatic vendor badge" then BADGE = s end
    if s.name:find("Bag icon size", 1, true) == 1 then ISIZE = s end
  end
  function BagProfile() return BAGANATOR_CONFIG.Profiles[BAGANATOR_CURRENT_PROFILE or "DEFAULT"] or BAGANATOR_CONFIG.Profiles.DEFAULT end
  function SkullCount() local n = 0 for _, k in ipairs({ "icon_top_left_corner_array", "icon_top_right_corner_array", "icon_bottom_left_corner_array", "icon_bottom_right_corner_array" }) do for _, v in ipairs(BagProfile()[k] or {}) do if v == "gearmatic_bis" then n = n + 1 end end end return n end
''')
bag = {}
if lua.eval("SKULL and BADGE and ISIZE") is None or not lua.eval("SKULL and BADGE and ISIZE"):
    bag["rows on the Options page"] = False
else:
    lua.execute('SKULL.set(false)')
    bag["skull off: out of every corner"] = lua.eval("SkullCount()") == 0 and lua.eval("SKULL.get()") is False
    lua.execute('SKULL.set(true); SKULL.set(true)')
    bag["skull on: once, top right"] = (lua.eval("SkullCount()") == 1 and lua.eval('BagProfile().icon_top_right_corner_array[1]') == "gearmatic_bis"
        and lua.eval("SKULL.get()") is True)
    gp = "GearMatic.db.profile"
    lua.execute('BADGE.set("Gold coin")')
    bag["badge coin"] = lua.eval(gp + ".vendorMarkerStyle") == "coin" and lua.eval(gp + ".bestGoldShowVendor") is True and lua.eval("BADGE.get()") == "Gold coin"
    lua.execute('BADGE.set("Off")')
    bag["badge off: style kept"] = lua.eval(gp + ".bestGoldShowVendor") is False and lua.eval(gp + ".vendorMarkerStyle") == "coin" and lua.eval("BADGE.get()") == "Off"
    lua.execute('BADGE.set("Gold $")')
    bag["badge $"] = lua.eval(gp + ".vendorMarkerStyle") == "dollar" and lua.eval(gp + ".bestGoldShowVendor") is True and lua.eval("BADGE.get()") == "Gold $"
    # one size for every corner icon: a texture and a frame icon scaled, text and GearMatic's own left alone
    lua.execute(r'''
      function Region(kind, extra) local r = { scale = 1, kind = kind }
        function r:SetScale(v) self.scale = v end
        function r:GetObjectType() return self.kind end
        for k, v in pairs(extra or {}) do r[k] = v end
        return r end
      function NewCorner(id, r) local d = { regionType = "CornerWidget", region = r, tags = { id } }
        CORNER_FRAMES[#CORNER_FRAMES + 1] = d
        for _, fn in ipairs(SKIN_LISTENERS) do fn(d) end
        return r end
      PAWN_ARROW = NewCorner("pawn", Region("Texture"))
      CIMI = NewCorner("can_i_mog_it", Region("Frame"))
      ILVL = NewCorner("item_level", Region("FontString", { sizeFont = true }))
      CU_TEXT = NewCorner("cheapupgrades_badge", Region("FontString"))
      GM_SKULL = NewCorner("gearmatic_bis", Region("Texture"))
      GearMatic.db.profile.bagIconSize = "large"
      ISIZE.set("Small")
      JUNK = NewCorner("junk", Region("Texture")) -- (made after the pick: the listener sizes it as it's made)
    ''')
    small = 18 / 28
    sc = lambda n: lua.eval(n + ".scale")
    bag["size small: icons scaled, made before and after"] = all(abs(sc(n) - small) < 1e-9 for n in ("PAWN_ARROW", "CIMI", "JUNK"))
    bag["size small: text left alone"] = sc("ILVL") == 1 and sc("CU_TEXT") == 1
    bag["size small: GearMatic's own icons not scaled twice, its setting set"] = sc("GM_SKULL") == 1 and lua.eval(gp + ".bagIconSize") == "small"
    bag["size small: the row reads it back"] = lua.eval("ISIZE.get()") == "Small"
    lua.execute('ISIZE.set("Large")')
    bag["size large: every icon back to its own size"] = all(sc(n) == 1 for n in ("PAWN_ARROW", "CIMI", "JUNK")) and lua.eval(gp + ".bagIconSize") == "large"
print("bag icon rows:", bag)
if not all(bag.values()):
    lua.execute('ERRORS[#ERRORS+1] = "Bag icon rows wrong"')
print("synced:", lua.eval("MasterOptionsDB.syncChars"), "shared:", lua.eval("(function() local o = {} for k, v in pairs(MasterOptionsDB.shared or {}) do o[#o+1] = k .. '=' .. tostring(v) end table.sort(o) return table.concat(o, '; ') end)()"))
errs = lua.eval("ERRORS")
print("ERRORS:", len(errs))
for i in range(1, len(errs) + 1):
    print("  ", errs[i])

