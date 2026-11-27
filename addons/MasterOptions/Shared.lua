-- Master Options: checks used by more than one file (MasterOptions.lua and the modules). Loaded before them.
-- Each reads another addon only, and answers false / nil when that addon isn't there.
local S = {}
MasterOptions_Shared = S

---------------------------------------------------------------------------
-- Errors: a module's caught errors go to Master Options' error log (/mo > Problems)
--   local Report, Check = MasterOptions_Shared.ErrorReporters(ADDON)
--   Report(where, err)             logs err
--   Check(where, pcall(fn, ...))   logs the error when the call failed; passes the call's results through
---------------------------------------------------------------------------
function S.ErrorReporters(addon)
    local function Report(where, ...)
        local r = _G.MasterOptions_ReportError
        if r then r(addon, where, ...) end
    end
    local function Check(where, ok, ...)
        if not ok then Report(where, ...) end
        return ok, ...
    end
    return Report, Check
end

---------------------------------------------------------------------------
-- Small helpers every part uses
---------------------------------------------------------------------------
-- An addon of someone else's, loaded (true / false)
local function AddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    return f and f(name) and true or false
end
S.AddOnLoaded = AddOnLoaded

-- Items: the C_Item function where the client has it, else the old global
S.GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
S.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

-- GearMatic: its namespace (the global GearMatic), its AceDB profile, its account-wide table (GearMaticDB)
function S.GearMatic() local g = _G.GearMatic; return type(g) == "table" and g or nil end
function S.GearMaticProfile()
    local g = S.GearMatic()
    return g and type(g.db) == "table" and type(g.db.profile) == "table" and g.db.profile or nil
end
function S.GearMaticDB() local d = _G.GearMaticDB; return type(d) == "table" and d or nil end

-- Mastercraft's settings (MastercraftDB.settings, the table it reads live), or nil
function S.MastercraftSettings()
    local db = _G.MastercraftDB
    return type(db) == "table" and type(db.settings) == "table" and db.settings or nil
end

-- Baganator: redraw its item buttons (junk coins, corner icons). One for every caller, a moment after the first
-- ask, so several changes at once redraw once.
local bagRefreshPending = false
function S.RefreshBagButtons()
    if bagRefreshPending then return end
    bagRefreshPending = true
    C_Timer.After(0.2, function()
        bagRefreshPending = false
        local api = _G.Baganator and _G.Baganator.API
        if api and type(api.RequestItemButtonsRefresh) == "function" then pcall(api.RequestItemButtonsRefresh) end
    end)
end

-- fn once, a moment after the first of any number of calls: soon = Debounce(fn, 1); soon() / soon(0.2)
function S.Debounce(fn, defaultDelay)
    local pending = false
    return function(delay)
        if pending then return end
        pending = true
        C_Timer.After(delay or defaultDelay or 0, function()
            pending = false
            fn()
        end)
    end
end

-- A module's /mo command: /mo <word> ... calls fn(the rest of the line); usage is its line in /mo help
function S.Command(word, fn, usage)
    local m = _G.MasterOptions_Modules
    if m and m.RegisterCommand then m.RegisterCommand(word, fn, usage) end
end

-- A module's own ADDON_LOADED, run now: Master Options starts a module after the saved variables are in, so the
-- setup it did on that event as a separate addon happens here. (frame.OnEvent: the sandbox tests' frames)
function S.ReplayAddonLoaded(frame, addon)
    local h = frame.GetScript and frame:GetScript("OnEvent") or frame.OnEvent
    if h then h(frame, "ADDON_LOADED", addon) end
end

-- This character, as Master Options keys it in its saves: "First Last-Realm" (WoW Forever: first and last name,
-- and an empty realm name)
function S.CharacterKey()
    local first, last = UnitName("player")
    return (first or "?") .. ((last and last ~= "") and (" " .. last) or "") .. "-" .. (GetRealmName() or "")
end

-- Master Options' own version and author, from its .toc (one place: the window title, /mo > Thanks, the game's
-- Options page and the minimap button all show them)
function S.About()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local function Get(key)
        local ok, v = pcall(meta, "MasterOptions", key)
        return ok and type(v) == "string" and v ~= "" and v or nil
    end
    local version, author = meta and Get("Version") or "?", meta and Get("Author") or "DMNerd"
    return version, author, ("Master Options %s  |cff9d9d9dby %s|r"):format(version, author)
end

-- Mastercraft's saved data (MastercraftDB), or nil
function S.MastercraftDB()
    local db = _G.MastercraftDB
    return type(db) == "table" and db or nil
