-- Master Options: the /mo window, the recommended setup and the per-character choices kept the same on every
-- character.

local _, MO = ...
-- from the files before this one
local Loaded, OPTIONS, Problems, SyncIcons = MO.Loaded, MO.OPTIONS, MO.Problems, MO.SyncIcons
local SeedShared -- set below: copies this character's per-character choices to the account

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local rows = {}
MO.needsReload = false
local reloadBtn
local RefreshProblems -- set once the window exists

local function RefreshAll()
    -- (every change in the window or Options ends here: matched bag icons follow it)
    local ok, changed = pcall(SyncIcons)
    if ok and changed then MO.needsReload = true end
    for _, r in ipairs(rows) do r:Refresh() end
    if RefreshProblems then RefreshProblems() end
    if reloadBtn then reloadBtn:SetShown(MO.needsReload) end
end

local Available

-- Recommended setup, applied once per character on first load (and by the button).
-- Skips anything whose addon isn't loaded; returns how many rows it set.
-- An option's recommended value: a value, or a function (a choice that depends on what's installed, such as
-- Pawn when it is there and GearMatic when it isn't)
local function RecOf(opt)
    if type(opt.rec) == "function" then return opt.rec() end
    return opt.rec
end

local DEFAULTS_VERSION = 30
local Remember -- set below
local function ApplyRecommended(after, manual) -- after: only options added after this defaults version
    local n = 0
    for _, opt in ipairs(OPTIONS) do
        if opt.rec ~= nil and Available(opt) and (opt.since or 1) > (after or 0) then
            local want = RecOf(opt)
            if opt.kind == "choice" and not opt.needs and want ~= "Off" and want ~= opt.off and not Loaded(want) then want = nil end
            if want ~= nil and opt.get() ~= want then
                local ok = pcall(opt.set, want)
                if ok then
                    n = n + 1
                    if opt.reload then MO.needsReload = true end
                    if manual and Remember then Remember(opt) end
                end
            end
        end
    end
    RefreshAll()
    return n
end

-- Per-character rows kept the same on every character (MasterOptionsDB.shared[label] = value)
local function SharedStore()
    MasterOptionsDB.shared = MasterOptionsDB.shared or {}
    return MasterOptionsDB.shared
end
Remember = function(opt) -- after the player changed a row: keep it for the account
    if MasterOptionsDB and MasterOptionsDB.seedPending then
        MasterOptionsDB.seedPending = nil
        SeedShared()
    end
    if not (opt.scope and MasterOptionsDB and MasterOptionsDB.syncChars) then return end
    local ok, v = pcall(opt.get)
    if ok and v ~= nil and v ~= "Both (conflict)" and v ~= "Mixed" then SharedStore()[opt.label] = v end
end
SeedShared = function(onlyMissing)
    local store = SharedStore()
    for _, opt in ipairs(OPTIONS) do
        if opt.scope and Available(opt) and not (onlyMissing and store[opt.label] ~= nil) then
            local ok, v = pcall(opt.get)
            if ok and v ~= nil and v ~= "Both (conflict)" and v ~= "Mixed" then store[opt.label] = v end
        end
    end
end
-- at login: make this character match the account's choices; returns how many rows changed
local function ApplyShared()
    if not (MasterOptionsDB and MasterOptionsDB.syncChars) then return 0 end
    if MasterOptionsDB.seedPending then
        MasterOptionsDB.seedPending = nil
        SeedShared() -- just turned on: this character (after its recommended setup) is the template
        return 0
    end
    SeedShared(true) -- rows added since: start from this character
    local store, n = SharedStore(), 0
    for _, opt in ipairs(OPTIONS) do
        local want = opt.scope and store[opt.label]
        if want ~= nil and Available(opt) then
            local ok, cur = pcall(opt.get)
            if ok and cur ~= want and pcall(opt.set, want) then
                n = n + 1
                if opt.reload then MO.needsReload = true end
            end
        end
    end
    if n > 0 then RefreshAll() end
    return n
end

