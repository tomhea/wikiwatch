# Build StorageProbe.prg for sideloading to a real Venu 2 / Venu 3.
# Outputs to C:\Temp (monkeyc can't write under the Documents\Garmin tree — a
# scanner/indexer locks the freshly-written binary; see wikiwatch reference_toolchain).
param([string]$Device = "venu2")
$ErrorActionPreference = "Stop"
$sdkRoot = "C:\Users\tomhe\AppData\Roaming\Garmin\ConnectIQ\Sdks"
$sdk = (Get-ChildItem $sdkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
$monkeyc = Join-Path $sdk "bin\monkeyc.bat"
$devKey  = "C:\Users\tomhe\Documents\Garmin\developer_key"
$proj = $PSScriptRoot
$out  = "C:\Temp\StorageProbe.prg"
& $monkeyc -d $Device -f (Join-Path $proj "monkey.jungle") -o $out -y $devKey -w
if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
Write-Host "BUILD OK -> $out"
