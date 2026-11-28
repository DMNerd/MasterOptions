# Mastercraft_CheapDisenchants: the auction house's replicate list read for each green item's cheapest buyout, valued by
# Mastercraft's tooltip "Disenchant ~..." row, listed when it disenchants into more than it costs (biggest profit first);
# blues when ticked; the server's 15-minute limit; a row's click searches for it in the auction house's own Browse.
import sys
src = open(sys.argv[1], encoding="utf-8").read()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test; lua = module_test(_sys.argv[1])
from shared_lua import fake_tooltip; fake_tooltip(lua)
lua.execute(r'''
  FRAMES, TIMERS, ERRS, PRINTS, NOW = {}, {}, 0, {}, 100000
  function time() return NOW end
  function print(s) PRINTS[#PRINTS + 1] = s end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; io.write("ERR ", tostring(e), "\n") end
  local function Region()
    local r = { scripts = {}, shown = false }
    for _, m in ipairs({ "SetSize", "SetPoint", "SetHeight", "SetWidth", "SetJustifyH", "SetAllPoints", "SetColorTexture",
      "EnableMouse", "EnableMouseWheel", "SetChecked", "SetTexture", "SetFrameLevel", "SetHitRectInsets", "SetWordWrap",
      "SetAtlas", "SetAutoFocus", "ClearFocus", "ClearAllPoints", "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues", "SetEnabled" }) do r[m] = function() end end
    function r:SetValue(v) self.value = v end
    function r:LockHighlight() self.lit = true end
    function r:UnlockHighlight() self.lit = false end
    function r:GetStringWidth() return 60 end
    function r:GetText() return self.text end
    function r:HookScript(k, fn) self.scripts[k] = fn end
    function r:GetFrameLevel() return 1 end
    function r:GetHeight() return 600 end
    function r:GetScript(k) return self.scripts[k] end
    function r:IsObjectType() return true end
    function r:SetText(t) self.text = t end
    function r:SetScript(k, fn) self.scripts[k] = fn end
    function r:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function r:IsShown() return self.shown end
    function r:GetChecked() return self.checked end
    function r:CreateTexture() return Region() end
    function r:CreateFontString() return Region() end
    return r
  end
  function CreateFrame(kind, name, parent, template)
    local f = Region(); f.ev = {}
    function f:RegisterEvent(e) self.ev[e] = true end
    if template == "BasicFrameTemplateWithInset" then f.TitleText = Region() end
    if name then _G[name] = f end
    FRAMES[#FRAMES + 1] = f; return f
  end
  C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = fn end }
  function Run() for _ = 1, 50 do local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end end
  function Fire(e, ...) for _, f in ipairs(FRAMES) do if f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
  WorldFrame = {}
  -- the auction house: listings { itemID, quality, count, buyout }
  LIST = {
    { 1001, 2, 1, 5000 }, { 1001, 2, 1, 3000 },  -- green: cheapest 3000, disenchants into 4000
    { 1002, 2, 1, 10000 },                         -- green: disenchants into 8000 - not worth it
    { 1003, 3, 1, 1000 },                          -- blue: into 5000 (with blues)
    { 1004, 1, 1, 10 },                            -- white: never
    { 1005, 2, 2, 2000 },                          -- green, a stack of 2: 1000 each, into 1500
    { 1006, 2, 1, 100 },                           -- green with no Disenchant row
    { 1007, 2, 1, 1000 },                          -- green: into 9000, needs an enchanter
    { 1001, 2, 1, 1, "Me" },                       -- your own auction: never counted
  }
  DE = { [1001] = 4000, [1002] = 8000, [1003] = 5000, [1005] = 1500, [1007] = 9000 }
  -- the client's item data (name, link, quality, item level - none here: each its own group - ..., texture), from the
  -- listings' quality; NOTLOADED: not in the client yet (loaded through Item:ContinueOnItemLoad)
  NOTLOADED = {}
  function GetItemInfo(id)
    if NOTLOADED[id] then return nil end
    local q
    for _, l in ipairs(LIST) do if l[1] == id then q = l[2] end end
    if ITEMQ and ITEMQ[id] then q = ITEMQ[id] end
    if not q then return nil end
    return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "|h[Item " .. id .. "]|h|r", q, nil, 1, "Armor", "Cloth", 1, "INVTYPE_CHEST", 0, "tex" .. id
  end
  LOADS = {}
  Item = { CreateFromItemID = function(_, id) return { ContinueOnItemLoad = function(_, fn) LOADS[#LOADS + 1] = function() NOTLOADED[id] = nil; fn() end end } end }
  local function Coins(c) -- (the game's money string: coin icons)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local o = ""
    if g > 0 then o = o .. g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t " end
    if s > 0 then o = o .. s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t " end
    if k > 0 then o = o .. k .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
    return o
  end
  function UnitName() return "Me" end
  function IsShiftKeyDown() return SHIFT == true end
  REPLICATES = 0
  C_AuctionHouse = {
    ReplicateItems = function() REPLICATES = REPLICATES + 1 end,
    GetNumReplicateItems = function() return #LIST end,
    GetReplicateItemInfo = function(i) local l = LIST[i + 1]
      return "Item " .. l[1], "tex" .. l[1], l[3], l[2], true, 10, 0, 0, 0, l[4], 0, false, nil, l[5] or "Seller", "x", 0, l[1], true end,
    GetReplicateItemLink = function(i) local id = LIST[i + 1][1]; return "|cff1eff00|Hitem:" .. id .. "|h[Item " .. id .. "]|h|r" end,
  }
  -- the game's tooltip hook (TooltipDataProcessor): Master Options' advice listeners hear every item tooltip
  POSTCALLS, LEARNED, READS = {}, 0, 0
  Enum = { TooltipDataType = { Item = 0 } }
  TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) POSTCALLS[#POSTCALLS + 1] = fn end }
  MasterOptions_Shared.OnMastercraftAdvice("test", function() LEARNED = LEARNED + 1 end)
  function GameTooltip:SetHyperlink(link)
    local id = tonumber(link:match("item:(%d+)"))
    READS = READS + 1
    for _, fn in ipairs(POSTCALLS) do fn(self, { id = id }) end
    LEFT, RIGHT = { "Item " .. id, " ", "|cff4da6ffMastercraft|r" }, { nil, nil, "|cffaaaaaaDISENCHANT|r" }
    if DE[id] then LEFT[#LEFT + 1] = "Disenchant"; RIGHT[#LEFT] = "~" .. Coins(DE[id]) end
    if id == 1007 then LEFT[#LEFT + 1] = "Needs an enchanter - a friend or guild mate." end
  end
  SEARCHED = nil
  function hooksecurefunc(t, k, fn) local o = t[k]; t[k] = function(...) local r = o(...); fn(...); return r end end
  AuctionHouseFrame = { SearchBar = { SearchBox = { SetText = function(_, t) SEARCHED = t end }, StartSearch = function() STARTED = true end },
    SetDisplayMode = function(_, m) MODE = m end, SetTitle = function(_, t) TITLE = t end, GetFrameLevel = function() return 1 end,
    Tabs = { { name = "Buy" }, { name = "Sell" } } }
  LINKED = nil
  ChatEdit_InsertLink = function(l) LINKED = l end
  AuctionHouseFrameDisplayMode = { Buy = { "BrowseResultsFrame", "SearchBar" } }
  function Order() local o = {} for _, e in ipairs(MasterOptions_CheapDisenchants.Results()) do o[#o + 1] = e.itemID .. "+" .. e.profit end return table.concat(o, ",") end
''')
# Master Options' own LibStub and LibAHTab (Libs), as the .toc loads them before the modules
libs = _os.path.join(_os.path.dirname(_os.path.dirname(_os.path.abspath(sys.argv[1]))), "Libs")
lua.execute("function PanelTemplates_TabResize() end; function PanelTemplates_DeselectTab(t) t.selected = false end; function PanelTemplates_SelectTab(t) t.selected = true end")
for lib in ("LibStub.lua", "LibAHTab.lua"):
    lua.eval("function(s, n) return load(s, '=' .. n) end")(open(_os.path.join(libs, lib), encoding="utf-8").read(), lib)()
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_Mastercraft_CheapDisenchants")
E, L = lua.eval, lua.execute
P = "MasterOptions_CheapDisenchants.ParseMoney"
res = {
    "money: coin icons": E(P + '("1|TInterface\\\\MoneyFrame\\\\UI-GoldIcon:0:0:2:0|t 20|TInterface\\\\MoneyFrame\\\\UI-SilverIcon:0:0:2:0|t 5|TInterface\\\\MoneyFrame\\\\UI-CopperIcon:0:0:2:0|t")') == 12005,
    "money: thousands with a comma": E(P + '("1,234|TInterface\\\\MoneyFrame\\\\UI-GoldIcon:0:0:2:0|t")') == 12340000,
    "money: 1g 20s 5c (colourblind)": E(P + '("1g 20s 5c")') == 12005,
    "money: coloured, with ~": E(P + '("~|cffffffff2|r|TInterface\\\\MoneyFrame\\\\UI-SilverIcon:0:0:2:0|t")') == 200,
    "money: no price": E(P + '("no price")') is None,
}
L('Fire("ADDON_LOADED", "MasterOptions_Mastercraft_CheapDisenchants"); Fire("AUCTION_HOUSE_SHOW")')
TAB = '_G["LibAHFrame-1.0-MasterOptions_CheapDisenchants"]'
res["at the auction house: a Cheap Disenchants tab, through Master Options' own LibAHTab"] = E(TAB + " ~= nil and " + TAB + ".text") == "Cheap Disenchants"
L(TAB + '.scripts.OnClick(' + TAB + ')')
res["...its click: the window shown, the auction house's own view put away, its title"] = E("MasterOptionsCheapDisenchants.shown and type(MODE) == 'table' and TITLE == 'Cheap Disenchants'") is True
L('MasterOptions_CheapDisenchants.Scan()')
res["Scan AH: one full read of the auction house asked for"] = E("REPLICATES") == 1
L('Fire("REPLICATE_ITEM_LIST_UPDATE"); Run()')
res["greens worth disenchanting, cheapest listing each (stacks per item), the biggest profit first"] = E("Order()") == "1007+8000,1001+1000,1005+500"
res["a scan's tooltip reads are quiet: Master Options' modules learn nothing from auction house items"] = E("LEARNED") == 0 and E("READS") > 0
res["...needs an enchanter: marked"] = E("MasterOptions_CheapDisenchants.Results()[1].enchanter") is True
res["...the list shows them"] = E("MasterOptionsCheapDisenchants.rows[1].entry ~= nil and MasterOptionsCheapDisenchants.rows[4].shown == false") is True
res["...the Scan button counts down the server's 15 minutes"] = "(15:00)" in (E("MasterOptionsCheapDisenchants.scan.text") or "")
L('MasterOptionsCheapDisenchants.headers.buyout.scripts.OnClick()')
res["a column header: sorted by it (Buyout, highest first; the same buyout by name)"] = E("Order()") == "1001+1000,1005+500,1007+8000"
L('MasterOptionsCheapDisenchants.headers.buyout.scripts.OnClick()')
res["...again: the other way"] = E("Order()") == "1005+500,1007+8000,1001+1000"
L('MasterOptionsCheapDisenchants.headers.profit.scripts.OnClick()')
L('NOW = NOW + 60; READS = 0; MasterOptions_CheapDisenchantsDB.blues = true; MasterOptions_CheapDisenchants.Scan(); Run()')
res["scanned again within 10 minutes: only the new item read (values kept)"] = E("READS") == 1
res["Scan again within 15 minutes: not asked again, the last read valued again (blues ticked: the blue too)"] = E("REPLICATES") == 1 and E("Order()") == "1007+8000,1003+4000,1001+1000,1005+500"
res["...and says when it can read again"] = "in 14 min" in (E("PRINTS[#PRINTS]") or "")
L('NOW = NOW + 15 * 60; MasterOptions_CheapDisenchants.Scan()')
res["after 15 minutes: asked again"] = E("REPLICATES") == 2
L('Fire("REPLICATE_ITEM_LIST_UPDATE"); Run(); SHIFT = true; MasterOptionsCheapDisenchants.rows[2].scripts.OnClick(MasterOptionsCheapDisenchants.rows[2]); SHIFT = false')
res["Shift-click a row: its link in chat"] = "item:1003" in (E("LINKED") or "")
L('MasterOptionsCheapDisenchants.rows[2].scripts.OnClick(MasterOptionsCheapDisenchants.rows[2])')
res["a row's click: the auction house's Buy view searches for it by its exact name"] = E("SEARCHED") == '"Item 1003"' and E("STARTED") is True and E("MODE == AuctionHouseFrameDisplayMode.Buy") is True
res["...and the game's view puts our window away"] = E("MasterOptionsCheapDisenchants.shown") is False
L('LIST[2][4] = 1; Fire("REPLICATE_ITEM_LIST_UPDATE"); Run()')
res["another addon's read while our tab isn't open: left alone"] = E("Order()") == "1007+8000,1003+4000,1001+1000,1005+500"
# Valued by group: every item of one quality, item level and weapon / armour disenchants into the same (Mastercraft's
# DisenchantResults) - one tooltip read per group, then only the items cheaper than their group's value read on their
# own (an item that can't be disenchanted drops out there). Shirts and tabards are never read.
L(r'''
  ITEM = {}  -- itemID -> { ilvl, classID, equipLoc }
  C_Item = { GetDetailedItemLevelInfo = function(link) local i = ITEM[tonumber(link:match("item:(%d+)"))]; return i and i[1] end,
             GetItemInfoInstant = function(link) local id = type(link) == "number" and link or tonumber(link:match("item:(%d+)")); local i = ITEM[id]
               if i then return id, nil, nil, i[3], nil, i[2] end end }
  LIST = {}
  for k = 0, 29 do -- thirty greens of item level 20, armour: they all disenchant into 5000
    local id = 2000 + k
    ITEM[id] = { 20, 4, "INVTYPE_CHEST" }
    DE[id] = 5000
    LIST[#LIST + 1] = { id, 2, 1, 1000 + k * 500 } -- 1000 .. 15500: the first eight cost less than 5000
  end
  DE[2003] = nil               -- one of the cheap ones can't be disenchanted (no Disenchant row on its own tooltip)
  ITEM[2100] = { 20, 4, "INVTYPE_BODY" }; DE[2100] = 9000; LIST[#LIST + 1] = { 2100, 2, 1, 10 } -- a shirt: never
  ITEM[2200] = { 20, 2, "INVTYPE_WEAPON" }; DE[2200] = 7000; LIST[#LIST + 1] = { 2200, 2, 1, 6000 } -- a weapon: its own group
  MasterOptions_CheapDisenchantsDB.blues = false
  NOW = NOW + 16 * 60; READS = 0
  MasterOptions_CheapDisenchants.Scan(); Fire("REPLICATE_ITEM_LIST_UPDATE"); Run()
  function Has(id) for _, e in ipairs(MasterOptions_CheapDisenchants.Results()) do if e.itemID == id then return e end end end
''')
res["grouped: the cheap items of the group listed (an item that can't be disenchanted left out), the weapon by its own value"] = E(
    "#MasterOptions_CheapDisenchants.Results()") == 8 and E("Has(2000) ~= nil and Has(2000).profit == 4000 and Has(2003) == nil and Has(2200) ~= nil and Has(2200).profit == 1000") is True
