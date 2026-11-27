# DungeonJournal_Upgrades: Dungeon Journal's loot rows get an upgrade arrow, its size and GearMatic's BiS skull,
# by the one judge (Pawn with Pawn Forever, else GearMatic + CheapUpgrades' size); a late item is marked when it
# arrives; a reused row is cleared.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, TIMERS, ERRS = {}, {}, 0
  function CreateFrame() local f = { ev = {} }
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    FRAMES[#FRAMES + 1] = f; return f end
  C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = fn end }
  function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; print("ERR", e) end
  function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = orig(...); fn(...); return r end end
  LOADED = { GearMatic = true, CheapUpgrades = true, ForeverDungeonJournal = true }
  C_AddOns = { IsAddOnLoaded = function(n) return LOADED[n] == true end }
  CACHED = { [100] = true, [101] = true, [102] = true, [103] = true, [200] = true }
  C_Item = { GetItemInfo = function(id) if CACHED[id] then return "x", "|Hitem:" .. id .. "|h" end end }
  local function ID(link) return tonumber(link:match("item:(%d+)")) end
  -- GearMatic: 100 upgrade, 101 an alt's upgrade, 102 best in slot (not an upgrade), 103 nothing
  GearMatic = { BagOverlay = { MarkerVerdict = function(link) local id = ID(link)
      return { upgrade = id == 100 or id == 101 or id == 104, alt = id == 101, skull = id == 102 } end },
    ApplyUpgradeArrow = function(tex, kind) tex.kind = "gm-" .. kind end,
    ApplyBiSSkull = function(tex) tex.kind = "skull" end }
  CheapUpgrades = { ctx = {}, Bags = { BadgeText = function(info) return "+" .. info.pct .. "%" end } }
  function CheapUpgrades:WatchedInfo(link) local id = ID(link)
    if id == 100 or id == 104 then return { { info = { state = "upgrade", pct = 23 } } } end return {} end
  function PawnGetItemData(link) return { id = ID(link) } end
  function PawnIsItemAnUpgrade(item) if item.id == 200 then return { { PercentUpgrade = 0.12 } } end end
  -- Dungeon Journal
  local function Region(kind) local r = { shown = false, kind = nil }
    function r:Show() self.shown = true end; function r:Hide() self.shown = false end
    function r:SetPoint() end; function r:SetSize() end; function r:SetTexCoord() end
    function r:SetTexture(t) self.kind = t end; function r:SetText(t) self.text = t end
    return r end
  function NewRow() local row = { icon = { GetObjectType = function() return "Texture" end, GetHeight = function() return 38 end } }
    function row:CreateTexture() return Region() end
    function row:CreateFontString() return Region() end
    function row:IsShown() return true end
    return row end
  ForeverDungeonJournal_NS = { UpdateFavouriteIndicator = function(row, id) row.fdjFavouriteItemID = id end }
  function Show(row, id) ForeverDungeonJournal_NS.UpdateFavouriteIndicator(row, id); return row.moUpgrade end
  function Desc(p) return tostring(p.arrow.shown and p.arrow.kind or "-") .. "|" .. tostring(p.text.shown and p.text.text or "-")
    .. "|" .. tostring(p.skull.shown and p.skull.kind or "-") end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_DungeonJournal_Upgrades")
E, L = lua.eval, lua.execute
L("R1, R2, R3, R4, R5 = NewRow(), NewRow(), NewRow(), NewRow(), NewRow()")
res = {
    "GearMatic judge, an upgrade: chevron + CheapUpgrades' size": E("Desc(Show(R1, 100))") == "gm-up|+23%|-",
    "an upgrade for an alt only: the alt chevron": E("Desc(Show(R2, 101))") == "gm-alt|-|-",
    "best in slot: GearMatic's skull": E("Desc(Show(R3, 102))") == "-|-|skull",
    "nothing to say: nothing shown": E("Desc(Show(R4, 103))") == "-|-|-",
}
L('Show(R5, 104)')
res["item not sent yet: unmarked"] = E("Desc(R5.moUpgrade)") == "-|-|-"
L('CACHED[104] = true; Fire("GET_ITEM_INFO_RECEIVED"); RunTimers()')
res["...marked when it arrives"] = E("Desc(R5.moUpgrade)") == "gm-up|+23%|-"
L('Show(R1, 103)')
res["a row reused for another item: cleared"] = E("Desc(R1.moUpgrade)") == "-|-|-"
L('LOADED.Pawn, LOADED.Pawn_Forever = true, true')
p = E("Desc(Show(R1, 200))")
res["Pawn judge (Pawn Forever installed): Pawn's arrow and its percent"] = p.startswith("Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow|") and "+12%" in p and p.endswith("|-")
res["Pawn judge: GearMatic's upgrade isn't shown as Pawn's"] = E("Desc(Show(R2, 100))") == "-|-|-"
L('LOADED.Pawn_Forever = nil')
res["Pawn without Pawn Forever: GearMatic judges again"] = E("Desc(Show(R2, 100))") == "gm-up|+23%|-"
L('CheapUpgrades.ctx = nil; TIMERS = {}; Show(R4, 100)')
res["CheapUpgrades not ready: asked again a few times, not forever"] = E("#TIMERS") == 1
L('for i = 1, 10 do RunTimers() end')
res["...and stops"] = E("#TIMERS") == 0 and E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
