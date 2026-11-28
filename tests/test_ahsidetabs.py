# AuctionHouse_SideTabs: the auction house's tabs (the game's and LibAHTab's) stacked down the window's side, one
# width; on the left when the right is off the screen; again when a tab is added later or the game sizes one again.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # (run with -I: the tests' own folder for shared_lua)
import shared_lua
MODULE = sys.argv[1]
lua = shared_lua.module_test(MODULE)
shared_lua.fake_frames(lua, timers_now=True)
src = shared_lua.module_source(MODULE)
lua.execute(r'''
  HOOKS = {}
  function hooksecurefunc(t, k, fn)
    if type(t) == "string" then t, k, fn = _G, t, k end
    local old = t[k]
    t[k] = function(...) local r = old(...); fn(...); return r end
  end
  local function Tab(text, textW)
    local t = { shown = true, w = 70, text = text }
    t.Text = { GetStringWidth = function() return textW end }
    function t:IsShown() return self.shown end
    function t:GetHeight() return 32 end
    function t:ClearAllPoints() self.point = nil end
    function t:SetWidth(w) self.w = w end
    function t:SetPoint(...) self.point = { ... } end
    return t
  end
  NewTab = Tab
  function PanelTemplates_TabResize(tab) tab.w = 70 end
  SCREEN_RIGHT, AH_RIGHT = 1920, 900
  UIParent = { GetRight = function() return SCREEN_RIGHT end }
  AuctionHouseFrame = { Tabs = { Tab("Buy", 30), Tab("Sell", 30), Tab("Auctions", 60) }, scripts = {} }
  function AuctionHouseFrame:GetRight() return AH_RIGHT end
  function AuctionHouseFrame:HookScript(k, fn) self.scripts[k] = fn end
  function AuctionHouseFrame:SetDisplayMode() end
  LIB = { internalState = { Tabs = { Tab("Shopping", 60), Tab("Cheap Disenchants", 120) } } }
  function LIB:CreateTab(_, _, text) table.insert(self.internalState.Tabs, NewTab(text, 50)) end
  function LIB:SetSelected() end
  LibStub = function() return LIB end
  function All() local t = {}; for _, x in ipairs(AuctionHouseFrame.Tabs) do t[#t + 1] = x end
    for _, x in ipairs(LIB.internalState.Tabs) do t[#t + 1] = x end; return t end
''')
lua.eval("function(s) return load(s, '=ahsidetabs') end")(src)("MasterOptions_AuctionHouse_SideTabs")
E, L = lua.eval, lua.execute
res = {}
L('Fire("AUCTION_HOUSE_SHOW")')
res["the game's tabs and LibAHTab's stacked down the window's right, in order"] = E(r'''(function()
  for i, t in ipairs(All()) do
    local p = t.point
    if not (p and p[1] == "TOPLEFT" and p[2] == AuctionHouseFrame and p[3] == "TOPRIGHT" and p[5] == -(32 + (i - 1) * 28)) then return false end
  end
  return true end)()''') is True
res["...one width: the longest name and a margin"] = E("(function() for _, t in ipairs(All()) do if t.w ~= 152 then return false end end return true end)()") is True
L('PanelTemplates_TabResize(AuctionHouseFrame.Tabs[1])')
res["the game sizes a tab again: ours back"] = E("AuctionHouseFrame.Tabs[1].w") == 152
L('LIB:CreateTab("x", nil, "Upgrades")')
res["a tab added later: laid out under the rest"] = E("LIB.internalState.Tabs[3].point[5]") == -(32 + 5 * 28)
L('AH_RIGHT = 1850; AuctionHouseFrame.scripts.OnShow()')
res["the right off the screen: down the left side"] = E("AuctionHouseFrame.Tabs[1].point[1] == 'TOPRIGHT' and AuctionHouseFrame.Tabs[1].point[3] == 'TOPLEFT'") is True
L('AuctionHouseFrame.Tabs[2].shown = false; MasterOptions_AuctionHouseSideTabs.Layout()')
res["a hidden tab leaves no gap"] = E("AuctionHouseFrame.Tabs[3].point[5]") == -(32 + 1 * 28)
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