function Available(opt)
    if type(opt.needs_any) == "table" then -- (any one of these addons is enough)
        local any = false
        for _, n in ipairs(opt.needs_any) do if Loaded(n) then any = true break end end
        if not any then return false end
    end
    if type(opt.needs) == "table" then
        for _, n in ipairs(opt.needs) do if not Loaded(n) then return false end end
    elseif opt.needs and not Loaded(opt.needs) then
        return false
    end
    if opt.kind == "choice" and opt.needs then return true end
    if opt.kind == "choice" then
        for _, c in ipairs(opt.choices) do
            if c ~= "Off" and Loaded(c) then return true end
        end
        return false
    end
    return true
end

local function Tooltip(frame, opt)
    if not opt.tip then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(opt.label, 1, 1, 1)
        local text = opt.tip
        if type(text) == "function" then
            local ok, t = pcall(text); text = ok and t or nil
        end
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        if opt.scope then
            local synced = MasterOptionsDB and MasterOptionsDB.syncChars
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("Saved per %s by its addon. %s"):format(opt.scope,
                synced and "\"Same choices on every character\" is on: your choice is applied on every character at login."
                    or "Turn on \"Same choices on every character\" to keep it the same everywhere."), 0.44, 0.66, 0.86, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------
-- The window (/mo): sections on the left, the chosen section's settings on the right.
-- Each setting: its name, a short description, and a dropdown (choices) or a tick box.
-- A conflict ("Both (conflict)") tints the row red and marks its section; Problems is its own section.
---------------------------------------------------------------------------
local WIN_W, WIN_H = 680, 500
local SIDE_W = 160
local PANE_W = WIN_W - SIDE_W - 52
local CTRL_W = 160
local RED = { 1, 0.33, 0.33 }

local function ShortDesc(opt)
    if opt.desc then return opt.desc end
    local t = opt.tip
    if type(t) ~= "string" then return nil end
    local s = t:match("^(.-[%.!?])%s") or t
    if #s > 120 then s = s:sub(1, 117):gsub("%s+%S*$", "") .. "..." end
    return s
end

local function IsConflict(opt)
    if opt.kind ~= "choice" or not Available(opt) then return false end
    local ok, v = pcall(opt.get)
    return ok and v == "Both (conflict)"
end

-- Standalone window
local win = CreateFrame("Frame", "MasterOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
win:SetSize(WIN_W, WIN_H)
win:SetPoint("CENTER")
win:SetMovable(true)
win:SetClampedToScreen(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if MasterOptionsDB then MasterOptionsDB.winPos = { point, relPoint, x, y } end
end)
win:SetFrameStrata("DIALOG")
win:Hide()
tinsert(UISpecialFrames, "MasterOptionsFrame")
win.title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
win.title:SetPoint("TOP", 0, -5)
win.title:SetText("Master Options")

-- left: the sections
local side = CreateFrame("Frame", nil, win)
side:SetPoint("TOPLEFT", 10, -30)
side:SetPoint("BOTTOMLEFT", 10, 44)
side:SetWidth(SIDE_W)
local sideBg = side:CreateTexture(nil, "BACKGROUND")
sideBg:SetAllPoints()
sideBg:SetColorTexture(0, 0, 0, 0.25)
local divider = win:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 0.82, 0, 0.25)
divider:SetPoint("TOPLEFT", side, "TOPRIGHT", 4, 0)
divider:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 4, 0)
divider:SetWidth(1)

-- right: the chosen section, scrolling when long
local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", side, "TOPRIGHT", 12, 0)
scroll:SetPoint("BOTTOMRIGHT", -30, 44)
local body = CreateFrame("Frame", nil, scroll)
body:SetSize(PANE_W, 10)
scroll:SetScrollChild(body)

local sections = {}     -- { name, opts = {}, pane, button, height }
local current           -- the section shown

---------------------------------------------------------------------------
-- The choice menu: a small list under a dropdown button
---------------------------------------------------------------------------
local okMenu, menu = pcall(CreateFrame, "Frame", "MasterOptionsMenu", UIParent, "TooltipBackdropTemplate")
if not okMenu then
    -- (a client without that template: a plain dark box)
    menu = CreateFrame("Frame", "MasterOptionsMenu", UIParent)
    local bg = menu:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.95)
