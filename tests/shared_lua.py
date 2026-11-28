# Shared.lua (MasterOptions_Shared) is loaded before MasterOptions.lua and the modules in game (.toc): tests that
# load one of those files on its own load it first, from the addon folder the tested file is in.
import os


def load_shared(lua, tested_path):
    d = os.path.dirname(os.path.abspath(tested_path))
    for _ in range(3):
        p = os.path.join(d, "Shared.lua")
        if os.path.exists(p):
            f = lua.eval("function(s) local f, e = load(s, '=Shared.lua'); if not f then error(e) end; return f end")
            f(open(p, encoding="utf-8").read())()
            return
        d = os.path.dirname(d)
    raise FileNotFoundError("Shared.lua not found above " + tested_path)


def load_pawn(lua, tested_path):
    """Pawn.lua (Master Options' Pawn code: MasterOptions_Pawn, MasterOptions_GearKeeps ...) for a module's test, with
    the few core accessors it takes from MasterOptions.lua: Loaded (IsAddOnLoaded, or C_AddOns'), GM, PAWN."""
    d = os.path.dirname(os.path.abspath(tested_path))
    for _ in range(3):
        p = os.path.join(d, "Pawn.lua")
        if os.path.exists(p):
            break
        d = os.path.dirname(d)
    else:
        raise FileNotFoundError("Pawn.lua not found above " + tested_path)
    ns = lua.eval(r'''function()
      local function Loaded(n)
        local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        if f then return f(n) and true or false end
        return n == "Pawn" and type(PawnCommon) == "table" or n == "GearMatic" and type(GearMatic) == "table"
      end
      return { Loaded = Loaded,
        GM = function() local g = GearMatic; return type(g) == "table" and g.db and g.db.profile or nil end,
        PAWN = function() return type(PawnCommon) == "table" and PawnCommon or nil end }
    end''')()
    # (a test that makes its frame stubs later: a plain one for Pawn.lua's event frames meanwhile)
    lua.execute("if not CreateFrame then CreateFrame = function() return { RegisterEvent = function() end, "
                "SetScript = function() end } end; PAWN_TEMP_FRAMES = true end")
    load = lua.eval("function(s, n) local f, e = load(s, '=' .. n); if not f then error(e) end; return f end")
    load(open(p, encoding="utf-8").read(), "Pawn.lua")("MasterOptions", ns)
    lua.execute("if PAWN_TEMP_FRAMES then CreateFrame, PAWN_TEMP_FRAMES = nil, nil end")
    return ns


def load_master_options(lua, mo_path):
    """MasterOptions.lua and the files that follow it in the .toc (AddonSettings.lua ... Startup.lua), in that order,
    sharing one addon table as the game gives them (local _, ns = ...)."""
    d = os.path.dirname(os.path.abspath(mo_path))
    toc = open(os.path.join(d, "MasterOptions.toc"), encoding="utf-8").read().splitlines()
    files = [l.strip() for l in toc if l.strip() and not l.startswith("#")]
    start = files.index("MasterOptions.lua")
    core = []
    for f in files[start:]:
        if "\\" in f or "/" in f:
            break  # (Modules\... : the modules come after the core files)
        core.append(f)
    ns = lua.table()
    load = lua.eval("function(s, n) local f, e = load(s, '=' .. n); if not f then error(e) end; return f end")
    for f in core:
        load(open(os.path.join(d, f), encoding="utf-8").read(), f)("MasterOptions", ns)
    return ns


MODULE_STUB = "function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end"


def module_test(tested_path, **runtime_args):
    """A Lua runtime for a test of one file: Shared.lua loaded (load_shared), and MasterOptions_Module running a
    module's body at once, as its old addon did."""
    from lupa import LuaRuntime
    lua = LuaRuntime(**runtime_args)
    load_shared(lua, tested_path)
    lua.execute(MODULE_STUB)
    return lua


# The small fakes most module tests need (each test adds or overrides what it needs after them):
# frames with events (FRAMES, CreateFrame, Fire), timers (queued: RunTimers() runs one round, Run(n) up to n rounds;
# or run at once with timers_now), and errors counted (ERRS).
FAKE_FRAMES = r'''
FRAMES, TIMERS, ERRS = {}, {}, 0
function CreateFrame() local f = { ev = {} }
  function f:RegisterEvent(e) self.ev[e] = true end
  function f:SetScript(k, fn) self[k] = fn end
  FRAMES[#FRAMES + 1] = f; return f end
C_Timer = { After = function(d, fn) if TIMERS_NOW then fn() else TIMERS[#TIMERS + 1] = fn end end }
function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
function Run(n) for _ = 1, (n or 10) do RunTimers() end end
function Fire(e, ...) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e, ...) end end end
function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; io.write("ERR ", tostring(e), "\n") end
'''


def fake_frames(lua, timers_now=False):
    lua.globals().TIMERS_NOW = timers_now
    lua.execute(FAKE_FRAMES)


# GameTooltip, as the hidden reads use it: lines LEFT[i] / RIGHT[i] (RIGHTCOL[i]: a right text's colour), its
# GameTooltipTextLeft/Right1..12 font strings; never on screen. A test adds the Set... that fills LEFT and RIGHT.
FAKE_TOOLTIP = r'''
LEFT, RIGHT, RIGHTCOL = {}, {}, {}
GameTooltip = {}
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:NumLines() return #LEFT end
function GameTooltip:SetOwner(o) self.owner = o end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:IsShown() return false end
function GameTooltip:GetItem() return nil end
function GameTooltip:Hide() end
function GameTooltip:Show() end
function GameTooltip:AddLine() end
for i = 1, 12 do
  _G["GameTooltipTextLeft" .. i] = { GetText = function() return LEFT[i] end }
  _G["GameTooltipTextRight" .. i] = { GetText = function() return RIGHT[i] end, IsShown = function() return RIGHT[i] ~= nil end,
    GetTextColor = function() local c = RIGHTCOL[i] or { 1, 1, 1 }; return c[1], c[2], c[3] end }
end
'''


def fake_tooltip(lua):
    lua.execute(FAKE_TOOLTIP)


def module_source(tested_path):
    return open(tested_path, encoding="utf-8").read()
