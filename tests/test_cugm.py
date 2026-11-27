# CheapUpgrades_GearMatic: CheapUpgrades gets a "GearMatic" weights profile per spec from GearMatic's own spec
# weights, in its units (ratings -> per 1%), used unless you picked a profile of your own; kept up to date.
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
  -- GearMatic: a druid's spec lines (+ a Pawn copy, which must not be used)
  GM_SCALES = {
    { name = "Pawn copy", spec = "Balance", weights = { spellpower = 99 } },
    { speclogic = true, specToken = "Balance", weights = { spellpower = 6, spelldamage = 6, critrating = 3, hitrating = 7,
      intellect = 1.2, weaponskill_mh_1 = 5 } },
    { speclogic = true, specToken = "Feral_DPS", weights = { agility = 6, strength = 5, critrating = 4.2, feralattackpower = 2 } },
    { speclogic = true, specToken = "Feral_Tank", weights = { stamina = 4, agility = 2, dodgerating = 1, armor = 0.1 } },
    { bundled = true, spec = "Restoration", weights = { healing = 2, intellect = 1, mp5 = 2 } },
  }
  GearMatic = { Compat = { CurrentCharKey = function() return "R-Me" end },
                ScaleImport = { GetScalesForClass = function() return GM_SCALES end } }
  -- CheapUpgrades: the profile API (Profiles.lua) as it behaves
  PROFILES, EVALS, CREATES = {}, 0, 0
  CheapUpgrades = { chardb = { profile = { BEAR = "My bear" } }, db = {} }
  function CheapUpgrades:GetClass() return "DRUID" end
  function CheapUpgrades:Evaluate() EVALS = EVALS + 1 end
  CheapUpgrades.Profiles = {
    Known = function() local k = {} for _, s in ipairs({ "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPELL_POWER", "HEALING",
      "CRIT", "HIT", "DODGE", "ARMOR", "MP5", "FERAL_ATTACK_POWER" }) do k[s] = true end return k end,
  }
  local P = CheapUpgrades.Profiles
  function P:Get(class, spec, name) for _, p in ipairs(PROFILES) do if p.class == class and p.spec == spec and p.name == name then return p end end end
  function P:Create(spec, name, weights, class) CREATES = CREATES + 1
    local p = { spec = spec, name = name, weights = weights, class = class }; PROFILES[#PROFILES + 1] = p; return p end
  function P:SetActive(spec, name) CheapUpgrades.chardb.profile[spec] = name end
  function Prof(spec) return P:Get("DRUID", spec, "GearMatic") end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_CheapUpgrades_GearMatic")
E, L = lua.eval, lua.execute
L('Fire("PLAYER_LOGIN"); RunTimers()')
close = lambda a, b: a is not None and abs(a - b) < 1e-3
res = {
    "a profile per spec GearMatic has": all(E('Prof("%s") ~= nil' % k) for k in ("BALANCE", "CAT", "BEAR", "RESTO")),
    "Balance: shown against spell power (1.0), not doubled with spell damage": close(E('Prof("BALANCE").weights.SPELL_POWER'), 1.0),
    "Balance: crit per rating -> per 1% (3 x 14 / 6)": close(E('Prof("BALANCE").weights.CRIT'), 7.0),
    "Balance: hit per rating -> per 1% (7 x 10 / 6)": close(E('Prof("BALANCE").weights.HIT'), 11.6667),
    "Balance: from GearMatic's spec line, not the Pawn copy": not close(E('Prof("BALANCE").weights.SPELL_POWER'), 99 / 6),
    "weapon skill left out (no such stat)": E('next(Prof("BALANCE").weights, nil) ~= nil and Prof("BALANCE").weights.WEAPONSKILL_MH_1 == nil'),
    "Feral_DPS -> Cat, against strength (first main stat)": close(E('Prof("CAT").weights.STRENGTH'), 1.0) and close(E('Prof("CAT").weights.AGILITY'), 1.2),
    "Feral_Tank -> Bear, dodge per 1% (x12)": close(E('Prof("BEAR").weights.DODGE'), 12 / 2),
    "Restoration from the bundled pool": close(E('Prof("RESTO").weights.HEALING'), 1.0),
    "used where you had nothing": all(E('CheapUpgrades.chardb.profile.%s' % k) == "GearMatic" for k in ("BALANCE", "CAT", "RESTO")),
    "your own Bear profile stays in use": E('CheapUpgrades.chardb.profile.BEAR') == "My bear",
    "CheapUpgrades re-evaluated": E("EVALS") == 1,
}
L('CREATES, EVALS = 0, 0; Fire("PLAYER_LEVEL_UP"); RunTimers()')
res["nothing changed: nothing rewritten, no re-evaluation"] = E("CREATES") == 0 and E("EVALS") == 0
L('GM_SCALES[2].weights.critrating = 6; Fire("PLAYER_TALENT_UPDATE"); RunTimers()')
res["GearMatic's weights changed: the profile follows"] = close(E('Prof("BALANCE").weights.CRIT'), 14.0) and E("CREATES") == 0 and E("EVALS") == 1
L('EVALS = 0; GearMatic.ScaleImport.PawnLiveScaleName = function() return "Pawn Forever: Balance" end; Fire("PLAYER_TALENT_UPDATE"); RunTimers()')
res["GearMatic on Pawn's scale: stands aside (CheapUpgrades follows Pawn), your own kept"] = (
    all(E('CheapUpgrades.chardb.profile.%s' % k) is None for k in ("BALANCE", "CAT", "RESTO"))
    and E('CheapUpgrades.chardb.profile.BEAR') == "My bear" and E("EVALS") == 1 and E('Prof("BALANCE") ~= nil'))
L('GearMatic.ScaleImport.PawnLiveScaleName = function() return nil end; Fire("PLAYER_TALENT_UPDATE"); RunTimers()')
res["GearMatic back on its own weights: the profiles in use again"] = E('CheapUpgrades.chardb.profile.BALANCE') == "GearMatic"
L('GearMatic.ScaleImport = nil; Fire("PLAYER_LEVEL_UP"); RunTimers()')
res["GearMatic not ready: nothing done, no error"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