end
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:EnableMouse(true)
menu:Hide()
menu.rows = {}
tinsert(UISpecialFrames, "MasterOptionsMenu")
local menuWatch = CreateFrame("Frame", nil, menu)
pcall(menuWatch.RegisterEvent, menuWatch, "GLOBAL_MOUSE_DOWN")
menuWatch:SetScript("OnEvent", function()
    if menu:IsShown() and not menu:IsMouseOver() and not (menu.owner and menu.owner:IsMouseOver()) then menu:Hide() end
end)
win:HookScript("OnHide", function() menu:Hide() end)

local function Choose(opt, value)
    menu:Hide()
    pcall(opt.set, value)
    if opt.reload then MO.needsReload = true end
    Remember(opt)
    RefreshAll()
end

local function OpenMenu(owner, opt)
    if menu:IsShown() and menu.owner == owner then menu:Hide() return end
    local cur = select(2, pcall(opt.get))
    local list = {}
    for _, c in ipairs(opt.choices) do
        if c == "Off" or c == opt.off or opt.needs or Loaded(c) then list[#list + 1] = c end
    end
    local width = CTRL_W
    for i, c in ipairs(list) do
        local r = menu.rows[i]
        if not r then
            r = CreateFrame("Button", nil, menu)
            r:SetHeight(20)
            r:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 20)
            r:SetPoint("RIGHT", -8, 0)
            r.hl = r:CreateTexture(nil, "HIGHLIGHT")
            r.hl:SetAllPoints()
            r.hl:SetColorTexture(1, 0.82, 0, 0.15)
            r.check = r:CreateTexture(nil, "ARTWORK")
            r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            r.check:SetSize(16, 16)
            r.check:SetPoint("LEFT", 0, 0)
            r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", 20, 0)
            r.text:SetJustifyH("LEFT")
            menu.rows[i] = r
        end
        r.text:SetText(c .. (c == RecOf(opt) and "  |cff9d9d9d(recommended)|r" or ""))
        r.check:SetShown(c == cur)
        r:SetScript("OnClick", function() Choose(opt, c) end)
        width = math.max(width, (r.text:GetStringWidth() or 0) + 40)
        r:Show()
    end
    for i = #list + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(width, #list * 20 + 16)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
    menu.owner = owner
    menu:Show()
end

