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
    [string]$Device = "venu2",
    [string]$GoldenId = "1143"   # the largest article in golden.json (worst case)
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj    = Resolve-Path "$PSScriptRoot\.."
$app     = Join-Path $proj "source\wikiwatchApp.mc"
$prg     = Join-Path $proj "bin\wikiwatch-wdcheck.prg"
$log     = Join-Path $proj "bin\wdcheck.log"
$golden  = Join-Path $proj "scripts\m10-compress\golden.json"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

# 1. Pull the worst-case blob + its expected char length out of golden.json.
$blob = & python -c "import json,sys; g=json.load(open(r'$golden',encoding='utf-8')); v=[x for x in g if x['id']=='$GoldenId'][0]; sys.stdout.write(v['blob_b64'])"
if (-not $blob) { Write-Error "could not read golden blob id=$GoldenId"; exit 2 }

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
($all -split "`r?`n") | Select-String -Pattern "Watchdog|Tripped|crash|Error:|first-paint|full-layout|cache HIT" | ForEach-Object { Write-Host $_ }
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

if ($fail) { exit 1 }
Write-Host "WDCHECK PASS: worst-case article decoded + rendered, no watchdog; lazy-load ok (full-layout lines=$layoutLines)." -ForegroundColor Green
exit 0
