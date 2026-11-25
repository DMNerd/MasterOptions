import sys
from lupa import LuaRuntime

lua = LuaRuntime()

lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
FR, TM, PRINTS = {}, {}, {}
function CreateFrame() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:SetScript(k, fn) self[k] = fn end FR[#FR+1] = f return f end
C_Timer = { After = function(d, fn) TM[#TM+1] = fn end }
function Run(n) for _ = 1, (n or 40) do local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function InCombatLockdown() return COMBAT == true end
function print(s) PRINTS[#PRINTS+1] = s end
WorldFrame = {}
Enum = { BankType = { Character = 0, Account = 2 } }
BankFrame = { IsVisible = function() return true end, GetActiveBankType = function() return 0 end }
-- bags: 1 linen (guide still needs), 2 copper (guide uses all), 3 silk (VENDOR), 4 wool (AUCTION),
--       5 thread (VENDOR, keep some for guide), 6 pole (KEEP: fishing), 7 iron (tracked), 8 mageweave (guide, Never in bank)
BAG = {
  { itemID = 2589, adv = { "KEEP", "Your Tailoring guide still needs 20." } },
  { itemID = 2770, adv = { "KEEP", "Your Mining guide uses all 12 you have." } },
  { itemID = 4306, adv = { "VENDOR", "Pays 3s more than the auction house." } },
  { itemID = 2592, adv = { "AUCTION", "Pays 40s more than vendoring." } },
  { itemID = 2321, adv = { "VENDOR", "Keep 2 for your Tailoring guide - you have 8, the other 6 can go." } },
  { itemID = 6256, adv = { "KEEP", "You use it for fishing." } },
  { itemID = 2772, adv = { "KEEP", "You're tracking it: 4 / 20." }, tracked = true },
  { itemID = 4338, adv = { "KEEP", "Testchar's Tailoring guide still needs 10." } },
}
MastercraftDB = { settings = { depositNever = { [4338] = true } } }
MOVED, BANKFREE = {}, 50
C_Container = {
  GetContainerNumSlots = function(b) return b == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(b, s) local i = b == 0 and BAG[s]; if i and not i.moved then return { itemID = i.itemID, stackCount = 5 } end end,
  GetContainerNumFreeSlots = function(b) return b < 0 and BANKFREE or 0 end,
  UseContainerItem = function(b, s, _, bankType) MOVED[#MOVED+1] = BAG[s].itemID; BAG[s].moved = true; BANKFREE = BANKFREE - 1; LASTTYPE = bankType end,
}
LEFT, RIGHT = {}, {}
GameTooltip = {}
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:NumLines() return #LEFT end
function GameTooltip:SetOwner(o) self.owner = o end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:IsShown() return false end
function GameTooltip:GetItem() return nil end
function GameTooltip:Hide() end
function GameTooltip:SetBagItem(b, s)
  local a = BAG[s].adv
  if BAG[s].tracked then
    -- Mastercraft 2.1.2, an item you track: its header first without the verdict, the Tracking row, then the reason
    LEFT, RIGHT = { "Item", " ", "|cff4da6ffMastercraft|r", "Tracking", a[2] }, { nil, nil, nil, "4 / 20" }
  else
    LEFT, RIGHT = { "Item", " ", "|cff4da6ffMastercraft|r", a[2] }, { nil, nil, "|cffaaaaaa" .. a[1] .. "|r" }
  end
end
for i = 1, 10 do
  _G["GameTooltipTextLeft" .. i] = { GetText = function() return LEFT[i] end }
  _G["GameTooltipTextRight" .. i] = { GetText = function() return RIGHT[i] end, IsShown = function() return RIGHT[i] ~= nil end }
end
function Reset() for _, i in ipairs(BAG) do i.moved = nil end; MOVED = {}; BANKFREE = 50; PRINTS = {} end
function List() local o = {} for _, v in ipairs(MOVED) do o[#o+1] = tostring(v) end table.sort(o) return table.concat(o, ",") end
''')
lua.eval("function(s) local f, e = load(s, '=bank'); if not f then error(e) end; return f end")(open(sys.argv[1], encoding="utf-8").read())("MasterOptions_Mastercraft_BankMats")
L, E = lua.execute, lua.eval
fails = []
def check(name, got, want):
    ok = got == want
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else "  got %r want %r" % (got, want)))
    if not ok: fails.append(name)

L('Fire("ADDON_LOADED", "MasterOptions_Mastercraft_BankMats"); Fire("BANKFRAME_OPENED"); Run()')
check("guide mode: only guide materials go", E("List()"), "2589,2770")
check("into the open bank tab", E("LASTTYPE"), 0)
check("one chat line", E("#PRINTS"), 1)

L('Reset(); MasterOptions_MastercraftBankDB.mode = "tracked"; Fire("BANKFRAME_OPENED"); Run()')
check("tracked mode: tracked items too", E("List()"), "2589,2770,2772")

L('Reset(); MasterOptions_MastercraftBankDB.mode = "guide"; BANKFREE = 1; Fire("BANKFRAME_OPENED"); Run()')
check("stops when the bank is full", E("List()"), "2589")
check("says the bank is full", "full" in (E("PRINTS[1]") or ""), True)

L('Reset(); Fire("BANKFRAME_OPENED"); Fire("BANKFRAME_CLOSED"); Run()')
check("bank closed before it starts: nothing moves", E("List()"), "")

L('Reset(); COMBAT = true; Fire("BANKFRAME_OPENED"); Run(); COMBAT = false')
check("in combat: nothing moves", E("List()"), "")

L('Reset(); MasterOptions_MastercraftBankDB.mode = "off"; Fire("BANKFRAME_OPENED"); Run()')
check("off: nothing moves", E("List()"), "")

if fails:
    print("ERRORS: %d" % len(fails)); sys.exit(1)
print("ERRORS: 0")
