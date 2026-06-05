# M10.4 recently-read gate.
#
# The unit tests cover Recents.add + RecentsStore persistence, but not that the
# recents actually SURFACE on the keyboard's empty buffer. This script seeds two
# recents, force-opens the keyboard in the real app, and asserts the keyboard
# rendered them ("M10.4 recents: n=2 ...") with no crash/watchdog.
#
# It temporarily injects the force-open into wikiwatchApp.getInitialView (backed up
# + restored, never committed), builds a throwaway .prg, runs it, analyses the log.
#
# Precondition: the simulator is running (the script starts it if not).
param(
    [int]$WaitSeconds = 10,
    [string]$Device = "venu2"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj = Resolve-Path "$PSScriptRoot\.."
$app  = Join-Path $proj "source\wikiwatchApp.mc"
$prg  = Join-Path $proj "bin\wikiwatch-recentscheck.prg"
$log  = Join-Path $proj "bin\recentscheck.log"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

if (-not (Get-Process -Name "simulator","connectiq" -ErrorAction SilentlyContinue)) {
    Write-Host "starting simulator..."
    Start-Process -FilePath (Join-Path $sdk "bin\connectiq.bat") -WindowStyle Minimized
    Start-Sleep -Seconds 14
}

# Inject: seed two recents, then force-open the keyboard as getInitialView.
$backup = Get-Content $app -Raw
try {
    $lines = Get-Content $app
    $out = New-Object System.Collections.Generic.List[string]
    $injected = $false
    foreach ($ln in $lines) {
        $out.Add($ln)
        if (-not $injected -and $ln -match "function getInitialView\(") {
            $out.Add("        // RECENTSCHECK force-open (injected by recents-check.ps1)")
            $out.Add("        RecentsStore.clear();")
            $out.Add("        RecentsStore.record(`"0`", `"shalom`");")
            $out.Add("        RecentsStore.record(`"1`", `"torah`");")
            $out.Add("        var __rcKb = new wikiwatchKeyboardView();")
            $out.Add("        return [ __rcKb, new wikiwatchKeyboardDelegate(__rcKb, `"`") ];")
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

$text = (Get-Content $log -Raw -ErrorAction SilentlyContinue)
if ($null -eq $text) { $text = "" }
$errText = (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
if ($null -eq $errText) { $errText = "" }
$all = $text + "`n" + $errText

Write-Host "---- recentscheck simulator log (relevant lines) ----"
($all -split "`r?`n") | Select-String -Pattern "Watchdog|Tripped|crash|Error:|M10.4 recents" | ForEach-Object { Write-Host $_ }
Write-Host "-----------------------------------------------------"

$fail = $false
if ($all -match "Watchdog Tripped|Code Executed Too Long|app crash|Encountered an app crash") {
    Write-Host "RECENTSCHECK FAIL: watchdog / crash detected." -ForegroundColor Red
    $fail = $true
}
if (-not ($all -match "M10.4 recents: n=(\d+)")) {
    Write-Host "RECENTSCHECK FAIL: keyboard never logged recents on the empty buffer." -ForegroundColor Red
    $fail = $true
} elseif ([int]$Matches[1] -lt 2) {
    Write-Host "RECENTSCHECK FAIL: recents n=$($Matches[1]) (<2) — seeded entries did not surface." -ForegroundColor Red
    $fail = $true
}

if ($fail) { exit 1 }
Write-Host "RECENTSCHECK PASS: 2 seeded recents surfaced on the keyboard's empty buffer, no watchdog." -ForegroundColor Green
exit 0
