-- Master Options: the options - every row of the window (and of the game's Options page), with its get / set.

local _, MO = ...
-- from the files before this one
local AUC, AnnoyingOn, ApplyBagIconSize, ApplyJunk, ApplyUpgradeArrow, ArrowState, BAG, BagIconSize = MO.AUC, MO.AnnoyingOn, MO.ApplyBagIconSize, MO.ApplyJunk, MO.ApplyUpgradeArrow, MO.ArrowState, MO.BAG, MO.BagIconSize
local CORNERS, CU, ChatLinesOn, CornerAdd, CornerHas, CornerRemove, FollowSpec, FollowSpecOn = MO.CORNERS, MO.CU, MO.ChatLinesOn, MO.CornerAdd, MO.CornerHas, MO.CornerRemove, MO.FollowSpec, MO.FollowSpecOn
local GM, GMBuiltinChosen, GMRefreshBagIcons, ICON_SCALE, IconsMatch, Judge, JunkState, Loaded = MO.GM, MO.GMBuiltinChosen, MO.GMRefreshBagIcons, MO.ICON_SCALE, MO.IconsMatch, MO.Judge, MO.JunkState, MO.Loaded
local MATCH_ARROW, MATCH_JUNK, MC, MatchedArrow, MatchedJunk, OMT, PAWN, PawnElseGearMatic = MO.MATCH_ARROW, MO.MATCH_JUNK, MO.MC, MO.MatchedArrow, MO.MatchedJunk, MO.OMT, MO.PAWN, MO.PawnElseGearMatic
local PawnShows, QuestieProfile, RefreshGearMatic, SPK, SYN, SetAnnoying, SetChatLines, SetOMT = MO.PawnShows, MO.QuestieProfile, MO.RefreshGearMatic, MO.SPK, MO.SYN, MO.SetAnnoying, MO.SetChatLines, MO.SetOMT
local SetPawnScales, SyncPawnHidden, TownGet, TownSet, UIStyleGet, UIStyleSet, UIStyleTip, gmOn = MO.SetPawnScales, MO.SyncPawnHidden, MO.TownGet, MO.TownSet, MO.UIStyleGet, MO.UIStyleSet, MO.UIStyleTip, MO.gmOn
local mcNotOff, mcOn, mcSetTip, mcTip = MO.mcNotOff, MO.mcOn, MO.mcSetTip, MO.mcTip
local OMM = MO.OMM
local GATHER_PX = { Small = { 12, 10 }, Medium = { 14, 12 }, Large = { 16, 14 } } -- (world map, minimap: pixels)

---------------------------------------------------------------------------
-- The options. "choice" rows: who handles it. "toggle" rows: on/off.
---------------------------------------------------------------------------
-- A "who shows this" row over any number of addons. sources: { name, get(), set(on) }.
-- Choosing one turns the others off; two or more on shows as a conflict.
-- Where an item comes from, in tooltips (the row "Where an item drops"): each addon's own line
local function DJDB()
    local db = Loaded("ForeverDungeonJournal") and _G.ForeverDungeonJournalDB
    return type(db) == "table" and db or nil
end
local DROP_SOURCES = {
    { name = "GearMatic", loaded = function() return GM() ~= nil end,
      get = function() return gmOn("dropRateTooltip") end,
      set = function(on) local g = GM(); if g then g.dropRateTooltip = on end end },
    { name = "Dungeon Journal", loaded = function() return Loaded("ForeverDungeonJournal") end,
      get = function() local db = DJDB(); return not (db and db.itemSourceStrip == false) end,
      set = function(on)
          local db = DJDB()
          if db then if on then db.itemSourceStrip = nil else db.itemSourceStrip = false end end
      end },
    { name = "Mastercraft", loaded = function() return MC() ~= nil end,
      get = function() return mcTip("tipSources") and true or false end,
      set = function(on) mcSetTip("tipSources", on) end },
}

local function Multi(label, rec, since, tip, sources, offLabel)
    local choices = {}
    for _, src in ipairs(sources) do choices[#choices + 1] = src[1] end
    choices[#choices + 1] = offLabel
    return {
        kind = "choice", label = label, rec = rec, since = since, tip = tip, choices = choices, off = offLabel,
        get = function()
            local on = {}
            for _, src in ipairs(sources) do
                if Loaded(src[1]) and src[2]() then on[#on + 1] = src[1] end
            end
            if #on > 1 then return "Both (conflict)" end
            return on[1] or offLabel
        end,
        set = function(v)
            for _, src in ipairs(sources) do
                if Loaded(src[1]) then pcall(src[3], v == src[1]) end
            end
        end,
    }
end

-- A row picking GearMatic or Mastercraft for a job both can do, each with one on/off setting (gmKey in GearMatic's
-- profile, on unless false; mcKey in Mastercraft's settings, on only when true): both on shows the conflict.
local function GearMaticOrMastercraftRow(opt, gmKey, mcKey)
    opt.get = function()
        local g, m = gmOn(gmKey) and GM(), mcOn(mcKey)
        if g and m then return "Both (conflict)" end
        return g and "GearMatic" or m and "Mastercraft" or "Off"
    end
    opt.set = function(v)
        local g, m = GM(), MC()
        if g then g[gmKey] = (v == "GearMatic") end
        if m then m[mcKey] = (v == "Mastercraft") end
    end
    return opt
end

-- A Baganator icon row with a "Match ..." choice that follows another setting (MasterOptionsDB.iconsMatch[key]):
-- shows the match choice while it's on, else what Baganator has (state(profile)); picking writes Baganator's
-- profile through apply(profile, choice), the matched choice worked out by matched().
local function MatchedIconRow(opt, key, matchLabel, none, state, apply, matched)
    opt.get = function()
        local p = BAG(); if not p then return none end
        if IconsMatch()[key] then return matchLabel end
        return state(p)
    end
    opt.set = function(v)
        local p = BAG(); if not p then return end
        MasterOptionsDB.iconsMatch = MasterOptionsDB.iconsMatch or {}
        MasterOptionsDB.iconsMatch[key] = (v == matchLabel) or nil
        apply(p, v == matchLabel and matched() or v)
    end
    return opt
end

local OPTIONS = {
    { header = "This account" },
    {
        kind = "toggle", label = "Same choices on every character", rec = true, since = 8,
        tip = "Most settings here are saved for your whole account already. The ones marked (per char) are saved per character (or per profile) by their addon. With this on, Master Options keeps your choice for those once, for the account, and applies it on every character at login - so a new character starts with your choices, not the recommended ones. Turning it on takes this character's current choices.",
        get = function() return MasterOptionsDB and MasterOptionsDB.syncChars and true or false end,
        set = function(v)
            MasterOptionsDB.syncChars = v or nil
            -- take this character's choices - after the rest of a login's setup, or at once from a click
            MasterOptionsDB.seedPending = v or nil
        end,
    },

    { header = "Vendor and bank" },
    GearMaticOrMastercraftRow({
        kind = "choice", label = "Sell junk automatically", rec = "GearMatic",
        tip = "GearMatic and Mastercraft both sell junk at every vendor. When both are on they sell the same items and the game can say \"item busy\".",
        choices = { "GearMatic", "Mastercraft", "Off" },
    }, "autoSellJunk", "autoJunk"),
    {
        kind = "choice", label = "Also sell what Mastercraft says to VENDOR", rec = "Goods", since = 17,
        needs = "MasterOptions_Mastercraft_VendorSell", choices = { "Goods", "Goods and gear", "Off" },
        tip = "At a vendor, items whose Mastercraft advice is VENDOR are sold by the addon picked above (GearMatic: with its \"always sell\" list, for that visit only; Mastercraft: sold by the patch, as Mastercraft sells greys). Goods: materials, potions, food and other non-gear. Goods and gear: also gear, but never Pawn or GearMatic upgrades, set or loadout pieces. Never sold: what Mastercraft says to KEEP (or keep some of for a guide), AUCTION or DISENCHANT, and GearMatic's never-sell list. Nothing is sold when junk selling is Off. Needs the MasterOptions_Mastercraft_VendorSell patch.",
        get = function()
            local d = _G.MasterOptions_MastercraftVendorDB
            local m = type(d) == "table" and d.mode or "goods"
            return (m == "all" and "Goods and gear") or (m == "off" and "Off") or "Goods"
        end,
        set = function(v)
            MasterOptions_MastercraftVendorDB = MasterOptions_MastercraftVendorDB or {}
            MasterOptions_MastercraftVendorDB.mode = (v == "Goods and gear" and "all") or (v == "Off" and "off") or "goods"
        end,
    },
    {
        kind = "choice", label = "At the bank: guide materials go in", rec = "Guide mats", since = 18,
        needs = "MasterOptions_Mastercraft_BankMats", choices = { "Guide mats", "Guide and tracked mats", "Off" },
        tip = "When you open the bank, what Mastercraft keeps for your profession guides (\"... guide still needs\", \"... guide uses all you have\") goes into it, so you collect it there - Mastercraft's Grab mats brings it back to craft. What Mastercraft says to VENDOR or AUCTION stays in your bags to be sold, and so do tools, fishing gear, food, items you keep some of for a guide, and Mastercraft's \"Never in the bank\" list. Guide and tracked mats: your Mastercraft item tracker's items too. Needs the MasterOptions_Mastercraft_BankMats patch.",
        get = function()
            local d = _G.MasterOptions_MastercraftBankDB
            local m = type(d) == "table" and d.mode or "guide"
            return (m == "tracked" and "Guide and tracked mats") or (m == "off" and "Off") or "Guide mats"
        end,
        set = function(v)
            MasterOptions_MastercraftBankDB = MasterOptions_MastercraftBankDB or {}
            MasterOptions_MastercraftBankDB.mode = (v == "Guide and tracked mats" and "tracked") or (v == "Off" and "off") or "guide"
        end,
    },
    GearMaticOrMastercraftRow({
        kind = "choice", label = "Repair automatically", rec = "Mastercraft",
        tip = "Mastercraft repairs from the guild bank first when your rank allows it. GearMatic uses your own gold.",
        choices = { "Mastercraft", "GearMatic", "Off" },
    }, "autoRepair", "autoRepair"),
    {
        kind = "toggle", label = "Mastercraft: repair from guild bank first", rec = true,
        needs = "Mastercraft",
        get = function() return mcNotOff("repairGuild") end,
        set = function(v) local m = MC(); if m then m.repairGuild = v end end,
    },

    { header = "Gathering nodes (ore and herbs)" },
    {
        kind = "choice", label = "World map pins from", rec = "OpenMap_Tweaks",
        tip = "Mastercraft and OpenMap_Tweaks both draw spawn points. Pick one to avoid two pins per node.",
        choices = { "Mastercraft", "OpenMap_Tweaks", "Off" },
        get = function()
            local m = MC() and mcNotOff("nodesWorldMap")
            local o = OMT() and OMT().gather
            if m and o then return "Both (conflict)" end
            return m and "Mastercraft" or o and "OpenMap_Tweaks" or "Off"
        end,
        set = function(v)
            local m = MC()
            if m then m.nodesWorldMap = (v == "Mastercraft") end
            SetOMT("gather", "gather", v == "OpenMap_Tweaks")
        end,
    },
    -- (OpenMap_MiniMap records the spots you gather from too, and draws them: a third pin on the same herb)
    Multi("Minimap pins from", "OpenMap_Tweaks", 32,
        "Mastercraft, OpenMap_Tweaks and OpenMap_MiniMap (its gathered spots: where you've looted a herb, ore or chest) can each put a pin on the minimap for the same node. Pick one. OpenMap_Tweaks can only show minimap pins while its world map pins are on.", {
        { "Mastercraft", function() return MC() and mcNotOff("nodesMinimap") end,
          function(on) local m = MC(); if m then m.nodesMinimap = on end end },
        { "OpenMap_Tweaks", function() return OMT() and OMT().gather and OMT().gatherMinimap end,
          function(on)
              if on then SetOMT("gather", "gather", true) end
              SetOMT("gatherMinimap", "gather minimap", on)
          end },
        { "OpenMap_MiniMap", function() local p = OMM(); return p and p.gatherPins ~= false end,
          function(on) local p = OMM(); if p then p.gatherPins = on end end },
    }, "Off"),

    -- (one size for gathering pins, whichever addon draws them: Mastercraft's are 16 / 14 pixels x its size
    -- settings, OpenMap_Tweaks' its own pixel sizes - by default 16 and 14 against 12 and 8)
    {
        kind = "choice", label = "Gathering pin size", rec = "Medium",
        needs_any = { "Mastercraft", "OpenMap_Tweaks" }, choices = { "Small", "Medium", "Large" },
        tip = "One size for herb and ore pins on the world map and the minimap, whether Mastercraft or OpenMap_Tweaks draws them (by default Mastercraft's were bigger: 16 / 14 pixels against 12 / 8). Small: 12 / 10. Medium: 14 / 12. Large: 16 / 14.",
        get = function()
            local m, o = MC(), OMT()
            local function Name(world)
                for name, px in pairs(GATHER_PX) do if math.abs(px[1] - world) < 0.6 then return name end end
                return "Mixed"
            end
            local a = m and Name((m.nodesMapSize or 1) * 16)
            local b = o and Name(o.gatherIconSize or 12)
            if a and b and a ~= b then return "Mixed" end
            return a or b or "Medium"
        end,
        set = function(v)
            local px = GATHER_PX[v]; if not px then return end
            local m = MC()
            if m then m.nodesMapSize, m.nodesMiniSize = px[1] / 16, px[2] / 14 end
            local o = OMT()
            -- (written straight in: its /omt gather size prints its whole status each time; its minimap pins read
            -- the size as they draw, its world map pins at the map's next redraw)
            if o then o.gatherIconSize, o.gatherMinimapSize = px[1], px[2] end
        end,
    },
    {
        kind = "choice", label = "Which nodes show", rec = "Skill-ups only", since = 2,
        tip = "Mastercraft's node rule. With the MasterOptions_OpenMapTweaks_Mastercraft patch it also filters OpenMap_Tweaks' pins.",
        needs = "Mastercraft",
        choices = { "Skill-ups only", "Gatherable", "All" },
        get = function()
            local f = (MC() or {}).nodesFilter or "skillups"
            return f == "all" and "All" or f == "gatherable" and "Gatherable" or "Skill-ups only"
        end,
        set = function(v)
            local m = MC(); if not m then return end
            m.nodesFilter = v == "All" and "all" or v == "Gatherable" and "gatherable" or "skillups"
        end,
    },
    {
        kind = "choice", label = "When nodes show", rec = "While tracking", since = 2,
        tip = "While tracking: with Find Minerals / Find Herbs on (or while farming), not in towns, instances or combat. While farming: only after Mastercraft's Start farming (/mc farm). Never: no nodes at all.",
        needs = "Mastercraft",
        choices = { "While tracking", "While farming", "Always", "Never" },
        get = function()
            local w = (MC() or {}).nodesWhen or "tracking"
            return w == "always" and "Always" or w == "never" and "Never" or w == "farming" and "While farming" or "While tracking"
        end,
        set = function(v)
            local m = MC(); if not m then return end
            m.nodesWhen = v == "Always" and "always" or v == "Never" and "never" or v == "While farming" and "farming" or "tracking"
        end,
    },

    { header = "Maps" },
    {
        -- OpenMap and Dungeon Journal both show a map inside a dungeon; MasterOptions_DungeonJournal_OpenMap
        -- (which replaces OpenMap_NoDungeonMap) turns OpenMap's off and opens Dungeon Journal's from OpenMap's
        -- entrance icons instead. Read as that patch loads, so a change needs a reload.
        kind = "choice", label = "Map inside dungeons", rec = "Dungeon Journal", since = 11, reload = true,
        needs = { "OpenMap", "ForeverDungeonJournal", "MasterOptions_DungeonJournal_OpenMap" },
        choices = { "Dungeon Journal", "OpenMap" },
        tip = "OpenMap and Dungeon Journal both put a map of the dungeon on the world map when you're inside one. Dungeon Journal: OpenMap's own \"Dungeon maps inside dungeons\" is off (the rest of OpenMap's dungeon features stay). OpenMap: its own dungeon map. What an entrance click opens: the next row.",
        get = function() return (MasterOptionsDB and MasterOptionsDB.dungeonMap == "openmap") and "OpenMap" or "Dungeon Journal" end,
        set = function(v) MasterOptionsDB.dungeonMap = (v == "OpenMap") and "openmap" or nil end,
    },
    {
        -- OpenMap has its own "Clicking a dungeon entrance opens" (its map / Dungeon Journal's page:
        -- worldmap.entranceClick); MasterOptions_DungeonJournal_OpenMap adds Dungeon Journal's map of the dungeon.
        -- One choice for the three, written to OpenMap's option too. (No `since`: recommended for a new
        -- character only - an update keeps what your entrances open now.)
        kind = "choice", label = "Dungeon entrance click", rec = "Dungeon Journal map", reload = true,
        needs = { "OpenMap", "ForeverDungeonJournal", "MasterOptions_DungeonJournal_OpenMap" },
        choices = { "Dungeon Journal map", "Dungeon Journal page", "OpenMap's map" },
        tip = "What clicking a dungeon entrance on OpenMap's world map opens. Dungeon Journal map: Dungeon Journal's map of that dungeon on the world map (a list when several share the entrance; right-click or Esc back). Dungeon Journal page: its journal page (OpenMap's own option). OpenMap's map: OpenMap's map of the dungeon.",
        get = function()
            local v = MasterOptionsDB and MasterOptionsDB.entranceClick
            if v == nil then v = (MasterOptionsDB and MasterOptionsDB.dungeonMap == "openmap") and "openmap" or "djmap" end
            return (v == "djpage" and "Dungeon Journal page") or (v == "openmap" and "OpenMap's map") or "Dungeon Journal map"
        end,
        set = function(v)
            MasterOptionsDB.entranceClick = (v == "Dungeon Journal page" and "djpage") or (v == "OpenMap's map" and "openmap") or "djmap"
        end,
    },
    {
        kind = "choice", label = "Town NPC icons", rec = "Questie", since = 21, scope = "character",
        needs = "Questie", choices = { "Questie", "Game's tracking", "OpenMap + game's tracking" },
        tip = "Auctioneer, banker, battlemaster, innkeeper, mailbox, repair and stable master icons (flight masters: their own row with OpenMap): the game's minimap tracking, Questie's townsfolk menu and OpenMap's Townsfolk menu can all draw them, so a kind ticked in two shows twice. Questie: on the world map and the minimap (pick the kinds in Questie's menu). Game's tracking: on the minimap only. OpenMap + game's tracking: OpenMap's on the world map, the game's on the minimap (battlemasters: the game's only). Switching moves the kinds you have on to the one you pick; trainers and the rest stay as they are.",
        get = TownGet, set = TownSet,
    },
    {
        kind = "choice", label = "Flight masters", rec = "OpenMap", since = 32, scope = "character",
        needs = { "OpenMap", "Questie" }, choices = { "OpenMap", "Questie" },
        tip = "OpenMap (its flight masters, with the routes you know; OpenMap_MiniMap's on the minimap) and Questie (its townsfolk Flight Master) both draw flight masters, so each showed twice. OpenMap: Questie's off. Questie: OpenMap's off - but OpenMap_Tweaks turns OpenMap's back on whenever the map opens, so with OpenMap_Tweaks installed only OpenMap works. The game's minimap tracking of flight masters goes off either way.",
        get = MO.FlightGet, set = MO.FlightSet,
    },
    {
        kind = "choice", label = "World map coordinates", rec = "OpenMap", since = 32, reload = true,
        needs = { "OpenMap", "Questie" }, choices = { "OpenMap", "Questie", "Off" }, off = "Off",
        tip = "OpenMap's coordinates bar and Questie's (in the map's title) both show your and the cursor's coordinates. Questie's cursor figure is for the zone the map shows underneath, which on OpenMap's stitched map can differ from where the cursor is. OpenMap: its bar. Questie: Questie's. Takes a reload.",
        get = MO.MapCoordsGet, set = MO.MapCoordsSet,
    },

    { header = "Routes and waypoints" },
    {
        kind = "choice", label = "Navigation arrow", rec = "Shortest Path's arrow", since = 32,
        needs = "ShortestPathForever", choices = { "Shortest Path's arrow", "Game's marker only" },
        tip = "While ShortestPathForever leads you somewhere, it shows its own arrow on screen and the game's waypoint marker. Shortest Path's arrow: both. Game's marker only: its arrow hidden, the game's marker leads (one pointer on screen).",
        get = MO.ArrowGet, set = MO.ArrowSet,
    },
    {
        kind = "choice", label = "Arrow text", rec = "Both", since = 32,
        needs = "ShortestPathForever", choices = { "Distance", "Time", "Both" },
        tip = "What ShortestPathForever's arrow says under it: the distance left, the time left, or both.",
        get = MO.ArrowTextGet, set = MO.ArrowTextSet,
    },
    {
        -- ShortestPathForever's own "Move the arrow" (its Settings > Interface > Direction arrow): registered with the
        -- game's Settings as ShortestPathForever_arrowMove - read and switched through it, nothing of ours saved. No
        -- recommendation: a switch you flip while placing it, not a setting.
        kind = "toggle", label = "Move Shortest Path's arrow",
        needs = "ShortestPathForever",
        tip = "On: Shortest Path's direction arrow shows over a dark box (with or without a journey) to drag anywhere; Shift-drag or the arrow keys nudge it, right-click puts it back in its own place. Off: locked again and click-through, where you left it. The same switch as Shortest Path's own \"Move the arrow\".",
        get = function()
            local s = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_arrowMove")
            return s and s.GetValue and s:GetValue() == true or false
        end,
        set = function(v)
            local s = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_arrowMove")
            if s and s.SetValue then s:SetValue(v and true or false) end
        end,
    },
    {
        kind = "choice", label = "Quest and recipe waypoints", rec = "Shortest Path journey", since = 32,
        needs = "ShortestPathForever", choices = { "Shortest Path journey", "Game's waypoint" },
        tip = "Questie (its tracker's Set TomTom target), Mastercraft (Waypoint) and WhatsTraining send their waypoints to TomTom. Without TomTom installed, ShortestPathForever stands in for it. Shortest Path journey: each becomes a journey with a route (one at a time: a new one replaces the last). Game's waypoint: the game's own map pin and marker, no route. The same as Shortest Path's own \"Let guides set TomTom waypoints\"; takes effect at once.",
        get = MO.TargetsGet, set = MO.TargetsSet,
    },

    { header = "Nameplates" },
    {
        kind = "choice", label = "Quest icons on nameplates", rec = "BetterBlizzPlates", since = 13, reload = true,
        choices = { "BetterBlizzPlates", "Questie", "Off" },
        tip = "Questie and BetterBlizzPlates can both mark the mobs your quests need with an icon on their nameplate, so a mob gets two. BetterBlizzPlates reads the game's own quest data (Forever's own quests too, and in dungeons); Questie uses its quest database (and has no nameplate icons in Forever's dungeons).",
        get = function()
            local q = QuestieProfile()
            local b = Loaded("BetterBlizzPlates") and type(_G.BetterBlizzPlatesDB) == "table" and _G.BetterBlizzPlatesDB
            local qOn = q and q.nameplateEnabled ~= false
            local bOn = b and b.questIndicator == true
            if qOn and bOn then return "Both (conflict)" end
            return bOn and "BetterBlizzPlates" or qOn and "Questie" or "Off"
        end,
        set = function(v)
            local q = QuestieProfile()
            if q then q.nameplateEnabled = (v == "Questie") end
            local b = Loaded("BetterBlizzPlates") and type(_G.BetterBlizzPlatesDB) == "table" and _G.BetterBlizzPlatesDB
            if b then b.questIndicator = (v == "BetterBlizzPlates") end
        end,
    },

    {
        kind = "choice", label = "Quest icon on your target's frame", rec = "BetterBlizzFrames", since = 15, reload = true,
        choices = { "BetterBlizzFrames", "Questie", "Off" },
        tip = "BetterBlizzFrames and Questie can both put a quest icon on the target (and focus) frame of a mob your quests need, so it gets two.",
        get = function()
            local q = QuestieProfile()
            local b = Loaded("BetterBlizzFrames") and type(_G.BetterBlizzFramesDB) == "table" and _G.BetterBlizzFramesDB
            local qOn = q and q.nameplateEnabled ~= false and q.nameplateTargetFrameEnabled ~= false
            local bOn = b and b.questIndicator == true
            if qOn and bOn then return "Both (conflict)" end
            return bOn and "BetterBlizzFrames" or qOn and "Questie" or "Off"
        end,
        set = function(v)
            local q = QuestieProfile()
            if q then q.nameplateTargetFrameEnabled = (v == "Questie") end
            local b = Loaded("BetterBlizzFrames") and type(_G.BetterBlizzFramesDB) == "table" and _G.BetterBlizzFramesDB
            if b then b.questIndicator = (v == "BetterBlizzFrames") end
        end,
    },

    { header = "Tooltips" },
    Multi("Auction price", "Auctionator", 4,
        "Auctionator, Mastercraft and CheapUpgrades can each add an auction house price line.", {
        { "Auctionator",
          function() return AUC("auction_tooltips") end,
          function(on)
              AUC("auction_tooltips", on)
              -- Mastercraft can hide Auctionator's lines at every login: don't let it undo this choice
              local m = MC(); if on and m then m.hideAuctionatorTips = false end
          end },
        { "Mastercraft",
          function() return mcTip("tipPrice") end,
          function(on) mcSetTip("tipPrice", on) end },
        { "CheapUpgrades",
          function() local c = CU(); return c and c.tooltip ~= false and c.tooltipPrice ~= false end,
          -- (its master switch "Item tooltips" too: off, the line would never show)
          function(on) local c = CU(); if c then c.tooltipPrice = on; if on then c.tooltip = true end end end },
    }, "Off"),
    Multi("Vendor sell price", "Game's own line", 4,
        "The game already shows \"Sell Price\" on every item. Auctionator and Mastercraft can add a second vendor line.", {
        { "Auctionator",
          function() return AUC("vendor_tooltips") end,
          function(on)
              AUC("vendor_tooltips", on)
              local m = MC(); if on and m then m.hideAuctionatorTips = false end
          end },
        { "Mastercraft",
          function() return mcTip("tipVendor") end,
          function(on) mcSetTip("tipVendor", on) end },
    }, "Game's own line"),
    Multi("Upgrade % per spec", PawnElseGearMatic, 4,
        "Pawn, GearMatic and CheapUpgrades can each list an upgrade size for every spec. With \"Stat weights\" below set to Pawn they all value items with Pawn's scales; Pawn's own line is the most compact and matches Baganator's bag arrows.", {
        { "Pawn",
          function() local pw = PAWN(); return pw and pw.ShowUpgradesOnTooltips and true or false end,
          function(on) local pw = PAWN(); if pw then pw.ShowUpgradesOnTooltips = on end end },
        { "GearMatic",
          -- (its item tooltip line: autoDetectTooltip, shown while autoDetect is on too - ItemTooltipHook.lua.
          -- showInTooltip, used here before 2.3.2, is only its summary on a character's mouseover tooltip)
          function() local g = GM(); return g ~= nil and g.autoDetect ~= false and g.autoDetectTooltip ~= false end,
          function(on) local g = GM(); if g then g.autoDetectTooltip = on; if on then g.autoDetect = true end end end },
        { "CheapUpgrades",
          function() local c = CU(); return c and c.tooltip ~= false and c.tooltipUpgrades ~= false end,
          function(on) local c = CU(); if c then c.tooltipUpgrades = on; if on then c.tooltip = true end end end },
    }, "Off"),
    {
        -- Three addons can say where an item comes from, each with its own reach: GearMatic (ItemTooltipHook.lua:
        -- profile.dropRateTooltip, WoW Forever: the creature or chest and the chance), Dungeon Journal
        -- (ItemSource.lua: ForeverDungeonJournalDB.itemSourceStrip, on unless false: the boss, or the quest), and
        -- Mastercraft (Tooltip.lua: settings.tipSources, materials: vendors, drops, gathering). Not a conflict -
        -- "All" is a choice of its own, and two on shows as "A + B".
        kind = "choice", label = "Where an item drops (tooltip)", rec = "GearMatic", since = 29,
        needs_any = { "GearMatic", "ForeverDungeonJournal", "Mastercraft" },
        choices = { "GearMatic", "Dungeon Journal", "Mastercraft", "All", "Off" }, off = "Off",
        tip = "GearMatic, Dungeon Journal and Mastercraft can each add lines to item tooltips saying where an item comes from. GearMatic: the creature or chest and how often it drops (from what GearMatic players looted; a Classic estimate until enough is known). Dungeon Journal: the boss, or the quest it's a reward of. Mastercraft: for materials, the vendors, drops and gathering that give them. All: every line.",
        get = function()
            local on, n = {}, 0
            for _, src in ipairs(DROP_SOURCES) do
                if src.loaded() then n = n + 1; if src.get() then on[#on + 1] = src.name end end
            end
            if #on == 0 then return "Off" end
            if #on == n and n > 1 then return "All" end
            return table.concat(on, " + ")
        end,
        set = function(v)
            for _, src in ipairs(DROP_SOURCES) do
                if src.loaded() then src.set(v == src.name or v == "All") end
            end
        end,
    },
    {
        kind = "choice", label = "Counts on your characters", since = 3, rec = "Syndicator",
        tip = "Syndicator (used by Baganator) and Mastercraft both list how many each of your characters has.",
        choices = { "Syndicator", "Mastercraft", "Off" },
        get = function()
            local sy = SYN() and SYN().show_inventory_tooltips ~= false
            local m = mcTip("tipOwnersList")
            if sy and m then return "Both (conflict)" end
            return sy and "Syndicator" or m and "Mastercraft" or "Off"
        end,
        set = function(v)
            local sy = SYN(); if sy then sy.show_inventory_tooltips = (v == "Syndicator") end
            mcSetTip("tipOwnersList", v == "Mastercraft")
        end,
    },

    { header = "Stat weights" },
    {
        -- (since 16: applied again - before, it switched with /pff, which left a stock scale with no spec,
        -- "Rogue: Off Hand", shown next to Pawn Forever's)
        kind = "choice", label = "Pawn scales", rec = "Pawn Forever", since = 16, scope = "character",
        needs = { "Pawn", "Pawn_Forever" }, choices = { "Pawn Forever", "Pawn stock" },
        tip = "Which Pawn scales this character shows: Pawn Forever's (weights for WoW Forever, leveling and level 60) or Pawn's stock Classic ones. Pawn keeps this per character. GearMatic, CheapUpgrades and the quest reward pick follow whatever Pawn shows.",
        get = function()
            local pw = PAWN(); if not (pw and type(pw.Scales) == "table") then return "Pawn Forever" end
            local _, _, classID = UnitClass("player")
            local forever, stock = false, false
            for _, s in pairs(pw.Scales) do
                if type(s) == "table" and s.ClassID == classID and PawnShows(s) then
                    if s.Provider == "PawnForever" then forever = true elseif s.Provider == "Classic" then stock = true end
                end
            end
            if forever and stock then return "Both (conflict)" end
            return stock and "Pawn stock" or "Pawn Forever"
        end,
        set = function(v) SetPawnScales(v ~= "Pawn stock"); pcall(FollowSpec) end,
    },
    {
        kind = "choice", label = "Spec for Pawn and CheapUpgrades", rec = "Follow GearMatic", since = 26,
        needs = "GearMatic", choices = { "Follow GearMatic", "Your own choice" },
        tip = "GearMatic works out your spec from your talents (and its own Cat / Bear choice for Feral). Follow GearMatic: Pawn shows only that spec's scale (of the set you use - Pawn Forever's or stock; scales for no particular spec stay as they are), and CheapUpgrades' spec and ticked specs are that spec - so upgrade arrows, tooltips, quest rewards and the auction house all judge by one spec, and follow a talent change. Your own choice: Pawn shows the scales you tick (upgrades for any of them, off-spec too), CheapUpgrades the specs you pick. Either way, selling and deleting (vendor selling, GearMatic's sell guard, DeleteCheapestItem) keep Pawn's upgrades and best items for every spec of the set you use - following, the other specs are counted for that check only.",
        get = function() return FollowSpecOn() and "Follow GearMatic" or "Your own choice" end,
        set = function(v)
            -- (not `(v ~= ...) and false or nil`: that is always nil)
            if v == "Follow GearMatic" then MasterOptionsDB.specFollow = nil else MasterOptionsDB.specFollow = false end
            pcall(FollowSpec)
        end,
    },
    {
        kind = "choice", label = "GearMatic stat weights", since = 5, scope = "character",
        rec = function() return Judge() == "Pawn" and "Pawn" or "GearMatic's own" end,
        needs = { "GearMatic", "Pawn" }, off = "GearMatic's own",
        tip = "Pawn: GearMatic scores, marks and auto-equips with the Pawn scale this character shows in Pawn (Pawn Forever's, once it has swapped them in), and Pawn itself works out each item's value, so GearMatic agrees with Pawn. Show or hide scales in Pawn to change it. GearMatic's own: its Icy Veins guide weights.",
        choices = { "Pawn", "GearMatic's own" },
        get = function()
            local g = GM()
            if not (g and g.usePawnWeights) or GMBuiltinChosen() then return "GearMatic's own" end
            return "Pawn"
        end,
        set = function(v)
            local g = GM(); if not g then return end
            local si = _G.GearMatic and _G.GearMatic.ScaleImport
            local pawn = (v == "Pawn")
            g.usePawnWeights = pawn
            g.pawnAutoImport = pawn -- copies of Pawn's scales are refreshed at every login
            SyncPawnHidden()
            if pawn then
                -- back off GearMatic's built-in guide and any pinned scale, so Pawn's is picked
                if si and si.UsePawnScale then pcall(si.UsePawnScale) end
            elseif si and si.UseBuiltinScale then
                pcall(si.UseBuiltinScale)
            end
            RefreshGearMatic()
        end,
    },
    {
        kind = "toggle", label = "CheapUpgrades: use Pawn's weights", since = 5,
        rec = function() return Judge() == "Pawn" end,
        needs = { "CheapUpgrades", "Pawn" },
        tip = "CheapUpgrades asks Pawn what each item is worth, with the Pawn scale shown for your spec. A weights profile in CheapUpgrades still comes first (also the \"GearMatic\" one CheapUpgrades / GearMatic gives it), and a Pawn scale picked for a spec in CheapUpgrades' Stat weights is used instead of the one Pawn shows.",
        get = function() local c = CU(); return c ~= nil and c.usePawn == true end,
        set = function(v)
            local c = CU(); if not c then return end
            c.usePawn = v
            local cu = _G.CheapUpgrades
            if type(cu) == "table" then
                if v and cu.Engine and cu.Engine.NotePawnLinks then pcall(cu.Engine.NotePawnLinks) end
                if cu.Refresh and cu.SafeCall then pcall(cu.SafeCall, cu, cu.Refresh, cu) end
            end
        end,
    },

    { header = "Upgrade markers" },
    {
        kind = "toggle", label = "CheapUpgrades: \"+23%\" badges in bags", needs = "CheapUpgrades", rec = true,
        get = function() local c = CU(); return c and c.bagBadges ~= false end,
        set = function(v)
            local c = CU(); if c then c.bagBadges = v end
            local cu = _G.CheapUpgrades
            if cu and cu.Bags and cu.Bags.Refresh then pcall(cu.Bags.Refresh, cu.Bags) end
            if _G.Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
                Baganator.API.RequestItemButtonsRefresh()
            end
        end,
    },
    {
        kind = "toggle", label = "GearMatic: auto-equip upgrades", needs = "GearMatic", rec = false,
        tip = "GearMatic equips gear it scores as better on its own. Turn off if you'd rather decide with Pawn or CheapUpgrades.",
        get = function() return gmOn("autoEquipUpgrades") and GM() ~= nil end,
        set = function(v) local g = GM(); if g then g.autoEquipUpgrades = v end end,
    },

    { header = "Bags (Baganator)" },
    MatchedIconRow({
        -- (since 17: "Match stat weights" added, and recommended)
        kind = "choice", label = "Upgrade arrow in bags", rec = MATCH_ARROW, since = 17, reload = true,
        needs = "Baganator", choices = { MATCH_ARROW, "Pawn", "GearMatic", "Off" },
        tip = "Pawn's arrow and GearMatic's chevron both sit in the top-left corner of Baganator's bag slots. Match stat weights: the arrow of whoever judges upgrades under Stat weights - Pawn's while GearMatic uses Pawn's weights, GearMatic's chevron (which also marks upgrades for your alts) when it uses its own. Follows when you change that. Also sets Baganator's \"Upgrade\" plugin (its Upgrades category and search).",
        scope = "Baganator profile",
    }, "arrow", MATCH_ARROW, "Off", ArrowState, ApplyUpgradeArrow, MatchedArrow),
    MatchedIconRow({
        kind = "choice", label = "Junk coin in bags", rec = MATCH_JUNK, since = 17, reload = true,
        needs = "Baganator", choices = { MATCH_JUNK, "GearMatic", "Mastercraft", "Greys only" }, off = "Greys only",
        tip = "Which items Baganator marks with its junk coin (and sorts to the end). Match junk seller: exactly what the addon picked under Vendor > Sell junk automatically will sell - follows when you change that. GearMatic: greys, your GearMatic junk and marked items, outgrown gear and low-value items when turned on in GearMatic (needs MasterOptions_GearMatic_Baganator). Mastercraft: greys (with MasterOptions_Mastercraft_VendorSell also what Mastercraft says to VENDOR). With the VendorSell patch, VENDOR items get the coin under GearMatic too. Greys only: Baganator's own rule.",
        scope = "Baganator profile",
    }, "junk", MATCH_JUNK, "Greys only", JunkState, ApplyJunk, MatchedJunk),
    {
        kind = "toggle", label = "Grey out junk in bags", rec = true, since = 34, reload = true,
        needs = "Baganator",
        tip = "Baganator shows every item with the junk coin in grey - so what will be sold at the next vendor (with the coin above: also what Mastercraft says to VENDOR) stands out at a glance. Baganator's own \"Grey out junk\" setting.",
        get = function() local p = BAG(); return p ~= nil and p.icon_grey_junk == true end,
        set = function(v)
            local p = BAG(); if not p then return end
            p.icon_grey_junk = v and true or false
            if _G.Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
                pcall(Baganator.API.RequestItemButtonsRefresh)
            end
        end,
        scope = "Baganator profile",
    },
    {
        -- (GearMatic's skull is Baganator's corner widget "gearmatic_bis", top right; Baganator auto-inserts a
        -- widget once only, so taking it out sticks)
        kind = "toggle", label = "Best-in-slot skull in bags", reload = true,
        needs = { "Baganator", "GearMatic" },
        tip = "GearMatic's skull in the top-right corner of Baganator's bag slots, on items that are best in slot for you. GearMatic has no switch for it in the bags (only for the character sheet).",
        get = function() local p = BAG(); return p ~= nil and CornerHas(p, "gearmatic_bis") end,
        set = function(v)
            local p = BAG(); if not p then return end
            if v then CornerAdd(p, "gearmatic_bis", CORNERS[2]) else CornerRemove(p, "gearmatic_bis") end
        end,
        scope = "Baganator profile",
    },
    {
        -- (Baganator corner widget "masteroptions_never_sell", Modules\NeverSell.lua; first in the top right)
        kind = "toggle", label = "Never-sell lock in bags", rec = true, reload = true, needs = "Baganator",
        tip = "A lock in the top-right corner of every bag slot whose item is on the never-sell list (/mo > Never sell): no addon sells or deletes it.",
        get = function() local p = BAG(); return p ~= nil and CornerHas(p, "masteroptions_never_sell") end,
        set = function(v)
            local p = BAG(); if not p then return end
            if v then CornerAdd(p, "masteroptions_never_sell", CORNERS[2]) else CornerRemove(p, "masteroptions_never_sell") end
        end,
        scope = "Baganator profile",
    },
    {
        -- (Baganator corner widget "masteroptions_mc_advice", Modules\Baganator_Mastercraft.lua; last in the top
        -- right, so the lock and GearMatic's skull win the corner)
        -- (since 35: turns GearMatic's vendor badge off - two verdicts on one slot; 36: its auction and disenchant
        -- badges too)
        kind = "toggle", label = "Mastercraft advice in bags", rec = true, since = 36, reload = true,
        needs = { "Baganator", "MasterOptions_Baganator_Mastercraft", "MasterOptions_Mastercraft_Advice" },
        tip = "Mastercraft's advice as an icon in the top-right corner of Baganator's bag slots: a green tick for KEEP (also \"keep some for a guide\"), the vendor's bag for VENDOR, the auctioneer for AUCTION and the disenchant icon for DISENCHANT. Learned from the item tooltips, and read for new items in the background. No vendor's bag where the junk coin already shows it goes at the next vendor. Turns GearMatic's best-gold badges off - the vendor $, the auction price tag and the disenchant marker say the same (one verdict per slot).",
        get = function() local p = BAG(); return p ~= nil and CornerHas(p, "masteroptions_mc_advice") end,
        set = function(v)
            local p = BAG(); if not p then return end
            CornerRemove(p, "masteroptions_mc_advice")
            if v then
                p[CORNERS[2]] = type(p[CORNERS[2]]) == "table" and p[CORNERS[2]] or {}
                table.insert(p[CORNERS[2]], "masteroptions_mc_advice")
                -- (one verdict per slot: GearMatic's three "best gold" badges off - the module's own rule)
                local bm = _G.MasterOptions_BaganatorMastercraft
                if bm then bm.OneVerdictPerSlot(true) end
            end
        end,
        scope = "Baganator profile",
    },
    {
        kind = "choice", label = "GearMatic vendor badge", needs = "GearMatic",
        choices = { "Gold $", "Gold coin", "Off" }, off = "Off",
        tip = "GearMatic's badge in the bottom-left corner of gear you don't need, when a vendor pays the most for it. Gold coin looks like Baganator's junk coin, which means \"will be sold\" - Gold $ keeps the two apart.",
        get = function()
            local s = GM(); if not s then return "Off" end
            if s.bestGoldShowVendor == false then return "Off" end
            return s.vendorMarkerStyle == "coin" and "Gold coin" or "Gold $"
        end,
        set = function(v)
            local s = GM(); if not s then return end
            s.bestGoldShowVendor = v ~= "Off"
            if v ~= "Off" then s.vendorMarkerStyle = (v == "Gold coin") and "coin" or "dollar" end
            GMRefreshBagIcons()
            -- (one verdict per slot: GearMatic's badge back on takes Mastercraft's advice icons off)
            local p = v ~= "Off" and BAG()
            if p then CornerRemove(p, "masteroptions_mc_advice") end
        end,
    },
    {
        kind = "choice", label = "Bag icon size", needs = "Baganator",
        choices = { "Large", "Medium", "Small" },
        tip = "One size for every icon on Baganator's bag slots, whichever addon adds it: Pawn's arrow, the junk coin, GearMatic's arrow, skull and badge, and any other addon's corner icons. Text (item level, counts, CheapUpgrades' \"+23%\") keeps Baganator's font size. Large: each addon's own size. Also sets GearMatic's Bag icon size.",
        get = function() return BagIconSize() end,
        set = function(v)
            MasterOptionsDB.bagIconSize = ICON_SCALE[v] and v or "Large"
            ApplyBagIconSize()
        end,
    },

    { header = "Chat" },
    {
        kind = "toggle", label = "Annoying mode", rec = false, since = 28, scope = "character",
        needs_any = { "GearMatic", "Questie", "Mastercraft" },
        tip = "Addons posting in chat as you, for other players to see. Off turns all of these off (and remembers how each was, so On puts it back): GearMatic's upgrade posts to /party, /raid, /guild and battlegrounds, its emotes on equipping and after selling or repairing; Questie's quest progress to your group; Mastercraft's whispers answering !who. Lines only you see in your own chat stay as they are.",
        get = function() return AnnoyingOn() end,
        set = function(v) SetAnnoying(v) end,
    },
    {
        kind = "toggle", label = "Chat lines only you see", since = 29, scope = "character",
        needs_any = { "GearMatic", "CheapUpgrades", "Mastercraft", "Questie", "Auctionator", "ForeverDungeonJournal" },
        tip = "Notices addons print in your own chat window - nobody else sees them. Off turns all of these off (and remembers how each was, so On puts it back): GearMatic's line for each item you equip, its auto-equip reminder at login and its reminder to share recorded drops; CheapUpgrades' line when new gear in your bags is an upgrade; Mastercraft's lines after selling junk and repairing; Questie's lines for items that start a quest and for your own quest updates; Auctionator's line for each new auction; Dungeon Journal's notices.",
        get = function() return ChatLinesOn() end,
        set = function(v) SetChatLines(v) end,
    },

    { header = "Quests" },
    {
        kind = "choice", label = "Pre-select best quest reward", rec = PawnElseGearMatic, since = 7,
        needs = "MasterOptions_DialogKey_Pawn", choices = { "Pawn", "GearMatic", "Off" },
        tip = "On the quest reward screen the best choice is selected for you, so DialogKey's key (or Complete Quest) takes it. Pawn: the biggest upgrade by the Pawn scales you show. GearMatic: the choice GearMatic marks as an upgrade for this character. With no upgrade, the one worth most at a vendor. Needs the MasterOptions_DialogKey_Pawn patch.",
        get = function()
            local d = _G.MasterOptions_DialogKeyPawnDB
            local m = type(d) == "table" and d.mode or "pawn"
            -- (what the patch does: Pawn's pick without Pawn installed is GearMatic's - DialogKey_Pawn.lua Mode)
            if m == "pawn" and not Loaded("Pawn") and Loaded("GearMatic") then m = "gearmatic" end
            return (m == "gearmatic" and "GearMatic") or (m == "off" and "Off") or "Pawn"
        end,
        set = function(v)
            MasterOptions_DialogKeyPawnDB = MasterOptions_DialogKeyPawnDB or {}
            MasterOptions_DialogKeyPawnDB.mode = (v == "GearMatic" and "gearmatic") or (v == "Off" and "off") or "pawn"
        end,
    },
    {
        -- Pawn (PawnUI.lua: its arrow, bottom-left of the reward icon) and GearMatic (QuestRewardHook.lua: its
        -- chevron top-right, or a gold $ on the best vendor choice) both mark rewards - on the same buttons, and with
        -- GearMatic's own weights not always the same one. Only the markers: GearMatic's autoDetect (bag arrows,
        -- tooltips) and the pre-select above stay as they are.
        kind = "choice", label = "Quest reward marker", rec = PawnElseGearMatic, since = 23,
        choices = { "Pawn", "GearMatic", "Both", "Off" },
        tip = "Pawn and GearMatic both mark the best quest reward, so the same reward button can get two markers (and, with GearMatic's own weights, on different rewards). Pick one - the same as Pre-select best quest reward above, so the selected reward and its marker agree. Pawn's setting is its \"quest upgrade advisor\" (also its world quest upgrade marks); GearMatic's only its quest reward marks.",
        get = function()
            local pw, g = PAWN(), GM()
            local p = pw ~= nil and pw.ShowQuestUpgradeAdvisor ~= false
            local m = g ~= nil and g.autoDetectQuestReward ~= false
            return (p and m and "Both") or (p and "Pawn") or (m and "GearMatic") or "Off"
        end,
        set = function(v)
            local pw, g = PAWN(), GM()
            if pw then pw.ShowQuestUpgradeAdvisor = (v == "Pawn" or v == "Both") end
            if g then g.autoDetectQuestReward = (v == "GearMatic" or v == "Both") end
        end,
    },

    { header = "Fishing" },
    {
        -- Sparkles_Forever: its bobber effect off also turns the bobber's nameplate off (SoftTargetNameplateInteract 0,
        -- SoftTarget.lua SetNameplateGate) - and Mastercraft's mark sits on that nameplate. So "Mastercraft only"
        -- isn't offered: with Sparkles installed it wouldn't show (Problems says so if it's set that way).
        kind = "choice", label = "Fishing bobber mark", rec = "Sparkles", since = 23,
        needs = { "Mastercraft", "Sparkles_Forever" },
        choices = { "Sparkles", "Both", "Off" },
        tip = "Sparkles and Mastercraft both mark your fishing bobber. Sparkles: its effect only. Both: its effect and Mastercraft's mark above it. Mastercraft's mark alone isn't offered while Sparkles is installed: turning Sparkles' bobber effect off also turns off the bobber's nameplate, which Mastercraft's mark sits on.",
        get = function()
            local s, m = SPK(), MC()
            local sp = s and s.sparkleBobber ~= false
            local mc = m and m.fishMarker ~= false
            if sp and mc then return "Both" end
            return sp and "Sparkles" or "Off"
        end,
        set = function(v)
            local s, m = SPK(), MC()
            if s then s.sparkleBobber = (v ~= "Off") end
            if m then m.fishMarker = (v == "Both") end
        end,
    },

    { header = "Look" },
    {
        kind = "choice", label = "UI style", rec = "WoW", reload = true, scope = "character",
        needs = "MasterOptions", choices = { "WoW", "Dark" },
        tip = UIStyleTip, get = UIStyleGet, set = UIStyleSet,
    },
    {
        -- BetterBlizzFrames' minimap options move, re-skin or hide the same Minimap / MinimapCluster pieces
        -- OpenMap_MiniMap does (its classic minimap is applied as it loads: forever\modules\classicMinimap.lua)
        -- (shown, and recommended, only while both are loaded - when they fight: picking BetterBlizzFrames disables
        -- OpenMap_MiniMap, and after the reload this row is gone; turn it on again in the AddOns list)
        kind = "choice", label = "Minimap", rec = "OpenMap_MiniMap", since = 23, reload = true,
        needs = { "BetterBlizzFrames", "OpenMap_MiniMap" }, choices = { "OpenMap_MiniMap", "BetterBlizzFrames classic" },
        tip = "OpenMap_MiniMap and BetterBlizzFrames' minimap options (Classic minimap, Minimap tweaks, Hide minimap buttons, Hide minimap, Hide minimap in arena) work on the same frames and fight. OpenMap_MiniMap: those BetterBlizzFrames options off. BetterBlizzFrames classic: its classic minimap on and the OpenMap_MiniMap addon disabled (turn it on again in the AddOns list). Takes a reload.",
        get = function()
            local b = type(_G.BetterBlizzFramesDB) == "table" and _G.BetterBlizzFramesDB or {}
            local AO = C_AddOns or {}
            local state = AO.GetAddOnEnableState and AO.GetAddOnEnableState("OpenMap_MiniMap", UnitName("player"))
            if state == 0 and b.classicMinimap == true then return "BetterBlizzFrames classic" end -- (after the reload)
            local bbfOn = b.classicMinimap == true or b.foreverMinimapTweaks == true or b.hideMinimapButtons == true or b.hideMinimap == true
                or b.hideMinimapAuto == true
            return bbfOn and "Both (conflict)" or "OpenMap_MiniMap"
        end,
        set = function(v)
            local b = _G.BetterBlizzFramesDB
            local AO = C_AddOns or {}
            local enable, disable = AO.EnableAddOn or EnableAddOn, AO.DisableAddOn or DisableAddOn
            if v == "BetterBlizzFrames classic" then
                if type(b) == "table" then b.classicMinimap = true; b.SkipMinimapForeverTint = nil end
                if disable then pcall(disable, "OpenMap_MiniMap") end
            else
                if type(b) == "table" then
                    b.classicMinimap, b.foreverMinimapTweaks, b.hideMinimapButtons, b.hideMinimap = false, false, false, false
                    -- (its arena hiding hides the whole MinimapCluster - OpenMap_MiniMap's map with it)
                    b.hideMinimapAuto, b.hideMinimapAutoQueueEye = false, false
                    -- (BBF.TintForeverMinimap, at every login whatever the options: the minimap buttons' rings
                    -- tinted bronze - on OpenMap_MiniMap's map, its own look instead. A BetterBlizzFrames key with no
                    -- checkbox of its own.)
                    b.SkipMinimapForeverTint = true
                end
                if enable then pcall(enable, "OpenMap_MiniMap") end
            end
        end,
    },
    {
        kind = "choice", label = "Minimap buttons", rec = "On mouse-over", since = 32, reload = true,
        needs = "OpenMap_MiniMap", choices = { "On mouse-over", "Round the edge", "In a tray" },
        tip = "Other addons' minimap buttons (Questie, GearMatic, WhatsTraining...) on OpenMap_MiniMap's map: laid round its edge and shown only while the mouse is over the map, always round the edge, or gathered in a tray (one button that opens them). Takes a reload.",
        get = MO.ButtonsGet, set = MO.ButtonsSet,
    },
    {
        kind = "choice", label = "Minimap border", rec = "Action bar", since = 19,
        needs = "MasterOptions_OpenMapMiniMap_Border", choices = { "Action bar", "OpenMap's own" }, off = "OpenMap's own",
        tip = "Action bar: OpenMap's square minimap and its zone bar framed with the same border as your action bar buttons. OpenMap's own: its thin dark border or gold frame (UI style picks which). Square minimap only. Needs the MasterOptions_OpenMapMiniMap_Border patch.",
        get = function()
            local d = _G.MasterOptions_MinimapBorderDB
            return (type(d) == "table" and d.on == false) and "OpenMap's own" or "Action bar"
        end,
        set = function(v)
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            MasterOptions_MinimapBorderDB.on = (v == "Action bar")
            local b = _G.MasterOptions_MinimapBorder
            if b and b.Apply then pcall(b.Apply) end
        end,
    },
    {
        kind = "choice", label = "Minimap border thickness", rec = "Thick", since = 20,
        needs = "MasterOptions_OpenMapMiniMap_Border", choices = { "As on buttons", "Thick", "Thicker" },
        tip = "How thick the action-bar border round the minimap is: as on the action buttons themselves, or thicker (it's a much bigger frame). Changes at once.",
        get = function()
            local d = _G.MasterOptions_MinimapBorderDB
            local s = type(d) == "table" and d.scale or 1.6
            return (s <= 1.1 and "As on buttons") or (s >= 2 and "Thicker") or "Thick"
        end,
        set = function(v)
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            MasterOptions_MinimapBorderDB.scale = (v == "As on buttons" and 1) or (v == "Thicker" and 2.2) or 1.6
            local b = _G.MasterOptions_MinimapBorder
            if b and b.Apply then pcall(b.Apply) end
        end,
    },
    {
        kind = "choice", label = "Minimap coordinates", rec = "Top center", since = 22,
        needs = "MasterOptions_OpenMapMiniMap_Border",
        choices = { "Top left", "Top center", "Top right", "Bottom left", "Bottom center", "Bottom right", "Game's place" },
        tip = "The coordinates in a small tab sticking out of the minimap's frame, like the zone bar (same background and border): on its top or bottom edge, at the left, centre or right. When the minimap is so close to the top (or bottom) of the screen that the tab would stick off it, the tab goes on the other edge, and this row says so - move the minimap away from the screen's edge to have it where you picked. Shown while the game's coordinates setting is on (Edit Mode's minimap \"show coordinates\", or OpenMap's \"Coordinates under the map\"). Game's place: the game's own line on the map's bottom edge, where OpenMap's bottom row of addon buttons covers it. Changes at once.",
        -- (the row's short text: says so when the tab had to go on the other edge)
        desc = function()
            local b = _G.MasterOptions_MinimapBorder
            local wanted, used
            if b and b.CoordsSide then wanted, used = b.CoordsSide() end
            if wanted and used and wanted ~= used then
                return ("|cffffd200On the %s edge now:|r no room %s your minimap - it's at the %s of the screen. Move it away from the edge to have it %s."):format(
                    used, wanted == "top" and "above" or "below", wanted, wanted == "top" and "on top" or "at the bottom")
            end
            return "The coordinates in a small tab sticking out of the minimap's frame, like the zone bar: on its top or bottom edge."
        end,
        get = function()
            local d = _G.MasterOptions_MinimapBorderDB
            local m = type(d) == "table" and d.coords or nil
            if m == "game" then return "Game's place" end
            if m == nil or m == "top" then return "Top center" end
            local side, align = m:match("^(%a+)%-(%a+)$")
            if not side then return "Top center" end
            return side:sub(1, 1):upper() .. side:sub(2) .. " " .. align
        end,
        set = function(v)
            MasterOptions_MinimapBorderDB = MasterOptions_MinimapBorderDB or {}
            MasterOptions_MinimapBorderDB.coords = (v == "Game's place") and "game" or v:lower():gsub(" ", "-")
            local b = _G.MasterOptions_MinimapBorder
            if b and b.PlaceCoords then pcall(b.PlaceCoords) end
        end,
    },

}
-- the modules (Modules\*.lua, once separate addons): on / off for the next load, and what each is doing now
local MODULE_STATE_TEXT = { on = "|cff66dd66running|r", off = "|cff9d9d9doff|r", error = "|cffff5555stopped by an error (Problems)|r",
    ["old folder"] = "|cffffd200standing aside: the old separate addon of the same name is still installed (Problems)|r" }
-- Every module (Modules\*.lua): its name, a title, the addons it needs (as its MasterOptions_Module line declares
-- them - the registry is empty while this file loads; tests\test_moduleslist.py checks the two agree, and that none
-- is missing), the defaults version it came with (since: turned on by Recommended on upgrading past it) and what it
-- does (tip), under the section it belongs in. Its row: the title, the tip's first sentence and what it needs under
-- it, the tick box greyed when a needed addon isn't loaded; the whole tip and what it's doing now in the tooltip.
local MODULES = {
    { header = "Modules: maps (on / off after a reload)" },
    { "DungeonJournal_OpenMap", "Dungeon Journal's map inside dungeons", { "ForeverDungeonJournal", "OpenMap" }, since = 11,
      tip = "Dungeon Journal's map of the dungeon inside dungeons instead of OpenMap's (Maps > Map inside dungeons), and OpenMap's dungeon entrance icons opening it (Dungeon entrance click) - a list to pick from where several dungeons share an entrance. Replaces OpenMap_NoDungeonMap." },
    { "DungeonJournal_ShowOnMap", "Dungeon Journal's Show on Map as an OpenMap pin", { "ForeverDungeonJournal", "OpenMap" }, since = 37,
      tip = "Dungeon Journal's Show on Map also puts a blue OpenMap pin there (named, followed like a pin you drop), gone again when Dungeon Journal clears its mark. A pin you wrote your own note on stays." },
    { "DungeonJournal_SpokenBosses", "Spoken's stories on Dungeon Journal's map", { "ForeverDungeonJournal", "Spoken_Bosses" }, since = 32,
      tip = "Spoken_Bosses tells the dungeon's story beside the world map when Dungeon Journal's map of it is shown there (Map inside dungeons, Dungeon entrance click), and a boss's story when you click the boss on that map." },
    { "ShortestPathForever_OpenMapPins", "One trip, one OpenMap pin", { "ShortestPathForever", "OpenMap" }, since = 32,
      tip = "One trip, one pin: every ShortestPathForever journey (Shift-click, a pin you follow in OpenMap, Dungeon Journal's Show on Map, a quest or recipe waypoint) has an OpenMap pin at its destination, and ShortestPathForever's own goal marker is hidden meanwhile (at the minimap's rim it stays, pointing the way). Any end - arriving, clearing, stopping, a new journey - clears the pin and OpenMap's following. A pin you wrote a note on stays." },
    { "ShortestPathForever_OpenMapMiniMap", "Journey goal visible on OpenMap's minimap", { "ShortestPathForever", "OpenMap_MiniMap" }, since = 23,
      tip = "Shortest Path's journey goal on the minimap stays visible over OpenMap's painted minimap (it faded with the game's terrain, and was gone at far zoom)." },
    { "Mastercraft_FarmTour", "Farming tours", { "Mastercraft", "ShortestPathForever" }, since = 30,
      tip = "Start farming in Mastercraft and ShortestPathForever walks you through this zone's herbs and veins worth it to you, nearest first (Mastercraft's own nodes and its Which nodes rule), and stops when you do. ShortestPathForever's own farming tour needs GatherMate2. /mo farm starts one without Mastercraft's session (/mo farm herbs, ores, stop)." },
    { "Mastercraft_RecipeMap", "Recipe map markers", { "Mastercraft", "Questie" }, since = 31,
      tip = "Map markers (world map and minimap) on the vendors selling patterns for recipes you haven't learned, the creatures and chests they drop from (a specific drop, with GearMatic's chance - world drops aren't marked), and on your profession's trainers when you're near your skill cap and can train the next rank. From Mastercraft's list of your recipes and QuestieDB's vendors and trainers. A pattern's own skill isn't known: its tooltip at the vendor tells." },
    { "OpenMapTweaks_Mastercraft", "Mastercraft's node rule for OpenMap_Tweaks' pins", { "OpenMap_Tweaks", "Mastercraft" }, since = 2,
      tip = "Mastercraft's node rule also filters OpenMap_Tweaks' gathering pins." },
    { "OpenMapMiniMap_Border", "Action bar border round the minimap", { "OpenMap_MiniMap" }, since = 19,
      tip = "OpenMap's square minimap framed with the action bar buttons' border (Look > Minimap border)." },
    { header = "Modules: gear (on / off after a reload)" },
    { "DungeonJournal_Upgrades", "Upgrade marks in Dungeon Journal's loot", { "ForeverDungeonJournal" }, since = 29,
      tip = "Dungeon Journal's loot marked: an upgrade arrow and how big (+23%) by whoever judges upgrades - Pawn with Pawn Forever, else GearMatic with CheapUpgrades' size - GearMatic's skull on what's best in slot for you, and a cog on what your Mastercraft guides need. No more hovering every item." },
    { "CheapUpgrades_GearMatic", "CheapUpgrades uses GearMatic's stat weights", { "CheapUpgrades", "GearMatic" }, since = 27,
      tip = "CheapUpgrades values items with GearMatic's stat weights: a \"GearMatic\" weights profile for every spec, kept up to date (level, talents) and used unless you picked a profile of your own in CheapUpgrades. Off: CheapUpgrades' own weights again." },
    { "GearMatic_SpecKeep", "Keep your best gear for every spec", { "GearMatic" }, since = 27,
      tip = "Gear that is your best or 2nd best for any of your specs in GearMatic is kept from selling (Master Options' and GearMatic's own) and from DeleteCheapestItem - off-spec pieces too. GearMatic itself only looks at the spec you play now. Works with or without Pawn." },
    { "GearMatic_Forever", "Separate GearMatic data per character", { "GearMatic" }, since = 7,
      tip = "Keeps GearMatic's data apart for characters that share a first name (Forever reports no realm, so GearMatic saved them as one). Turning it off later makes GearMatic go back to the shared record." },
    { "DialogKey_Pawn", "Best quest reward pre-selected", { "DialogKey_Numy" }, since = 7,
      tip = "Pre-selects the best quest reward so DialogKey's key takes it (pick whose choice under Quests)." },
    { header = "Modules: selling (on / off after a reload)" },
    { "NeverSell", "One never-sell list for every addon", {}, since = 24,
      tip = "One never-sell list, kept the same in GearMatic (never auto-sold), Mastercraft (no VENDOR / AUCTION advice) and DeleteCheapestItem (never offered for deletion): add or remove an item in any of them, or with /mo never <item>, and it changes in all. /mo never lists it." },
    { "GearMatic_SellGuard", "GearMatic's selling keeps what's protected", { "GearMatic" }, since = 25,
      tip = "GearMatic's gear and low-value selling keeps what Master Options protects: the never-sell list, materials your Mastercraft guides need, and gear Pawn calls an upgrade or your best for a spec, or GearMatic rates your best or 2nd best for any spec (with GearMatic_SpecKeep) - through GearMatic's own sell guard." },
    { "DeleteCheapestItem_Protect", "Keep gear and materials from being deleted", { "DeleteCheapestItem" }, since = 10,
      tip = "DeleteCheapestItem never offers upgrades (Pawn, GearMatic), best-in-slot items, set or loadout pieces, profession tools or materials Mastercraft says you need. Kept as entries in its ignore list; only those it added are removed again." },
    { "Mastercraft_Keep", "Materials your guides need are never sold", { "Mastercraft" }, since = 10,
      tip = "Materials on your Mastercraft item tracker, or that Mastercraft's tooltip says a guide still needs, go on GearMatic's never-sell list (and are protected from DeleteCheapestItem with the Protect patch)." },
    { "Mastercraft_VendorSell", "Sell what Mastercraft says to vendor", { "Mastercraft" }, since = 17,
      tip = "At a vendor, what Mastercraft's advice says to VENDOR is sold by your junk seller (GearMatic or Mastercraft). Pick what under Vendor and bank." },
    { "Mastercraft_BankMats", "Guide materials go into the bank", { "Mastercraft" }, since = 18,
      tip = "When you open the bank, the materials Mastercraft keeps for your guides go into it; VENDOR and AUCTION items stay in your bags. Pick what under Vendor and bank." },
    { "CheapUpgrades_Baganator", "Upgrade badges on bag slots", { "CheapUpgrades", "Baganator" }, since = 1,
      tip = "CheapUpgrades' \"+23%\" badges on Baganator's bag slots." },
    { "GearMatic_Baganator", "GearMatic's junk coins and loadouts in bags", { "GearMatic", "Baganator" }, since = 6,
      tip = "Baganator junk coins from GearMatic's vendor rules, and GearMatic loadouts shown as equipment sets on bag slots (GearMatic has loadouts on Vanilla / TBC clients only - not on Forever)." },
    { "Mastercraft_Advice", "Mastercraft's advice remembered", { "Mastercraft" }, since = 37,
      tip = "Remembers what Mastercraft advises for each item (KEEP, VENDOR, AUCTION, DISENCHANT), learned from its tooltips and read for new items in your bags in the background - so the junk coins for VENDOR items and the advice icons in the bags show without hovering each item." },
    { "Baganator_Mastercraft", "Mastercraft's junk coin and advice icons in bags", { "Baganator", "Mastercraft" }, since = 37,
      tip = "Mastercraft in Baganator's bags: its junk coin (greys, and what Master Options sells with them) and an icon with its advice on every bag slot (Bags > Mastercraft advice in bags). While the icons show, GearMatic's best-gold badges stay off - one verdict per slot." },
    { header = "Modules: more (on / off after a reload)" },
    { "Mastercraft_FishingView", "Fishing view keeps bags and pop-ups", { "Mastercraft" }, since = 12,
      tip = "While Mastercraft's fishing view hides the interface: Baganator's bags, DeleteCheapestItem's window, confirmation pop-ups and loot rolls stay visible, and Chattynator's chat follows Mastercraft's chat setting. Replaces MasterOptions_Mastercraft_Baganator." },
    { "Mastercraft_Auctionator", "Scan prices button on Auctionator's page", { "Mastercraft", "Auctionator" }, since = 9,
      tip = "Mastercraft's Scan prices button on Auctionator's page (next to Full Scan) instead of the tab row or the bottom corner, where it covered Buyout." },
    { "Mastercraft_Chattynator", "Mastercraft's /played kept out of chat", { "Mastercraft", "Chattynator" }, since = 14,
      tip = "Mastercraft's own /played request (it records your play time) stays out of Chattynator's chat, as it already does in the game's chat. Your own /played still shows." },
    { "Chat_AddonWhispers", "Hide not-online lines from addons' whispers", {}, since = 33,
      tip = "Hides \"No player named ... is currently playing\" when an addon's hidden whisper (OpenMap's map sharing, Questie's sync, Mastercraft's crafter search ...) went to someone who just logged off - you sent nothing. Your own whispers' answers always show. /mo whispers lists which addon whispered whom." },
}
-- addon folder names as the AddOns list shows them
local NICE = { ForeverDungeonJournal = "Dungeon Journal", DialogKey_Numy = "DialogKey", Spoken_Bosses = "Spoken Bosses",
    ShortestPathForever = "Shortest Path Forever", OpenMap_MiniMap = "OpenMap MiniMap", OpenMap_Tweaks = "OpenMap Tweaks",
    DeleteCheapestItem = "DeleteCheapestItem" }
local function NeedsLine(needs)
    if #needs == 0 then return "Needs: nothing else" end
    local out = {}
    for _, a in ipairs(needs) do
        local n = NICE[a] or a
        out[#out + 1] = Loaded(a) and n or ("|cffff5555" .. n .. " (not loaded)|r")
    end
    return "Needs: " .. table.concat(out, ", ")
end
local function FirstSentence(text)
    local s = (text or ""):match("^(.-[%.!?])%s") or text or ""
    if #s > 170 then s = s:sub(1, 167):gsub("%s+%S*$", "") .. "..." end
    return s
end
for _, entry in ipairs(MODULES) do
    if entry.header then
        OPTIONS[#OPTIONS + 1] = { header = entry.header }
    else
        local short, title, needs = entry[1], entry[2], entry[3]
        local name = "MasterOptions_" .. short
        local function M() return _G.MasterOptions_Modules end
        OPTIONS[#OPTIONS + 1] = {
            kind = "toggle", label = title, reload = true, rec = true, since = entry.since or 1,
            module = short, needs = #needs > 0 and needs or nil,
            desc = function() return FirstSentence(entry.tip) .. "\n" .. NeedsLine(needs) end,
            tip = function()
                local m = M()
                local state = m and m.State(short)
                local now = state and (MODULE_STATE_TEXT[state] or ("|cff9d9d9dnot running: " .. state .. "|r")) or "?"
                return (entry.tip or "") .. "\n\n" .. NeedsLine(needs) .. "\nModule: " .. short .. "\nNow: " .. now
            end,
            get = function() local m = M(); return m == nil or m.IsEnabled(short) end,
            set = function(v) local m = M(); if m then m.SetEnabled(short, v) end end,
        }
    end
end

-- for the files after this one
MO.OPTIONS = OPTIONS