---------------------------------------------------------------------------
-- A setting's row
---------------------------------------------------------------------------
local function BuildRow(parent, opt, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:EnableMouse(true)
    Tooltip(row, opt)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 8, -7)
    label:SetPoint("RIGHT", row, "RIGHT", -(CTRL_W + 16), 0)
    label:SetJustifyH("LEFT")
    local tags = ""
    if opt.scope then tags = tags .. "  |cff6fa8dc(per char)|r" end
    if opt.reload then tags = tags .. "  |cffd8a44c(reload)|r" end
    label:SetText(opt.label .. tags)

    local desc = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", row, "RIGHT", -(CTRL_W + 16), 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(ShortDesc(opt) or "")

    local h = 14 + (label:GetStringHeight() or 12) + ((desc:GetText() or "") ~= "" and (desc:GetStringHeight() or 10) + 3 or 0)
    row:SetHeight(math.max(36, h))

    if opt.kind == "choice" then
        local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btn:SetSize(CTRL_W, 22)
        btn:SetPoint("RIGHT", -6, 0)
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        arrow:SetSize(12, 12)
        arrow:SetPoint("RIGHT", -6, 0)
        arrow:SetRotation(-math.pi / 2)
        btn:SetScript("OnClick", function(self) OpenMenu(self, opt) end)
        Tooltip(btn, opt)
        function row:Refresh()
            local ok = Available(opt)
            btn:SetEnabled(ok)
            local v = ok and select(2, pcall(opt.get)) or "not installed"
            v = tostring(v)
            local text = v == RecOf(opt) and (v .. " *") or v
            btn:SetText(v == "Both (conflict)" and ("|cffff5555" .. text .. "|r") or text)
            label:SetFontObject(ok and "GameFontHighlight" or "GameFontDisable")
            row.bg:SetColorTexture(RED[1], RED[2], RED[3], (ok and v == "Both (conflict)") and 0.12 or 0)
        end
    else
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("RIGHT", -6 - (CTRL_W - 26) / 2, 0)
        cb:SetScript("OnClick", function(self)
            pcall(opt.set, self:GetChecked() and true or false)
            if opt.reload then MO.needsReload = true end
            Remember(opt)
            RefreshAll()
        end)
        local recText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        recText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        if opt.rec ~= nil then recText:SetText(RecOf(opt) and "rec: on" or "rec: off") end
        function row:Refresh()
            local ok = Available(opt)
            cb:SetEnabled(ok)
            cb:SetChecked(ok and select(2, pcall(opt.get)) or false)
            label:SetFontObject(ok and "GameFontHighlight" or "GameFontDisable")
        end
    end
    rows[#rows + 1] = row
    return row:GetHeight()
end

---------------------------------------------------------------------------
-- Problems: its own section, first
---------------------------------------------------------------------------
local probPane = CreateFrame("Frame", nil, body)
probPane:SetPoint("TOPLEFT")
probPane:SetSize(PANE_W, 50) -- (a real size: a frame without one may not draw what's in it)
local probHeader = probPane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
probHeader:SetPoint("TOPLEFT", 8, -6)
probHeader:SetPoint("RIGHT", probPane, "RIGHT", -8, 0)
probHeader:SetJustifyH("LEFT")
local probLines = {}
local function ProbLine(i)
    local l = probLines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, probPane)
    l.bg = l:CreateTexture(nil, "BACKGROUND")
    l.bg:SetAllPoints()
    l.bg:SetColorTexture(RED[1], RED[2], RED[3], 0.08)
    l.text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    l.text:SetJustifyH("LEFT")
    l.text:SetPoint("TOPLEFT", 8, -6)
    l.text:SetPoint("RIGHT", l, "RIGHT", -146, 0)
    l.fix = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.fix:SetSize(70, 22)
    l.fix:SetPoint("RIGHT", -70, 0)
    l.ignore = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.ignore:SetSize(60, 22)
    l.ignore:SetPoint("RIGHT", -6, 0)
    l.ignore:SetText("Ignore")
    probLines[i] = l
    return l
end

local probCount, probHeight = 0, 50
local function FillProblems()
    local list = Problems()
    probCount = #list
    for _, l in ipairs(probLines) do l:Hide() end
    if #list == 0 then
        probHeader:SetText("|cff66dd66No problems found.|r  |cff9d9d9dErrors in our patches, addons that don't load, leftovers of old patches and settings pointing at missing addons show up here.|r")
        probHeight = 50
        probPane:SetHeight(probHeight)
        return
    end
    probHeader:SetText(("|cffff5555%d problem%s|r  |cff9d9d9d- fix (most take a reload) or ignore.|r"):format(#list, #list > 1 and "s" or ""))
    local y = -30
    for i, p in ipairs(list) do
        local l = ProbLine(i)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 0, y)
        l:SetPoint("RIGHT", probPane, "RIGHT", 0, 0)
        l.text:SetText(p.text)
        local h = math.max(34, (l.text:GetStringHeight() or 12) + 14)
        l:SetHeight(h)
        l.fix:SetShown(p.fix ~= nil and p.fixLabel ~= nil)
        l.fix:SetText(p.fixLabel or "")
        l.fix:SetScript("OnClick", function()
            pcall(p.fix)
            if not p.noReload then MO.needsReload = true end
            RefreshAll()
        end)
        l.ignore:SetText(p.ignoreLabel or "Ignore")
        l.ignore:SetScript("OnClick", function()
            if p.onIgnore then
                pcall(p.onIgnore)
            else
                MasterOptionsDB.ignoredProblems = MasterOptionsDB.ignoredProblems or {}
                MasterOptionsDB.ignoredProblems[p.id] = true
            end
            RefreshAll()
        end)
        l:Show()
        y = y - h - 4
    end
    probHeight = -y + 6
    probPane:SetHeight(probHeight)
end

---------------------------------------------------------------------------
-- Never sell: its own section - the shared list of Modules\NeverSell.lua (MasterOptions_NeverSell)
---------------------------------------------------------------------------
local nsPane = CreateFrame("Frame", nil, body)
nsPane:SetPoint("TOPLEFT")
nsPane:SetSize(PANE_W, 50)
local nsSec -- set in BuildWindow
local nsHeader = nsPane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nsHeader:SetPoint("TOPLEFT", 8, -6)
nsHeader:SetPoint("RIGHT", nsPane, "RIGHT", -8, 0)
nsHeader:SetJustifyH("LEFT")
local ItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local ItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local FillNeverSell -- (below)

-- the add box: an item ID, a shift-clicked item link, or an item dragged onto it
local nsBox = CreateFrame("EditBox", nil, nsPane, "InputBoxTemplate")
nsBox:SetSize(260, 22)
nsBox:SetAutoFocus(false)
local nsAdd = CreateFrame("Button", nil, nsPane, "UIPanelButtonTemplate")
nsAdd:SetSize(70, 22)
nsAdd:SetPoint("LEFT", nsBox, "RIGHT", 8, 0)
nsAdd:SetText("Add")
local nsHint = nsPane:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
nsHint:SetPoint("LEFT", nsAdd, "RIGHT", 10, 0)
nsHint:SetPoint("RIGHT", nsPane, "RIGHT", -8, 0)
nsHint:SetJustifyH("LEFT")
nsHint:SetText("Shift-click or drag an item here, or type its ID.")
local function NeverSellAddFromBox()
    local ns = _G.MasterOptions_NeverSell
    local text = nsBox:GetText()
    if type(text) ~= "string" then text = "" end
    local id = tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
    if ns and id then
        ns.Set(id, true)
        nsBox:SetText("")
        nsBox:ClearFocus()
        FillNeverSell()
    end
end
nsAdd:SetScript("OnClick", NeverSellAddFromBox)
nsBox:SetScript("OnEnterPressed", NeverSellAddFromBox)
nsBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local function DropItem()
    if not GetCursorInfo then return end
    local kind, id = GetCursorInfo() -- (not `GetCursorInfo and GetCursorInfo()`: that keeps only the first value)
    if kind == "item" and id then
        nsBox:SetText(tostring(id))
        if ClearCursor then ClearCursor() end
        NeverSellAddFromBox()
    end
end
nsBox:SetScript("OnReceiveDrag", DropItem)
nsBox:SetScript("OnMouseDown", function() if GetCursorInfo and GetCursorInfo() == "item" then DropItem() end end)
-- shift-click an item while the box has the cursor: its link goes in (the game only fills the chat box)
local function InsertLink(link)
    if nsBox:HasFocus() and type(link) == "string" then nsBox:SetText(link); return true end
end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", InsertLink) end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", InsertLink) end

local nsLines = {}
local function NeverSellLine(i)
    local l = nsLines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, nsPane)
    l:SetHeight(24)
    l.bg = l:CreateTexture(nil, "BACKGROUND")
    l.bg:SetAllPoints()
    l.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(20, 20)
    l.icon:SetPoint("LEFT", 8, 0)
    l.text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    l.text:SetPoint("LEFT", l.icon, "RIGHT", 6, 0)
    l.text:SetPoint("RIGHT", l, "RIGHT", -86, 0)
    l.text:SetJustifyH("LEFT")
    l.remove = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.remove:SetSize(70, 20)
    l.remove:SetPoint("RIGHT", -6, 0)
    l.remove:SetText("Remove")
    -- the item's tooltip on hover
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    nsLines[i] = l
    return l
