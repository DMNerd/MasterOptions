# Changelog

What changed in each version of Master Options, as you notice it in game. Newest first.
Each version's section is also its release notes on GitHub.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.10.4] - 2026-11-27

### Fixed

- **Spare gear Mastercraft says to VENDOR is sold again** (sell mode "Goods and gear"). The off-spec check kept
  anything GearMatic ranked "2nd best" for a spec. But GearMatic ranks only what you own, so a spare pair of
  gloves far worse than the ones you wear counted as "2nd best" just for being the only other pair. Now only
  "best for one of your specs" keeps a piece (a bag piece that beats what you wear is an upgrade, still kept).
  The same check also protects gear from DeleteCheapestItem and GearMatic's own sell pass.
- A GearMatic upgrade only for an alt no longer keeps a **soulbound** piece: it can't be sent to them.
  Account-bound pieces still stay.

## [2.10.3] - 2026-11-27

### Changed

- **`/mo vendor`** says which rule keeps a piece of gear: a GearMatic loadout, Pawn, GearMatic's best / 2nd best for
  one of your specs, a GearMatic upgrade for you or an alt, best in slot, or an equipment set.

## [2.10.2] - 2026-11-27

### Added

- **`/mo vendor`**: lists every item in your bags that Mastercraft says to VENDOR, and for each one whether it
  will be sold at the next vendor or the rule that stops it (gear while the sell mode is Goods, the never-sell
  list, kept for a guide, no vendor price, no junk seller...). It also says who sells your junk and which junk
  coin Baganator uses. It only reports and never sells anything.

## [2.10.1] - 2026-11-27

### Added

- **Move Shortest Path's arrow** (Routes and waypoints), and `/mo arrow`: unlocks ShortestPathForever's direction
  arrow to drag anywhere (Shift-drag or the arrow keys nudge it, right-click puts it back), and locks it again,
  click-through, where you left it. The same switch as ShortestPathForever's own "Move the arrow".

## [2.10.0] - 2026-11-27

### Changed