res["grouped: a shirt never read or listed"] = E("Has(2100) == nil") is True
res["grouped: 32 items, 2 groups - one read per group and one per cheap find, not one per item"] = 0 < E("READS") <= 2 + 9
# Max price (as CheapUpgrades' "Max price:"): what costs more isn't listed; changing it lists the last scan again (no
# new scan, values kept: nothing read again); saved
L('READS = 0; R0 = REPLICATES; MasterOptions_CheapDisenchants.SetMaxPrice(3000); Run()')
res["max price 30s: only what costs up to it listed (the 1000-3000 ones), the weapon at 60s gone"] = E(
    "#MasterOptions_CheapDisenchants.Results()") == 4 and E("Has(2200) == nil and Has(2004) ~= nil and Has(2005) == nil") is True
res["...saved, no new scan, nothing read again"] = E("MasterOptions_CheapDisenchantsDB.maxPrice") == 3000 and E("REPLICATES") == E("R0") and E("READS") == 0
L('MasterOptions_CheapDisenchants.SetMaxPrice(0); Run()')
res["max price 0: no max, every find back"] = E("#MasterOptions_CheapDisenchants.Results()") == 8 and E("MasterOptions_CheapDisenchantsDB.maxPrice") is None
# The Cheapest list: everything that can be disenchanted, the cheapest first - the dear ones by their group's value (a
# loss), the one that can't be disenchanted and the shirt still out; switching reads nothing again
L('READS = 0; MasterOptionsCheapDisenchants.modeCheap.scripts.OnClick(); MasterOptionsCheapDisenchants:Show()')
res["Cheapest: every item that can be disenchanted, the cheapest first, nothing read again"] = E(
    "#MasterOptions_CheapDisenchants.Results()") == 30 and E("MasterOptions_CheapDisenchants.Results()[1].itemID") == 2000 and E(
    "Has(2029) ~= nil and Has(2029).profit == 5000 - 15500 and Has(2003) == nil and Has(2100) == nil") is True and E("READS") == 0
