# GearMatic_SpecKeep: an item GearMatic rates best or 2nd best for ANY of your specs is kept (off-spec too);
# levelling leftovers at max level aren't; anything GearMatic can't answer is left alone, never an error.
import sys
src = open(sys.argv[1], encoding="utf-8").read()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test; lua = module_test(_sys.argv[1])
lua.execute(r'''
  ERRS = 0
  function MasterOptions_ReportError() ERRS = ERRS + 1 end
  function Link(id) return "|cff|Hitem:" .. id .. "::::|h[x]|h|r" end
  local function ID(link) return tonumber(link:match("item:(%d+)")) end
  -- 300: best for the off-spec only, 301: best for the spec you play, 400: best but a levelling leftover,
  -- 500: a material (not equippable), 600: gear nobody rates, 666: GearMatic errors on it
  C_Item = { GetItemInfoInstant = function(link)
    if ID(link) == 500 then return 500, "Trade Goods", "Cloth", "" end
    return ID(link), "Weapon", "Sword", "INVTYPE_WEAPON" end }
  CURRENT, OFF = { name = "Combat" }, { name = "Subtlety" }
  ASKED = {}
  GearMatic = {
    Compat = { CurrentCharKey = function() return "Realm-Me" end },
    ScaleImport = { GetScalesForClass = function(key) if key == "Realm-Me" then return { CURRENT, OFF } end return {} end },
    Scoring2 = { BestItems = {
      BadgeLevelBandPasses = function(link) return ID(link) ~= 400 end,
      IsItemBestOrSecondBest = function(scale, equipLoc, link, owned)
        ASKED[#ASKED + 1] = equipLoc .. ":" .. tostring(owned)
        local id = ID(link)
        if id == 666 then error("boom") end
        if id == 300 then return scale == OFF end
        if id == 301 or id == 400 then return scale == CURRENT end
        return false
      end } },
  }
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_GearMatic_SpecKeep")
E = lua.eval
L = lua.execute
res = {
    "module API there": E("type(MasterOptions_GearMaticSpecKeeps) == 'table'"),
    "off-spec best kept": E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(300))") is True,
    "current-spec best kept": E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(301))") is True,
    "levelling leftover not kept": E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(400))") is False,
    "material not asked about": E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(500))") is False,
    "gear nobody rates not kept": E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(600))") is False,
}
L("ASKED = {}; MANY = MasterOptions_GearMaticSpecKeeps.KeepsMany({ Link(300), Link(600), Link(301), Link(666) })")
res["many: the kept ones only"] = (E("MANY[Link(300)]") is True and E("MANY[Link(301)]") is True
    and E("MANY[Link(600)]") is None and E("MANY[Link(666)]") is None)
res["asked with the item's slot and owned pools"] = E("ASKED[1]") == "INVTYPE_WEAPON:true"
res["GearMatic erroring: not kept, no error out"] = E("ERRS") == 0
# GearMatic's own ranks (GetRank + RankAppliesToSlot): 2nd best only counts where a second one is worn
L(r'''
  local function ID(link) return tonumber(link:match("item:(%d+)")) end
  SLOT = { [700] = "INVTYPE_HAND", [701] = "INVTYPE_FINGER", [702] = "INVTYPE_HAND" }
  C_Item.GetItemInfoInstant = function(link) local id = ID(link) return id, "Armor", "Cloth", SLOT[id] or "INVTYPE_WEAPON" end
  local bi = GearMatic.Scoring2.BestItems
  bi.GetRank = function(scale, loc, link) local id = ID(link)
    if id == 700 or id == 701 then return "second" end
    if id == 702 then return scale == OFF and "best" or "second" end
  end
  bi.RankAppliesToSlot = function(loc) return loc == "INVTYPE_FINGER" end
''')
res["spare gloves, 2nd best: not kept"] = E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(700))") is False
res["2nd best ring: not kept either"] = E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(701))") is False
res["gloves best for the off-spec: kept"] = E("MasterOptions_GearMaticSpecKeeps.Keeps(Link(702))") is True
L("GearMatic.Scoring2 = nil")
res["GearMatic without BestItems: nothing kept, no error"] = (E("next(MasterOptions_GearMaticSpecKeeps.KeepsMany({ Link(300) })) == nil")
    and E("ERRS") == 0)
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
