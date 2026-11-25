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

-- (a caught error goes to Master Options' error log: /mo > Problems)
local function Report(where, err)
    local r = _G.MasterOptions_ReportError
    if r then r("MasterOptions_DeleteCheapestItem_Protect", where, err) end
end

local function GM() local g = _G.GearMatic; return type(g) == "table" and g or nil end

local function PawnUpgrade(link)
    -- (Master Options' shared check: also every spec's scale while Pawn follows GearMatic's spec)
    if type(_G.MasterOptions_PawnKeeps) == "function" then return MasterOptions_PawnKeeps(link) end
    if type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return false end
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    -- an upgrade for a scale you show, or already your best or second-best item for one (Pawn's 3rd / 4th
    -- returns: an off-spec piece you keep in your bags is never "an upgrade", but it is your best)
    local ok2, up, _, best, second = pcall(_G.PawnIsItemAnUpgrade, item)
    if not ok2 then return false end
    for _, t in ipairs({ up or false, best or false, second or false }) do
        if type(t) == "table" and next(t) ~= nil then return true end
    end
    return false
end

local function GearMaticKeeps(link, bag, slot, itemID)
    local gm = GM()
    if not gm then return false end
    local bo = gm.BagOverlay
    if bo and bo.MarkerVerdict then
        local ok, v = pcall(bo.MarkerVerdict, link, bag, slot)
        if ok and type(v) == "table" and (v.upgrade or v.alt or v.skull) then return true end
    end
    local va = gm.VendorAutomation
    if va and va.InEquipmentSet then
        local ok, inSet = pcall(va.InEquipmentSet, bag, slot, itemID)
        if ok and inSet then return true end
    end
    return false
end

-- GearMatic loadouts: every item ID in them
local function LoadoutIDs()
    local ids = {}
    local gm = GM()
    local store = gm and gm.Loadouts and gm.Loadouts.Store
    if not (store and store.List and store.Get) then return ids end
    local ok, names = pcall(store.List)
    for _, name in ipairs(ok and names or {}) do
        local e = store.Get(name)
        for _, s in pairs(type(e) == "table" and e.slots or {}) do
            if type(s) == "table" and s.itemID then ids[s.itemID] = true end
        end
    end
    return ids
end

local function Protected()
    local want = {}
    local keep = _G.MasterOptions_MastercraftKeep
    local loadouts = LoadoutIDs()
    local numSlots = C_Container.GetContainerNumSlots
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
                    if PawnUpgrade(link) or GearMaticKeeps(link, bag, slot, id) then want[id] = true end
                end
            end
        end
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

local pending = false
local function Queue(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 1, function() pending = false; Sync() end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Queue(4) -- after Pawn, GearMatic and Mastercraft have set up
    elseif event == "BAG_UPDATE_DELAYED" then
        Sync() -- at once: new loot is protected before DeleteCheapestItem looks at the bags
    else
        Queue(1)
    end
end)
end)
