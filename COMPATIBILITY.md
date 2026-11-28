# Compatibility log

Every update check (`scripts\check-addons.ps1 -Log`, see UPDATING.md), newest first: the versions of the
addons Master Options works with, which changed since the check before, and what was done about it.

## 2026-11-28 - Master Options 2.19.0

| Addon | Version | Since the last check | Names |
|---|---|---|---|
| Mastercraft | 2.1.3 | same | ok |
| OpenMap_Tweaks | 1.5.5 | same | ok |
| CheapUpgrades | 0.18.13 | same | ok |
| Baganator | 870 | same | ok |
| Syndicator | 293 | same | ok |
| GearMatic | 6.11.0 | same | ok |
| OpenMap | v0.8.14 | same | ok |
| OpenMap_MiniMap | 1.4.1 | **updated** (was 1.4.0) | ok |
| ForeverDungeonJournal | 2.1.7 | same | ok |
| Questie | ? | same | ok |
| DialogKey_Numy | v1.2.62 | same | ok |
| Chattynator | 241 | same | ok |
| Auctionator | 354 | same | ok |
| BetterBlizzPlates | v2.2.5c | same | ok |
| BetterBlizzFrames | v2.2.4 | same | ok |
| Details | #Details.20261124.15450.172 | same | ok |
| DeleteCheapestItem | v1.11.0 | **updated** (was v1.10.0) | ok |
| Sparkles_Forever | 0.6.0-beta | same | ok |
| ShortestPathForever | 1.50.0 | **updated** (was 1.49.3) | ok |
| QuestieDB | 1.1.6 | same | ok |
| Spoken_Bosses | 3.13.2 | same | ok |
| Spoken | 3.13.2 | same | ok |
| Spoken_Places | 3.13.2 | same | ok |

Not installed (skipped): Pawn, Pawn_Forever, BetterBetterBlizzPlates.

**Notes:**
- **ShortestPathForever 1.49.4 / 1.50.0** (its CHANGELOG.md): 1.49.4 - turning off *Show direction arrow* hides its
  arrow *and the game's waypoint marker* (TomTom's arrow stays). That broke Master Options' "Navigation arrow: Game's
  marker only": nothing was left on screen to follow. Fixed: the choice is now **Destination pin only** - its arrow
  off and its "Show a pin over the destination" (destinationPin, set through its registered Settings entry) on; back
  to its arrow turns the pin off again if Master Options turned it on. The old choice name still works (shared
  choices moved over), and a Problems row catches an arrow left off with no pin and no TomTom ("Turn on the pin").
  1.50.0 - a compass that can stay on screen without a journey, and a TomTom waypoint you remove stays removed: nothing
  Master Options touches.
- **OpenMap_MiniMap 1.4.1** (no changelog in its folder; CurseForge file page,
  https://www.curseforge.com/wow/addons/openmap-minimap-the-openmap-companion/files/9863635): straight or curved zone
  bar on the round map, zone name size, zoom buttons and tracking / calendar / clock can be hidden or shown on
  mouse-over only, painted map in cities can be off, an edge waypoint arrow toggle, stepped dungeon zoom, fixes
  (black outline after flights, Rotate Minimap reset at login, the "not tested" message for OpenMap 0.8.14). Checked
  against Master Options: the border follows the zone bar's real edges (a straight bar or a bigger name is measured,
  not assumed); hidden buttons aren't counted when the coordinates move clear of buttons (only shown ones are);
  ShortestPathForever_OpenMapMiniMap stands aside from 1.4.0 on. Nothing to change.
- **DeleteCheapestItem 1.11.0** (its CHANGELOG.md): reagent bag markers in its loot window, icons inset on Forever.
  Master Options only keeps its IgnoredItems list (DeleteCheapestItem_Protect): nothing to change.

## 2026-11-27 - Master Options 2.16.0

