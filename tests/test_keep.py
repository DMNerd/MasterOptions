import sys
from lupa import LuaRuntime
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
FR, TM, PC = {}, {}, {}
function CreateFrame() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:SetScript(k, fn) self[k] = fn end FR[#FR+1] = f return f end
C_Timer = { After = function(d, fn) TM[#TM+1] = fn end }
function Run() local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function UnitGUID() return "P" end
function time() return 1 end
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) PC[#PC+1] = fn end }
GearMaticDB = { sellIgnore = {}, sellMark = {} }
MastercraftDB = { settings = {}, goals = {} }
REFRESHED = 0
GearMatic = { RefreshSellIgnoreSurfaces = function() REFRESHED = REFRESHED + 1 end }
LEFT, RIGHT = {}, {}
GameTooltip = {}
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:NumLines() return #LEFT end
for i = 1, 10 do
  _G["GameTooltipTextLeft" .. i] = { GetText = function() return LEFT[i] end }
  _G["GameTooltipTextRight" .. i] = { GetText = function() return RIGHT[i] end, IsShown = function() return RIGHT[i] ~= nil end }
end
function Hover(id) for _, fn in ipairs(PC) do fn(GameTooltip, { id = id }) end; Run() end
''')
lua.eval("function(s) return load(s, '=keep') end")(open(sys.argv[1], encoding="utf-8").read())("MasterOptions_Mastercraft_Keep")
L = lua.execute
L('Fire("ADDON_LOADED", "MasterOptions_Mastercraft_Keep")')
L('LEFT = { "Fishing Pole", " ", "|cff4da6ffMastercraft|r", "You use it for fishing." }; RIGHT = { nil, nil, "|cff66b8ffKEEP|r" }; Hover(6256)')
print("Mastercraft says KEEP:   never-sell =", lua.eval("GearMaticDB.sellIgnore[6256] == true"), "| GearMatic badges redrawn:", lua.eval("REFRESHED"))
L('RIGHT = { nil, nil, "VENDOR" }; Hover(6256)')
print("later it says VENDOR:    never-sell =", lua.eval("GearMaticDB.sellIgnore[6256] == true"))
L('LEFT = { "Some item" }; RIGHT = {}; Hover(1234)')
print("no Mastercraft advice:   never-sell =", lua.eval("GearMaticDB.sellIgnore[1234] == true"))