end

-- One of Questie's modules (QuestieLoader:ImportModule), or nil
function S.QuestieModule(name)
    local ql = _G.QuestieLoader
    if not (type(ql) == "table" and type(ql.ImportModule) == "function") then return nil end
    local ok, m = pcall(ql.ImportModule, ql, name)
    return ok and type(m) == "table" and m or nil
end

---------------------------------------------------------------------------
-- Gear to keep (selling, deleting)
---------------------------------------------------------------------------
-- Gear to keep: Master Options' own check (Pawn.lua: MasterOptions_GearKeeps - the upgrade judges' word, and
-- GearMatic's best for any of your specs with GearMatic_SpecKeep). true, and why - or false.
function S.KeepsGear(link)
    if type(_G.MasterOptions_GearKeeps) == "function" then return _G.MasterOptions_GearKeeps(link) end
    return false
end

local GM = S.GearMatic

-- Bound to you alone (soulbound, not account-bound): it can never go to an alt. nil = can't tell.
function S.Soulbound(bag, slot, link)
    local get = C_Container and C_Container.GetContainerItemInfo
    local ok, info = pcall(get or error, bag, slot)
    if not ok or type(info) ~= "table" or info.isBound == nil then return nil end
    if not info.isBound then return false end
    -- account-bound items (bind types 7-9) travel to alts
    local l = link or info.hyperlink
    local bindType = l and select(14, S.GetItemInfo(l))
    if type(bindType) == "number" and bindType >= 7 then return false end
    return true
end

-- GearMatic's own verdict on a bag slot: an upgrade (for you or an alt), best in slot, or in an equipment set.
-- An upgrade only for an alt doesn't keep a soulbound piece: it can't be sent to them. true, and why (for /mo vendor)
function S.GearMaticKeeps(link, bag, slot, itemID)
    local gm = GM()
    if not gm then return false end
    local bo = gm.BagOverlay
    if bo and bo.MarkerVerdict then
        local ok, v = pcall(bo.MarkerVerdict, link, bag, slot)
        if ok and type(v) == "table" then
            if v.upgrade then return true, "GearMatic: an upgrade for you" end
            if v.skull then return true, "GearMatic: best in slot" end
            if v.alt and S.Soulbound(bag, slot, link) ~= true then
                return true, "GearMatic: an upgrade for one of your alts (not soulbound)"
            end
        end
    end
    local va = gm.VendorAutomation
    if va and va.InEquipmentSet then
        local ok, inSet = pcall(va.InEquipmentSet, bag, slot, itemID)
        if ok and inSet then return true, "in an equipment set" end
    end
    return false
end

-- GearMatic loadouts: { [itemID] = true } for every item in them
function S.GearMaticLoadoutIDs()
    local ids = {}
    local gm = GM()
    local store = gm and gm.Loadouts and gm.Loadouts.Store
    if not (store and store.List and store.Get) then return ids end
    local ok, names = pcall(store.List)
    for _, name in ipairs(ok and names or {}) do
        local e = store.Get(name)
        for _, s in pairs(type(e) == "table" and e.slots or {}) do
            if type(s) == "table" and s.itemID then ids[s.itemID] = true end
        end
    end
    return ids
end

---------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------
-- Same rule as CheapUpgrades' own Bigger(): an empty slot (no %) beats any %.
local function Bigger(a, b)
    if not b then return true end
    if not a.pct then return b.pct ~= nil end
    return b.pct ~= nil and a.pct > b.pct
end

-- CheapUpgrades' badge for an item ("+23%" in its colour, or "NEW" for an empty slot): the text, false when it
-- isn't an upgrade for a spec you watch, nil while CheapUpgrades isn't ready (ask again later)
function S.CheapUpgradesBadge(link)
    local cu = _G.CheapUpgrades
    if type(cu) ~= "table" or type(cu.WatchedInfo) ~= "function" then return false end
    if not cu.ctx then return nil end
    if type(link) ~= "string" or link == "" then return false end
    local ok, list = pcall(cu.WatchedInfo, cu, link)
    if not ok or type(list) ~= "table" then return nil end
    local best
    for _, e in ipairs(list) do
        if e.info and e.info.state == "upgrade" and Bigger(e.info, best) then best = e.info end
    end
    if not best then return false end
    local textOk, text = pcall(cu.Bags and cu.Bags.BadgeText, best)
    if not textOk or type(text) ~= "string" or text == "" then return false end
    return text
end

