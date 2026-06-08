# Validate CapProbe in the simulator against the local HTTPS fixture (the same one
# install-check uses, with the trusted dev cert). Confirms the probe correctly
# reports OK vs -402 across the size ramp, so we trust it on the real watch.
param([int]$Port = 8099, [int]$WaitSeconds = 18, [string]$Device = "venu2")
$ErrorActionPreference = "Stop"

$sdkRoot = "C:\Users\tomhe\AppData\Roaming\Garmin\ConnectIQ\Sdks"
$sdk = (Get-ChildItem $sdkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
$monkeydo = Join-Path $sdk "bin\monkeydo.bat"

$proj = $PSScriptRoot
$wiki = (Resolve-Path "$PSScriptRoot\..\..").Path   # the wikiwatch repo root (cap-probe lives under probes/)
$fixture = Join-Path $wiki "scripts\m10-compress\fixture_server.py"
$cert = Join-Path $wiki "bin\fixture-cert.pem"
$key  = Join-Path $wiki "bin\fixture-key.pem"
$prg  = "C:\Temp\CapProbe.prg"   # build output (monkeyc can't write under the repo tree)
$log  = Join-Path $proj "bin\probe-sim.log"
$srvlog = Join-Path $proj "bin\probe-srv.log"

if (-not (Get-Process -Name "simulator","connectiq" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath (Join-Path $sdk "bin\connectiq.bat") -WindowStyle Minimized
    Start-Sleep -Seconds 14
}

# 1. Build the probe pointing at the local fixture.
& (Join-Path $proj "build.ps1") -Device $Device -BaseUrl "https://127.0.0.1:$Port/probe/" | Select-Object -Last 1

# 2. Serve cap-probe/server over the trusted HTTPS fixture.
$srv = Start-Process -FilePath "python" -ArgumentList @($fixture, "$Port", (Join-Path $proj "server"), $cert, $key) `
    -NoNewWindow -PassThru -RedirectStandardOutput $srvlog -RedirectStandardError "$srvlog.err"
Start-Sleep -Seconds 1

try {
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    $javaBefore = @((Get-Process -Name java -ErrorAction SilentlyContinue).Id)
    $p = Start-Process -FilePath $monkeydo -ArgumentList @($prg, $Device) -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Seconds $WaitSeconds
    try { $p.Kill() } catch {}
    Get-Process -Name java -ErrorAction SilentlyContinue |
        Where-Object { $javaBefore -notcontains $_.Id } | ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
}
finally {
    try { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host "---- probe results (sim) ----"
(Get-Content $log -ErrorAction SilentlyContinue) | Select-String -Pattern "probe \d+KB rc=" | ForEach-Object { Write-Host $_ }
Write-Host "-----------------------------"
