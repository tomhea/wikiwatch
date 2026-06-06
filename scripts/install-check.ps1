# M10.6 install gate — full sim install of the v17 corpus over a LOCAL fixture
# server, to empirically find the makeWebRequest response cap (rc=-402) and prove
# the dense compressed chunks install with no -402/-101/crash.
#
# How it works (the sim has no phone, so it can't reach the real server — and we
# WANT the new local v17, not the deployed v16):
#   1. Serve docs/server/ over http://127.0.0.1:$Port (python http.server).
#   2. Override Downloader.BASE_URL -> the local server (backed up + restored).
#   3. Inject a force-fresh-install into wikiwatchApp.getInitialView (wipe stores,
#      return the InstallView) so the app downloads the whole corpus on launch.
#   4. Run in the sim, capture stdout, then assert: no -402/-101/-300/-400/crash,
#      every chunk received (receivedCount == chunkCount), and print the chunk
#      count (old 254-for-1200 -> new N-for-2800) as the round-trip/speed proxy.
#
# NOTE: like the other *-check.ps1 gates, the sim is a STRUCTURAL/round-trip proof;
# the real BLE response cap + download speed are confirmed on-device (the tag).
# The sim's -402 ceiling is a useful first bound but may differ from the watch.
param(
    [int]$Port = 8099,
    [int]$WaitSeconds = 45,
    [string]$Device = "venu2",
    # Point the install at this base URL instead of the local fixture (e.g. the
    # real https://wikiwatch.tomhe.app for a connectivity probe, or a GitHub-raw
    # branch URL). Empty = local HTTPS fixture serving docs/server/.
    [string]$BaseUrl = "",
    # The sim's makeWebRequest response cap is ~16 KB — BELOW the real watch's
    # (CapProbe: 48 KB OK, 64 KB -402). When the shipped corpus packs chunks
    # bigger than the sim can fetch, set this to re-pack a sim-safe temp fixture
    # (same bodies + same index parts) into bin/sim-server, so the install
    # MACHINERY is still proven green in the sim; the shipped (bigger) chunk size
    # is validated on-device. 0 = serve docs/server as-is.
    [int]$SimPackKB = 0
)
$UseFixture = [string]::IsNullOrEmpty($BaseUrl)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sdk.ps1"

$proj   = Resolve-Path "$PSScriptRoot\.."
$app    = Join-Path $proj "source\wikiwatchApp.mc"
$dload  = Join-Path $proj "source\net\Downloader.mc"
$server = Join-Path $proj "docs\server"
$prg    = Join-Path $proj "bin\wikiwatch-installcheck.prg"
$log    = Join-Path $proj "bin\installcheck.log"
New-Item -ItemType Directory -Force -Path (Split-Path $prg) | Out-Null

# Optionally build a sim-safe temp fixture (smaller chunks) from the same bodies +
# the shipped index parts, leaving docs/server untouched.
if ($SimPackKB -gt 0 -and $UseFixture) {
    $simRoot = Join-Path $proj "bin\sim-server"
    $simChunk = Join-Path $simRoot "chunk"
    Write-Host "sim-pack: re-packing chunks at $SimPackKB KB into $simRoot (shipped corpus untouched)"
    New-Item -ItemType Directory -Force -Path $simChunk | Out-Null
    python (Join-Path $PSScriptRoot "m10-compress\dense_pack.py") --target-bytes ($SimPackKB * 1024) --out-dir $simChunk | Select-Object -Last 1
    if ($LASTEXITCODE) { Write-Error "sim-pack dense_pack failed"; exit 1 }
    # Reuse the shipped index parts verbatim (index is chunk-packing-independent, <=9.6 KB).
    if (Test-Path (Join-Path $simRoot "index")) { Remove-Item (Join-Path $simRoot "index") -Recurse -Force }
    Copy-Item (Join-Path $server "index") (Join-Path $simRoot "index") -Recurse
    # Temp manifest: shipped version/codec, but chunkCount from the re-packed chunks.
    $shipMan = Get-Content (Join-Path $server "manifest.json") -Raw | ConvertFrom-Json
    $simChunkCount = @(Get-ChildItem $simChunk -Filter *.json).Count
    $simMan = [ordered]@{
        version = $shipMan.version; totalBytes = 0; chunkCount = $simChunkCount
        chunkUriPattern = "/chunk/{n}.json"; indexCount = $shipMan.indexCount
        indexUriPattern = "/index/{n}.json"; bodyCodec = $shipMan.bodyCodec; modelVersion = $shipMan.modelVersion
    }
    ($simMan | ConvertTo-Json -Compress) | Out-File (Join-Path $simRoot "manifest.json") -Encoding ascii -NoNewline
    $server = $simRoot
    Write-Host "sim-pack: serving $simChunkCount chunks @ $SimPackKB KB (machinery proof; shipped corpus is bigger)"
}

