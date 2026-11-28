-- Master Options: what the options read and write in other addons - Annoying mode (posting in chat as you), the
-- bag icon size, Baganator's and Chattynator's profiles, the UI style, and the bag icons that follow other choices.

local _, MO = ...
-- from the files before this one
local AUC, CU, GM, GMRefreshBagIcons, Loaded, MC, OMT = MO.AUC, MO.CU, MO.GM, MO.GMRefreshBagIcons, MO.Loaded, MO.MC, MO.OMT

---------------------------------------------------------------------------
-- Chat switches: groups of settings with which addons write in chat, turned off and back on together.
--   Annoying mode       what addons post AS YOU, for other players to see - upgrades shouted to the group or guild,
--                       public emotes, automatic whispers. Found by what each addon sends (SendChatMessage /
--                       DoEmote), not by its labels; what is sent only when you ask (Details' reports, typed
--                       commands) isn't here.
--   Chat lines only you see   notices addons print in your own chat window.
-- Off remembers each setting (per character: GearMatic's and Questie's can be per profile), an already-off one
-- too, then turns them all off; on puts back what it remembered (with nothing remembered: each addon's default).
---------------------------------------------------------------------------
local function GMSocial()
    local s = GM()
    if not s then return nil end
    s.social = type(s.social) == "table" and s.social or {}
    return s.social
end
local function QuestieProfile()
    local q = Loaded("Questie") and type(_G.Questie) == "table" and _G.Questie.db and _G.Questie.db.profile
    return type(q) == "table" and q or nil
end
local function DJDB()
    local db = Loaded("ForeverDungeonJournal") and _G.ForeverDungeonJournalDB
    return type(db) == "table" and db or nil
end

local LEAVE = {} -- (a default meaning: nothing remembered, so leave it as it is)
local function OnUnlessFalse(v) return v ~= false end

-- A setting in a table: tbl() -> the table or nil; on(v) -> is it on; off: the value that turns it off;
-- default: what "on" sets when nothing was remembered (LEAVE: nothing)
local function Field(id, addon, what, tbl, key, on, off, default)
    if off == nil then off = false end         -- (not "off == nil and false or off": that gives nil)
    if default == nil then default = true end
    return { id = id, addon = addon, what = what, on = on or OnUnlessFalse, off = off, default = default,
             ready = function() return tbl() ~= nil end,
             get = function() local t = tbl(); return t and t[key] end,
             set = function(v) local t = tbl(); if t then t[key] = v end end }
end

local ANNOYING = {}
for _, k in ipairs({ { "emote", "an emote with each upgrade you equip" },
                     { "vendorEmote", "a public emote with what auto-sell sold and repairs cost" },
                     { "sendToParty", "your upgrades in /party" }, { "sendToRaid", "your upgrades in /raid" },
                     { "sendToGuild", "your upgrades in /guild" }, { "sendToBattleGrounds", "your upgrades in battleground chat" } }) do
    ANNOYING[#ANNOYING + 1] = Field("gm:" .. k[1], "GearMatic", k[2], GMSocial, k[1])
end
ANNOYING[#ANNOYING + 1] = Field("questie:announce", "Questie", "quest progress in /party or /raid", QuestieProfile,
    "questAnnounceChannel", function(v) return v ~= nil and v ~= "disabled" end, "disabled", LEAVE) -- (Questie's default: "disabled")
ANNOYING[#ANNOYING + 1] = Field("mc:whoReply", "Mastercraft", "whispers answering !who in guild and group chat", MC, "whoReply")

local CHAT_LINES = {
    Field("gm:chatNotificationsEnabled", "GearMatic", "a line for each new item you equip", GM, "chatNotificationsEnabled"),
    Field("gm:autoEquipLoginHint", "GearMatic", "the auto-equip reminder at login", GM, "autoEquipLoginHint"),
    Field("gm:dropReminder", "GearMatic", "the reminder to share recorded drops", GM, "dropReminder"),
    Field("cu:bagAlerts", "CheapUpgrades", "a line when new gear in your bags is an upgrade", CU, "bagAlerts"),
    Field("mc:junkSummary", "Mastercraft", "what selling junk brought in", MC, "junkSummary"),
    Field("mc:repairSummary", "Mastercraft", "what the repair cost", MC, "repairSummary"),
    Field("questie:items", "Questie", "items you pick up that start a quest", QuestieProfile, "questAnnounceItems"),
    Field("questie:local", "Questie", "your quest updates", QuestieProfile, "questAnnounceLocally",
        function(v) return v == true end, false, LEAVE), -- (off by default in Questie)
    Field("dj:chat", "ForeverDungeonJournal", "Dungeon Journal's notices", DJDB, "hideChatLines",
        function(v) return v ~= true end, true, LEAVE), -- (inverted: "hide" on = lines off)
    { id = "auc:chatLog", addon = "Auctionator", what = "your new auctions", on = OnUnlessFalse, off = false, default = true,
      ready = function() return AUC("auction_chat_log") ~= nil end,
      get = function() return AUC("auction_chat_log") end,
      set = function(v) AUC("auction_chat_log", v) end },
}
-- (LEAVE for dj:chat: nil is Dungeon Journal's "shown", so remembering nil and putting it back is all it needs)

local function SavedFor(store)
    local char = MasterOptions_Shared.CharacterKey()
    MasterOptionsDB[store] = type(MasterOptionsDB[store]) == "table" and MasterOptionsDB[store] or {}
    MasterOptionsDB[store][char] = MasterOptionsDB[store][char] or {}
    return MasterOptionsDB[store][char]
end

-- on while any of them writes
local function GroupOn(list)
    for _, c in ipairs(list) do
        if Loaded(c.addon) and c.ready() and c.on(c.get()) then return true end
    end
    return false
end

local function SetGroup(list, store, on)
    local saved = SavedFor(store)
    for _, c in ipairs(list) do
        if Loaded(c.addon) and c.ready() then
            if not on then
                -- every one remembered, an already-off one too (on must not turn on what you had off); a second
                -- "off" keeps what the first remembered. (Wrapped: nil, the addon's default, is remembered too.)
                if saved[c.id] == nil then saved[c.id] = { v = c.get() } end
                c.set(c.off)
            elseif saved[c.id] then
                c.set(saved[c.id].v)
                saved[c.id] = nil
            elseif c.default ~= LEAVE then
                c.set(c.default) -- (nothing remembered: the addon's default)
            end
        end
    end
end

local function AnnoyingOn() return GroupOn(ANNOYING) end
local function SetAnnoying(on) SetGroup(ANNOYING, "annoyingSaved", on) end
local function ChatLinesOn() return GroupOn(CHAT_LINES) end
local function SetChatLines(on) SetGroup(CHAT_LINES, "chatLinesSaved", on) end

---------------------------------------------------------------------------
-- Bag icon size: every icon any addon puts in a corner of Baganator's bag slots, one size
-- Baganator hands each corner widget, as it creates it, to its skin listeners (API.Skins.RegisterListener,
-- regionType "CornerWidget", tags = { widget id }): an icon (texture or frame) is scaled there. Text (item
-- level, counts, "+23%") is left alone - Baganator sizes it by its own font size (the sizeFont ones). GearMatic's
-- widgets are sized by GearMatic itself (its bagIconSize, also for its bottom-left badge, which isn't a widget):
-- the row sets that instead, so nothing is scaled twice.
---------------------------------------------------------------------------
local ICON_SCALE = { Large = 1, Medium = 23 / 28, Small = 18 / 28 } -- (GearMatic's steps: its badge 28 / 23 / 18)
local GM_ICON_SIZE = { Large = "large", Medium = "medium", Small = "small" }

local function BagIconSize() return MasterOptionsDB and MasterOptionsDB.bagIconSize or "Large" end

local function ScaleCornerIcon(details)
    if type(details) ~= "table" or details.regionType ~= "CornerWidget" then return end
    local r, id = details.region, type(details.tags) == "table" and details.tags[1]
    if type(r) ~= "table" or type(r.SetScale) ~= "function" or r.sizeFont then return end
    if r.GetObjectType and r:GetObjectType() == "FontString" then return end
    if type(id) == "string" and id:find("^gearmatic") then return end
    r:SetScale(ICON_SCALE[BagIconSize()] or 1)
end

local function ApplyBagIconSize()
    local api = _G.Baganator and _G.Baganator.API and _G.Baganator.API.Skins
    if api and api.GetAllFrames then
        for _, details in ipairs(api.GetAllFrames() or {}) do pcall(ScaleCornerIcon, details) end
    end
    local s = Loaded("GearMatic") and GM()
    local gmSize = GM_ICON_SIZE[BagIconSize()]
    -- (only once you've picked a size here: until then GearMatic keeps its own)
    if s and MasterOptionsDB and MasterOptionsDB.bagIconSize and s.bagIconSize ~= gmSize then
        s.bagIconSize = gmSize
        GMRefreshBagIcons()
    end
end

do
    local api = Loaded("Baganator") and _G.Baganator and _G.Baganator.API and _G.Baganator.API.Skins
    if api and api.RegisterListener then
        api.RegisterListener(function(details) pcall(ScaleCornerIcon, details) end)
    end
end

---------------------------------------------------------------------------
-- Baganator and Chattynator settings: the active profile table (written directly; they read it on reload)
---------------------------------------------------------------------------
local function ProfileOf(addon, config, current)
    local c = _G[config]
    if not (Loaded(addon) and type(c) == "table" and type(c.Profiles) == "table") then return nil end
    return c.Profiles[_G[current] or "DEFAULT"] or c.Profiles.DEFAULT
end
local function BAG()  return ProfileOf("Baganator", "BAGANATOR_CONFIG", "BAGANATOR_CURRENT_PROFILE") end
local function CHAT() return ProfileOf("Chattynator", "CHATTYNATOR_CONFIG", "CHATTYNATOR_CURRENT_PROFILE") end

local CORNERS = { "icon_top_left_corner_array", "icon_top_right_corner_array",
                  "icon_bottom_left_corner_array", "icon_bottom_right_corner_array" }
local function CornerHas(p, id)
    for _, k in ipairs(CORNERS) do
        if type(p[k]) == "table" then
            for _, v in ipairs(p[k]) do if v == id then return true end end
        end
    end
    return false
end
local function CornerRemove(p, id)
    for _, k in ipairs(CORNERS) do
        local arr = p[k]
        if type(arr) == "table" then
            for i = #arr, 1, -1 do if arr[i] == id then table.remove(arr, i) end end
        end
    end
end
local function CornerAdd(p, id, key)
    if CornerHas(p, id) then return end
    p[key] = type(p[key]) == "table" and p[key] or {}
    table.insert(p[key], 1, id)
end

-- DeleteCheapestItem: its AceDB profile (found through AceDB's registry, as its own table is private)
local function DCIProfile()
    if not Loaded("DeleteCheapestItem") or type(_G.DCI_ProfilesDB) ~= "table" then return nil end
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if not (AceDB and AceDB.db_registry) then return nil end
    for db in pairs(AceDB.db_registry) do
        if db.sv == _G.DCI_ProfilesDB then return db.profile end
    end
end

-- Baganator switches to a plugin as it registers whenever the chosen one isn't a registered plugin ("Greys only"
-- = "poor_quality" and "Off" = "none" never are) unless that plugin is on its *_plugin_ignored list (API\Main.lua
-- AutoSet). Its own settings window fills that list on every change; writing the choice directly didn't - so
-- "Greys only" came back as GearMatic's coins after a reload. Every plugin we know of goes on the list, the
-- chosen one off it.
local KNOWN_PLUGINS = {
    junk = { "gearmatic", "mastercraft", "selljunk", "scrap", "vendor", "dejunk", "peddler", "enhanceqol_vendor" },
    upgrade = { "pawn", "gearmatic_upgrade", "simple_item_levels" },
}
local function SetBagPlugin(p, kind, id)
    p[kind .. "_plugin"] = id
    local key = kind .. "_plugin_ignored"
    p[key] = type(p[key]) == "table" and p[key] or {}
    for _, other in ipairs(KNOWN_PLUGINS[kind]) do p[key][other] = true end
    p[key][id] = nil
end

-- Baganator: the two bag-icon rows, on any profile
local function ApplyUpgradeArrow(p, v)
    if v == "Pawn" and not Loaded("Pawn") then return end
    if v == "GearMatic" and not Loaded("GearMatic") then return end
    CornerRemove(p, "pawn"); CornerRemove(p, "gearmatic_upgrade_corner")
    if v == "Pawn" then CornerAdd(p, "pawn", CORNERS[1])
    elseif v == "GearMatic" then CornerAdd(p, "gearmatic_upgrade_corner", CORNERS[1]) end
    SetBagPlugin(p, "upgrade", (v == "Pawn" and "pawn") or (v == "GearMatic" and "gearmatic_upgrade") or "none")
end
local function ApplyJunk(p, v)
    if v == "GearMatic" and Loaded("MasterOptions_GearMatic_Baganator") then SetBagPlugin(p, "junk", "gearmatic")
    elseif v == "Mastercraft" and Loaded("MasterOptions_Baganator_Mastercraft") then SetBagPlugin(p, "junk", "mastercraft")
    else SetBagPlugin(p, "junk", "poor_quality") end -- (Mastercraft without our plugin: greys, Baganator's own rule)
end
local function ArrowState(p)
    local pw, gm = CornerHas(p, "pawn"), CornerHas(p, "gearmatic_upgrade_corner")
    if pw and gm then return "Both (conflict)" end
    return pw and "Pawn" or gm and "GearMatic" or "Off"
end
local function JunkState(p)
    return (p.junk_plugin == "gearmatic" and "GearMatic") or (p.junk_plugin == "mastercraft" and "Mastercraft") or "Greys only"
end

---------------------------------------------------------------------------
-- UI style: each addon's own skin setting, WoW (Blizzard-like) or Dark. nil = leave that addon as it is.
---------------------------------------------------------------------------
local function DetailsInstances()
    local d = _G.Details
    if not (Loaded("Details") and type(d) == "table" and d.GetAllInstances) then return {} end
    local out = {}
    for _, inst in ipairs(d:GetAllInstances() or {}) do
        if type(inst) == "table" and inst.ativa and inst.ChangeSkin then out[#out + 1] = inst end
    end
    return out
end

-- Town NPCs (auctioneer, banker, innkeeper ...): the game's minimap tracking and Questie's townsfolk show the
-- same kinds. TOWN: the kinds both have, under the same (English) name.
local TOWN = { "Auctioneer", "Banker", "Battlemaster", "Innkeeper", "Mailbox", "Repair", "Stable Master", "Flight Master" }

-- the game's tracking list: name -> { index, active }
local function TownTracking()
    local out = {}
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return out end
    local okN, n = pcall(C_Minimap.GetNumTrackingTypes)
    for i = 1, (okN and n or 0) do
        local ok, a, _, c = pcall(C_Minimap.GetTrackingInfo, i)
        if ok then
            local name, active
            if type(a) == "table" then name, active = a.name, a.active else name, active = a, c end -- (table on newer clients)
            if type(name) == "string" then out[name] = { index = i, active = active == true } end
        end
    end
    return out
end
local function QuestieTown()
    local q = QuestieProfile()
    if not q then return nil end
    q.townsfolkConfig = type(q.townsfolkConfig) == "table" and q.townsfolkConfig or {}
    return q.townsfolkConfig
end
-- Questie draws its townsfolk again from its settings (its own login pass: off first, then what's ticked)
local function QuestieTownRefresh()
    local menu = MasterOptions_Shared.QuestieModule("QuestieMenu")
    if menu and menu.OnLogin then pcall(menu.OnLogin, menu, true) end
end
-- OpenMap draws some of the same kinds on the world map (Map\Townsfolk.lua, from Questie's database; all off
-- by default): with Questie's on too, each shows twice there. (Not on the minimap, so the game's tracking and
-- OpenMap's don't double.) Questie's name -> OpenMap's key.
local TOWN_OPENMAP = { Auctioneer = "auctioneer", Banker = "banker", Innkeeper = "innkeeper", Mailbox = "mailbox",
                       Repair = "repair", ["Stable Master"] = "stable" }
local function OpenMapTown()
    local om = Loaded("OpenMap") and _G.OpenMap
    local mod = type(om) == "table" and om.GetModule and om:GetModule("worldmap")
    if mod and type(mod.db) == "table" and type(mod.db.townsfolk) == "table" then return mod.db.townsfolk, mod end
end
-- flight masters: their own row ("Flight masters") while OpenMap is loaded - OpenMap draws them too (worldmap.flight)
local function FlightOwnRow() return Loaded("OpenMap") end
local function TownKinds()
    local out = {}
    for _, k in ipairs(TOWN) do if not (k == "Flight Master" and FlightOwnRow()) then out[#out + 1] = k end end
    return out
end
-- Questie (world map and minimap), the game's tracking (minimap only), or OpenMap on the world map with the game's
-- tracking on the minimap (a kind OpenMap doesn't draw: the game's tracking alone)
local function TownGet()
    local t, q = TownTracking(), QuestieTown()
    if not q then return "Questie" end
    local o = OpenMapTown() or {}
    local game, questie, openmap = false, false, false
    for _, k in ipairs(TownKinds()) do
        local g, qq = t[k] and t[k].active, q[k] == true
        local om = TOWN_OPENMAP[k] and o[TOWN_OPENMAP[k]] == true
        if g and qq then return "Both (conflict)" end
        if qq and om then return "Both (conflict)" end
        game, questie, openmap = game or g, questie or qq, openmap or om
    end
    if questie then return "Questie" end
    if openmap then return "OpenMap + game's tracking" end
    return game and "Game's tracking" or "Questie"
end
-- the kinds you have on (in any) move to the one picked; the others turn them off
local function TownSet(v)
    local t, q = TownTracking(), QuestieTown()
    if not q then return end
    local o, omMod = OpenMapTown()
    local setTracking = C_Minimap and C_Minimap.SetTracking
    local omChanged = false
    local function Track(g, on)
        if g and g.active ~= on and setTracking then pcall(setTracking, g.index, on) end
    end
    for _, k in ipairs(TownKinds()) do
        local g = t[k]
        local ok = o and TOWN_OPENMAP[k]
        local on = (g and g.active) or q[k] == true or (ok and o[ok] == true)
        if v == "Questie" then
            if on then q[k] = true end
            Track(g, false)
            -- (Questie's own world map icons: OpenMap's of the same kind off, else each shows twice there)
            if ok and o[ok] == true then o[ok] = false; omChanged = true end
        elseif g or ok then -- (a kind neither the game's list nor OpenMap has stays with Questie)
            if on then Track(g, true) end
            if q[k] then q[k] = false end
            if ok then
                local want = on and v == "OpenMap + game's tracking"
                if (o[ok] == true) ~= want then o[ok] = want; omChanged = true end
            end
        end
    end
    -- (OpenMap's townsfolk that Questie has too are out of its menu - OpenMap_QuestieTownsfolk - unless they're the
    -- ones in use: put back first, so the kinds set above are there)
    MasterOptionsDB = MasterOptionsDB or {}
    MasterOptionsDB.townOpenMap = type(MasterOptionsDB.townOpenMap) == "table" and MasterOptionsDB.townOpenMap or {}
    MasterOptionsDB.townOpenMap[MasterOptions_Shared.CharacterKey()] = (v == "OpenMap + game's tracking") or nil
    local hide = _G.MasterOptions_OpenMapTownsfolk
    if hide and hide.Apply then hide.Apply() end
    if omChanged and omMod and omMod.RefreshTownsfolk then pcall(omMod.RefreshTownsfolk, omMod) end
    QuestieTownRefresh()
end

-- OpenMap_MiniMap: the profile in use - this character's own (OpenMap keys it on the first name), or the shared one
local function OMM()
    return Loaded("OpenMap_MiniMap") and MasterOptions_Shared.OpenMapMiniMapProfile() or nil
end

---------------------------------------------------------------------------
-- Maps and routes: who draws or does what, when several addons do the same (2.9.0's compatibility review)
---------------------------------------------------------------------------
local function OpenMapWM()
    local mod = Loaded("OpenMap") and MasterOptions_Shared.OpenMapWorldMap()
    return mod and type(mod.db) == "table" and mod or nil
end

-- Flight masters: OpenMap's flight set (worldmap.flight; OpenMap_MiniMap's pinFlights on the minimap) or Questie's
-- townsfolk "Flight Master" (world map and minimap); the game's minimap tracking of them off either way.
-- (OpenMap_Tweaks turns OpenMap's back on whenever the map opens: with it, Questie's alone isn't possible.)
local function FlightGet()
    local q, mod = QuestieTown(), OpenMapWM()
    local om = mod and mod.db.flight ~= false
    local qq = q and q["Flight Master"] == true
    if om and qq then return "Both (conflict)" end
    return (qq and not om) and "Questie" or "OpenMap"
end
local function FlightSet(v)
    local q, mod, mm = QuestieTown(), OpenMapWM(), OMM()
    local openmap = v == "OpenMap"
    if q then q["Flight Master"] = not openmap end
    if mod then
        mod.db.flight = openmap
        local S = _G.OpenMap and _G.OpenMap.MapStitch
        local set = S and type(S.GetPinSet) == "function" and S.GetPinSet("flight")
        if type(set) == "table" and type(S.SetPinSetOn) == "function" then pcall(S.SetPinSetOn, set, openmap) end
    end
    if mm then mm.pinFlights = openmap end
    local g = TownTracking()["Flight Master"]
    if g and g.active and C_Minimap and C_Minimap.SetTracking then pcall(C_Minimap.SetTracking, g.index, false) end
    QuestieTownRefresh()
end

-- World map coordinates: OpenMap's bar (worldmap.coords) or Questie's (in the map's title: mapCoordinatesEnabled)
local function MapCoordsGet()
    local mod, q = OpenMapWM(), QuestieProfile()
    local om = mod and mod.db.coords ~= false
    local qq = q and q.mapCoordinatesEnabled == true
    if om and qq then return "Both (conflict)" end
    return om and "OpenMap" or qq and "Questie" or "Off"
end
local function MapCoordsSet(v)
    local mod, q = OpenMapWM(), QuestieProfile()
    if mod then mod.db.coords = v == "OpenMap" end
    if q then q.mapCoordinatesEnabled = v == "Questie" end
end

-- ShortestPathForever's settings (ShortestPathForeverDB: its arrow reads them as it draws)
local function SPF()
    return Loaded("ShortestPathForever") and type(_G.ShortestPathForeverDB) == "table" and _G.ShortestPathForeverDB or nil
end
local LABELS = { Distance = "distance", Time = "time", Both = "both" }
-- one of its settings: through the game's Settings where it's registered (ShortestPathForever_<key>: its own
-- refresh runs, no reload), else straight into its saved settings
local function SetSPF(key, value)
    local s = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_" .. key)
    if s and s.SetValue and pcall(s.SetValue, s, value) then return end
    local d = SPF(); if d then d[key] = value end
end
-- Navigation arrow: its arrow, or only its pin over the destination (destinationPin). Since ShortestPathForever 1.49.4
-- its arrow off also takes away the game's waypoint marker (only TomTom's arrow stays): "Game's marker only" (until
-- 2.19.0) left nothing to follow. The pin is turned on with it, and off again on the way back if we turned it on.
local PIN_ONLY, OLD_PIN_ONLY = "Destination pin only", "Game's marker only"
local function ArrowGet()
    local d = SPF() or {}
    return d.arrow == false and PIN_ONLY or "Shortest Path's arrow"
end
local function ArrowSet(v)
    if not SPF() then return end
    MasterOptionsDB = MasterOptionsDB or {}
    if v == OLD_PIN_ONLY then
        v = PIN_ONLY
        -- (the account-wide choice kept under its old name: the new one, so it isn't set again at every login)
        local shared = MasterOptionsDB.shared
        if type(shared) == "table" and shared["Navigation arrow"] == OLD_PIN_ONLY then shared["Navigation arrow"] = PIN_ONLY end
    end
    local pinOnly = v == PIN_ONLY
    SetSPF("arrow", not pinOnly)
    if pinOnly then
        if SPF().destinationPin ~= true then
            SetSPF("destinationPin", true)
            MasterOptionsDB.spfPinOurs = true
        end
    elseif MasterOptionsDB.spfPinOurs then
        MasterOptionsDB.spfPinOurs = nil
        SetSPF("destinationPin", false)
    end
end
local function ArrowTextGet()
    local m = (SPF() or {}).arrowLabel or "distance"
    for label, key in pairs(LABELS) do if key == m then return label end end
    return "Distance"
end
local function ArrowTextSet(v) local d = SPF(); if d then d.arrowLabel = LABELS[v] or "distance" end end
-- Questie's, Mastercraft's and WhatsTraining's waypoints go to TomTom; without TomTom, ShortestPathForever stands
-- in for it (its "Let guides set TomTom waypoints": tomtom) and they become journeys. Off: the game's waypoint.
local function TargetsGet() return (SPF() or {}).tomtom == false and "Game's waypoint" or "Shortest Path journey" end
-- (through its own setting, ShortestPathForever_tomtom, where it's registered: its stand-in starts or stands down at
-- once - ns.RefreshTomTom - instead of after a reload)
local function TargetsSet(v)
    local on = v ~= "Game's waypoint"
    local s = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_tomtom")
    if s and s.SetValue and pcall(s.SetValue, s, on) then return end
    local d = SPF(); if d then d.tomtom = on end
end

-- OpenMap_MiniMap's other addons' minimap buttons: round the edge, only on mouse-over, or gathered in a tray
local function ButtonsGet()
    local p = OMM() or {}
    if p.buttonTray == true then return "In a tray" end
    return p.hoverButtons == false and "Round the edge" or "On mouse-over"
end
local function ButtonsSet(v)
    local p = OMM(); if not p then return end
    p.buttonTray = v == "In a tray"
    p.hoverButtons = v ~= "Round the edge"
end

local STYLES = {
    -- (OpenMap's minimap, square either way: WoW = its gold frame round map and zone bar, Dark = the thin
    -- dark border, its default)
    { name = "OpenMap_MiniMap", label = "OpenMap minimap (shape / border)", wow = "square / gold", dark = "square / dark", reload = true,
      get = function()
          local p = OMM(); if not p then return nil end
          return (p.shape or "square") .. " / " .. (p.border or "dark")
      end,
      set = function(v)
          local p = OMM(); if not p then return end
          local shape, border = v:match("^(%a+) / (%a+)$")
          if shape then p.shape, p.border = shape, border end
      end },
    { name = "Baganator", wow = "blizzard", dark = "dark", reload = true,
      get = function() local p = BAG(); return p and p.current_skin end,
      set = function(v) local p = BAG(); if p then p.current_skin = v end end },
    { name = "Chattynator", wow = "blizzard", dark = "dark", reload = true,
      get = function() local p = CHAT(); return p and p.current_skin end,
      set = function(v) local p = CHAT(); if p then p.current_skin = v end end },
    { name = "Details", wow = "WoW Interface", dark = "Minimalistic",
      get = function()
          local list = DetailsInstances()
          if #list == 0 then return nil end
          local s = list[1].skin
          for _, inst in ipairs(list) do if inst.skin ~= s then return "mixed" end end
          return s
      end,
      set = function(v) for _, inst in ipairs(DetailsInstances()) do pcall(inst.ChangeSkin, inst, v) end end },
    { name = "Mastercraft", wow = "wow", dark = "midnight", reload = true,
      get = function() local m = MC(); return m and (m.theme or "wow") end,
      set = function(v) local m = MC(); if m then m.theme = v end end },
    { name = "BetterBlizzFrames", label = "BetterBlizzFrames dark mode", wow = false, dark = true, reload = true,
      get = function()
          local db = _G.BetterBlizzFramesDB
          if not (Loaded("BetterBlizzFrames") and type(db) == "table") then return nil end
          return db.darkModeUi == true
      end,
      set = function(v) local db = _G.BetterBlizzFramesDB; if type(db) == "table" then db.darkModeUi = v end end },
    -- Forever's own bronze window frame is the WoW look; its alternative is a plain Blizzard frame, not a dark
    -- one, so Dark leaves it alone.
    { name = "DeleteCheapestItem", label = "DeleteCheapestItem bronze frame", wow = false, dark = nil, reload = true,
      get = function() local p = DCIProfile(); if p then return p.HideBronzeTheme == true end end,
      set = function(v) local p = DCIProfile(); if p then p.HideBronzeTheme = v end end },
}

local function StyleAvailable(s) return Loaded(s.name) and s.get() ~= nil end

local UIStyleGet, UIStyleSet, UIStyleTip
local function styleMatches(look)
    local any = false
    for _, s in ipairs(STYLES) do
        local want = s[look]
        if want ~= nil and StyleAvailable(s) then
            any = true
            if s.get() ~= want then return false end
        end
    end
    return any
end
UIStyleGet = function()
    if styleMatches("wow") then return "WoW" end
    if styleMatches("dark") then return "Dark" end
    return "Mixed"
end
UIStyleSet = function(v)
    local look = (v == "Dark") and "dark" or "wow"
    for _, s in ipairs(STYLES) do
        local want = s[look]
        if want ~= nil and StyleAvailable(s) and s.get() ~= want then pcall(s.set, want) end
    end
end
UIStyleTip = function()
    local lines = { "Switches every addon that has its own skin to the Blizzard-like look (WoW) or its dark one. Baganator, Chattynator, Mastercraft, BetterBlizzFrames and OpenMap's minimap (square either way - WoW: the gold frame; Dark: the thin dark border) change after a reload; Details at once. Addons without a skin setting (Auctionator, Questie, OpenMap, Pawn, GearMatic, CheapUpgrades) already use Blizzard frames.", " " }
    for _, s in ipairs(STYLES) do
        if StyleAvailable(s) then
            local cur = s.get()
            local tag = (cur == s.wow) and "|cff88ff88WoW|r" or (s.dark ~= nil and cur == s.dark) and "|cffaaaaffDark|r" or ("|cffffcc00" .. tostring(cur) .. "|r")
            lines[#lines + 1] = (s.label or s.name) .. ": " .. tag
        end
    end
    return table.concat(lines, "\n")
end

local function GMBuiltinChosen()
    local gm = _G.GearMatic
    local key = type(gm) == "table" and gm.Compat and gm.Compat.CurrentCharKey and gm.Compat.CurrentCharKey()
    return key and gm.ScaleImport and gm.ScaleImport.IsBuiltinChosen and gm.ScaleImport.IsBuiltinChosen(key) or false
end

-- GearMatic treats nil as "on" (it only checks == false)
local function gmOn(key) local s = GM(); return s ~= nil and s[key] ~= false end
local function mcOn(key) local s = MC(); return s ~= nil and s[key] == true end
local function mcNotOff(key) local s = MC(); return s ~= nil and s[key] ~= false end
-- Mastercraft's Settings > Modules (2.1.2): settings.modules[key] = false turns a whole part off ("tip": every
-- tooltip line, "loot": the KEEP / VENDOR advice, "ah": the Scan prices button)
local function mcModule(key) return MC() ~= nil and MasterOptions_Shared.MastercraftModuleOn(key) end
local function mcModuleOn(key) local s = MC(); if s and type(s.modules) == "table" then s.modules[key] = nil end end
-- a Mastercraft tooltip line: its own switch and Tooltip extras both on
local function mcTip(key) return mcNotOff(key) and mcModule("tip") end
local function mcSetTip(key, on)
    local m = MC(); if not m then return end
    m[key] = on
    if on then mcModuleOn("tip") end
end

---------------------------------------------------------------------------
-- Bag icons that follow your other choices (MasterOptionsDB.iconsMatch = { arrow = true, junk = true }):
--   upgrade arrow = whose upgrade judgement is in use (Stat weights: GearMatic on Pawn -> Pawn's arrow,
--                   GearMatic's own weights -> GearMatic's chevron)
--   junk coin     = what your junk seller will sell (Vendor: GearMatic's rules, or Mastercraft's greys and
--                   the VENDOR advice it sells with the VendorSell patch)
---------------------------------------------------------------------------
local MATCH_ARROW, MATCH_JUNK = "Match stat weights", "Match junk seller"

local function MatchedArrow()
    local g = GM()
    if g and not (g.usePawnWeights and not GMBuiltinChosen()) then return "GearMatic" end
    if Loaded("Pawn") then return "Pawn" end
    return g and "GearMatic" or "Off"
end
local function MatchedJunk()
    if gmOn("autoSellJunk") and GM() then return "GearMatic" end
    if mcOn("autoJunk") then return "Mastercraft" end
    return "Greys only"
end
local function IconsMatch() return MasterOptionsDB and MasterOptionsDB.iconsMatch or {} end

-- brings the matched icons up to date; true when Baganator's settings changed (they apply after a reload)
local function SyncIcons()
    local m, p = IconsMatch(), BAG()
    if not p then return false end
    local changed = false
    if m.arrow then
        local want = MatchedArrow()
        if ArrowState(p) ~= want then ApplyUpgradeArrow(p, want); changed = true end
    else
        -- Pawn's arrow picked, Pawn not installed: Baganator only has Pawn's widget while Pawn is loaded, so no
        -- arrow would show - GearMatic's chevron stands in (remembered: Pawn's comes back with Pawn)
        local pawnOut = not Loaded("Pawn") and Loaded("GearMatic")
        if pawnOut and ArrowState(p) == "Pawn" then
            ApplyUpgradeArrow(p, "GearMatic")
            MasterOptionsDB.arrowStandIn = true
            changed = true
        elseif MasterOptionsDB.arrowStandIn and Loaded("Pawn") then
            if ArrowState(p) == "GearMatic" then ApplyUpgradeArrow(p, "Pawn"); changed = true end
            MasterOptionsDB.arrowStandIn = nil
        end
    end
    if m.junk then
        local before = p.junk_plugin
        ApplyJunk(p, MatchedJunk())
        if p.junk_plugin ~= before then changed = true end
    end
    return changed
end

local function SetOMT(key, slashArg, want)
    local db = OMT(); if not db then return end
    if (db[key] and true or false) ~= want then
        -- the slash command toggles and refreshes the pins; fall back to writing it
        if SlashCmdList and SlashCmdList.OPENMAPTWEAKS then
            SlashCmdList.OPENMAPTWEAKS(slashArg)
        end
        if (db[key] and true or false) ~= want then db[key] = want end
    end
end

-- for the files after this one
MO.AnnoyingOn = AnnoyingOn
MO.ApplyBagIconSize = ApplyBagIconSize
MO.ApplyJunk = ApplyJunk
MO.ApplyUpgradeArrow = ApplyUpgradeArrow
MO.ArrowState = ArrowState
MO.BAG = BAG
MO.BagIconSize = BagIconSize
MO.CORNERS = CORNERS
MO.CornerAdd = CornerAdd
MO.CornerHas = CornerHas
MO.CornerRemove = CornerRemove
MO.GMBuiltinChosen = GMBuiltinChosen
MO.ICON_SCALE = ICON_SCALE
MO.IconsMatch = IconsMatch
MO.JunkState = JunkState
MO.MATCH_ARROW = MATCH_ARROW
MO.MATCH_JUNK = MATCH_JUNK
MO.MatchedArrow = MatchedArrow
MO.MatchedJunk = MatchedJunk
MO.QuestieProfile = QuestieProfile
MO.SetAnnoying = SetAnnoying
MO.SetBagPlugin = SetBagPlugin
MO.SetOMT = SetOMT
MO.SyncIcons = SyncIcons
MO.TownGet = TownGet
MO.FlightGet, MO.FlightSet = FlightGet, FlightSet
MO.MapCoordsGet, MO.MapCoordsSet = MapCoordsGet, MapCoordsSet
MO.ArrowGet, MO.ArrowSet, MO.ArrowTextGet, MO.ArrowTextSet = ArrowGet, ArrowSet, ArrowTextGet, ArrowTextSet
MO.TargetsGet, MO.TargetsSet = TargetsGet, TargetsSet
MO.ButtonsGet, MO.ButtonsSet = ButtonsGet, ButtonsSet
MO.OMM = OMM
MO.TownSet = TownSet
MO.UIStyleGet = UIStyleGet
MO.UIStyleSet = UIStyleSet
MO.UIStyleTip = UIStyleTip
MO.gmOn = gmOn
MO.mcNotOff = mcNotOff
MO.mcOn = mcOn
MO.mcSetTip = mcSetTip
MO.mcTip = mcTip
MO.ChatLinesOn = ChatLinesOn
MO.SetChatLines = SetChatLines