- **One trip, one pin** (ShortestPathForever with OpenMap). However a trip starts - Shift-click on the map, a pin
  you follow in OpenMap, Dungeon Journal's Show on Map, a quest or recipe waypoint - it now looks and ends the
  same way:
  - **Placing:** an OpenMap pin marks the destination - OpenMap's own pin when there is one, else a gold one named
    after the journey - on the world map, the minimap and in OpenMap's pin list. ShortestPathForever's own goal
    marker is hidden meanwhile, so one pin marks the spot (at the minimap's rim its marker stays, pointing the
    way; a route's numbered stops stay too).
  - **Clearing:** any end - arriving, clearing it in ShortestPathForever, stopping it in OpenMap, a new journey
    replacing it - takes the pin away and OpenMap stops following it. A pin you wrote a note on stays.
  - Before, quest waypoints and Shift-click trips had no OpenMap pin, and a pin stayed (still followed) after you
    arrived or started another trip.

## [2.9.3] - 2026-11-27

### Changed

- **Minimap coordinates on the other edge say why.** When your minimap is right at the top of the screen, a tab
  "Top" would stick off it, so it goes under the minimap instead - as before, but the setting gave no sign of it.
  Its row in /mo now says "On the bottom edge now: no room above your minimap", and the tooltip explains it. Move
  the minimap a little away from the screen's edge to have it where you picked.

## [2.9.2] - 2026-11-27

### Fixed

- **The section list ran out of the /mo window.** With 2.9.0's sections it was taller than the window, and the
  last ones (Modules, Thanks) lay over the buttons below. The rows now fit the window, and if they ever don't, the
  list scrolls with the mouse wheel, keeping the section you picked in sight.
- **"No player named ... is currently playing" lines you didn't cause.** Addons talk to each other's copies with
  hidden whispers (OpenMap's map sharing, Questie's sync, Mastercraft's crafter search, Details); one to someone who
  just logged off makes the server print that line in your chat. New module **Chat / AddonWhispers** hides it -
  never for a whisper you typed yourself. `/mo whispers` lists which addon whispered whom.

## [2.9.1] - 2026-11-27

### Fixed

- **Questie's "iconData is nil! ... Aborting!" errors in chat** when you hovered a Questie icon on the map or
  minimap. Master Options' pattern vendor, trainer and drop markers (Mastercraft + Questie) share Questie's map
  pin library, and Questie checks every pin in it as if it were its own. Questie now passes ours by; they still
  show on the world map, OpenMap's map and the minimap.

## [2.9.0] - 2026-11-27

### Added

- **Spoken_Bosses' stories on Dungeon Journal's map.** When Dungeon Journal's map of a dungeon is on the world
  map (Map inside dungeons, Dungeon entrance click), Spoken_Bosses tells that dungeon's story beside it, and a
  boss's story when you click the boss. It used to know only OpenMap's and Leatrix Maps' dungeon views.

- **Pick who does it, for maps and routes** (where two addons both did it, each showed twice):
  - **Flight masters:** OpenMap or Questie.
  - **World map coordinates:** OpenMap, Questie or off.
  - **Town NPC icons:** a third choice, OpenMap on the world map with the game's tracking on the minimap.
  - **Minimap pins from:** OpenMap_MiniMap's gathered spots counted as a third source (one herb had three pins).
  - **Routes and waypoints** (ShortestPathForever): Navigation arrow (its arrow or the game's marker only),
    Arrow text (distance, time or both), Quest and recipe waypoints (a Shortest Path journey or the game's
    waypoint, for Questie, Mastercraft and WhatsTraining).
  - **Minimap buttons** (OpenMap_MiniMap): on mouse-over, round the edge, or in a tray.

- **Gathering pin size:** one size (Small / Medium / Large) for herb and ore pins on the world map and the
  minimap, whether Mastercraft or OpenMap_Tweaks draws them (Mastercraft's were bigger).

### Changed

- **One look:** the recipe map's markers are drawn in Questie's style and at Questie's town icon size (a
  trainer with its profession's icon, a vendor with a pattern on it, a drop with Questie's loot icon), with a
  soft gold glow for "for you". The dungeon chooser on OpenMap's map is a small /mo-style window.
- **Modules are plain options.** Each has a name that says what it does, its explanation and the addons it
  needs right under it (a missing one in red), and is greyed out while one of them isn't loaded. They're in
  four sections: maps, gear, selling and more. Seven newer modules had no on / off switch at all: they have
  one now (Farming tours, Recipe map markers, Upgrade marks in Dungeon Journal's loot, Keep your best gear for
  every spec, CheapUpgrades uses GearMatic's stat weights, Spoken's stories, Clearing a journey clears its pin).
- The minimap's zone bar and coordinates tab have the same header as the /mo window (and Details' title bar)
  while the action bar border is on.

### Fixed

- "Where an item drops (tooltip)" offers Dungeon Journal and All again (only addon names were listed).
- **Recipe map markers show.** They never did: Questie keeps its own copy of the map-pin library, which Master
  Options didn't look for.
- A farming tour no longer takes your route back at the next zone line after you followed a pin or a quest target
  (it starts in a new zone only in place of its own tour, or when no journey is under way).
- Minimap coordinates come back (the game's own line) when OpenMap_MiniMap's look is off or gives way to another
  minimap addon; they were hidden with no tab.
- The minimap's coordinates tab goes under the map when it would leave the top of the screen.
- ShortestPathForever's goal on the minimap hides with its route while you drag OpenMap_MiniMap's map.
- Dungeon Journal's and ShortestPathForever's clearing finds the OpenMap pin you followed even after the journey
  moved the game's waypoint along the way.
- Less work in fights with the world map open: OpenMap's stitched map isn't refreshed whole for gathering pins.
- The Minimap row also turns BetterBlizzFrames' "Hide minimap in arena" off for OpenMap_MiniMap.
- Clearing ShortestPathForever's journey to an OpenMap pin you followed clears the pin too: OpenMap no longer
  keeps following it, and the pin goes from the map (one you wrote a note on stays, no longer followed).
- The minimap's action bar border fits the map on both sides: no gap left of the map, and the zone bar's
  calendar no longer runs under the border on the right.

## [2.8.1] - 2026-11-27

### Added

- **/mo > Thanks:** the authors of every addon Master Options works with, the libraries it uses and the data
  behind GearMatic, CheapUpgrades and Mastercraft. The game's Options page (Options > AddOns > Master Options)
  has a Thanks button that opens it.
- Master Options' version and author in the /mo window's title, at the top of the Options page and in the
  minimap button's tooltip.

### Changed

- The addon list shows Master Options' author (DMNerd) and its new one-line description.
- Released under the MIT license.

## [2.8.0] - 2026-11-27

### Added

- **Farming tours from Mastercraft.** Start farming in Mastercraft and ShortestPathForever walks you through this
  zone's herbs and veins worth gathering for you (Mastercraft's own nodes and its "Which nodes" rule), nearest
  first, and stops when you do. ShortestPathForever's own farming tour needs GatherMate2; this one doesn't.
  `/mo farm` starts one without Mastercraft's session (`/mo farm herbs`, `ores`, `stop`).
- **Recipe map.** Markers on the world map and minimap:
  - vendors selling a pattern, recipe, plans, formula, schematic, manual, design or camp blueprint for a recipe
    you haven't learned;
  - creatures and chests that drop one, with GearMatic's WoW Forever drop chance (specific drops only - world
    drops aren't marked);
  - your profession's trainers once you're near your skill cap and can train the next rank.
  From Mastercraft's list of your recipes and QuestieDB. A pattern's own required skill isn't known: check its
  tooltip at the vendor.
- **Problems page:** BetterBetterBlizzPlates made for a different BetterBlizzPlates version (its window stays
  closed); QuestieDB turned off, missing, or without the data Questie needs (with an Enable button).
- **"Where an item drops (tooltip)"** now includes Mastercraft's material sources line: GearMatic, Dungeon
  Journal, Mastercraft, All or Off.

### Changed

- Smoother in busy places: the recipe map only redraws when something it shows changed (not on every weapon
  skill point) and waits out fights; Dungeon Journal's loot marks do nothing while the journal is closed;
  OpenMap's gathering pins no longer scan your tracking every frame.

## [2.7.0] - 2026-11-27

### Added

- **Upgrade marks in Dungeon Journal's loot.** Every item row shows an upgrade arrow and its size ("+23%"), and
  GearMatic's skull on what's best in slot for you - by Pawn with Pawn Forever, otherwise GearMatic with
  CheapUpgrades' size. A cog marks loot your Mastercraft guides need.
- **"Where an item drops (tooltip)":** GearMatic's drop chance line, Dungeon Journal's boss or quest line, or both.
- **"Chat lines only you see":** turns off (and back on) every addon's notices in your own chat - GearMatic's
  equip lines and reminders, CheapUpgrades' upgrade alert, Mastercraft's junk and repair summaries, Questie's
  own lines, Auctionator's auction log, Dungeon Journal's notices.

## [2.6.0] - 2026-11-27

### Added

- **Works without Pawn.** Everything that used Pawn falls back to GearMatic; Pawn stays a choice when it's
  installed. One rule picks who judges upgrades everywhere: Pawn with Pawn Forever, otherwise GearMatic.
- **Off-spec gear kept without Pawn:** gear that is your best or second-best for any of your specs in GearMatic
  isn't sold (by Master Options or GearMatic) or offered by DeleteCheapestItem.
- **CheapUpgrades uses GearMatic's stat weights** (a "GearMatic" weights profile per spec, kept up to date).
- **Bag icon size:** one size (Large / Medium / Small) for every icon on Baganator's bag slots, whichever addon
  adds it. Also: GearMatic's best-in-slot skull in bags on or off, and its vendor badge ($, coin or off).
- **Annoying mode:** turns off everything that posts in chat as you for others to see - GearMatic's upgrade
  posts and emotes, Questie's group announcements, Mastercraft's !who whispers - and back on as it was.
  Recommended off.
- **Problems page:** GearMatic's coin vendor badge next to Baganator's junk coin.

## [2.5.2] - 2026-11-26

Not released on its own: part of 2.6.0.

### Changed

- Lighter bag scan for DeleteCheapestItem protection and a lighter never-sell sync.
- OpenMap's gathering pin check and the minimap coordinates do less work while you stand still.

### Added

- **Problems page:** the old "local patch" addons (OpenMapTweaks_Mastercraft, CheapUpgrades_Baganator,
  Mastercraft_Baganator) are named as replaced by Master Options' modules.

## [2.5.1] - 2026-11-26

### Fixed

- Following GearMatic's spec no longer drops the protection of your off-spec gear from selling and deleting.

## [2.5.0] - 2026-11-26

### Added

- **"Spec for Pawn and CheapUpgrades": Follow GearMatic.** Pawn shows only your current spec's scale, and
  CheapUpgrades follows the same spec - at login, on a talent change and on GearMatic's Cat / Bear switch.

## [2.4.0] - 2026-11-26

### Added

- **Dungeon entrance click:** what clicking an OpenMap dungeon entrance opens - Dungeon Journal's map, its
  journal page, or OpenMap's map.
- **Town NPC icons:** OpenMap's world-map townsfolk as a third choice next to Questie and the game's tracking.
- **GearMatic sell guard:** GearMatic's own selling keeps the never-sell list, materials your Mastercraft guides
  need, and gear Pawn calls an upgrade or your best.

## [2.3.2] - 2026-11-25

### Fixed

- Map inside dungeons keeps everything OpenMap's own dungeon handling does (Zephras Isle's map, the dungeon
  card, quest log docking and more).
- Baganator's "Greys only" junk coins and "Off" upgrade arrows stay that way after a reload.
- GearMatic's "Upgrade % per spec" line is its item tooltip line.
- Vendor selling and DeleteCheapestItem also keep gear Pawn says is already your best or second-best.
- DeleteCheapestItem 1.9's list migration isn't read as items you removed.

## [2.3.1] - 2026-11-25

### Fixed

- Dragging an item onto the Never sell box adds it.

## [2.3.0] - 2026-11-25

### Added

- **/mo > Never sell:** the shared never-sell list, with each item's icon and tooltip; add by shift-click, drag or
  item ID, remove per item.

## [2.2.0] - 2026-11-25

### Added

- **One never-sell list** for GearMatic, Mastercraft and DeleteCheapestItem, kept the same in all three both ways.
  `/mo never <item>`, `/mo never remove <item>`, `/mo never`.

## [2.1.1] - 2026-11-25

### Fixed

- OpenMap_Tweaks' gathering pins on the normal world map (an error with OpenMap's stitched map off).

