-- Master Options: the health check - addons that can't load, leftover copies of our patches, settings pointing at
-- addons that aren't there (the Problems section of /mo, and once at login).

local _, MO = ...
-- from the files before this one
local BAG, GM, GMRefreshBagIcons, Loaded, MC, SPK, SetBagPlugin = MO.BAG, MO.GM, MO.GMRefreshBagIcons, MO.Loaded, MO.MC, MO.SPK, MO.SetBagPlugin

---------------------------------------------------------------------------
-- Health check: addons that can't load, leftover copies of our patches, and settings that point at
-- addons which aren't there. Shown at the top of /mo (with a fix where there is one) and once at login.
---------------------------------------------------------------------------
local AO = C_AddOns or {}
local NumAddOns   = AO.GetNumAddOns or GetNumAddOns
local AddOnInfo   = AO.GetAddOnInfo or GetAddOnInfo
local AddOnDeps   = AO.GetAddOnDependencies or GetAddOnDependencies
local IsLOD       = AO.IsAddOnLoadOnDemand or IsAddOnLoadOnDemand
local function Exists(name)
    if AO.DoesAddOnExist then return AO.DoesAddOnExist(name) end
    local ok, _, _, _, _, reason = pcall(AddOnInfo, name)
    return ok and reason ~= "MISSING"
end
local function AddonEnabled(name)
    local who = UnitName("player")
    local state = AO.GetAddOnEnableState and AO.GetAddOnEnableState(name, who)
    if state == nil and GetAddOnEnableState then state = GetAddOnEnableState(who, name) end
    return (state or 0) > 0
end
local function SetAddonEnabled(name, on)
    local fn = on and (AO.EnableAddOn or EnableAddOn) or (AO.DisableAddOn or DisableAddOn)
    if fn then fn(name) end
end

-- our patches before they got the MasterOptions_ prefix: an old copy left installed loads twice
local RENAMED = { "Mastercraft_Baganator", "CheapUpgrades_Baganator", "OpenMapTweaks_Mastercraft", "GearMatic_Baganator" }

-- Baganator plugin ids -> the addon(s) that register them
local BAG_JUNK_OWNER = {
    gearmatic = "MasterOptions_GearMatic_Baganator", mastercraft = "MasterOptions_Baganator_Mastercraft", enhanceqol_vendor = { "EnhanceQoL", "EnhanceQoLVendor" },
    selljunk = "SellJunk", scrap = "Scrap", vendor = "Vendor", dejunk = "Dejunk", peddler = "Peddler",
}
local BAG_UPGRADE_OWNER = { pawn = "Pawn", gearmatic_upgrade = "GearMatic", simple_item_levels = "SimpleItemLevel" }
local function OwnerLoaded(o)
    if type(o) == "table" then
        for _, n in ipairs(o) do if Loaded(n) then return true end end
        return false
    end
    return Loaded(o)
end

-- (MO.ShowErrorText: the copy window, made with the window in Window.lua)

-- Each check: { name, function(add, out) }. add(id, text, fixLabel, fix) adds a problem (unless ignored); out is
-- the list itself, for a row with more to it (the errors row). Run one by one, each on its own: one that fails
-- doesn't keep the others from being looked at.
local CHECKS = {}

