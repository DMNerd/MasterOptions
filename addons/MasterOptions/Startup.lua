-- Master Options: the game's Options page (Options > AddOns > Master Options), /mo, and what runs at login.

local _, MO = ...
-- from the files before this one
local ApplyRecommended, ApplyShared, Available, BuildWindow, DEFAULTS_VERSION = MO.ApplyRecommended, MO.ApplyShared, MO.Available, MO.BuildWindow, MO.DEFAULTS_VERSION
local Loaded, OPTIONS, OpenWindow, Problems, RecOf, RefreshAll, Remember = MO.Loaded, MO.OPTIONS, MO.OpenWindow, MO.Problems, MO.RecOf, MO.RefreshAll, MO.Remember
local SyncIcons, win = MO.SyncIcons, MO.win

---------------------------------------------------------------------------
-- Options > AddOns > Master Options: every row of the window as the game's own checkbox or dropdown
-- (the same get/set as the window, so both always show the same). The page's Defaults button applies
-- the recommended setup. Rows whose addons aren't loaded are left out, as the window greys them.
---------------------------------------------------------------------------
local settingsCategory
local function IsChoice(opt, v)
    for _, c in ipairs(opt.choices or {}) do if c == v then return true end end
    return false
end
local function SafeGet(opt)
    local ok, v = pcall(opt.get)
    if ok then return v end
end
local reloadSaid = false
local function RegisterSettingsPanel()
    if settingsCategory or not (Settings and Settings.RegisterAddOnCategory) then return end
    if not (Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting and Settings.VarType) then
        -- a client without the list-style pages: a page with a button that opens the window
        if not Settings.RegisterCanvasLayoutCategory then return end
        local panel = CreateFrame("Frame")
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(200, 26)
        b:SetPoint("TOPLEFT", 16, -16)
        b:SetText("Open Master Options")
        b:SetScript("OnClick", OpenWindow)
        settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Master Options")
        Settings.RegisterAddOnCategory(settingsCategory)
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("Master Options")
    local function Header(text)
        if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
            pcall(layout.AddInitializer, layout, CreateSettingsListSectionHeaderInitializer(text))
        end
    end
    local function Button(label, text, fn, tip)
        if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
            pcall(layout.AddInitializer, layout, CreateSettingsButtonInitializer(label, text, fn, tip, true))
        end
    end
    local version, author = MasterOptions_Shared.About()
    Header(("Master Options %s - by %s"):format(version, author))
    Button("Master Options window", "Open", OpenWindow,
        "The same settings in Master Options' own window (/mo), with the Problems list.")
    Button("Thanks", "Show", function() if MO.OpenThanks then MO.OpenThanks() end end,
        "The authors of every addon Master Options works with - everything it connects is their work.")
    Button("Some changes need a reload", "Reload", ReloadUI,
        "Skins, bag icons and compatibility patches take effect after a reload.")

    local function Changed(opt)
        if opt.reload then
            MO.needsReload = true
            if not reloadSaid then
                reloadSaid = true
                print("|cffffd200Master Options:|r reload to finish (the Reload button at the top of the page, or /reload).")
            end
        end
        Remember(opt)
        RefreshAll()
    end

    local header
    for i, opt in ipairs(OPTIONS) do
        if opt.header then
            header = opt.header
        elseif Available(opt) then
            if header then Header(header); header = nil end
            local variable = "MasterOptions_Row" .. i
            local name = opt.label .. (opt.scope and " (per char)" or "")
            local tip = opt.tip
            if type(tip) == "function" then local ok, t = pcall(tip); tip = ok and t or nil end
            if opt.kind == "toggle" then
                local default = RecOf(opt)
                if default == nil then default = SafeGet(opt) and true or false end
                local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, default,
                    function() return Available(opt) and SafeGet(opt) and true or false end,
                    function(v)
                        v = v and true or false
                        if Available(opt) and (SafeGet(opt) and true or false) ~= v then
                            pcall(opt.set, v)
                            Changed(opt)
                        end
                    end)
                Settings.CreateCheckbox(category, setting, tip)
            else
                local default = RecOf(opt)
                if default == nil or not IsChoice(opt, default) then default = opt.choices[1] end
                local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.String, name, default,
                    function() return tostring(SafeGet(opt) or default) end,
                    function(v)
                        if IsChoice(opt, v) and Available(opt) and SafeGet(opt) ~= v then
                            pcall(opt.set, v)
                            Changed(opt)
                        end
                    end)
                Settings.CreateDropdown(category, setting, function()
                    local c = Settings.CreateControlTextContainer()
                    for _, choice in ipairs(opt.choices) do
                        -- (as the window's button: choices whose addon isn't loaded are left out)
                        if MO.ChoiceShown(opt, choice) then
                            c:Add(choice, choice == RecOf(opt) and (choice .. " *") or choice)
                        end
                    end
                    -- a state that isn't a choice ("Both (conflict)", "Mixed") is shown, in red
                    local cur = SafeGet(opt)
                    if cur ~= nil and not IsChoice(opt, cur) then c:Add(tostring(cur), "|cffff5555" .. tostring(cur) .. "|r") end
                    return c:GetData()
                end, tip)
            end
        end
    end
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

