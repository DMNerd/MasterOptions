-- Master Options module: runs always (it syncs whichever of the lists below are installed).
MasterOptions_Module("NeverSell", {}, function(ADDON)

-- One "never sell" list for every addon that keeps one, kept in sync both ways:
--   GearMatic           GearMaticDB.sellIgnore[itemID] = true        never auto-sold (account)
--   Mastercraft         MastercraftDB.settings.lootNever[itemID]     its loot advisor gives no VENDOR / AUCTION
--                                                                    advice, so nothing (ours included) sells it (account)
--   DeleteCheapestItem  DCI_CharDB.IgnoredItems = { itemID, ... }    never offered for deletion (per character)
-- Master Options' own copy: MasterOptionsDB.neverSell[itemID] = true (account).
--
-- How: each list's state at the last sync is remembered (MasterOptionsDB.neverSellSeen[source]). What a list has
-- now and didn't then was added there - it goes on every list; what it had then and hasn't now was taken off
-- there - it comes off every list. The first sync is the union of all of them. DeleteCheapestItem's list is per
-- character, so its "then" is per character too: another character catches up when it logs in.
--
-- Entries our own modules put there automatically aren't yours and aren't synced: Mastercraft_Keep's in
-- GearMatic (GearMaticDB.moKeep) and DeleteCheapestItem_Protect's (DCI_CharDB.moProtected). An item you put on
-- the list yourself is yours: those modules let go of it (they never take off what isn't theirs).
--
-- /mo never <item link or ID>       add          /mo never remove <item link or ID>   remove
-- /mo never                          list

local function Report(where, err)
    if _G.MasterOptions_ReportError then MasterOptions_ReportError(ADDON, where, err) end
end

local function Loaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f and f(name) and true or false
end

local function DB()
    MasterOptionsDB = MasterOptionsDB or {}
    MasterOptionsDB.neverSell = type(MasterOptionsDB.neverSell) == "table" and MasterOptionsDB.neverSell or {}
    MasterOptionsDB.neverSellSeen = type(MasterOptionsDB.neverSellSeen) == "table" and MasterOptionsDB.neverSellSeen or {}
    return MasterOptionsDB.neverSell, MasterOptionsDB.neverSellSeen
end

local function CharKey()
    local first, last = UnitName("player")
    return (first or "?") .. ((last and last ~= "") and (" " .. last) or "")
end

---------------------------------------------------------------------------
-- The lists: read() -> { [itemID] = true } of your entries; add(id), remove(id)
---------------------------------------------------------------------------
local SOURCES = {}

SOURCES[#SOURCES + 1] = {
    key = "gearmatic", name = "GearMatic",
    get = function()
        local g = _G.GearMaticDB
        if not (Loaded("GearMatic") and type(g) == "table") then return nil end
        g.sellIgnore = type(g.sellIgnore) == "table" and g.sellIgnore or {}
        return g
    end,
    read = function(g)
        local auto = type(g.moKeep) == "table" and g.moKeep or {}
        local out = {}
        for key, on in pairs(g.sellIgnore) do
            local id = tonumber(key)
            if id and on and not auto[id] then out[id] = true end
        end
        return out
    end,
    add = function(g, id)
        g.sellIgnore[id] = true
        if type(g.moKeep) == "table" then g.moKeep[id] = nil end -- (yours now: Mastercraft_Keep lets go)
    end,
    remove = function(g, id) g.sellIgnore[id] = nil end,
    after = function()
        local gm = _G.GearMatic
        if type(gm) == "table" and type(gm.RefreshSellIgnoreSurfaces) == "function" then pcall(gm.RefreshSellIgnoreSurfaces) end
    end,
}

SOURCES[#SOURCES + 1] = {
    key = "mastercraft", name = "Mastercraft",
    get = function()
        local db = _G.MastercraftDB
        local s = Loaded("Mastercraft") and type(db) == "table" and db.settings
        if type(s) ~= "table" then return nil end
        s.lootNever = type(s.lootNever) == "table" and s.lootNever or {}
        return s
    end,
    read = function(s)
        local out = {}
        for key, on in pairs(s.lootNever) do
            local id = tonumber(key)
            if id and on then out[id] = true end
        end
        return out
    end,
    add = function(s, id) s.lootNever[id] = true end,
    remove = function(s, id) s.lootNever[id] = nil end,
}

SOURCES[#SOURCES + 1] = {
    key = "dci", name = "DeleteCheapestItem", perChar = true,
    -- (its list's format: DeleteCheapestItem 1.9 replaced each character's list once with a copy of the old
    -- one, setting schemaVersion. A list whose version changed since the last sync is read as new - joined,
    -- never taken as your removals.)
    version = function(c) return c.schemaVersion end,
    get = function()
        local c = _G.DCI_CharDB
        if not (Loaded("DeleteCheapestItem") and type(c) == "table") then return nil end
        c.IgnoredItems = type(c.IgnoredItems) == "table" and c.IgnoredItems or {}
        return c
    end,
    read = function(c)
        local auto = type(c.moProtected) == "table" and c.moProtected or {}
        local out = {}
        for _, v in ipairs(c.IgnoredItems) do
            local id = tonumber(v)
            if id and not auto[id] then out[id] = true end
        end
        return out
    end,
    add = function(c, id)
        local there = false
        for _, v in ipairs(c.IgnoredItems) do if tonumber(v) == id then there = true break end end
        if not there then table.insert(c.IgnoredItems, id) end
        if type(c.moProtected) == "table" then c.moProtected[id] = nil end -- (yours now: the Protect module lets go)
    end,
    remove = function(c, id)
        for i = #c.IgnoredItems, 1, -1 do
            if tonumber(c.IgnoredItems[i]) == id then table.remove(c.IgnoredItems, i) end
        end
    end,
}

local function SeenKey(src) return src.perChar and (src.key .. ":" .. CharKey()) or src.key end

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------
local function Copy(t) local o = {} for k in pairs(t) do o[k] = true end return o end

local function Sync()
    local master, seen = DB()
    local live = {}
    -- 1. what changed in each list since the last sync -> into the master list
    local added, removed = {}, {}
    for _, src in ipairs(SOURCES) do
        local h = src.get()
        if h then
            local now = src.read(h)
            local was = seen[SeenKey(src)]
            if src.version then
                MasterOptionsDB.neverSellVersion = type(MasterOptionsDB.neverSellVersion) == "table" and MasterOptionsDB.neverSellVersion or {}
                local v = tostring(src.version(h))
                if was and MasterOptionsDB.neverSellVersion[SeenKey(src)] ~= v then was = nil end
                MasterOptionsDB.neverSellVersion[SeenKey(src)] = v
            end
            live[#live + 1] = { src = src, h = h, now = now }
            for id in pairs(now) do
                if not (was and was[id]) then added[id] = true end
            end
            if was then
                for id in pairs(was) do
                    if not now[id] then removed[id] = true end
                end
            end
        end
    end
    for id in pairs(removed) do if not added[id] then master[id] = nil end end -- (added somewhere and removed elsewhere at once: kept)
    for id in pairs(added) do master[id] = true end
    -- 2. the master list -> every list
    for _, l in ipairs(live) do
        local changed = false
        for id in pairs(master) do
            if not l.now[id] then l.src.add(l.h, id); changed = true end
        end
        for id in pairs(l.now) do
            if not master[id] then l.src.remove(l.h, id); changed = true end
        end
        seen[SeenKey(l.src)] = Copy(master)
        if changed and l.src.after then pcall(l.src.after) end
    end
end

local API = {}
local function Signature()
    local master = DB()
    local ids = {}
    for id in pairs(master) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end
local function SafeSync()
    local before = Signature()
    local ok, err = pcall(Sync)
    if not ok then Report("syncing the never-sell lists", err) end
    -- (the list changed - in another addon, or here: Master Options' window shows it again)
    if API.OnChange and Signature() ~= before then pcall(API.OnChange) end
end

---------------------------------------------------------------------------
-- The list from Master Options (window, slash command)
---------------------------------------------------------------------------
function API.Sync() SafeSync() end
function API.List()
    local master = DB()
    local out = {}
    for id in pairs(master) do out[#out + 1] = id end
    table.sort(out)
    return out
end
function API.Has(id) local master = DB(); return master[tonumber(id) or -1] == true end
-- adding or removing here counts as a change made in Master Options: synced at once
function API.Set(id, on)
    id = tonumber(id)
    if not id then return false end
    local master = DB()
    master[id] = on and true or nil
    SafeSync()
    return true
end
function API.Sources()
    local out = {}
    for _, src in ipairs(SOURCES) do if src.get() then out[#out + 1] = src.name end end
    return out
end
MasterOptions_NeverSell = API

---------------------------------------------------------------------------
-- When: after login (every addon's saved variables in, Protect / Keep done), then every few seconds out of
-- combat (catches changes made in each addon's own window), and right away when a vendor or the bank opens
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("BANKFRAME_OPENED")
local ready, wait = false, 0
-- The few-seconds look is cheap: each list's table, size and sum of its IDs (plus which addons are loaded and
-- DeleteCheapestItem's list version), compared with how they were after the last sync. Only a difference runs
-- the full sync. (Nothing is built for the look itself: no garbage every few seconds.)
local fp = {}
local function Put(i, v)
    if fp[i] ~= v then fp[i] = v; return true end
    return false
end
local function SumKeys(t, i)
    local n, sum = 0, 0
    if type(t) == "table" then
        for k in pairs(t) do n = n + 1; sum = sum + (tonumber(k) or 0) end
    end
    local a = Put(i, t); local b = Put(i + 1, n); local c = Put(i + 2, sum)
    return a or b or c
end
local function SumValues(t, i)
    local n, sum = 0, 0
    if type(t) == "table" then
        for _, v in ipairs(t) do n = n + 1; sum = sum + (tonumber(v) or 0) end
    end
    local a = Put(i, t); local b = Put(i + 1, n); local c = Put(i + 2, sum)
    return a or b or c
end
-- true when anything differs from the last look (and remembers this one)
local function Moved()
    local g, mc, c = _G.GearMaticDB, _G.MastercraftDB, _G.DCI_CharDB
    local ms = type(mc) == "table" and mc.settings
    local changed = false
    if Put(1, Loaded("GearMatic")) then changed = true end
    if Put(2, Loaded("Mastercraft")) then changed = true end
    if Put(3, Loaded("DeleteCheapestItem")) then changed = true end
    if Put(4, c) then changed = true end
    if Put(5, type(c) == "table" and c.schemaVersion or nil) then changed = true end
    if SumKeys(type(g) == "table" and g.sellIgnore or nil, 6) then changed = true end
    if SumKeys(type(ms) == "table" and ms.lootNever or nil, 9) then changed = true end
    if SumValues(type(c) == "table" and c.IgnoredItems or nil, 12) then changed = true end
    if SumKeys(MasterOptionsDB and MasterOptionsDB.neverSell or nil, 15) then changed = true end
    return changed
end

-- (from Master Options' window and slash command too: the look after it then finds nothing new)
local function SyncAndRemember()
    SafeSync()
    Moved() -- (the lists as the sync left them: the next look compares with these)
end
API.Sync = SyncAndRemember
local set = API.Set
API.Set = function(id, on) local r = set(id, on); Moved(); return r end

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(5, function() ready = true; SyncAndRemember() end)
    elseif ready then
        SyncAndRemember()
    end
end)
f:SetScript("OnUpdate", function(_, dt)
    if not ready then return end
    wait = wait + dt
    if wait < 3 then return end
    wait = 0
    if InCombatLockdown and InCombatLockdown() then return end
    if Moved() then SyncAndRemember() end
end)
end)
