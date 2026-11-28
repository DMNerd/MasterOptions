import sys
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test; lua = module_test(_sys.argv[1])
from shared_lua import fake_tooltip; fake_tooltip(lua)
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
# learned only from items you have: an auction house item's or a chat link's KEEP doesn't reach the never-sell list
L('OWNED = {}; C_Item = C_Item or {}; C_Item.GetItemCount = function(id) return OWNED[id] or 0 end')
L('LEFT = { "Fishing Rod", " ", "|cff4da6ffMastercraft|r", "You use it for fishing." }; RIGHT = { nil, nil, "|cff66b8ffKEEP|r" }; Hover(7777)')
notMine = lua.eval("GearMaticDB.sellIgnore[7777] == nil")
L('OWNED[7777] = 1; Hover(7777)')
mine = lua.eval("GearMaticDB.sellIgnore[7777] == true")
print(("ok   " if notMine else "FAIL ") + "an item you don't have (auction house, chat link): its KEEP not learned")
print(("ok   " if mine else "FAIL ") + "...once you have it: learned (never-sell)")
L('C_Item.GetItemCount = nil')
if not (notMine and mine):
    print("ERRORS: 1"); sys.exit(1)
# IsNeeded: an item in Mastercraft's tracker (read in place), and one that isn't
L('MastercraftDB.goals = { [UnitGUID("player")] = { { id = 2592 }, { id = "4306" } } }')
tracked = lua.eval("MasterOptions_MastercraftKeep.IsNeeded(2592) and MasterOptions_MastercraftKeep.IsNeeded(4306) and not MasterOptions_MastercraftKeep.IsNeeded(9999)")
print("tracked items needed:", tracked)
if not tracked:
    print("ERRORS: 1")