---------------------------------------------------------------------------
-- Gathering (Herbalism, Mining): your skill, and which nodes are worth it by Mastercraft's rule
---------------------------------------------------------------------------
S.HERB, S.MINE, S.ENCHANTING = 182, 186, 333 -- (skill line IDs)
local HERB, MINE = S.HERB, S.MINE
local MAX_GATHER_SKILL = 300
local PROF_NAMES = {
    [HERB] = { Herbalism = true, Herboristerie = true, ["Kr\195\164uterkunde"] = true, ["Herborister\195\173a"] = true, Erbalismo = true, Herborismo = true },
    [MINE] = { Mining = true, Minage = true, Bergbau = true, ["Miner\195\173a"] = true, Estrazione = true, ["Minera\195\167\195\163o"] = true },
    [S.ENCHANTING] = { Enchanting = true, Enchantement = true, Verzauberkunst = true, Encantamiento = true, Incantamento = true, Encantamento = true },
}

-- { [skill line] = rank } for the professions you have (of S.HERB, S.MINE, S.ENCHANTING)
function S.ProfessionRanks()
    local found = {}
    if GetProfessions and GetProfessionInfo then
        local res = { pcall(GetProfessions) }
        if res[1] then
            for i = 2, 6 do
                local idx = res[i]
                if idx then
                    local ok, _, _, rank, _, _, _, sl = pcall(GetProfessionInfo, idx)
                    if ok and PROF_NAMES[sl] then found[sl] = rank or 0 end
                end
            end
        end
    end
    if next(found) == nil and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank = GetSkillLineInfo(i)
            if name and not header then
                for sl, names in pairs(PROF_NAMES) do
                    if names[name] then found[sl] = rank or 0 end
                end
            end
        end
    end
    return found
end

-- { [S.HERB] = rank, [S.MINE] = rank } for the gathering professions you have
function S.GatheringRanks()
    local all, found = S.ProfessionRanks(), {}
    found[HERB], found[MINE] = all[HERB], all[MINE]
    return found
end

-- Mastercraft's Settings > Nodes > Which nodes (settings.nodesFilter: "skillups" (its default), "gatherable", "all"):
-- is a node needing req skill worth it at skill? No req known: yes. At the top (300) there are no skill-ups left:
-- then all you can gather.
function S.GatherWanted(filter, skill, req)
    if filter == "all" then return true end
    if not skill then return false end
    if not req then return true end
    if skill < req then return false end
    if filter == "gatherable" or skill >= MAX_GATHER_SKILL then return true end
    return skill - req < 100
end

---------------------------------------------------------------------------
-- Mastercraft's Settings > Modules (2.1.2): MastercraftDB.settings.modules[key] = false turns a whole part off
-- ("tip": every tooltip line, "loot": the KEEP / VENDOR advice, "ah": the Scan prices button). On otherwise,
-- also before Mastercraft's saved settings are there.
---------------------------------------------------------------------------
function S.MastercraftModuleOn(key)
    local db = _G.MastercraftDB
    local m = type(db) == "table" and type(db.settings) == "table" and db.settings.modules
    return not (type(m) == "table" and m[key] == false)
end

