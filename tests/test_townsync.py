# Questie_OpenMapTownsfolk: Questie's and OpenMap's townsfolk menus kept in step, each icon drawn once. A kind ticked
# in either menu is ticked in the other; OpenMap draws them on its world map and Questie on the minimap - Questie's
# world map icons of the synced kinds held back (FakeHide) while OpenMap's stitched map is up, given back otherwise.
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
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function Tick() for _, f in ipairs(FRAMES) do if f.OnUpdate then f.OnUpdate(f, 1) end end end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; print("ERR", e) end
  function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = table.pack(orig(...)); fn(...); return table.unpack(r, 1, r.n) end end
  function UnitName() return "Test", "Char" end
  function GetRealmName() return "" end
  MasterOptionsDB = { townSync = { ["Test Char-"] = true } }

  -- Questie: its townsfolk settings, its menu's redraw, its map's manual icons (a world map and a minimap frame each)
  Questie = { db = { profile = { townsfolkConfig = { Repair = true, Battlemaster = true } } } }
  QCFG = Questie.db.profile.townsfolkConfig
  REDRAWS = 0
  QuestieMenu = { OnLogin = function(self, force) REDRAWS = REDRAWS + 1 end }
  local n = 0
  local function Icon(mini)
    n = n + 1
    local f = { miniMapIcon = mini, hidden = false, shown = true }
    function f:FakeHide() self.hidden = true; self.fakeHides = (self.fakeHides or 0) + 1 end
    function f:FakeShow() self.hidden = false end
    _G["QuestieFrame" .. n] = f
    return "QuestieFrame" .. n, f
  end
  QuestieMap = { manualFrames = {} }
  function QuestieMap:DrawManualIcon(data, areaID, x, y, typ)
    self.manualFrames[typ] = self.manualFrames[typ] or {}
    self.manualFrames[typ][data.id] = self.manualFrames[typ][data.id] or {}
    local list = self.manualFrames[typ][data.id]
    local wn, w = Icon(false); local mn, m = Icon(true)
    list[#list + 1] = wn; list[#list + 1] = mn
    return w, m
  end
  QuestieLoader = { ImportModule = function(_, name) if name == "QuestieMap" then return QuestieMap elseif name == "QuestieMenu" then return QuestieMenu end end }

  -- OpenMap: its world map module's townsfolk settings and refresh, and whether its stitched map is up
  OREFRESH = 0
  WM = { db = { townsfolk = { banker = true, vendor = true } } }
  function WM:RefreshTownsfolk() OREFRESH = OREFRESH + 1 end
  OpenMap = { GetModule = function(_, n) if n == "worldmap" then return WM end end }
  OMTOWN = WM.db.townsfolk
  STITCHED = true
  OpenMapAPI = { IsStitched = function() return STITCHED end }
  WorldMapFrame = { shown = true, IsShown = function(self) return self.shown end }
''')
lua.eval("function(s) return load(s, '=townsync') end")(src)("MasterOptions_Questie_OpenMapTownsfolk")
E, L = lua.eval, lua.execute
res = {}

# login: in step from what either had (Questie's repair, OpenMap's banker)
L('Fire("PLAYER_LOGIN")')
res["login: what either menu had is on in both (repair, banker)"] = E(
    'QCFG.Repair == true and QCFG.Banker == true and OMTOWN.repair == true and OMTOWN.banker == true')
res["...both redrawn (OpenMap's townsfolk, Questie's icons)"] = E("OREFRESH") >= 1 and E("REDRAWS") >= 1
res["kinds only one of them has: left alone (Questie's battlemasters, OpenMap's vendors)"] = E(
    'QCFG.Battlemaster == true and OMTOWN.vendor == true and QCFG.Vendor == nil')

# ticked in Questie's menu -> OpenMap's too (its menu has nothing to hook: the once-a-second look)
L('O0 = OREFRESH; QCFG.Innkeeper = true; Tick()')
res["ticked in Questie's menu: ticked in OpenMap's, OpenMap redrawn"] = E('OMTOWN.innkeeper == true') and E("OREFRESH > O0")
# unticked in OpenMap's menu -> Questie's too (OpenMap refreshes its townsfolk: hooked)
L('R0 = REDRAWS; OMTOWN.repair = false; WM:RefreshTownsfolk()')
res["unticked in OpenMap's menu: unticked in Questie's, Questie redrawn"] = E('QCFG.Repair == false') and E("REDRAWS > R0")
L('R1, O1 = REDRAWS, OREFRESH; Tick(); Tick()')
res["nothing changed: nothing redrawn"] = E("REDRAWS == R1 and OREFRESH == O1")

# Questie draws a synced kind: its world map icon held back, its minimap icon stays
L('W, M = QuestieMap:DrawManualIcon({ id = 100 }, 1519, 50, 50, "Banker")')
res["Questie's world map icon of a synced kind held back (FakeHide) while OpenMap's map is up"] = E("W.hidden == true and W.moHeld == true")
res["...its minimap icon stays (Questie draws the minimap)"] = E("M.hidden == false")
L('WB, MB = QuestieMap:DrawManualIcon({ id = 200 }, 1519, 40, 40, "Battlemaster")')
res["a kind OpenMap doesn't have: Questie's world map icon stays"] = E("WB.hidden == false")

# an icon Questie showed again on its own (explored ground) -> held back again while the world map is open
L('W:FakeShow(); Tick()')
res["shown again by Questie: held back again at the next look (map open)"] = E("W.hidden == true")
# OpenMap's map not up (a fight, a map it doesn't stitch) -> Questie's given back
L('STITCHED = false; Tick()')
res["OpenMap's map not up: Questie's world map icon given back"] = E("W.hidden == false and W.moHeld == nil")
L('STITCHED = true; Tick()')
res["...and held back again when it is"] = E("W.hidden == true")

# an icon Questie hid itself (unexplored ground) is never shown by us
L('W2, M2 = QuestieMap:DrawManualIcon({ id = 101 }, 1519, 60, 60, "Banker")')
L('W3 = select(1, QuestieMap:DrawManualIcon({ id = 102 }, 1519, 61, 61, "Innkeeper")); W3.moHeld = nil; W3.hidden = true')
L('STITCHED = false; Tick()')
res["an icon Questie hid itself stays hidden when ours are given back"] = E("W3.hidden == true")
L('STITCHED = true; Tick()')

# synced off ("Town NPC icons" set to something else): every held-back icon given back, the menus left as they are
L('MasterOptionsDB.townSync = {}; MasterOptions_TownSync.Changed(); QCFG.Mailbox = true; Tick()')
res["sync off: Questie's world map icons given back"] = E("W.hidden == false and W2.hidden == false")
res["sync off: the menus no longer follow each other"] = E("OMTOWN.mailbox == nil")
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
