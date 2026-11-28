# CheapUpgrades_Mastercraft: on the tooltip of an item CheapUpgrades calls an upgrade - what the piece it replaces brings
# back (Mastercraft's pick, read beforehand), who of your characters has one, who can craft it and its materials' cost.
import sys
src = open(sys.argv[1], encoding="utf-8").read()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test; lua = module_test(_sys.argv[1])
from shared_lua import fake_tooltip; fake_tooltip(lua)
from shared_lua import fake_frames; fake_frames(lua)
lua.execute(r'''
  function InCombatLockdown() return false end
  WorldFrame = {}
  function GetMoneyString(c) return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
  -- items: id -> equip location, item level
  ITEMS = { [100] = { "INVTYPE_WRIST", 20 }, [101] = { "INVTYPE_WRIST", 25 }, [200] = { "INVTYPE_FINGER", 18 },
            [201] = { "INVTYPE_FINGER", 22 }, [202] = { "INVTYPE_FINGER", 30 }, [300] = { "INVTYPE_HEAD", 30 },
            [400] = { "INVTYPE_CLOAK", 20 }, [900] = { "INVTYPE_NON_EQUIP", 1 } }
  local function ID(link) return tonumber(tostring(link):match("item:(%d+)")) end
  function L(id) return "|cff1eff00|Hitem:" .. id .. "|h[Item " .. id .. "]|h|r" end
  C_Item = { GetItemInfoInstant = function(link) local i = ITEMS[ID(link)]; return ID(link), nil, nil, i and i[1] end,
             GetDetailedItemLevelInfo = function(link) local i = ITEMS[ID(link)]; return i and i[2] end }
  -- worn: wrist 100, rings 200 (weaker) and 201; no head, no cloak worn
  WORN = { [9] = L(100), [11] = L(200), [12] = L(201) }
  function GetInventoryItemLink(_, slot) return WORN[slot] end
  -- Mastercraft's rows for a worn piece: { vendor, auction, disenchant, its pick }
  WORTH = { [100] = { 50, nil, 12000, "disenchant" }, [200] = { 300, 9000, nil, "auction" }, [201] = { 40, nil, nil, "vendor" } }
  GameTooltip.lines = {}
  function GameTooltip:GetItem() return nil, self.link end
  function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = t end
  READS = 0
  function GameTooltip:SetInventoryItem(_, slot)
    READS = READS + 1
    local w = WORTH[ID(WORN[slot])] or {}
    LEFT, RIGHT, RIGHTCOL = { "Item", "|cff4da6ffMastercraft|r" }, { nil, nil }, {}
    for i, label in ipairs({ "Vendor", "Auction", "Disenchant" }) do
      if w[i] then LEFT[#LEFT + 1] = label; RIGHT[#LEFT] = GetMoneyString(w[i])
        RIGHTCOL[#LEFT] = (w[4] == label:lower()) and { 1, 1, 0.6 } or { 0.85, 0.85, 0.85 } end
    end
  end
  -- CheapUpgrades: what it calls an upgrade
  UPGRADES = { [101] = true, [202] = true, [300] = true, [400] = true, [900] = true }
  CheapUpgrades = { ctx = {}, Bags = { BadgeText = function(info) return "+" .. info.pct .. "%" end } }
  function CheapUpgrades:WatchedInfo(link) if UPGRADES[ID(link)] then return { { info = { state = "upgrade", pct = 10 } } } end return {} end
  -- Mastercraft: characters, their bags / bank / mail, their recipes
  MastercraftDB = {
    chars = { ["Player-1"] = { name = "Anathar" }, ["Player-2"] = { name = "Bob" } },
    inv = { ["Player-1"] = { bank = { [202] = 1 } }, ["Player-2"] = { bags = { [202] = 1 }, mail = { [400] = 1 } } },
    recipes = { ["Player-2"] = { Leatherworking = { list = {
      { output = 101, learned = true, reagents = { { itemID = 2318, qty = 6 }, { itemID = 2320, qty = 2 } } },
      { output = 300, learned = false, reagents = {} },
      { output = 400, learned = true, reagents = { { itemID = 2318, qty = 2 }, { itemID = 9999, qty = 1 } } } } } } },
  }
  PRICES = { [2318] = 300, [2320] = 50 }
  Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return PRICES[id] end } } }
  -- the game's tooltip hook
  POST = {}
  Enum = { TooltipDataType = { Item = 0 } }
  TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) POST[#POST + 1] = fn end }
  function Hover(id, owner)
    GameTooltip.lines, GameTooltip.link, GameTooltip.owner = {}, L(id), owner or {}
    for _, fn in ipairs(POST) do fn(GameTooltip, { id = id }) end
    return table.concat(GameTooltip.lines, " | ")
  end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_CheapUpgrades_Mastercraft")
E, X = lua.eval, lua.execute
X('Fire("PLAYER_LOGIN"); Run()')
res = {}
res["your worn pieces' worth read beforehand, quietly"] = E("READS") == 3
wrist = E('Hover(101)')
res["an upgrade for your wrist: what your bracers bring back (Mastercraft's pick: disenchant)"] = "Replaces Item 100: ~1g 20s 0c back (disenchant)" in wrist
res["...who can craft it, its materials at Auctionator's prices"] = "You can craft it: Bob (Leatherworking) - materials ~0g 19s 0c" in wrist
res["...under a Master Options header"] = "Master Options - Mastercraft" in wrist
ring = E('Hover(202)')
res["a ring: the weaker of your two rings (item level 18) and its auction price"] = "Replaces Item 200: ~0g 90s 0c back (auction house)" in ring
res["...who already has one (bank, bags)"] = "You have one: Anathar (bank), Bob (bags)" in ring
head = E('Hover(300)')
res["nothing worn there: fills an empty slot (a recipe not learned: no craft line)"] = "Fills an empty slot" in head and "You can craft" not in head
cloak = E('Hover(400)')
res["a material without a price: the cost marked *"] = "materials ~0g 6s 0c*" in cloak and "Bob (mail)" in cloak
res["not an upgrade (CheapUpgrades says nothing): no lines"] = E('Hover(100)') == ""
res["not gear: no lines"] = E('Hover(900)') == ""
res["Master Options' own hidden read (GameTooltip off screen): no lines"] = E('Hover(101, WorldFrame)') == ""
X('WORN[9] = L(101); READS = 0; Fire("PLAYER_EQUIPMENT_CHANGED"); Run()')
res["your gear changed: only the new piece read again"] = E("READS") == 1
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
