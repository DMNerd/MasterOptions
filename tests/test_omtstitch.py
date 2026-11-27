# OpenMapTweaks_Mastercraft with OpenMap's stitched map: OpenMap_Tweaks adds its gathering pins through
# OpenMap.MapStitch.AddPin (set "omt_gather", pin.data = the spot); Mastercraft's node rule must hide the unwanted ones.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  local Frame = {}
  Frame.__index = Frame
  function Frame:Show() self.shown = true end
  function Frame:Hide() self.shown = false end
  function Frame:SetShown(v) self.shown = v and true or false end
  function Frame:IsShown() return self.shown end
  function Frame:RegisterEvent(e) end
  function Frame:SetScript(k, fn) self[k] = fn end
  FRAMES = {}
  function CreateFrame() local f = setmetatable({}, Frame); FRAMES[#FRAMES + 1] = f; return f end
  function hooksecurefunc(t, k, fn) local o = t[k]; t[k] = function(...) local r = o(...); fn(...); return r end end
  function InCombatLockdown() return false end
  function IsResting() return false end
  function IsInInstance() return false end
  -- a miner with skill 150
  function GetProfessions() return 1 end
  function GetProfessionInfo(i) return "Mining", nil, 150, 300, nil, nil, 186 end
  TRACKING = false
  C_Minimap = { GetNumTrackingTypes = function() return 1 end,
                GetTrackingInfo = function() SCANS = (SCANS or 0) + 1; return { active = TRACKING, spellID = 2580 } end }
  MastercraftDB = { settings = { nodesFilter = "skillups", nodesWhen = "tracking" } }
  OpenMap = nil -- built late, as in game: the module hooks it on a later tick
  -- the normal world map (stitched map off): OpenMap_Tweaks' pin mixin, whose OnAcquired the module wraps
  OpenMapTweaksNodePinMixin = { OnAcquired = function(self, spot, x, y) self.spot = spot; self:Show() end }
  function Acquire(l)
    local pin = setmetatable({}, Frame)
    local ok, err = pcall(OpenMapTweaksNodePinMixin.OnAcquired, pin, { list = { { e = { sl = 186, l = l } } } }, 0.5, 0.5)
    pin.err = not ok and tostring(err) or nil
    return pin
  end

  function Fire(ev) for _, f in ipairs(FRAMES) do if f.OnEvent then f.OnEvent(f, ev) end end end
  function Tick() for _, f in ipairs(FRAMES) do if f.OnUpdate then f.OnUpdate(f, 1) end end end

  -- OpenMap's stitched map (Stitch.lua: PinSet / AddPin / GetPinSet)
  function BuildOpenMap()
    local sets = {}
    local S = {}
    function S.PinSet(key) sets[key] = sets[key] or { pins = {} }; return sets[key] end
    function S.GetPinSet(key) return sets[key] end
    function S.AddPin(set, u, v, look, data)
      local pin = setmetatable({ data = data }, Frame); pin:Show(); set.pins[#set.pins + 1] = pin; return pin
    end
    OpenMap = { MapStitch = S }
  end
  function AddOMT(l)
    local S = OpenMap.MapStitch
    return S.AddPin(S.PinSet("omt_gather"), 0.5, 0.5, {}, { list = { { e = { sl = 186, l = l } } } })
  end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_OpenMapTweaks_Mastercraft")
L, E = lua.execute, lua.eval
L('Fire("PLAYER_LOGIN"); BuildOpenMap(); Tick()')
res = {}
L('LOW, MID, HIGH = AddOMT(1), AddOMT(100), AddOMT(175)')
L('OTHER = OpenMap.MapStitch.AddPin(OpenMap.MapStitch.PinSet("questie"), 0.1, 0.1, {}, { list = { { e = { sl = 186, l = 100 } } } })')
res["not tracking: all ore pins hidden"] = E("not LOW.shown and not MID.shown and not HIGH.shown")
L('WM = Acquire(100)')
res["normal world map pin: no error"] = E("WM.err == nil")
res["normal world map pin, not tracking: hidden"] = E("WM.shown == false")
res["other pin sets untouched"] = E("OTHER.shown == true")
L('TRACKING = true; Tick()')
res["tracking, skill-ups: only 100 shows (1 is grey, 175 too high)"] = E("not LOW.shown and MID.shown and not HIGH.shown")
L('WM1, WM100 = Acquire(1), Acquire(100)')
res["normal world map, tracking: same rule (100 shows, 1 doesn't)"] = E("WM100.shown == true and WM1.shown == false")
L('MastercraftDB.settings.nodesFilter = "gatherable"; Tick()')
res["gatherable: 1 and 100 show"] = E("LOW.shown and MID.shown and not HIGH.shown")
L('MastercraftDB.settings.nodesFilter = "all"; Tick()')
res["all: every pin shows"] = E("LOW.shown and MID.shown and HIGH.shown")
L('NEW = AddOMT(250)')
res["a pin added later follows the rule"] = E("NEW.shown == true")
L('MastercraftDB.settings.nodes = { Mining = false }; Tick()')
res["Mastercraft's Mining map switch off: hidden"] = E("not LOW.shown and not MID.shown and not NEW.shown")
L('MastercraftDB.settings.nodes = nil; MastercraftDB.settings.nodesWhen = "farming"; Tick()')
res["while farming, not farming: hidden (tracking doesn't count)"] = E("not MID.shown")
L('function UnitGUID() return "Player-1" end; MastercraftDB.farm = { ["Player-1"] = { start = 1, gained = {} } }; Tick()')
res["while farming, farm session on: shown"] = E("MID.shown == true")
# (OpenMap_Tweaks shows every minimap pin every frame: the tracking scan is done twice a second, not per pin)
L('MastercraftDB.farm = nil; MastercraftDB.settings.nodesWhen = nil; TRACKING = true; Tick(); SCANS = 0; for i = 1, 50 do AddOMT(250) end')
res["50 pins shown: no tracking scan per pin"] = E("SCANS") == 0
L('TRACKING = false; Tick()')
res["tracking turned off: the next look sees it (pins hidden)"] = E("SCANS") > 0 and E("not AddOMT(250).shown")
L('WorldMapFrame = { IsShown = function() return true end, RefreshAllDataProviders = function() FULL = (FULL or 0) + 1 end }')
L('OpenMapAPI = { IsStitched = function() return true end }; FULL = 0; TRACKING = not TRACKING; Fire("MINIMAP_UPDATE_TRACKING")')
res["OpenMap's stitched map: a change doesn't refresh every map provider (only OpenMap's pins)"] = E("FULL") == 0
L('OpenMapAPI = nil; FULL = 0; TRACKING = not TRACKING; Fire("MINIMAP_UPDATE_TRACKING")')
res["Blizzard's own map: still refreshed (on a change)"] = E("FULL") >= 1
L('function InCombatLockdown() return true end; FULL = 0; TRACKING = not TRACKING; Fire("MINIMAP_UPDATE_TRACKING"); function InCombatLockdown() return false end')
res["...but not in a fight"] = E("FULL") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
