# After updating other addons: checks that every name Master Options relies on (scripts\touchpoints.txt) is
# still in the installed copies - functions, frames, settings keys, tooltip texts. A missing one means that
# addon renamed or removed something we use: look closer before playing (and tell Claude which).
# Then the AddOns folder itself: addons whose dependencies aren't installed (WoW won't load them), and old patches
# a Master Options module replaces (retired.txt, or a .toc by "local patch") - zip those into backups\ and delete.
# It reads the addons' files only. Exit code 1 if anything is found.
# -Log: also adds this check to COMPATIBILITY.md (newest first) - every addon's version, which changed since the last
# logged check, what's missing - with a Notes line to fill in (what changed in them, what Master Options did about it).
param(
    [string]$AddOns = $(if ($IsMacOS) { "/Applications/World of Warcraft/_forever_/Interface/AddOns" } else { "D:\World of Warcraft\_forever_\Interface\AddOns" }),
    [switch]$Log
)
$ErrorActionPreference = "Stop"
$list = Join-Path $PSScriptRoot "touchpoints.txt"
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns" }

$entries = Get-Content $list | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object {
    $p = $_ -split "\|", 4
    [pscustomobject]@{ Addon = $p[0].Trim(); Kind = $p[1].Trim(); Name = $p[2].Trim(); Ours = $p[3].Trim() }
}

$missing = @()
$skipped = @()
$rows = @() # (for -Log: name, version, state)
foreach ($group in ($entries | Group-Object Addon)) {
    $dir = Join-Path $AddOns $group.Name
    if (-not (Test-Path $dir)) { $skipped += $group.Name; continue }
    $toc = Get-ChildItem $dir -Filter *.toc | Select-Object -First 1
    $m = if ($toc) { Select-String -Path $toc.FullName -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1 }
    $ver = if ($m) { $m.Matches[0].Groups[1].Value } else { "?" } # (some addons' .toc has no Version line)
    $files = Get-ChildItem $dir -Recurse -Include *.lua, *.xml, *.toc -File
    $bad = @()
    foreach ($e in $group.Group) {
        if (-not ($files | Select-String -SimpleMatch -Pattern $e.Name -List | Select-Object -First 1)) { $bad += $e }
    }
    $state = if ($bad.Count) { "$($bad.Count) MISSING" } else { "ok" }
    $rows += [pscustomobject]@{ Addon = $group.Name; Version = $ver.Trim(); State = $state; Missing = ($bad | ForEach-Object { $_.Name }) -join ", " }
    Write-Host ("{0,-24} {1,-14} {2,3} names  {3}" -f $group.Name, $ver, $group.Count, $state) -ForegroundColor ($(if ($bad.Count) { "Red" } else { "Green" }))
    foreach ($b in $bad) { Write-Host ("    missing {0} '{1}'  (used by {2})" -f $b.Kind, $b.Name, $b.Ours) -ForegroundColor Red }
    $missing += $bad
}
if ($skipped.Count) { Write-Host ("not installed (skipped): " + ($skipped -join ", ")) -ForegroundColor DarkGray }

