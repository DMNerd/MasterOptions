# After updating other addons: checks that every name Master Options relies on (scripts\touchpoints.txt) is
# still in the installed copies - functions, frames, settings keys, tooltip texts. A missing one means that
# addon renamed or removed something we use: look closer before playing (and tell Claude which).
# It reads the addons' files only. Exit code 1 if anything is missing.
param([string]$AddOns = "D:\World of Warcraft\_forever_\Interface\AddOns")
$ErrorActionPreference = "Stop"
$list = Join-Path $PSScriptRoot "touchpoints.txt"
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns" }

$entries = Get-Content $list | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object {
    $p = $_ -split "\|", 4
    [pscustomobject]@{ Addon = $p[0].Trim(); Kind = $p[1].Trim(); Name = $p[2].Trim(); Ours = $p[3].Trim() }
}

$missing = @()
$skipped = @()
foreach ($group in ($entries | Group-Object Addon)) {
    $dir = Join-Path $AddOns $group.Name
    if (-not (Test-Path $dir)) { $skipped += $group.Name; continue }
    $toc = Get-ChildItem $dir -Filter *.toc | Select-Object -First 1
    $ver = if ($toc) { (Select-String -Path $toc.FullName -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value } else { "?" }
    $files = Get-ChildItem $dir -Recurse -Include *.lua, *.xml, *.toc -File
    $bad = @()
    foreach ($e in $group.Group) {
        if (-not ($files | Select-String -SimpleMatch -Pattern $e.Name -List | Select-Object -First 1)) { $bad += $e }
    }
    $state = if ($bad.Count) { "$($bad.Count) MISSING" } else { "ok" }
    Write-Host ("{0,-24} {1,-14} {2,3} names  {3}" -f $group.Name, $ver, $group.Count, $state) -ForegroundColor ($(if ($bad.Count) { "Red" } else { "Green" }))
    foreach ($b in $bad) { Write-Host ("    missing {0} '{1}'  (used by {2})" -f $b.Kind, $b.Name, $b.Ours) -ForegroundColor Red }
    $missing += $bad
}
if ($skipped.Count) { Write-Host ("not installed (skipped): " + ($skipped -join ", ")) -ForegroundColor DarkGray }
if ($missing.Count) { Write-Host "`n$($missing.Count) name(s) missing - those addons changed something Master Options uses." -ForegroundColor Red; exit 1 }
Write-Host "`nEverything Master Options relies on is still there." -ForegroundColor Green