## [2.1.0] - 2026-11-25

### Added

- Rows for the fishing bobber mark (Sparkles_Forever or Mastercraft), the quest reward marker (Pawn or GearMatic)
  and the minimap (OpenMap_MiniMap or BetterBlizzFrames' classic one).
- Module ShortestPathForever / OpenMapMiniMap: the journey goal stays visible on OpenMap's painted minimap.
- **Problems page:** Pawn without Pawn Forever; Sparkles settings that clash with Mastercraft.

### Changed

- Works with Mastercraft 2.1.2, OpenMap_Tweaks 1.5.4 and CheapUpgrades 0.18.11 (the node filter reaches OpenMap's
  stitched map, Mastercraft's Settings > Modules are followed, and more).

## [2.0.0] - 2026-11-25

### Added

- **Master Options:** one window (`/mo`) for the settings that overlap between your addons, and modules that make
  them work together (until now separate `MasterOptions_<Addon>_<Addon>` addons). Each module runs only when the
  addons it works with are loaded.

[Unreleased]: https://github.com/DMNerd/MasterOptions/compare/v2.9.0...HEAD
[2.9.0]: https://github.com/DMNerd/MasterOptions/compare/v2.8.1...v2.9.0
[2.8.1]: https://github.com/DMNerd/MasterOptions/compare/v2.8.0...v2.8.1
[2.8.0]: https://github.com/DMNerd/MasterOptions/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/DMNerd/MasterOptions/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/DMNerd/MasterOptions/compare/v2.5.1...v2.6.0
[2.5.2]: https://github.com/DMNerd/MasterOptions/compare/v2.5.1...v2.6.0
[2.5.1]: https://github.com/DMNerd/MasterOptions/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/DMNerd/MasterOptions/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/DMNerd/MasterOptions/compare/v2.3.2...v2.4.0
[2.3.2]: https://github.com/DMNerd/MasterOptions/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/DMNerd/MasterOptions/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/DMNerd/MasterOptions/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/DMNerd/MasterOptions/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/DMNerd/MasterOptions/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/DMNerd/MasterOptions/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/DMNerd/MasterOptions/releases/tag/v2.0.0
