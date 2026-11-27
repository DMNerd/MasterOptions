-- Master Options module: runs always (it watches every addon's hidden whispers).
MasterOptions_Module("Chat_AddonWhispers", {}, function(ADDON)

-- "No player named 'X' is currently playing." for whispers you never sent.
--
-- Addons talk to each other's copies with hidden addon messages, some of them whispered to one player: OpenMap
-- (map sharing with friends), Questie (its party and guild sync), Details, Auctionator, Mastercraft (finding
-- crafters). Whisper someone who has just logged off and the server answers with that system line - in your chat,
-- though you sent nothing. Mastercraft hides the ones its own whispers cause; the others don't.
--
-- This hides the line when the player named was the target of an addon's hidden whisper (any addon:
-- C_ChatInfo.SendAddonMessage, hooked where it's called, so a queued message counts when it's really sent) in
-- the last 10 seconds - unless you typed a whisper to that name in that time yourself (SendChatMessage): your
-- own "not online" answers always show.

local WINDOW = 10 -- seconds (the server answers at once; Mastercraft uses the same)
local addonTo, typedTo = {}, {} -- [name key] = GetTime()

local function Now() return GetTime() end

-- "Name-Realm" / "First Last-Realm" -> "name" / "first last" (lower case, no realm)
local function Key(name)
    if type(name) ~= "string" or name == "" then return nil end
    name = name:gsub("%-[^%-]*$", "") -- (a realm after the last dash: names themselves have no dash)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and name:lower() or nil
end

-- the server's line names the player as the whisper was addressed, a first name only, or first and last
local function Same(a, b)
    if a == b then return true end
    local firstA, firstB = a:match("^(%S+)"), b:match("^(%S+)")
    return (not a:find(" ", 1, true) and firstB == a) or (not b:find(" ", 1, true) and firstA == b)
end

local function Recent(list, key, now)
    for k, at in pairs(list) do
        if now - at > WINDOW then list[k] = nil
        elseif Same(k, key) then return true end
    end
    return false
end

-- which addon sent it: the first addon folder in the call stack that isn't a library or Master Options
local recent = {} -- the last whispers: { at, name, addon, prefix, hidden }
local function Sender()
    local ok, stack = pcall(_G.debugstack, 3, 12, 0)
    if not ok or type(stack) ~= "string" then return "?" end
    for folder, rest in stack:gmatch("AddOns[/\\]([^/\\]+)[/\\]([^\n]*)") do
        if folder ~= "MasterOptions" and not rest:find("^[Ll]ibs?[/\\]") then return folder end
    end
    return "?"
end

-- old entries out of the name lists, now and then (Filter prunes them too, but only when a line comes)
local sinceTidy = 0
local function Tidy(now)
    sinceTidy = sinceTidy + 1
    if sinceTidy < 64 then return end
    sinceTidy = 0
    for _, list in ipairs({ addonTo, typedTo }) do
        for k, at in pairs(list) do if now - at > WINDOW then list[k] = nil end end
    end
end

local function OnAddonMessage(prefix, text, channel, target)
    if channel == "WHISPER" then
        local k = Key(target)
        if k then
            local now = Now()
            addonTo[k] = now
            -- (an addon's sync sends many at once: the same whisper again within a second is the same entry - no
            -- call stack read for it)
            local top = recent[1]
            if top and top.name == target and top.prefix == tostring(prefix) and now - top.at < 1 then
                top.at = now
            else
                table.insert(recent, 1, { at = now, name = target, addon = Sender(), prefix = tostring(prefix) })
                if #recent > 30 then recent[#recent] = nil end
            end
            Tidy(now)
        end
    end
end
local function OnChat(msg, channel, language, target)
    if channel == "WHISPER" then
        local k = Key(target)
        if k then typedTo[k] = Now() end
    end
end
if hooksecurefunc then
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(hooksecurefunc, C_ChatInfo, "SendAddonMessage", OnAddonMessage) end
    if C_ChatInfo and C_ChatInfo.SendAddonMessageLogged then pcall(hooksecurefunc, C_ChatInfo, "SendAddonMessageLogged", OnAddonMessage) end
    if _G.SendAddonMessage then pcall(hooksecurefunc, "SendAddonMessage", OnAddonMessage) end
    if _G.SendChatMessage then pcall(hooksecurefunc, "SendChatMessage", OnChat) end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then pcall(hooksecurefunc, C_ChatInfo, "SendChatMessage", OnChat) end
end

-- the game's own "No player named '%s' is currently playing." in this client's language, as a pattern
local notFound
local function NotFoundName(msg)
    if type(msg) ~= "string" or type(_G.ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return nil end
    if not notFound then
        local p = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("%%%d?%$?s", "\001", 1)
        p = p:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        notFound = "^" .. p:gsub("\001", "(.+)") .. "$"
    end
    return msg:match(notFound)
end

local function Filter(_, _, msg)
    local name = NotFoundName(msg)
    local k = name and Key(name)
    if not k then return false end
    local now = Now()
    if Recent(typedTo, k, now) then return false end -- (you whispered them: your answer shows)
    if not Recent(addonTo, k, now) then return false end
    for _, r in ipairs(recent) do
        local rk = Key(r.name)
        if rk and Same(rk, k) then r.hidden = (r.hidden or 0) + 1; break end
    end
    return true
end

-- /mo whispers: the last hidden whispers addons sent, who to and which addon - and which "No player named" lines
-- that hid
local function List()
    local head = "|cffffd200Master Options:|r "
    if #recent == 0 then print(head .. "no addon has whispered anyone since you logged in.") return end
    print(head .. "the last hidden whispers addons sent (newest first; \"not online\" = its \"No player named\" line hidden):")
    local now = Now()
    for i, r in ipairs(recent) do
        if i > 15 then break end
        print(("  %ds ago  |cffffffff%s|r -> %s  |cff9d9d9d(%s)|r%s"):format(math.floor(now - r.at), r.addon, r.name, r.prefix,
            r.hidden and ("  |cffff8080not online|r" .. (r.hidden > 1 and (" x" .. r.hidden) or "")) or ""))
    end
end
if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", Filter)
elseif ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", Filter)
end

MasterOptions_AddonWhispers = { List = List, Recent = function() return recent end } -- (for the tests)
MasterOptions_Shared.Command("whispers", List, "whispers - which addon whispered whom (the hidden \"No player named\" lines)")
end)