---------------------------------------------------------------------------
-- Mastercraft's advice, as its item tooltip shows it. Its verdicts are worked out in private functions, but it writes
-- them onto GameTooltip, and supports another addon reading items through a hidden GameTooltip (its Tooltip.lua,
-- patch-479). One reader for every module (Mastercraft_Advice, _Keep, _VendorSell, _BankMats):
--   verdict    the right side of its "Mastercraft" header: "KEEP", "VENDOR", "AUCTION", "DISENCHANT", "NO PRICES".
--              An item you track has the header without one (its "Tracking" row under it) and the advice's reason
--              further down: KEEP, known by the reason's wording (Mastercraft's Loot.lua writes those under KEEP only)
--   reason     the line under the verdict ("Your Tailoring guide still needs 4." ...), "" when there's none
--   keepSome   a line under it keeps some for a guide: "Keep 5 for your Tailoring guide - you have 8, the other 3
--              can go." / "... guide needs ..." / "... guide uses ..."
--   guideNeeds its guide section's "<Profession> guide needs  N more" line
---------------------------------------------------------------------------
local function StripColour(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local KEEP_REASONS = { "guide still needs", "guide uses all", "^You're tracking it:" }

function S.ReadMastercraftAdvice(tip)
    local name = tip:GetName()
    if not name then return nil, "", false, false end
    local verdict, reason, keepSome, guideNeeds, header, reasonNext = nil, "", false, false, false, false
    for i = 1, tip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local text = left and left:GetText()
        if type(text) == "string" then
            if text:find("guide needs$") then guideNeeds = true end
            if not header and text:find("Mastercraft", 1, true) then
                header = true
                local right = _G[name .. "TextRight" .. i]
                local r = right and right:IsShown() and right:GetText()
                if type(r) == "string" and r ~= "" then verdict, reasonNext = StripColour(r):upper(), true end
            elseif header then
                local t = StripColour(text)
                if reasonNext then
                    reason, reasonNext = t, false
                elseif not verdict then
                    for _, p in ipairs(KEEP_REASONS) do
                        if t:find(p) then verdict, reason = "KEEP", t break end
                    end
                end
                -- (the reason line itself may be the one: "Keep 5 for your Tailoring guide - ...")
                if t:find("^Keep %d+ for") or t:find("guide needs") or t:find("guide uses") then keepSome = true end
            end
        end
    end
    return verdict, reason, keepSome, guideNeeds
end

-- Every item tooltip GameTooltip shows (yours and the hidden reads below) read once, after Mastercraft has added its
-- lines (the hook is set by the first module that asks, at Master Options' own load: Mastercraft, an optional
-- dependency, has set its own by then), and handed to each subscriber: fn(itemID, verdict, reason, keepSome,
-- guideNeeds). Not while Mastercraft's tooltip lines are off (its Settings > Modules > Tooltip extras): then a tooltip
-- says nothing about the item, and reading it would forget what was learned.
local adviceSubs, adviceHooked = {}, false
local lastRead = { id = nil }
local function OnItemTooltip(tip, data)
    if tip ~= GameTooltip then return end
    local id = data and type(data.id) == "number" and data.id
    if not id then
        local _, link = tip:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not id or not S.MastercraftModuleOn("tip") then return end
    local ok, verdict, reason, keepSome, guideNeeds = pcall(S.ReadMastercraftAdvice, tip)
    if not ok then
        if _G.MasterOptions_ReportError then _G.MasterOptions_ReportError("MasterOptions", "reading Mastercraft's advice", verdict) end
        return
    end
    lastRead.id, lastRead.verdict, lastRead.reason, lastRead.keepSome, lastRead.guideNeeds = id, verdict, reason, keepSome, guideNeeds
    for i = 1, #adviceSubs do
        local sub = adviceSubs[i]
        local okS, err = pcall(sub.fn, id, verdict, reason, keepSome, guideNeeds)
        if not okS and _G.MasterOptions_ReportError then _G.MasterOptions_ReportError(sub.name, "learning from an item tooltip", err) end
    end
end

function S.OnMastercraftAdvice(name, fn)
    adviceSubs[#adviceSubs + 1] = { name = name, fn = fn }
    if not adviceHooked and TooltipDataProcessor and Enum and Enum.TooltipDataType then
        adviceHooked = true
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    end
end

-- Mastercraft's advice for a bag slot, read now through the hidden GameTooltip (the subscribers learn from it too):
-- verdict, reason, keepSome, guideNeeds - nil when there's nothing to read
function S.MastercraftSlotAdvice(bag, slot)
    local tip = GameTooltip
    if not (tip and tip.SetBagItem) then return nil end
    lastRead.id = nil
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    local verdict, reason, keepSome, guideNeeds
    if pcall(tip.SetBagItem, tip, bag, slot) then
        if lastRead.id then -- (read by the hook just now)
            verdict, reason, keepSome, guideNeeds = lastRead.verdict, lastRead.reason, lastRead.keepSome, lastRead.guideNeeds
        elseif S.MastercraftModuleOn("tip") then -- (no tooltip data hook on this client)
            local ok, v, r, k, g = pcall(S.ReadMastercraftAdvice, tip)
            if ok then verdict, reason, keepSome, guideNeeds = v, r, k, g end
        end
    end
    tip:Hide()
    return verdict, reason, keepSome, guideNeeds
end

-- An item's tooltip is on screen (the mouse on a bag slot): a hidden read through GameTooltip would take it away
function S.ItemTooltipShown()
    return GameTooltip:IsShown() and GameTooltip:GetOwner() ~= WorldFrame and GameTooltip:GetItem() ~= nil
end

---------------------------------------------------------------------------
-- OpenMap_MiniMap: the profile in use - this character's own (OpenMap keys it on the first name), or the shared one
---------------------------------------------------------------------------
function S.OpenMapMiniMapProfile()
    local db = _G.OpenMapMiniMapDB
    if type(db) ~= "table" then return nil end
    local first = UnitName("player")
    local c = first and type(db.char) == "table" and db.char[first .. "-" .. (GetRealmName() or "")]
    if type(c) == "table" and c.own and type(c.profile) == "table" then return c.profile end
    return type(db.profile) == "table" and db.profile or nil
end

---------------------------------------------------------------------------
-- OpenMap: the spot it was last told to follow (its TrackPoint: a pin followed, Dungeon Journal's Show on Map),
-- until its ClearPin. OpenMap itself defines "followed" by where the game's waypoint is, but ShortestPathForever's
-- journey moves that waypoint along the way - so a pin's clearing was missed when matched by the waypoint
-- (Dungeon Journal's mark removed, the journey cleared). Watched from login (S.WatchOpenMapFollow).
---------------------------------------------------------------------------
local followed, followHooked
local NEAR = 5e-4

local function OpenMapWorldMap()
    local om = _G.OpenMap
    local mod = type(om) == "table" and type(om.GetModule) == "function" and om:GetModule("worldmap")
    return type(mod) == "table" and mod or nil
end
S.OpenMapWorldMap = OpenMapWorldMap

function S.WatchOpenMapFollow()
    if followHooked then return true end
    local mod = OpenMapWorldMap()
    if not (mod and type(mod.TrackPoint) == "function") then return false end
    followHooked = true
    hooksecurefunc(mod, "TrackPoint", function(mapID, x, y) followed = { mapID, x, y } end)
    if type(mod.ClearPin) == "function" then hooksecurefunc(mod, "ClearPin", function() followed = nil end) end
    return true
end

local function Same(mapID, x, y, m2, x2, y2)
    return mapID ~= nil and mapID == m2 and x and x2 and y and y2
        and math.abs(x - x2) < NEAR and math.abs(y - y2) < NEAR or false
end

-- whether OpenMap follows the spot now: the one it was told to follow, and either the game's waypoint still on it
-- or ShortestPathForever's journey for it (owner "OpenMap:Pin") still under way. Not followed any more (another
-- journey took over, OpenMap stopped it itself): false, so clearing it can't clear someone else's waypoint
function S.OpenMapFollows(mapID, x, y)
    local mod = OpenMapWorldMap()
    if not mod then return false end
    local wm, wx, wy = nil, nil, nil
    if type(mod.WaypointPoint) == "function" then wm, wx, wy = mod.WaypointPoint() end
    if Same(mapID, x, y, wm, wx, wy) then return true end
    if not (followed and Same(mapID, x, y, followed[1], followed[2], followed[3])) then return false end
    local spf = _G.ShortestPathForever
    local api = type(spf) == "table" and spf.API
    if not (type(api) == "table" and type(api.CurrentStop) == "function") then return false end
    local ok, stop = pcall(api.CurrentStop, "OpenMap:Pin")
    return ok and stop ~= nil
end

-- the spot OpenMap was last told to follow (map, x, y), else where the game's waypoint is
function S.OpenMapFollowed()
    if followed then return followed[1], followed[2], followed[3] end
    local mod = OpenMapWorldMap()
    if mod and type(mod.WaypointPoint) == "function" then return mod.WaypointPoint() end
end

---------------------------------------------------------------------------
-- OpenMap's pins, as our modules place and clear them (DungeonJournal_ShowOnMap, ShortestPathForever_OpenMapPins):
-- straight into OpenMap's pin list (OpenMapDB: worldmap -> pins), in its own format - one way for all of them.
-- Each module keeps its own record of the pins it placed; a pin removed by any of them is forgotten by all
-- (OpenMapPins.OnRemove).
---------------------------------------------------------------------------
local Pins = {}
S.OpenMapPins = Pins
local NOTE_MAX = 160

-- OpenMap's world map module with its pin list, or nil
function Pins.Module()
    local mod = OpenMapWorldMap()
    if mod and type(mod.db) == "table" and type(mod.db.pins) == "table" and type(mod.db.pins.list) == "table" then return mod end
end

function Pins.Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < NEAR end
local function Round(v) return math.floor(v * 1e4 + 0.5) / 1e4 end

-- a pin's note: one line, no "|" (OpenMap's escapes), long dashes as " - ", at most 160 bytes (cut whole characters)
function Pins.Note(text)
    text = tostring(text or ""):gsub("%c", " "):gsub("|", "/")
    text = text:gsub("%s*\226\128\148%s*", " - "):gsub("%s*\226\128\147%s*", " - ")
    if #text > NOTE_MAX then text = text:sub(1, NOTE_MAX):gsub("[\192-\255][\128-\191]*$", "") end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- the pin at a spot: OpenMap's own lookup, else one within a hair of it
function Pins.Find(mod, map, x, y)
    if mod.PinAt then
        local p = mod.PinAt(map, x, y)
        if p then return p end
    end
    for _, p in ipairs(mod.db.pins.list) do
        if p.map == map and Pins.Near(p.x, x) and Pins.Near(p.y, y) then return p end
    end
end

-- a new pin (colour: OpenMap's 1 gold, 2 red, 3 green, 4 blue, 5 purple; from: where it came from, OpenMap shows it)
function Pins.Add(mod, map, x, y, note, color, from)
    local pins = mod.db.pins
    pins.nextId = pins.nextId or 1
    local p = { id = pins.nextId, map = map, x = Round(x), y = Round(y), note = note, color = color, from = from,
                at = time and time() or nil }
    pins.nextId = pins.nextId + 1
    table.insert(pins.list, p)
    if mod.db.pinsHidden and mod.SetPinsHidden then pcall(mod.SetPinsHidden, false) end -- (else it would be out of sight)
    if mod.RefreshPins then pcall(mod.RefreshPins) end
    return p
end

-- fn(pinID): a pin was removed - forget it
local removedCallbacks = {}
function Pins.OnRemove(fn) removedCallbacks[#removedCallbacks + 1] = fn end

-- the pin out of OpenMap's list, its sketches with it, and out of every module's record (the caller refreshes)
function Pins.Remove(mod, p)
    local list = mod.db.pins.list
    for i = #list, 1, -1 do if list[i] == p then table.remove(list, i) end end
    if mod.DropSketches and p.id then pcall(mod.DropSketches, p.id) end
    if p.id then
        for _, fn in ipairs(removedCallbacks) do pcall(fn, p.id) end
    end
end

---------------------------------------------------------------------------
-- Master Options' look for its own frames on others' maps (the minimap's zone bar and coordinates tab; the dungeon
-- chooser is the game's BasicFrameTemplate itself): the /mo window's header (the game's BasicFrameTemplate title bar - Details' title bar matches it),
-- else a grey gradient like it, darker at the top
---------------------------------------------------------------------------
local HEAD_TOP, HEAD_BOTTOM = { 0.06, 0.06, 0.06 }, { 0.18, 0.18, 0.175 }
-- a texture filled as the /mo window's header: its texture copied (atlas, or file and coords), else a gradient
local function TitleLike(tex)
    local src = _G.MasterOptionsFrame and _G.MasterOptionsFrame.TitleBg
    if not src then return false end
    local atlas = src.GetAtlas and src:GetAtlas()
    if atlas and tex.SetAtlas then
        tex:SetAtlas(atlas, false)
        if tex.SetHorizTile and src.GetHorizTile then tex:SetHorizTile(src:GetHorizTile() and true or false) end
        return true
    end
    local file = src.GetTexture and src:GetTexture()
    if not file then return false end
    tex:SetTexture(file)
    if src.GetTexCoord then tex:SetTexCoord(src:GetTexCoord()) end
    if src.GetVertexColor then tex:SetVertexColor(src:GetVertexColor()) end
    return true
end

function S.HeaderFill(tex)
    if TitleLike(tex) then return end
    tex:SetColorTexture(1, 1, 1, 1)
    local t, b = HEAD_TOP, HEAD_BOTTOM
    if _G.CreateColor and tex.SetGradient
        and pcall(tex.SetGradient, tex, "VERTICAL", _G.CreateColor(b[1], b[2], b[3], 1), _G.CreateColor(t[1], t[2], t[3], 1)) then
        return
    end
    if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, "VERTICAL", b[1], b[2], b[3], 1, t[1], t[2], t[3], 1) then
        return
    end
    tex:SetColorTexture((t[1] + b[1]) / 2, (t[2] + b[2]) / 2, (t[3] + b[3]) / 2, 1)
end


-- a map marker's tooltip, as OpenMap's and Questie's: the name in gold, its lines in white, a hint in grey, and
-- whose marker it is last, small and grey
function S.MarkerTooltip(owner, title, lines, hint, source)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title or "", 1, 0.82, 0)
    for _, l in ipairs(lines or {}) do GameTooltip:AddLine(l, 1, 1, 1, true) end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true) end
    GameTooltip:AddLine(source and ("Master Options - " .. source) or "Master Options", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end
