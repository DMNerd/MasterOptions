import sys
from lupa import LuaRuntime

lua = LuaRuntime()

lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
FR, TM = {}, {}
local function Region(kind)
  local r = { kind = kind, shown = true, alpha = 1, points = {}, children = {}, w = 0, h = 0, top = 0, scripts = {} }
  function r:SetAlpha(a) self.alpha = a end
  function r:Show() self.shown = true end
  function r:Hide() self.shown = false end
  function r:SetShown(v) self.shown = v and true or false end
  function r:IsShown() return self.shown end
  function r:ClearAllPoints() self.points = {} end
  function r:SetPoint(p, rel, rp, x, y) self.points[#self.points+1] = { p, rel, rp, x, y } end
  function r:SetSize(w, h) self.w, self.h = w, h end
  function r:GetWidth() return self.w end
  function r:GetHeight() return self.h end
  function r:GetTop() return self.top end
  function r:SetTexture(f) self.file = f end
  function r:SetTexCoord(...) self.coords = { ... } end
  function r:SetFrameStrata(s) self.strata = s end
  function r:GetFrameStrata() return self.strata or "LOW" end
  function r:SetFrameLevel(l) self.level = l end
  function r:GetFrameLevel() return self.level or 1 end
  function r:GetChildren() return unpack(self.children) end
  function r:HookScript(k, fn) self.scripts[k] = fn end
  function r:SetColorTexture() end
  function r:SetText(t) self.txt = t end
  function r:GetStringWidth() return 50 end
  function r:GetStringHeight() return 10 end
  function r:CreateFontString() local t = Region('fs'); self.fonts = self.fonts or {}; self.fonts[#self.fonts+1] = t; return t end
  function r:CreateTexture() local t = Region("tex"); self.textures = self.textures or {}; self.textures[#self.textures+1] = t; return t end
  function r:RegisterEvent(e) self.ev = self.ev or {}; self.ev[e] = true end
  function r:SetScript(k, fn) self.scripts[k] = fn end
  return r
end
NewRegion = Region
function CreateFrame(kind, name, parent)
  local f = Region("frame")
  if parent then parent.children[#parent.children+1] = f end
  if name then _G[name] = f end
  FR[#FR+1] = f
  return f
end
function hooksecurefunc() end
REPORTED = {}
function MasterOptions_ReportError(a, w, e) REPORTED[#REPORTED+1] = w .. ': ' .. tostring(e); print('REPORTED', w, e) end
unpack = unpack or table.unpack
C_Timer = { After = function(d, fn) TM[#TM+1] = fn end }
function Run() for _ = 1, 10 do local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev and f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
function UnitName() return "Testchar", "Doe" end
function GetRealmName() return "" end
C_Texture = { GetAtlasInfo = function(n) if n == "UI-HUD-ActionBar-IconFrame" then return { file = 4612, leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end end }
FIRED = {}
LibStub = function(name) if name == 'LibDBIcon-1.0' then return { callbacks = { Fire = function(self, ev) FIRED[#FIRED+1] = ev end } } end end
OpenMapMiniMapDB = { profile = { shape = "square", border = "dark" } }
-- OpenMap's frames: the cluster holds the map frame (body), which holds the border (edge) and the zone bar
Cluster = Region("frame")
Minimap = Region("frame"); function Minimap:GetParent() return Cluster end
Painted = Region("frame"); Painted.texture = Region("tex"); Painted.w, Painted.h = 198, 198   -- (not the bar)
Body = Region("frame"); Body.w, Body.h, Body.top = 198, 198, 500
Edge = Region("frame"); Edge.texture = Region("tex"); Edge.lines = { Region("tex"), Region("tex"), Region("tex"), Region("tex") }
Bar = Region("frame"); Bar.texture = Region("tex"); Bar.w, Bar.h, Bar.top = 198, 23, 525
Body.children = { Painted, Edge, Bar }
Coords = Region('frame'); Coords.points = { { 'BOTTOM', Minimap, 'BOTTOM', 0, -2 } }
function Coords:GetNumPoints() return #self.points end
function Coords:GetPoint(i) return unpack(self.points[i]) end
MinimapCluster = { MinimapContainer = { PlayerCoords = Coords } }
Cluster.children = { Region("frame"), Body }
''')
lua.eval("function(s) local f, e = load(s, '=border'); if not f then error(e) end; return f end")(open(sys.argv[1], encoding="utf-8").read())("MasterOptions_OpenMapMiniMap_Border")
L, E = lua.execute, lua.eval
fails = []
def check(name, got, want):
    ok = got == want
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else "  got %r want %r" % (got, want)))
    if not ok: fails.append(name)

L('Fire("ADDON_LOADED", "MasterOptions_OpenMapMiniMap_Border"); Fire("PLAYER_ENTERING_WORLD"); Run()')
check("border frame built on OpenMap's map frame", E("(function() for _, c in ipairs(Body.children) do if c == MasterOptionsMinimapBorder then return true end end return false end)()"), True)
check("eight pieces (no middle)", E("#MasterOptionsMinimapBorder.textures"), 8)
check("pieces cut from the action button atlas", E("MasterOptionsMinimapBorder.textures[1].file"), 4612)
check("top-left corner: thick by default (1.6 x a button's)", round(E("MasterOptionsMinimapBorder.textures[1].w"), 3), round(45 * 0.30 * 1.6, 3))
check("rim round the zone bar (above the map) and the map", E("MasterOptionsMinimapBorder.points[1][2] == Bar and MasterOptionsMinimapBorder.points[2][2] == Body"), True)
check("OpenMap's own lines see-through", E("Edge.lines[1].alpha + Edge.texture.alpha"), 0)
check("shown", E("MasterOptionsMinimapBorder.shown"), True)
check("coordinates: a tab on the frame's top edge, centred", E("MasterOptionsMinimapCoords.shown and MasterOptionsMinimapCoords.points[1][1] == 'BOTTOM' and MasterOptionsMinimapCoords.points[1][2] == MasterOptionsMinimapBorder and MasterOptionsMinimapCoords.points[1][3] == 'TOP'"), True)
check("the game's own line see-through meanwhile", E("Coords.alpha"), 0)
check("the tab has the rim too", E("#MasterOptionsMinimapCoords.textures >= 8"), True)
L("MasterOptions_MinimapBorderDB.coords = 'bottom-right'; MasterOptions_MinimapBorder.PlaceCoords()")
check("bottom right: under the frame, at its right", E("MasterOptionsMinimapCoords.points[1][1] == 'TOPRIGHT' and MasterOptionsMinimapCoords.points[1][3] == 'BOTTOMRIGHT' and MasterOptionsMinimapCoords.points[1][4] < 0"), True)
L("MasterOptions_MinimapBorderDB.coords = 'game'; MasterOptions_MinimapBorder.PlaceCoords()")
check("game's place: tab gone, the game's line back", E("MasterOptionsMinimapCoords.shown == false and Coords.alpha == 1"), True)
L("Coords.shown = false; MasterOptions_MinimapBorderDB.coords = 'top-left'; MasterOptions_MinimapBorder.PlaceCoords()")
check("coordinates setting off: no tab", E("MasterOptionsMinimapCoords.shown"), False)
L("Coords.shown = true; MasterOptions_MinimapBorderDB.coords = nil; MasterOptions_MinimapBorder.PlaceCoords()")
check("OpenMap told to lay the minimap buttons out again, twice", E("#FIRED == 2 and FIRED[1] == 'LibDBIcon_IconCreated'"), True)

L('Bar.top = 280; MasterOptions_MinimapBorder.Apply(); Run()')
check("zone bar under the map: rim from map to bar", E("MasterOptionsMinimapBorder.points[1][2] == Body and MasterOptionsMinimapBorder.points[2][2] == Bar"), True)

L('MasterOptions_MinimapBorderDB.on = false; MasterOptions_MinimapBorder.Apply(); Run()')
check("off: hidden, OpenMap's border back", E("MasterOptionsMinimapBorder.shown == false and Edge.lines[1].alpha == 1"), True)

L('MasterOptions_MinimapBorderDB.on = true; OpenMapMiniMapDB.profile.shape = "round"; MasterOptions_MinimapBorder.Apply(); Run()')
check("round minimap: left alone", E("MasterOptionsMinimapBorder.shown == false and Edge.texture.alpha == 1"), True)

if fails:
    print("ERRORS: %d" % len(fails)); sys.exit(1)
print("ERRORS: 0")
