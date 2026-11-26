# When other addons update

Master Options reads and hooks other addons' settings, functions and frames. An update to one of them can
break a module without any error showing. Do this after every batch of addon updates (CurseForge, Wago, a zip).
It takes about 10 minutes, or about 30 if a changelog touches something we use.

## 1. Run the name check (1 minute)

```sh
pwsh scripts/check-addons.ps1        # Windows: .\scripts\check-addons.ps1
```

- `Everything Master Options relies on is still there.` Go to step 2.
- A name is listed as missing: that addon renamed or removed something we use. Find the line in
  `scripts/touchpoints.txt`. The last column says which of our files uses it. Fix that file before you play.
- `not installed (skipped)`: that addon isn't installed, so its module stays off. It only matters if you meant to
  have it installed.

## 2. Read the changelogs (5 to 20 minutes)

For each updated addon that Master Options uses (it has a `# --- <Addon> (<version>)` heading in
`scripts/touchpoints.txt`), read its changelog from the version in that heading up to the new one. Most addons
ship a `CHANGELOG.md` or `CHANGE_LOG.md` in their folder.

Look for:

- **Settings renamed or removed**, or a changed default, for a setting that the Master Options window sets.
- **A new feature that does what one of our modules does.** Then both run. Either turn one off, or have the
  module step aside when the addon's own feature is on.
- **Changes to things we draw on or hook:** bag slot icons and junk coins (GearMatic, Baganator), the minimap and
  its buttons (OpenMap_MiniMap, BetterBlizzFrames), map pins (OpenMap, OpenMap_Tweaks), tooltips (Mastercraft),
  Pawn scales.

Addons with no heading in `touchpoints.txt` aren't used by Master Options. Skip their changelogs.

## 3. Check the AddOns folder (2 minutes)

- **Missing dependencies:** an addon whose `## Dependencies` aren't installed doesn't load. Master Options'
  Problems page (`/mo`, Problems) lists addons that didn't load.
- **Old patches still installed:** any folder whose `.toc` says `## Author: local patch`, other than
  `MasterOptions`, is an old patch that a module now replaces. Zip it into `backups/`, then delete the folder.
  The Problems page names the ones it knows about.

## 4. Check in the game (5 minutes)

Log in, `/reload` once, then:

1. `/mo`, Problems: no new errors or warnings.
2. Open your bags (Baganator): upgrade arrows, BiS skulls and junk coins each show once, not twice.
3. Look at the minimap: the buttons, coordinates and border are where they belong.
4. Open the world map: gathering pins follow Mastercraft's rules, and clicking a dungeon entrance opens
   Dungeon Journal's map.
5. Visit a vendor: junk sells, and nothing on the never-sell list does.

## 5. Record it

In `scripts/touchpoints.txt`, update the version in each checked addon's `# --- <Addon> (<version>)` heading,
and the date in line 3. Add any new names a fix now relies on. Commit.

If a fix was needed: edit in `addons/`, `pwsh scripts/test.ps1`, `pwsh scripts/deploy.ps1`, check in game,
bump `## Version:` in `MasterOptions.toc`, commit, then tag (see Releases in the README).
