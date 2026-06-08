# Build the CapProbe .prg for sideloading to a real Venu 2 / Venu 3.
#   .\build.ps1            -> ships pointing at https://wikiwatch.tomhe.app/probe/
#   .\build.ps1 -BaseUrl "https://127.0.0.1:8099/probe/"  -> sim test against a local fixture
param(
    [string]$Device = "venu2",
    [string]$BaseUrl = ""   # empty = leave the shipped wikiwatch.tomhe.app URL
)
$ErrorActionPreference = "Stop"

$sdkRoot = "C:\Users\tomhe\AppData\Roaming\Garmin\ConnectIQ\Sdks"
$sdk = (Get-ChildItem $sdkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
$monkeyc = Join-Path $sdk "bin\monkeyc.bat"
$devKey  = "C:\Users\tomhe\Documents\Garmin\developer_key"

$proj = $PSScriptRoot
$view = Join-Path $proj "source\ProbeView.mc"
# Output to C:\Temp: monkeyc can't write under the Documents\Garmin tree (a
# scanner/indexer locks the freshly-written binary — see wikiwatch reference_toolchain).
$prg  = "C:\Temp\CapProbe.prg"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

$backup = $null
try {
    if ($BaseUrl -ne "") {
        $backup = [System.IO.File]::ReadAllText($view)
        $patched = $backup -replace 'const BASE = "https://wikiwatch\.tomhe\.app/probe/";',
            ('const BASE = "' + $BaseUrl + '";')
        if ($patched -eq $backup) { throw "BASE anchor not found in ProbeView.mc" }
        [System.IO.File]::WriteAllText($view, $patched, [System.Text.UTF8Encoding]::new($false))
        Write-Host "build: BASE overridden -> $BaseUrl"
    }
    & $monkeyc -d $Device -f (Join-Path $proj "monkey.jungle") -o $prg -y $devKey -w
    if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
    Write-Host "BUILD OK -> $prg"
}
finally {
    if ($backup -ne $null) { [System.IO.File]::WriteAllText($view, $backup, [System.Text.UTF8Encoding]::new($false)) }
}
