# ShortestPathForever_OpenMapPins: one trip, one pin. Every journey has an OpenMap pin at its destination (OpenMap's
# own there, else one placed for it); ShortestPathForever's goal marker is hidden meanwhile (not at the minimap's rim,
# not a route's numbered stops); any end - arrived, cleared, stopped, replaced - clears the pin and OpenMap's
# following; a pin with your own note stays; the same spot changing owner is the same trip.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, ERRS = {}, 0
  function CreateFrame() local f = { ev = {} }
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    FRAMES[#FRAMES + 1] = f; return f end
  C_Timer = { After = function(d, fn) fn() end }
  function time() return 1000 end
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; print("ERR", e) end
  function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = orig(...); fn(...); return r end end
  MasterOptionsDB = {}
  -- a frame-like table: Show / Hide / SetShown / IsShown
  local Region = {}
  Region.__index = Region
  function Region:Show() self.shown = true end
  function Region:Hide() self.shown = false end
  function Region:SetShown(v) self.shown = v and true or false end
  function Region:IsShown() return self.shown end
  function NewRegion(t) return setmetatable(t or {}, Region) end

  -- ShortestPathForever
  JOURNEY, ENDED, SUBS, T = nil, {}, {}, 0
  ShortestPathForever = { API = {
    Subscribe = function(fn) SUBS[#SUBS + 1] = fn end,
    Journey = function() if JOURNEY == "loading" then return nil, "loading" end; if JOURNEY then return JOURNEY end; return nil, "none" end,
    Ended = function(owner) local e = ENDED[owner]; if e then return e.reason, e.at end end,
    CurrentStop = function(owner) return JOURNEY and JOURNEY ~= "loading" and JOURNEY.owner == owner and 1 or nil end,
  } }
  function Notify() for _, fn in ipairs(SUBS) do fn({}) end end
  function Go(owner, map, x, y, title) JOURNEY = { owner = owner, goal = { map = map, x = x, y = y, title = title }, legs = {} }; Notify() end
  function Stop(owner, reason) T = T + 1; ENDED[owner] = { reason = reason, at = T }; JOURNEY = nil; Notify() end
  -- its goal markers: the minimap's texture, and world map pins on the canvas
  GOAL = NewRegion({ shown = false })
  ShortestPathForeverMinimapRoute = NewRegion({ Goal = GOAL })
  LONE = NewRegion({ pressRegions = {}, SetStopAlpha = function() end, shown = false })
  NUMBERED = NewRegion({ pressRegions = {}, SetStopAlpha = function() end, stopNumbers = { 1, 2 }, shown = false })
  local canvas = { GetChildren = function() return LONE, NUMBERED end }
  WorldMapFrame = NewRegion({ shown = true, GetCanvas = function() return canvas end, HookScript = function() end })

  -- OpenMap
  FOLLOWED, CLEARS, REFRESH = nil, 0, 0
  WM = { db = { pins = { list = {}, nextId = 50 } } }
  function WM.WaypointPoint() if FOLLOWED then return FOLLOWED.map, FOLLOWED.x, FOLLOWED.y end end
  function WM.PinAt(m, x, y) for _, p in ipairs(WM.db.pins.list) do if p.map == m and p.x == x and p.y == y then return p end end end
  function WM.ClearPin() FOLLOWED = nil; CLEARS = CLEARS + 1 end
  function WM.RefreshPins() REFRESH = REFRESH + 1 end
  function WM.TrackPoint(m, x, y) FOLLOWED = { map = m, x = x, y = y } end
  OpenMap = { GetModule = function(_, n) if n == "worldmap" then return WM end end }
  MasterOptions_DJOpenMapDB = { ours = {} }
  -- (DungeonJournal_ShowOnMap, in game: forgets its own record of a pin any module of ours removes)
  MasterOptions_Shared.OpenMapPins.OnRemove(function(id) MasterOptions_DJOpenMapDB.ours[id] = nil end)
  function Pin(id, note, from, x) local p = { id = id, map = 1434, x = x or (0.1 * id), y = 0.5, note = note, from = from }
    table.insert(WM.db.pins.list, p); return p end
  function Has(id) for _, p in ipairs(WM.db.pins.list) do if p.id == id then return true end end return false end
  function PinAtSpot(x) for _, p in ipairs(WM.db.pins.list) do if math.abs(p.x - x) < 1e-6 then return p end end end
  function Count() return #WM.db.pins.list end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_ShortestPathForever_OpenMapPins")
E, L = lua.eval, lua.execute
res = {}

# a leftover trip pin from last session (no journey leads to it any more) is cleaned up at login
L('LEFT = Pin(9, "Journey to Old Place", "Master Options"); MasterOptionsDB.tripPins = { [9] = "Journey to Old Place" }; Fire("PLAYER_LOGIN")')
res["login: subscribed, a leftover trip pin cleaned up"] = E("#SUBS") == 1 and not E("Has(9)")

# a quest waypoint (TomTom stand-in) -> a gold OpenMap pin named after the journey
L('Go("TomTom", 1434, 0.4, 0.6, "Kill 10 boars")')
res["a journey: an OpenMap pin at its destination, gold, named after it"] = E(
    'PinAtSpot(0.4) ~= nil and PinAtSpot(0.4).note == "Kill 10 boars" and PinAtSpot(0.4).color == 1 and PinAtSpot(0.4).from == "Master Options"')
L('GOAL:Show(); LONE:Show(); NUMBERED:Show(); ShortestPathForeverMinimapRoute.goalEdge = nil; Notify(); GOAL:Show(); LONE:Show(); NUMBERED:Show()')
res["Shortest Path's goal marker hidden: minimap and world map (one pin marks the spot)"] = E("GOAL.shown") is False and E("LONE.shown") is False
res["a route's numbered stops stay"] = E("NUMBERED.shown") is True
L('ShortestPathForeverMinimapRoute.goalEdge = true; GOAL:Show()')
res["at the minimap's rim the goal stays (it points the way)"] = E("GOAL.shown") is True
L('ShortestPathForeverMinimapRoute.goalEdge = nil')
# ShortestPathForever 1.49.1: no goalEdge any more - the goal at the rim is shown faded (its EDGE_ALPHA 0.6)
L('ALPHA = 0.6; function GOAL:GetAlpha() return ALPHA end; GOAL:Show()')
res["1.49.1: at the rim (shown faded) the goal stays"] = E("GOAL.shown") is True
L('ALPHA = 1; GOAL:Show()')
res["1.49.1: on the minimap (full alpha) it's hidden"] = E("GOAL.shown") is False
L('GOAL.GetAlpha = nil')

# loading: nothing changes
L('JOURNEY = "loading"; Notify()')
res["Shortest Path still loading: the trip and its pin stay"] = E("PinAtSpot(0.4) ~= nil")

# arrived -> the pin goes
L('JOURNEY = { owner = "TomTom", goal = { map = 1434, x = 0.4, y = 0.6, title = "Kill 10 boars" } }; Notify(); Stop("TomTom", "arrived")')
res["arrived: the trip's pin goes"] = E("PinAtSpot(0.4) == nil")
L('GOAL:Show(); LONE:Show()')
res["no trip: Shortest Path's markers shown again"] = E("GOAL.shown") is True and E("LONE.shown") is True

# replaced by another journey -> the old pin goes, the new one comes
L('Go("TomTom", 1434, 0.45, 0.5, "Quest A"); Go("OpenMap", 1434, 0.55, 0.5, "Journey to Elwynn")')
res["replaced: the old trip's pin goes, the new trip gets its own"] = E("PinAtSpot(0.45) == nil and PinAtSpot(0.55) ~= nil")
L('Stop("OpenMap", "cleared")')

# Ctrl-click: OpenMap's own pin, followed -> no second pin; on arrival OpenMap stops following and its pin goes
L('P1 = Pin(1, "", nil, 0.7); WM.TrackPoint(1434, 0.7, 0.5); C0 = Count(); Go("OpenMap:Pin", 1434, 0.7, 0.5, "Pin")')
res["Ctrl-click pin: no second pin placed"] = E("Count()") == E("C0")
L('Stop("OpenMap:Pin", "arrived")')
res["Ctrl-click pin, arrived: OpenMap stops following, the pin goes"] = E("CLEARS") >= 1 and not E("Has(1)")

# your own note keeps the pin (no longer followed)
L('C1 = CLEARS; P2 = Pin(2, "my farm spot", nil, 0.75); WM.TrackPoint(1434, 0.75, 0.5); Go("OpenMap:Pin", 1434, 0.75, 0.5, "my farm spot"); Stop("OpenMap:Pin", "cleared")')
res["a pin with your own note: kept, no longer followed"] = E("Has(2)") and E("CLEARS") == E("C1") + 1

# Dungeon Journal's pin: goes, and its record with it
L('P3 = Pin(3, "Dungeon Journal: Deadmines", "Dungeon Journal", 0.8); MasterOptions_DJOpenMapDB.ours[3] = true; WM.TrackPoint(1434, 0.8, 0.5); Go("OpenMap:Pin", 1434, 0.8, 0.5, "Deadmines"); Stop("OpenMap:Pin", "cancelled")')
res["Dungeon Journal's pin, stopped in OpenMap: goes, its record too"] = not E("Has(3)") and E("MasterOptions_DJOpenMapDB.ours[3]") is None

# the same spot changing owner: you click the trip's gold pin and OpenMap follows it -> the same trip, nothing cleared
L('Go("TomTom", 1434, 0.3, 0.5, "Quest B"); G = PinAtSpot(0.3); C2 = CLEARS; WM.TrackPoint(1434, G.x, G.y); Go("OpenMap:Pin", 1434, 0.3, 0.5, "Quest B")')
res["the trip's pin followed in OpenMap (same spot, new owner): pin kept, still followed"] = E("PinAtSpot(0.3) ~= nil") and E("CLEARS") == E("C2") and E("FOLLOWED ~= nil")
L('Stop("OpenMap:Pin", "arrived")')
res["...and it goes when you arrive"] = E("PinAtSpot(0.3) == nil")

# a newly followed pin elsewhere is never unfollowed by the old trip ending
L('Go("TomTom", 1434, 0.2, 0.5, "Quest C"); P4 = Pin(4, "", nil, 0.9); WM.TrackPoint(1434, 0.9, 0.5); C3 = CLEARS; Go("OpenMap:Pin", 1434, 0.9, 0.5, "Pin")')
res["replaced by a pin you follow: the old trip's pin goes, the new pin stays followed"] = E("PinAtSpot(0.2) == nil") and E("CLEARS") == E("C3") and E("Has(4)")

# Shift-click on an OpenMap pin (Dungeon Journal's): a journey there, not OpenMap's share in chat
L(r'''
  SHIFT, ALT, CHAT, SHARED, NAV, COMBAT = false, false, false, 0, nil, false
  function IsShiftKeyDown() return SHIFT end
  function IsAltKeyDown() return ALT end
  function IsControlKeyDown() return false end
  ChatEdit_GetActiveWindow = function() return CHAT end
  ShortestPathForever.API.Navigate = function(owner, m, x, y, title)
    if COMBAT then return false end
    NAV = { owner = owner, map = m, x = x, y = y, title = title }; return true end
  function OpenMapClick(self) if IsAltKeyDown() then DELETED = self.data elseif IsShiftKeyDown() then SHARED = SHARED + 1 end end
  local function Kids(t) return function(self) return table.unpack(self.kids) end end
  ROOT = { kids = {} }; ROOT.GetChildren = Kids()
  CELL = { kids = {}, GetParent = function() return ROOT end }; CELL.GetChildren = Kids()
  ROOT.kids[1] = CELL
  DJ = Pin(30, "Dungeon Journal: Deadmines", "Dungeon Journal", 0.33)
  BTN = { data = DJ, GetParent = function() return CELL end, hooks = {} }
  function BTN:HookScript(k, fn) self.hooks[#self.hooks + 1] = fn end
  CELL.kids[1] = BTN
  local OTHER = { GetParent = function() return nil end }
  function EnumerateFrames(f) if f == nil then return OTHER elseif f == OTHER then return BTN end end
  function WM.RefreshPins() REFRESH = REFRESH + 1; BTN.OnClick = OpenMapClick; BTN.hooks = {} end
  -- (the module hooked RefreshPins at login: hook the new one as OpenMap's own would be)
''')
L('Fire("PLAYER_LOGIN")')  # (a second login in the sandbox: hooks the replaced RefreshPins)
L('WM.RefreshPins()')
res["pin buttons found and wrapped after RefreshPins"] = E("BTN.OnClick ~= OpenMapClick") and E("#BTN.hooks") == 1
L('SHIFT = true; BTN:OnClick()')
res["Shift-click on a pin: a journey there, named after its note, not shared"] = E(
    'NAV ~= nil and NAV.owner == "OpenMap" and NAV.map == 1434 and math.abs(NAV.x - 0.33) < 1e-9 and NAV.title == "Dungeon Journal: Deadmines"') and E("SHARED") == 0
L('NAV = nil; CHAT = true; BTN:OnClick()')
res["chat box open: Shift-click still shares the pin"] = E("NAV == nil") and E("SHARED") == 1
L('CHAT = false; COMBAT = true; BTN:OnClick()')
res["journey refused (in a fight): OpenMap's own click"] = E("SHARED") == 2
L('COMBAT = false; ALT = true; BTN:OnClick()')
res["Alt-click: still OpenMap's delete"] = E("DELETED == DJ") and E("NAV == nil")
L('ALT = false; SHIFT = false; WM.RefreshPins()')
res["wrapped again after the next RefreshPins"] = E("BTN.OnClick ~= OpenMapClick") and E("#BTN.hooks") == 1
# the tooltip's Shift-click line says what it does now
L(r'''
  LINES = { { t = "Dungeon Journal: Deadmines" }, { t = "|cffffd200Shift-click:|r share in chat" }, { t = "|cffffd200Alt-click:|r delete it" } }
  for i, l in ipairs(LINES) do
    l.GetText = function(self) return self.t end; l.SetText = function(self, s) self.t = s end
    _G["GameTooltipTextLeft" .. i] = l end
  GameTooltip = { GetOwner = function() return BTN end, NumLines = function() return #LINES end, Show = function() end }
  BTN.hooks[1](BTN)
''')
res["tooltip: Shift-click line says journey, colour kept"] = E("LINES[2].t").startswith("|cffffd200Shift-click:|r journey there") and E("LINES[3].t") == "|cffffd200Alt-click:|r delete it"
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