| Addon | Version | Since the last check | Names |
|---|---|---|---|
| Mastercraft | 2.1.3 | same | ok |
| OpenMap_Tweaks | 1.5.5 | same | ok |
| CheapUpgrades | 0.18.13 | **updated** (was 0.18.12) | ok |
| Baganator | 870 | same | ok |
| Syndicator | 293 | same | ok |
| GearMatic | 6.11.0 | same | ok |
| OpenMap | v0.8.14 | **updated** (was v0.8.13) | ok |
| OpenMap_MiniMap | 1.4.0 | same | ok |
| ForeverDungeonJournal | 2.1.7 | same | ok |
| Questie | ? | same | ok |
| DialogKey_Numy | v1.2.62 | same | ok |
| Chattynator | 241 | same | ok |
| Auctionator | 354 | same | ok |
| BetterBlizzPlates | v2.2.5c | same | ok |
| BetterBlizzFrames | v2.2.4 | same | ok |
| Details | #Details.20261124.15450.172 | same | ok |
| DeleteCheapestItem | v1.10.0 | same | ok |
| Sparkles_Forever | 0.6.0-beta | same | ok |
| ShortestPathForever | 1.49.3 | **updated** (was 1.49.1) | ok |
| QuestieDB | 1.1.6 | same | ok |
| Spoken_Bosses | 3.13.2 | **updated** (was 3.13.1) | ok |
| Spoken | 3.13.2 | **updated** (was 3.13.1) | ok |
| Spoken_Places | 3.13.2 | **updated** (was 3.13.1) | ok |

Not installed (skipped): Pawn, Pawn_Forever, BetterBetterBlizzPlates.

**Notes:**

- **ShortestPathForever 1.49.2-1.49.3:** a dot midway on short dotted walks; Follow TomTom's arrow picks your waypoint
  back up. Nothing we use changed.
- **OpenMap v0.8.14:** battleground maps zoom; a "Find a place" search box on the map's title bar; "Waypoint distance in
  meters" and "TomTom waypoint too" options (Master Options sets neither); API 5 (RegisterMenuToggle right-click,
  RefreshMenuToggles - not used by us). Clicking a quest icon no longer tracks it; Ctrl-click waypoints and following a
  pin wait for a fight to end. Townsfolk icons now under Questie's. Dungeon Journal's dungeon maps no longer drawn
  over inside dungeons - fits our Map inside dungeons. Nothing to change.
- **CheapUpgrades 0.18.13:** a green "Top pick" in its Upgrades and Alts tabs, a bigger /cu status, auction house scan lag
  fixed. Its bag badges (ours in Baganator) unchanged.
- **Spoken 3.13.2** (Spoken, Spoken_Places by rustykey; Spoken_Bosses by Nucabe): a voice-feedback invitation at login
  (its own setting), less stutter, narrator API additions (Supports, RegisterNarrator, GetSpeaker, a Pause control).
  Spoken_Places' SelectMap / SelectSubzone and Spoken_Bosses' MapLore, which our story module uses, unchanged.
- Changelogs read online: OpenMap's GitHub CHANGELOG, the CurseForge file pages of CheapUpgrades, Spoken and
  OpenMap_MiniMap. README's credits corrected (Spoken is rustykey's, not Nucabe's: Nucabe made Spoken Bosses).

## 2026-11-27 - Master Options 2.15.0 (before this log was kept)

From the update check then, written down afterwards:

- **ShortestPathForever 1.49.1** dropped `goalEdge` (the minimap goal at the rim): its EDGE_ALPHA fade tells it now -
  Master Options 2.15.1. Its 1.49.0 calmer tour line (`tourLine`) used by farming tours from 2.15.2.
- **OpenMap_MiniMap 1.4.0** (from 1.3.1): new borders (WOW Default - round -, Bronze, Sky Blue), "Show the zone bar",
  "Arrange addon buttons", a curved zone bar on the round minimap. It now keeps Shortest Path's minimap destination
  from fading itself - what our ShortestPathForever_OpenMapMiniMap module does (both together are harmless; the
  module can retire once nobody runs an older OpenMap_MiniMap). Its button slots stay private: the coordinates plate
  moves clear of buttons instead (2.16.0).
- **OpenMap_Tweaks 1.5.5, CheapUpgrades 0.18.12, Spoken 3.13.1:** every name still there.

