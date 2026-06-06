# M10.1 watchdog + lazy-load gate.
#
# The (:test) unit-test harness does NOT enforce the CIQ watchdog; running the
# actual app via `monkeydo` DOES. So this script force-opens the WORST-CASE path
# (decode + render the largest compressed article) in the real app, captures the
# simulator's stdout, and FAILS if it sees "Watchdog Tripped" / a crash. It also
# asserts the reader's lazy-load still works (a first-paint of the initial screens
# BEFORE the full background layout completes).
#
# It temporarily injects a force-open into wikiwatchApp.getInitialView (backed up +
# restored, never committed), builds a throwaway .prg, runs it, and analyses the log.
#
# Run this before handing the user any build to sideload. Exit 0 = safe, 1 = FAIL.
#
# Precondition: the simulator is running (the script starts it if not).
param(
    [int]$WaitSeconds = 22,
    [string]$Device = "venu2"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj    = Resolve-Path "$PSScriptRoot\.."
$app     = Join-Path $proj "source\wikiwatchApp.mc"
$prg     = Join-Path $proj "bin\wikiwatch-wdcheck.prg"
$log     = Join-Path $proj "bin\wdcheck.log"
$chunkDir = Join-Path $proj "docs\server\chunk"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

# 1. M10.6: pick the worst-case blob = the LARGEST compressed body in the SHIPPED
#    corpus (docs/server/chunk). The v1 model is unchanged, so any shipped blob
#    decodes; the largest compressed body is the heaviest decode+render path. (Was
#    hard-pinned to the old golden id=1143; the new 2,800 corpus has different ids.)
$pick = & python -c @"
import json, glob, os, sys
best_id, best_b64 = None, ''
for p in glob.glob(os.path.join(r'$chunkDir', '*.json')):
    for aid, b64 in json.load(open(p, encoding='utf-8'))['articles'].items():
        if len(b64) > len(best_b64):
            best_id, best_b64 = aid, b64
sys.stderr.write('worst-case id=%s b64len=%d\n' % (best_id, len(best_b64)))
sys.stdout.write(best_b64)
"@
$blob = $pick
if (-not $blob) { Write-Error "could not find a worst-case blob in $chunkDir"; exit 2 }

# 2. Make sure the simulator is up.
if (-not (Get-Process -Name "simulator","connectiq" -ErrorAction SilentlyContinue)) {
    Write-Host "starting simulator..."
    Start-Process -FilePath (Join-Path $sdk "bin\connectiq.bat") -WindowStyle Minimized
    Start-Sleep -Seconds 14
}

# 3. Inject a force-open of DecodeView(largest blob) as the FIRST line of
#    getInitialView (before BootGuard, so SafeMode never interferes). Back up first.
$backup = Get-Content $app -Raw
try {
    $lines = Get-Content $app
    $out = New-Object System.Collections.Generic.List[string]
    $injected = $false
    foreach ($ln in $lines) {
        $out.Add($ln)
        if (-not $injected -and $ln -match "function getInitialView\(") {
            $out.Add("        // WDCHECK force-open (injected by watchdog-check.ps1)")
            $out.Add("        return [ new DecodeView(Decompressor.b64ToBytes(`"$blob`"), `"wdcheck`"), new DecodeDelegate() ];")
            $injected = $true
        }
    }
    if (-not $injected) { throw "getInitialView anchor not found" }
    [System.IO.File]::WriteAllText($app, ($out -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

    # 4. Build the throwaway harness .prg.
    & $monkeyc -d $Device -f (Join-Path $proj "monkey.jungle") -o $prg -y $devKey -w
    if ($LASTEXITCODE -ne 0) { throw "harness build failed ($LASTEXITCODE)" }

    # 5. Run it in the simulator; capture stdout.
    if (Test-Path $log) { Remove-Item $log }
    $p = Start-Process -FilePath $monkeydo -ArgumentList @($prg, $Device) -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Seconds $WaitSeconds
    try { $p.Kill() } catch {}
}
finally {
    # 6. Always restore the original source.
    [System.IO.File]::WriteAllText($app, $backup, [System.Text.UTF8Encoding]::new($false))
}

# 7. Analyse the captured log.
$text = (Get-Content $log -Raw -ErrorAction SilentlyContinue)
if ($null -eq $text) { $text = "" }
$errText = (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
if ($null -eq $errText) { $errText = "" }
$all = $text + "`n" + $errText

Write-Host "---- wdcheck simulator log (relevant lines) ----"
($all -split "`r?`n") | Select-String -Pattern "Watchdog|Tripped|crash|Error:|first-paint|stream first-paint|full-layout|cache HIT" | ForEach-Object { Write-Host $_ }
Write-Host "------------------------------------------------"

$fail = $false
if ($all -match "Watchdog Tripped|Code Executed Too Long|app crash|Encountered an app crash") {
    Write-Host "WDCHECK FAIL: watchdog / crash detected on the worst-case article open." -ForegroundColor Red
    $fail = $true
}
# lazy-load: a first-paint must precede a later full-layout (progressive render).
$hasFirstPaint = $all -match "first-paint: ms="
$hasFullLayout = $all -match "full-layout: ms=.*lines=(\d+)"
$layoutLines = if ($hasFullLayout) { [int]$Matches[1] } else { 0 }
if (-not $hasFirstPaint) {
    Write-Host "WDCHECK FAIL: no first-paint logged (reader never rendered the initial screens)." -ForegroundColor Red
    $fail = $true
}
if (-not $hasFullLayout) {
    Write-Host "WDCHECK FAIL: no full-layout logged (background lazy-load never finished)." -ForegroundColor Red
    $fail = $true
} elseif ($layoutLines -le 2) {
    Write-Host "WDCHECK WARN: full-layout lines=$layoutLines (<=2) — lazy-load may not have exercised a multi-batch fill." -ForegroundColor Yellow
}

# M10.2 streaming property: the reader must paint its first ~2 screens BEFORE the
# full decode finishes (tokensDone < tokenCount at first paint), proving it streams
# rather than decode-then-paint.
$hasStreamFP = $all -match "stream first-paint: tokensDone=(\d+) tokenCount=(\d+)"
if ($hasStreamFP) { $tokDone = [int]$Matches[1]; $tokCount = [int]$Matches[2] } else { $tokDone = 0; $tokCount = 0 }
if (-not $hasStreamFP) {
    Write-Host "WDCHECK FAIL: no 'stream first-paint' log (streaming reader never rendered)." -ForegroundColor Red
    $fail = $true
} elseif ($tokDone -ge $tokCount) {
    Write-Host "WDCHECK FAIL: stream first-paint tokensDone=$tokDone >= tokenCount=$tokCount (whole body decoded before first paint — not streaming)." -ForegroundColor Red
    $fail = $true
}

# M10.2 first paint covers ~2 screens (height target), not the old fixed 2 lines.
$hasFPMetrics = $all -match "first-paint: ms=\d+ sublines=(\d+) contentH=(\d+) screenH=(\d+)"
if ($hasFPMetrics) {
    $fpSub = [int]$Matches[1]; $fpContentH = [int]$Matches[2]; $fpScreenH = [int]$Matches[3]
    $twoScreens = [int]($fpScreenH * 1.6)   # ~2 screens, slack for the dense-budget cap
    if ($fpSub -le 2) {
        Write-Host "WDCHECK FAIL: first-paint sublines=$fpSub (<=2) — regressed to the old tiny first batch." -ForegroundColor Red
        $fail = $true
    } elseif ($fpContentH -lt $twoScreens) {
        Write-Host "WDCHECK WARN: first-paint contentH=$fpContentH < ~2 screens (screenH=$fpScreenH x1.6=$twoScreens), sublines=$fpSub — dense-paragraph budget cap; acceptable." -ForegroundColor Yellow
    } else {
        Write-Host "WDCHECK OK: first-paint contentH=$fpContentH >= ~2 screens (screenH=$fpScreenH, sublines=$fpSub)." -ForegroundColor Green
    }
} else {
    Write-Host "WDCHECK FAIL: first-paint metrics (sublines/contentH/screenH) not logged." -ForegroundColor Red
    $fail = $true
}

if ($fail) { exit 1 }
Write-Host "WDCHECK PASS: worst-case article streamed + rendered, no watchdog; first screen before full decode (tokensDone=$tokDone/$tokCount); first-paint sublines=$fpSub contentH=$fpContentH; full-layout lines=$layoutLines." -ForegroundColor Green
exit 0
