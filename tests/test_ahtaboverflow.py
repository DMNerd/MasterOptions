# AuctionHouse_TabOverflow: the auction house's tab row (the game's tabs and LibAHTab's) kept to the window's width -
# what would reach past its right edge hidden and listed in a "More" tab; a pick there opens that tab; More bears the
# open tab's name and shows chosen; all back when they fit.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # (run with -I: the tests' own folder for shared_lua)
import shared_lua
MODULE = sys.argv[1]
lua = shared_lua.module_test(MODULE)
shared_lua.fake_frames(lua, timers_now=True)
src = shared_lua.module_source(MODULE)
lua.execute(r'''
  function hooksecurefunc(t, k, fn)
    if type(t) == "string" then t, k, fn = _G, t, k end
    local old = t[k]
    t[k] = function(...) local r = old(...); fn(...); return r end
  end
  -- frames: every method a no-op unless given here
  local Base = {}
  function Base:Show() self.shown = true end
  function Base:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
  function Base:IsShown() return self.shown end
  function Base:SetScript(k, fn) self.scripts[k] = fn end
  function Base:HookScript(k, fn) self.scripts[k] = fn end
  function Base:GetScript(k) return self.scripts[k] end
  function Base:SetText(t) self.text = t end
  function Base:GetText() return self.text end
  function Base:SetPoint(...) self.point = { ... } end
  function Base:GetWidth() return 90 end
  function Base:GetPoint() local p = self.point or {}; return p[1], p[2], p[3], p[4], p[5] end
  function Base:ClearAllPoints() self.point = nil end
  function Base:GetStringWidth() return 80 end
  function Base:CreateTexture() return New() end
  function Base:CreateFontString() return New() end
  function Base:SetTextColor(r, g, b) self.color = { r, g, b } end
  local meta = { __index = function(_, k) return Base[k] or (type(k) == "string" and k:match("^%u") and function() end) or nil end }
  function New() return setmetatable({ scripts = {}, shown = false }, meta) end
  -- (the game's tab template puts each tab made with it into its parent's Tabs: parentArray)
  CreateFrame = function(_, name, parent, template) local f = New(); f.ev = {}
    if template == "AuctionHouseFrameDisplayModeTabTemplate" and parent then
      parent.Tabs = rawget(parent, "Tabs") or {}; table.insert(parent.Tabs, f)
    end
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self.scripts[k] = fn; if k == "OnEvent" then self.OnEvent = fn end end
    if name then _G[name] = f end
    FRAMES[#FRAMES + 1] = f; return f end
  SELECTED = {}
  function PanelTemplates_SelectTab(t) SELECTED[t] = true end
  function PanelTemplates_DeselectTab(t) SELECTED[t] = nil end
  -- ten tabs, 100 wide each from 0: rights 100 .. 1000; the window's right edge at 800
  local prev
  AuctionHouseFrame = New(); AuctionHouseFrame.shown = true
  local function Tab(text)
    local t = New(); t.shown = true; t.text = text
    t.point = prev and { "TOPLEFT", prev, "TOPRIGHT", 3, 0 } or { "TOPLEFT", AuctionHouseFrame, "BOTTOMLEFT", 10, 0 }
    function t:GetLeft() return 0 end
    t.scripts.OnClick = function() CLICKED = text end
    prev = t
    return t
  end
  AH_RIGHT = 800
  MasterOptionsDB = {}
  AuctionHouseFrame.Tabs = { Tab("Buy"), Tab("Sell"), Tab("Auctions") }
  function AuctionHouseFrame:GetRight() return AH_RIGHT end
  function AuctionHouseFrame:SetDisplayMode() end
  LIB = { internalState = { Tabs = {} } }
  for _, s in ipairs({ "Upgrades", "Alts", "Cheap Disenchants", "Shopping", "Selling", "Cancelling", "Auctionator" }) do
    table.insert(LIB.internalState.Tabs, Tab(s))
  end
  function LIB:CreateTab() end
  function LIB:GetButton(id) return self.byID[id] end
  function LIB:SetSelected() end
  LIB.byID = { sell = LIB.internalState.Tabs[5], shop = LIB.internalState.Tabs[4] }
  LibStub = function() return LIB end
  function Names() local t = {}; for _, x in ipairs(MasterOptions_AuctionHouseTabOverflow.Overflow()) do t[#t + 1] = x.text end; return table.concat(t, ",") end
''')
lua.eval("function(s) return load(s, '=ahtaboverflow') end")(src)("MasterOptions_AuctionHouse_TabOverflow")
E, L = lua.eval, lua.execute
res = {}
L('Fire("AUCTION_HOUSE_SHOW")')
res["the tabs past the window's edge (with room for More) hidden and listed, in order"] = E("Names()") == "Selling,Cancelling,Auctionator" and E(
    "LIB.internalState.Tabs[5].shown == false and LIB.internalState.Tabs[4].shown == true") is True
