import sys
from lupa import LuaRuntime

keep_path, protect_path = sys.argv[1], sys.argv[2]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end io.write(table.concat(t, " "), "\n") end
FRAMES, TIMERS, POSTCALLS = {}, {}, {}
function UnitGUID() return "Player-6943-00A6A3F9" end
function time() return 1000 end
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) POSTCALLS[#POSTCALLS+1] = fn end }
-- bags: fishing pole (tool), an upgrade, a grey, a material, a user-ignored item
BAG = {
  { itemID = 6256, hyperlink = "item:6256", quality = 1 },  -- Fishing Pole
  { itemID = 1111, hyperlink = "item:1111", quality = 2 },  -- an upgrade (Pawn)
  { itemID = 2222, hyperlink = "item:2222", quality = 0 },  -- grey junk
  { itemID = 2589, hyperlink = "item:2589", quality = 1 },  -- Linen Cloth (a guide needs it)
  { itemID = 3333, hyperlink = "item:3333", quality = 1 },  -- ignored by the player
}
C_Container = { GetContainerNumSlots = function(b) return b == 0 and #BAG or 0 end,
                GetContainerItemInfo = function(b, s) return b == 0 and BAG[s] or nil end }
C_Item = { IsEquippableItem = function(link) return link == "item:1111" or link == "item:2222" end }
function PawnGetItemData(link) return { link = link } end
function PawnIsItemAnUpgrade(item) if item.link == "item:1111" then return { { PercentUpgrade = 0.12 } } end return nil end
GearMaticDB = { sellIgnore = { [4444] = true }, sellMark = {} }
MastercraftDB = { settings = {}, goals = { ["Player-6943-00A6A3F9"] = { { id = 2592 } } } } -- tracking Wool Cloth
DCI_CharDB = { IgnoredItems = { 3333 } }
-- a fake GameTooltip showing Linen Cloth with Mastercraft's line
GameTooltip = { lines = { "Linen Cloth", " ", "Mastercraft", "Tailoring guide needs" } }
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:NumLines() return #self.lines end
for i = 1, 10 do _G["GameTooltipTextLeft" .. i] = { GetText = function() return GameTooltip.lines[i] end } end
function list(t) local o = {} for k, v in pairs(t) do o[#o+1] = tostring(type(k) == "number" and k > 100 and k or v) end table.sort(o) return table.concat(o, ",") end
function arr(t) local o = {} for _, v in ipairs(t) do o[#o+1] = tostring(v) end table.sort(o) return table.concat(o, ",") end
''')
load = lua.eval("function(src, name) local f, e = load(src, '=' .. name); if not f then error(e) end; return f end")
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, protect_path)
from shared_lua import fake_frames; fake_frames(lua)
load(open(keep_path, encoding="utf-8").read(), "keep")("MasterOptions_Mastercraft_Keep")
load(open(protect_path, encoding="utf-8").read(), "protect")("MasterOptions_DeleteCheapestItem_Protect")
L = lua.execute
L('Fire("ADDON_LOADED", "MasterOptions_Mastercraft_Keep"); Fire("PLAYER_LOGIN"); RunTimers()')
print("after login:")
print("  DCI ignore list:      ", lua.eval("arr(DCI_CharDB.IgnoredItems)"), "(added by patch:", lua.eval("list(DCI_CharDB.moProtected)") + ")")
print("  GearMatic never-sell: ", lua.eval("list(GearMaticDB.sellIgnore)"), "(added:", lua.eval("list(GearMaticDB.moKeep)") + ")")
# hover Linen Cloth: Mastercraft's tooltip says a guide needs it
L('for _, fn in ipairs(POSTCALLS) do fn(GameTooltip, { id = 2589 }) end; RunTimers(); Fire("BAG_UPDATE_DELAYED")')
print("after hovering Linen Cloth (guide needs it):")
print("  DCI ignore list:      ", lua.eval("arr(DCI_CharDB.IgnoredItems)"))
print("  GearMatic never-sell: ", lua.eval("list(GearMaticDB.sellIgnore)"))
# the upgrade leaves the bags, Linen is no longer needed (tooltip without the line)
L('table.remove(BAG, 2); GameTooltip.lines = { "Linen Cloth" }; for _, fn in ipairs(POSTCALLS) do fn(GameTooltip, { id = 2589 }) end; RunTimers(); Fire("BAG_UPDATE_DELAYED")')
print("after the upgrade is gone and Linen isn't needed any more:")
print("  DCI ignore list:      ", lua.eval("arr(DCI_CharDB.IgnoredItems)"), "(patch's:", lua.eval("list(DCI_CharDB.moProtected)") + ")")
print("  GearMatic never-sell: ", lua.eval("list(GearMaticDB.sellIgnore)"), "(patch's:", lua.eval("list(GearMaticDB.moKeep)") + ")")
