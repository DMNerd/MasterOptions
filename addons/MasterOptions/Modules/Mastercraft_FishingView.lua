-- Master Options module (was the addon MasterOptions_Mastercraft_FishingView): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_FishingView", { "Mastercraft" }, function(ADDON)

-- Mastercraft fishing view <-> your other addons.
--
-- Mastercraft's Fishing > View "hide UI" sets UIParent's alpha to 0 and keeps only what it knows visible: its
-- own windows, Blizzard's chat frames and loot window, the tooltip. Other addons' windows go invisible - and
-- an invisible window still takes clicks (Mastercraft found that with its own pop-ups).
--
-- While the interface is hidden, this keeps visible (each shown one ignores its parent's alpha, as
-- Mastercraft does for its own; given back when the view ends or the window closes):
--   * Baganator's bag, bank and guild bank windows (was MasterOptions_Mastercraft_Baganator)
--   * DeleteCheapestItem's window (fishing fills your bags: it pops up then)
--   * confirmation pop-ups (StaticPopup) and loot rolls (GroupLootFrame)
-- And Chattynator: its windows ignore their parent's alpha anyway (they need to), so Mastercraft's own chat
-- setting never reached them. With Mastercraft's "hide chat while fishing" they are hidden now too; with
-- "only after a whisper", shown again for a while when one comes in.
--
-- Event-driven: only while the interface is hidden does a watcher run (5 times a second, to catch a window
-- opened then); the rest of the time this does nothing.

local WHISPER_SHOW = 15 -- seconds Chattynator's chat shows after a whisper ("only after a whisper")

local kept = {}         -- [frame] = its IsIgnoringParentAlpha before
local chatHidden = {}   -- [chat window] = its alpha before
local whisperUntil = 0

local function Keep(fr)
    if kept[fr] == nil then
        kept[fr] = fr:IsIgnoringParentAlpha() or false
        fr:SetIgnoreParentAlpha(true)
    end
end
local function Release(fr)
    if kept[fr] ~= nil then
        fr:SetIgnoreParentAlpha(kept[fr])
        kept[fr] = nil
    end
end

-- Baganator's windows: named per view, kind and skin
local VIEWS = { "Single", "Category" }
local KINDS = { "BackpackViewFrame", "BankViewFrame", "GuildViewFrame" }
local function BaganatorFrames(list)
    local api = type(Baganator) == "table" and type(Baganator.API) == "table" and Baganator.API.Skins
    local ok, skin = false, nil
    if api and api.GetCurrentSkin then ok, skin = pcall(api.GetCurrentSkin) end
    if not (ok and type(skin) == "string") then return end
    for _, view in ipairs(VIEWS) do
        for _, kind in ipairs(KINDS) do
            list[#list + 1] = _G["Baganator_" .. view .. "View" .. kind .. skin]
        end
    end
    list[#list + 1] = _G["Baganator_CharacterSelectFrame" .. skin]
end

local function Keepers()
    local list = {}
    BaganatorFrames(list)
    list[#list + 1] = _G.DCIFrame
    for i = 1, 4 do
        list[#list + 1] = _G["StaticPopup" .. i]
        list[#list + 1] = _G["GroupLootFrame" .. i]
    end
    return list
end

-- Chattynator's chat windows: the shown children of its link handler that are chat windows
local function ChatWindows()
    local out = {}
    local handler = _G.ChattynatorHyperlinkHandler
    if not (handler and handler.GetChildren) then return out end
    for _, child in ipairs({ handler:GetChildren() }) do
        if child.ScrollingMessages and child:IsShown() then out[#out + 1] = child end
    end
    return out
end

local function ChatWanted()
    local s = type(_G.MastercraftDB) == "table" and _G.MastercraftDB.settings
    local mode = type(s) == "table" and s.fishHideChat or "show"
    if mode == "show" then return true end
    -- typing: as Mastercraft does for the game's chat
    local active = _G.ChatEdit_GetActiveWindow or (_G.ChatFrameUtil and _G.ChatFrameUtil.GetActiveWindow)
    if active and active() then return true end
    if mode == "whisper" then return GetTime() < whisperUntil end
    return false
end

local function Update()
    local veiled = UIParent:GetAlpha() < 0.01
    local seen = {}
    if veiled then
        for _, f in ipairs(Keepers()) do
            if type(f) == "table" and f.SetIgnoreParentAlpha and f:IsShown() then Keep(f); seen[f] = true end
        end
    end
    for f in pairs(kept) do if not seen[f] then Release(f) end end
    -- Chattynator
    local hide = veiled and not ChatWanted()
    if hide then
        for _, w in ipairs(ChatWindows()) do
            if chatHidden[w] == nil then
                chatHidden[w] = w:GetAlpha()
                w:SetAlpha(0)
            end
        end
    else
        for w, a in pairs(chatHidden) do
            w:SetAlpha(a)
            chatHidden[w] = nil
        end
    end
end

local watcher = CreateFrame("Frame")
local wait = 0
local function Tick(_, dt)
    wait = wait + dt
    if wait < 0.2 then return end
    wait = 0
    Update()
end

local function OnAlpha()
    if UIParent:GetAlpha() < 0.01 then
        if not watcher:GetScript("OnUpdate") then
            wait = 0.2 -- check at once
            watcher:SetScript("OnUpdate", Tick)
        end
    else
        watcher:SetScript("OnUpdate", nil)
        Update() -- give everything back
    end
end

hooksecurefunc(UIParent, "SetAlpha", OnAlpha)
OnAlpha() -- in case the interface is already hidden (a reload mid-fishing)

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_WHISPER")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_BN_WHISPER")
ev:SetScript("OnEvent", function()
    whisperUntil = GetTime() + WHISPER_SHOW
    if UIParent:GetAlpha() < 0.01 then Update() end
end)
end)
