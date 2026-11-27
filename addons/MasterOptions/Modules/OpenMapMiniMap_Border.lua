-- Master Options module (was the addon MasterOptions_OpenMapMiniMap_Border): runs when OpenMap_MiniMap is loaded.
MasterOptions_Module("OpenMapMiniMap_Border", { "OpenMap_MiniMap" }, function(ADDON)

-- OpenMap minimap <- the action bar's button border.
--
-- The action buttons are framed by the atlas "UI-HUD-ActionBar-IconFrame" (OpenMap uses it for its own icons,
-- so this client has it). It's drawn for one 45-unit button; here it's cut into corners and edges (a
-- nine-slice of the atlas) and stretched round the square minimap and its zone bar together, the rim as thick
-- as on the buttons. OpenMap's own border (its dark lines, or its gold frame) is made see-through meanwhile;
-- the zone bar's dark background stays, inside the rim.
--
-- OpenMap keeps its frames to itself: its map frame (Frame.body: the rectangle the minimap has at full
-- size, parented to the minimap's parent) is found as the child there holding the border frame (a frame with
-- .texture and .lines). Only alpha is changed on OpenMap's textures, and only while this is on.
-- Square shape only: with OpenMap's round shape nothing changes.
--
-- MasterOptions_MinimapBorderDB: { on = true, scale = 1.6 (1 = as thick as on a button), outset (units the rim reaches past the map; RIM x scale) }

local unpack = unpack or table.unpack
local ATLAS = "UI-HUD-ActionBar-IconFrame"
local BUTTON = 45     -- the action button the atlas is drawn for (UI units)
local CUT = 0.30      -- the share of the atlas each corner takes (the rim and its rounded corner fit in it)
local RIM = 4         -- the rim's width on a 45-unit button (UI units)
-- The atlas isn't symmetric: on its left (and top) the bright line is at the outer edge with its shading inside
-- it, on its right (and bottom) the line is inside with the shading outside. Framed evenly, the left shading lay
-- beside the map, see-through: a gap left of the map (a player's screenshots, measured: ~2/3 of the rim). So the
-- left side reaches out only this share of the rim, and so does the top (its shading too was see-through,
-- above the zone bar). What's under the rim's line on each side: LINE_IN (outer line: left, top) of the rim
-- in from the frame's edge, LINE_OUT (inner line: right, bottom) out from the map.
local LEFT_SHARE = 1 / 3
local LINE_IN, LINE_OUT = 0.15, 0.25
-- the zone bar and the coordinates tab: the header of the /mo window (the game's BasicFrameTemplate title bar,
-- its TitleBg - which Details' title bar matches; a player's ask, for them to look alike). Without it: a grey
-- gradient like it, darker at the top. OpenMap's own colour put back when the border is off
local OPENMAP_BAR = { 0.07, 0.055, 0.04 } -- (OpenMap's zone bar colour: Frame.DARK_COLOUR)
local DB

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local function On() return not DB or DB.on ~= false end

local HeadFill = MasterOptions_Shared.HeaderFill

local OpenMapProfile = MasterOptions_Shared.OpenMapMiniMapProfile
local function Square()
    local p = OpenMapProfile()
    return not p or (p.shape or "square") == "square"
end

---------------------------------------------------------------------------
-- OpenMap's frames: the map frame (body), its border frame (edge) and the zone bar
---------------------------------------------------------------------------
local body, edge, bar
local PlaceCoords -- (below)

-- OpenMap_MiniMap's look on the minimap now: its map frame up (it hides it when off, or when it gives way to
-- another minimap addon - its Restore). Off: the game's own minimap, with the game's own coordinates line.
local function OpenMapLook()
    if not (body and body:IsShown()) then return false end
    local p = OpenMapProfile()
    return not (p and p.enabled == false)
end


local function Find()
    if body and edge then return true end
    local parent = Minimap and Minimap:GetParent()
    if not parent then return false end
    for _, c in ipairs({ parent:GetChildren() }) do
        for _, e in ipairs({ c:GetChildren() }) do
            if type(e.lines) == "table" and #e.lines == 4 and e.texture then
                body, edge = c, e
                return true
            end
        end
    end
    return false
end

local function FindBar()
    if bar or not body then return bar end
    -- (OpenMap's zone bar: a frame with .texture, 23 high - Frame.HEADER_H - and about as wide as the map;
    -- other frames hang from the map frame too: the painted map, the pins)
    local bw = body:GetWidth() or 0
    for _, c in ipairs({ body:GetChildren() }) do
        if c ~= edge and c.texture and not c.lines and c ~= _G.MasterOptionsMinimapBorder
            and math.abs((c:GetHeight() or 0) - 23) < 5 and math.abs((c:GetWidth() or 0) - bw) < 40 then
            bar = c
            break
        end
    end
    return bar
end

---------------------------------------------------------------------------
-- The nine-slice
---------------------------------------------------------------------------
local frame, pieces

-- a frame with the atlas cut into eight pieces (corners and edges, no middle); nil without the atlas
local function Slice(parent, name)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS)
    if not info then return nil end
    local file = info.file or info.filename
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    if not (file and l and r and t and b) then return nil end
    local cw, ch = (r - l) * CUT, (b - t) * CUT
    -- texcoords of each piece: x0, x1, y0, y1
    local X = { { l, l + cw }, { l + cw, r - cw }, { r - cw, r } }
    local Y = { { t, t + ch }, { t + ch, b - ch }, { b - ch, b } }
    local holder = CreateFrame("Frame", name, parent)
    holder.pieces = {}
    for row = 1, 3 do
        for col = 1, 3 do
            if not (row == 2 and col == 2) then -- (no middle: the map shows through)
                local tex = holder:CreateTexture(nil, "OVERLAY")
                tex:SetTexture(file)
                tex:SetTexCoord(X[col][1], X[col][2], Y[row][1], Y[row][2])
                holder.pieces[row * 10 + col] = tex
            end
        end
    end
    return holder
end

-- the pieces in a holder, corners k across
-- Rounded corners: the atlas's own (square ones - its edges running the whole length, crossing - left a notch at each
-- corner: the atlas's line is at the outer edge on the left and further in at the bottom; a player's screenshot). The
-- zone bar's background follows them (BarFill). Square where asked: the coordinates tab's side tucked under the rim.
local function SliceLayout(p, k, roundTop, roundBottom)
    for _, tex in pairs(p) do tex:ClearAllPoints() end
    p[11]:SetShown(roundTop) p[13]:SetShown(roundTop) p[31]:SetShown(roundBottom) p[33]:SetShown(roundBottom)
    if roundTop then
        p[11]:SetPoint("TOPLEFT") p[11]:SetSize(k, k)
        p[13]:SetPoint("TOPRIGHT") p[13]:SetSize(k, k)
        p[12]:SetPoint("TOPLEFT", p[11], "TOPRIGHT") p[12]:SetPoint("TOPRIGHT", p[13], "TOPLEFT")
    else
        p[12]:SetPoint("TOPLEFT") p[12]:SetPoint("TOPRIGHT")
    end
    p[12]:SetHeight(k)
    if roundBottom then
        p[31]:SetPoint("BOTTOMLEFT") p[31]:SetSize(k, k)
        p[33]:SetPoint("BOTTOMRIGHT") p[33]:SetSize(k, k)
        p[32]:SetPoint("BOTTOMLEFT", p[31], "BOTTOMRIGHT") p[32]:SetPoint("BOTTOMRIGHT", p[33], "BOTTOMLEFT")
    else
        p[32]:SetPoint("BOTTOMLEFT") p[32]:SetPoint("BOTTOMRIGHT")
    end
    p[32]:SetHeight(k)
    -- the sides: between the corners where rounded, the whole height where square
    p[21]:SetPoint("TOPLEFT", 0, roundTop and -k or 0) p[21]:SetPoint("BOTTOMLEFT", 0, roundBottom and k or 0) p[21]:SetWidth(k)
    p[23]:SetPoint("TOPRIGHT", 0, roundTop and -k or 0) p[23]:SetPoint("BOTTOMRIGHT", 0, roundBottom and k or 0) p[23]:SetWidth(k)
