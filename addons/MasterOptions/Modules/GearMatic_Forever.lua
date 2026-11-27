-- Master Options module (was the addon MasterOptions_GearMatic_Forever): runs when GearMatic is loaded.
MasterOptions_Module("GearMatic_Forever", { "GearMatic" }, function(ADDON)

-- GearMatic <-> WoW Forever character patch.
--
-- Problem: GearMatic keys every per-character record (gear scan, scales, auto-equip, junk lists, ...) as
-- "Realm-FirstName". WoW Forever reports an empty realm and gives each character a last name instead
-- (UnitName returns "Testchar", "Beta"), so every character called Testchar is saved under "-Testchar":
-- one record, overwritten by whichever logs in.
--
-- Fix:
-- 1. GearMatic's public Compat.CurrentCharKey is replaced with one that adds the last name
--    ("-Testchar Beta"). Everything that asks GearMatic for the current character goes through it.
-- 2. Once per character, the record under the old shared key moves to the new key - only when its class
--    matches (GearMatic's own DropRealmlessTwin does the same for the bare key at login).
-- 3. GearMatic's loadouts and equipment sets build their key privately ("-Testchar"), which a patch can't
--    reach. Instead each character's copy is kept here and swapped into that slot at login and back out at
--    logout, so only one character's sets are ever in it.
-- Nothing in GearMatic's files is changed.

local gm = _G.GearMatic
local C = type(gm) == "table" and gm.Compat
if not (C and type(C.CurrentCharKey) == "function" and type(C.RealmCharKey) == "function") then return end

local original = C.CurrentCharKey

-- "First Last" on Forever; nil elsewhere (UnitName("player") has no second value on normal realms)
local function FullName()
    local first, last = UnitName("player")
    if type(first) ~= "string" or first == "" then return nil end
    if type(last) ~= "string" or last == "" then return nil end
    return first .. " " .. last
end

-- 1. the key
C.CurrentCharKey = function()
    local full = FullName()
    if not full then return original() end
    return C.RealmCharKey(C.PlayerRealm and C.PlayerRealm() or "", full)
end

local db -- MasterOptions_GearMaticForeverDB
local function DB()
    MasterOptions_GearMaticForeverDB = MasterOptions_GearMaticForeverDB or {}
    db = MasterOptions_GearMaticForeverDB
    db.stash = db.stash or {}
    db.owner = db.owner or {}
    return db
end

-- 2. move the old shared record to this character's key (once)
local function Migrate()
    local g = _G.GearMaticDB
    if type(g) ~= "table" or type(g.chars) ~= "table" then return end
    local newKey, oldKey = C.CurrentCharKey(), original()
    if not newKey or not oldKey or newKey == oldKey then return end
    if g.chars[newKey] ~= nil then return end -- already has its own record
    local old = g.chars[oldKey]
    local _, class = UnitClass("player")
    if type(old) ~= "table" or (old.class ~= nil and old.class ~= class) then return end
    for k, store in pairs(g) do
        if type(store) == "table" and k ~= "loadouts" and k ~= "equipSets"
            and store[oldKey] ~= nil and store[newKey] == nil then
            store[newKey] = store[oldKey]
            store[oldKey] = nil
        end
    end
    print(("|cffffd200Master Options:|r GearMatic data for %s moved to its own record (%s -> %s)."):format(FullName(), oldKey, newKey))
end

-- 3. loadouts / equipment sets: swap this character's copy into GearMatic's shared slot
local SWAP = { "loadouts", "equipSets" }
local function SlotKey(store)
    local realm, name = GetRealmName and GetRealmName(), UnitName("player")
    if store == "loadouts" then return (realm or "Unknown") .. "-" .. (name or "Unknown") end
    if not realm or not name then return nil end -- equipSets: GearMatic uses no key then
    return realm .. "-" .. name
end

local swappedIn = false
local function SwapIn()
    local full, g = FullName(), _G.GearMaticDB
    if not full or type(g) ~= "table" then return end
    DB()
    for _, s in ipairs(SWAP) do
        local key = SlotKey(s)
        if key then
            g[s] = g[s] or {}
            db.stash[s] = db.stash[s] or {}
            local mine = db.stash[s][full]
            if mine ~= nil then
                g[s][key] = mine
            elseif db.owner[s] and db.owner[s] ~= full then
                g[s][key] = nil -- the slot holds another character's sets: start empty
            end -- else first use ever: keep what is there
        end
    end
    swappedIn = true
end

local function SwapOut()
    local full, g = FullName(), _G.GearMaticDB
    if not (swappedIn and full and type(g) == "table") then return end
    DB()
    for _, s in ipairs(SWAP) do
        local key = SlotKey(s)
        if key and type(g[s]) == "table" then
            db.stash[s] = db.stash[s] or {}
            db.stash[s][full] = g[s][key]
            db.owner[s] = full
        end
    end
end

local done = false
local function Run()
    if done or not FullName() then return end
    done = true
    DB()
    local r = _G.MasterOptions_ReportError -- (a caught error goes to Master Options' error log: /mo > Problems)
    local ok, err = pcall(Migrate)
    if not ok and r then r("MasterOptions_GearMatic_Forever", "moving the old shared record", err) end
    ok, err = pcall(SwapIn)
    if not ok and r then r("MasterOptions_GearMatic_Forever", "switching in this character's loadouts", err) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        -- our saved variables are in; run before GearMatic's login work if the name is known already
        if name == ADDON then Run() end
    elseif event == "PLAYER_LOGIN" then
        Run()
    elseif event == "PLAYER_LOGOUT" then
        SwapOut()
    end
end)

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
