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
      "SetAtlas" }) do r[m] = function() end end
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
             GetItemInfoInstant = function(link) local id = tonumber(link:match("item:(%d+)")); local i = ITEM[id]
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
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
