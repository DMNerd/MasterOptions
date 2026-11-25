-- Master Options module: runs when GearMatic is loaded.
MasterOptions_Module("GearMatic_SellGuard", { "GearMatic" }, function(ADDON)

-- GearMatic's official way for another addon to keep an item its gear and low-value selling rules would sell:
-- VendorAutomation.RegisterSellGuard(name, fn(link, bag, slot)) -> true keeps it (any guard keeping it wins).
-- Master Options' guard keeps:
--   * anything on the never-sell list (Modules\NeverSell.lua; also in GearMatic's sellIgnore - this is the
--     second lock)
--   * materials Mastercraft's guides or your item tracker still need (Modules\Mastercraft_Keep.lua)
--   * gear Pawn says is an upgrade, or already your best or second-best item, for a scale you show - an
--     off-spec piece in your bags, which GearMatic's own scoring (one spec) can call outgrown
-- GearMatic asks guards only in those two rules: its junk list and items you marked "always sell" stay yours.

local function ItemID(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end

local function PawnKeeps(link)
    -- (Master Options' shared check: also every spec's scale while Pawn follows GearMatic's spec)
    if type(_G.MasterOptions_PawnKeeps) == "function" then return MasterOptions_PawnKeeps(link) end
    if type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return false end
    local ok, item = pcall(_G.PawnGetItemData, link)
    if not ok or type(item) ~= "table" then return false end
    local ok2, up, _, best, second = pcall(_G.PawnIsItemAnUpgrade, item)
    if not ok2 then return false end
    for _, t in ipairs({ up or false, best or false, second or false }) do
        if type(t) == "table" and next(t) ~= nil then return true end
    end
    return false
end

local function Keeps(link, bag, slot)
    local id = ItemID(link)
    if id then
        local ns = _G.MasterOptions_NeverSell
        if ns and ns.Has and ns.Has(id) then return true end
        local keep = _G.MasterOptions_MastercraftKeep
        if keep and keep.IsNeeded and keep.IsNeeded(id) then return true end
    end
    return PawnKeeps(link)
end

local gm = _G.GearMatic
local va = type(gm) == "table" and gm.VendorAutomation
if type(va) == "table" and type(va.RegisterSellGuard) == "function" then
    va.RegisterSellGuard("MasterOptions", function(link, bag, slot)
        local ok, keep = pcall(Keeps, link, bag, slot)
        if not ok then
            if _G.MasterOptions_ReportError then MasterOptions_ReportError(ADDON, "GearMatic's sell guard", keep) end
            return true -- (an error keeps the item: never sold by a guess)
        end
        return keep
    end)
end
end)
