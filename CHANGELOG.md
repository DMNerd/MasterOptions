# Changelog

What changed in each version of Master Options, as you notice it in game. Newest first.
Each version's section is also its release notes on GitHub.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.8.1] - 2026-11-27

### Added

- **/mo > Thanks:** the authors of every addon Master Options works with, the libraries it uses and the data
  behind GearMatic, CheapUpgrades and Mastercraft.

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

[Unreleased]: https://github.com/DMNerd/MasterOptions/compare/v2.8.1...HEAD
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
