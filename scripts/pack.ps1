# Builds dist\MasterOptionsPack.zip: every addon folder plus INSTALL.txt.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root "dist"
$stage = Join-Path $dist "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage -Confirm:$false }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $root "INSTALL.txt") $stage
Get-ChildItem (Join-Path $root "addons") -Directory | % { Copy-Item -Recurse $_.FullName (Join-Path $stage $_.Name) }
$zip = Join-Path $dist "MasterOptionsPack.zip"
if (Test-Path $zip) { Remove-Item $zip -Confirm:$false }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
Remove-Item -Recurse -Force $stage -Confirm:$false
Write-Host "built $zip"
