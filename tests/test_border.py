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
  function r:SetWidth(w) self.w = w end
  function r:SetHeight(h) self.h = h end
  function r:SetVertexColor(_, _, _, a) self.alpha = a or 1 end
  function r:GetWidth() return self.w end
  function r:GetHeight() return self.h end
  function r:GetTop() return self.top end
  function r:GetEffectiveScale() return 1 end
  function r:GetLeft() return self.left or 100 end
  function r:GetRight() return (self.left or 100) + (self.w or 0) end
  function r:GetDrawLayer() return "BACKGROUND", 0 end
  function r:CreateMaskTexture() local m = Region("mask"); self.masks = self.masks or {}; self.masks[#self.masks+1] = m; return m end
  function r:AddMaskTexture(m) self.mask = m end
  function r:IsObjectType(t) return self.kind == "button" and t == "Button" end
  function r:SetAllPoints(rel) self.points = { { 'ALL', rel } } end
  function r:GetBottom() return self.bottom or (self.top - self.h) end
  function r:SetTexture(f) self.file = f end
  function r:SetTexCoord(...) self.coords = { ... } end
  function r:SetFrameStrata(s) self.strata = s end
  function r:GetFrameStrata() return self.strata or "LOW" end
  function r:SetFrameLevel(l) self.level = l end
  function r:GetFrameLevel() return self.level or 1 end
  function r:GetChildren() return unpack(self.children) end
  function r:HookScript(k, fn) self.scripts[k] = fn end
  function r:SetColorTexture(...) self.atlas = nil; self.color = { ... } end
  function r:SetAtlas(a) self.atlas = a; self.color = nil end
  function r:SetHorizTile(v) self.htile = v end
  function r:GetHorizTile() return self.htile end
  function r:GetAtlas() return self.atlas end
  function r:SetText(t) self.txt = t end
  function r:GetStringWidth() return 50 end
  function r:GetFont() return "Fonts\\FRIZQT__.TTF", 10 end
  function r:SetFont(f, s, flags) self.fontFlags = flags end
  function r:SetJustifyH(j) self.justify = j end
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
function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = orig(...); fn(...); return r end end
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
Header = Region('frame'); Header.strata, Header.level = 'MEDIUM', 4
Bar.strata, Bar.level = 'MEDIUM', 3
MinimapCluster = { MinimapContainer = { PlayerCoords = Coords }, ZoneTextButton = Header }
Cluster.children = { Region("frame"), Body }
-- the /mo window's header (BasicFrameTemplate's TitleBg)
MasterOptionsFrame = { TitleBg = Region("tex") }; MasterOptionsFrame.TitleBg.atlas = "_UI-Frame-TitleTileBg"; MasterOptionsFrame.TitleBg.htile = true
''')
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, sys.argv[1])
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
check("left edge: thick by default (1.6 x a button's)", round(E("MasterOptionsMinimapBorder.pieces[21].w"), 3), round(45 * 0.30 * 1.6, 3))
check("rim: sides on the map's own (not the wider zone bar's), the left drawn in (its shading), up over the bar", E("(function() local p = MasterOptionsMinimapBorder.points; return p[1][2] == Body and p[2][2] == Body and p[1][4] < 0 and p[2][4] > 0 and -p[1][4] < p[2][4] and p[1][5] > -p[2][5] + 20 end)()"), True)
check("rounded corners all round (the atlas's own: no notch where edges cross), the edges between them", E("(function() local p = MasterOptionsMinimapBorder.pieces; return p[11].shown and p[13].shown and p[31].shown and p[33].shown and p[12].points[1][2] == p[11] and p[32].points[2][2] == p[33] end)()"), True)
L("Edge.texture:SetVertexColor(1, 1, 1, 1)")
check("OpenMap setting its border up again (a setting changed): hidden again at once", E("Edge.texture.alpha"), 0)
check("rim drawn over the zone bar and its buttons (a higher strata than the map's border)", E("MasterOptionsMinimapBorder.strata == 'MEDIUM' and MasterOptionsMinimapBorder.level == 7"), True)
check("zone bar's background: the middle between the rounded corners, up to the rim's top line", E("(function() local p = Bar.texture.points; return #p == 2 and p[1][2] == Body and p[1][4] > 0 and p[2][4] < 0 and p[1][5] > 25 end)()"), True)
check("...and a piece in each corner, the bar's whole height, cut round by a circle on the curve's centre (no gap inside the curve, no square past it)", E("(function() local t = Bar.textures; if not (t and #t == 2 and t[1].shown and t[2].shown and t[1].mask and t[2].mask) then return false end; local l, r, m = t[1].points, t[2].points, t[1].mask; return l[1][4] < 0 and r[2][4] > 0 and l[1][5] == Bar.texture.points[1][5] and m.w == m.h and m.w > 30 and m.points[1][1] == 'CENTER' end)()"), True)
check("OpenMap's own lines see-through", E("Edge.lines[1].alpha + Edge.texture.alpha"), 0)
check("shown", E("MasterOptionsMinimapBorder.shown"), True)
check("coordinates: a tab on the frame's top edge, centred", E("MasterOptionsMinimapCoords.shown and MasterOptionsMinimapCoords.points[1][1] == 'BOTTOM' and MasterOptionsMinimapCoords.points[1][2] == MasterOptionsMinimapBorder and MasterOptionsMinimapCoords.points[1][3] == 'TOP'"), True)
L("UIParent = { GetTop = function() return 600 end, GetEffectiveScale = function() return 1 end }; MasterOptionsMinimapBorder.top = 595; MasterOptions_MinimapBorder.PlaceCoords()")
check("map at the screen's top: the tab flips under the frame (not off the screen)", E("MasterOptionsMinimapCoords.points[1][1] == 'TOP' and MasterOptionsMinimapCoords.points[1][3] == 'BOTTOM'"), True)
L("UIParent = nil; MasterOptionsMinimapBorder.top = 300; MasterOptions_MinimapBorder.PlaceCoords()")
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
check("zone bar under the map: rim from map down over the bar, sides still the map's", E("(function() local p = MasterOptionsMinimapBorder.points; return p[1][2] == Body and p[2][2] == Body and p[2][5] < -20 and p[1][5] < 20 end)()"), True)

check("zone bar under the map: its background's middle down to the rim's bottom line", E("(function() local p = Bar.texture.points; return #p == 2 and p[1][3] == 'BOTTOMLEFT' and p[1][4] > 0 and p[2][4] < 0 and p[2][5] < -45 end)()"), True)
check("zone bar: the /mo window's header texture (tiled)", E("Bar.texture.atlas == '_UI-Frame-TitleTileBg' and Bar.texture.htile == true"), True)
check("coordinates tab: the same header texture", E("MasterOptionsMinimapCoords.bg.atlas == '_UI-Frame-TitleTileBg'"), True)
L('MasterOptions_MinimapBorderDB.on = false; MasterOptions_MinimapBorder.Apply(); Run()')
check("off: hidden, OpenMap's border back", E("MasterOptionsMinimapBorder.shown == false and Edge.lines[1].alpha == 1"), True)
check("off: the bar's background back on the bar", E("Bar.texture.points[1][1] == 'ALL' and Bar.texture.points[1][2] == Bar"), True)
check("off: the zone bar in OpenMap's colour again", E("Bar.texture.atlas == nil and Bar.texture.color[1] == 0.07 and Bar.texture.htile == false"), True)

L('MasterOptions_MinimapBorderDB.on = true; Body.shown = false; MasterOptions_MinimapBorder.Apply(); Run()')
check("OpenMap_MiniMap's look off (its map frame hidden): our border hidden", E("MasterOptionsMinimapBorder.shown"), False)
check("...and the game's own coordinates line back, no tab", E("Coords.alpha == 1 and not MasterOptionsMinimapCoords.shown"), True)
L('Body.shown = true; OpenMapMiniMapDB.profile.enabled = false; MasterOptions_MinimapBorder.Apply(); Run()')
check("OpenMap_MiniMap switched off in its options: the game's coordinates", E("Coords.alpha == 1 and not MasterOptionsMinimapCoords.shown"), True)
L('OpenMapMiniMapDB.profile.enabled = nil; MasterOptions_MinimapBorder.Apply(); Run()')
check("...on again: border and tab back", E("MasterOptionsMinimapBorder.shown and MasterOptionsMinimapCoords.shown and Coords.alpha == 0"), True)
# the coordinates tab moves along its edge clear of a minimap button where it would sit (OpenMap_MiniMap's slots are
# its own); with no button there it stays where asked
L(r'''
  MasterOptions_MinimapBorderDB.on = true; MasterOptions_MinimapBorderDB.coords = "bottom-center"
  OpenMapMiniMapDB.profile.shape = "square"; Bar.top = 525
  MasterOptionsMinimapBorder.left, MasterOptionsMinimapBorder.w = 0, 400
  MasterOptions_MinimapBorder.Apply(); Run()
  TAB = MasterOptionsMinimapCoords; X0 = TAB.points[1] and TAB.points[1][4]
  Btn = NewRegion("button"); Btn.left, Btn.w, Btn.top, Btn.h = TAB:GetLeft() + 5, 30, TAB:GetTop(), 30
  Minimap.children = { Btn }
  MasterOptions_MinimapBorder.Apply(); Run()
  X1 = TAB.points[1][4]
  Minimap.children = {}
  MasterOptions_MinimapBorder.Apply(); Run()
  X2 = TAB.points[1][4]
