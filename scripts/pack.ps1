# Builds dist\MasterOptionsPack.zip: every addon folder plus INSTALL.txt and CHANGELOG.md (the GitHub Release asset).
# -CurseForge: dist\MasterOptions-curseforge.zip instead - only the MasterOptions folder at the top, nothing else:
# the CurseForge app unpacks a file straight into the AddOns folder.
param([switch]$CurseForge)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root "dist"
$stage = Join-Path $dist "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage -Confirm:$false }
New-Item -ItemType Directory -Force $stage | Out-Null
if ($CurseForge) {
    Copy-Item -Recurse (Join-Path $root "addons\MasterOptions") (Join-Path $stage "MasterOptions")
    $zip = Join-Path $dist "MasterOptions-curseforge.zip"
} else {
    Copy-Item (Join-Path $root "INSTALL.txt") $stage
    Copy-Item (Join-Path $root "CHANGELOG.md") $stage
    Get-ChildItem (Join-Path $root "addons") -Directory | ForEach-Object { Copy-Item -Recurse $_.FullName (Join-Path $stage $_.Name) }
    $zip = Join-Path $dist "MasterOptionsPack.zip"
}
if (Test-Path $zip) { Remove-Item $zip -Confirm:$false }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
Remove-Item -Recurse -Force $stage -Confirm:$false
Write-Host "built $zip"
