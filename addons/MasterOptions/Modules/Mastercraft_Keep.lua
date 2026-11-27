-- Master Options module (was the addon MasterOptions_Mastercraft_Keep): runs when Mastercraft is loaded.
MasterOptions_Module("Mastercraft_Keep", { "Mastercraft" }, function(ADDON)

-- Mastercraft -> keep the materials you're collecting.
--
-- Mastercraft knows what your crafting guides still need, but keeps that to itself (its tables are private).
-- Two exact sources are readable:
--   * your Mastercraft item tracker (MastercraftDB.goals, per character)
--   * Mastercraft's own tooltip line "<Profession> guide needs  N more": whenever you see an item's tooltip,
--     this remembers whether Mastercraft says a guide (yours or an alt's) needs it - and forgets it when a
--     later tooltip no longer says so.
-- What's needed goes on GearMatic's "never auto-sell" list (so its junk, gear and low-value rules leave it),
-- and MasterOptions_DeleteCheapestItem_Protect keeps it off DeleteCheapestItem's list.
-- Only entries this patch added are ever removed again (GearMaticDB.moKeep lists them); yours stay.
--
-- Shared with the Protect patch: MasterOptions_MastercraftKeep.IsNeeded(itemID).

local DB -- MasterOptions_MastercraftKeepDB: { needed = { [itemID] = time last confirmed } }

local _, Check = MasterOptions_Shared.ErrorReporters(ADDON) -- (caught errors to /mo > Problems)

local function TrackerIDs()
    local out = {}
    local mc = _G.MastercraftDB
    local goals = type(mc) == "table" and type(mc.goals) == "table" and mc.goals
    if not goals then return out end
    local mine = goals[UnitGUID("player") or ""]
    for _, list in pairs({ mine }) do
        for _, g in ipairs(list or {}) do
            local id = type(g) == "table" and tonumber(g.id)
            if id then out[id] = true end
        end
    end
    return out
end

local function IsNeeded(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    if DB and DB.needed and DB.needed[itemID] then return true end
    if DB and DB.keep and DB.keep[itemID] then return true end
    return TrackerIDs()[itemID] == true
end
MasterOptions_MastercraftKeep = { IsNeeded = IsNeeded }

---------------------------------------------------------------------------
-- GearMatic's never-sell list (account-wide): add what's needed, remove what we added and isn't any more
---------------------------------------------------------------------------
local function SyncGearMatic()
    local g = _G.GearMaticDB
    if type(g) ~= "table" then return end
    g.sellIgnore = g.sellIgnore or {}
    g.moKeep = g.moKeep or {}
    local want = TrackerIDs()
    for id in pairs(DB.needed) do want[id] = true end
    for id in pairs(DB.keep) do want[id] = true end
    local before = 0
    for _ in pairs(g.moKeep) do before = before + 1 end
    local marked = type(g.sellMark) == "table" and g.sellMark or {}
    for id in pairs(want) do
        -- you marked it "always sell" in GearMatic: that wins
        if not marked[id] and not g.sellIgnore[id] then
            g.sellIgnore[id] = true
            g.moKeep[id] = true
        end
    end
    for id in pairs(g.moKeep) do
        if not want[id] then
            g.sellIgnore[id] = nil
            g.moKeep[id] = nil
        end
    end
    -- GearMatic's bag badges (its "best gold" $ / price tag skip items on the never-sell list): redraw
    local after = 0
    for _ in pairs(g.moKeep) do after = after + 1 end
    local gm = _G.GearMatic
    if after ~= before and type(gm) == "table" and type(gm.RefreshSellIgnoreSurfaces) == "function" then
        pcall(gm.RefreshSellIgnoreSurfaces)
    end
end

---------------------------------------------------------------------------
-- Learning from Mastercraft's tooltip (runs after Mastercraft has added its lines)
---------------------------------------------------------------------------
local function GuideLineIn(tooltip)
    local name = tooltip:GetName()
    if not name then return false end
    for i = 1, tooltip:NumLines() do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if type(text) == "string" and text:find("guide needs$") then return true end
    end
    return false
end

-- Mastercraft's advice for the item: the right side of its "Mastercraft" header line ("KEEP", "VENDOR",
-- "AUCTION", "DISENCHANT", "NO PRICES"), or nil when the tooltip has no advice
local function VerdictIn(tooltip)
    local name = tooltip:GetName()
    if not name then return nil end
    for i = 1, tooltip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local text = left and left:GetText()
        if type(text) == "string" and text:find("Mastercraft", 1, true) then
            local right = _G[name .. "TextRight" .. i]
            local r = right and right:IsShown() and right:GetText()
            if type(r) == "string" and r ~= "" then
                return (r:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):upper())
            end
        end
    end
end

local function GuideLinesOn()
    local s = type(_G.MastercraftDB) == "table" and _G.MastercraftDB.settings
    return not (type(s) == "table" and s.tipGuide == false)
end

-- Mastercraft's Settings > Modules (2.1.2): "Tooltip extras" off = no Mastercraft lines at all. Then a tooltip
-- says nothing about the item, and reading it would forget what's needed: learn nothing until it's back on.
local function TooltipLinesOn() return MasterOptions_Shared.MastercraftModuleOn("tip") end

local pending = false
local function Learn(tooltip, data)
    if tooltip ~= GameTooltip or not DB or not TooltipLinesOn() then return end
    local itemID = data and type(data.id) == "number" and data.id
    if not itemID then
        local _, link = tooltip:GetItem()
        itemID = link and tonumber(link:match("item:(%d+)"))
    end
    if not itemID then return end
    local changed = false
    -- Mastercraft's KEEP advice (tools, fishing things, what your recipes use ...): kept; another verdict lets go
    local okV, verdict = Check("reading Mastercraft's advice", pcall(VerdictIn, tooltip))
    if okV and verdict then
        local was = DB.keep[itemID] ~= nil
        local keep = verdict == "KEEP"
        DB.keep[itemID] = keep and time() or nil
        changed = changed or (was ~= keep)
    end
    -- "<Profession> guide needs N more"
    if GuideLinesOn() then
        local ok, needed = Check("reading Mastercraft's guide line", pcall(GuideLineIn, tooltip))
        if ok then
            local before = DB.needed[itemID] ~= nil
            if needed then DB.needed[itemID] = time() else DB.needed[itemID] = nil end
            changed = changed or (before ~= needed)
        end
    end
    if changed and not pending then
        pending = true
        C_Timer.After(1, function() pending = false; SyncGearMatic() end)
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        Check("learning from an item tooltip", pcall(Learn, tooltip, data))
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MasterOptions_MastercraftKeepDB = MasterOptions_MastercraftKeepDB or {}
        DB = MasterOptions_MastercraftKeepDB
        DB.needed = DB.needed or {}
        DB.keep = DB.keep or {}
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, SyncGearMatic)
    end
end)

-- (Master Options runs this after the saved variables are in: the setup this did on its own ADDON_LOADED as a
-- separate addon, now)
local h = f.GetScript and f:GetScript("OnEvent") or f.OnEvent -- (f.OnEvent: the sandbox tests' frames)
if h then h(f, "ADDON_LOADED", ADDON) end
end)
