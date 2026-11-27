-- Master Options module (was the addon MasterOptions_DeleteCheapestItem_Protect): runs when DeleteCheapestItem is loaded.
MasterOptions_Module("DeleteCheapestItem_Protect", { "DeleteCheapestItem" }, function(ADDON)

-- DeleteCheapestItem <-> Pawn / GearMatic / Mastercraft protection patch.
--
-- DeleteCheapestItem offers the cheapest item in your bags for deletion, guarded only by its own ignore
-- list (and "hide soulbound"). It knows nothing of upgrades or sets, and a fishing pole or skinning knife is
-- about the cheapest thing you carry. Deleting can't be undone.
--
-- Its functions are private, so this patch keeps entries in its saved ignore list (DCI_CharDB.IgnoredItems,
-- per character) for what's in your bags and must not be offered:
--   * upgrades: Pawn says so (any scale you show), or GearMatic marks an upgrade for you or an alt
--   * GearMatic best-in-slot items
--   * pieces of an equipment set or a GearMatic loadout
--   * profession tools (mining pick, skinning knife, fishing poles, enchanting rods ...)
--   * materials Mastercraft says you need (with MasterOptions_Mastercraft_Keep)
-- What it added is listed in DCI_CharDB.moProtected and taken off again when no longer needed; entries you
-- added yourself are never touched.

local IsEquippable = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem

-- profession tools (Classic item IDs): never the "cheapest item" to delete
local TOOLS = {
    [2901] = true,  -- Mining Pick
    [7005] = true,  -- Skinning Knife
    [12709] = true, -- Finkle's Skinner
    [5956] = true,  -- Blacksmith Hammer
    [6219] = true,  -- Arclight Spanner
    [10498] = true, -- Gyromatic Micro-Adjustor
    [4471] = true,  -- Flint and Tinder
    [5060] = true,  -- Thieves' Tools
    [9149] = true,  -- Philosopher's Stone
    [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true, -- enchanting rods
    [6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true, -- fishing poles
}

local Report = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local Shared = MasterOptions_Shared
local PawnUpgrade = Shared.KeepsGear           -- (Pawn or GearMatic: Master Options' shared check)
local GearMaticKeeps = Shared.GearMaticKeeps   -- (GearMatic's bag verdict, equipment sets)
local LoadoutIDs = Shared.GearMaticLoadoutIDs  -- (GearMatic loadouts: every item ID in them)

-- Pawn's and GearMatic's word on each piece of gear, kept per link: this runs on every bag update (looting), and
-- asking them about every piece each time is the costly part. Asked again after an equipment, level or talent
-- change (Forget, below), and after 30 s anyway; a new item is asked at once.
local gearVerdict, gearAt = {}, 0
local function Forget() gearVerdict = {} end

local function Protected()
    local want = {}
    local now = GetTime and GetTime() or 0
    if now == 0 or now - gearAt > 30 then gearVerdict, gearAt = {}, now end
    local keep = _G.MasterOptions_MastercraftKeep
    local loadouts = LoadoutIDs()
    local numSlots = C_Container.GetContainerNumSlots
    -- 1. what's protected by itself; gear goes on a list for Pawn and GearMatic
    local gear, gearLinks = {}, {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, (numSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not want[id] then
                local link = info.hyperlink
                if TOOLS[id] or loadouts[id] then
                    want[id] = true
                elseif keep and keep.IsNeeded and keep.IsNeeded(id) then
                    want[id] = true
                elseif link and (info.quality or 1) > 0 and IsEquippable(link) then
                    local known = gearVerdict[link]
                    if known ~= nil then
                        if known then want[id] = true end
                    else
                        gear[#gear + 1] = { link = link, bag = bag, slot = slot, id = id }
                        gearLinks[#gearLinks + 1] = link
                    end
                end
            end
        end
    end
    -- 2. the gear not asked about yet: Pawn all at once (Master Options widens its scales once for the lot), then GearMatic
    if #gear == 0 then return want end
    local many = _G.MasterOptions_GearKeepsMany
    local pawnKeeps = type(many) == "function" and many(gearLinks) or nil
    for _, g in ipairs(gear) do
        local up
        if pawnKeeps then up = pawnKeeps[g.link] == true else up = PawnUpgrade(g.link) end
        local keeps = (up or GearMaticKeeps(g.link, g.bag, g.slot, g.id)) and true or false
        gearVerdict[g.link] = keeps
        if keeps then want[g.id] = true end
    end
    return want
end

local function Sync()
    local c = _G.DCI_CharDB
    if type(c) ~= "table" then return end
    c.IgnoredItems = c.IgnoredItems or {}
    c.moProtected = c.moProtected or {}
    local list, mine = c.IgnoredItems, c.moProtected
    local inList = {}
    for _, id in ipairs(list) do inList[id] = true end
    local ok, want = pcall(Protected)
    if not ok then Report("working out what to protect", want) return end
    for id in pairs(want) do
        if not inList[id] then
            table.insert(list, id)
            mine[id] = true
        end
    end
    for id in pairs(mine) do
        if not want[id] then
            for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
            mine[id] = nil
        end
    end
end

local Queue = MasterOptions_Shared.Debounce(function() Sync() end, 1)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")
for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Queue(4) -- after Pawn, GearMatic and Mastercraft have set up
    elseif event == "BAG_UPDATE_DELAYED" then
        Sync() -- at once: new loot is protected before DeleteCheapestItem looks at the bags
    else
        Forget() -- (what's an upgrade or your best changed)
        Queue(1)
    end
end)
end)
