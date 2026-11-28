# Copy-paste check (jscpd), as tests and lint: .jscpd.json leaves out the embedded libraries (Libs) and the saved
# variable fixtures; .jscpd-baseline.json holds the duplication that's there on purpose (the tests' small fakes, each
# tailored to its test). Fails on a new clone - in the addon or in a test.
#   pwsh scripts/dedup.ps1              check: any clone not in the baseline fails
#   pwsh scripts/dedup.ps1 -Update      after removing or deliberately keeping a clone: write the baseline again
param([switch]$Update)
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    if ($Update) {
        npx -y jscpd --config .jscpd.json --baseline .jscpd-baseline.json --update-baseline
    } else {
        npx -y jscpd --config .jscpd.json --baseline .jscpd-baseline.json --fail-on-new-clones
    }
    exit $LASTEXITCODE
} finally { Pop-Location }
