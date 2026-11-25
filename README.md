# Master Options

Master Options (`/mo`) and its compatibility patches for the WoW Forever client (Interface 16001).
It is one window for the settings that overlap between installed addons: vendor automation, gathering pins,
stat weights, bag icons, UI style and so on. What makes them work together are modules in
`addons/MasterOptions/Modules/` (until 2.0 they were separate `MasterOptions_<Addon>_<Addon>` addons): each runs only
when the addons it works with are loaded, and can be turned off under /mo > Modules. They only read other addons'
public data and settings; the third-party addons themselves are never edited.

## Layout

| Path | What |
|---|---|
| `addons/MasterOptions/` | The addon as it goes into `Interface\AddOns` |
| `addons/MasterOptions/Modules/` | One file per module: `MasterOptions_Module(name, { needed addons }, function(ADDON) ... end)`, run by `Modules.lua` |
| `tests/` | Sandbox tests: Lua run through lupa with stubbed WoW APIs |
| `tests/fixtures/` | Copies of real SavedVariables and the installed-addon list, used by the tests |
| `scripts/` | test / deploy / pack / pull; `migrate.ps1` (once, WoW closed: the 1.x patches' saved data into MasterOptions) |
| `INSTALL.txt` | Install notes shipped in the pack |

## Workflow

```powershell
.\scripts\test.ps1      # all sandbox tests (first run creates .venv with lupa)
.\scripts\deploy.ps1    # copy addons\* into the game's AddOns folder, then /reload in game
.\scripts\pack.ps1      # dist\MasterOptionsPack.zip
.\scripts\pull.ps1      # copy changes made directly in AddOns back into the repo
.\scripts\lint.ps1      # luacheck (.luacheckrc); first run downloads luacheck 1.2.0 into .tools\ (checksum pinned)
```

Edit in `addons/`, run the tests, deploy, then check in game.

## Releases

GitHub Actions (`.github/workflows/release.yml`) runs the tests on every push to `main` and on pull requests.
To publish a release, bump `## Version:` in `MasterOptions.toc`, commit, then tag that commit with the same version:

```powershell
git tag v2.0.1
git push origin main v2.0.1
```

The workflow checks that the tag matches the `.toc` version, builds the pack, and attaches
`MasterOptions-<version>.zip` to a new GitHub Release with notes generated from the commits.

**Test data:** `tests/fixtures/` holds anonymised settings tables (characters renamed Testchar Alpha / Testchar Beta, realm
"Test Realm", logs and other players' names removed).

## Modules

| Module | Needs | Does |
|---|---|---|
| GearMatic / Baganator | GearMatic, Baganator | Junk coin from GearMatic's sell rules; loadouts as equipment sets |
| GearMatic / Forever | GearMatic | Separate GearMatic data per character (Forever has no realm name) |
| CheapUpgrades / Baganator | CheapUpgrades, Baganator | "+23%" badges on bag slots |
| OpenMapTweaks / Mastercraft | OpenMap_Tweaks, Mastercraft | Mastercraft's node rule filters OpenMap_Tweaks' pins |
| DialogKey / Pawn | DialogKey | Pre-selects the best quest reward (Pawn / GearMatic) |
| Mastercraft / Auctionator | Mastercraft, Auctionator | Scan prices button on Auctionator's page |
| DeleteCheapestItem / Protect | DeleteCheapestItem | Never offers upgrades, sets, tools or needed materials |
| Mastercraft / Keep | Mastercraft | Needed / KEEP items go on GearMatic's never-sell list |
| Mastercraft / VendorSell | Mastercraft | Items Mastercraft marks VENDOR are sold by your junk seller, and get the junk coin |
| Mastercraft / BankMats | Mastercraft | At the bank, guide materials go in; VENDOR / AUCTION items stay in bags |
| OpenMapMiniMap / Border | OpenMap_MiniMap | Square minimap framed with the action bar buttons' border |
| DungeonJournal / OpenMap | ForeverDungeonJournal, OpenMap | Show on Map puts an OpenMap pin; map inside dungeons |
| Mastercraft / FishingView | Mastercraft | Bags, popups and loot rolls stay visible in the fishing view |
| Mastercraft / Chattynator | Mastercraft, Chattynator | Mastercraft's /played request stays out of Chattynator |
| ShortestPathForever / OpenMapMiniMap | ShortestPathForever, OpenMap_MiniMap | Shortest Path's journey goal stays visible on OpenMap's painted minimap |

## Supported addons

Every one is optional: Master Options works with whatever is installed and greys out the rest.

| Addon | What Master Options does with it |
|---|---|
| Pawn | Stat weights that GearMatic, CheapUpgrades, the quest reward pick and Baganator's arrows all follow; Quest reward marker (Pawn's or GearMatic's, not both on one button) |
| **Pawn Forever** | **Strongly recommended with Pawn.** Stat weights made for WoW Forever. Without it everything above uses Pawn's stock Classic scales, and /mo > Problems says so |
| GearMatic | Junk selling, never-sell list, auto-equip, stat weights |
| CheapUpgrades | Upgrade badges and tooltip lines |
| Mastercraft | Gathering nodes, VENDOR / KEEP advice, tooltips, bank materials, fishing view |
| OpenMap, OpenMap_Tweaks, OpenMap_MiniMap | Gathering pins, dungeon entrances, square minimap and border |
| ForeverDungeonJournal | Dungeon maps opened from OpenMap |
| Baganator (with Syndicator) | Junk coin and upgrade arrows in bags, counts on your characters |
| Auctionator | Price tooltips, Mastercraft's scan button |
| Chattynator | Keeps Mastercraft's /played out of chat; Details chat-tab clash check |
| Questie | Town NPC icons, quest icons on nameplates and the target frame |
| BetterBlizzPlates, BetterBlizzFrames | Quest icons, dark mode, Minimap (OpenMap_MiniMap or BetterBlizzFrames' classic minimap, not both), chat clash check |
| DeleteCheapestItem | Protects upgrades, sets, tools and needed materials |
| DialogKey (Numy's DialogKey_Numy) | Pre-selects the best quest reward |
| Details | Chat-tab clash check with Chattynator |
| Sparkles_Forever | Fishing bobber mark (Sparkles / both with Mastercraft's); Problems flags a bobber left unmarked and tracking switching that makes "While tracking" node pins blink |
| ForeverLootRollMover | Works alongside: its moved loot rolls stay visible in Mastercraft's fishing view |
| STBU_OpenMapFlightmap | Works alongside: flight master window only, no overlap with OpenMap's or Questie's map icons |
| WhatsTraining | Works alongside; no shared settings |
| ShortestPathForever | Draws on OpenMap's stitched map itself (OpenMapAPI); its minimap goal kept visible by a module. While TomTom isn't installed it answers TomTom calls, so waypoints from Questie, Mastercraft and OpenMap's Ctrl-click start a journey (its own setting) |

## Client facts worth knowing

- `UnitName("player")` returns first and last name. `GetRealmName()` returns "".
- SavedVariables are written only at logout or `/reload`.
- Mastercraft decorates only GameTooltip and ItemRefTooltip. Its advice can be read through a hidden
  GameTooltip, which is how VendorSell reads it.