res["...saved, its button lit, a loss in red"] = E("MasterOptions_CheapDisenchantsDB.mode") == "cheap" and E(
    "MasterOptionsCheapDisenchants.modeCheap.lit and not MasterOptionsCheapDisenchants.modeProfit.lit") is True and any(
    "ff6666-" in (E("MasterOptionsCheapDisenchants.rows[%d].profit.text" % i) or "") for i in range(1, 25))
L('MasterOptionsCheapDisenchants.modeProfit.scripts.OnClick(); MasterOptionsCheapDisenchants:Hide()')
res["...Profitable again: the finds only, the biggest profit first"] = E("#MasterOptions_CheapDisenchants.Results()") == 8 and E(
    "MasterOptions_CheapDisenchantsDB.mode") is None and E("MasterOptions_CheapDisenchants.Results()[1].profit") == 4000
# Our own read under the game's flood of REPLICATE_ITEM_LIST_UPDATE (one per row whose data comes in): read once, to
# the end - not restarted by each - and its echoes afterwards read nothing again
L(r'''
  function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
  ROWREADS = 0
  local get = C_AuctionHouse.GetReplicateItemInfo
  C_AuctionHouse.GetReplicateItemInfo = function(i) ROWREADS = ROWREADS + 1; return get(i) end
  ITEM[3001] = { 25, 4, "INVTYPE_LEGS" }; DE[3001] = 6000
  LIST = { { 3001, 2, 1, 2000 }, { 3001, 2, 1, 2500 } }
  NOW = NOW + 16 * 60
  MasterOptions_CheapDisenchants.Scan(); R1 = REPLICATES
  Fire("REPLICATE_ITEM_LIST_UPDATE")
  for _ = 1, 3 do RunTimers(); for _ = 1, 30 do Fire("REPLICATE_ITEM_LIST_UPDATE") end end
  Run()
''')
res["flood of list events during our read: read to the end once, the find listed"] = E("Has(3001) ~= nil and Has(3001).profit == 4000") is True and E("ROWREADS") == 2
L('R2 = ROWREADS; for _ = 1, 50 do Fire("REPLICATE_ITEM_LIST_UPDATE") end; Run()')
res["...the events after it (its echoes): nothing read again"] = E("ROWREADS") == E("R2")
res["...the Scan button free again (not stuck on Scanning)"] = "Scanning" not in (E("MasterOptionsCheapDisenchants.scan.text") or "")

