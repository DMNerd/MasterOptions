-- Master Options module: runs when GearMatic is loaded.
MasterOptions_Module("GearMatic_SpecKeep", { "GearMatic" }, function(ADDON)

-- GearMatic -> off-spec gear kept (selling, deleting), with or without Pawn.
--
-- GearMatic's bag verdict (upgrade chevron, best-in-slot skull) and its sell pass look at the spec you play
-- now only, so a piece that is your best for another spec - an off-spec weapon, a tank set in the bags - is
-- nothing to it. Pawn covered that (best / second-best per scale, MasterOptions_PawnKeeps), but only with Pawn
-- installed. This asks GearMatic itself: for every spec scale of your class (ScaleImport.GetScalesForClass),
-- is the item your best or second-best in its slot among what you own (Scoring2.BestItems, the same pools
-- behind its tooltip's "best" / "2nd best" lines)? Then it stays.
--
-- Leftovers from levelling: at max level an item that doesn't need max level never counts (GearMatic's own
-- band for those lines, BestItems.BadgeLevelBandPasses), or a level 40 mace would be kept forever.
--
-- Used through Master Options' MasterOptions_GearKeeps (Mastercraft_VendorSell, DeleteCheapestItem_Protect and
-- GearMatic_SellGuard, which GearMatic's own sell pass asks through its sell guard). GearMatic is only read.

local function Report(where, err)
    local r = _G.MasterOptions_ReportError
    if r then r(ADDON, where, err) end
end

local InstantInfo = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

-- what's needed from GearMatic, or nil
local function Parts()
    local gm = _G.GearMatic
    if type(gm) ~= "table" then return nil end
    local si, bi, c = gm.ScaleImport, gm.Scoring2 and gm.Scoring2.BestItems, gm.Compat
    if not (si and type(si.GetScalesForClass) == "function" and bi and type(bi.IsItemBestOrSecondBest) == "function"
        and c and type(c.CurrentCharKey) == "function") then return nil end
    return si, bi, c
end

-- this character's spec scales (one per spec), or nil
local function Scales(si, c)
    local okK, key = pcall(c.CurrentCharKey)
    if not (okK and key) then return nil end
    local okS, list = pcall(si.GetScalesForClass, key)
    if not okS or type(list) ~= "table" or #list == 0 then return nil end
    return list
end

local function KeepsOne(bi, scales, link)
    if type(link) ~= "string" then return false end
    local equipLoc = InstantInfo and select(4, InstantInfo(link))
    if type(equipLoc) ~= "string" or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return false end
    if type(bi.BadgeLevelBandPasses) == "function" then
        local okB, passes = pcall(bi.BadgeLevelBandPasses, link)
        if okB and passes == false then return false end
    end
    for _, scale in ipairs(scales) do
        local ok, best = pcall(bi.IsItemBestOrSecondBest, scale, equipLoc, link, true)
        if ok and best then return true end
    end
    return false
end

-- links: a list of item links -> { [link] = true } for each one GearMatic rates best or 2nd best for a spec
local function KeepsMany(links)
    local out = {}
    local si, bi, c = Parts()
    if not si then return out end
    local scales = Scales(si, c)
    if not scales then return out end
    for _, link in ipairs(links) do
        local ok, keep = pcall(KeepsOne, bi, scales, link)
        if not ok then Report("GearMatic's best items per spec", keep)
        elseif keep then out[link] = true end
    end
    return out
end

MasterOptions_GearMaticSpecKeeps = {
    Keeps = function(link) return KeepsMany({ link })[link] == true end,
    KeepsMany = KeepsMany,
}
end)
