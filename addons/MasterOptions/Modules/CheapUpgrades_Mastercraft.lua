-- Master Options module: runs when CheapUpgrades and Mastercraft are loaded.
MasterOptions_Module("CheapUpgrades_Mastercraft", { "CheapUpgrades", "Mastercraft" }, function(ADDON)

-- CheapUpgrades <- Mastercraft: three lines on the tooltip of an item CheapUpgrades calls an upgrade (its own tab's
-- tooltips too, the auction house's, a chat link's...):
--   Replaces Wolf Bracers: ~1g 20s back (disenchant)   - the piece it replaces (of two rings, trinkets or weapons:
--                                                         the weaker), and the most Mastercraft says it brings in -
--                                                         its own pick (vendor, auction or disenchant; bound counted)
--   You have one: Anathar (bank)                       - Mastercraft's record of every character's bags, bank, mail
--   You can craft it: Anathar (Leatherworking) - materials ~2g 10s
--                                                      - a recipe one of your characters has learned (Mastercraft's
--                                                         lists); its materials at Auctionator's prices (* = some
--                                                         have no price)
-- Your equipped pieces' values are read beforehand, quietly, when nothing is on screen (at login and when your gear
-- changes): a tooltip can't be read while another is being built. Nothing of either addon is changed.

local S = MasterOptions_Shared
local _, Check = S.ErrorReporters(ADDON)