# With Auctionator: Scan AH starts its quick scan (no 15 minutes), its rows taken when it says it's complete; an item
# whose data isn't in the client yet is loaded first
L(r'''
  QUICKS, LISTENER = 0, nil
  Auctionator = {
    EventBus = { Register = function(_, obj, events) LISTENER = obj; LISTENED = events end },
    IncrementalScan = { Events = { ScanComplete = "full_incremental_scan_complete" } },
    FullScan = { Events = { ScanComplete = "replicate_scan_complete" } },
    State = { IncrementalScanFrameRef = { InitiateScan = function() QUICKS = QUICKS + 1 end }, FullScanFrameRef = {} },
  }
  Fire("AUCTION_HOUSE_SHOW")
  ITEMQ = { [4001] = 2, [4002] = 2, [4003] = 2, [5001] = 2 }
  for _, id in ipairs({ 4001, 4002, 4003, 5001 }) do ITEM[id] = { 30, 4, "INVTYPE_FEET" }; DE[id] = 3000 end
  ITEM[4003] = { 31, 4, "INVTYPE_FEET" } -- (its own group: its tooltip read once it's loaded)
  NOTLOADED[4003] = true
  R3 = REPLICATES
  MasterOptions_CheapDisenchants.Scan()
''')
res["with Auctionator: Scan AH starts its quick scan, not our own 15-minute read"] = E("QUICKS") == 1 and E("REPLICATES") == E("R3") and E("LISTENER ~= nil")
L(r'''
  LISTENER:ReceiveEvent("full_incremental_scan_complete", {
    { itemKey = { itemID = 4001, itemLevel = 30 }, minPrice = 500, totalQuantity = 3 },
    { itemKey = { itemID = 4002, itemLevel = 30 }, minPrice = 100, totalQuantity = 0 },  -- (none left)
    { itemKey = { itemID = 4003, itemLevel = 31 }, minPrice = 700, totalQuantity = 1 },  -- (data not loaded yet)
  })
''')
res["Auctionator's quick scan: its rows listed (none left: not), while an item's data is loading the rest waits"] = E("Has(4001)") is None
L('for _, fn in ipairs(LOADS) do fn() end; LOADS = {}; Run(); MasterOptionsCheapDisenchants:Show()')
res["...once loaded: listed, with the loaded one, by their lowest price"] = E("Has(4001) ~= nil and Has(4001).profit == 2500 and Has(4003) ~= nil and Has(4002) == nil") is True
res["...the footer says where it came from"] = "Auctionator's quick scan" in (E("MasterOptionsCheapDisenchants.count.text") or "")
res["...with Auctionator: a Quick scan button, and the full scan beside it as Full scan"] = E("MasterOptionsCheapDisenchants.quick.shown and MasterOptionsCheapDisenchants.quick.text == 'Quick scan'") is True and (E("MasterOptionsCheapDisenchants.scan.text") or "").find("Full scan") >= 0

