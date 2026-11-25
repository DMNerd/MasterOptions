# Lints the addon with luacheck (.luacheckrc at the repo root). Exit code 1 if luacheck finds problems.
# First run downloads luacheck 1.2.0 (the official Windows build) into .tools\ and checks it against a pinned
# SHA-256 before it is ever run.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$version = "1.2.0"
$sha256 = "0F1C69C4D09F1EBB4D8DF14C215E4553E2E639BD4CB7BF3C639B0DAA6198317B"
$exe = Join-Path $root ".tools\luacheck-$version\luacheck.exe"
if ($IsMacOS -or $IsLinux) {
    # macOS/Linux: luacheck from PATH (macOS: brew install luacheck)
    $exe = (Get-Command luacheck -ErrorAction SilentlyContinue).Source
    if (-not $exe) { throw "luacheck not found. Install it: brew install luacheck" }
} else {
if (-not (Test-Path $exe)) {
    Write-Host "Downloading luacheck $version ..."
    New-Item -ItemType Directory -Force (Split-Path $exe) | Out-Null
    Invoke-WebRequest -Uri "https://github.com/lunarmodules/luacheck/releases/download/v$version/luacheck.exe" -OutFile $exe
}
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash
if ($hash -ne $sha256) {
    Remove-Item $exe -Confirm:$false
    throw "luacheck.exe checksum mismatch ($hash) - deleted. Expected $sha256."
}
}
Push-Location $root
try {
    & $exe addons/MasterOptions --config .luacheckrc @args
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
