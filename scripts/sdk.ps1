# Locate the newest installed Connect IQ SDK and expose $sdk + $monkeyc + $monkeydo.
# Dot-source this from build.ps1 / test.ps1: `. $PSScriptRoot\sdk.ps1`

$sdkRoot = "C:\Users\tomhe\AppData\Roaming\Garmin\ConnectIQ\Sdks"
$sdkDir  = Get-ChildItem $sdkRoot -Directory |
           Sort-Object Name -Descending |
           Select-Object -First 1
if ($null -eq $sdkDir) {
    Write-Error "No Connect IQ SDK found under $sdkRoot"
    exit 1
}

$script:sdk      = $sdkDir.FullName
$script:monkeyc  = Join-Path $sdk "bin\monkeyc.bat"
$script:monkeydo = Join-Path $sdk "bin\monkeydo.bat"

$keyPath = (Resolve-Path "$PSScriptRoot\..\..\developer_key" -ErrorAction SilentlyContinue)
if ($null -eq $keyPath) {
    Write-Error "developer_key not found at $PSScriptRoot\..\..\developer_key"
    exit 1
}
$script:devKey = $keyPath.Path

# Build-output dir. monkeyc's PRG + bitmap-cache writes FAIL under the repo tree
# (C:\Users\...\Documents\Garmin\) — a background scanner/indexer locks the
# freshly-written binary mid-write ("Access is denied" / "The system cannot find
# the file specified", exit 100) — while writes to C:\Temp are clean. So all
# monkeyc -o output goes here; logs + the versions/ artifact archival stay in the
# repo (plain file writes there are unaffected). See reference_toolchain memory.
$script:buildDir = "C:\Temp\wikiwatch-build"
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Force -Path $buildDir | Out-Null }