res["...More not one of the auction house's own tabs (no anchor loop)"] = E(
    "(function() for _, t in ipairs(AuctionHouseFrame.Tabs) do if t == MasterOptions_AuctionHouseTabOverflow.More() then return false end end return #AuctionHouseFrame.Tabs == 3 end)()") is True
res["...a More tab after the last that fits"] =E("MasterOptions_AuctionHouseTabOverflow.More().shown") is True and E(
    "MasterOptions_AuctionHouseTabOverflow.More().point[2] == LIB.internalState.Tabs[4]") is True and E(
    "MasterOptions_AuctionHouseTabOverflow.More().text:find('^More') ~= nil") is True
L('local m = MasterOptions_AuctionHouseTabOverflow.More(); m.scripts.OnClick(m)')
res["More's click: the list of them"] = E("MasterOptionsAHTabMore.shown") is True and E("MasterOptionsAHTabMore.rows[2].text.text") == "Cancelling"
L('MasterOptionsAHTabMore.rows[1].scripts.OnClick(MasterOptionsAHTabMore.rows[1])')
res["a pick there: that tab opened (its own click), the list closed"] = E("CLICKED") == "Selling" and E("MasterOptionsAHTabMore.shown") is False
L('LIB:SetSelected("sell")')
res["...while it's open: More bears its name and shows chosen"] = E("MasterOptions_AuctionHouseTabOverflow.More().text:find('^Selling') ~= nil") is True and E(
    "SELECTED[MasterOptions_AuctionHouseTabOverflow.More()]") is True
L('LIB:SetSelected("shop")')
res["a tab in the row chosen: More back to More, not chosen"] = E("MasterOptions_AuctionHouseTabOverflow.More().text:find('^More') ~= nil") is True and E(
    "SELECTED[MasterOptions_AuctionHouseTabOverflow.More()]") is None
L('AH_RIGHT = 1200; AuctionHouseFrame.scripts.OnShow()')
res["all fit: every tab back in the row (More stays, for Arrange tabs)"] = E("Names()") == "" and E("LIB.internalState.Tabs[7].shown") is True
L('local m = MasterOptions_AuctionHouseTabOverflow.More(); m.scripts.OnClick(m)')
res["...More's click then: straight to where each tab goes"] = E("MasterOptionsAHTabMore.rows[1].text.text") == "Buy" and "Auto" in (
    E("MasterOptionsAHTabMore.rows[1].place.text") or "") and "Done" in (E("MasterOptionsAHTabMore.rows[11].text.text") or "")
# Arrange tabs: a click goes round Auto -> Always in row -> Always in More; saved by the tab; the row laid out again
L(r'''
  MasterOptionsAHTabMore.rows[11].scripts.OnClick(MasterOptionsAHTabMore.rows[11]) -- (Done)
  AH_RIGHT = 800; MasterOptions_AuctionHouseTabOverflow.Layout()
  local m = MasterOptions_AuctionHouseTabOverflow.More(); m.scripts.OnClick(m); m.scripts.OnClick(m) -- (closed, opened)
''')
res["More's list ends with Arrange tabs..."] = "Arrange" in (E("MasterOptionsAHTabMore.rows[4].text.text") or "")
L(r'''
  MasterOptionsAHTabMore.rows[4].scripts.OnClick(MasterOptionsAHTabMore.rows[4])
  local rows = MasterOptionsAHTabMore.rows
  rows[1].scripts.OnClick(rows[1]); rows[1].scripts.OnClick(rows[1])   -- Buy: Always in More
  rows[10].scripts.OnClick(rows[10])                                   -- Auctionator: Always in row
''')
res["Buy always in More, Auctionator always in row: saved"] = E("MasterOptionsDB.ahTabs.Buy") == "more" and E("MasterOptionsDB.ahTabs.Auctionator") == "row"
res["...More lists Buy and what didn't fit after Auctionator took its room"] = E("Names()") == "Buy,Selling,Cancelling" and E(
    "LIB.internalState.Tabs[7].shown") is True and E("AuctionHouseFrame.Tabs[1].shown") is False
res["...the row starts where Buy did (no gap), Auctionator chained after Shopping"] = E(
    "AuctionHouseFrame.Tabs[2].point[2] == AuctionHouseFrame and AuctionHouseFrame.Tabs[2].point[4] == 10") is True and E(
    "LIB.internalState.Tabs[7].point[2] == LIB.internalState.Tabs[4]") is True
res["...the arrange list shows it"] = "Always in More" in (E("MasterOptionsAHTabMore.rows[1].place.text") or "")
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
