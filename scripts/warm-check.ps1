# M10.3 eager-model-parse gate.
#
# The unit-test harness (/t) can't show the keyboard, so it can't exercise the
# ModelWarmer that runs from the keyboard's onShow. This script force-opens the
# KEYBOARD in the real app (with a seeded compressed manifest so corpusNeedsModel
# is true), captures the simulator's stdout, and asserts the model was parsed
# EAGERLY in the background ("M10.3 warm: model parsed eagerly") with no watchdog
# trip — i.e. the first compressed article would open without the DecodeView gate.
#
# It temporarily injects the force-open into wikiwatchApp.getInitialView (backed up
# + restored, never committed), builds a throwaway .prg, runs it, analyses the log.
#
# Run this (alongside watchdog-check.ps1) before handing the user any build that
# touches the warm/parse path. Exit 0 = eager parse confirmed, 1 = FAIL.
#
# Precondition: the simulator is running (the script starts it if not).
param(
    [int]$WaitSeconds = 14,
    [string]$Device = "venu2"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj = Resolve-Path "$PSScriptRoot\.."
$app  = Join-Path $proj "source\wikiwatchApp.mc"
$prg  = Join-Path $buildDir "wikiwatch-warmcheck.prg"
$log  = Join-Path $proj "bin\warmcheck.log"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

# 1. Make sure the simulator is up.
if (-not (Get-Process -Name "simulator","connectiq" -ErrorAction SilentlyContinue)) {
    Write-Host "starting simulator..."
    Start-Process -FilePath (Join-Path $sdk "bin\connectiq.bat") -WindowStyle Minimized
    Start-Sleep -Seconds 14
}

# 2. Inject a force-open of the keyboard (with a seeded COMPRESSED manifest, so the
#    warmer's corpusNeedsModel guard passes) as the FIRST line of getInitialView.
$backup = Get-Content $app -Raw
try {
    $lines = Get-Content $app
    $out = New-Object System.Collections.Generic.List[string]
    $injected = $false
    foreach ($ln in $lines) {
        $out.Add($ln)
        if (-not $injected -and $ln -match "function getInitialView\(") {
            $out.Add("        // WARMCHECK force-open (injected by warm-check.ps1)")
            $out.Add("        Manifest.save({ :version => 16, :articles => [], :bodyCodec => BodyCodec.BPE_HUFF_1, :modelVersion => CompModel.bakedVersion() });")
            $out.Add("        var __wcKb = new wikiwatchKeyboardView();")
            $out.Add("        return [ __wcKb, new wikiwatchKeyboardDelegate(__wcKb, `"`") ];")
            $injected = $true
        }
    }
    if (-not $injected) { throw "getInitialView anchor not found" }
    [System.IO.File]::WriteAllText($app, ($out -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

    # 3. Build the throwaway harness .prg.
    & $monkeyc -d $Device -f (Join-Path $proj "monkey.jungle") -o $prg -y $devKey -w
    if ($LASTEXITCODE -ne 0) { throw "harness build failed ($LASTEXITCODE)" }

    # 4. Run it in the simulator; capture stdout.
    if (Test-Path $log) { Remove-Item $log }
    $p = Start-Process -FilePath $monkeydo -ArgumentList @($prg, $Device) -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Seconds $WaitSeconds
    try { $p.Kill() } catch {}
}
finally {
    # 5. Always restore the original source.
    [System.IO.File]::WriteAllText($app, $backup, [System.Text.UTF8Encoding]::new($false))
}

# 6. Analyse the captured log.
$text = (Get-Content $log -Raw -ErrorAction SilentlyContinue)
if ($null -eq $text) { $text = "" }
$errText = (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
if ($null -eq $errText) { $errText = "" }
$all = $text + "`n" + $errText

Write-Host "---- warmcheck simulator log (relevant lines) ----"
($all -split "`r?`n") | Select-String -Pattern "Watchdog|Tripped|crash|Error:|M10.3 warm" | ForEach-Object { Write-Host $_ }
Write-Host "--------------------------------------------------"

$fail = $false
if ($all -match "Watchdog Tripped|Code Executed Too Long|app crash|Encountered an app crash") {
    Write-Host "WARMCHECK FAIL: watchdog / crash detected during background warm." -ForegroundColor Red
    $fail = $true
}
if (-not ($all -match "M10.3 warm: model parsed eagerly")) {
    Write-Host "WARMCHECK FAIL: model was NOT parsed eagerly (no 'M10.3 warm: model parsed eagerly' log) — first open would still hit the gate." -ForegroundColor Red
    $fail = $true
}

if ($fail) { exit 1 }
Write-Host "WARMCHECK PASS: compression model parsed EAGERLY in the background on keyboard show, no watchdog — first compressed article opens without the parse gate." -ForegroundColor Green
exit 0