# --- the AddOns folder
$folders = Get-ChildItem $AddOns -Directory
$installed = @{}
foreach ($f in $folders) { $installed[$f.Name] = $true }
$retired = Get-Content (Join-Path $PSScriptRoot "retired.txt") | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object { $_.Trim() }
$noDeps = @()
$oldPatches = @()
foreach ($f in $folders) {
    # the .toc WoW reads: <folder>.toc, else the first one (flavour .tocs such as _Mainline list the same deps)
    $toc = Join-Path $f.FullName "$($f.Name).toc"
    if (-not (Test-Path $toc)) { $toc = (Get-ChildItem $f.FullName -Filter *.toc | Select-Object -First 1).FullName }
    if (-not $toc) { continue }
    $lines = Get-Content $toc
    $deps = @()
    foreach ($l in $lines) {
        if ($l -match '^##\s*(Dependencies|RequiredDeps|Dep[0-9]*)\s*:\s*(.*)$') {
            $deps += $Matches[2] -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
    }
    $lacking = @($deps | Select-Object -Unique | Where-Object { -not $installed[$_] })
    if ($lacking.Count) { $noDeps += [pscustomobject]@{ Addon = $f.Name; Lacking = $lacking -join ", " } }
    $author = [string](($lines | Where-Object { $_ -match '^##\s*Author\s*:' } | Select-Object -First 1) -replace '^##\s*Author\s*:\s*', '')
    if ($f.Name -ne "MasterOptions" -and (($retired -contains $f.Name) -or ($author.Trim() -match '^local( patch)?$'))) { $oldPatches += $f.Name }
}
foreach ($d in $noDeps) { Write-Host ("{0} won't load: needs {1}, which isn't installed" -f $d.Addon, $d.Lacking) -ForegroundColor Red }
foreach ($o in $oldPatches) { Write-Host ("{0}: an old patch - a Master Options module does its job now. Zip it into the backups folder and delete it." -f $o) -ForegroundColor Red }
if (-not ($noDeps.Count -or $oldPatches.Count)) { Write-Host "AddOns folder: every dependency installed, no old patches." -ForegroundColor Green }

if ($Log) {
    $file = Join-Path (Split-Path $PSScriptRoot) "COMPATIBILITY.md"
    $head = "# Compatibility log`n`nEvery update check (``scripts\check-addons.ps1 -Log``, see UPDATING.md), newest first: the versions of the`naddons Master Options works with, which changed since the check before, and what was done about it.`n"
    $text = if (Test-Path $file) { [IO.File]::ReadAllText($file) } else { $head }
    # the versions in the newest entry (the first table in the file)
    $before = @{}
    $firstEntry = [regex]::Match($text, '(?ms)^## .*?(?=^## |\z)')
    if ($firstEntry.Success) {
        foreach ($mt in [regex]::Matches($firstEntry.Value, '(?m)^\| ([^|]+?) \| ([^|]+?) \|')) {
            $before[$mt.Groups[1].Value.Trim()] = $mt.Groups[2].Value.Trim()
        }
    }
    $toc = Join-Path (Split-Path $PSScriptRoot) "addons\MasterOptions\MasterOptions.toc"
    $mo = ((Select-String -Path $toc -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1).Matches[0].Groups[1].Value).Trim()
    $lines = @("## $(Get-Date -Format 'yyyy-MM-dd') - Master Options $mo", "", "| Addon | Version | Since the last check | Names |", "|---|---|---|---|")
    foreach ($r in $rows) {
        $was = $before[$r.Addon]
        $since = if (-not $firstEntry.Success -or -not $was) { "-" } elseif ($was -ne $r.Version) { "**updated** (was $was)" } else { "same" }
        $names = if ($r.Missing) { "$($r.State): $($r.Missing)" } else { $r.State }
        $lines += "| $($r.Addon) | $($r.Version) | $since | $names |"
    }
    if ($skipped.Count) { $lines += "", "Not installed (skipped): $($skipped -join ', ')." }
    $lines += "", "**Notes:** (what changed in the updated addons, what Master Options did about it)", ""
    $entry = ($lines -join "`n") + "`n"
    $at = $text.IndexOf("`n## ")
    $text = if ($at -ge 0) { $text.Substring(0, $at + 1) + $entry + $text.Substring($at + 1) } else { $text.TrimEnd() + "`n`n" + $entry }
    [IO.File]::WriteAllText($file, $text, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "`nLogged in COMPATIBILITY.md - fill in its Notes line." -ForegroundColor Cyan
}

if ($missing.Count) { Write-Host "`n$($missing.Count) name(s) missing - those addons changed something Master Options uses." -ForegroundColor Red }
if ($missing.Count -or $noDeps.Count -or $oldPatches.Count) { exit 1 }
Write-Host "`nEverything Master Options relies on is still there." -ForegroundColor Green
