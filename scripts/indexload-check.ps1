# M10.5 sliced index-load gate.
#
# Seeds a LARGE synthetic search index (2800 articles — the M10.6 corpus size,
# 2.3x the old 1200) into Storage, force-opens the keyboard with a pre-filled query, and asserts
# the index loads ACROSS MULTIPLE TICKS (sliced, not one watchdog-tripping handler)
# and that typed search works on the fully-loaded index, with no crash.
#
# NOTE: the sim does not enforce the watchdog (only the real watch does), so this
# proves the load is STRUCTURALLY sliced + correct; the final watchdog proof at a
# big corpus is on-device (the tag), per the project's watchdog-gate convention.
#
# Injects a force-open into wikiwatchApp.getInitialView (backed up + restored).
param(
    [int]$WaitSeconds = 16,
    [string]$Device = "venu2",
    [int]$N = 2800
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj = Resolve-Path "$PSScriptRoot\.."
$app  = Join-Path $proj "source\wikiwatchApp.mc"
$prg  = Join-Path $buildDir "wikiwatch-indexcheck.prg"
$log  = Join-Path $proj "bin\indexcheck.log"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

if (-not (Get-Process -Name "simulator","connectiq" -ErrorAction SilentlyContinue)) {
    Write-Host "starting simulator..."
    Start-Process -FilePath (Join-Path $sdk "bin\connectiq.bat") -WindowStyle Minimized
    Start-Sleep -Seconds 14
}

$inject = @(
    "        // INDEXLOADCHECK force-open (injected by indexload-check.ps1)",
    "        IndexStore.wipeAll(); IndexCache.clear();",
    "        var __n = $N; var __per = 150; var __k = 0; var __i = 0;",
    "        while (__i < __n) {",
    "            var __part = [] as Array<Dictionary>;",
    "            var __end = __i + __per; if (__end > __n) { __end = __n; }",
    "            while (__i < __end) { __part.add({ :id => __i.toString(), :title => `"כותרת`" + __i.toString(), :popularity => (__n - __i) }); __i++; }",
    "            IndexStore.putPart(__k, __part); __k++;",
    "        }",
    "        InstallState.setInstalledCount(__n);",
    "        var __kb = new wikiwatchKeyboardView();",
    "        return [ __kb, new wikiwatchKeyboardDelegate(__kb, `"כות`") ];"
)

$backup = Get-Content $app -Raw
try {
    $lines = Get-Content $app
    $out = New-Object System.Collections.Generic.List[string]
    $injected = $false
    foreach ($ln in $lines) {
        $out.Add($ln)
        if (-not $injected -and $ln -match "function getInitialView\(") {
            foreach ($il in $inject) { $out.Add($il) }
            $injected = $true
        }
    }
    if (-not $injected) { throw "getInitialView anchor not found" }
    [System.IO.File]::WriteAllText($app, ($out -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

    & $monkeyc -d $Device -f (Join-Path $proj "monkey.jungle") -o $prg -y $devKey -w
    if ($LASTEXITCODE -ne 0) { throw "harness build failed ($LASTEXITCODE)" }

    if (Test-Path $log) { Remove-Item $log }
    $p = Start-Process -FilePath $monkeydo -ArgumentList @($prg, $Device) -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Seconds $WaitSeconds
    try { $p.Kill() } catch {}
}
finally {
    [System.IO.File]::WriteAllText($app, $backup, [System.Text.UTF8Encoding]::new($false))
}

$text = (Get-Content $log -Raw -ErrorAction SilentlyContinue); if ($null -eq $text) { $text = "" }
$errText = (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue); if ($null -eq $errText) { $errText = "" }
$all = $text + "`n" + $errText

Write-Host "---- indexcheck simulator log (relevant lines) ----"
($all -split "`r?`n") | Select-String -Pattern "Watchdog|Tripped|crash|Error:|M10.5 index loaded|M5 rank: buf=" | ForEach-Object { Write-Host $_ }
Write-Host "---------------------------------------------------"

$fail = $false
if ($all -match "Watchdog Tripped|Code Executed Too Long|app crash|Encountered an app crash") {
    Write-Host "INDEXCHECK FAIL: watchdog / crash detected." -ForegroundColor Red; $fail = $true
}
if ($all -match "M10.5 index loaded: n=(\d+) ticks=(\d+)") {
    $n = [int]$Matches[1]; $ticks = [int]$Matches[2]
    if ($n -lt $N) { Write-Host "INDEXCHECK FAIL: loaded n=$n < seeded $N." -ForegroundColor Red; $fail = $true }
    if ($ticks -lt 2) { Write-Host "INDEXCHECK FAIL: ticks=$ticks (<2) — load was NOT sliced across ticks." -ForegroundColor Red; $fail = $true }
} else {
    Write-Host "INDEXCHECK FAIL: no 'M10.5 index loaded' log (index never finished loading)." -ForegroundColor Red; $fail = $true
}
# search worked on the loaded index: the pre-filled 'כות' query must match (>0 total).
$searchOk = $false
foreach ($m in ([regex]"M5 rank: buf=.*?total=(\d+)").Matches($all)) {
    if ([int]$m.Groups[1].Value -gt 0) { $searchOk = $true }
}
if (-not $searchOk) {
    Write-Host "INDEXCHECK FAIL: typed search returned 0 matches on the loaded index." -ForegroundColor Red; $fail = $true
}

if ($fail) { exit 1 }
Write-Host "INDEXCHECK PASS: $N-article index loaded sliced across ticks (n=$n ticks=$ticks), search works, no crash." -ForegroundColor Green
exit 0
