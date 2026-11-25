-- Master Options error log: what went wrong in Master Options or one of its MasterOptions_* patches.
--
-- Two ways in:
--   * Lua errors nobody caught, whose message or call stack is in one of our folders (a chained error
--     handler: the game's own, or BugSack's if it was set first, still gets every error as before)
--   * errors our patches catch themselves (they pcall their work so a bug can't break your UI) and hand in
--     with MasterOptions_ReportError(addonName, where, err)
-- Kept in MasterOptionsDB.errors (so they're still there after a reload), the same error counted, not
-- repeated; at most MAX. /mo > Problems lists them, with Copy (the full text, for a bug report) and Clear.
--
-- Loaded first in MasterOptions.toc, and every patch loads after Master Options, so their load errors count too.

local MAX = 30
local pending = {}       -- before MasterOptionsDB is loaded
local said = false       -- the chat line: once per session
local recording = false  -- (an error while recording one: not recorded again)

local Log = {}
MasterOptions_ErrorLog = Log

local function Meta(addon, field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(get, addon, field)
    return ok and v or nil
end

local function List()
    if type(MasterOptionsDB) ~= "table" then return nil end
    MasterOptionsDB.errors = type(MasterOptionsDB.errors) == "table" and MasterOptionsDB.errors or {}
    return MasterOptionsDB.errors
end

local function Add(e)
    local list = List()
    if not list then pending[#pending + 1] = e; return end
    for i, old in ipairs(list) do
        if old.addon == e.addon and old.where == e.where and old.msg == e.msg then
            old.count = (old.count or 1) + (e.count or 1)
            old.last = e.last
            old.stack = old.stack or e.stack
            table.remove(list, i)
            table.insert(list, 1, old) -- (the latest first)
            return
        end
    end
    table.insert(list, 1, e)
    while #list > MAX do table.remove(list) end
end

local function Record(addon, where, msg, stack)
    if recording then return end
    recording = true
    pcall(function()
        local now = time()
        Add({ addon = addon or "?", where = where, msg = tostring(msg or "?"), stack = stack, count = 1,
              first = now, last = now, version = addon and Meta(addon, "Version") })
        if not said and type(MasterOptionsDB) == "table" then
            said = true
            print(("|cffffd200Master Options:|r %s hit an error. /mo > Problems shows it (Copy gives the text for a bug report)."):format(addon or "a patch"))
        end
        if Log.OnChange then pcall(Log.OnChange) end
    end)
    recording = false
end

-- for our patches: MasterOptions_ReportError(ADDON, "what it was doing", err)
function MasterOptions_ReportError(addon, where, err)
    Record(addon, where, err, nil)
end

---------------------------------------------------------------------------
-- Uncaught errors in our folders (the error handler, chained)
---------------------------------------------------------------------------
local OURS = "AddOns[/\\](MasterOptions[%w_]*)[/\\]"

local function Capture(msg)
    local s = tostring(msg)
    local addon = s:match(OURS)
    local stack = debugstack and debugstack(4, 12, 0) or nil
    if not addon and stack then addon = stack:match(OURS) end -- (raised elsewhere, called from our code)
    if addon then Record(addon, nil, s, stack) end
end

if geterrorhandler and seterrorhandler then
    local prev = geterrorhandler()
    seterrorhandler(function(msg, ...)
        pcall(Capture, msg)
        if prev then return prev(msg, ...) end
    end)
end

---------------------------------------------------------------------------
-- For Master Options' window
---------------------------------------------------------------------------
function Log.List() return List() or pending end

function Log.Count()
    local n = 0
    for _, e in ipairs(Log.List()) do n = n + 1 end
    return n
end

function Log.Clear()
    local list = List()
    if list then wipe(list) end
    wipe(pending)
    if Log.OnChange then pcall(Log.OnChange) end
end

-- Everything as plain text, for a bug report
function Log.Text()
    local out = {}
    local client = (GetBuildInfo and table.concat({ GetBuildInfo() }, " ")) or "?"
    out[#out + 1] = ("Master Options %s - client %s - %s"):format(Meta("MasterOptions", "Version") or "?", client, date("%Y-%m-%d %H:%M"))
    for i, e in ipairs(Log.List()) do
        out[#out + 1] = ""
        out[#out + 1] = ("#%d  %s %s%s  x%d  (first %s, last %s)"):format(i, e.addon, e.version or "",
            e.where and ("  [" .. e.where .. "]") or "", e.count or 1,
            date("%m-%d %H:%M", e.first or 0), date("%m-%d %H:%M", e.last or 0))
        out[#out + 1] = e.msg
        if e.stack and e.stack ~= "" then out[#out + 1] = e.stack end
    end
    return table.concat(out, "\n")
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= "MasterOptions" then return end
    MasterOptionsDB = MasterOptionsDB or {}
    local early = pending
    pending = {}
    for i = #early, 1, -1 do Add(early[i]) end
    f:UnregisterEvent("ADDON_LOADED")
end)