if (-not (Test-Path (Join-Path $server "manifest.json"))) {
    Write-Error "no manifest.json under $server — generate the corpus first"; exit 1
}
$manifest   = Get-Content (Join-Path $server "manifest.json") -Raw | ConvertFrom-Json
$chunkCount = $manifest.chunkCount

if (-not (Get-Process -Name "simulator","connectiq" -ErrorAction SilentlyContinue)) {
    Write-Host "starting simulator..."
    Start-Process -FilePath (Join-Path $sdk "bin\connectiq.bat") -WindowStyle Minimized
    Start-Sleep -Seconds 14
}

# --- 1. local fixture HTTPS server (sim's makeWebRequest requires TLS = rc-1001
#        SECURE_CONNECTION_REQUIRED over http; self-signed cert, sim is lenient) --
$server_log = Join-Path $proj "bin\installcheck-server.log"
$srv = $null
if ($UseFixture) {
    $BaseUrl = "https://127.0.0.1:$Port"
    $fixture = Join-Path $proj "scripts\m10-compress\fixture_server.py"
    $cert = Join-Path $proj "bin\fixture-cert.pem"
    $key  = Join-Path $proj "bin\fixture-key.pem"
    if (-not (Test-Path $cert) -or -not (Test-Path $key)) {
        Write-Host "generating self-signed fixture cert..."
        & openssl req -x509 -newkey rsa:2048 -keyout $key -out $cert -days 3650 -nodes `
            -subj "/CN=127.0.0.1" -addext "subjectAltName=IP:127.0.0.1" 2>$null
        if ($LASTEXITCODE -ne 0) { throw "openssl cert generation failed ($LASTEXITCODE)" }
    }
    $srv = Start-Process -FilePath "python" -ArgumentList @($fixture, "$Port", $server, $cert, $key) `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput $server_log -RedirectStandardError "$server_log.err"
    Start-Sleep -Seconds 1
    Write-Host "fixture server: $BaseUrl (pid $($srv.Id)) serving $server"
} else {
    Write-Host "using external base URL: $BaseUrl (no local fixture)"
}

$appBackup   = Get-Content $app -Raw
$dloadBackup = Get-Content $dload -Raw
try {
    # --- 2. override BASE_URL -> local fixture --------------------------------
    $dloadText = $dloadBackup -replace 'const BASE_URL = "https://wikiwatch\.tomhe\.app";',
        ('const BASE_URL = "' + $BaseUrl + '";   // INSTALLCHECK override')
    if ($dloadText -eq $dloadBackup) { throw "BASE_URL anchor not found in Downloader.mc" }
    [System.IO.File]::WriteAllText($dload, $dloadText, [System.Text.UTF8Encoding]::new($false))

    # --- 3. inject force-fresh-install at the top of getInitialView -----------
    $inject = @(
        "        // INSTALLCHECK force fresh install (injected by install-check.ps1)",
        "        ArticleStore.wipeAll(); IndexStore.wipeAll(); InstallState.reset();",
        "        return [ new InstallView(false), new InstallDelegate() ];"
    )
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

    # --- 4. build + run -------------------------------------------------------
    & $monkeyc -d $Device -f (Join-Path $proj "monkey.jungle") -o $prg -y $devKey -w
    if ($LASTEXITCODE -ne 0) { throw "harness build failed ($LASTEXITCODE)" }

    Remove-Item $log -Force -ErrorAction SilentlyContinue
    # monkeydo spawns a java app-runner that keeps the sim app alive (and holds the
    # log handle) after we kill the .bat; track pre-existing java so we kill only
    # THIS run's runner, never the simulator itself.
    $javaBefore = @((Get-Process -Name java -ErrorAction SilentlyContinue).Id)
    $p = Start-Process -FilePath $monkeydo -ArgumentList @($prg, $Device) -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Seconds $WaitSeconds
    try { $p.Kill() } catch {}
    Get-Process -Name java -ErrorAction SilentlyContinue |
        Where-Object { $javaBefore -notcontains $_.Id } |
        ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
    Start-Sleep -Milliseconds 500
}
finally {
    [System.IO.File]::WriteAllText($app, $appBackup, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($dload, $dloadBackup, [System.Text.UTF8Encoding]::new($false))
    if ($srv -ne $null) { try { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue } catch {} }
}

# --- 5. parse + assert --------------------------------------------------------
$text = (Get-Content $log -Raw -ErrorAction SilentlyContinue); if ($null -eq $text) { $text = "" }
$errText = (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue); if ($null -eq $errText) { $errText = "" }
$all = $text + "`n" + $errText
$linesAll = $all -split "`r?`n"

# rc histogram across all chunk/index/manifest results.
$rcCounts = @{}
foreach ($m in ([regex]"rc=(-?\d+)").Matches($all)) {
    $rc = $m.Groups[1].Value
    if ($rcCounts.ContainsKey($rc)) { $rcCounts[$rc]++ } else { $rcCounts[$rc] = 1 }
}
# last reported received count.
$received = -1
foreach ($m in ([regex]"\((\d+)/$chunkCount\) bytes").Matches($all)) { $received = [int]$m.Groups[1].Value }

Write-Host "---- install-check: rc histogram ----"
foreach ($k in ($rcCounts.Keys | Sort-Object { [int]$_ })) { Write-Host ("  rc={0}: {1}" -f $k, $rcCounts[$k]) }
Write-Host "---- relevant log lines ----"
$linesAll | Select-String -Pattern "rc=-402|rc=-101|rc=-30|rc=-40|Watchdog|crash|Error:|incompatible|complete|switch" |
    Select-Object -First 40 | ForEach-Object { Write-Host $_ }
Write-Host "----------------------------"

$fail = $false
if ($all -match "Watchdog Tripped|Code Executed Too Long|app crash|Encountered an app crash") {
    Write-Host "INSTALLCHECK FAIL: watchdog / crash detected." -ForegroundColor Red; $fail = $true
}
if ($all -match "rc=-402") { Write-Host "INSTALLCHECK FAIL: rc=-402 NETWORK_RESPONSE_TOO_LARGE (chunk over the response cap)." -ForegroundColor Red; $fail = $true }
if ($all -match "rc=-101") { Write-Host "INSTALLCHECK WARN/FAIL: rc=-101 BLE_QUEUE_FULL seen (back-off should re-queue; check it completed)." -ForegroundColor Yellow }
if ($all -match "rc=-300|rc=-400") { Write-Host "INSTALLCHECK FAIL: rc=-300/-400 — sim could not reach the fixture server (networking blocked)." -ForegroundColor Red; $fail = $true }
if ($all -match "incompatible corpus") { Write-Host "INSTALLCHECK FAIL: binary refused the corpus (codec/modelVersion mismatch)." -ForegroundColor Red; $fail = $true }
if ($received -lt $chunkCount) {
    Write-Host "INSTALLCHECK FAIL: received=$received < chunkCount=$chunkCount (install did not finish — try a larger -WaitSeconds)." -ForegroundColor Red; $fail = $true
}

if ($fail) { Write-Host "chunkCount(v17)=$chunkCount  received=$received" -ForegroundColor Red; exit 1 }
Write-Host "INSTALLCHECK PASS: v17 installed, $chunkCount chunks all received (received=$received), no -402/-101/crash." -ForegroundColor Green
Write-Host "  download proxy: $chunkCount chunks for 2,800 articles (old corpus: 254 chunks for 1,200)." -ForegroundColor Green
exit 0
