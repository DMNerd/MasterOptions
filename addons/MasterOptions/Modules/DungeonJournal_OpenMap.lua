-- Master Options module (was the addon MasterOptions_DungeonJournal_OpenMap): runs when ForeverDungeonJournal and OpenMap are loaded.
MasterOptions_Module("DungeonJournal_OpenMap", { "ForeverDungeonJournal", "OpenMap" }, function(ADDON)

-- Dungeon Journal <-> OpenMap: the map inside dungeons and OpenMap's dungeon entrance clicks.
-- (Dungeon Journal's Show on Map as an OpenMap pin was part of this until 2.13.0: DungeonJournal_ShowOnMap.)

--------------------------------------------------------------------------------
-- Map inside dungeons: Dungeon Journal's (was the separate addon OpenMap_NoDungeonMap)
-- Master Options' "Map inside dungeons" (MasterOptionsDB.dungeonMap): "journal" (the default) or "openmap".
-- With "journal": OpenMap's own dungeon map is off, and OpenMap's dungeon entrance icons open Dungeon
-- Journal's map of that dungeon on the world map (its journal page when it has no map); several dungeons at
-- one entrance (Scarlet Monastery, Blackrock Mountain): a list to pick one. Right-click, its "World Map"
-- button or Esc goes back. Must run now, as the files load: before OpenMap's PLAYER_LOGIN setup.
-- (Left to OpenMap_NoDungeonMap if that is still on, so the two never both do it.)
--------------------------------------------------------------------------------
-- OpenMap's own switch for its map inside dungeons (Map\Dungeons.lua: worldmap.dungeonInside; its menu's
-- "Dungeon maps inside dungeons"). Until 2.3.1 this replaced OpenMap's whole SetupDungeons, which now also
-- does Zephras Isle's map, marking dungeons you entered, the wheel back out, the dungeon card, the quest
-- log docking and the Scarlet Monastery / Dire Maul wing for Dungeon Journal - all of that was lost.
local insideWanted -- true / false once decided below: set again at login (OpenMap's settings may load later)
local function SetOpenMapInside(mod, on)
    insideWanted = on
    local d = mod and mod.db
    if type(d) ~= "table" then return end
    MasterOptions_DJOpenMapDB = MasterOptions_DJOpenMapDB or {}
    local store = MasterOptions_DJOpenMapDB -- (this runs before the module's own ADDON_LOADED setup below)
    if not on then
        if d.dungeonInside ~= false then d.dungeonInside = false; store.setInside = true end
    elseif store.setInside then
        d.dungeonInside = nil -- (only what we turned off: back to OpenMap's default)
        store.setInside = nil
    end
end

-- What clicking an OpenMap dungeon entrance opens (Master Options' "Dungeon entrance click",
-- MasterOptionsDB.entranceClick): "djmap" Dungeon Journal's map of the dungeon on the world map (ours, below),
-- "djpage" its journal page (OpenMap's own option, worldmap.entranceClick = "journal"), "openmap" OpenMap's map
-- of it (entranceClick = "map"). Not chosen yet: as Map inside dungeons (OpenMap's map -> OpenMap's).
local function EntranceMode()
    local mo = _G.MasterOptionsDB
    local v = type(mo) == "table" and mo.entranceClick
    if v == "djmap" or v == "djpage" or v == "openmap" then return v end
    return (type(mo) == "table" and mo.dungeonMap == "openmap") and "openmap" or "djmap"
end
local function SetOpenMapEntrance(mod)
    local d = mod and mod.db
    if type(d) == "table" then d.entranceClick = (EntranceMode() == "djpage") and "journal" or "map" end
end

local function DungeonMapPart()
    local A = C_AddOns or {}
    local state = A.GetAddOnEnableState and A.GetAddOnEnableState("OpenMap_NoDungeonMap", UnitName("player"))
    if (state or 0) > 0 then return end

    local ns = _G.OpenMap
    local mod = ns and ns.GetModule and ns:GetModule("worldmap")
    if not mod then return end

    -- 1. the map inside dungeons: OpenMap's own switch; with Dungeon Journal's, the floors OpenMap holds there off
    local mo = _G.MasterOptionsDB
    if type(mo) == "table" and mo.dungeonMap == "openmap" then
        SetOpenMapInside(mod, true)
    else
        SetOpenMapInside(mod, false)
        mod.HoldDungeonHere = function() end
    end

    -- entrance clicks: OpenMap's own option; Dungeon Journal's map (2. and 3. below) only when that's the pick
    SetOpenMapEntrance(mod)
    if EntranceMode() ~= "djmap" then return end

    -- 2. Dungeon Journal's map on the world map, for a dungeon you're not in
    local FDJ = _G.ForeverDungeonJournal_NS
    local preview -- Dungeon Journal's name of the dungeon being shown, or nil
    if FDJ and type(FDJ.RefreshWorldMapOverlay) == "function" then
        -- its overlay shows FDJ.CurrentDungeon(): only while it refreshes, and only while previewing,
        -- that answers the clicked dungeon
        local refresh = FDJ.RefreshWorldMapOverlay
        FDJ.RefreshWorldMapOverlay = function(...)
            if not preview then return refresh(...) end
            local current = FDJ.CurrentDungeon
            FDJ.CurrentDungeon = function() return preview end
            local ok, err = pcall(refresh, ...)
            FDJ.CurrentDungeon = current
            if not ok then error(err, 0) end
        end
    else
        FDJ = nil
    end

    local function HasMap(key) return FDJ and FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[key] ~= nil end

    -- the world map navigated away (its navigation bar, a zone clicked open, the mouse wheel out) while a dungeon
    -- is previewed: the preview ends - Dungeon Journal's map only goes with a map change it doesn't watch
    local previewMap
    if FDJ and WorldMapFrame and type(WorldMapFrame.OnMapChanged) == "function" then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            if not preview then return end
            local now = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or WorldMapFrame.mapID
            if now == previewMap then return end
            preview, previewMap = nil, nil
            C_Timer.After(0, function()
                if WorldMapFrame:IsShown() then pcall(FDJ.RefreshWorldMapOverlay) end
            end)
        end)
    end

    -- the overlay went away (right-click, its World Map button, the map closed): preview over
    local hookedBackdrop
    local function WatchBackdrop()
        local journal = _G.ForeverDungeonJournalFrame
        local backdrop = journal and journal.dungeonMapPanel and journal.dungeonMapPanel:GetParent()
        if not backdrop or backdrop == journal or hookedBackdrop == backdrop then return end
        hookedBackdrop = backdrop
        backdrop:HookScript("OnHide", function()
            if not preview then return end
            preview = nil
            C_Timer.After(0, function()
                if WorldMapFrame and WorldMapFrame:IsShown() then pcall(FDJ.RefreshWorldMapOverlay) end
            end)
        end)
    end

    local function OpenJournalPage(key)
        if not (FDJ and FDJ.DB and FDJ.DB[key]) then return false end
        local frame, toggle = _G.ForeverDungeonJournalFrame, _G.ForeverDungeonJournal_Toggle
        if not (frame and frame:IsShown()) and type(toggle) == "function" then pcall(toggle) end
        if HasMap(key) and type(FDJ.OpenDungeonMap) == "function" then return (pcall(FDJ.OpenDungeonMap, key)) end
        return type(FDJ.OpenBossPage) == "function" and (pcall(FDJ.OpenBossPage, key)) or false
    end

    local function ShowOnWorldMap(key)
        if not (HasMap(key) and WorldMapFrame and WorldMapFrame:IsShown()) then return false end
        if FDJ.IsDungeonMapLocked and FDJ.IsDungeonMapLocked(key) then return false end -- (its RPG mode)
        local journal = _G.ForeverDungeonJournalFrame
        if journal and journal:IsShown() then return false end -- (it's using its map panel itself)
        preview = key
        previewMap = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or WorldMapFrame.mapID
        pcall(FDJ.RefreshWorldMapOverlay)
        if not FDJ.IsWorldMapOverlayAttached() then
            local button = _G.ForeverDungeonJournalWorldMapToggle -- (switched to the world map earlier)
            if button and button:IsShown() then button:Click() end
        end
        if FDJ.IsWorldMapOverlayAttached() then
            WatchBackdrop()
            return true
        end
        preview = nil
        pcall(FDJ.RefreshWorldMapOverlay)
        return false
    end

    local function Open(key)
        if not ShowOnWorldMap(key) and not OpenJournalPage(key) then
            print("|cffffd200Master Options:|r Dungeon Journal has nothing for " .. key .. ".")
        end
    end

    -- OpenMap's names for dungeons -> Dungeon Journal's
    local function Plain(name)
        return ((name or ""):lower():gsub("^the ", ""):gsub("%s*[-:]%s*", ": "))
    end
    local ALIAS = { ["stormwind stockade"] = "stockade" }
    -- Dungeon Journal's dungeons for one of OpenMap's instances: by name, or its parts
    -- ("Stratholme" -> "Stratholme: Living", "Stratholme: Undead")
    local function JournalKeys(inst)
        local keys = {}
        if not (FDJ and FDJ.DB) then return keys end
        local want = Plain(inst[2])
        want = ALIAS[want] or want
        local exact, parts = nil, {}
        for key, entry in pairs(FDJ.DB) do
            if type(entry) == "table" and (not entry.previewOnly or HasMap(key)) then
                local p = Plain(key)
                if p == want then exact = key
                elseif p:sub(1, #want + 2) == want .. ": " then parts[#parts + 1] = key end
            end
        end
        if exact then keys[1] = exact return keys end
        table.sort(parts)
        return parts
    end

    -- several at one entrance (Scarlet Monastery's wings, Blackrock Mountain): pick one
    local chooser
    local HEADER = 30 -- (the title bar)
    local function CloseOnClickElsewhere()
        if not (chooser and chooser:IsShown()) then return end
        if chooser:IsMouseOver() then return end
        if chooser.pin and chooser.pin:IsVisible() and chooser.pin:IsMouseOver() then return end
        chooser:Hide()
    end
    local function Choose(pin, keys)
        if not chooser then
            -- (the /mo window's frame: the game's BasicFrameTemplate - its title bar and close button - so what
            -- Master Options puts on others' maps looks like Master Options; a plain dark box where it's missing)
            local ok, f = pcall(CreateFrame, "Frame", "MasterOptionsDungeonChooser", WorldMapFrame, "BasicFrameTemplateWithInset")
            chooser = ok and f or CreateFrame("Frame", "MasterOptionsDungeonChooser", WorldMapFrame)
            chooser:SetFrameStrata("TOOLTIP")
            chooser:EnableMouse(true)
            if not ok then
                local bg = chooser:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.05, 0.04, 0.03, 0.92)
            end
            local title = chooser.TitleText or chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            if not chooser.TitleText then title:SetPoint("TOP", 0, -5) end
            title:SetText("Pick a dungeon")
            local close = chooser.CloseButton
            if not close then
                close = CreateFrame("Button", nil, chooser, "UIPanelCloseButton")
                close:SetSize(26, 26)
                close:SetPoint("TOPRIGHT", 1, 1)
            end
            close:SetScript("OnClick", function() chooser:Hide() end)
            chooser.rows = {}
            WorldMapFrame:HookScript("OnHide", function() chooser:Hide() end)
            -- a click anywhere else closes it: every mouse click in the game, so only while it's open
            local watcher = CreateFrame("Frame", nil, chooser)
            watcher:SetScript("OnEvent", CloseOnClickElsewhere)
            local global = pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
            if global then
                watcher:UnregisterEvent("GLOBAL_MOUSE_DOWN")
                chooser:SetScript("OnShow", function() watcher:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
            else
                local sc = WorldMapFrame.ScrollContainer
                if sc then sc:HookScript("OnMouseDown", CloseOnClickElsewhere) end
            end
            chooser:SetScript("OnHide", function(self)
                self.pin = nil
                if global then watcher:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
            end)
            chooser:Hide() -- (made shown: hidden first, so the Show below runs its OnShow)
        end
        local width = 160
        for i, key in ipairs(keys) do
            local row = chooser.rows[i]
            if not row then
                row = CreateFrame("Button", nil, chooser, "UIPanelButtonTemplate")
                row:SetHeight(22)
                row:SetPoint("TOPLEFT", 8, -HEADER - (i - 1) * 24)
                row:SetScript("OnClick", function(self) chooser:Hide() Open(self.key) end)
                chooser.rows[i] = row
            end
            row.key = key
            row:SetText(HasMap(key) and key or (key .. "  |cff999999(journal)|r"))
            width = math.max(width, (row:GetFontString():GetStringWidth() or 0) + 30)
            row:Show()
        end
        for i = #keys + 1, #chooser.rows do chooser.rows[i]:Hide() end
        for i = 1, #keys do chooser.rows[i]:SetWidth(width) end
        chooser:SetSize(width + 16, HEADER + #keys * 24 + 10) -- (the template's inset border round the rows)
        chooser:ClearAllPoints()
        chooser:SetPoint("TOPLEFT", pin, "BOTTOMRIGHT", 2, 2)
        chooser:Show()
        chooser.pin = pin
    end

    local function Click(pin)
        if GameTooltip then GameTooltip:Hide() end
        if chooser and chooser:IsShown() then
            local same = chooser.pin == pin
            chooser:Hide()
            if same then return end -- (its list was open: clicking the entrance again closes it)
        end
        local keys, seen = {}, {}
        for _, inst in ipairs(pin.instances or {}) do
            for _, key in ipairs(JournalKeys(inst)) do
                if not seen[key] then seen[key] = true keys[#keys + 1] = key end
            end
        end
        if #keys == 0 then
            local names = {}
            for _, inst in ipairs(pin.instances or {}) do names[#names + 1] = inst[2] end
            print("|cffffd200Master Options:|r Dungeon Journal has nothing for " .. table.concat(names, ", ") .. ".")
        elseif #keys == 1 then
            Open(keys[1])
        else
            Choose(pin, keys)
        end
    end

    -- 3. OpenMap's entrance icons: kept (tooltip, level range), their click is ours
    --    (to hide them, untick "Dungeons and raids" in OpenMap's options)
    local S = ns.MapStitch
    local build = S and S.BuildDungeonPins
    if build then
        S.BuildDungeonPins = function(...)
            local pins = build(...)
            -- (without Dungeon Journal's data: OpenMap's own click stays)
            if FDJ then for _, pin in ipairs(pins) do pin.OnClick = Click end end
            return pins
        end
    end
end
local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

Check("setting up the map inside dungeons", pcall(DungeonMapPart))

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local om = _G.OpenMap
        local wm = om and om.GetModule and om:GetModule("worldmap")
        if insideWanted ~= nil then
            Check("setting OpenMap's map inside dungeons", pcall(SetOpenMapInside, wm, insideWanted))
        end
        if wm then Check("setting OpenMap's entrance click", pcall(SetOpenMapEntrance, wm)) end
    end
end)
end)
