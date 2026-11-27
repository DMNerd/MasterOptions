-- Master Options module: runs when Questie and Chattynator are loaded.
MasterOptions_Module("Questie_Chattynator", { "Questie", "Chattynator" }, function(ADDON)

-- Questie's quest links, shift-clicked again in Chattynator's chat.
--
-- Shift-click a Questie quest link in chat and the game puts the link into the chat box as it is; Questie then
-- rebuilds it from its quest data (QuestieLink.GetQuestLinkStringById: the current title and level, the right colour).
-- On clients with ChatFrameMixin.OnHyperlinkClick Questie does that from a hook on the game's chat windows only
-- (Modules\QuestLinks\Link.lua, _InstallHyperlinkClickHook: ChatFrame1..N) - Chattynator replaces those with its own
-- (its clicks reach ChattynatorHyperlinkHandler), so there the link stayed as clicked. Older clients go through
-- ChatFrame_OnHyperlinkShow, which Chattynator's handler calls too: nothing to do there.
-- The same rebuild here, from Chattynator's handler. Unlike Questie's own (which empties the chat box first), only the
-- link just put in is replaced: what you typed around it stays.

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON)

local function Escape(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end

local function Relink(link, button)
    if button ~= "LeftButton" or not IsShiftKeyDown() then return end
    local q = _G.Questie
    if not (type(q) == "table" and q.started) then return end
    local linkType, questId = strsplit(":", link or "")
    questId = tonumber(questId)
    if linkType ~= "questie" or not questId then return end
    local box = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    local loader = _G.QuestieLoader
    local QuestieLink = loader and loader.ImportModule and loader:ImportModule("QuestieLink")
    if not (box and QuestieLink and QuestieLink.GetQuestLinkStringById) then return end
    local fresh = QuestieLink.GetQuestLinkStringById(questId)
    if type(fresh) ~= "string" or fresh == "" then return end
    local text = box:GetText() or ""
    -- the link the game just put in: the last one with this link data
    local pattern = "|c%x%x%x%x%x%x%x%x|H" .. Escape(link) .. "|h.-|h|r"
    local at, last = 1, nil
    while true do
        local s, e = text:find(pattern, at)
        if not s then break end
        last, at = { s, e }, e + 1
    end
    if last then
        box:SetText(text:sub(1, last[1] - 1) .. fresh .. text:sub(last[2] + 1))
    else
        ChatEdit_InsertLink(fresh)
    end
end

local hooked = false
local function Hook()
    if hooked then return true end
    -- (only where Questie hooks the game's chat windows themselves - else its global hook covers Chattynator too)
    if not (ChatFrameMixin and ChatFrameMixin.OnHyperlinkClick) then hooked = true return true end
    local c = _G.Chattynator
    local handler = c and c.API and c.API.GetHyperlinkHandler and c.API.GetHyperlinkHandler()
    if not (handler and handler.HookScript) then return false end
    hooked = true
    handler:HookScript("OnHyperlinkClick", function(_, link, _, button)
        Check("relinking a Questie quest link", pcall(Relink, link, button))
    end)
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not Hook() then C_Timer.After(2, Hook) end
end)

MasterOptions_QuestieChattynator = { Relink = Relink } -- (for the tests)
end)
