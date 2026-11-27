-- Master Options module: runs when Dungeon Journal (ForeverDungeonJournal) is loaded.
MasterOptions_Module("DungeonJournal_Upgrades", { "ForeverDungeonJournal" }, function(ADDON)

-- Dungeon Journal -> upgrade marks on its loot.
--
-- Dungeon Journal lists every boss's loot (and recipes' items, quest rewards, PvP rewards), but whether a piece
-- is an upgrade for you only shows when you hover it. This marks each item row, by the same judge as the rest
-- of Master Options (MasterOptions_Shared.UpgradeJudge: Pawn with Pawn Forever installed, else GearMatic):
--   arrow, top left of the icon   an upgrade: Pawn's arrow, or GearMatic's chevron (its alt colour when it's an
--                                 upgrade for one of your other characters only)
--   "+23%", left of the star      how big: Pawn's percent, or CheapUpgrades' badge (which follows GearMatic's
--                                 weights with CheapUpgrades_GearMatic)
--   skull, top right of the icon  GearMatic: best in slot for you
--   cog, bottom left of the icon  Mastercraft: your crafting guides need it, you track it, or its advice is KEEP
--                                 (Mastercraft_Keep's MasterOptions_MastercraftKeep.IsNeeded)
-- Every row Dungeon Journal draws for an item goes through its FDJ.UpdateFavouriteIndicator(row, itemID) (the
-- favourite star at the row's right): hooked there. An item the game hasn't sent yet is marked when it arrives;
-- your gear or talents changing marks the rows again. Dungeon Journal itself is only read.

local FDJ = _G.ForeverDungeonJournal_NS
if type(FDJ) ~= "table" or type(FDJ.UpdateFavouriteIndicator) ~= "function" then return end

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)
local Shared = MasterOptions_Shared
local GetInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local PAWN_ARROW = "Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow"
local NEEDED_ICON = "Interface\\Icons\\INV_Misc_Gear_01" -- (the crafting mark)

local rows = setmetatable({}, { __mode = "k" }) -- rows marked (weak: they go with Dungeon Journal's frames)

-- what to show for an item: { arrow = "pawn" | "up" | "alt" | nil, text = "+23%" | nil, skull = bool,
-- needed = bool }, or nil while the item (or CheapUpgrades) isn't ready
local function Marks(itemID)
    local _, link = GetInfo(itemID)
    if not link then return nil end
    local keep = _G.MasterOptions_MastercraftKeep
    local out = { skull = false, needed = type(keep) == "table" and type(keep.IsNeeded) == "function"
        and keep.IsNeeded(itemID) == true or false }
    local gm = _G.GearMatic
    local bo = type(gm) == "table" and gm.BagOverlay
    local verdict = bo and type(bo.MarkerVerdict) == "function" and bo.MarkerVerdict(link) or nil
    if type(verdict) == "table" then out.skull = verdict.skull == true end
    if Shared.UpgradeJudge() == "Pawn" then
        local pct = Shared.PawnUpgradePercent(link)
        if pct == false then return nil end
        if pct then
            out.arrow = "pawn"
            out.text = ("|cff00ff00+%.0f%%|r"):format(pct * 100)
        end
    else
        if type(verdict) == "table" and verdict.upgrade then out.arrow = verdict.alt and "alt" or "up" end
        local badge = Shared.CheapUpgradesBadge(link)
        if badge == nil then return nil end
        if badge then out.text = badge end
    end
    return out
end

local function Parts(row)
    if row.moUpgrade then return row.moUpgrade end
    local icon = row.icon or row.Icon
    local anchor = (type(icon) == "table" and icon.GetObjectType) and icon or row
    local p = { anchor = anchor }
    p.arrow = row:CreateTexture(nil, "OVERLAY", nil, 7)
    p.arrow:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
    p.skull = row:CreateTexture(nil, "OVERLAY", nil, 7)
    p.skull:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 3, 3)
    p.needed = row:CreateTexture(nil, "OVERLAY", nil, 7)
    p.needed:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -2, -2)
    p.needed:SetTexture(NEEDED_ICON)
    p.needed:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.text:SetPoint("RIGHT", row, "RIGHT", -27, 0) -- (left of Dungeon Journal's star, 15 wide at -8)
    row.moUpgrade = p
    return p
end

local function Paint(row, itemID)
    local p = Parts(row)
    local m = itemID and Marks(itemID)
    p.arrow:Hide(); p.skull:Hide(); p.text:Hide(); p.needed:Hide()
    if not m then return m == nil and itemID ~= nil end -- (true: ask again when the item arrives)
    local size = math.max(10, math.floor((p.anchor:GetHeight() or 38) * 0.42 + 0.5))
    local gm = _G.GearMatic
    if m.arrow == "pawn" then
        p.arrow:SetTexture(PAWN_ARROW); p.arrow:SetTexCoord(0, 1, 0, 1)
        p.arrow:SetSize(size * 0.9, size); p.arrow:Show()
    elseif m.arrow and type(gm) == "table" and type(gm.ApplyUpgradeArrow) == "function" then
        gm.ApplyUpgradeArrow(p.arrow, m.arrow)
        p.arrow:SetSize(size, size); p.arrow:Show()
    end
    if m.skull and type(gm) == "table" and type(gm.ApplyBiSSkull) == "function" then
        gm.ApplyBiSSkull(p.skull)
        p.skull:SetSize(size * 1.3, size * 1.3); p.skull:Show()
    end
    if m.text then p.text:SetText(m.text); p.text:Show() end
    if m.needed then p.needed:SetSize(size, size); p.needed:Show() end
    return false
end

-- The rows on screen marked again, a moment later (several events in a row: once). Only what's on screen: a row
-- of a closed journal stays IsShown (its window is hidden, not the row), so IsVisible. GET_ITEM_INFO_RECEIVED
-- comes for every item the game sends anywhere (bags, auction scans, tooltips): it marks again only the rows
-- still waiting for their item (row.moWaiting), and nothing while the journal is closed. Your gear, talents or
-- level changing: every row on screen. CheapUpgrades still starting up is asked again by a timer, a few times.
local waiting, retries, everyRow = false, 0, false
local MAX_RETRIES = 5
local function Visible(row) return type(row.IsVisible) == "function" and row:IsVisible() end

local function PaintRow(row, itemID)
    local ok, again = Check("marking Dungeon Journal's loot", pcall(Paint, row, itemID))
    row.moWaiting = ok and again or nil
    return row.moWaiting
end

local function MarkLater(retry, all)
    if all then everyRow = true end
    if waiting then return end
    if retry then
        if retries >= MAX_RETRIES then return end
        retries = retries + 1
    end
    waiting = true
    C_Timer.After(retry and 2 or 0.3, function()
        waiting = false
        local whole = everyRow
        everyRow = false
        local pending = false
        for row in pairs(rows) do
            if Visible(row) and (whole or row.moWaiting) and PaintRow(row, row.fdjFavouriteItemID) then pending = true end
        end
        if pending then MarkLater(true) else retries = 0 end
    end)
end

local function AnyWaitingOnScreen()
    for row in pairs(rows) do if row.moWaiting and Visible(row) then return true end end
    return false
end

hooksecurefunc(FDJ, "UpdateFavouriteIndicator", function(row, itemID)
    if type(row) ~= "table" or type(row.CreateTexture) ~= "function" then return end
    rows[row] = true
    if PaintRow(row, tonumber(itemID)) then MarkLater(true) end
end)

local f = CreateFrame("Frame")
for _, e in ipairs({ "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
    if not next(rows) then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        -- (thousands of these in an auction house scan: nothing to look at while Dungeon Journal's window is closed)
        local journal = _G.ForeverDungeonJournalFrame
        if journal and journal.IsVisible and not journal:IsVisible() then return end
        if AnyWaitingOnScreen() then retries = 0; MarkLater() end
    else
        retries = 0; MarkLater(false, true)
    end
end)
end)