end

local function Build()
    if frame then return true end
    frame = Slice(body, "MasterOptionsMinimapBorder")
    if not frame then return false end
    pieces = frame.pieces
    return true
end

local function Scale() return (DB and DB.scale) or 1.6 end -- (1: as thick as on a button; thicker by default - a player's ask)

local function Layout(top, bottom)
    local s = Scale()
    local k = BUTTON * CUT * s       -- (the corner's size on screen)
    -- the rim outside the map and the zone bar, not over them: nothing on the map's edge (pins, the bar's buttons)
    -- goes under it, and the map's square corners stay inside the rim's rounded ones (a player's screenshot)
    local o = (DB and DB.outset) or RIM * s
    -- sides: the map's own, both of them. OpenMap's zone bar reaches a few units past the map's sides (its
    -- dark border's width): framing the bar's left and the map's right put a gap left of the map and the bar's
    -- end (the calendar) under the rim on the right (a player's screenshot). Height: the bar's, above or under.
    local up = top ~= body and (top:GetTop() or 0) - (body:GetTop() or 0) or 0
    local down = bottom ~= body and (body:GetBottom() or 0) - (bottom:GetBottom() or 0) or 0
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", body, "TOPLEFT", -o * LEFT_SHARE, o * LEFT_SHARE + math.max(0, up))
    frame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", o, -o - math.max(0, down))
    -- (rounded corners all round: the zone bar's background follows them - BarFill)
    SliceLayout(pieces, k, true, true)
end

-- OpenMap's own border: see-through while ours is on
local function OwnBorder(alpha)
    if not edge then return end
    if edge.texture then edge.texture:SetAlpha(alpha) end
    for _, line in ipairs(edge.lines or {}) do line:SetAlpha(alpha) end
    local b = FindBar()
    for _, line in ipairs(b and b.lines or {}) do line:SetAlpha(alpha) end -- (OpenMap's gold lines round the bar)
end

-- the zone bar's background: the title-bar gradient while ours is on, else OpenMap's colour again
local barStyled
local function BarLook(styled)
    local b = FindBar()
    local tex = b and b.texture
    if not (tex and tex.SetColorTexture) or barStyled == styled then return end
    if styled then HeadFill(tex)
    elseif barStyled then
        local c = OPENMAP_BAR
        if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
        if tex.SetHorizTile then tex:SetHorizTile(false) end
        if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
        tex:SetColorTexture(c[1], c[2], c[3], 1)
    end
    barStyled = styled
end

-- the zone bar's background stretched out under the rim on every side it touches: OpenMap draws the bar
-- inside its own gold frame's band (narrower than the map) and the rim's shading is see-through - both showed
-- the world between the rim and the bar (a player's screenshot). Back on the bar when ours is off.
-- The rim's corners are rounded (by the bar too - a player's ask): a background reaching the rim's lines there showed
-- its square corners past the curve, and one stopping at the curve's start left the world showing inside the curve (a
-- player's screenshot: gaps in the header). So it's three pieces: the middle, between the corners, the whole height;
-- and in each corner a piece cut round by a circle (the game's round portrait mask) - filled inside the curve only.
-- (Styled as the bar: HeadFill.)
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local barSides, barMasks = {}, {}
local function BarSide(b, tex, i)
    if not barSides[i] then
        local layer, sub = tex:GetDrawLayer()
        local s = b:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
        HeadFill(s)
        if b.CreateMaskTexture and s.AddMaskTexture then
            local m = b:CreateMaskTexture()
            m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            s:AddMaskTexture(m)
            barMasks[i] = m
        end
        barSides[i] = s
    end
    return barSides[i], barMasks[i]
end

local function BarFill(on)
    local b = FindBar()
    local tex = b and b.texture
    if not (tex and tex.ClearAllPoints) then return end
    tex:ClearAllPoints()
    for _, side in pairs(barSides) do side:Hide() end
    local bl, bt, bb = body:GetLeft(), body:GetTop(), body:GetBottom()
    local t, btm = b:GetTop(), b:GetBottom()
    if not (on and bl and bt and bb and t and btm) then tex:SetAllPoints(b) return end
    local o = (DB and DB.outset) or RIM * Scale()
    local left, right = -o * LEFT_SHARE + o * LINE_IN, o * LINE_OUT
    local k = BUTTON * CUT * Scale()                 -- (the rim's corner)
    local inL, inR = -o * LEFT_SHARE + k, o - k      -- (the middle: from the left corner's end to the right one's)
    local above = t > bt
    local outer, inner -- (the background's edge at the rim's line, and at the map; offsets from the map's edge)
    if above then outer, inner = t - bt + o * LEFT_SHARE - o * LINE_IN, btm - bt
    else outer, inner = btm - bb - o * LINE_OUT, t - bb end
    local edgeY = above and "TOP" or "BOTTOM"
    if above then
        tex:SetPoint("TOPLEFT", body, "TOPLEFT", inL, outer)
        tex:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", inR, inner)
    else
        tex:SetPoint("TOPLEFT", body, "BOTTOMLEFT", inL, inner)
        tex:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", inR, outer)
    end
    -- the corners: from the rim's side line to the middle, the bar's whole height, cut round by a circle k across
    -- from its centre (where the curve's centre is: k in from the frame's side and its rim line). Without masks on
    -- this client: only below the curve (no square past it), as before.
    local centreY = above and (outer - k) or (outer + k)
    for i, c in ipairs({ { "LEFT", left, inL, inL }, { "RIGHT", inR, right, inR } }) do
        local s, m = BarSide(b, tex, i)
        local anchor = edgeY .. c[1]
        s:ClearAllPoints()
        local fromY = m and outer or centreY -- (masked: the whole height; else only below the curve)
        local y1, y2 = above and fromY or inner, above and inner or fromY
        s:SetPoint("TOPLEFT", body, anchor, c[2], y1)
        s:SetPoint("BOTTOMRIGHT", body, anchor, c[3], y2)
        if m then
            m:ClearAllPoints()
            m:SetSize(2 * k, 2 * k)
            m:SetPoint("CENTER", body, anchor, c[4], centreY)
        end
        s:SetShown(m ~= nil or (above and (centreY - inner) or (inner - centreY)) > 0.5)
    end
end

-- the rim above the map's border and the zone bar (its background reaches under the rim now: drawn over it, it
-- hid the rim - a player's screenshot) and the bar's buttons: the highest strata of those, one level up
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function Above(b)
    local strata, level = edge:GetFrameStrata(), edge:GetFrameLevel()
    local header = MinimapCluster and MinimapCluster.ZoneTextButton
    for _, f in ipairs({ b or false, header or false }) do
        if f and f.GetFrameStrata then
            local fs, fl = f:GetFrameStrata(), f:GetFrameLevel() or 0
            if f == header then fl = fl + 2 end -- (OpenMap puts the bar's buttons two levels over it)
            if (STRATA[fs] or 0) > (STRATA[strata] or 0) then strata, level = fs, fl
            elseif fs == strata and fl > level then level = fl end
        end
    end
    return strata, level + 1
end

local function Apply()
    if not Find() then return false end
    local want = On() and Square() and OpenMapLook()
    if not want then
        if frame then frame:Hide() end
        OwnBorder(1)
        BarLook(false)
        BarFill(false)
        return true
    end
    if not Build() then return false end
    -- the rim round the map and the zone bar together (the bar above the map, or under it)
    local top, bottom = body, body
    local b = FindBar()
    if b and b:IsShown() then
        local bt, mt = b:GetTop(), body:GetTop()
        if bt and mt and bt > mt then top = b else bottom = b end
    end
    local strata, level = Above(b)
    frame:SetFrameStrata(strata)
    frame:SetFrameLevel(level)
    Layout(top, bottom)
    frame:Show()
    OwnBorder(0)
    BarLook(true)
    BarFill(b and b:IsShown())
    return true
end

local ApplySoon = MasterOptions_Shared.Debounce(function()
    Check("drawing the minimap border", pcall(Apply))
    Check("placing the coordinates", pcall(PlaceCoords)) -- (the tab sits on the frame)
end, 0.2)
local coordsSide -- { wanted = "top" | "bottom", used = the edge the tab is on } once placed
MasterOptions_MinimapBorder = {
    Apply = function() ApplySoon(0) end,
    PlaceCoords = function() Check("placing the coordinates", pcall(PlaceCoords)) end,
    -- the edge asked for and the one used: they differ when the asked one would put the tab off the screen
    CoordsSide = function() if coordsSide then return coordsSide.wanted, coordsSide.used end end,
}

---------------------------------------------------------------------------
-- The coordinates in a small tab of their own, sticking out of the frame like the zone bar (a player's ask):
-- top or bottom edge, left, centre or right. Same dark background as the zone bar, the same action-button rim
-- (half size), its edge tucked under the frame's rim so it grows out of it. The game's own coordinates line
-- (Edit Mode's "show coordinates": MinimapContainer.PlayerCoords - it hung on the map's bottom edge, under
-- OpenMap's bottom row of addon buttons) is made see-through meanwhile; the tab shows while the game's would
-- (that setting on). DB.coords: "inside" (the numbers alone, in the map's top-right corner) | "top-left" |
-- "top-center" | "top-right" | "bottom-..." (a tab) | "game" (the game's own).
---------------------------------------------------------------------------
local tab

-- Clear of the minimap's buttons: OpenMap_MiniMap lays other addons' buttons round the map's edge (its slots are its
-- own - nothing outside it can take some away), and one where the tab sits covered it or sat under it. So the tab
-- moves instead: along its edge, the least it can, to the first place no button overlaps - within the frame's
-- corners. No such place: where it was asked to be.
local placed -- { point, anchor, relPoint, x, y }: where PlaceCoords put it, before moving it clear
local function Rect(r)
    local l, rr, b, t = r:GetLeft(), r:GetRight(), r:GetBottom(), r:GetTop()
    if not (l and rr and b and t) then return nil end
    local e = r:GetEffectiveScale() or 1
    return l * e, rr * e, b * e, t * e
end
local function MinimapButtons()
    local out = {}
    for _, c in ipairs({ Minimap:GetChildren() }) do
        if c ~= tab and c ~= frame and c:IsShown() and c.IsObjectType and c:IsObjectType("Button") then
            local l, r, b, t = Rect(c)
            if l and (r - l) > 8 and (r - l) < 60 then out[#out + 1] = { l, r, b, t } end
        end
    end
    return out
end
local function ClearOfButtons()
    if not (placed and tab and tab:IsShown()) then return end
    tab:ClearAllPoints()
    tab:SetPoint(placed[1], placed[2], placed[3], placed[4], placed[5])
    local L, R, B, T = Rect(tab)
    if not L then return end
    local hits = {}
    for _, btn in ipairs(MinimapButtons()) do
        if btn[3] < T - 1 and btn[4] > B + 1 then hits[#hits + 1] = btn end -- (level with the tab)
    end
    local function Free(dx)
        for _, btn in ipairs(hits) do
            if btn[1] < R + dx - 1 and btn[2] > L + dx + 1 then return false end
        end
        return true
    end
    if Free(0) then return end
    -- the room along the edge: within the frame (the map without it), clear of its rounded corners
    local ring = frame and frame:IsShown()
    local fl, fr = Rect(ring and frame or body)
    if not fl then return end
    local inset = ring and BUTTON * CUT * Scale() * (frame:GetEffectiveScale() or 1) or 0
    local best
    for _, btn in ipairs(hits) do
        for _, dx in ipairs({ btn[1] - 2 - R, btn[2] + 2 - L }) do
            if L + dx >= fl + inset - 0.5 and R + dx <= fr - inset + 0.5 and Free(dx)
                and (not best or math.abs(dx) < math.abs(best)) then best = dx end
        end
    end
    if not best then return end
    tab:ClearAllPoints()
    tab:SetPoint(placed[1], placed[2], placed[3], placed[4] + best / (tab:GetEffectiveScale() or 1), placed[5])
end

local function Coords()
    local c = MinimapCluster and MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords
    return type(c) == "table" and c.SetAlpha and c or nil
end

local function CoordsMode()
    local m = DB and DB.coords
    if m == "game" then return "game" end
    if m == "top" or m == nil then return "top-center" end -- ("top": the first version's - the map's top edge)
    return m
end

local function PlayerXY()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return "--, --" end
    local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
    local ok, pos = false, nil
    if okM and map then ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player") end
    if ok and pos then
        local x, y = pos:GetXY()
        if x and y and (x > 0 or y > 0) then return ("%.1f, %.1f"):format(x * 100, y * 100) end
    end
    return "--, --" -- (no position: in an instance, or between maps)
end

local function TabBuild()
    if tab then return tab end
    tab = Slice(body, "MasterOptionsMinimapCoords") or CreateFrame("Frame", "MasterOptionsMinimapCoords", body)
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    HeadFill(tab.bg) -- (as the zone bar)
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local wait, shown, look = 0, nil, 0
    tab:SetScript("OnUpdate", function(self, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.2
        local xy = PlayerXY()
        if xy ~= shown then shown = xy; self.text:SetText(xy) end -- (standing still: nothing redrawn)
        -- (OpenMap_MiniMap lays its buttons out again as addons add or move theirs: looked at once a second)
        look = look + 1
        if look >= 5 then look = 0; Check("keeping the coordinates clear of buttons", pcall(ClearOfButtons)) end
    end)
    return tab
end

-- the side the tab fits on: the one asked for, else the other when it would leave the screen (a map at the screen's
-- top - OpenMap_MiniMap keeps the map on screen, but not what sticks out of it)
local function OnScreenSide(side, top, bottom, h)
    local ui = UIParent
    local us = ui and ui.GetEffectiveScale and ui:GetEffectiveScale() or 1
    local screenTop = ui and ui.GetTop and ui:GetTop()
    if side == "bottom" then
        local b, es = bottom:GetBottom(), bottom.GetEffectiveScale and bottom:GetEffectiveScale() or 1
        if b and (b - h) * es < 0 then return "top" end
    elseif screenTop then
        local t, es = top:GetTop(), top.GetEffectiveScale and top:GetEffectiveScale() or 1
        if t and (t + h) * es > screenTop * us then return "bottom" end
    end
    return side
end

-- "inside": just the numbers, in the map's top-right corner - no tab, no background (outlined, so they read over the
-- map; a player's ask: "just simplify it"). Above the map's pins.
local inner
local function InnerBuild()
    if inner then return inner end
    inner = CreateFrame("Frame", "MasterOptionsMinimapCoordsInside", body)
    inner:SetSize(80, 14)
    inner.text = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font, size = inner.text:GetFont()
    if font then inner.text:SetFont(font, size or 10, "OUTLINE") end
    inner.text:SetPoint("TOPRIGHT")
    inner.text:SetJustifyH("RIGHT")
    local wait, shown = 0, nil
    inner:SetScript("OnUpdate", function(self, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.2
        local xy = PlayerXY()
        if xy ~= shown then shown = xy; self.text:SetText(xy) end
    end)
    return inner
end

PlaceCoords = function()
    local c = Coords()
    local mode = CoordsMode()
    -- (OpenMap_MiniMap's look off: the game's line - until 2.9.0 it stayed see-through with no tab: no coordinates)
    if mode == "game" or not OpenMapLook() then
        if tab then tab:Hide() end
        if inner then inner:Hide() end
        if c then c:SetAlpha(1) end
        return
    end
    if c then c:SetAlpha(0) end
    -- shown while the game's line would be (its setting, also OpenMap's "Coordinates under the map")
    local want = (c and c:IsShown()) or (GetCVar and GetCVar("minimapShowPlayerCoords") == "1")
    if not want then
        if tab then tab:Hide() end
        if inner then inner:Hide() end
        return
    end
    if mode == "inside" then
        if tab then tab:Hide() end
        coordsSide = nil
        InnerBuild()
        inner:ClearAllPoints()
        inner:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -4)
        inner:SetFrameStrata(edge and edge:GetFrameStrata() or body:GetFrameStrata())
        inner:SetFrameLevel(((edge and edge:GetFrameLevel()) or body:GetFrameLevel() or 1) + 10)
        inner.text:SetText(PlayerXY())
        inner:Show()
        return
    end
    if inner then inner:Hide() end
    TabBuild()
    local s = Scale()
    local k = BUTTON * CUT * s * 0.5          -- (the tab's corners: half the frame's)
    local ring = frame and frame:IsShown()
    -- what it sticks out of: our frame, or (OpenMap's own border) the map and the zone bar
    local top, bottom = frame, frame
    if not ring then
        top, bottom = body, body
        local b = FindBar()
        if b and b:IsShown() then
            if (b:GetTop() or 0) > (body:GetTop() or 0) then top = b else bottom = b end
        end
    end
    local tuck = ring and RIM * s or 0         -- (under the frame's rim, so the two rims meet)
    local side, align = mode:match("^(%a+)%-(%a+)$")
    local inset = ring and BUTTON * CUT * s or 0 -- (clear of the frame's rounded corner)
    local point = (align == "left" and "LEFT") or (align == "right" and "RIGHT") or ""
    local x = (align == "left" and inset) or (align == "right" and -inset) or 0
    tab.text:SetText(PlayerXY())
    local h = math.max(12, tab.text:GetStringHeight() or 12) + 2 * RIM * s * 0.5 + 4
    tab:SetSize(math.max(62, (tab.text:GetStringWidth() or 50) + 2 * k + 8), h + tuck)
    local wanted = side
    side = OnScreenSide(side, top, bottom, h)
    coordsSide = { wanted = wanted, used = side } -- (for the /mo row: says so when it had to use the other edge)
    tab:ClearAllPoints()
    tab.text:ClearAllPoints()
    if side == "bottom" then
        placed = { "TOP" .. point, bottom, "BOTTOM" .. point, x, tuck }
        tab.text:SetPoint("CENTER", 0, -tuck / 2)
    else
        placed = { "BOTTOM" .. point, top, "TOP" .. point, x, -tuck }
        tab.text:SetPoint("CENTER", 0, tuck / 2)
    end
    tab:SetPoint(placed[1], placed[2], placed[3], placed[4], placed[5])
    local inner = RIM * s * 0.5
    tab.bg:ClearAllPoints()
    -- (to the rim's lines: theirs at the outer edge on the left and top, further in on the right and bottom -
    -- inset evenly, the top and left showed the world under the line's shading)
    tab.bg:SetPoint("TOPLEFT", inner * 0.3, -inner * 0.3)
    tab.bg:SetPoint("BOTTOMRIGHT", -inner, inner)
    -- (rounded on its outer side; square where it's tucked under the frame's rim)
    if tab.pieces then SliceLayout(tab.pieces, k, side ~= "bottom", side == "bottom") end
    tab:SetFrameStrata(ring and frame:GetFrameStrata() or edge:GetFrameStrata())
    tab:SetFrameLevel(math.max(0, (ring and frame:GetFrameLevel() or edge:GetFrameLevel() + 1) - 1))
    tab:Show()
    ClearOfButtons()
end

local coordsHooked = false
local function HookCoords()
    local c = Coords()
    if coordsHooked or not c then return end
    coordsHooked = true
    -- the game's line switched on or off (Edit Mode, OpenMap's setting): the tab follows
    local function Follow() C_Timer.After(0, function() Check("placing the coordinates", pcall(PlaceCoords)) end) end
    if c.HookScript then
        c:HookScript("OnShow", Follow)
        c:HookScript("OnHide", Follow)
    end
end
-- OpenMap lays the minimap buttons out again (it listens to LibDBIcon's "icon created")
local function RelayButtons()
    local stub = _G.LibStub
    local lib = stub and stub("LibDBIcon-1.0", true)
    if type(lib) == "table" and lib.callbacks and lib.callbacks.Fire then
        lib.callbacks:Fire("LibDBIcon_IconCreated")
    end
end

local hooked = false
local function Hook()
    if hooked or not (body and edge) then return end
    hooked = true
    body:HookScript("OnShow", function() ApplySoon() end)
    body:HookScript("OnHide", function() ApplySoon(0) end) -- (OpenMap_MiniMap's look off: the game's coordinates back)
    body:HookScript("OnSizeChanged", function() ApplySoon() end)
    -- OpenMap sets its border up again when its look changes (any of its settings): shown, and its colour set -
    -- SetVertexColor(1, 1, 1, 1) puts its alpha back too. Hidden again at once, not after the 0.2 s wait
    -- (its gold frame blinked through - a player's report); the rest a moment later.
    local function Again()
        if not (frame and frame:IsShown()) then return end
        Check("hiding OpenMap's border", pcall(OwnBorder, 0))
        ApplySoon()
    end
    for _, t in ipairs({ edge.texture, unpack(edge.lines or {}) }) do
        for _, method in ipairs({ "SetShown", "Show", "SetVertexColor", "SetTexture" }) do -- (not SetAlpha: ours)
            if t[method] then hooksecurefunc(t, method, Again) end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(f.RegisterEvent, f, "EDIT_MODE_LAYOUTS_UPDATED")
pcall(f.RegisterEvent, f, "CVAR_UPDATE")
f:SetScript("OnEvent", function(_, event, name)
    if event == "CVAR_UPDATE" then -- (the coordinates setting: the tab follows it)
        if name == "minimapShowPlayerCoords" then C_Timer.After(0, function() Check("placing the coordinates", pcall(PlaceCoords)) end) end
        return
    end
    if event == "ADDON_LOADED" then
        if name == ADDON then
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            DB = MasterOptions_MinimapBorderDB
        end
        return
    end
    -- (OpenMap sets its look up at login and once more a moment later: after both)
    for _, d in ipairs({ 0.5, 2.5 }) do
        C_Timer.After(d, function()
            local ok = Check("drawing the minimap border", pcall(Apply))
            if ok then Hook() end
            if Check("placing the coordinates", pcall(PlaceCoords)) then HookCoords() end
        end)
    end
    -- Other addons' minimap buttons: OpenMap lays them round its edge at login, 2 s later, and whenever
    -- LibDBIcon makes one - but a button that places itself later still (an addon setting up late) stayed
    -- where it put itself, until you dragged one (a player's report). LibDBIcon's own "icon created" signal,
    -- which only OpenMap listens to, has OpenMap lay them all out again: a few seconds in, and once more.
    for _, d in ipairs({ 4, 10 }) do
        C_Timer.After(d, function() Check("laying out the minimap buttons", pcall(RelayButtons)) end)
    end
end)

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
