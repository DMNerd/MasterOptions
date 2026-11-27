-- Master Options module: runs when Mastercraft and Questie are loaded.
MasterOptions_Module("Mastercraft_RecipeMap", { "Mastercraft", "Questie" }, function(ADDON)

-- Mastercraft + Questie -> map markers on the vendors and trainers worth a visit for your professions.
--
--   pattern vendors  an NPC of your faction (or both) selling the pattern, recipe, plans, formula, schematic,
--                    manual or design of a recipe you haven't learned. Mastercraft's save lists every recipe of
--                    your professions with "learned" (MastercraftDB.recipes[GUID][profession].list); QuestieDB
--                    knows which items vendors sell (LibQuestieDB.Item "vendors") and finds the pattern by its
--                    name ("Pattern: " .. the recipe's name: both in the game's language).
--                    Not known: the skill a pattern needs - the marker can be ahead of your skill (the tooltip
--                    says so); the pattern's own tooltip at the vendor tells.
--   drops            the creatures and chests a pattern drops from, when it's a specific drop: GearMatic's own WoW
--                    Forever drop rates (GearMatic.DropRates: measured, or a Classic estimate) with up to 5 sources,
--                    else QuestieDB's (npcDrops / objectDrops) with up to 8. A world drop (more sources) isn't
--                    marked. One marker per source and zone, at the middle of its spawns; inside dungeons
--                    there's no outdoor spot (Dungeon Journal's loot list shows those).
--   trainers         your profession's trainers (Questie's Townsfolk.professionTrainers), once you're within 25
--                    of your cap (MastercraftDB.chars[GUID].professions: skill / max) and your level allows the
--                    next rank (Journeyman 10, Expert 20, Artisan 35). Artisan is taught by some trainers only.
-- Where: each NPC's spawns (LibQuestieDB.Npc "spawns", by area: Questie's ZoneDB gives the map), drawn with
-- HereBeDragons-Pins (Questie's), so they show on the world map - the game's and OpenMap's - and the minimap.
-- Marked again at login, on skill-ups and new recipes, a new level, and after a profession window closes
-- (Mastercraft scans it then). Mastercraft, Questie and QuestieDB are only read.

local Shared = MasterOptions_Shared
local Report, Check = Shared.ErrorReporters(ADDON)

local PROF_ID = { -- (profession name in Mastercraft's save -> skill line, Questie's profession key)
    ["First Aid"] = 129, Blacksmithing = 164, Leatherworking = 165, Alchemy = 171, Herbalism = 182, Cooking = 185,
    Mining = 186, Tailoring = 197, Engineering = 202, Enchanting = 333, Fishing = 356, Skinning = 393, Jewelcrafting = 755,
}
local PATTERN_PREFIXES = { "Pattern: ", "Recipe: ", "Plans: ", "Formula: ", "Schematic: ", "Manual: ", "Design: " }
local NEXT_RANK = { -- cap now -> next rank's name and the level it needs
    [75] = { "Journeyman", 10 }, [150] = { "Expert", 20 }, [225] = { "Artisan", 35 },
}
local NEAR_CAP = 25
local VENDOR_ICON = "Interface\\Icons\\INV_Scroll_03"
local TRAINER_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local DROP_ICON = "Interface\\Icons\\INV_Misc_Bag_10"
local MAX_GM_SOURCES, MAX_QUESTIE_SOURCES = 5, 8 -- (more: a world drop, not marked)
local GLOW = "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64"

local function MCDB() local db = _G.MastercraftDB; return type(db) == "table" and db or nil end
local function Lib() local l = _G.LibQuestieDB; return type(l) == "table" and l or nil end
local function Module(name)
    local ql = _G.QuestieLoader
    return type(ql) == "table" and type(ql.ImportModule) == "function" and ql:ImportModule(name) or nil
end
local function Pins() return LibStub and LibStub("HereBeDragons-Pins-2.0", true) or nil end
local function MyFaction() return UnitFactionGroup("player") == "Alliance" and "A" or "H" end

-- QuestieDB fields (nil when unknown)
local function ItemField(id, key) local l = Lib(); return l and l.Item and l.Item.Get and l.Item.Get(id, key) end
local function NpcField(id, key) local l = Lib(); return l and l.Npc and l.Npc.Get and l.Npc.Get(id, key) end
local function ItemIdsByName(name) local l = Lib(); return l and l.Item and l.Item.IdsByName and l.Item.IdsByName(name) end
local function ObjectField(id, key) local l = Lib(); return l and l.Object and l.Object.Get and l.Object.Get(id, key) end
local function IdsByName(entity, name)
    local l = Lib(); local e = l and l[entity]
    return e and type(e.IdsByName) == "function" and e.IdsByName(name) or nil
end
local function Field(entity, id, key) if entity == "Object" then return ObjectField(id, key) end return NpcField(id, key) end

local function Mine(npc) -- an NPC of your faction (or both)
    local f = NpcField(npc, "friendlyToFaction")
    return f == nil or f == "" or f == "AH" or f == MyFaction()
end

---------------------------------------------------------------------------
-- What to mark: { [npcID] = { kind = "vendor" | "trainer", lines = { ... } } }
---------------------------------------------------------------------------
-- the recipes you haven't learned, each with its pattern items: { { recipe, profession, items = { itemID, ... } } }
local function Patterns()
    local db = MCDB()
    local mine = db and type(db.recipes) == "table" and db.recipes[UnitGUID("player") or ""]
    local out = {}
    for prof, data in pairs(type(mine) == "table" and mine or {}) do
        for _, r in ipairs(type(data) == "table" and type(data.list) == "table" and data.list or {}) do
            if type(r) == "table" and r.learned == false and type(r.name) == "string" then
                local items = {}
                for _, prefix in ipairs(PATTERN_PREFIXES) do
                    for _, itemID in ipairs(ItemIdsByName(prefix .. r.name) or {}) do items[#items + 1] = itemID end
                end
                if #items > 0 then out[#out + 1] = { recipe = r.name, prof = prof, items = items } end
            end
        end
    end
    return out
end

-- one mark per place: marks[key] = { kind, entity = "Npc" | "Object", id, lines, seen, centre = bool }
local function Mark(marks, kind, entity, id, line, centre)
    local key = entity .. ":" .. id
    local e = marks[key] or { kind = kind, entity = entity, id = id, lines = {}, seen = {}, centre = centre }
    marks[key] = e
    if not e.seen[line] then e.seen[line] = true; e.lines[#e.lines + 1] = line end
end

local function Vendors(marks, patterns)
    for _, p in ipairs(patterns) do
        for _, itemID in ipairs(p.items) do
            for _, npc in ipairs(ItemField(itemID, "vendors") or {}) do
                if Mine(npc) then Mark(marks, "vendor", "Npc", npc, ("%s (%s)"):format(p.recipe, p.prof)) end
            end
        end
    end
end

-- where a pattern drops: GearMatic's rates first (names: found in QuestieDB), else QuestieDB's own drop lists
local function Drops(marks, patterns)
    local gm = _G.GearMatic
    local dr = type(gm) == "table" and type(gm.DropRates) == "table" and gm.DropRates or nil
    for _, p in ipairs(patterns) do
        for _, itemID in ipairs(p.items) do
            local sources = {}
            if dr and type(dr.ForItem) == "function" then
                for _, e in ipairs(dr.ForItem(itemID) or {}) do
                    if type(e) == "table" and not e.progress and type(e.name) == "string" and type(e.percent) == "number" then
                        sources[#sources + 1] = e
                    end
                end
            end
            if #sources > 0 and #sources <= MAX_GM_SOURCES then
                for _, e in ipairs(sources) do
                    local entity = e.kind == "o" and "Object" or "Npc"
                    local line = ("%s (%s): %.1f%%%s"):format(p.recipe, p.prof, e.percent,
                        e.estimate and " - a Classic estimate" or "")
                    for _, id in ipairs(IdsByName(entity, e.name) or {}) do Mark(marks, "drop", entity, id, line, true) end
                end
            elseif #sources == 0 then
                for _, list in ipairs({ { "Npc", ItemField(itemID, "npcDrops") }, { "Object", ItemField(itemID, "objectDrops") } }) do
                    local ids = type(list[2]) == "table" and list[2] or {}
                    if #ids > 0 and #ids <= MAX_QUESTIE_SOURCES then
                        for _, id in ipairs(ids) do
                            Mark(marks, "drop", list[1], id, ("%s (%s): drops here"):format(p.recipe, p.prof), true)
                        end
                    end
                end
            end
        end
    end
end

local function Trainers(out)
    local db = MCDB()
    local me = db and type(db.chars) == "table" and db.chars[UnitGUID("player") or ""]
    local tf = Module("Townsfolk")
    local trainers = tf and type(tf.professionTrainers) == "table" and tf.professionTrainers
    if not (type(me) == "table" and trainers) then return end
    local level = UnitLevel("player") or 0
    for _, p in ipairs(type(me.professions) == "table" and me.professions or {}) do
        local nextRank = type(p) == "table" and NEXT_RANK[p.max]
        local id = type(p) == "table" and PROF_ID[p.name]
        if nextRank and id and (p.skill or 0) >= p.max - NEAR_CAP and level >= nextRank[2] then
            local line = ("Train %s %s (%d / %d)%s"):format(nextRank[1], p.name, p.skill, p.max,
                nextRank[1] == "Artisan" and " - only some trainers teach Artisan" or "")
            for _, npc in ipairs(trainers[id] or {}) do
                if Mine(npc) then Mark(out, "trainer", "Npc", npc, line) end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Drawing (HereBeDragons-Pins): one marker per NPC spawn
---------------------------------------------------------------------------
local REF = "MasterOptions_RecipeMap"
local pool, used = {}, 0

local function Marker(kind, lines, name)
    used = used + 1
    local m = pool[used]
    if not m then
        m = CreateFrame("Frame", nil, UIParent)
        m:SetSize(16, 16)
        m.glow = m:CreateTexture(nil, "BACKGROUND")
        m.glow:SetTexture(GLOW)
        m.glow:SetPoint("CENTER")
        m.glow:SetSize(30, 30)
        m.glow:SetVertexColor(1, 0.82, 0.2, 0.9)
        m.icon = m:CreateTexture(nil, "ARTWORK")
        m.icon:SetAllPoints()
        m:EnableMouse(true)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.title or "", 1, 0.82, 0)
            for _, l in ipairs(self.lines or {}) do GameTooltip:AddLine(l, 1, 1, 1, true) end
            if self.kind == "vendor" then
                GameTooltip:AddLine("Sells patterns for recipes you haven't learned - each pattern's tooltip says the skill it needs.", 0.6, 0.6, 0.6, true)
            elseif self.kind == "drop" then
                GameTooltip:AddLine("Drops patterns for recipes you haven't learned (the chance: GearMatic's WoW Forever rates).", 0.6, 0.6, 0.6, true)
            end
            GameTooltip:AddLine("Master Options (Mastercraft + Questie)", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pool[used] = m
    end
    m.kind, m.lines, m.title = kind, lines, name
    m.icon:SetTexture((kind == "vendor" and VENDOR_ICON) or (kind == "drop" and DROP_ICON) or TRAINER_ICON)
    return m
end

local function Place(pins, e, name, uiMapID, x, y)
    local m = Marker(e.kind, e.lines, name)
    pins:AddWorldMapIconMap(REF, m, uiMapID, x / 100, y / 100, _G.HBD_PINS_WORLDMAP_SHOW_PARENT)
    local mm = Marker(e.kind, e.lines, name)
    pins:AddMinimapIconMap(REF, mm, uiMapID, x / 100, y / 100, false, false)
end

local function Draw(marks)
    local pins = Pins()
    if not pins then return 0 end
    pins:RemoveAllWorldMapIcons(REF)
    pins:RemoveAllMinimapIcons(REF)
    used = 0
    local zones = Module("ZoneDB")
    local count = 0
    for _, e in pairs(marks) do
        local name = Field(e.entity, e.id, "name") or (e.entity .. " " .. e.id)
        for areaID, spots in pairs(Field(e.entity, e.id, "spawns") or {}) do
            local uiMapID = zones and type(zones.GetUiMapIdByAreaId) == "function" and zones:GetUiMapIdByAreaId(areaID)
            local sx, sy, n = 0, 0, 0
            for _, s in ipairs(uiMapID and type(spots) == "table" and spots or {}) do
                local x, y = tonumber(s[1]), tonumber(s[2])
                if x and y and x >= 0 and y >= 0 then
                    if e.centre then
                        sx, sy, n = sx + x, sy + y, n + 1
                    else
                        Place(pins, e, name, uiMapID, x, y)
                        count = count + 1
                    end
                end
            end
            if e.centre and n > 0 then -- (one marker for the zone: where its spawns are, on average)
                Place(pins, e, name, uiMapID, sx / n, sy / n)
                count = count + 1
            end
        end
    end
    for i = used + 1, #pool do pool[i]:Hide() end
    return count
end

---------------------------------------------------------------------------
-- When: QuestieDB's item name index first (built in small steps), then marked again on changes
---------------------------------------------------------------------------
local indexReady = false
local function BuildIndex(done)
    local l = Lib()
    local item = l and l.Item
    if not (item and type(item.BuildNameIndexAsync) == "function") then indexReady = true; done() return end
    local co = coroutine.create(function() item.BuildNameIndexAsync(400) end)
    local function step()
        local ok, err = coroutine.resume(co)
        if not ok then Report("reading QuestieDB's item names", err); indexReady = true; done() return end
        if coroutine.status(co) == "dead" then indexReady = true; done() return end
        C_Timer.After(0, step)
    end
    step()
end

local function Refresh()
    local marks, patterns = {}, Patterns()
    Vendors(marks, patterns)
    Drops(marks, patterns)
    Trainers(marks)
    return Draw(marks)
end

local pending = false
local function RefreshSoon(delay)
    if pending or not indexReady then return end
    pending = true
    C_Timer.After(delay or 1, function()
        pending = false
        Check("marking vendors and trainers", pcall(Refresh))
    end)
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_TAB",
                     "PLAYER_LEVEL_UP", "TRADE_SKILL_CLOSE", "CRAFT_CLOSE" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- (after Questie has built its townsfolk lists, and Mastercraft has its save)
        C_Timer.After(6, function() BuildIndex(function() RefreshSoon(0) end) end)
    else
        local closed = event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE"
        RefreshSoon(closed and 2 or 1) -- (a profession window closed: Mastercraft saves its scan first)
    end
end)

MasterOptions_RecipeMap = { Refresh = Refresh }
end)
