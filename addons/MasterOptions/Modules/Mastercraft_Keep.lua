-- Master Options module (was the addon MasterOptions_Mastercraft_Keep): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_Keep", { "Mastercraft" }, function(ADDON)

-- Mastercraft -> keep the materials you're collecting.
--
-- Mastercraft knows what your crafting guides still need, but keeps that to itself (its tables are private).
-- Two exact sources are readable:
--   * your Mastercraft item tracker (MastercraftDB.goals, per character)
--   * Mastercraft's own tooltip line "<Profession> guide needs  N more": whenever you see an item's tooltip,
--     this remembers whether Mastercraft says a guide (yours or an alt's) needs it - and forgets it when a
--     later tooltip no longer says so.
-- What's needed goes on GearMatic's "never auto-sell" list (so its junk, gear and low-value rules leave it),
-- and MasterOptions_DeleteCheapestItem_Protect keeps it off DeleteCheapestItem's list.
-- Only entries this patch added are ever removed again (GearMaticDB.moKeep lists them); yours stay.
--
-- Shared with the Protect patch: MasterOptions_MastercraftKeep.IsNeeded(itemID).

local DB -- MasterOptions_MastercraftKeepDB: { needed = { [itemID] = time last confirmed } }

local S = MasterOptions_Shared

-- every item tracked in Mastercraft's item tracker (MastercraftDB.goals[your GUID] = { { id = itemID, ... }, ... }),
-- as a set. IsNeeded is asked for every bag slot on every bag update and Baganator redraw, and every Dungeon Journal
-- row: the set is made again only when the list is another table or another length (tracking or untracking an item)
local trackedSet, trackedFrom, trackedLen = {}, nil, -1
local function TrackerIDs()
    local mc = _G.MastercraftDB
    local goals = type(mc) == "table" and type(mc.goals) == "table" and mc.goals[UnitGUID("player") or ""]
    if type(goals) ~= "table" then goals = nil end
    local len = goals and #goals or 0
    if goals ~= trackedFrom or len ~= trackedLen then
        trackedSet, trackedFrom, trackedLen = {}, goals, len
        for i = 1, len do
            local id = type(goals[i]) == "table" and tonumber(goals[i].id)
            if id then trackedSet[id] = true end
        end
    end
    return trackedSet
end

local function Tracked(itemID) return TrackerIDs()[itemID] == true end

local function IsNeeded(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    if DB and DB.needed and DB.needed[itemID] then return true end
    if DB and DB.keep and DB.keep[itemID] then return true end
    return Tracked(itemID)
end
MasterOptions_MastercraftKeep = { IsNeeded = IsNeeded }

---------------------------------------------------------------------------
-- GearMatic's never-sell list (account-wide): add what's needed, remove what we added and isn't any more
---------------------------------------------------------------------------
local function SyncGearMatic()
    local g = _G.GearMaticDB
    if type(g) ~= "table" then return end
    g.sellIgnore = g.sellIgnore or {}
    g.moKeep = g.moKeep or {}
    local want = {}
    for id in pairs(TrackerIDs()) do want[id] = true end
    for id in pairs(DB.needed) do want[id] = true end
    for id in pairs(DB.keep) do want[id] = true end
    local before = 0
    for _ in pairs(g.moKeep) do before = before + 1 end
    local marked = type(g.sellMark) == "table" and g.sellMark or {}
    for id in pairs(want) do
        -- you marked it "always sell" in GearMatic: that wins
        if not marked[id] and not g.sellIgnore[id] then
            g.sellIgnore[id] = true
            g.moKeep[id] = true
        end
    end
    for id in pairs(g.moKeep) do
        if not want[id] then
            g.sellIgnore[id] = nil
            g.moKeep[id] = nil
        end
    end
    -- GearMatic's bag badges (its "best gold" $ / price tag skip items on the never-sell list): redraw
    local after = 0
    for _ in pairs(g.moKeep) do after = after + 1 end
    local gm = _G.GearMatic
    if after ~= before and type(gm) == "table" and type(gm.RefreshSellIgnoreSurfaces) == "function" then
        pcall(gm.RefreshSellIgnoreSurfaces)
    end
end

---------------------------------------------------------------------------
-- Learning from Mastercraft's tooltip lines (MasterOptions_Shared reads every item tooltip once, for every module;
-- not while Mastercraft's tooltip lines are off)
---------------------------------------------------------------------------
-- its guide section's "<Profession> guide needs  N more" lines (Mastercraft's Settings > Tooltip > guide lines)
local function GuideLinesOn()
    local s = S.MastercraftSettings()
    return not (s and s.tipGuide == false)
end

local SyncSoon = S.Debounce(function() SyncGearMatic() end, 1)
local function Learn(itemID, verdict, _, _, guideNeeds)
    if not DB then return end
    local changed = false
    -- Mastercraft's KEEP advice (tools, fishing things, what your recipes use ...): kept; another verdict lets go
    if verdict then
        local was = DB.keep[itemID] ~= nil
        local keep = verdict == "KEEP"
        DB.keep[itemID] = keep and time() or nil
        changed = was ~= keep
    end
    -- "<Profession> guide needs N more"
    if GuideLinesOn() then
        local before = DB.needed[itemID] ~= nil
        if guideNeeds then DB.needed[itemID] = time() else DB.needed[itemID] = nil end
        changed = changed or (before ~= guideNeeds)
    end
    if changed then SyncSoon() end
end
S.OnMastercraftAdvice(ADDON, Learn)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftKeepDB = MasterOptions_MastercraftKeepDB or {}
        DB = MasterOptions_MastercraftKeepDB
        DB.needed = DB.needed or {}
        DB.keep = DB.keep or {}
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, SyncGearMatic)
    end
end)

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
