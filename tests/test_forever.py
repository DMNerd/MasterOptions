import sys
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[2])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
sv, patch = sys.argv[1], sys.argv[2]
lua.execute(open(sv, encoding="utf-8").read())
lua.execute(r'''
  PLAYER = { "Testchar", "Alpha", "ROGUE" }
  function UnitName(u) return PLAYER[1], PLAYER[2] end
  function UnitClass(u) return PLAYER[3], PLAYER[3] end
  function GetRealmName() return "" end
  function print(...) io.write(table.concat({...}, " "), "\n") end
  frames = {}
  function CreateFrame() local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    frames[#frames+1] = f; return f end
  -- GearMatic's Compat, copied logic
  local C = {}
  function C.RealmCharKey(realm, name) return (realm or GetRealmName() or "?") .. "-" .. (name or "?") end
  local savedRealm
  function C.PlayerRealm()
    local r = GetRealmName(); if r ~= "" then return r end
    if savedRealm then return savedRealm end
    local name = UnitName("player"); local _, class = UnitClass("player")
    local found, count = nil, 0
    for _, d in pairs(GearMaticDB.chars) do
      if type(d) == "table" and d.name == name and d.class == class and type(d.realm) == "string" and d.realm ~= "" and d.realm ~= found then found = d.realm; count = count + 1 end
    end
    if count ~= 1 then return "" end
    savedRealm = found; return found
  end
  function C.CurrentCharKey() return C.RealmCharKey(C.PlayerRealm(), (UnitName("player"))) end
  function C._reset() savedRealm = nil end
  GearMatic = { Compat = C }
  function fire(ev, arg) for _, f in ipairs(frames) do if f.events[ev] and f.OnEvent then f.OnEvent(f, ev, arg) end end end
  function keys(t, pat) local o = {} for k in pairs(t) do if tostring(k):find(pat) then o[#o+1] = tostring(k) end end table.sort(o) return table.concat(o, " | ") end
  -- pretend a loadout exists in the shared slot
  GearMaticDB.loadouts = { ["-Testchar"] = { RogueSet = { slots = {} } } }
''')
chunk = lua.eval("function(src) return load(src, '=patch') end")(open(patch, encoding="utf-8").read())
chunk("MasterOptions_GearMatic_Forever")
L = lua.eval
print("BEFORE chars:", L('keys(GearMaticDB.chars, "Testchar")'))
print("BEFORE scales:", L('keys(GearMaticDB.scales, "Testchar")'))
lua.execute('fire("ADDON_LOADED", "MasterOptions_GearMatic_Forever")')
print("key now:", L('GearMatic.Compat.CurrentCharKey()'))
print("AFTER chars:", L('keys(GearMaticDB.chars, "Testchar")'))
print("AFTER scales:", L('keys(GearMaticDB.scales, "Testchar")'))
print("rogue class at new key:", L('GearMaticDB.chars["-Testchar Alpha"] and GearMaticDB.chars["-Testchar Alpha"].class'))
lua.execute('fire("PLAYER_LOGOUT")')
print("stash loadouts:", L('keys(MasterOptions_GearMaticForeverDB.stash.loadouts, "")'))
# second character: the mage
lua.execute('PLAYER = { "Testchar", "Beta", "MAGE" }; GearMatic.Compat._reset(); done_reset = true')
chunk2 = lua.eval("function(src) return load(src, '=patch2') end")(open(patch, encoding="utf-8").read())
lua.execute('frames = {}')
lua.execute('GearMatic.Compat.CurrentCharKey = function() return GearMatic.Compat.RealmCharKey(GearMatic.Compat.PlayerRealm(), (UnitName("player"))) end')
chunk2("MasterOptions_GearMatic_Forever")
lua.execute('fire("ADDON_LOADED", "MasterOptions_GearMatic_Forever")')
print("mage key:", L('GearMatic.Compat.CurrentCharKey()'))
print("AFTER2 chars:", L('keys(GearMaticDB.chars, "Testchar")'))
print("mage loadout slot (should be empty):", L('GearMaticDB.loadouts["-Testchar"] == nil'))

