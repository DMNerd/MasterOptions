# The other way round from deploy: copies our addon folders from the game's AddOns folder into this repo
# (for changes made there directly). Review with `git diff` afterwards.
param([string]$AddOns = $(if ($IsMacOS) { "/Applications/World of Warcraft/_forever_/Interface/AddOns" } else { "D:\World of Warcraft\_forever_\Interface\AddOns" }))
$ErrorActionPreference = "Stop"
$dst = Join-Path (Split-Path $PSScriptRoot -Parent) "addons"
foreach ($d in Get-ChildItem $dst -Directory) {
    $from = Join-Path $AddOns $d.Name
    if (-not (Test-Path $from)) { Write-Host "skip $($d.Name) (not in AddOns)"; continue }
    Remove-Item -Recurse -Force $d.FullName -Confirm:$false
    Copy-Item -Recurse $from $d.FullName
    Write-Host "pulled $($d.Name)"
}
