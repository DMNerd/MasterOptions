import sys
from lupa import LuaRuntime
lua = LuaRuntime()
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
FR, TM = {}, {}
function CreateFrame() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:SetScript(k, fn) self[k] = fn end FR[#FR+1] = f return f end
C_Timer = { After = function(d, fn) TM[#TM+1] = fn end }
function Run(n) for _ = 1, (n or 30) do local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function InCombatLockdown() return false end function GetTime() return 100 end
function GetCoinTextureString(c) return c .. "c" end
WorldFrame = {}
-- bag 0: 1 linen (VENDOR), 2 silk (AUCTION), 3 grey, 4 sword (VENDOR, gear), 5 thread (VENDOR but "Keep 2 for your guide"),
--        6 pole (KEEP), 7 herb (VENDOR, on never-sell), 8 boots (VENDOR, Pawn upgrade)
BAG = {
  { itemID = 2589, hyperlink = "item:2589", quality = 1, stackCount = 5 },
  { itemID = 4306, hyperlink = "item:4306", quality = 1, stackCount = 3 },
  { itemID = 3300, hyperlink = "item:3300", quality = 0, stackCount = 1 },
  { itemID = 2488, hyperlink = "item:2488", quality = 2, stackCount = 1, gear = true },
  { itemID = 2320, hyperlink = "item:2320", quality = 1, stackCount = 8 },
  { itemID = 6256, hyperlink = "item:6256", quality = 1, stackCount = 1, gear = true },
  { itemID = 765,  hyperlink = "item:765",  quality = 1, stackCount = 4 },
  { itemID = 2961, hyperlink = "item:2961", quality = 2, stackCount = 1, gear = true, up = true },
}
ADVICE = { [2589] = {"VENDOR"}, [4306] = {"AUCTION"}, [2488] = {"VENDOR"}, [2320] = {"VENDOR", "Keep 2 for your Tailoring guide - you have 8, the other 6 can go."},
           [6256] = {"KEEP"}, [765] = {"VENDOR"}, [2961] = {"VENDOR"} }
SOLD = {}
C_Container = {
  GetContainerNumSlots = function(b) return b == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(b, s) local i = b == 0 and BAG[s]; if i and not i.sold then return i end end,
  GetContainerItemID = function(b, s) local i = b == 0 and BAG[s]; if i and not i.sold then return i.itemID end end,
  UseContainerItem = function(b, s) SOLD[#SOLD+1] = BAG[s].itemID; BAG[s].sold = true end,
}
C_Item = {
  GetItemInfo = function(l) local id = tonumber(l:match("%d+")); return "n", l, 1, 1, 1, "", "", 1, "", 0, 10 end,
  IsEquippableItem = function(l) local id = tonumber(l:match("%d+")); for _, i in ipairs(BAG) do if i.itemID == id then return i.gear end end end,
}
PawnGetItemData = function(l) return { l = l } end
PawnIsItemAnUpgrade = function(item) if item.l == "item:2961" then return { 1 } end end
-- hidden tooltip reads
LEFT, RIGHT, SHOWN = {}, {}, false
GameTooltip = {}
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:NumLines() return #LEFT end
function GameTooltip:SetOwner(o) self.owner = o end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:IsShown() return SHOWN end
function GameTooltip:GetItem() return nil end
function GameTooltip:Hide() SHOWN = false end
READS = 0
function GameTooltip:SetBagItem(b, s)
  READS = READS + 1
  local a = ADVICE[BAG[s].itemID]
  LEFT, RIGHT = { "Item" }, {}
  if a then LEFT[2] = " "; LEFT[3] = "|cff4da6ffMastercraft|r"; RIGHT[3] = "|cffaaaaaa" .. a[1] .. "|r"; LEFT[4] = a[2] or "Pays more." end
end
for i = 1, 10 do
  _G["GameTooltipTextLeft" .. i] = { GetText = function() return LEFT[i] end }
  _G["GameTooltipTextRight" .. i] = { GetText = function() return RIGHT[i] end, IsShown = function() return RIGHT[i] ~= nil end }
end
MastercraftDB = { settings = { autoJunk = false } }
GMQ = {}
GMProf = { autoSellJunk = true }
GearMaticDB = { sellIgnore = { [765] = true }, sellMark = {} }
SELLJUNK = 0
GearMatic = { db = { profile = GMProf }, VendorAutomation = {
  SellJunk = function() SELLJUNK = SELLJUNK + 1; GMQ = {} ; for s, i in ipairs(BAG) do if GearMaticDB.sellMark[i.itemID] then GMQ[#GMQ+1] = { bag = 0, slot = s, itemID = i.itemID, marked = true } end end end,
  _Queue = function() return GMQ end,
} }
CORNER = {}
Baganator = { API = {
  RegisterJunkPlugin = function() end,
  RegisterCornerWidget = function(label, id, onUpdate, onInit, pos) CORNER[id] = { onUpdate = onUpdate, onInit = onInit, pos = pos } end,
  RequestItemButtonsRefresh = function() end,
} }
function Reset() for _, i in ipairs(BAG) do i.sold = nil end; SOLD = {}; GMQ = {} end
function List(t) local o = {} for _, v in ipairs(t) do o[#o+1] = tostring(type(v) == "table" and v.itemID or v) end table.sort(o) return table.concat(o, ",") end
''')
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, sys.argv[1])
# (the advice store and the Baganator pieces are modules of their own, next to VendorSell)
_mods = _os.path.dirname(_os.path.abspath(sys.argv[1]))
for _name in ("Mastercraft_Advice", "Mastercraft_VendorSell", "Baganator_Mastercraft"):
    _src = open(sys.argv[1] if _name == "Mastercraft_VendorSell" else _os.path.join(_mods, _name + ".lua"), encoding="utf-8").read()
    lua.eval("function(s, n) return load(s, '=' .. n) end")(_src, _name)("MasterOptions_" + _name)
L, E = lua.execute, lua.eval
L('Fire("ADDON_LOADED", "MasterOptions_Mastercraft_VendorSell")')

print("== seller GearMatic, mode goods")
L('Fire("MERCHANT_SHOW"); Run()')
print("GearMatic queue:", E("List(GMQ)"), "| marked for visit:", E("List((function() local t={} for id in pairs(GearMaticDB.moSell or {}) do t[#t+1]=id end return t end)())"), "| tooltip reads:", E("READS"))
L('Fire("MERCHANT_CLOSED"); Run()')
print("after close: sellMark empty =", E("next(GearMaticDB.sellMark) == nil"), "| moSell =", E("GearMaticDB.moSell"))

print("== mode all")
L('MasterOptions_MastercraftVendorDB.mode = "all"; Reset(); Fire("MERCHANT_SHOW"); Run()')
print("GearMatic queue:", E("List(GMQ)"))
L('Fire("MERCHANT_CLOSED"); Run()')

print("== seller Mastercraft, mode goods")
L('GMProf.autoSellJunk = false; MastercraftDB.settings.autoJunk = true; MasterOptions_MastercraftVendorDB.mode = "goods"; Reset(); Fire("MERCHANT_SHOW"); Run()')
print("sold by patch:", E("List(SOLD)"))
L('Fire("MERCHANT_CLOSED"); Run()')

print("== junk selling off")
L('MastercraftDB.settings.autoJunk = false; Reset(); Fire("MERCHANT_SHOW"); Run()')
print("sold:", E("List(SOLD)"), "| GM queue:", E("List(GMQ)"))

print("== mode off")
L('MastercraftDB.settings.autoJunk = true; MasterOptions_MastercraftVendorDB.mode = "off"; Reset(); Fire("MERCHANT_SHOW"); Run()')
print("sold:", E("List(SOLD)"))

print("== bag icons (WouldSell, no tooltip reads)")
L('GMProf.autoSellJunk = true; MasterOptions_MastercraftVendorDB.mode = "goods"; Reset(); READS = 0; Fire("MERCHANT_CLOSED"); Fire("PLAYER_LOGIN"); Run()')
print("background reads after login:", E("READS"))
L('READS = 0')
print("coin on linen:", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 1, 2589)"), "| silk:", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 2, 4306)"),
      "| thread:", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 5, 2320)"), "| sword (goods mode):", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 4, 2488)"),
      "| tooltip reads:", E("READS"))
L('MasterOptions_MastercraftVendorDB.mode = "all"')
print("mode all: sword:", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 4, 2488)"), "| boots (upgrade):", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 8, 2961)"))
L('GMProf.autoSellJunk = false; MastercraftDB.settings.autoJunk = false')
print("junk selling off: linen:", E("MasterOptions_MastercraftVendorSell.WouldSell(0, 1, 2589)"))

print("== /mo vendor (why each VENDOR item is or isn't sold)")
errors = 0
def check(what, ok):
    global errors
    if not ok: errors += 1
    print(("ok   " if ok else "FAIL ") + what)
L('GMProf.autoSellJunk = true; MasterOptions_MastercraftVendorDB.mode = "goods"; Reset()')
L('OUT = {}; local p = print; print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end OUT[#OUT+1] = table.concat(t, " ") end; '
  'MasterOptions_MastercraftVendorSell.Explain(); print = p')
out = list(lua.eval("OUT").values())
for line in out: print("   ", line)
def line_for(item): return next((l for l in out if item in l), "")
check("header: mode and seller", "sell mode goods, junk seller gearmatic" in out[0])
check("linen: sold", "sold at the vendor" in line_for("item:2589"))
check("sword: gear in Goods mode", "gear (sell mode is Goods)" in line_for("item:2488"))
check("thread: keep some for a guide", "keep some for a guide" in line_for("item:2320"))
check("herb: never-sell list", "never-sell" in line_for("item:765"))
check("silk (AUCTION) not listed", line_for("item:4306") == "")
L('MasterOptions_MastercraftVendorDB.mode = "all"; OUT = {}; local p = print; print = function(s) OUT[#OUT+1] = s end; MasterOptions_MastercraftVendorSell.Explain(); print = p; MasterOptions_MastercraftVendorDB.mode = "goods"')
out = list(lua.eval("OUT").values())
check("goods and gear: sword sold, boots kept with the reason", "sold at the vendor" in line_for("item:2488") and "kept gear - Pawn" in line_for("item:2961"))
L('GMProf.autoSellJunk = false; OUT = {}; local p = print; print = function(s) OUT[#OUT+1] = s end; MasterOptions_MastercraftVendorSell.Explain(); print = p')
out = list(lua.eval("OUT").values())
check("no seller: says why", "GearMatic's Sell junk is off" in out[0] and "no junk seller" in line_for("item:2589"))
print("== Baganator advice icons")
L(r'''
  local w = CORNER.masteroptions_mc_advice
  TEX = {}
  local function Icon(id)
    local t = { SetTexture = function(self, p) self.p = p end }
    local shown = w.onUpdate(t, { itemID = id })
    return shown and t.p or "none"
  end
  POS = w.pos.corner .. ":" .. w.pos.priority
  I_LINEN, I_THREAD, I_SILK, I_POLE, I_GREY = Icon(2589), Icon(2320), Icon(4306), Icon(6256), Icon(3300)
  I_LINEN_COIN = w.onUpdate({ SetTexture = function() end }, { itemID = 2589, isJunk = true })
  I_POLE_COIN = w.onUpdate({ SetTexture = function() end }, { itemID = 6256, isJunk = true })
''')
check("advice icon registered top right, after lock and skull", E("POS") == "top_right:3")
check("linen: vendor icon", "VendorGossipIcon" in E("I_LINEN"))
check("thread (keep some for a guide): keep tick", "ReadyCheck-Ready" in E("I_THREAD"))
check("silk: auction icon", "Auctioneer" in E("I_SILK"))
check("pole: keep tick", "ReadyCheck-Ready" in E("I_POLE"))
check("grey (no advice): no icon", E("I_GREY") == "none")
check("VENDOR with the junk coin already: no second icon", E("I_LINEN_COIN") is False)
check("other advice still shows next to a junk coin", E("I_POLE_COIN") is True)
L('ACTIVE = false; Baganator.API.IsCornerWidgetActive = function(id) return ACTIVE and id == "masteroptions_mc_advice" end; '
  'GMRefreshed = 0; MasterOptions_GMRefreshBagIcons = function() GMRefreshed = GMRefreshed + 1 end; '
  'MasterOptions_BaganatorMastercraft.OneVerdictPerSlot()')
check("advice icons off: GearMatic's badges left alone", E("GMProf.bestGoldShowAuction") is None and E("GMRefreshed") == 0)
L('ACTIVE = true; GMProf.bestGoldShowAuction = true; Fire("PLAYER_LOGIN"); Run()')
check("advice icons on: at login all three GearMatic badges off, its bags redrawn",
      E("GMProf.bestGoldShowVendor") is False and E("GMProf.bestGoldShowAuction") is False
      and E("GMProf.bestGoldShowDisenchant") is False and E("GMRefreshed") == 1)
print("ERRORS:", errors)