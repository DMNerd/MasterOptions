-- Master Options: Share setup - every choice Master Options shows (its rows, its modules on / off) and the never-sell
-- list as one line of text, to paste on another account or computer.
--
-- A code: "MO1!" then the choices serialized (AceSerializer-3.0), compressed and made printable (LibDeflate) - both
-- shipped in Libs. Choices are kept by the row's name; importing sets each row it knows that can be set here (its
-- addons loaded, the value still one of its choices), skips the rest and says how many of each. Nothing runs from a
-- code: it's read back as plain values only.

local _, MO = ...
local OPTIONS, Available, RefreshAll = MO.OPTIONS, MO.Available, nil

local PREFIX = "MO1!"
local function Libs()
    local ser = LibStub and LibStub("AceSerializer-3.0", true)
    local def = LibStub and LibStub("LibDeflate", true)
    return ser, def
end

local function Value(opt)
    local ok, v = pcall(opt.get)
    if not ok or v == nil or v == "Both (conflict)" or v == "Mixed" then return nil end
    return v
end

-- the code for this character's choices; nil and why when the libraries are missing
local function Export()
    local ser, def = Libs()
    if not (ser and def) then return nil, "the sharing libraries didn't load" end
    local rows = {}
    for _, opt in ipairs(OPTIONS) do
        if opt.label and (opt.kind == "choice" or opt.kind == "toggle") and Available(opt) then
            local v = Value(opt)
            if v ~= nil then rows[opt.label] = v end
        end
    end
    local data = { v = 1, rows = rows }
    local ns = _G.MasterOptions_NeverSell
    if ns and type(ns.List) == "function" then
        local ok, list = pcall(ns.List)
        if ok and type(list) == "table" then data.neverSell = list end
    end
    local packed = def:CompressDeflate(ser:Serialize(data), { level = 9 })
    return PREFIX .. def:EncodeForPrint(packed)
end

-- a code read back: the data, or nil and why
local function Decode(code)
    local ser, def = Libs()
    if not (ser and def) then return nil, "the sharing libraries didn't load" end
    code = type(code) == "string" and code:gsub("%s", "") or ""
    if code:sub(1, #PREFIX) ~= PREFIX then return nil, "that isn't a Master Options code (it starts with " .. PREFIX .. ")" end
    local packed = def:DecodeForPrint(code:sub(#PREFIX + 1))
    local text = packed and def:DecompressDeflate(packed)
    if not text then return nil, "the code is cut short or changed - copy it again, whole" end
    local ok, data = ser:Deserialize(text)
    if not ok or type(data) ~= "table" or type(data.rows) ~= "table" then return nil, "the code can't be read" end
    return data
end

local function Fits(opt, v)
    if opt.kind == "toggle" then return type(v) == "boolean" end
    if v == "Off" or v == opt.off then return true end
    for _, c in ipairs(opt.choices or {}) do if c == v then return true end end
    return false
end

-- apply a code: how many set, how many already so, how many skipped (row unknown here, its addons not loaded, or the
-- value no longer one of its choices), never-sell items added - or nil and why
local function Import(code)
    local data, why = Decode(code)
    if not data then return nil, why end
    local set, same, skipped = 0, 0, 0
    local known = {}
    for _, opt in ipairs(OPTIONS) do
        local want = opt.label and data.rows[opt.label]
        if want ~= nil then
            known[opt.label] = true
            if Available(opt) and Fits(opt, want) then
                if Value(opt) == want then
                    same = same + 1
                elseif pcall(opt.set, want) then
                    set = set + 1
                    if opt.reload then MO.needsReload = true end
                    if MO.Remember then pcall(MO.Remember, opt) end
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
    end
    for label in pairs(data.rows) do if not known[label] then skipped = skipped + 1 end end
    local added = 0
    local ns = _G.MasterOptions_NeverSell
    if ns and type(ns.Set) == "function" and type(data.neverSell) == "table" then
        local have = {}
        local ok, list = pcall(ns.List)
        for _, id in ipairs(ok and type(list) == "table" and list or {}) do have[id] = true end
        for _, id in ipairs(data.neverSell) do
            if type(id) == "number" and not have[id] and pcall(ns.Set, id, true) then added = added + 1 end
        end
    end
    RefreshAll = RefreshAll or MO.RefreshAll
    if RefreshAll then pcall(RefreshAll) end
    return { set = set, same = same, skipped = skipped, neverSell = added }
end

---------------------------------------------------------------------------
-- The "Share setup" section of the /mo window: a box for the code, Make code, Use this code
---------------------------------------------------------------------------
local function BuildPane(parent, width)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPLEFT")
    pane:SetSize(width, 290)
    local head = pane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    head:SetPoint("TOPLEFT", 8, -6)
    head:SetText("Share setup")
    local info = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    info:SetPoint("RIGHT", pane, "RIGHT", -8, 0)
    info:SetJustifyH("LEFT")
    info:SetText("Every choice Master Options shows (and the never-sell list) as one code. Make code here, copy it (Ctrl+C), and on another account or computer paste it below (Ctrl+V) and Use this code. A choice whose addons aren't loaded there is left as it is.")
    local holder = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    holder:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -10)
    holder:SetPoint("RIGHT", pane, "RIGHT", -8, 0)
    holder:SetHeight(150)
    if holder.SetBackdrop then
        holder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        holder:SetBackdropColor(0, 0, 0, 0.5)
    end
    local sf = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontSmall")
    box:SetWidth(width - 60)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    sf:SetScrollChild(box)
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() box:SetFocus() end)
    local status = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -38)
    status:SetPoint("RIGHT", pane, "RIGHT", -8, 0)
    status:SetJustifyH("LEFT")
    local make = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    make:SetSize(120, 22)
    make:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -8)
    make:SetText("Make code")
    make:SetScript("OnClick", function()
        local code, why = Export()
        if not code then status:SetText("|cffff5555Can't make a code: " .. why .. ".|r") return end
        box:SetText(code)
        box:SetFocus()
        box:HighlightText()
        status:SetText(("A code of %d characters - copy it with Ctrl+C."):format(#code))
    end)
    local use = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    use:SetSize(120, 22)
    use:SetPoint("LEFT", make, "RIGHT", 8, 0)
    use:SetText("Use this code")
    use:SetScript("OnClick", function()
        local r, why = Import(box:GetText())
        if not r then status:SetText("|cffff5555" .. why .. ".|r") return end
        status:SetText(("Set %d choice%s (%d already so, %d skipped: not here or not loaded)%s%s."):format(
            r.set, r.set == 1 and "" or "s", r.same, r.skipped,
            r.neverSell > 0 and (", " .. r.neverSell .. " items added to never sell") or "",
            MO.needsReload and " - reload to finish" or ""))
    end)
    return pane, 290
end

MO.Share = { Export = Export, Import = Import, Decode = Decode, BuildPane = BuildPane }