''')
check("coordinates tab: a minimap button where it sits - moved along the edge clear of it", E("X1 ~= X0 and (X1 > X0 + 30 or X1 < X0 - 30)"), True)
check("...the button gone: back where asked", E("X2 == X0"), True)

# OpenMap_MiniMap's "Snap to the screen's edge": the map flush against the screen's right and top edges - the rim
# comes in over the map's edge there, not off the screen
L(r'''
  UIParent = NewRegion("frame"); UIParent.w, UIParent.h = 298, 500 -- (the map: 100..298 across, its top at 500)
  MasterOptions_MinimapBorderDB.coords = "inside"; Bar.top = 500
  MasterOptions_MinimapBorder.Apply(); Run()
  P = MasterOptionsMinimapBorder.points
''')
check("map flush against the screen's right and top: the rim's line on the screen's edge (only its shading past it cut; no map showing past the line)", E("math.abs(P[2][4] - 6.4 * 0.75) < 0.01 and math.abs(P[1][5] - 6.4 * 0.15) < 0.01"), True)
L('UIParent.w, UIParent.h = 2000, 2000; MasterOptions_MinimapBorder.Apply(); Run(); P = MasterOptionsMinimapBorder.points')
check("...with room round it: the rim outside the map as before", E("P[2][4] > 0"), True)
L('UIParent = nil; Bar.top = 525')

# "inside": the numbers alone in the map's top-right corner - no tab
L('MasterOptions_MinimapBorderDB.coords = "inside"; MasterOptions_MinimapBorder.Apply(); Run()')
check("inside: the numbers in the map's top-right corner, outlined, no tab", E("(function() local f = MasterOptionsMinimapCoordsInside; return f ~= nil and f.shown and f.points[1][1] == 'TOPRIGHT' and f.points[1][2] == Body and f.text.fontFlags == 'OUTLINE' and not MasterOptionsMinimapCoords.shown end)()"), True)
L('MasterOptions_MinimapBorderDB.coords = "top-center"; MasterOptions_MinimapBorder.Apply(); Run()')
check("...a tab chosen again: the inside numbers gone, the tab back", E("MasterOptionsMinimapCoordsInside.shown == false and MasterOptionsMinimapCoords.shown"), True)

L('MasterOptions_MinimapBorderDB.on = true; OpenMapMiniMapDB.profile.shape = "round"; MasterOptions_MinimapBorder.Apply(); Run()')
check("round minimap: left alone", E("MasterOptionsMinimapBorder.shown == false and Edge.texture.alpha == 1"), True)

if fails:
    print("ERRORS: %d" % len(fails)); sys.exit(1)
print("ERRORS: 0")
