-- Master Options module: runs when CheapUpgrades and GearMatic are loaded.
MasterOptions_Module("CheapUpgrades_GearMatic", { "CheapUpgrades", "GearMatic" }, function(ADDON)

-- CheapUpgrades <- GearMatic's stat weights.
--
-- CheapUpgrades values items with its own weights, Pawn's scale, or a weights profile of yours. This gives it a
-- profile named "GearMatic" for every spec of your class, made from the weights GearMatic itself uses for that
-- spec (ScaleImport.GetScalesForClass: its spec lines, the same as its tooltip's rows), and uses it - so
-- CheapUpgrades' "+23%" and the auction house upgrades follow GearMatic. Kept up to date at login, on level-up
-- and on talent changes. GearMatic's weights alone carry no procs, set bonuses or caps, so its own verdicts can
-- still differ a little.
--
-- Converted to CheapUpgrades' units: GearMatic weighs crit, hit, haste, expertise, dodge, parry and block per
-- rating point, CheapUpgrades per 1% (WoW Forever's table, as CheapUpgrades' Scoring.lua uses it: 1% = 14 crit,
-- 10 hit, haste or expertise, 12 dodge, 15 parry, 5 block rating). Spell power and spell damage are one stat
-- there (the larger value, never added). Stats it has no line for (weapon skill, armor penetration) are left
-- out. Counted with CheapUpgrades' own rules (hit and expertise caps, levelling), as its built-in weights are -
-- GearMatic's are below the caps the same way.
--
-- While GearMatic itself scores with Pawn's scale (Master Options' "GearMatic stat weights: Pawn"), this stands
-- aside: CheapUpgrades then follows Pawn too (its "use Pawn's weights"), so both still agree.
-- A profile of your own chosen for a spec in CheapUpgrades stays in use there. With this module off, a spec on
-- "GearMatic" goes back to CheapUpgrades' own weights (MasterOptions.lua, at login).

local PROFILE = "GearMatic"

local Report = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

-- GearMatic stat -> CheapUpgrades stat, and how many rating points make 1% (nil: the same unit)
local STAT = {
    strength = { "STRENGTH" }, agility = { "AGILITY" }, stamina = { "STAMINA" }, intellect = { "INTELLECT" },
    spirit = { "SPIRIT" }, armor = { "ARMOR" },
    attackpower = { "ATTACK_POWER" }, ap = { "ATTACK_POWER" },
    feralattackpower = { "FERAL_ATTACK_POWER" }, feralap = { "FERAL_ATTACK_POWER" },
    rangedattackpower = { "RANGED_ATTACK_POWER" }, rap = { "RANGED_ATTACK_POWER" },
    critrating = { "CRIT", 14 }, hitrating = { "HIT", 10 }, hasterating = { "HASTE", 10 },
    expertiserating = { "EXPERTISE", 10 }, dodgerating = { "DODGE", 12 }, parryrating = { "PARRY", 15 },
    blockrating = { "BLOCK", 5 }, defenserating = { "DEFENSE" }, blockvalue = { "BLOCK_VALUE" },
    spellpower = { "SPELL_POWER" }, spelldamage = { "SPELL_POWER" }, healing = { "HEALING" },
    mp5 = { "MP5" }, hp5 = { "HP5" }, health = { "HEALTH" }, mana = { "MANA" },
    spellpenetration = { "SPELL_PENETRATION" },
    arcanespelldamage = { "ARCANE_DAMAGE_DONE" }, firespelldamage = { "FIRE_DAMAGE_DONE" },
    frostspelldamage = { "FROST_DAMAGE_DONE" }, holyspelldamage = { "HOLY_DAMAGE_DONE" },
    naturespelldamage = { "NATURE_DAMAGE_DONE" }, shadowspelldamage = { "SHADOW_DAMAGE_DONE" },
    dps = { "DPS" }, meleedps = { "DPS" }, offhanddps = { "OFFHAND_DPS" },
    rangeddps = { "RANGED_DPS" }, wanddps = { "RANGED_DPS" },
}
-- the stat a profile is shown against (1.0): the first one the spec weighs
local MAIN = { "STRENGTH", "AGILITY", "SPELL_POWER", "HEALING", "STAMINA", "INTELLECT" }

-- GearMatic's spec (its token, lower case, no spaces or _) -> CheapUpgrades' spec keys, per class
local SPECS = {
    WARRIOR = { arms = { "ARMS" }, fury = { "FURY" }, protection = { "PROT" } },
    PALADIN = { holy = { "HOLY" }, protection = { "PROT" }, retribution = { "RET" } },
    HUNTER = { beastmastery = { "BM" }, marksmanship = { "MM" }, survival = { "SV", "SVMELEE" } },
    ROGUE = { assassination = { "ASSA" }, combat = { "COMBAT" }, subtlety = { "SUB" } },
    PRIEST = { discipline = { "DISC" }, holy = { "HOLY" }, shadow = { "SHADOW" } },
    SHAMAN = { elemental = { "ELE" }, enhancement = { "ENH" }, restoration = { "RESTO" } },
    MAGE = { arcane = { "ARCANE" }, fire = { "FIRE" }, frost = { "FROST" } },
    WARLOCK = { affliction = { "AFFLI" }, demonology = { "DEMO" }, destruction = { "DESTRO" } },
    DRUID = { balance = { "BALANCE" }, feraldps = { "CAT" }, feral = { "CAT" }, feraltank = { "BEAR" },
              restoration = { "RESTO" } },
}

-- GearMatic weights -> CheapUpgrades weights (nil when nothing usable)
local function Convert(gw, known)
    local out = {}
    for k, v in pairs(gw) do
        local m = type(k) == "string" and type(v) == "number" and v == v and STAT[k:lower()]
        if m and (not known or known[m[1]]) then
            local value = v * (m[2] or 1)
            if out[m[1]] == nil or value > out[m[1]] then out[m[1]] = value end -- (two names, one stat: the larger)
        end
    end
    local main
    for _, s in ipairs(MAIN) do
        if (out[s] or 0) > 0 then main = out[s] break end
    end
    if not main then return nil end
    local any = false
    for s, v in pairs(out) do
        v = v / main
        out[s] = math.floor(v * 10000 + 0.5) / 10000
        if out[s] ~= 0 then any = true end
    end
    return any and out or nil
end

local function Token(scale)
    local t = scale.specToken or scale.spec or scale.name
    return type(t) == "string" and t:gsub("[%s_]", ""):lower() or nil
end

-- CheapUpgrades spec key -> GearMatic's weights for it (GearMatic's own spec lines: not a copy of a Pawn scale)
local function GearMaticWeights(class)
    local gm = _G.GearMatic
    local si, c = gm and gm.ScaleImport, gm and gm.Compat
    if not (si and type(si.GetScalesForClass) == "function" and c and type(c.CurrentCharKey) == "function") then return nil end
    local key = c.CurrentCharKey()
    if not key then return nil end
    local map = SPECS[class]
    if not map then return nil end
    local out = {}
    for _, scale in ipairs(si.GetScalesForClass(key) or {}) do
        if type(scale) == "table" and (scale.speclogic or scale.bundled) and type(scale.weights) == "table" then
            for _, specKey in ipairs(map[Token(scale) or ""] or {}) do
                if not out[specKey] then out[specKey] = scale.weights end
            end
        end
    end
    return out