# Auctionator's full scan finishing while our tab is closed: kept, and listed when the tab opens
L(r'''
  MasterOptionsCheapDisenchants:Hide()
  LISTENER:ReceiveEvent("replicate_scan_complete", {
    { replicateInfo = { "Item 5001", "tex", 1, 2, true, 10, 0, 0, 0, 900, 0, false, nil, "Seller", "x", 0, 5001, true }, itemLink = "x" },
    { replicateInfo = { "Item 5001", "tex", 1, 2, true, 10, 0, 0, 0, 1, 0, false, nil, "Me", "x", 0, 5001, true }, itemLink = "x" }, -- (yours)
  })
  Run()
''')
res["Auctionator's full scan with our tab closed: not read then"] = E("Has(5001)") is None
L('MasterOptionsCheapDisenchants:Show(); Run()')
res["...read when the tab opens (your own auction left out)"] = E("Has(5001) ~= nil and Has(5001).buyout == 900") is True
# Your own auctions in Auctionator's quick scan (containsOwnerItem): yours alone - not listed; yours among others -
# listed, marked "the cheapest may be yours"
L(r'''
  for _, id in ipairs({ 6001, 6002 }) do ITEMQ[id] = 2; ITEM[id] = { 40, 4, "INVTYPE_HAND" }; DE[id] = 9000 end
  LISTENER:ReceiveEvent("full_incremental_scan_complete", {
    { itemKey = { itemID = 6001 }, minPrice = 1000, totalQuantity = 1, containsOwnerItem = true },  -- only yours
    { itemKey = { itemID = 6002 }, minPrice = 1000, totalQuantity = 4, containsOwnerItem = true },  -- yours among others
  })
  Run()
''')
res["quick scan, only your own listing: not listed"] = E("Has(6001)") is None
res["quick scan, yours among others: listed, marked (the cheapest may be yours)"] = E("Has(6002) ~= nil and Has(6002).yours == true") is True
L('MasterOptionsCheapDisenchants:Show()')
res["...the row says so, and the profit shows its share of the price"] = any(
    "may be yours" in (E("MasterOptionsCheapDisenchants.rows[%d].sub.text" % i) or "") and "800%" in (E("MasterOptionsCheapDisenchants.rows[%d].profit.text" % i) or "")
    for i in range(1, 4))

