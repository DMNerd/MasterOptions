# Changelog

What changed in each version of Master Options, as you notice it in game. Newest first.
Each version's section is also its release notes on GitHub.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- **Shift-click on an OpenMap pin starts a Shortest Path journey:** on the map, Shift-click plans a journey, but on
  an OpenMap pin (your own, Dungeon Journal's Show on Map pins, shared ones) OpenMap used Shift-click to share the
  pin in chat, and Alt-click deletes it, so no click on a pin could start a journey there. Shift-click on a pin now
  journeys there, named after the pin's note. With a chat box open it still shares the pin, as Shift-click does
  everywhere else in the game. The pin's tooltip says so.

- **OpenMap_MiniMap's "Snap to the screen's edge":** with the map flush against the screen, the action-bar border
  around it went partly off the screen. OpenMap_MiniMap only leaves room for its own thinner border. On a side
  against the screen's edge, the border's line now sits on the screen's edge itself: the map ends at the line, and
  only the faint shading past it is cut off.

## [2.17.0] - 2026-11-27

### Added

- **Questie quest links re-linked in Chattynator** (new module): shift-click a Questie quest link in Chattynator's
  chat and the chat box gets Questie's fresh link (current title and level), as it does in the game's own chat.
  What you typed around it stays.
- **Problems: Sparkles' corpse plates and BetterBlizzPlates.** Sparkles' "Enemy plates at corpses" switches enemy
  nameplates on for a moment, and BetterBlizzPlates saves every change to them as your choice. A logout or reload
  during a fight at a corpse could leave enemy plates on for good. Problems now flags it, only when BetterBlizzPlates
  keeps enemy plates off somewhere, and "Turn off" switches Sparkles' option off.

- **Minimap coordinates "Inside, top right"** (now recommended, applied with this update): just the numbers in the
  minimap's top-right corner, outlined, with no tab or background, and never in the way of the addon buttons round
  the edge. The tab on the frame's edge is still a choice.

### Fixed

- The never-sell lock and Mastercraft's advice icons in Baganator's bags didn't show on items with a cooldown running
  (a Hearthstone, a potion): the cooldown sweep covered them. They're drawn above it now.

### Changed

- **Journey goal visible on OpenMap's minimap** stands aside with OpenMap_MiniMap 1.4.0 and newer, which keeps
  Shortest Path's minimap goal visible itself. It still does the job with older versions.
- **Quest and recipe waypoints** (Shortest Path journey or the game's waypoint) takes effect at once, through
  Shortest Path's own setting. Before, it took a reload.

## [2.16.0] - 2026-11-27

### Added

- **Selling what Mastercraft says to DISENCHANT, when you can't** (sell mode "Goods and gear"): a soulbound piece
  whose advice is DISENCHANT is sold at the vendor when this character has no Enchanting. It can't go to an
  enchanter alt or the auction house. Upgrades, set and loadout pieces and the never-sell list still keep it, and
  `/mo vendor` lists these too.
- **The never-sell list says when it followed you.** Put an item on (or take it off) in GearMatic's, Mastercraft's or
  DeleteCheapestItem's own list, and Master Options says in chat that the other loaded addons have it too, for
  example: "[item] put on the never-sell list in GearMatic - also in Mastercraft and DeleteCheapestItem."

### Fixed

- **Minimap border corners:** they showed a notch, because the border's edges crossed there and their lines don't
  meet. All four are now the border's own rounded corners, and the zone bar's background follows the curve. The
  coordinates plate is rounded on its outer side too.
- **The coordinates plate no longer sits on a minimap button.** OpenMap_MiniMap places other addons' buttons round
  the map's edge. Where one is in the plate's way, the plate moves along its edge to the nearest free place, within
  the border's corners. With no free place it stays where you chose.
- A bag slot with the junk coin no longer also shows Mastercraft's advice icon, whatever the advice: the coin already
  says it goes at the next vendor. Before, only VENDOR's icon stepped aside, so the DISENCHANT pieces sold under
  the rule above showed two icons.

## [2.15.2] - 2026-11-27

### Changed

- **Farming tours use ShortestPathForever's calmer tour line** (new in its 1.49): a solid line with softly rounded
  corners that shows the leg you're on and the next four, instead of every leg to every node. With an older
  ShortestPathForever the tour starts as before.

## [2.15.1] - 2026-11-27

### Fixed

- **ShortestPathForever 1.49.1:** the journey's goal at the minimap's rim, which points the way, stays visible again
  next to the trip's OpenMap pin. Shortest Path no longer says when its goal is at the rim, so Master Options tells
  by how it draws it there: faded. Older versions still work as before.

## [2.15.0] - 2026-11-27

### Added

- **Problems: a module that didn't start.** If every addon a module needs is installed, enabled and loaded, but
  the module still didn't start, `/mo > Problems` says so. That means the addon loaded after Master Options:
  Master Options' own mistake, to report. This is how the Spoken story module sat unnoticed until 2.14.1.

### Changed

- **One way to place and clear OpenMap pins.** Dungeon Journal's Show on Map pins and Shortest Path's trip pins are
  now placed, found and removed by the same code, with the same note format.
- **Fixed with it:** a Show on Map pin cleared by Dungeon Journal now also drops OpenMap's sketches on it and the
  trip module's record of it. The trip module no longer edits the Show on Map module's saved data.

## [2.14.1] - 2026-11-27

### Fixed

- **Spoken's dungeon and boss stories on Dungeon Journal's map never showed**, since that module came in 2.7. It
  needs Spoken_Bosses, which loaded after Master Options (it wasn't one of Master Options' optional dependencies),
  so the module never started. That is also why `/mo story` said "no command". A test now makes sure every addon a
  module needs loads before Master Options.

## [2.14.0] - 2026-11-27

### Added

- **`/mo help`** lists every `/mo` command there is now. Each module brings its own (`never`, `vendor`, `story`,
  `whispers`, `farm`), so a module turned off takes its command with it. A word that isn't a command now says
  so, instead of opening the window.

### Changed

- **Code organisation** (nothing changes in game):
  - All of Master Options' Pawn code is in one file, `Pawn.lua`. The shared code modules use no longer knows Pawn;
    the modules that need it ask Master Options' Pawn file.
  - The recommended setup, the same choices on every character and which rows are available moved from the
    window's file to `Settings.lua`.
  - The addon problem checks are one named check each. One that fails no longer stops the others: it shows as a
    problem row instead.

## [2.13.0] - 2026-11-27

### Changed

- **Modules reorganised**, each doing one job (/mo > Modules lists them):
  - **Mastercraft's advice remembered** (new, split from Sell what Mastercraft says to vendor): what Mastercraft
    advises for each item, for the junk coins and the advice icons. The icons now also work with VENDOR selling's
    module turned off.
  - **Mastercraft's junk coin and advice icons in bags** (new, split from the same): Baganator's "Mastercraft" junk
    coin, the advice icons, and GearMatic's badges kept off while they show.
  - **Dungeon Journal's Show on Map as an OpenMap pin** (new, split from Dungeon Journal on OpenMap's map, now
    "Dungeon Journal's map inside dungeons").
  - The module list's titles, tips and versions are now kept in one place.
- **One reader for Mastercraft's tooltip.** Mastercraft's advice was read separately by the selling, keep and
  bank modules, each its own way. Now one reader serves all three, once per tooltip.

### Fixed

- With Mastercraft's tooltip lines turned off (its Settings > Modules), every hover made Master Options forget what
  Mastercraft had said about that item.
- An item you track in Mastercraft now counts as KEEP for selling and the bag icons (the bank module already knew).

### Performance

- **DeleteCheapestItem protection** asks Pawn and GearMatic only about gear it hasn't seen yet. Before, it asked
  about every piece on every bag update while looting.
- **Baganator redraws ask much less of each bag slot:**
  - the junk coin checks Mastercraft's advice first and reuses the slot data Baganator already has
  - the Pawn / GearMatic keep check is cached until your bags, gear, level or talents change
  - CheapUpgrades' badges are cached until CheapUpgrades re-evaluates
  - Mastercraft's tracker list is read once per change, not per slot
- **Bags redraw once** when several modules change things at once, and once at the end of the background advice
  reads (not after every batch).
- **Shortest Path:** its journey pin check no longer walks OpenMap's pin list every frame, and the world map's
  pins are no longer listed twice a second. The minimap goal waits for a journey instead of checking once a second.
- **Smaller savings:**
  - the `/mo` window refreshes only the rows on screen, and nothing while it's closed
  - the minimap button's tooltip counts problems once per 10 s
  - Dungeon Journal's loot marks ignore item-info events while its window is closed
  - addon whisper bursts are recorded once
  - the dungeon chooser listens for clicks only while it's open
  - another addon's error spam no longer makes Master Options read a call stack for every error

## [2.12.6] - 2026-11-27

### Fixed

- A dungeon opened from its entrance still showed the zone's story (2.12.5 only caught a quick click). On OpenMap's
  map every click picks the zone under it in Spoken Places, the entrance click too, and so does a click anywhere on
  Dungeon Journal's map, which covers that zone. While that map is up, the story we showed (the dungeon's, or the
  boss's you clicked) now goes back after any such pick.

### Added

- `/mo story`: what happened the last time Dungeon Journal's map went up on the world map. It shows the dungeon,
  Spoken's instance for it, the map, and whether a story was shown.

## [2.12.5] - 2026-11-27

### Fixed

- Clicking a dungeon entrance on OpenMap's map showed the story of the zone you clicked in, not the dungeon's. The
  same click also picks that zone's story in Spoken Places, after the dungeon's went up. The dungeon's story is now
  put back.
- The dungeon map opened by an entrance click stayed on top when you navigated the world map with its navigation
  bar (or opened another zone). It now closes when the world map moves to another map.

## [2.12.4] - 2026-11-27

### Fixed

- Opening a dungeon's map from Dungeon Journal didn't always bring up that dungeon's story in Spoken's map panel.
  The zone's story (or none) showed instead. Spoken Places drops a story put up from outside when the world map
  changes, which happens while Dungeon Journal opens a dungeon, and Master Options still counted that story as
  showing. After a map change it's now put back while Dungeon Journal's map is up.

## [2.12.3] - 2026-11-27

### Fixed

- GearMatic's badges still came back next to Mastercraft's advice icons. 2.12.1 and 2.12.2 turned them off only when
  the advice row was switched on, but Baganator had already switched the icons on by itself, so that never ran. Now,
  at every login while the advice icons show, GearMatic's vendor $, auction price tag and disenchant marker are
  turned off.

## [2.12.2] - 2026-11-27

### Fixed

- Double icons in the bags came back a while after a reload. Besides its vendor $, GearMatic has an auction-house
  price tag and a disenchant marker, which appear once it has worked out prices. **Mastercraft advice in bags** now
  turns all three off, also with this update.

## [2.12.1] - 2026-11-27

### Changed

- One verdict per bag slot: **Mastercraft advice in bags** turns GearMatic's vendor badge off. That happens with this
  update too, and turning the badge back on takes the advice icons away. The VENDOR bag isn't shown where the junk
  coin already says the item goes at the next vendor.

## [2.12.0] - 2026-11-27

### Added

- **Mastercraft advice in bags** (Bags, Baganator): Mastercraft's advice as an icon in the top-right corner of each
  bag slot. A green tick means KEEP (also "keep some for a guide"), the vendor's bag means VENDOR, the auctioneer
  means AUCTION, and the disenchant icon means DISENCHANT. The advice is learned from item tooltips, and new items
  are read in the background, now even with VENDOR selling off.
- **Never-sell lock in bags** (Bags, Baganator): a lock on every item on the never-sell list. It's first in the
  top-right corner, so it wins over GearMatic's skull and the advice icon.
- Both icons can also be moved or turned off in Baganator's own icon settings.

## [2.11.1] - 2026-11-27

### Fixed

- Questie's "A frame is lacking the GetIconScale function for resizing!" error when the world map changes zone.
  Questie resizes every icon in its map-pin library, and our recipe vendor and trainer markers live there too. It
  now leaves ours alone (the same kind of fix as 2.9.1's "iconData is nil").

## [2.11.0] - 2026-11-27

### Added

- **Grey out junk in bags** (Bags, Baganator), recommended and switched on with this update: every item with the
  junk coin shows in grey, so what the next vendor visit sells (also what Mastercraft says to VENDOR) stands out.
  Baganator's own "Grey out junk" setting. Takes effect after a `/reload`.

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

[Unreleased]: https://github.com/DMNerd/MasterOptions/compare/v2.17.0...HEAD
[2.17.0]: https://github.com/DMNerd/MasterOptions/compare/v2.16.0...v2.17.0
[2.16.0]: https://github.com/DMNerd/MasterOptions/compare/v2.15.2...v2.16.0
[2.15.2]: https://github.com/DMNerd/MasterOptions/compare/v2.15.1...v2.15.2
[2.15.1]: https://github.com/DMNerd/MasterOptions/compare/v2.15.0...v2.15.1
[2.15.0]: https://github.com/DMNerd/MasterOptions/compare/v2.14.1...v2.15.0
[2.14.1]: https://github.com/DMNerd/MasterOptions/compare/v2.14.0...v2.14.1
[2.14.0]: https://github.com/DMNerd/MasterOptions/compare/v2.13.0...v2.14.0
[2.13.0]: https://github.com/DMNerd/MasterOptions/compare/v2.12.6...v2.13.0
[2.12.6]: https://github.com/DMNerd/MasterOptions/compare/v2.12.5...v2.12.6
[2.12.5]: https://github.com/DMNerd/MasterOptions/compare/v2.12.4...v2.12.5
[2.12.4]: https://github.com/DMNerd/MasterOptions/compare/v2.12.3...v2.12.4
[2.12.3]: https://github.com/DMNerd/MasterOptions/compare/v2.12.2...v2.12.3
[2.12.2]: https://github.com/DMNerd/MasterOptions/compare/v2.12.1...v2.12.2
[2.12.1]: https://github.com/DMNerd/MasterOptions/compare/v2.12.0...v2.12.1
[2.12.0]: https://github.com/DMNerd/MasterOptions/compare/v2.11.1...v2.12.0
[2.11.1]: https://github.com/DMNerd/MasterOptions/compare/v2.11.0...v2.11.1
[2.11.0]: https://github.com/DMNerd/MasterOptions/compare/v2.10.4...v2.11.0
[2.10.4]: https://github.com/DMNerd/MasterOptions/compare/v2.10.3...v2.10.4
[2.10.3]: https://github.com/DMNerd/MasterOptions/compare/v2.10.2...v2.10.3
[2.10.2]: https://github.com/DMNerd/MasterOptions/compare/v2.10.1...v2.10.2
[2.10.1]: https://github.com/DMNerd/MasterOptions/compare/v2.10.0...v2.10.1
[2.10.0]: https://github.com/DMNerd/MasterOptions/compare/v2.9.3...v2.10.0
[2.9.3]: https://github.com/DMNerd/MasterOptions/compare/v2.9.2...v2.9.3
[2.9.2]: https://github.com/DMNerd/MasterOptions/compare/v2.9.1...v2.9.2
[2.9.1]: https://github.com/DMNerd/MasterOptions/compare/v2.9.0...v2.9.1
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