end

local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- Brings every spec's "GearMatic" profile up to date and uses it where you haven't picked one of your own.
-- Returns how many profiles changed.
local function Sync()
    local cu = _G.CheapUpgrades
    local P = cu and cu.Profiles
    if not (P and type(P.Get) == "function" and type(P.Create) == "function" and type(P.SetActive) == "function"
        and type(cu.GetClass) == "function" and cu.chardb and cu.db) then return 0 end
    -- GearMatic on Pawn's scale: let go, so CheapUpgrades' Pawn setting applies
    local si = _G.GearMatic and _G.GearMatic.ScaleImport
    local onPawn = si and type(si.PawnLiveScaleName) == "function" and select(2, pcall(si.PawnLiveScaleName)) or nil
    if type(onPawn) == "string" then
        local released = 0
        for specKey, name in pairs(cu.chardb.profile or {}) do
            if name == PROFILE then cu.chardb.profile[specKey] = nil; released = released + 1 end
        end
        if released > 0 and type(cu.Evaluate) == "function" then pcall(cu.Evaluate, cu) end
        return released
    end
    local class = cu:GetClass()
    local known = type(P.Known) == "function" and P.Known() or nil
    local weights = GearMaticWeights(class)
    if not weights then return 0 end
    local changed = 0
    for specKey, gw in pairs(weights) do
        local w = Convert(gw, known)
        if w then
            local p = P:Get(class, specKey, PROFILE)
            if not p then
                P:Create(specKey, PROFILE, w, class)
                changed = changed + 1
            elseif not Same(p.weights or {}, w) then
                p.weights = w
                changed = changed + 1
            end
            local chosen = cu.chardb.profile and cu.chardb.profile[specKey]
            if chosen == nil then
                P:SetActive(specKey, PROFILE)
                changed = changed + 1
            end
        end
    end
    if changed > 0 and type(cu.Evaluate) == "function" then pcall(cu.Evaluate, cu) end
    return changed
end

local SyncSoon = MasterOptions_Shared.Debounce(function()
    local ok, err = pcall(Sync)
    if not ok then Report("giving CheapUpgrades GearMatic's weights", err) end
end, 1)

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
    SyncSoon(event == "PLAYER_LOGIN" and 4 or 1) -- (login: after GearMatic and CheapUpgrades have set up)
end)

MasterOptions_CheapUpgradesGearMatic = { Sync = Sync, Convert = Convert, PROFILE = PROFILE }
end)
