# Mastercraft_BankMats: Store mats / Take mats under the bank window, by Mastercraft's advice for each item - how many,
# a stack split when only part of it goes - and the storing by itself at the bank (off by default).
import sys
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test; lua = module_test(_sys.argv[1])
from shared_lua import fake_tooltip; fake_tooltip(lua)

lua.execute(r'''
FR, TM, PRINTS = {}, {}, {}
function CreateFrame(kind, name) local f = { ev = {}, scripts = {} }; if name then _G[name] = f end
  function f:RegisterEvent(e) self.ev[e] = true end function f:SetScript(k, fn) self[k] = fn; self.scripts[k] = fn end
  for _, m in ipairs({ "SetSize", "SetText", "ClearAllPoints", "SetPoint", "SetFrameStrata" }) do f[m] = function() end end
  function f:Show() self.shown = true end function f:Hide() self.shown = false end
  FR[#FR+1] = f return f end
C_Timer = { After = function(d, fn) TM[#TM+1] = fn end }
function Run(n) for _ = 1, (n or 80) do local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end end
function Fire(e, ...) for _, f in ipairs(FR) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function InCombatLockdown() return COMBAT == true end
function IsShiftKeyDown() return SHIFT == true end
function print(s) PRINTS[#PRINTS+1] = s end
WorldFrame, UIParent = {}, {}
Enum = { BankType = { Character = 0, Account = 2 } }
BankFrame = { IsVisible = function() return true end, GetActiveBankType = function() return 0 end }
MastercraftDB = { settings = { depositNever = { [4338] = true } } }

-- Mastercraft's advice for each item (its counts are for everything you have: bags and bank)
ADV = {
  [2589] = { "KEEP", "Your Tailoring guide still needs 20." },                                  -- linen
  [2770] = { "KEEP", "Your Mining guide uses all 12 you have." },                                -- copper
  [4306] = { "VENDOR", "Pays 3s more than the auction house." },                                 -- silk
  [2592] = { "AUCTION", "Pays 40s more than vendoring." },                                       -- wool
  [2321] = { "VENDOR", "Keep 12 for your Tailoring guide - you have 30, the other 18 can go." }, -- thread
  [2996] = { "AUCTION", "Keep 5 for your Tailoring guide - you have 25, the other 20 can go." },  -- bolt
  [6256] = { "KEEP", "You use it for fishing." },                                                -- pole
  [2772] = { "KEEP", "You're tracking it: 4 / 20." },                                            -- iron
  [4338] = { "KEEP", "Testchar's Tailoring guide still needs 10." },                             -- mageweave: Never in bank
}
-- bags (bag 0) and bank (bag -1): { itemID, count } per slot
function World(bags, bank) SLOTS = { [0] = {}, [-1] = {} }
  for i, e in ipairs(bags) do SLOTS[0][i] = { e[1], e[2] } end
  for i, e in ipairs(bank) do SLOTS[-1][i] = { e[1], e[2] } end
  SIZE = { [0] = 16, [-1] = 16 }; CURSOR = nil; PRINTS = {}; TM = {}
end
local function Count(id, where) local n = 0; for _, s in pairs(SLOTS[where]) do if s[1] == id then n = n + s[2] end end return n end
function Has(where) local t = {} for _, s in pairs(SLOTS[where]) do if s[2] > 0 then t[s[1]] = (t[s[1]] or 0) + s[2] end end
  local o = {} for id, n in pairs(t) do o[#o + 1] = id .. "x" .. n end table.sort(o) return table.concat(o, ",") end
local function Free(where) local n = 0; for i = 1, SIZE[where] do local s = SLOTS[where][i]; if not s or s[2] == 0 then n = n + 1 end end return n end
local function Put(where, id, n)   -- (the game: onto a stack of it with room, else a free slot)
  for i = 1, SIZE[where] do local s = SLOTS[where][i]; if s and s[1] == id and s[2] > 0 and s[2] + n <= 20 then s[2] = s[2] + n; return end end
  for i = 1, SIZE[where] do local s = SLOTS[where][i]; if not s or s[2] == 0 then SLOTS[where][i] = { id, n }; return end end
end
C_Item = { GetItemCount = function(id, withBank) return Count(id, 0) + (withBank and Count(id, -1) or 0) end,
           GetItemMaxStackSizeByID = function() return 20 end }
C_Container = {
  GetContainerNumSlots = function(b) return SIZE[b] or 0 end,
  GetContainerItemInfo = function(b, i) local s = SLOTS[b] and SLOTS[b][i]; if s and s[2] > 0 then return { itemID = s[1], stackCount = s[2] } end end,
  GetContainerNumFreeSlots = function(b) if SLOTS[b] then return Free(b), 0 end return 0, 0 end,
  UseContainerItem = function(b, i) local s = SLOTS[b][i]; Put(b == 0 and -1 or 0, s[1], s[2]); s[2] = 0 end,
  SplitContainerItem = function(b, i, n) local s = SLOTS[b][i]; s[2] = s[2] - n; CURSOR = { s[1], n } end,
  PickupContainerItem = function(b, i) if CURSOR then local s = SLOTS[b][i]
    if s and s[2] > 0 then s[2] = s[2] + CURSOR[2] else SLOTS[b][i] = { CURSOR[1], CURSOR[2] } end; CURSOR = nil end end,
}
function CursorHasItem() return CURSOR ~= nil end
function ClearCursor() CURSOR = nil end
NUM_BAG_SLOTS, NUM_BANKBAGSLOTS = 0, 0
function GameTooltip:AddLine() end function GameTooltip:Show() end
function GameTooltip:SetItemByID(id)
  local a = ADV[id] or { "", "" }
  LEFT, RIGHT = { "Item", " ", "|cff4da6ffMastercraft|r", a[2] }, { nil, nil, "|cffaaaaaa" .. a[1] .. "|r" }
end
function Click(name, shift) PRINTS = {}; SHIFT = shift; _G[name].scripts.OnClick(); SHIFT = false; Run() end
''')
lua.eval("function(s) local f, e = load(s, '=bank'); if not f then error(e) end; return f end")(open(sys.argv[1], encoding="utf-8").read())("MasterOptions_Mastercraft_BankMats")
L, E = lua.execute, lua.eval
fails = []
def check(name, got, want):
    ok = got == want
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else "  got %r want %r" % (got, want)))
    if not ok: fails.append(name)

