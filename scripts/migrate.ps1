# One-time move to Master Options 2.0 (patches became modules of MasterOptions):
#  1. saved data: each old patch's saved-variables file (WTF\Account\<acct>\SavedVariables\MasterOptions_X.lua)
#     is appended to MasterOptions.lua there - the variable names are the same, MasterOptions now declares them.
#     The old file is renamed to .migrated (kept). A variable MasterOptions.lua already has is left as it is.
#  2. the old patch folders in AddOns: zipped to backups\ (outside git), then removed - while one is installed,
#     its module stands aside.
# WoW must be closed: it rewrites the saved-variables files when you log out.
param([string]$Game = "D:\World of Warcraft\_forever_")
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$old = Get-Content (Join-Path $PSScriptRoot "retired.txt") | Where-Object { $_ -and -not $_.StartsWith("#") }

if (Get-Process -Name "Wow" -ErrorAction SilentlyContinue) {
    throw "WoW is running. Close it first: it rewrites the saved-variables files when you log out."
}

# 1. saved data
foreach ($acct in Get-ChildItem (Join-Path $Game "WTF\Account") -Directory) {
    $sv = Join-Path $acct.FullName "SavedVariables"
    if (-not (Test-Path $sv)) { continue }
    $target = Join-Path $sv "MasterOptions.lua"
    $text = if (Test-Path $target) { Get-Content $target -Raw } else { "" }
    $changed = $false
    foreach ($name in $old) {
        $file = Join-Path $sv "$name.lua"
        if (-not (Test-Path $file)) { continue }
        $add = Get-Content $file -Raw
        # only the variables MasterOptions.lua doesn't have yet
        $keep = New-Object System.Text.StringBuilder
        foreach ($block in [regex]::Split($add, "(?m)^(?=[A-Za-z_][A-Za-z0-9_]* = )")) {
            if (-not $block.Trim()) { continue }
            $var = [regex]::Match($block, "^([A-Za-z_][A-Za-z0-9_]*) = ").Groups[1].Value
            if ($var -and $text -match "(?m)^$([regex]::Escape($var)) = ") { Write-Host "  $($acct.Name): $var already in MasterOptions.lua - kept as it is"; continue }
            [void]$keep.Append($block.TrimEnd() + "`r`n")
        }
        if ($keep.Length -gt 0) {
            $text = $text.TrimEnd() + "`r`n" + $keep.ToString()
            $changed = $true
        }
        Rename-Item $file "$name.lua.migrated" -Force
        Write-Host "  $($acct.Name): $name saved data -> MasterOptions.lua"
    }
    if ($changed) {
        if (Test-Path $target) { Copy-Item $target "$target.before-2.0" -Force }
        Set-Content $target $text -NoNewline -Encoding UTF8
    }
}

# 2. the old patch folders
$addons = Join-Path $Game "Interface\AddOns"
$present = $old | Where-Object { Test-Path (Join-Path $addons $_) }
if ($present) {
    $backup = Join-Path $root "backups"
    New-Item -ItemType Directory -Force $backup | Out-Null
    $zip = Join-Path $backup ("old-patch-folders-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".zip")
    Compress-Archive -Path ($present | ForEach-Object { Join-Path $addons $_ }) -DestinationPath $zip
    foreach ($p in $present) { Remove-Item -Recurse -Force (Join-Path $addons $p) -Confirm:$false }
    Write-Host "  old patch folders zipped to $zip and removed: $($present -join ', ')"
}