local function OpenSettingsPage()
    if settingsCategory and Settings and Settings.OpenToCategory then
        local id = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID
        if pcall(Settings.OpenToCategory, id) then return end
    end
    win:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    MasterOptionsDB = MasterOptionsDB or {}
    BuildWindow()

    -- Options > AddOns > Master Options: the same settings as the game's own controls
    pcall(RegisterSettingsPanel)

    -- WoW Forever: UnitName gives first and last name and the realm name is empty, so "Name-Realm"
    -- was the same key ("Testchar-") for every character sharing a first name. Key on the full name;
    -- a character with no record yet takes over the old shared key's version.
    local first = UnitName("player")
    local legacy = (first or "?") .. "-" .. (GetRealmName() or "")
    local char = MasterOptions_Shared.CharacterKey()
    MasterOptionsDB.applied = MasterOptionsDB.applied or {}
    C_Timer.After(2, function()
        local prev = MasterOptionsDB.applied[char] or MasterOptionsDB.applied[legacy] or 0
        local n = 0
        if prev < DEFAULTS_VERSION then
            MasterOptionsDB.applied[char] = DEFAULTS_VERSION
            -- first run: everything; later versions: only the rows added since (your own choices stay)
            n = ApplyRecommended(prev)
        end
        -- then your account-wide choices for the per-character rows (they win over "recommended")
        local s = ApplyShared()
        -- CheapUpgrades_GearMatic off (or GearMatic gone): specs on its "GearMatic" profile go back to
        -- CheapUpgrades' own weights (the profiles stay, for when it's on again)
        local cuAddon = _G.CheapUpgrades
        if Loaded("CheapUpgrades") and not Loaded("MasterOptions_CheapUpgrades_GearMatic") and type(cuAddon) == "table"
            and type(cuAddon.chardb) == "table" and type(cuAddon.chardb.profile) == "table" then
            local was = false
            for specKey, name in pairs(cuAddon.chardb.profile) do
                if name == "GearMatic" then cuAddon.chardb.profile[specKey] = nil; was = true end
            end
            if was and cuAddon.Evaluate then pcall(cuAddon.Evaluate, cuAddon) end
        end
        -- matched bag icons: a choice changed in the addon itself (GearMatic's weights, its junk selling)
        local okI, icons = pcall(SyncIcons)
        if okI and icons then
            MO.needsReload = true
            print("|cffffd200Master Options:|r bag icons matched to your stat weights / junk seller - /reload to show them.")
        end
        if n > 0 or s > 0 then
            local parts = {}
            if n > 0 then parts[#parts + 1] = "recommended setup applied (" .. n .. " changed)" end
            if s > 0 then parts[#parts + 1] = s .. " per-character setting" .. (s > 1 and "s" or "") .. " matched to your other characters" end
            print("|cffffd200Master Options:|r " .. table.concat(parts, "; ") .. ". /mo to review." .. (MO.needsReload and " Reload to finish." or ""))
        end
    end)

    -- Minimap button (LibDBIcon: drag it round the edge; OpenMap_MiniMap's tray collects it)
    MasterOptionsDB.minimap = MasterOptionsDB.minimap or {}
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and DBI then
        local tipCounts = {} -- (the tooltip's doubled-up and problem counts, and when they were counted)
        local obj = LDB:NewDataObject("MasterOptions", {
            type = "launcher",
            label = "Master Options",
            icon = "Interface\\AddOns\\MasterOptions\\Minimap",
            OnClick = function(_, button)
                if button == "RightButton" then
                    MasterOptionsDB.minimap.hide = true
                    DBI:Hide("MasterOptions")
                    print("|cffffd200Master Options:|r minimap button hidden. /mo minimap brings it back.")
                else
                    win:SetShown(not win:IsShown())
                end
            end,
            OnTooltipShow = function(tt)
                local version, author = MasterOptions_Shared.About()
                tt:AddDoubleLine("Master Options", ("%s - by %s"):format(version, author), 1, 0.82, 0, 0.6, 0.6, 0.6)
                -- (each hover asked every setting and ran the whole addon check: counted once per 10 s)
                local now = GetTime()
                if not tipCounts.at or now - tipCounts.at > 10 then
                    local n = 0
                    for _, opt in ipairs(OPTIONS) do
                        if opt.kind == "choice" and Available(opt) and opt.get() == "Both (conflict)" then n = n + 1 end
                    end
                    tipCounts.at, tipCounts.n, tipCounts.np = now, n, #Problems()
                end
                local n, np = tipCounts.n, tipCounts.np
                if n > 0 then
                    tt:AddLine(n .. " setting" .. (n > 1 and "s" or "") .. " doubled up", 1, 0.33, 0.33)
                else
                    tt:AddLine("No doubled-up settings", 0.4, 1, 0.4)
                end
                if np > 0 then tt:AddLine(np .. " addon problem" .. (np > 1 and "s" or ""), 1, 0.33, 0.33) end
                tt:AddLine("|cffffffffClick|r to open, |cffffffffRight-click|r to hide this button", 0.7, 0.7, 0.7)
            end,
        })
        DBI:Register("MasterOptions", obj, MasterOptionsDB.minimap)
    end

    -- Health check once per login
    C_Timer.After(4, function()
        local list = Problems()
        if #list == 0 then return end
        print(("|cffffd200Master Options:|r %d addon problem%s found - %s Type /mo to fix or ignore.")
            :format(#list, #list > 1 and "s" or "", list[1].text:match("^[^\n]*") .. (#list > 1 and (" (+" .. (#list - 1) .. " more)") or "")))
    end)

    -- Warn once per login if anything is doubled up (looked at again 3 s later: still doubled up?)
    local function Conflicts()
        local out = {}
        for _, opt in ipairs(OPTIONS) do
            if opt.kind == "choice" and Available(opt) and opt.get() == "Both (conflict)" then out[#out + 1] = opt.label end
        end
        return out
    end
    if #Conflicts() > 0 then
        C_Timer.After(3, function()
            local conflicts = Conflicts()
            if #conflicts == 0 then return end
            print("|cffffd200Master Options:|r two addons doing the same job: " .. table.concat(conflicts, ", ") .. ". Type /mo to pick one.")
        end)
    end
end)

SLASH_MASTEROPTIONS1 = "/mo"
SLASH_MASTEROPTIONS2 = "/masteroptions"
-- /mo <word>: Master Options' own commands below; every module brings its own (MasterOptions_Shared.Command - only
-- while it runs: /mo help lists what there is now)
local HEAD = "|cffffd200Master Options:|r "
local CORE = {
    { "arrow", "arrow - unlock or lock Shortest Path's direction arrow" },
    { "minimap", "minimap - hide or show this minimap button" },
    { "options", "options - Master Options in the game's Options" },
    { "errors", "errors - the text of Master Options' caught errors, to copy" },
}
local function Help()
    print(HEAD .. "/mo opens the window. Also:")
    for _, c in ipairs(CORE) do print("  /mo " .. c[2]) end
    local mods = _G.MasterOptions_Modules
    for _, c in ipairs(mods and mods.Commands and mods.Commands() or {}) do print("  /mo " .. (c.usage or c.word)) end
end

SlashCmdList.MASTEROPTIONS = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local word, rest = msg:match("^(%S*)%s*(.-)$")
    local mods = _G.MasterOptions_Modules
    local cmd = word ~= "" and mods and mods.Command and mods.Command(word)
    if cmd then
        local ok, err = pcall(cmd.fn, rest)
        if not ok and _G.MasterOptions_ReportError then MasterOptions_ReportError("MasterOptions", "/mo " .. word, err) end
        return
    end
    if word:lower() == "arrow" then
        -- /mo arrow: Shortest Path's "Move the arrow" on / off (its own setting, through the game's Settings)
        local s = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_arrowMove")
        if not (s and s.GetValue and s.SetValue) then
            print(HEAD .. "Shortest Path Forever's arrow setting isn't there (is the addon loaded?).")
            return
        end
        local on = s:GetValue() ~= true
        s:SetValue(on)
        print(HEAD .. "Shortest Path's arrow " .. (on
            and "unlocked - drag it (Shift-drag or arrow keys to nudge, right-click to reset). /mo arrow again to lock it."
            or "locked where it is."))
        return
    end
    if word:lower() == "help" then Help() return end
    msg = msg:lower()
    if msg == "minimap" then
        local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
        MasterOptionsDB.minimap = MasterOptionsDB.minimap or {}
        local hide = not MasterOptionsDB.minimap.hide
        MasterOptionsDB.minimap.hide = hide
        if DBI then if hide then DBI:Hide("MasterOptions") else DBI:Show("MasterOptions") end end
        print("|cffffd200Master Options:|r minimap button " .. (hide and "hidden" or "shown") .. ".")
        return
    end
    if msg == "options" or msg == "settings" then
        OpenSettingsPage()
        return
    end
    if msg == "errors" then
        MO.ShowErrorText()
        return
    end
    if msg ~= "" then
        print(HEAD .. "no command \"" .. word .. "\" (or its module is off - /mo > Modules). /mo help lists them.")
        return
    end
    win:SetShown(not win:IsShown())
end
