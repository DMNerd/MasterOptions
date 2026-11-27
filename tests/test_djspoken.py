# DungeonJournal_SpokenBosses: Dungeon Journal's map on the world map -> Spoken_Bosses' dungeon story; a boss
# clicked there -> its story; the map gone -> the story cleared (only one we showed). Dungeon Journal's names
# (wings, "The", its own spellings) -> Spoken's instances.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, _sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  FRAMES, ERRS, LOG = {}, 0, {}
  function CreateFrame() local f = { ev = {} }
    function f:RegisterEvent(e) self.ev[e] = true end
    function f:SetScript(k, fn) self[k] = fn end
    FRAMES[#FRAMES + 1] = f; return f end
  QUEUE, TM = false, {}
  C_Timer = { After = function(d, fn) if QUEUE then TM[#TM + 1] = fn else fn() end end }
  function RunTimers() local t = TM; TM = {}; for _, fn in ipairs(t) do fn() end end
  function Fire(e) for _, f in ipairs(FRAMES) do if f.ev[e] and f.OnEvent then f.OnEvent(f, e) end end end
  function MasterOptions_ReportError(_, _, e) ERRS = ERRS + 1; print("ERR", e) end
  function hooksecurefunc(t, k, fn) local orig = t[k]; t[k] = function(...) local r = orig(...); fn(...); return r end end
  WorldMapFrame = { scripts = {} }
  function WorldMapFrame:HookScript(k, fn) self.scripts[k] = fn end
  function WorldMapFrame:OnMapChanged() end
  -- Spoken
  SpokenDungeons = { dungeons = {
    [33] = { "Shadowfang Keep" }, [34] = { "Stormwind Stockade" }, [36] = { "Deadmines" },
    [189] = { "Scarlet Monastery" }, [329] = { "Stratholme" }, [229] = { "Blackrock Spire" },
    [3001] = { "The Shaper's Terrace" }, [2998] = { "Excavation Site: Wetlands" } } }
  local function key(n) return n and n:lower() end
  BOSSES = { [33] = { "Rethilgore", "Baron Silverlaine" }, [329] = { "Baron Rivendare" }, [99] = { "Baron Silverlaine" } }
  SpokenBossesAddon = { MapLore = {
    CurrentMapID = function() return 1421 end,
    ShowDungeon = function(map, id) LOG[#LOG + 1] = "dungeon " .. id .. "@" .. map; return id ~= 36 end,
    ShowBoss = function(map, found) LOG[#LOG + 1] = "boss " .. found.map .. ":" .. found.key; return true end,
    ClearStory = function() LOG[#LOG + 1] = "clear" end,
    BossNameKey = key,
    BossByName = function(wanted, prefer)
      for map, list in pairs(BOSSES) do for _, n in ipairs(list) do
        if key(n) == wanted and prefer and prefer(map) then return { map = map, key = wanted } end end end end,
  } }
  -- Spoken Places: a click on the map picks a place (SelectMap on OpenMap's map, SelectSubzone on Blizzard's)
  SpokenPlaces = { selected = nil }
  function SpokenPlaces:SelectMap(mapID) self.selected = { mapID = mapID, map = true } end
  function SpokenPlaces:SelectSubzone(mapID, area) self.selected = { mapID = mapID, areaName = area } end
  -- Dungeon Journal
  ATTACHED = false
  ForeverDungeonJournal_NS = {
    DB = { ["Shadowfang Keep"] = { bosses = { { name = "Rethilgore" }, { name = "Baron Silverlaine" } } } },
    SetMapDungeon = function() end,
    IsWorldMapOverlayAttached = function() return ATTACHED end,
    RefreshWorldMapOverlay = function() end,
    OpenBossFromWorldMap = function() end,
  }
  local FDJ = ForeverDungeonJournal_NS
  function Draw(name) ATTACHED = name ~= nil; if name then FDJ.SetMapDungeon(name) end; FDJ.RefreshWorldMapOverlay() end
  function Log() local s = table.concat(LOG, ","); LOG = {}; return s end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_DungeonJournal_SpokenBosses")
E, L = lua.eval, lua.execute
L('Fire("PLAYER_LOGIN")')
I = lambda n: E('MasterOptions_DJSpoken.InstanceOf("%s")' % n)
res = {
    "names: exact": I("Shadowfang Keep") == 33,
    "names: Dungeon Journal's 'The Deadmines'": I("The Deadmines") == 36,
    "names: a wing ('Stratholme: Living', 'Scarlet Monastery: Library')": I("Stratholme: Living") == 329 and I("Scarlet Monastery: Library") == 189,
    "names: its own spellings (The Stockade, Upper Blackrock Spire, Shaper's Terrace)":
        I("The Stockade") == 34 and I("Upper Blackrock Spire") == 229 and I("Shaper's Terrace") == 3001,
    "names: a colon in Spoken's own name stays exact": I("Excavation Site: Wetlands") == 2998,
    "names: unknown -> nothing": I("Hall of Nowhere") is None,
}
L('Draw("Shadowfang Keep")')
res["map up: the dungeon's story beside the world map"] = E("Log()") == "dungeon 33@1421"
L('FDJ_ = ForeverDungeonJournal_NS; FDJ_.RefreshWorldMapOverlay()')
res["refreshed, same dungeon: not shown again"] = E("Log()") == ""
L('WorldMapFrame:OnMapChanged()')
res["the map changed under Dungeon Journal's map (Spoken dropped ours): the dungeon's story back"] = E("Log()") == "dungeon 33@1421"
L('ForeverDungeonJournal_NS.OpenBossFromWorldMap("Shadowfang Keep", 2); ForeverDungeonJournal_NS.RefreshWorldMapOverlay()')
res["a boss clicked: its story, in that dungeon (a same-named boss elsewhere isn't picked)"] = E("Log()") == "boss 33:baron silverlaine"
L('Draw("Stratholme: Undead")')
res["another dungeon: ours cleared, its story"] = E("Log()") == "clear,dungeon 329@1421"
L('Draw(nil)')
res["map detached: story cleared"] = E("Log()") == "clear"
L('Draw(nil)')
res["...and only once"] = E("Log()") == ""
L('WorldMapFrame:OnMapChanged()')
res["a map change with Dungeon Journal's map not up: nothing"] = E("Log()") == ""
L('Draw("The Deadmines")')
res["a dungeon Spoken has no story for: nothing to clear later"] = E("Log()") == "dungeon 36@1421"
L('WorldMapFrame.scripts.OnHide()')
res["...the map closing doesn't clear someone else's story"] = E("Log()") == ""
L('Draw("Shadowfang Keep"); Log(); WorldMapFrame.scripts.OnHide()')
res["world map closed: our story cleared"] = E("Log()") == "clear"
L('ATTACHED = false; ForeverDungeonJournal_NS.OpenBossFromWorldMap("Shadowfang Keep", 1)')
res["a boss opened from the journal (not the world map): nothing"] = E("Log()") == ""
# the entrance click on OpenMap's map also picks the zone under it in Spoken Places (after our story went up, and
# however long the click took); so does any click on Dungeon Journal's map, which covers the zone
L(r'''
  WorldMapFrame.scripts.OnHide(); Draw(nil); Log()
  local show = SpokenBossesAddon.MapLore.ShowDungeon
  SpokenBossesAddon.MapLore.ShowDungeon = function(map, id) SpokenPlaces.selected = nil; return show(map, id) end
  local boss = SpokenBossesAddon.MapLore.ShowBoss
  SpokenBossesAddon.MapLore.ShowBoss = function(map, found) SpokenPlaces.selected = nil; return boss(map, found) end
  Draw("Shadowfang Keep")
  SpokenPlaces:SelectMap(1421)   -- (Spoken's click handler, same click)
''')
res["Spoken picked the zone under Dungeon Journal's map: the dungeon's story put back"] = (
    E("Log()") == "dungeon 33@1421,dungeon 33@1421" and E("SpokenPlaces.selected") is None)
L('ForeverDungeonJournal_NS.OpenBossFromWorldMap("Shadowfang Keep", 2); Log(); SpokenPlaces:SelectSubzone(1421, "Pyrewood Village")')
res["...after a boss was clicked: the boss's story put back, not the dungeon's"] = E("Log()") == "boss 33:baron silverlaine"
L('Draw(nil); Log(); SpokenPlaces:SelectMap(1421)')
res["...with Dungeon Journal's map gone: Spoken's pick stays"] = E("Log()") == "" and E("SpokenPlaces.selected ~= nil") is True
L('ForeverDungeonJournal_NS.OpenBossFromWorldMap("Shadowfang Keep", 1); SpokenPlaces.selected = nil; Log()')
L('Draw("Shadowfang Keep"); Log(); OUT = {}; local p = print; print = function(s) OUT[#OUT + 1] = s end; MasterOptions_DJSpoken.Explain(); print = p')
res["/mo story: says what the last try did"] = "Spoken's instance 33, on map 1421 -> story shown" in lua.eval("OUT[2]")
L('SpokenBossesAddon.MapLore = nil; Draw("Shadowfang Keep")')
res["Spoken's helper gone: nothing, no error"] = E("Log()") == "" and E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
