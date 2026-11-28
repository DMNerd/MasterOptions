-- Master Options: the settings themselves, apart from the window that shows them - the recommended setup (applied
-- once per character, again for rows added since: DEFAULTS_VERSION and each row's since), the per-character choices
-- kept the same on every character, and which rows and choices are available with the addons loaded.
-- (The window's RefreshAll, from Window.lua after this file, is looked up when it's called: MO.RefreshAll.)

local _, MO = ...
local Loaded, OPTIONS = MO.Loaded, MO.OPTIONS
local SeedShared -- (below: copies this character's per-character choices to the account)

local Available -- (below)

-- Recommended setup, applied once per character on first load (and by the button).
-- Skips anything whose addon isn't loaded; returns how many rows it set.
-- An option's recommended value: a value, or a function (a choice that depends on what's installed, such as
-- Pawn when it is there and GearMatic when it isn't)
local function RecOf(opt)
    if type(opt.rec) == "function" then return opt.rec() end
    return opt.rec
end

local DEFAULTS_VERSION = 42
local Remember -- set below
local function ApplyRecommended(after, manual) -- after: only options added after this defaults version
    local n = 0
    for _, opt in ipairs(OPTIONS) do
        if opt.rec ~= nil and Available(opt) and (opt.since or 1) > (after or 0) then
            local want = RecOf(opt)
            if opt.kind == "choice" and not opt.needs and want ~= "Off" and want ~= opt.off and not Loaded(want) then want = nil end
            if want ~= nil and opt.get() ~= want then
                local ok = pcall(opt.set, want)
                if ok then
                    n = n + 1
                    if opt.reload then MO.needsReload = true end
                    if manual and Remember then Remember(opt) end
                end
            end
        end
    end
    MO.RefreshAll()
    return n
end

-- Per-character rows kept the same on every character (MasterOptionsDB.shared[label] = value)
local function SharedStore()
    MasterOptionsDB.shared = MasterOptionsDB.shared or {}
    return MasterOptionsDB.shared
end
Remember = function(opt) -- after the player changed a row: keep it for the account
    if MasterOptionsDB and MasterOptionsDB.seedPending then
        MasterOptionsDB.seedPending = nil
        SeedShared()
    end
    if not (opt.scope and MasterOptionsDB and MasterOptionsDB.syncChars) then return end
    local ok, v = pcall(opt.get)
    if ok and v ~= nil and v ~= "Both (conflict)" and v ~= "Mixed" then SharedStore()[opt.label] = v end
end
SeedShared = function(onlyMissing)
    local store = SharedStore()
    for _, opt in ipairs(OPTIONS) do
        if opt.scope and Available(opt) and not (onlyMissing and store[opt.label] ~= nil) then
            local ok, v = pcall(opt.get)
            if ok and v ~= nil and v ~= "Both (conflict)" and v ~= "Mixed" then store[opt.label] = v end
        end
    end
end
-- at login: make this character match the account's choices; returns how many rows changed
local function ApplyShared()
    if not (MasterOptionsDB and MasterOptionsDB.syncChars) then return 0 end
    if MasterOptionsDB.seedPending then
        MasterOptionsDB.seedPending = nil
        SeedShared() -- just turned on: this character (after its recommended setup) is the template
        return 0
    end
    SeedShared(true) -- rows added since: start from this character
    local store, n = SharedStore(), 0
    for _, opt in ipairs(OPTIONS) do
        local want = opt.scope and store[opt.label]
        if want ~= nil and Available(opt) then
            local ok, cur = pcall(opt.get)
            if ok and cur ~= want and pcall(opt.set, want) then
                n = n + 1
                if opt.reload then MO.needsReload = true end
            end
        end
    end
    if n > 0 then MO.RefreshAll() end
    return n
end

function Available(opt)
    if type(opt.needs_any) == "table" then -- (any one of these addons is enough)
        local any = false
        for _, n in ipairs(opt.needs_any) do if Loaded(n) then any = true break end end
        if not any then return false end
    end
    if type(opt.needs) == "table" then
        for _, n in ipairs(opt.needs) do if not Loaded(n) then return false end end
    elseif opt.needs and not Loaded(opt.needs) then
        return false
    end
    -- (a choice row that names the addons it needs: those decide, not whether its choices are addons' names)
    if opt.kind == "choice" and (opt.needs or opt.needs_any) then return true end
    if opt.kind == "choice" then
        for _, c in ipairs(opt.choices) do
            if c ~= "Off" and Loaded(c) then return true end
        end
        return false
    end
    return true
end

-- a choice offered in the row's menu: "Off", or not an addon's name, or an addon that's loaded (a needs_any row's
-- own addons: only those loaded; its other choices - "All", "Dungeon Journal" - always)
local function ChoiceShown(opt, c)
    if c == "Off" or c == opt.off or opt.needs or Loaded(c) then return true end
    if type(opt.needs_any) == "table" then
        for _, n in ipairs(opt.needs_any) do if n == c then return false end end
        return true
    end
    return false
end


-- for the files after this one
MO.ApplyRecommended = ApplyRecommended
MO.ApplyShared = ApplyShared
MO.Available = Available
MO.ChoiceShown = ChoiceShown
MO.DEFAULTS_VERSION = DEFAULTS_VERSION
MO.RecOf = RecOf
MO.Remember = Remember
