-- Master Options modules: what were separate MasterOptions_<Addon>_<Addon> patch addons, now files in
-- Modules\, each run only when the addons it works with are loaded (soft dependencies) and you haven't turned
-- it off (/mo > Modules; MasterOptionsDB.modulesOff[name] = true).
--
-- A module file is MasterOptions_Module(name, { needed addons }, function(ADDON) ... end). The body runs at
-- Master Options' own ADDON_LOADED: after every addon it works with (they're Master Options' OptionalDeps,
-- so they load first) and after the saved variables are in, but before PLAYER_LOGIN - as the patches ran.
-- ADDON is the old patch's name ("MasterOptions_Mastercraft_Keep"), so error reports still say which one.
--
-- An old patch folder still installed and enabled does the same job: its module stands aside (else every hook
-- ran twice), and /mo > Problems offers to disable the folder.

local Loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local GetInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
local EnableState = C_AddOns and C_AddOns.GetAddOnEnableState

local list, byName = {}, {}

local M = { state = {}, list = list }
MasterOptions_Modules = M

function MasterOptions_Module(name, needs, body)
    if byName[name] then return end
    local m = { name = name, full = "MasterOptions_" .. name, needs = needs or {}, body = body }
    list[#list + 1] = m
    byName[name] = m
    m.full = "MasterOptions_" .. name
end

-- the old patch folder of a module: installed and enabled for this character
local function OldFolderOn(full)
    if not GetInfo then return false end
    local ok, name, _, _, _, reason = pcall(GetInfo, full)
    if not ok or not name or reason == "MISSING" then return false end
    local state
    if EnableState then
        local okE, s = pcall(EnableState, full, UnitName("player"))
        state = okE and s
    elseif GetAddOnEnableState then
        local okE, s = pcall(GetAddOnEnableState, UnitName("player"), full)
        state = okE and s
    end
    return (state or 0) > 0
end
M.OldFolderOn = OldFolderOn

local function Missing(m)
    local out = {}
    for _, a in ipairs(m.needs) do if not Loaded(a) then out[#out + 1] = a end end
    return out
end

local function Run()
    MasterOptionsDB = MasterOptionsDB or {}
    local off = type(MasterOptionsDB.modulesOff) == "table" and MasterOptionsDB.modulesOff or {}
    for _, m in ipairs(list) do
        local missing = Missing(m)
        if OldFolderOn(m.full) then
            M.state[m.name] = "old folder"
        elseif off[m.name] then
            M.state[m.name] = "off"
        elseif #missing > 0 then
            M.state[m.name] = "needs " .. table.concat(missing, ", ")
        else
            local ok, err = pcall(m.body, m.full)
            M.state[m.name] = ok and "on" or "error"
            if not ok and MasterOptions_ReportError then MasterOptions_ReportError(m.full, "starting", err) end
        end
    end
end

-- name: "Mastercraft_Keep" or "MasterOptions_Mastercraft_Keep"
local function Short(name) return (tostring(name):gsub("^MasterOptions_", "")) end
function M.Has(name) return byName[Short(name)] ~= nil end
function M.IsActive(name) return M.state[Short(name)] == "on" end
function M.State(name) return M.state[Short(name)] end
function M.Needs(name) local m = byName[Short(name)]; return m and m.needs or {} end
-- on/off for the next load (hooks can't be taken back mid-session)
function M.IsEnabled(name)
    local off = MasterOptionsDB and MasterOptionsDB.modulesOff
    return not (type(off) == "table" and off[Short(name)])
end
function M.SetEnabled(name, on)
    MasterOptionsDB = MasterOptionsDB or {}
    MasterOptionsDB.modulesOff = type(MasterOptionsDB.modulesOff) == "table" and MasterOptionsDB.modulesOff or {}
    MasterOptionsDB.modulesOff[Short(name)] = (not on) or nil
end
function M.Names()
    local out = {}
    for _, m in ipairs(list) do out[#out + 1] = m.name end
    return out
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= "MasterOptions" then return end
    f:UnregisterEvent("ADDON_LOADED")
    Run()
end)
