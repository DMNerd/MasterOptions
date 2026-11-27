# Master Options

**A meta settings manager and compatibility layer for WoW Forever addons** (Interface 16001).

The goal: make interesting and useful addons cooperate, for a vanilla-plus experience. The game keeps its classic
feel, and the addons on top of it work as one.

As a settings manager, `/mo` is one window for the settings that overlap between installed addons: vendor
automation, gathering pins, stat weights, bag icons, UI style and so on. As a compatibility layer, its modules make
those addons work together. They live in
`addons/MasterOptions/Modules/` (until 2.0 they were separate `MasterOptions_<Addon>_<Addon>` addons): each runs only
when the addons it works with are loaded, and can be turned off under /mo > Modules. They only read other addons'
public data and settings; the third-party addons themselves are never edited.

## Layout

| Path | What |
|---|---|
| `addons/MasterOptions/` | The addon as it goes into `Interface\AddOns` |
| `addons/MasterOptions/*.lua` | In the `.toc`'s order: `ErrorLog.lua`, `Modules.lua` (the module loader), `Shared.lua` (checks the modules use too), then the window's files sharing one addon table (`local _, MO = ...`): `MasterOptions.lua` (access to each addon, Pawn and spec), `AddonSettings.lua` (Annoying mode, bag icons, profiles, UI style), `Options.lua` (the rows), `Problems.lua` (the health check), `Window.lua` (/mo, the recommended setup), `Startup.lua` (the game's Options page, login) |
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
.\scripts\check-addons.ps1  # after updating other addons: every name we use still there? missing dependencies, old patches?
```

Edit in `addons/`, run the tests, deploy, then check in game.

After other addons update, follow [UPDATING.md](UPDATING.md).

**macOS:** the same scripts run under PowerShell 7. One-time setup: `brew install powershell python luacheck`.
Then run them as `pwsh scripts/test.ps1` and so on. On a Mac, the default AddOns folder is
`/Applications/World of Warcraft/_forever_/Interface/AddOns` (pass `-AddOns` to use another one), and `lint.ps1`
uses the `luacheck` on your PATH.

## Thanks

Master Options only makes these addons work together: everything it connects is their authors' work. Thank you to:

| Addon | By |
|---|---|
| GearMatic | the GearMatic team |
| Mastercraft | Shadowblade |
| Questie and QuestieDB | Aero, Logon, Muehe, TheCrux (BreakBB), Drejjmit, Dyaxler, Cheeq, TechnoHunter, Yttrium and everyone else |
| Baganator, Syndicator, Chattynator | plusmouse |
| Auctionator | plusmouse, Borjamacare |
| CheapUpgrades | KanIkkeKodeUI |
| Pawn | Vger |
| Pawn Forever | turlockmike |
| OpenMap, OpenMap MiniMap | the OpenMap contributors |
| OpenMap Tweaks | Austin |
| Dungeon Journal (ForeverDungeonJournal) | Exehn |
| Spoken, Spoken Bosses | Nucabe |
| Shortest Path Forever | cjber |
| DeleteCheapestItem Reloaded | Sander Vispoel (sandervspl) |
| DialogKey - Numy Edition | Numy (earlier versions: Foxthorn, N01ch, FuriousProgrammer) |
| Sparkles [Forever] | Crogin / CGN |
| BetterBlizzFrames, BetterBlizzPlates | Bodify |
| Details! Damage Meter | Terciob |

And to the libraries Master Options ships with or uses: LibStub (Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel,
joshborke), CallbackHandler (the Ace3 team), LibDataBroker (tekkub), LibDBIcon (funkehdude) and HereBeDragons
(Nevcairiel, through Questie's copy) - and to the WoWSims Forever and Wowhead Forever data GearMatic, CheapUpgrades
and Mastercraft are built on.

## Releases

GitHub Actions (`.github/workflows/release.yml`) runs the tests on every push to `main` and on pull requests.
To publish a release, move what's under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) into a new
`## [X.Y.Z] - date` section (and add its compare link at the bottom), bump `## Version:` in `MasterOptions.toc`,
commit, then tag that commit with the same version:

```powershell
git tag v2.0.1
git push origin main v2.0.1
```

The workflow checks that the tag matches the `.toc` version, builds the pack, and attaches
`MasterOptions-<version>.zip` to a new GitHub Release. Its notes are that version's section of CHANGELOG.md; a tag
without one fails the release, so nothing goes out without notes. The zip carries CHANGELOG.md too.

The same tag also publishes to **CurseForge** (project 1834365): the workflow builds a CurseForge zip with only the
`MasterOptions` folder (`scripts/pack.ps1 -CurseForge`) and uploads it through CurseForge's upload API, with the same
changelog section as its notes, for the WoW Forever game version that matches `## Interface:` (16001 -> 1.60.1).
This needs the repository secret `CF_API_TOKEN` (a CurseForge API token); CurseForge's own packager is left off on
purpose (no `.pkgmeta`).

**Test data:** `tests/fixtures/` holds anonymised settings tables (characters renamed Testchar Alpha / Testchar Beta, realm
"Test Realm", logs and other players' names removed).

## Modules

| Module | Needs | Does |
|---|---|---|
| GearMatic / Baganator | GearMatic, Baganator | Junk coin from GearMatic's sell rules; loadouts as equipment sets |
| GearMatic / Forever | GearMatic | Separate GearMatic data per character (Forever has no realm name) |
| CheapUpgrades / Baganator | CheapUpgrades, Baganator | "+23%" badges on bag slots |
| CheapUpgrades / GearMatic | CheapUpgrades, GearMatic | CheapUpgrades values items with GearMatic's stat weights: a "GearMatic" weights profile per spec (ratings converted to CheapUpgrades' per-1% units), kept up to date and used unless you picked a profile of your own |
| OpenMapTweaks / Mastercraft | OpenMap_Tweaks, Mastercraft | Mastercraft's node rule filters OpenMap_Tweaks' pins |
| DungeonJournal / Upgrades | ForeverDungeonJournal | Dungeon Journal's loot marked: an upgrade arrow and its size (Pawn with Pawn Forever, else GearMatic + CheapUpgrades' size), GearMatic's best-in-slot skull, and a cog on what your Mastercraft guides need |
| DialogKey / Pawn | DialogKey | Pre-selects the best quest reward (Pawn / GearMatic) |
| Mastercraft / Auctionator | Mastercraft, Auctionator | Scan prices button on Auctionator's page |
| DeleteCheapestItem / Protect | DeleteCheapestItem | Never offers upgrades, sets, tools or needed materials |
| Mastercraft / Keep | Mastercraft | Needed / KEEP items go on GearMatic's never-sell list |
| Mastercraft / VendorSell | Mastercraft | Items Mastercraft marks VENDOR are sold by your junk seller, and get the junk coin |
| Mastercraft / RecipeMap | Mastercraft, Questie | Map markers on vendors selling patterns for recipes you haven't learned, the creatures and chests they drop from (specific drops, with GearMatic's chance), and on your profession's trainers when you're near your cap and can train the next rank (Mastercraft's recipe list + QuestieDB, drawn with HereBeDragons) |
| Mastercraft / FarmTour | Mastercraft, ShortestPathForever | Start farming in Mastercraft and ShortestPathForever walks you through the zone's herbs and veins worth it to you (Mastercraft's nodes and rule), nearest first; `/mo farm` (`herbs`, `ores`, `stop`) without Mastercraft's session |
| Mastercraft / BankMats | Mastercraft | At the bank, guide materials go in; VENDOR / AUCTION items stay in bags |
| OpenMapMiniMap / Border | OpenMap_MiniMap | Square minimap framed with the action bar buttons' border |
| ShortestPathForever / OpenMapPins | ShortestPathForever, OpenMap | Clearing the journey to a followed OpenMap pin clears the pin too |
| DungeonJournal / SpokenBosses | ForeverDungeonJournal, Spoken_Bosses | Spoken_Bosses' dungeon and boss stories beside Dungeon Journal's map on the world map |
| DungeonJournal / OpenMap | ForeverDungeonJournal, OpenMap | Show on Map puts an OpenMap pin; map inside dungeons (OpenMap's own switch); Dungeon entrance click: Dungeon Journal's map, its page, or OpenMap's map (written to OpenMap's option too) |
| Mastercraft / FishingView | Mastercraft | Bags, popups and loot rolls stay visible in the fishing view |
| Mastercraft / Chattynator | Mastercraft, Chattynator | Mastercraft's /played request stays out of Chattynator |
| ShortestPathForever / OpenMapMiniMap | ShortestPathForever, OpenMap_MiniMap | Shortest Path's journey goal stays visible on OpenMap's painted minimap |
| GearMatic / SellGuard | GearMatic | GearMatic's gear and low-value selling keeps the never-sell list, materials Mastercraft's guides need, and gear Pawn calls an upgrade or your best for a spec, or that GearMatic rates your best or 2nd best for any spec (GearMatic's own sell guard) |
| GearMatic / SpecKeep | GearMatic | Gear that is your best or 2nd best in GearMatic for any of your specs (off-spec pieces too) is kept from selling and from DeleteCheapestItem. GearMatic alone only looks at the spec you play now; with this, Pawn isn't needed for it |
| NeverSell | any of GearMatic, Mastercraft, DeleteCheapestItem | One never-sell list, the same in GearMatic (never auto-sold), Mastercraft (no VENDOR / AUCTION advice) and DeleteCheapestItem (never offered for deletion): change it in any of them, or with `/mo never <item>` / `/mo never remove <item>`, and all follow. `/mo never` lists it, and /mo > Never sell shows it (add by shift-click, drag or item ID; Remove per item). Keep's and Protect's automatic entries aren't part of it |

## Supported addons

Every one is optional: Master Options works with whatever is installed and greys out the rest.
Links go to each addon's CurseForge page and, where it has a public one, its source repository; "—" means none
was found.

| Addon | Get it | What Master Options does with it |
|---|---|---|
| Pawn | [CurseForge](https://www.curseforge.com/wow/addons/pawn) · — | Stat weights that GearMatic, CheapUpgrades, the quest reward pick and Baganator's arrows all follow; Quest reward marker (Pawn's or GearMatic's, not both on one button) |
| **Pawn Forever** | [CurseForge](https://www.curseforge.com/wow/addons/pawn-forever) · [GitHub](https://github.com/turlockmike/pawn-forever) | **Strongly recommended with Pawn.** Stat weights made for WoW Forever. Without it everything above uses Pawn's stock Classic scales, and /mo > Problems says so |
| GearMatic | [CurseForge](https://www.curseforge.com/wow/addons/gearmatic) · — | Junk selling, never-sell list, auto-equip, stat weights; its spec (from your talents) is the one Pawn and CheapUpgrades follow ("Spec for Pawn and CheapUpgrades") |
| CheapUpgrades | [CurseForge](https://www.curseforge.com/wow/addons/cheap-upgrades) · — | Upgrade badges and tooltip lines |
| Mastercraft | [CurseForge](https://www.curseforge.com/wow/addons/mastercraft-forever) · — | Gathering nodes, VENDOR / KEEP advice, tooltips, bank materials, fishing view |
| OpenMap | [CurseForge](https://www.curseforge.com/wow/addons/openmap) · [GitHub](https://github.com/openmap-world/openmap) | Dungeon entrances, the stitched map our modules draw on |
| OpenMap_Tweaks | [CurseForge](https://www.curseforge.com/wow/addons/openmap-tweaks) · — | Gathering pins (filtered by Mastercraft's node rule) |
| OpenMap_MiniMap | [CurseForge](https://www.curseforge.com/wow/addons/openmap-minimap-the-openmap-companion) · — | Square minimap and its border; Minimap (it or BetterBlizzFrames' classic minimap, not both) |
| ForeverDungeonJournal (Exehn's "DungeonJournal") | [CurseForge](https://www.curseforge.com/wow/addons/dungeonjournal) · — | Dungeon maps opened from OpenMap |
| Spoken_Bosses (Nucabe's "Spoken") | — · — | Its dungeon and boss stories beside Dungeon Journal's map on the world map |
| Baganator | [CurseForge](https://www.curseforge.com/wow/addons/baganator) · [GitHub](https://github.com/TheMouseNest/Baganator) | Junk coin and upgrade arrows in bags |
| Syndicator (Baganator's backend) | [CurseForge](https://www.curseforge.com/wow/addons/syndicator) · [GitHub](https://github.com/TheMouseNest/Syndicator) | Counts on your characters |
| Auctionator | [CurseForge](https://www.curseforge.com/wow/addons/auctionator) · [GitHub](https://github.com/TheMouseNest/Auctionator) | Price tooltips, Mastercraft's scan button |
| Chattynator | [CurseForge](https://www.curseforge.com/wow/addons/chattynator) · [GitHub](https://github.com/TheMouseNest/Chattynator) | Keeps Mastercraft's /played out of chat; Details chat-tab clash check |
| Questie | [CurseForge](https://www.curseforge.com/wow/addons/questie) · [GitHub](https://github.com/Questie/Questie) | Town NPC icons, quest icons on nameplates and the target frame |
| BetterBlizzPlates | [CurseForge](https://www.curseforge.com/wow/addons/betterblizzplates) · — | Quest icons on nameplates |
| BetterBlizzFrames | [CurseForge](https://www.curseforge.com/wow/addons/betterblizzframes) · — | Quest icon on the target frame, dark mode, Minimap (OpenMap_MiniMap or its classic minimap, not both), chat clash check |
| DeleteCheapestItem (Reloaded) | [CurseForge](https://www.curseforge.com/wow/addons/delete-cheapest-item-reloaded) · [GitHub](https://github.com/sandervspl/DeleteCheapestItemReloaded) | Protects upgrades, sets, tools and needed materials |
| DialogKey (Numy Edition, DialogKey_Numy) | [CurseForge](https://www.curseforge.com/wow/addons/dialogkey-numy-edition) · [GitHub](https://github.com/NumyAddon/DialogKey_Numy) | Pre-selects the best quest reward |
| Details | [CurseForge](https://www.curseforge.com/wow/addons/details) · [GitHub](https://github.com/Tercioo/Details-Damage-Meter) | Chat-tab clash check with Chattynator |
| Sparkles_Forever | [CurseForge](https://www.curseforge.com/wow/addons/sparkles) · — | Fishing bobber mark (Sparkles / both with Mastercraft's); Problems flags a bobber left unmarked and tracking switching that makes "While tracking" node pins blink |
| ForeverLootRollMover | [CurseForge](https://www.curseforge.com/wow/addons/foreverlootrollmover) · — | Works alongside: its moved loot rolls stay visible in Mastercraft's fishing view |
| STBU_OpenMapFlightmap ("OpenMap Flightmap \| Forever") | [CurseForge search](https://www.curseforge.com/wow/search?search=OpenMap%20Flightmap) · — | Works alongside: flight master window only, no overlap with OpenMap's or Questie's map icons |
| WhatsTraining ("What's Training?") | [CurseForge](https://www.curseforge.com/wow/addons/whats-training) · [GitHub](https://github.com/fusionpit/WhatsTraining) | Works alongside; no shared settings |
| ShortestPathForever | [CurseForge](https://www.curseforge.com/wow/addons/shortest-path-forever) · [GitHub](https://github.com/cjber/shortest-path-forever) | Draws on OpenMap's stitched map itself (OpenMapAPI); its minimap goal kept visible by a module. While TomTom isn't installed it answers TomTom calls, so waypoints from Questie, Mastercraft and OpenMap's Ctrl-click start a journey (its own setting) |

## Client facts worth knowing

- `UnitName("player")` returns first and last name. `GetRealmName()` returns "".
- SavedVariables are written only at logout or `/reload`.
- Mastercraft decorates only GameTooltip and ItemRefTooltip. Its advice can be read through a hidden
  GameTooltip, which is how VendorSell reads it.

## License

MIT - see [LICENSE](LICENSE).