local SLOTS = { -- equip location -> the equipped slots it goes in
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local VIA = { vendor = "vendor", auction = "auction house", disenchant = "disenchant" }

local Money = MasterOptions_Shared.Money
local function ItemID(link) return link and tonumber(link:match("item:(%d+)")) end
local function EquipLoc(link)
    local info = C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    return info and select(4, info(link)) or nil
end
local function ILvl(link)
    local f = C_Item and C_Item.GetDetailedItemLevelInfo or _G.GetDetailedItemLevelInfo
    return f and link and f(link) or 0
end

---------------------------------------------------------------------------
-- Your equipped pieces' worth, by Mastercraft (read beforehand: slot -> { link, value, via })
---------------------------------------------------------------------------
local worth = {}
local function ReadWorth()
    for slot = 1, 18 do
        local link = GetInventoryItemLink("player", slot)
        if not link then
            worth[slot] = nil
        elseif not (worth[slot] and worth[slot].link == link) then
            local v = S.QuietTooltip(S.ReadMastercraftValues, "SetInventoryItem", "player", slot) or {}
            local via = v.best
            if not via then -- (no pick shown: the most of what it gives)
                for _, k in ipairs({ "disenchant", "auction", "vendor" }) do
                    if v[k] and (not via or v[k] > v[via]) then via = k end
                end
            end
            worth[slot] = { link = link, value = via and v[via], via = via }
        end
    end
end
local ReadSoon
ReadSoon = S.Debounce(function()
    -- (not in a fight, not while an item's tooltip is on screen: a moment later)
    if (InCombatLockdown and InCombatLockdown()) or S.ItemTooltipShown() then ReadSoon(2) return end
    Check("reading your gear's worth", pcall(ReadWorth))
end, 1)

-- the piece an item replaces: its slot's (of two, the weaker - lower item level; an empty one first)
local function Replaced(link)
    local slots = SLOTS[EquipLoc(link) or ""]
    if not slots then return nil end
    local pick, pickLvl
    for _, slot in ipairs(slots) do
        local w = worth[slot]
        local lvl = w and ILvl(w.link) or -1
        if not w then return { empty = true } end
        if not pick or lvl < pickLvl then pick, pickLvl = w, lvl end
    end
    return pick
end

---------------------------------------------------------------------------
-- Mastercraft's records: who has it, who can make it
---------------------------------------------------------------------------
local function MC() local db = _G.MastercraftDB; return type(db) == "table" and db or nil end
local function CharName(db, key)
    local c = type(db.chars) == "table" and db.chars[key]
    return type(c) == "table" and c.name or tostring(key):match("^([^%-]+)") or tostring(key)
end

-- "Anathar (bank), Bob (bags)": who has the item (up to 3)
local function Owners(itemID)
    local db = MC()
    local out = {}
    for key, inv in pairs(db and type(db.inv) == "table" and db.inv or {}) do
        if type(inv) == "table" then
            local where = {}
            for _, place in ipairs({ "bags", "bank", "mail" }) do
                local t = inv[place]
                if type(t) == "table" and (t[itemID] or 0) > 0 then where[#where + 1] = place end
            end
            if #where > 0 then out[#out + 1] = ("%s (%s)"):format(CharName(db, key), table.concat(where, ", ")) end
        end
    end
    table.sort(out)
    if #out > 3 then out = { out[1], out[2], out[3], ("%d more"):format(#out - 3) } end
    return #out > 0 and table.concat(out, ", ") or nil
end

-- what each learned recipe makes: itemID -> { { who, prof, reagents } } (made again when Mastercraft's lists change)
local makers, makersFrom
local function Makers()
    local db = MC()
    local recipes = db and db.recipes
    if makers and makersFrom == recipes then return makers end
    makers, makersFrom = {}, recipes
    for key, profs in pairs(type(recipes) == "table" and recipes or {}) do
        for prof, data in pairs(type(profs) == "table" and profs or {}) do
            for _, r in ipairs(type(data) == "table" and type(data.list) == "table" and data.list or {}) do
                if type(r) == "table" and r.learned and type(r.output) == "number" then
                    makers[r.output] = makers[r.output] or {}
                    table.insert(makers[r.output], { who = CharName(db, key), prof = prof, reagents = r.reagents or {} })
                end
            end
        end
    end
    return makers
end

local function Price(itemID)
    local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then return nil end
    local ok, p = pcall(api.GetAuctionPriceByItemID, "Master Options", itemID)
    return ok and type(p) == "number" and p > 0 and p or nil
end

-- the cheapest way one of your characters makes it: who, profession, its materials' cost, whether a price was missing
local function Craft(itemID)
    local best
    for _, m in ipairs(Makers()[itemID] or {}) do
        local cost, missing = 0, false
        for _, rg in ipairs(m.reagents) do
            local p = rg.itemID and Price(rg.itemID)
            if p then cost = cost + p * (rg.qty or 1) else missing = true end
        end
        if not best or (cost < best.cost and not missing) or (best.missing and not missing) then
            best = { who = m.who, prof = m.prof, cost = cost, missing = missing }
        end
    end
    return best
end

---------------------------------------------------------------------------
-- The tooltip lines
---------------------------------------------------------------------------
local GREY, GOLD = { 0.6, 0.6, 0.6 }, { 1, 0.82, 0 }
local function Lines(link)
    local out = {}
    local itemID = ItemID(link)
    if not itemID then return out end
    local r = Replaced(link)
    if r and r.empty then
        out[#out + 1] = "Fills an empty slot"
    elseif r and r.link then
        local name = r.link:match("%[(.-)%]") or "?"
        out[#out + 1] = r.value and ("Replaces %s: ~%s back (%s)"):format(name, Money(r.value), VIA[r.via] or r.via)
            or ("Replaces %s (Mastercraft has no price for it)"):format(name)
    end
    local owners = Owners(itemID)
    if owners then out[#out + 1] = "You have one: " .. owners end
    local c = Craft(itemID)
    if c then
        out[#out + 1] = ("You can craft it: %s (%s) - materials ~%s%s"):format(c.who, c.prof, Money(c.cost), c.missing and "*" or "")
    end
    return out
end

local function OnTooltip(tip, data)
    if not (tip == GameTooltip or tip == _G.ItemRefTooltip) or S.ReadingTooltip(tip) then return end
    local _, link = tip:GetItem()
    if not link or not SLOTS[EquipLoc(link) or ""] then return end
    if not S.CheapUpgradesBadge(link) then return end -- (only what CheapUpgrades calls an upgrade)
    local lines = Lines(link)
    if #lines == 0 then return end
    tip:AddLine("Master Options - Mastercraft", GREY[1], GREY[2], GREY[3])
    for _, l in ipairs(lines) do tip:AddLine(l, GOLD[1], GOLD[2], GOLD[3], true) end
    tip:Show()
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if TooltipDataProcessor and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
                Check("adding the upgrade lines", pcall(OnTooltip, tip, data))
            end)
        end
        ReadSoon(3)
    else
        ReadSoon()
    end
end)

MasterOptions_CUMastercraft = { Lines = Lines, ReadWorth = ReadWorth } -- (for the tests)
end)
