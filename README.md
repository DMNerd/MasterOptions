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
```

Edit in `addons/`, run the tests, deploy, then check in game.

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

## Client facts worth knowing

- `UnitName("player")` returns first and last name. `GetRealmName()` returns "".
- SavedVariables are written only at logout or `/reload`.
- Mastercraft decorates only GameTooltip and ItemRefTooltip. Its advice can be read through a hidden
  GameTooltip, which is how VendorSell reads it.
