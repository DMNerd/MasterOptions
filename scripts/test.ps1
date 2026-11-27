# Runs every sandbox test (Lua via lupa, with stubbed WoW APIs) against the addons in this repo.
# First run creates .venv and installs lupa. Exit code 1 if any test fails.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$py = if ($IsMacOS -or $IsLinux) { Join-Path $root ".venv/bin/python" } else { Join-Path $root ".venv\Scripts\python.exe" }
if (-not (Test-Path $py)) {
    Write-Host "Creating .venv ..."
    # macOS: prefer Homebrew python3 (the system one is 3.9); Windows: python
    $base = if ($IsMacOS -or $IsLinux) { (Get-Command python3.13, python3.12, python3 -ErrorAction SilentlyContinue | Select-Object -First 1).Source } else { "python" }
    & $base -m venv (Join-Path $root ".venv")
    & $py -m pip install --quiet lupa==2.8
}
$a = Join-Path $root "addons"
$t = Join-Path $root "tests"
function F($addon) { Join-Path $a ("MasterOptions\Modules\" + ($addon -replace "^MasterOptions_","") + ".lua") }
$mo = Join-Path $a "MasterOptions\MasterOptions.lua"

$tests = @(
    @("syntax: MasterOptions",       "check.py",       @($mo)),
    @("syntax: modules",             "check_modules.py", @((Join-Path $a "MasterOptions\Modules"))),
    @("syntax: core files",          "check_modules.py", @((Join-Path $a "MasterOptions"))),
    @("MasterOptions window + setup", "test_mo.py",     @($mo)),
    @("module loader",               "test_modules.py", @((Join-Path $a "MasterOptions\Modules.lua"))),
    @("error log",                   "test_errlog.py", @((Join-Path $a "MasterOptions\ErrorLog.lua"))),
    @("Pawn scales / stat weights",  "test_pawn.py",   @($mo)),
    @("recommended defaults: upgrade", "test_defaults.py", @($mo)),
    @("GearMatic_Forever",           "test_forever.py", @((Join-Path $t "fixtures\GearMatic_sv_copy.lua"), (F "MasterOptions_GearMatic_Forever"))),
    @("Mastercraft_Keep",            "test_keep.py",   @((F "MasterOptions_Mastercraft_Keep"))),
    @("DeleteCheapestItem_Protect",  "test_protect.py", @((F "MasterOptions_Mastercraft_Keep"), (F "MasterOptions_DeleteCheapestItem_Protect"))),
    @("Mastercraft_VendorSell",      "test_vsell.py",  @((F "MasterOptions_Mastercraft_VendorSell"))),
    @("Mastercraft_BankMats",        "test_bank.py",   @((F "MasterOptions_Mastercraft_BankMats"))),
    @("Mastercraft_FarmTour (farming tours)", "test_farmtour.py", @((F "MasterOptions_Mastercraft_FarmTour"))),
    @("OpenMapMiniMap_Border",       "test_border.py", @((F "MasterOptions_OpenMapMiniMap_Border"))),
    @("DungeonJournal_OpenMap pins", "test_djpin.py",  @((F "MasterOptions_DungeonJournal_OpenMap"))),
    @("DungeonJournal_OpenMap map",  "test_dmap.py",   @((F "MasterOptions_DungeonJournal_OpenMap"))),
    @("DungeonJournal_Upgrades (loot marks)", "test_djupgrades.py", @((F "MasterOptions_DungeonJournal_Upgrades"))),
    @("OpenMapTweaks_Mastercraft stitched map", "test_omtstitch.py", @((F "MasterOptions_OpenMapTweaks_Mastercraft"))),
    @("ShortestPathForever_OpenMapMiniMap", "test_spfgoal.py", @((F "MasterOptions_ShortestPathForever_OpenMapMiniMap"))),
    @("NeverSell (shared never-sell list)", "test_neversell.py", @((F "MasterOptions_NeverSell"))),
    @("GearMatic_SellGuard",          "test_sellguard.py", @((F "MasterOptions_GearMatic_SellGuard"))),
    @("GearMatic_SpecKeep (off-spec gear kept)", "test_speckeep.py", @((F "MasterOptions_GearMatic_SpecKeep"))),
    @("CheapUpgrades_GearMatic (weights profile)", "test_cugm.py", @((F "MasterOptions_CheapUpgrades_GearMatic"))),
    @("Mastercraft_FishingView",     "test_fish.py",   @((F "MasterOptions_Mastercraft_FishingView"))),
    @("Mastercraft_Chattynator",     "test_played.py", @((F "MasterOptions_Mastercraft_Chattynator")))
)

# macOS/Linux: run Lua in the C locale, as WoW does. Under a UTF-8 locale macOS treats bytes 0x80-0x9F as
# %c (control) in Lua patterns, which breaks multi-byte characters such as long dashes.
if ($IsMacOS -or $IsLinux) { $env:LC_ALL = "C"; $env:PYTHONCOERCECLOCALE = "0" }
$failed = @()
foreach ($x in $tests) {
    $name, $script, $args2 = $x
    $out = & $py -I (Join-Path $t $script) @args2 2>&1 | Out-String
    $bad = $LASTEXITCODE -ne 0 -or $out -match "Traceback|ERRORS: [1-9]"
    if ($bad) { $failed += $name; Write-Host "FAIL  $name" -ForegroundColor Red; Write-Host $out }
    else { Write-Host "ok    $name" -ForegroundColor Green; if ($env:VERBOSE_TESTS) { Write-Host $out } }
}
if ($failed.Count) { Write-Host "`n$($failed.Count) failed: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "`nAll $($tests.Count) passed." -ForegroundColor Green
