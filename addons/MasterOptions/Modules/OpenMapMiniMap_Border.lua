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
local DB

local function Check(where, ok, ...)
    local r = not ok and _G.MasterOptions_ReportError
    if r then r(ADDON, where, ...) end
    return ok, ...
end

local function On() return not DB or DB.on ~= false end

local function OpenMapProfile()
    local db = _G.OpenMapMiniMapDB
    if type(db) ~= "table" then return nil end
    local first = UnitName("player")
    local c = first and type(db.char) == "table" and db.char[first .. "-" .. (GetRealmName() or "")]
    if type(c) == "table" and c.own and type(c.profile) == "table" then return c.profile end
    return type(db.profile) == "table" and db.profile or nil
end
local function Square()
    local p = OpenMapProfile()
    return not p or (p.shape or "square") == "square"
end

---------------------------------------------------------------------------
-- OpenMap's frames: the map frame (body), its border frame (edge) and the zone bar
---------------------------------------------------------------------------
local body, edge, bar
local PlaceCoords -- (below)

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
local function SliceLayout(p, k)
    for _, tex in pairs(p) do tex:ClearAllPoints() end
    p[11]:SetPoint("TOPLEFT") p[11]:SetSize(k, k)
    p[13]:SetPoint("TOPRIGHT") p[13]:SetSize(k, k)
    p[31]:SetPoint("BOTTOMLEFT") p[31]:SetSize(k, k)
    p[33]:SetPoint("BOTTOMRIGHT") p[33]:SetSize(k, k)
    p[12]:SetPoint("TOPLEFT", p[11], "TOPRIGHT") p[12]:SetPoint("BOTTOMRIGHT", p[13], "BOTTOMLEFT")
    p[32]:SetPoint("TOPLEFT", p[31], "TOPRIGHT") p[32]:SetPoint("BOTTOMRIGHT", p[33], "BOTTOMLEFT")
    p[21]:SetPoint("TOPLEFT", p[11], "BOTTOMLEFT") p[21]:SetPoint("BOTTOMRIGHT", p[31], "TOPRIGHT")
    p[23]:SetPoint("TOPLEFT", p[13], "BOTTOMLEFT") p[23]:SetPoint("BOTTOMRIGHT", p[33], "TOPRIGHT")
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
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", top, "TOPLEFT", -o, o)
    frame:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", o, -o)
    SliceLayout(pieces, k)
end

-- OpenMap's own border: see-through while ours is on
local function OwnBorder(alpha)
    if not edge then return end
    if edge.texture then edge.texture:SetAlpha(alpha) end
    for _, line in ipairs(edge.lines or {}) do line:SetAlpha(alpha) end
    local b = FindBar()
    for _, line in ipairs(b and b.lines or {}) do line:SetAlpha(alpha) end -- (OpenMap's gold lines round the bar)
end

local function Apply()
    if not Find() then return false end
    local want = On() and Square()
    if not want then
        if frame then frame:Hide() end
        OwnBorder(1)
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
    frame:SetFrameStrata(edge:GetFrameStrata())
    frame:SetFrameLevel(edge:GetFrameLevel() + 1)
    Layout(top, bottom)
    frame:Show()
    OwnBorder(0)
    return true
end

local pending = false
local function ApplySoon(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 0.2, function()
        pending = false
        Check("drawing the minimap border", pcall(Apply))
        Check("placing the coordinates", pcall(PlaceCoords)) -- (the tab sits on the frame)
    end)
end
MasterOptions_MinimapBorder = {
    Apply = function() ApplySoon(0) end,
    PlaceCoords = function() Check("placing the coordinates", pcall(PlaceCoords)) end,
}

---------------------------------------------------------------------------
-- The coordinates in a small tab of their own, sticking out of the frame like the zone bar (a player's ask):
-- top or bottom edge, left, centre or right. Same dark background as the zone bar, the same action-button rim
-- (half size), its edge tucked under the frame's rim so it grows out of it. The game's own coordinates line
-- (Edit Mode's "show coordinates": MinimapContainer.PlayerCoords - it hung on the map's bottom edge, under
-- OpenMap's bottom row of addon buttons) is made see-through meanwhile; the tab shows while the game's would
-- (that setting on). DB.coords: "top-left" | "top-center" | "top-right" | "bottom-..." | "game" (the game's own).
---------------------------------------------------------------------------
local tab

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
    tab.bg:SetColorTexture(0.07, 0.055, 0.04, 1) -- (OpenMap's zone bar colour)
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local wait = 0
    tab:SetScript("OnUpdate", function(self, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.2
        self.text:SetText(PlayerXY())
    end)
    return tab
end

PlaceCoords = function()
    local c = Coords()
    local mode = CoordsMode()
    if mode == "game" or not body then
        if tab then tab:Hide() end
        if c then c:SetAlpha(1) end
        return
    end
    if c then c:SetAlpha(0) end
    -- shown while the game's line would be (its setting, also OpenMap's "Coordinates under the map")
    local want = (c and c:IsShown()) or (GetCVar and GetCVar("minimapShowPlayerCoords") == "1")
    if not want then
        if tab then tab:Hide() end
        return
    end
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
    tab:ClearAllPoints()
    tab.text:ClearAllPoints()
    if side == "bottom" then
        tab:SetPoint("TOP" .. point, bottom, "BOTTOM" .. point, x, tuck)
        tab.text:SetPoint("CENTER", 0, -tuck / 2)
    else
        tab:SetPoint("BOTTOM" .. point, top, "TOP" .. point, x, -tuck)
        tab.text:SetPoint("CENTER", 0, tuck / 2)
    end
    local inner = RIM * s * 0.5
    tab.bg:ClearAllPoints()
    tab.bg:SetPoint("TOPLEFT", inner, -inner)
    tab.bg:SetPoint("BOTTOMRIGHT", -inner, inner)
    if tab.pieces then SliceLayout(tab.pieces, k) end
    tab:SetFrameStrata(edge:GetFrameStrata())
    tab:SetFrameLevel(math.max(0, (ring and frame:GetFrameLevel() or edge:GetFrameLevel() + 1) - 1))
    tab:Show()
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
    body:HookScript("OnSizeChanged", function() ApplySoon() end)
    -- OpenMap switches its border pieces on and off when its look changes: ours stays on top of that
    for _, t in ipairs({ edge.texture, unpack(edge.lines or {}) }) do
        hooksecurefunc(t, "SetShown", function() if frame and frame:IsShown() then ApplySoon() end end)
        hooksecurefunc(t, "Show", function() if frame and frame:IsShown() then ApplySoon() end end)
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

-- (Master Options runs this after the saved variables are in: the setup this did on its own ADDON_LOADED as a
-- separate addon, now)
local h = f.GetScript and f:GetScript("OnEvent") or f.OnEvent -- (f.OnEvent: the sandbox tests' frames)
if h then h(f, "ADDON_LOADED", ADDON) end
end)