BAGS = '{ { 2589, 20 }, { 2770, 12 }, { 4306, 5 }, { 2592, 5 }, { 2321, 20 }, { 6256, 1 }, { 2772, 4 }, { 4338, 5 } }'

L('Fire("ADDON_LOADED", "MasterOptions_Mastercraft_BankMats"); World(%s, {}); Fire("BANKFRAME_OPENED"); Run()' % BAGS)
check("storing by itself: off by default (nothing moved on opening the bank)", E('Has(-1)'), "")
check("the two buttons show at the bank", E("MasterOptionsStoreMats.shown and MasterOptionsTakeMats.shown"), True)

L('Click("MasterOptionsStoreMats")')
check("Store mats: what guides need - all linen and copper, of thread only the 12 needed (a stack split)",
      E('Has(-1)'), "2321x12,2589x20,2770x12")
check("...the rest stays in your bags to be sold; tools, Never in bank and tracked items stay", E('Has(0)'), "2321x8,2592x5,2772x4,4306x5,4338x5,6256x1")
check("...one line said", "moved 44 items your guides need into your bank" in (E("PRINTS[1]") or ""), True)

L('World(%s, { { 2321, 10 } }); Click("MasterOptionsStoreMats")' % BAGS)
check("Store mats with 10 thread in the bank already: 2 more", "2321x12" in E('Has(-1)'), True)

L('World(%s, {}); Click("MasterOptionsStoreMats", true)' % BAGS)
check("Shift-click Store mats: what you track too", "2772x4" in E('Has(-1)'), True)

L('World(%s, {}); MasterOptions_MastercraftBankDB.mode = "guide"; Fire("BANKFRAME_OPENED"); Run(); MasterOptions_MastercraftBankDB.mode = "off"' % BAGS)
check("storing by itself (Guide mats): as a click", E('Has(-1)'), "2321x12,2589x20,2770x12")

BANK = '{ { 2589, 20 }, { 2321, 20 }, { 2592, 10 }, { 2996, 20 }, { 2772, 10 }, { 6256, 1 } }'
L('World({ { 2321, 5 }, { 2772, 4 } }, %s); Click("MasterOptionsTakeMats")' % BANK)
check("Take mats: what guides need and what you track, less what you carry (thread: 12 - 5 = 7, split)",
      E('Has(0)'), "2321x12,2589x20,2772x14,2996x5")
check("...one line said", "moved 42 items your guides need out of your bank" in (E("PRINTS[1]") or ""), True)

L('World({}, %s); Click("MasterOptionsTakeMats", true)' % BANK)
check("Shift-click Take mats: what's to auction - for the bolt only the 20 a guide doesn't need", E('Has(0)'), "2592x10,2996x20")
L('World({ { 2996, 8 } }, %s); Click("MasterOptionsTakeMats", true)' % BANK)
check("...with 8 bolts in your bags (5 needed, 3 spare already): 17 more", E('Has(0)'), "2592x10,2996x25")

L('World({}, %s); SIZE[0] = 0; Click("MasterOptionsTakeMats")' % BANK)
check("bags full: nothing taken, says so", E('Has(0)') == "" and "bags are full" in (E("PRINTS[1]") or ""), True)
L('World(%s, {}); SIZE[-1] = 0; Click("MasterOptionsStoreMats")' % BAGS)
check("bank full: nothing stored, says so", E('Has(-1)') == "" and "bank is full" in (E("PRINTS[1]") or ""), True)
L('World({}, %s); COMBAT = true; Click("MasterOptionsTakeMats"); COMBAT = false' % BANK)
check("in a fight: nothing moves", E('Has(0)'), "")
L('World({}, %s); CURSOR = { 1, 1 }; Click("MasterOptionsTakeMats")' % BANK)
check("something on the cursor: nothing moves (it would be put down somewhere)", E('Has(0)'), "")
L('World({}, %s); Click("MasterOptionsTakeMats"); Fire("BANKFRAME_CLOSED"); Run()' % BANK)
L('World({}, %s); _G.MasterOptionsTakeMats.scripts.OnClick(); Fire("BANKFRAME_CLOSED"); Run()' % BANK)
check("bank closed mid-way: it stops", E('Has(0)') != "2321x12,2589x20,2772x14,2996x5", True)
check("bank closed: the buttons go", E("MasterOptionsTakeMats.shown or MasterOptionsStoreMats.shown"), False)

if fails:
    print("ERRORS: %d" % len(fails)); sys.exit(1)
print("ERRORS: 0")
