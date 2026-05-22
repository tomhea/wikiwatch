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