end

local nsWaiting = false -- (an item's name not in the client's cache yet: shown once it arrives)
FillNeverSell = function()
    local ns = _G.MasterOptions_NeverSell
    for _, l in ipairs(nsLines) do l:Hide() end
    if not ns then
        nsHeader:SetText("|cff9d9d9dThe NeverSell module is off - turn it on under Modules (takes a reload).|r")
        nsBox:Hide(); nsAdd:Hide(); nsHint:Hide()
        if nsSec then nsSec.height = 50 end
        nsPane:SetHeight(50)
        return
    end
    nsBox:Show(); nsAdd:Show(); nsHint:Show()
    local list, where = ns.List(), ns.Sources()
    nsHeader:SetText(("|cffffd200%d item%s|r  |cff9d9d9dnever sold, never suggested for selling or deletion - the same list in %s. Add or remove one there, or here.|r")
        :format(#list, #list == 1 and "" or "s", #where > 0 and table.concat(where, ", ") or "no installed addon (GearMatic, Mastercraft, DeleteCheapestItem)"))
    local y = -6 - (nsHeader:GetStringHeight() or 14) - 8
    nsBox:ClearAllPoints()
    nsBox:SetPoint("TOPLEFT", 14, y)
    y = y - 30
    -- by name; items not cached yet last, by ID
    local items = {}
    for _, id in ipairs(list) do
        local name, link
        if ItemInfo then name, link = ItemInfo(id) end
        if not name then nsWaiting = true end
        items[#items + 1] = { id = id, name = name, link = link }
    end
    table.sort(items, function(a, b)
        if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
        if a.name and b.name and a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for i, r in ipairs(items) do
        local l = NeverSellLine(i)
        l.id = r.id
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 0, y)
        l:SetPoint("RIGHT", nsPane, "RIGHT", 0, 0)
        l.icon:SetTexture(ItemIcon and ItemIcon(r.id) or 134400)
        l.text:SetText((r.link or r.name or "item") .. "  |cff6a6a6a" .. r.id .. "|r")
        l.remove:SetScript("OnClick", function() ns.Set(r.id, false); FillNeverSell() end)
        l:Show()
        y = y - 25
    end
    local h = -y + 6
    if nsSec then nsSec.height = h end
    nsPane:SetHeight(h)
    if current == nsSec then body:SetHeight(math.max(10, h)) end
end

local nsEvents = CreateFrame("Frame")
nsEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
nsEvents:SetScript("OnEvent", function()
    if nsWaiting and nsPane:IsVisible() then nsWaiting = false; FillNeverSell() end
end)

---------------------------------------------------------------------------
-- The error log as text to copy (Problems > Copy, /mo errors)
---------------------------------------------------------------------------
local errWin
MO.ShowErrorText = function()
    if not errWin then
        errWin = CreateFrame("Frame", "MasterOptionsErrorFrame", UIParent, "BasicFrameTemplateWithInset")
        errWin:SetSize(560, 380)
        errWin:SetPoint("CENTER")
        errWin:SetFrameStrata("DIALOG")
        errWin:SetMovable(true)
        errWin:EnableMouse(true)
        errWin:RegisterForDrag("LeftButton")
        errWin:SetScript("OnDragStart", errWin.StartMoving)
        errWin:SetScript("OnDragStop", errWin.StopMovingOrSizing)
        tinsert(UISpecialFrames, "MasterOptionsErrorFrame") -- (Escape closes it)
        local title = errWin:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
        title:SetText("Master Options - errors (Ctrl+C to copy)")
        local sf = CreateFrame("ScrollFrame", nil, errWin, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -32)
        sf:SetPoint("BOTTOMRIGHT", -32, 12)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(500)
        eb:SetScript("OnEscapePressed", function() errWin:Hide() end)
        -- (read-only: typing puts the text back)
        eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(errWin.text or "") self:HighlightText() end end)
        sf:SetScrollChild(eb)
        errWin.eb = eb
    end
    local log = _G.MasterOptions_ErrorLog
    errWin.text = log and log.Text() or "No error log."
    errWin.eb:SetText(errWin.text)
    errWin:Show()
    errWin.eb:SetFocus()
    errWin.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Sections and the side list
---------------------------------------------------------------------------
local function ShowSection(sec)
    current = sec
    for _, s in ipairs(sections) do
        s.pane:SetShown(s == sec)
        s.button.selected:SetShown(s == sec)
    end
    if sec.neverSell then FillNeverSell() end
    body:SetHeight(math.max(10, (sec.problems and probHeight or sec.height) or 10))
    scroll:SetVerticalScroll(0)
    menu:Hide()
    if MasterOptionsDB then MasterOptionsDB.lastSection = sec.name end
end

local function SideButton(sec, i)
    local b = CreateFrame("Button", nil, side)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", 2, -4 - (i - 1) * 25)
    b:SetPoint("RIGHT", side, "RIGHT", -2, 0)
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetColorTexture(1, 0.82, 0, 0.18)
    b.selected:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -22, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(sec.name)
    b.badge = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.badge:SetPoint("RIGHT", -6, 0)
    b:SetScript("OnClick", function() ShowSection(sec) end)
    sec.button = b
end

local function BuildWindow()
    -- Problems first
    local probSec = { name = "Problems", pane = probPane, problems = true }
    sections[1] = probSec
    -- then a section for every header of OPTIONS
    local sec
    for _, opt in ipairs(OPTIONS) do
        if opt.header then
            sec = { name = (opt.header:gsub("%s*%(.-%)%s*$", "")), opts = {} }
            sections[#sections + 1] = sec
        elseif sec then
            sec.opts[#sec.opts + 1] = opt
        end
    end
    -- Never sell: right after Vendor and bank (or last)
    nsSec = { name = "Never sell", pane = nsPane, neverSell = true, height = 50, opts = {} }
    local at = #sections + 1
    for i, s in ipairs(sections) do if s.name == "Vendor and bank" then at = i + 1 end end
    table.insert(sections, at, nsSec)
    for i, s in ipairs(sections) do
        if not s.problems and not s.neverSell then
            s.pane = CreateFrame("Frame", nil, body)
            s.pane:SetPoint("TOPLEFT")
            s.pane:SetSize(PANE_W, 10)
            local y = -2
            for _, opt in ipairs(s.opts) do y = y - BuildRow(s.pane, opt, y) - 2 end
            s.height = -y + 4
            s.pane:SetHeight(s.height) -- (a real size: a frame without one may not draw what's in it)
        end
        s.pane:Hide()
        SideButton(s, i)
    end
    local want = MasterOptionsDB and MasterOptionsDB.lastSection
    local first = sections[2] or sections[1]
    for _, s in ipairs(sections) do if s.name == want then first = s end end
    -- the list changed (in another addon, or by /mo never): shown again if it's open
    local ns = _G.MasterOptions_NeverSell
    if ns then ns.OnChange = function() if nsPane:IsVisible() then FillNeverSell() end end end
    ShowSection(first)
    -- the window where it was left
    local pos = MasterOptionsDB and MasterOptionsDB.winPos
    if type(pos) == "table" and pos[1] then
        win:ClearAllPoints()
        win:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    end
end

RefreshProblems = function()
    FillProblems()
    for _, s in ipairs(sections) do
        local b = s.button
        if b then
            if s.problems then
                b.badge:SetText(probCount > 0 and ("|cffff5555" .. probCount .. "|r") or "")
            elseif s.neverSell then
                local ns = _G.MasterOptions_NeverSell
                local n = ns and #ns.List() or 0
                b.badge:SetText(n > 0 and ("|cff9d9d9d" .. n .. "|r") or "")
            else
                local n = 0
                for _, opt in ipairs(s.opts) do if IsConflict(opt) then n = n + 1 end end
                b.badge:SetText(n > 0 and ("|cffff5555" .. n .. "|r") or "")
            end
        end
    end
    if current then body:SetHeight(math.max(10, (current.problems and probHeight or current.height) or 10)) end
end
-- a new error while the window is open: shown at once
if _G.MasterOptions_ErrorLog then
    MasterOptions_ErrorLog.OnChange = function() if win:IsShown() then RefreshProblems() end end
end

-- footer
reloadBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
reloadBtn:SetSize(110, 24)
reloadBtn:SetPoint("BOTTOMRIGHT", -12, 12)
reloadBtn:SetText("Reload UI")
reloadBtn:SetScript("OnClick", ReloadUI)
reloadBtn:Hide()
local recBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
recBtn:SetSize(140, 24)
recBtn:SetPoint("BOTTOMLEFT", 12, 12)
recBtn:SetText("Use recommended")
recBtn:SetScript("OnClick", function()
    local n = ApplyRecommended(nil, true)
    print("|cffffd200Master Options:|r recommended setup applied (" .. n .. " changed).")
end)
local note = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("LEFT", recBtn, "RIGHT", 12, 0)
note:SetPoint("RIGHT", reloadBtn, "LEFT", -12, 0)
note:SetJustifyH("LEFT")
note:SetText("|cffff5555Red|r = two addons doing the same job.  * = recommended.  Hover a setting for more.")

win:SetScript("OnShow", RefreshAll)

local function OpenWindow()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    win:Show()
end

-- for the files after this one
MO.ApplyRecommended = ApplyRecommended
MO.ApplyShared = ApplyShared
MO.Available = Available
MO.BuildWindow = BuildWindow
MO.DEFAULTS_VERSION = DEFAULTS_VERSION
MO.OpenWindow = OpenWindow
MO.RecOf = RecOf
MO.RefreshAll = RefreshAll
MO.Remember = Remember
MO.win = win
