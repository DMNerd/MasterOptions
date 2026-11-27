-- Master Options: the game's Options page (Options > AddOns > Master Options), /mo, and what runs at login.

local _, MO = ...
-- from the files before this one
local ApplyRecommended, ApplyShared, Available, BuildWindow, ClearPawnHidden, DEFAULTS_VERSION, FollowSpec, GMUsesPawn = MO.ApplyRecommended, MO.ApplyShared, MO.Available, MO.BuildWindow, MO.ClearPawnHidden, MO.DEFAULTS_VERSION, MO.FollowSpec, MO.GMUsesPawn
local Loaded, OPTIONS, OpenWindow, Problems, RecOf, RefreshAll, RefreshGearMatic, Remember = MO.Loaded, MO.OPTIONS, MO.OpenWindow, MO.Problems, MO.RecOf, MO.RefreshAll, MO.RefreshGearMatic, MO.Remember
local SyncIcons, SyncPawnHidden, win = MO.SyncIcons, MO.SyncPawnHidden, MO.win

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
                local n = 0
                for _, opt in ipairs(OPTIONS) do
                    if opt.kind == "choice" and Available(opt) and opt.get() == "Both (conflict)" then n = n + 1 end
                end
                if n > 0 then
                    tt:AddLine(n .. " setting" .. (n > 1 and "s" or "") .. " doubled up", 1, 0.33, 0.33)
                else
                    tt:AddLine("No doubled-up settings", 0.4, 1, 0.4)
                end
                local np = #Problems()
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

-- Pawn -> GearMatic bridge events (see SyncPawnHidden)
local bridge = CreateFrame("Frame")
bridge:RegisterEvent("PLAYER_LOGIN")
bridge:RegisterEvent("PLAYER_LOGOUT")
bridge:RegisterEvent("PLAYER_LEVEL_UP")
-- druids: a talent change can change which Pawn scale GearMatic should use (see DruidPawnSpec)
for _, e in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(bridge.RegisterEvent, bridge, e) end
local resyncPending, specPending = false, false
local function Resync()
    resyncPending = false
    SyncPawnHidden()
    if GMUsesPawn() then RefreshGearMatic() end
end
bridge:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Pawn (an optional dependency, so loaded first) has set up its scales by now, and
        -- GearMatic copies them 2 s after login: flag them before that, and again to be sure.
        SyncPawnHidden()
        C_Timer.After(1, SyncPawnHidden)
        C_Timer.After(3, function() if GMUsesPawn() then Resync() end end)
        -- Pawn and CheapUpgrades follow GearMatic's spec (after GearMatic and Pawn are set up)
        C_Timer.After(3.5, function() pcall(FollowSpec) end)
        -- showing or hiding a scale in Pawn (or /pff stock|forever) changes what GearMatic uses
        local function QueueResync()
            if resyncPending then return end
            resyncPending = true
            C_Timer.After(0.2, Resync)
        end
        if type(_G.PawnSetScaleVisible) == "function" then hooksecurefunc("PawnSetScaleVisible", QueueResync) end
        -- GearMatic's Cat/Bear choice (/gm feral) picks the druid's Feral scale
        local gm = _G.GearMatic
        if type(gm) == "table" and type(gm.SetFeralRole) == "function" then
            hooksecurefunc(gm, "SetFeralRole", QueueResync)
            hooksecurefunc(gm, "SetFeralRole", function() C_Timer.After(0.3, function() pcall(FollowSpec) end) end)
        end
    elseif event == "PLAYER_LEVEL_UP" then
        -- Pawn Forever switches to its level-60 values 1 s after the level-up
        if GMUsesPawn() then C_Timer.After(2, RefreshGearMatic) end
    elseif event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        if select(2, UnitClass("player")) == "DRUID" and GMUsesPawn() and not resyncPending then
            resyncPending = true
            C_Timer.After(0.5, Resync)
        end
        -- a spec change: Pawn and CheapUpgrades follow (once GearMatic has seen the new talents)
        if not specPending then
            specPending = true
            C_Timer.After(0.6, function() specPending = false; pcall(FollowSpec) end)
        end
    elseif event == "PLAYER_LOGOUT" then
        ClearPawnHidden()
    end
end)

SLASH_MASTEROPTIONS1 = "/mo"
SLASH_MASTEROPTIONS2 = "/masteroptions"
-- /mo never [remove] <item link or ID>, /mo never: the shared never-sell list (Modules\NeverSell.lua)
local function NeverSellCommand(rest)
    local ns = _G.MasterOptions_NeverSell
    local head = "|cffffd200Master Options:|r "
    if not ns then print(head .. "the NeverSell module is off (/mo > Modules).") return end
    local function Name(id)
        local name, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
        return link or name or ("item " .. id)
    end
    local remove, item = rest:match("^(remove)%s+(.+)$")
    item = item or rest
    local id = tonumber(item:match("item:(%d+)") or item:match("^(%d+)$"))
    if id then
        ns.Set(id, not remove)
        local where = ns.Sources()
        print(head .. Name(id) .. (remove and " taken off" or " put on") .. " the never-sell list"
            .. (#where > 0 and (" (" .. table.concat(where, ", ") .. ")") or "") .. ".")
        return
    end
    if item ~= "" then print(head .. "/mo never <item link or ID> adds, /mo never remove <item> takes off, /mo never lists.") return end
    ns.Sync()
    local list = ns.List()
    local where = ns.Sources()
    print(head .. #list .. " item" .. (#list == 1 and "" or "s") .. " on the never-sell list, kept in sync with "
        .. (#where > 0 and table.concat(where, ", ") or "no installed addon") .. ":")
    for i, itemID in ipairs(list) do
        if i > 40 then print(("  ... and %d more"):format(#list - 40)) break end
        print("  " .. Name(itemID))
    end
end

SlashCmdList.MASTEROPTIONS = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local never = msg:match("^[Nn][Ee][Vv][Ee][Rr]%s*(.*)$")
    if never then NeverSellCommand(never) return end
    if msg:lower() == "whispers" then
        local w = _G.MasterOptions_AddonWhispers
        if w then w.List() else print("|cffffd200Master Options:|r the Chat / AddonWhispers module is off (/mo > Modules).") end
        return
    end
    local farm = msg:match("^[Ff][Aa][Rr][Mm]%s*(.*)$")
    if farm then
        local tour = _G.MasterOptions_FarmTour
        if tour then tour.Command(farm)
        else print("|cffffd200Master Options:|r farming tours need Mastercraft and ShortestPathForever (and the Mastercraft / FarmTour module on).") end
        return
    end
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
    win:SetShown(not win:IsShown())
end
