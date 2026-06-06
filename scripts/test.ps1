# Build the test .prg, launch it in the running simulator via monkeydo /t,
# stream stdout to bin/test-output.log, return exit 0 iff every (:test) PASSed.
#
# Preconditions:
#   - simulator.exe is already running (open it once per session).
#   - developer_key exists.
param(
    [string]$Device = "venu2",
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj    = Resolve-Path "$PSScriptRoot\.."
$prg     = Join-Path $buildDir "wikiwatch-test.prg"
$logPath = Join-Path $proj "bin\test-output.log"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

Push-Location $proj
try {
    # 1. Compile the test build.
    & $monkeyc -d $Device -f monkey.jungle --unit-test -o $prg -y $devKey -w
    if ($LASTEXITCODE -ne 0) {
        Write-Error "monkeyc --unit-test failed with exit $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # 2. Run tests in the simulator. monkeydo blocks until the test app exits.
    if (Test-Path $logPath) { Remove-Item $logPath }
    $proc = Start-Process -FilePath $monkeydo `
        -ArgumentList @($prg, $Device, "/t") `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError  "$logPath.err"
    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
        try { $proc.Kill() } catch {}
        Write-Error "test run timed out after $TimeoutSeconds s"
        exit 124
    }

    # 3. Parse the output. Connect IQ test harness prints lines like:
    #    "PASSED" / "FAILED" / "------------------------------------------------------------"
    #    plus a per-test "<class>.<method> PASS" or "FAIL" line.
    $log = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    if (-not $log) { $log = "" }
    Write-Host $log

    $failed = ($log -match "(?m)^\s*FAIL")
    $passed = ($log -match "(?m)^\s*PASS")
    if ($failed -or -not $passed) {
        Write-Error "tests FAILED (see $logPath)"
        exit 1
    }
    Write-Host "TESTS OK"
}
finally {
    Pop-Location
}