# Hide "needs an enchanter": left out at once, back when unticked
L(r'''
  ITEMQ[6003] = 2; ITEM[6003] = { 41, 4, "INVTYPE_HAND" }; DE[6003] = 9000; NEEDS = { [6003] = true }
  local set = GameTooltip.SetHyperlink
  function GameTooltip:SetHyperlink(link) set(self, link); if NEEDS[tonumber(link:match("item:(%d+)"))] then LEFT[#LEFT + 1] = "Needs an enchanter - a friend or guild mate." end end
  LISTENER:ReceiveEvent("full_incremental_scan_complete", { { itemKey = { itemID = 6003 }, minPrice = 1000, totalQuantity = 2 } })
  Run()
''')
res["needs an enchanter: listed and marked"] = E("Has(6003) ~= nil and Has(6003).enchanter == true") is True
L('MasterOptions_CheapDisenchantsDB.hideEnchanter = true; MasterOptions_CheapDisenchants.Rerank()')
res["Hide \"needs an enchanter\": left out"] = E("Has(6003)") is None
L('MasterOptions_CheapDisenchantsDB.hideEnchanter = nil; MasterOptions_CheapDisenchants.Rerank()')
res["...unticked: back"] = E("Has(6003) ~= nil") is True

# Full scan with Auctionator: its own full scan (its 15 minutes), rows taken when it says it's complete
L(r'''
  FULLS, CANFULL = 0, true
  Auctionator.State.FullScanFrameRef = { state = {}, InitiateScan = function() FULLS = FULLS + 1 end,
    CanInitiate = function() return CANFULL end }
  R4 = REPLICATES
  MasterOptions_CheapDisenchants.ScanFull()
''')
res["Full scan with Auctionator: Auctionator's full scan started, not ours"] = E("FULLS") == 1 and E("REPLICATES") == E("R4")
L(r'''
  ITEMQ[7001] = 2; ITEM[7001] = { 45, 2, "INVTYPE_WEAPON" }; DE[7001] = 20000
  LISTENER:ReceiveEvent("replicate_scan_complete", {
    { replicateInfo = { "Item 7001", "tex", 1, 2, true, 10, 0, 0, 0, 5000, 0, false, nil, "Seller", "x", 0, 7001, true } } })
  Run()
''')
res["...its rows listed when it's complete"] = E("Has(7001) ~= nil and Has(7001).buyout == 5000") is True
L('CANFULL = false; FULLS = 0; Auctionator.State.FullScanFrameRef.state.TimeOfLastReplicateScan = NOW; MasterOptions_CheapDisenchants.ScanFull()')
res["Full scan within Auctionator's 15 minutes: not started, says when it can"] = E("FULLS") == 0 and "full scan can run again in 15 min" in (E("PRINTS[#PRINTS]") or "")

# the empty list says what to do
L(r'''
  MasterOptionsCheapDisenchants:Show()
  MasterOptions_CheapDisenchants.SetMaxPrice(1)
  Run()
''')
res["nothing found under the max price: the empty list says so"] = "Up to" in (E("MasterOptionsCheapDisenchants.empty.text") or "") and E("MasterOptionsCheapDisenchants.empty.shown") is True
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
