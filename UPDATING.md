# When other addons update

Master Options reads and hooks other addons' settings, functions and frames. An update to one of them can
break a module without any error showing. Do this after every batch of addon updates (CurseForge, Wago, a zip).
It takes about 10 minutes, or about 30 if a changelog touches something we use.

## 1. Run the name check (1 minute)

```sh
pwsh scripts/check-addons.ps1 -Log   # Windows: .\scripts\check-addons.ps1 -Log
```

`-Log` adds the check to [COMPATIBILITY.md](COMPATIBILITY.md): every addon's version, which ones were updated since
the last logged check, and anything missing. You fill in its Notes in step 5.

- `Everything Master Options relies on is still there.` Go to step 2.
- A name is listed as missing: that addon renamed or removed something we use. Find the line in
  `scripts/touchpoints.txt`. The last column says which of our files uses it. Fix that file before you play.
- `not installed (skipped)`: that addon isn't installed, so its module stays off. It only matters if you meant to
  have it installed.

## 2. Read the changelogs (5 to 20 minutes)

For each addon the log marks **updated**, read its changelog from the old version up to the new one. Some ship a
`CHANGELOG.md` or `CHANGE_LOG.md` in their folder. For the rest, look online: the CurseForge file page of the new
version (its "What's new"), or the GitHub releases / CHANGELOG where the addon has a repository (links in the
README's Supported addons).

Look for:

- **Settings renamed or removed**, or a changed default, for a setting that the Master Options window sets.
- **A new feature that does what one of our modules does.** Then both run. Either turn one off, or have the
  module step aside when the addon's own feature is on.
- **Changes to things we draw on or hook:** bag slot icons and junk coins (GearMatic, Baganator), the minimap and
  its buttons (OpenMap_MiniMap, BetterBlizzFrames), map pins (OpenMap, OpenMap_Tweaks), tooltips (Mastercraft),
  Pawn scales.

Addons with no heading in `touchpoints.txt` aren't used by Master Options. Skip their changelogs.

## 3. The AddOns folder (checked in step 1)

The same script also checks the AddOns folder and fails if it finds either of these:

- **`<Addon> won't load: needs <X>`:** a dependency isn't installed. Install it, or delete the addon.
- **`<Addon>: an old patch`:** an addon listed in `scripts/retired.txt`, or one whose `.toc` says
  `## Author: local patch`. A Master Options module does its job now, so both would run. Zip the folder into
  `backups/`, then delete it.

## 4. Check in the game (5 minutes)

Log in, `/reload` once, then:

1. `/mo`, Problems: no new errors or warnings.
2. Open your bags (Baganator): upgrade arrows, BiS skulls and junk coins each show once, not twice.
3. Look at the minimap: the buttons, coordinates and border are where they belong.
4. Open the world map: gathering pins follow Mastercraft's rules, and clicking a dungeon entrance opens
   Dungeon Journal's map.
5. Visit a vendor: junk sells, and nothing on the never-sell list does.

Before a release, also go through **Waiting** in [IN-GAME-CHECKS.md](IN-GAME-CHECKS.md): what each change since the
last release needs a real game session to confirm.

## 5. Record it

In [COMPATIBILITY.md](COMPATIBILITY.md), replace the new entry's Notes line: per updated addon, what changed that
matters to Master Options (or "nothing we use"), and what was done about it (a fix and its version, a module that
can retire, a setting to watch).

In `scripts/touchpoints.txt`, update the version in each checked addon's `# --- <Addon> (<version>)` heading,
and the date in line 3. Add any new names a fix now relies on. Commit.

If a fix was needed: edit in `addons/`, `pwsh scripts/test.ps1`, `pwsh scripts/deploy.ps1`, check in game,
bump `## Version:` in `MasterOptions.toc`, commit, then tag (see Releases in the README).