-- 0. errors in Master Options or our patches (ErrorLog.lua): Copy for a bug report, Clear when done
CHECKS[#CHECKS + 1] = { "errors", function(_, out)
    local log = _G.MasterOptions_ErrorLog
    local errs = log and log.List() or {}
    if #errs > 0 then
        local lines = {}
        for i = 1, math.min(3, #errs) do
            local e = errs[i]
            local msg = (e.msg or "?"):gsub("^.-AddOns[/\\][^/\\]+[/\\]", ""):gsub("\n.*", "")
            if #msg > 110 then msg = msg:sub(1, 107) .. "..." end
            lines[#lines + 1] = ("|cffffd200%s|r%s: %s%s"):format(e.addon or "?", e.where and (" (" .. e.where .. ")") or "",
                msg, (e.count or 1) > 1 and ("  |cff9d9d9dx" .. e.count .. "|r") or "")
        end
        if #errs > 3 then lines[#lines + 1] = ("|cff9d9d9d+%d more|r"):format(#errs - 3) end
        out[#out + 1] = {
            id = "errors", fixLabel = "Copy", noReload = true, ignoreLabel = "Clear",
            text = ("%d error%s in Master Options' patches (Copy gives the full text for a bug report):\n%s"):format(
                #errs, #errs > 1 and "s" or "", table.concat(lines, "\n")),
            fix = function() if MO.ShowErrorText then MO.ShowErrorText() end end,
            onIgnore = function() log.Clear() end,
        }
    end
end }

-- 1. enabled addons that didn't load
CHECKS[#CHECKS + 1] = { "addons that didn't load", function(add)
    for i = 1, (NumAddOns and NumAddOns() or 0) do
        local name, _, _, _, reason = AddOnInfo(i)
        if name and not name:find("^Blizzard_") and AddonEnabled(name) and not Loaded(name)
            and not (IsLOD and IsLOD(i)) then
            local missing, off = {}, {}
            if AddOnDeps then
                for _, dep in ipairs({ AddOnDeps(i) }) do
                    if not Exists(dep) then missing[#missing + 1] = dep
                    elseif not AddonEnabled(dep) then off[#off + 1] = dep end
                end
            end
            local disable = function() SetAddonEnabled(name, false) end
            if #missing > 0 then
                add("missing:" .. name, ("%s needs %s, which isn't installed."):format(name, table.concat(missing, ", ")), "Disable", disable)
            elseif #off > 0 then
                add("depoff:" .. name, ("%s needs %s, which is disabled."):format(name, table.concat(off, ", ")), "Enable",
                    function() for _, d in ipairs(off) do SetAddonEnabled(d, true) end end)
            elseif reason == "INTERFACE_VERSION" then
                add("outdated:" .. name, ("%s is out of date for this game version and doesn't load."):format(name), "Disable", disable)
            elseif reason and reason ~= "DEMAND_LOADED" and reason ~= "DISABLED" then
                add("noload:" .. name, ("%s didn't load (%s)."):format(name, _G["ADDON_" .. reason] or reason), "Disable", disable)
            end
        end
    end
end }

-- 2. old copies of our patches
CHECKS[#CHECKS + 1] = { "old copies", function(add)
    for _, old in ipairs(RENAMED) do
        if Exists(old) then
            add("old:" .. old, ("Old copy %s is still installed (now built into Master Options). Delete its folder from Interface\\AddOns."):format(old),
                AddonEnabled(old) and "Disable" or nil, function() SetAddonEnabled(old, false) end)
        end
    end
end }

-- 2b. our patch addons from before they became modules of Master Options: while one is installed and
-- enabled its module stands aside (else every hook ran twice)
CHECKS[#CHECKS + 1] = { "old patch addons", function(add)
    local mods = _G.MasterOptions_Modules
    for _, short in ipairs(mods and mods.Names() or {}) do
        local old = "MasterOptions_" .. short
        if Exists(old) then
            add("oldmodule:" .. old, ("%s is now built into Master Options. Disable the old addon (then delete its folder from Interface\\AddOns) so its module can take over after a reload."):format(old),
                AddonEnabled(old) and "Disable" or nil, function() SetAddonEnabled(old, false) end)
        end
    end
end }

-- 3. entries a protection patch added, left behind after the patch was turned off or removed
CHECKS[#CHECKS + 1] = { "leftover entries", function(add)
    local dci = _G.DCI_CharDB
    if Loaded("DeleteCheapestItem") and not Loaded("MasterOptions_DeleteCheapestItem_Protect")
        and type(dci) == "table" and type(dci.moProtected) == "table" and next(dci.moProtected) then
        add("leftover:dci", "DeleteCheapestItem still ignores items the Protect patch added (it's off now).", "Remove", function()
            local list = dci.IgnoredItems or {}
            for id in pairs(dci.moProtected) do
                for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
            end
            dci.moProtected = nil
        end)
    end
    local gdb = _G.GearMaticDB
    if Loaded("GearMatic") and not Loaded("MasterOptions_Mastercraft_Keep")
        and type(gdb) == "table" and type(gdb.moKeep) == "table" and next(gdb.moKeep) then
        add("leftover:gmkeep", "GearMatic's never-sell list still has materials the Mastercraft Keep patch added (it's off now).", "Remove", function()
            for id in pairs(gdb.moKeep) do if gdb.sellIgnore then gdb.sellIgnore[id] = nil end end
            gdb.moKeep = nil
        end)
    end
    if Loaded("GearMatic") and not Loaded("MasterOptions_Mastercraft_VendorSell")
        and type(gdb) == "table" and type(gdb.moSell) == "table" and next(gdb.moSell) then
        add("leftover:gmsell", "GearMatic's \"always sell\" list still has items the Mastercraft VENDOR patch added for a vendor visit (it's off now).", "Remove", function()
            for id in pairs(gdb.moSell) do if gdb.sellMark then gdb.sellMark[id] = nil end end
            gdb.moSell = nil
        end)
    end
end }

-- Details in a chat tab: it hooks the game's chat tabs (FCF_SetWindowName, FCF_Close), which Chattynator
-- replaces with its own - the two can't work together
CHECKS[#CHECKS + 1] = { "Details in a chat tab", function(add)
    local det = _G.Details
    if Loaded("Details") and Loaded("Chattynator") and type(det) == "table" and type(det.chat_tab_embed) == "table"
        and det.chat_tab_embed.enabled then
        add("details:chatembed", "Details is set to sit in a chat tab, but Chattynator replaces the game's chat tabs. Turn Details' chat tab off.", "Turn off", function()
            if det.chat_embed and det.chat_embed.SetTabSettings then
                pcall(det.chat_embed.SetTabSettings, det.chat_embed, det.chat_tab_embed.tab_name or "", false)
            end
            det.chat_tab_embed.enabled = false
        end)
    end
end }

-- BetterBlizzFrames options that move the same minimap / chat pieces as OpenMap_MiniMap / Chattynator
CHECKS[#CHECKS + 1] = { "BetterBlizzFrames", function(add)
    local bbf = _G.BetterBlizzFramesDB
    if Loaded("BetterBlizzFrames") and type(bbf) == "table" then
        local clashes = {
            { "classicMinimap", "OpenMap_MiniMap", "its classic minimap re-skin" },
            { "foreverMinimapTweaks", "OpenMap_MiniMap", "its minimap tweaks (scale, position, title, mail)" },
            { "hideMinimapButtons", "OpenMap_MiniMap", "hiding minimap buttons (OpenMap_MiniMap's tray holds them)" },
            { "hideMinimap", "OpenMap_MiniMap", "hiding the minimap" },
            { "hideChatButtons", "Chattynator", "hiding the chat buttons (Chattynator moves them into its own bar)" },
        }
        for _, c in ipairs(clashes) do
            local key, other, what = c[1], c[2], c[3]
            if bbf[key] == true and Loaded(other) then
                add("bbf:" .. key, ("BetterBlizzFrames' %s works on the same frames as %s - the two will fight. Turn it off in BetterBlizzFrames."):format(what, other),
                    "Turn off", function() bbf[key] = false end)
            end
        end
    end
end }

-- addons a newer patch of ours now does the job of
-- (the ones without the MasterOptions_ prefix are older "local patch" addons: the loader doesn't
-- see them, so their module would run as well)
CHECKS[#CHECKS + 1] = { "replaced addons", function(add)
    local mods = _G.MasterOptions_Modules
    for old, new in pairs({ OpenMap_NoDungeonMap = "MasterOptions_DungeonJournal_OpenMap",
                            OpenMapTweaks_Mastercraft = "MasterOptions_OpenMapTweaks_Mastercraft",
                            CheapUpgrades_Baganator = "MasterOptions_CheapUpgrades_Baganator",
                            Mastercraft_Baganator = "MasterOptions_Mastercraft_FishingView",
                            MasterOptions_Mastercraft_Baganator = "MasterOptions_Mastercraft_FishingView" }) do
        if Exists(old) and (Exists(new) or (mods and mods.Has(new))) then
            add("replaced:" .. old, ("%s is no longer needed: %s does the same. Disable it, then delete its folder."):format(old, new),
                AddonEnabled(old) and "Disable" or nil,
                function() SetAddonEnabled(old, false); if Exists(new) then SetAddonEnabled(new, true) end end)
        end
    end
end }

-- Pawn without Pawn Forever: GearMatic's weights, CheapUpgrades' badges, the quest reward pick and Baganator's
-- upgrade arrow all follow the scales Pawn shows, and Pawn's stock Classic scales aren't made for WoW Forever
-- (enabled but not loaded yet is left to the "didn't load" check above, or to the reload after Enable)
CHECKS[#CHECKS + 1] = { "Pawn Forever", function(add)
    if Loaded("Pawn") and not Exists("Pawn_Forever") then
        add("pawnforever:missing", "Pawn is installed without Pawn Forever, so stat weights (GearMatic, CheapUpgrades, quest rewards, bag upgrade arrows) come from Pawn's stock Classic scales. Install Pawn Forever for weights made for WoW Forever.")
    elseif Loaded("Pawn") and not AddonEnabled("Pawn_Forever") then
        add("pawnforever:off", "Pawn Forever is disabled, so stat weights (GearMatic, CheapUpgrades, quest rewards, bag upgrade arrows) come from Pawn's stock Classic scales.",
            "Enable", function() SetAddonEnabled("Pawn_Forever", true) end)
    end
end }

-- Companion addons made for one version of the addon they extend
CHECKS[#CHECKS + 1] = { "companion versions", function(add)
    local Meta = AO.GetAddOnMetadata or _G.GetAddOnMetadata
    local function Field(name, key)
        local ok, v = pcall(Meta, name, key)
        return ok and type(v) == "string" and v:match("^%s*(.-)%s*$") or nil
    end
    -- BetterBetterBlizzPlates opens its window only for the BetterBlizzPlates version it names
    -- (X-BetterBlizzPlates-Version; BetterBlizzPlates' own Version carries a leading "v")
    if Meta and Loaded("BetterBetterBlizzPlates") and Loaded("BetterBlizzPlates") then
        local want, have = Field("BetterBetterBlizzPlates", "X-BetterBlizzPlates-Version"), Field("BetterBlizzPlates", "Version")
        have = have and have:gsub("^[vV]", "")
        if want and have and want ~= have then
            add("bbbp:version", ("BetterBetterBlizzPlates is made for BetterBlizzPlates %s, and you have %s - its options window stays closed until BetterBetterBlizzPlates is updated for it (BetterBlizzPlates' own options still work)."):format(want, have))
        end
    end
    -- Questie needs QuestieDB, at the contract its .toc names (X-QuestieDB-Contract): the same check Questie
    -- makes at login (Modules/VersionCheckDB.lua), here with the rest
    if Loaded("Questie") then
        local need = tonumber(Field("Questie", "X-QuestieDB-Contract") or "")
        if not Loaded("QuestieDB") then
            if Exists("QuestieDB") and not AddonEnabled("QuestieDB") then
                add("questiedb:off", "QuestieDB is turned off, so Questie has no quest data. Turn it on and reload.",
                    "Enable", function() SetAddonEnabled("QuestieDB", true) end)
            elseif not Exists("QuestieDB") then
                add("questiedb:missing", "QuestieDB isn't installed, so Questie has no quest data. Reinstall Questie (QuestieDB comes with it).")
            end
        elseif need then
            local lib = _G.LibQuestieDB
            local ok, supported = false, nil
            if type(lib) == "table" and type(lib.RequireContract) == "function" then ok, supported = pcall(lib.RequireContract, need) end
            local have = Field("QuestieDB", "Version") or "?"
            if not (ok and supported == true) then
                add("questiedb:contract", ("This Questie needs QuestieDB's data contract %d, which QuestieDB %s doesn't give - Questie may show no quests. Update Questie and QuestieDB together."):format(need, have))
            end
        end
    end
end }

-- Sparkles_Forever with Mastercraft
CHECKS[#CHECKS + 1] = { "Sparkles", function(add)
    local spk, mcs = SPK(), MC()
    if spk and mcs then
        -- Mastercraft's bobber mark on, Sparkles' bobber effect off: Sparkles then turns the bobber's nameplate off,
        -- and Mastercraft's mark sits on it - so neither shows
        if spk.sparkleBobber == false and mcs.fishMarker ~= false then
            add("sparkles:bobber", "Mastercraft's fishing bobber mark is on but Sparkles' bobber effect is off - Sparkles then turns off the bobber's nameplate that Mastercraft's mark sits on, so your bobber isn't marked at all.",
                "Use Sparkles'", function() spk.sparkleBobber = true; mcs.fishMarker = false end)
        end
        -- "Switch Herbs and Ore for me" swaps your tracking every few seconds: with nodes shown "While tracking",
        -- Mastercraft's (and OpenMap_Tweaks', through the module) node pins blink in and out with it
        if spk.masterEnabled ~= false and spk.minimapAutoAlternate == true and spk.minimapResources == true
            and (mcs.nodesWhen or "tracking") == "tracking" then
            add("sparkles:alternate", "Sparkles' \"Switch Herbs and Ore for me\" swaps your tracking every few seconds, so gathering node pins shown \"While tracking\" blink in and out. Turn the switching off, or set When nodes show to Always.",
                "Turn off", function() spk.minimapAutoAlternate = false end)
        end
    end
end }

-- 4. Baganator settings pointing at addons that aren't loaded
CHECKS[#CHECKS + 1] = { "Baganator", function(add)
    local p = BAG()
    if p then
        local j = p.junk_plugin
        if BAG_JUNK_OWNER[j] and not OwnerLoaded(BAG_JUNK_OWNER[j]) then
            add("bagjunk:" .. j, ("Baganator's junk coin is set to \"%s\", whose addon isn't loaded (so only greys are marked)."):format(j), "Reset",
                function() SetBagPlugin(p, "junk", Loaded("MasterOptions_GearMatic_Baganator") and "gearmatic" or "poor_quality") end)
        end
        local u = p.upgrade_plugin
        if BAG_UPGRADE_OWNER[u] and not OwnerLoaded(BAG_UPGRADE_OWNER[u]) then
            add("bagupgrade:" .. u, ("Baganator's upgrade plugin is set to \"%s\", whose addon isn't loaded."):format(u), "Reset",
                function() SetBagPlugin(p, "upgrade", (Loaded("Pawn") and "pawn") or (Loaded("GearMatic") and "gearmatic_upgrade") or "none") end)
        end
        -- GearMatic 6.10's "Gold coin" vendor badge is the same icon as Baganator's junk coin ("will be sold")
        local gs = GM()
        if gs and gs.vendorMarkerStyle == "coin" and gs.bestGoldShowVendor ~= false and p.junk_plugin ~= "none" then
            add("bagcoin:gearmatic", "GearMatic's vendor badge is the gold coin, the same icon as Baganator's junk coin - so a coin in your bags may mean \"sold\" or only \"worth most at a vendor\". Switch GearMatic's badge to the gold $.",
                "Use Gold $", function() gs.vendorMarkerStyle = "dollar"; GMRefreshBagIcons() end)
        end
    end
end }

local function Problems()
    local ignored = (MasterOptionsDB and MasterOptionsDB.ignoredProblems) or {}
    local out = {}
    local function add(id, text, fixLabel, fix)
        if not ignored[id] then out[#out + 1] = { id = id, text = text, fixLabel = fixLabel, fix = fix } end
    end
    for _, check in ipairs(CHECKS) do
        local ok, err = pcall(check[2], add, out)
        -- (a row here, not the error log: a new error there refreshes this list - and would fail again)
        if not ok then add("check:" .. check[1], ("Master Options couldn't check %s: %s"):format(check[1], tostring(err))) end
    end
    return out
end

-- for the files after this one
MO.Problems = Problems
