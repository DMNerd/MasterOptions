-- Master Options: what the options read and write in other addons - Annoying mode (posting in chat as you), the
-- bag icon size, Baganator's and Chattynator's profiles, the UI style, and the bag icons that follow other choices.

local _, MO = ...
-- from the files before this one
local GM, GMRefreshBagIcons, Loaded, MC, OMT = MO.GM, MO.GMRefreshBagIcons, MO.Loaded, MO.MC, MO.OMT

---------------------------------------------------------------------------
-- Annoying mode: every setting with which an addon posts in chat AS YOU, for other players to see - upgrades
-- shouted to the group or guild, public emotes, automatic whispers. Off turns them all off and remembers what
-- each was (per character: GearMatic's and Questie's settings can be per profile); on puts that back. Lines
-- only you see in your chat are not part of it. Found by what each addon sends (SendChatMessage / DoEmote),
-- not by its labels; what is sent only when you ask (Details' reports, typed commands) isn't here.
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

-- { id, addon, what it sends, table, key, value that is "off" }; "on" = anything else (nil = the addon's default, on)
local CHATTY = {}
for _, k in ipairs({ { "emote", "an emote with each upgrade you equip" },
                     { "vendorEmote", "a public emote with what auto-sell sold and repairs cost" },
                     { "sendToParty", "your upgrades in /party" }, { "sendToRaid", "your upgrades in /raid" },
                     { "sendToGuild", "your upgrades in /guild" }, { "sendToBattleGrounds", "your upgrades in battleground chat" } }) do
    CHATTY[#CHATTY + 1] = { id = "gm:" .. k[1], addon = "GearMatic", what = k[2], tbl = GMSocial, key = k[1], off = false }
end
CHATTY[#CHATTY + 1] = { id = "questie:announce", addon = "Questie", what = "quest progress in /party or /raid",
                        tbl = QuestieProfile, key = "questAnnounceChannel", off = "disabled" }
CHATTY[#CHATTY + 1] = { id = "mc:whoReply", addon = "Mastercraft", what = "whispers answering !who in guild and group chat",
                        tbl = MC, key = "whoReply", off = false }

local function ChattyOn(c, t)
    local v = t[c.key]
    if c.off == "disabled" then return v ~= nil and v ~= "disabled" end -- (Questie's default is "disabled")
    return v ~= false
end

local function AnnoyingSaved()
    local first, last = UnitName("player")
    local char = (first or "?") .. ((last and last ~= "") and (" " .. last) or "") .. "-" .. (GetRealmName() or "")
    MasterOptionsDB.annoyingSaved = type(MasterOptionsDB.annoyingSaved) == "table" and MasterOptionsDB.annoyingSaved or {}
    MasterOptionsDB.annoyingSaved[char] = MasterOptionsDB.annoyingSaved[char] or {}
    return MasterOptionsDB.annoyingSaved[char]
end

-- on while any of them posts
local function AnnoyingOn()
    for _, c in ipairs(CHATTY) do
        local t = Loaded(c.addon) and c.tbl()
        if t and ChattyOn(c, t) then return true end
    end
    return false
end

local function SetAnnoying(on)
    local saved = AnnoyingSaved()
    for _, c in ipairs(CHATTY) do
        local t = Loaded(c.addon) and c.tbl()
        if t then
            if not on then
                -- every one remembered, an already-off one too (on must not turn on what you had off); a second
                -- "off" keeps what the first remembered. (Wrapped: nil, the addon's default, is remembered too.)
                if saved[c.id] == nil then saved[c.id] = { v = t[c.key] } end
                t[c.key] = c.off
            elseif saved[c.id] then
                t[c.key] = saved[c.id].v
                saved[c.id] = nil
            elseif c.off == false then
                t[c.key] = true -- (nothing remembered: the addon's default, on)
            end
        end
    end
end

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
    elseif v == "Mastercraft" and Loaded("MasterOptions_Mastercraft_VendorSell") then SetBagPlugin(p, "junk", "mastercraft")
    else SetBagPlugin(p, "junk", "poor_quality") end -- (Mastercraft without the VendorSell patch sells greys only)
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
    local ql = _G.QuestieLoader
    if not (type(ql) == "table" and ql.ImportModule) then return end
    local ok, menu = pcall(ql.ImportModule, ql, "QuestieMenu")
    if ok and type(menu) == "table" and menu.OnLogin then pcall(menu.OnLogin, menu, true) end
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
local function TownGet()
    local t, q = TownTracking(), QuestieTown()
    if not q then return "Questie" end
    local o = OpenMapTown() or {}
    local game, questie = false, false
    for _, k in ipairs(TOWN) do
        local g, qq = t[k] and t[k].active, q[k] == true
        if g and qq then return "Both (conflict)" end
        if qq and TOWN_OPENMAP[k] and o[TOWN_OPENMAP[k]] == true then return "Both (conflict)" end
        game, questie = game or g, questie or qq
    end
    return (game and not questie) and "Game's tracking" or "Questie"
end
-- the kinds you have on (in either) move to the one picked; the other turns them off
local function TownSet(v)
    local t, q = TownTracking(), QuestieTown()
    if not q then return end
    local o, omMod = OpenMapTown()
    local setTracking = C_Minimap and C_Minimap.SetTracking
    local omChanged = false
    for _, k in ipairs(TOWN) do
        local g = t[k]
        local ok = o and TOWN_OPENMAP[k]
        local on = (g and g.active) or q[k] == true or (ok and o[ok] == true)
        if v == "Questie" then
            if on then q[k] = true end
            if g and g.active and setTracking then pcall(setTracking, g.index, false) end
            -- (Questie's own world map icons: OpenMap's of the same kind off, else each shows twice there)
            if ok and o[ok] == true then o[ok] = false; omChanged = true end
        elseif g then -- (a kind the game's list doesn't have stays with Questie)
            if on and not g.active and setTracking then pcall(setTracking, g.index, true) end
            if q[k] then q[k] = false end
        end
    end
    if omChanged and omMod and omMod.RefreshTownsfolk then pcall(omMod.RefreshTownsfolk, omMod) end
    QuestieTownRefresh()
end

-- OpenMap_MiniMap: the profile in use - this character's own (OpenMap keys it on the first name), or the shared one
local function OMM()
    return Loaded("OpenMap_MiniMap") and MasterOptions_Shared.OpenMapMiniMapProfile() or nil
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
MO.TownSet = TownSet
MO.UIStyleGet = UIStyleGet
MO.UIStyleSet = UIStyleSet
MO.UIStyleTip = UIStyleTip
MO.gmOn = gmOn
MO.mcNotOff = mcNotOff
MO.mcOn = mcOn
MO.mcSetTip = mcSetTip
MO.mcTip = mcTip
