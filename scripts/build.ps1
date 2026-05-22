# Build the release .prg into bin/wikiwatch.prg.
# Exit 0 on success, non-zero on any monkeyc warning or error (-w).
param(
    [string]$Device = "venu2"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj = Resolve-Path "$PSScriptRoot\.."
$out  = Join-Path $proj "bin\wikiwatch.prg"
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null

Push-Location $proj
try {
    & $monkeyc -d $Device -f monkey.jungle -o $out -y $devKey -w
    if ($LASTEXITCODE -ne 0) {
        Write-Error "monkeyc failed with exit $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Host "BUILD OK -> $out"
}
finally {
    Pop-Location
}
