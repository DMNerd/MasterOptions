# Copies the addons in this repo into the game's AddOns folder (replacing those folders only).
# Then /reload in game. Pass -AddOns to use another folder.
param([string]$AddOns = $(if ($IsMacOS) { "/Applications/World of Warcraft/_forever_/Interface/AddOns" } else { "D:\World of Warcraft\_forever_\Interface\AddOns" }))
$ErrorActionPreference = "Stop"
$src = Join-Path (Split-Path $PSScriptRoot -Parent) "addons"
# (once: the old patch addons' saved data into MasterOptions, their folders out of AddOns - see migrate.ps1)
$game = Split-Path (Split-Path $AddOns -Parent) -Parent
$pending = Get-Content (Join-Path $PSScriptRoot "retired.txt") | Where-Object { $_ -and -not $_.StartsWith("#") } | Where-Object { (Test-Path (Join-Path $AddOns $_)) -or (Get-ChildItem (Join-Path $game "WTF\Account\*\SavedVariables\$_.lua") -ErrorAction SilentlyContinue) }
if ($pending) { & (Join-Path $PSScriptRoot "migrate.ps1") -Game $game }
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns" }
foreach ($d in Get-ChildItem $src -Directory) {
    $dest = Join-Path $AddOns $d.Name
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest -Confirm:$false }
    Copy-Item -Recurse $d.FullName $dest
    Write-Host "deployed $($d.Name)"
}
