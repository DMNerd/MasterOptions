-- Master Options module (was the addon MasterOptions_DialogKey_Pawn): runs when DialogKey_Numy is loaded.
MasterOptions_Module("DialogKey_Pawn", { "DialogKey_Numy" }, function(ADDON)

-- DialogKey <-> Pawn / GearMatic quest reward patch.
--
-- Pawn and GearMatic both mark the best quest reward with an arrow, but DialogKey makes you pick the reward
-- with a number key first. On the reward screen this patch selects the best choice itself - the same as
-- clicking it - so DialogKey's key (or the Complete Quest button) takes it straight away. Click or press a
-- number to take something else.
--
-- Whose pick (set in /mo, saved in MasterOptions_DialogKeyPawnDB.mode):
--   "pawn"      the choice Pawn rates the biggest upgrade with the scales this character shows in Pawn
--   "gearmatic" the choice GearMatic marks as an upgrade for this character (Pawn breaks a tie)
--   "off"       nothing is pre-selected
-- When no choice is an upgrade, the one that sells to a vendor for the most is selected (as both mark it).

local Loaded = MasterOptions_Shared.AddOnLoaded
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function Mode()
    local d = _G.MasterOptions_DialogKeyPawnDB
    local m = type(d) == "table" and d.mode or "pawn"
    if m == "pawn" and not Loaded("Pawn") then m = Loaded("GearMatic") and "gearmatic" or "off" end
    if m == "gearmatic" and not Loaded("GearMatic") then m = Loaded("Pawn") and "pawn" or "off" end
    return m
end

local function DialogKey()
    local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
    return AceAddon and AceAddon:GetAddon("DialogKey_Numy", true)
end

-- Pawn: the biggest upgrade % across the scales Pawn shows for this character (nil = not an upgrade,
-- false = Pawn hasn't got the item yet)
local PawnUpgrade = MasterOptions_Shared.PawnUpgradePercent

-- GearMatic: is it an upgrade for this character (not only for an alt)?
local function GearMaticUpgrade(link)
    local gm = _G.GearMatic
    local bo = type(gm) == "table" and gm.BagOverlay
    if not (bo and bo.MarkerVerdict) then return nil end
    local ok, v = pcall(bo.MarkerVerdict, link)
    if not ok then return nil end
    return type(v) == "table" and v.upgrade == true and not v.alt
end

local function MostValuable(choices)
    local gm = _G.GearMatic
    local qrh = type(gm) == "table" and gm.QuestRewardHook
    if qrh and qrh._mostValuable then
        local ok, idx = pcall(qrh._mostValuable, choices)
        if ok and idx then return idx end
    end
    local bestIdx, bestValue = nil, 0
    for _, c in ipairs(choices) do
        local v = (c.price or 0) * (c.count or 1)
        if v > bestValue then bestIdx, bestValue = c.idx, v end
    end
    return bestIdx
end

-- the index to select, or nil (or "wait" while item data is still loading)
local function Pick(mode)
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    if n < 2 then return nil end
    local choices, bestIdx, bestScore, waiting = {}, nil, nil, false
    for i = 1, n do
        local link = GetQuestItemLink and GetQuestItemLink("choice", i)
        if not link or not GetInfo(link) then
            waiting = true
        else
            local _, _, count = GetQuestItemInfo("choice", i)
            choices[#choices + 1] = { idx = i, price = select(11, GetInfo(link)), count = count }
            local score
            if mode == "pawn" then
                local pct = PawnUpgrade(link)
                if pct == false then waiting = true elseif pct then score = pct end
            else
                if GearMaticUpgrade(link) then
                    score = 1 + (PawnUpgrade(link) or 0) -- Pawn breaks a tie
                end
            end
            if score and (not bestScore or score > bestScore) then bestIdx, bestScore = i, score end
        end
    end
    if bestIdx then return bestIdx end
    if waiting then return "wait" end
    return MostValuable(choices)
end

local function ButtonFor(i)
    if QuestInfo_GetRewardButton and QuestInfoFrame and QuestInfoFrame.rewardsFrame then
        local b = QuestInfo_GetRewardButton(QuestInfoFrame.rewardsFrame, i)
        if b then return b end
    end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
end

local function Select(idx)
    local dk = DialogKey()
    -- the player already chose (number key or click): leave it
    if dk and dk.itemChoice and dk.itemChoice > 0 then return end
    if QuestInfoFrame and QuestInfoFrame.itemChoice and QuestInfoFrame.itemChoice > 0 then return end
    local button = ButtonFor(idx)
    if button and QuestInfoItem_OnClick and not IsModifierKeyDown() then
        pcall(QuestInfoItem_OnClick, button) -- the same as clicking it: highlight + Blizzard's own choice
    end
    if QuestInfoFrame then QuestInfoFrame.itemChoice = idx end
    if dk then dk.itemChoice = idx end
end

local tries = 0
local function Try()
    if not (QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible()) then return end
    local mode = Mode()
    if mode == "off" then return end
    local idx = Pick(mode)
    if idx == "wait" then
        tries = tries + 1
        if tries <= 10 then C_Timer.After(0.2, Try) end -- up to 2 s for the server to send item data
        return
    end
    if idx then Select(idx) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("QUEST_COMPLETE")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            MasterOptions_DialogKeyPawnDB = MasterOptions_DialogKeyPawnDB or {}
            MasterOptions_DialogKeyPawnDB.mode = MasterOptions_DialogKeyPawnDB.mode or "pawn"
        end
    else
        -- after DialogKey resets its choice and the reward buttons are drawn
        tries = 0
        C_Timer.After(0.1, Try)
    end
end)

MasterOptions_Shared.ReplayAddonLoaded(f, ADDON) -- (its ADDON_LOADED setup, now: the saved variables are in)
end)
