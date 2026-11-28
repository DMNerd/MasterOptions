-- Master Options module: runs when OpenMap and Questie are loaded.
MasterOptions_Module("OpenMap_QuestieTownsfolk", { "OpenMap", "Questie" }, function(ADDON)

-- One townsfolk menu: the kinds Questie's townsfolk menu has too - repair, innkeepers, bankers, mailboxes,
-- auctioneers, stable masters, class trainers, spirit healers - are taken out of OpenMap's Townsfolk menu (and its
-- "Find a place" townsfolk), so they're picked in Questie's menu only and never show twice on the world map. Questie
-- draws them on the world map and the minimap; OpenMap only on the world map. OpenMap keeps what Questie hasn't got
-- (its vendors, profession trainers, rare mobs).
-- With "Town NPC icons" on "OpenMap + game's tracking" (MasterOptionsDB.townOpenMap[character]) OpenMap's are the
-- ones in use: then they're all there, as OpenMap has them.
-- Only OpenMap's list of kinds (mod.TOWNSFOLK: its menu, its search and its drawing all read it) is changed, in
-- memory; a kind taken out that was on in OpenMap is turned on in Questie's menu instead.

local S = MasterOptions_Shared
local _, Check = S.ErrorReporters(ADDON)

-- OpenMap's key -> Questie's
local SAME = { repair = "Repair", innkeeper = "Innkeeper", banker = "Banker", mailbox = "Mailbox",
               auctioneer = "Auctioneer", stable = "Stable Master", classTrainer = "Class Trainer",
               spirit = "Spirit Healer" }

local function OpenMapMod()
    local mod = S.OpenMapWorldMap()
    if mod and type(mod.TOWNSFOLK) == "table" and type(mod.db) == "table" then return mod end
end

-- OpenMap's townsfolk wanted ("Town NPC icons": OpenMap + game's tracking, this character)
local function OpenMapsInUse()
    local t = MasterOptionsDB and MasterOptionsDB.townOpenMap
    return type(t) == "table" and t[S.CharacterKey()] == true
end

local all       -- OpenMap's kinds as it has them (its order), kept the first time any is taken out
local hidden = false

local function Apply()
    local mod = OpenMapMod()
    if not mod then return end
    local kinds = mod.TOWNSFOLK
    all = all or { unpack(kinds) }
    local hide = not OpenMapsInUse()
    if hide == hidden then return end
    hidden = hide
    local folk = type(mod.db.townsfolk) == "table" and mod.db.townsfolk or {}
    local stitch = _G.OpenMap and _G.OpenMap.MapStitch
    if hide then
        -- (a kind on in OpenMap: on in Questie's menu instead, so nothing you had goes; OpenMap's pins of it off)
        local q = _G.Questie and _G.Questie.db and _G.Questie.db.profile
        local cfg = type(q) == "table" and type(q.townsfolkConfig) == "table" and q.townsfolkConfig
        local moved = false
        for key, qkey in pairs(SAME) do
            if folk[key] == true then
                folk[key] = false
                if cfg and cfg[qkey] ~= true then cfg[qkey] = true; moved = true end
            end
            local set = type(stitch) == "table" and type(stitch.GetPinSet) == "function" and stitch.GetPinSet("tf_" .. key)
            if set and type(stitch.SetPinSetOn) == "function" then pcall(stitch.SetPinSetOn, set, false) end
        end
        if moved then
            local menu = S.QuestieModule("QuestieMenu")
            if menu and menu.OnLogin then pcall(menu.OnLogin, menu, true) end
        end
    end
    -- the list refilled in place (OpenMap's files hold this table, not a copy)
    for i = #kinds, 1, -1 do kinds[i] = nil end
    for _, k in ipairs(all) do
        if not (hide and SAME[k.key]) then kinds[#kinds + 1] = k end
    end
    if type(mod.RefreshTownsfolk) == "function" then pcall(mod.RefreshTownsfolk, mod) end
    if type(mod.RefreshPanel) == "function" then pcall(mod.RefreshPanel, mod) end
end

-- now (before OpenMap's menu is first built), and at login (the saved choice, OpenMap set up)
Check("taking Questie's townsfolk out of OpenMap's menu", pcall(Apply))
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() Check("taking Questie's townsfolk out of OpenMap's menu", pcall(Apply)) end)

MasterOptions_OpenMapTownsfolk = { Apply = function() Check("taking Questie's townsfolk out of OpenMap's menu", pcall(Apply)) end,
                                   Hidden = function() return hidden end, SAME = SAME }
end)
