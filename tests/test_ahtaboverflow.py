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
  function Base:GetStringWidth() return 80 end
  function Base:CreateTexture() return New() end
  function Base:CreateFontString() return New() end
  function Base:SetTextColor(r, g, b) self.color = { r, g, b } end
  local meta = { __index = function(_, k) return Base[k] or function() end end }
  function New() return setmetatable({ scripts = {}, shown = false }, meta) end
  CreateFrame = function(_, name) local f = New(); f.ev = {}
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self.scripts[k] = fn; if k == "OnEvent" then self.OnEvent = fn end end
    if name then _G[name] = f end
    FRAMES[#FRAMES + 1] = f; return f end
  SELECTED = {}
  function PanelTemplates_SelectTab(t) SELECTED[t] = true end
  function PanelTemplates_DeselectTab(t) SELECTED[t] = nil end
  -- ten tabs, 100 wide each from 0: rights 100 .. 1000; the window's right edge at 800
  local n = 0
  local function Tab(text)
    n = n + 1
    local t = New(); t.shown = true; t.text = text; t.right = n * 100
    function t:GetRight() return self.right end
    t.scripts.OnClick = function() CLICKED = text end
    return t
  end
  AH_RIGHT = 800
  AuctionHouseFrame = New(); AuctionHouseFrame.shown = true
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
res["...a More tab after the last that fits"] = E("MasterOptions_AuctionHouseTabOverflow.More().shown") is True and E(
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
res["all fit: every tab back, no More"] = E("Names()") == "" and E("LIB.internalState.Tabs[7].shown") is True and E(
    "MasterOptions_AuctionHouseTabOverflow.More().shown") is False
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
