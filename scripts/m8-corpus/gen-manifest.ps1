# M8 corpus pipeline — step 5 of 5: gen-manifest.
#
# Builds docs/server/manifest.json from pack-chunks' packed.tsv + the chunk dir.
#
#   in : cached/packed.tsv  + docs/server/chunk/*.json
#   out: docs/server/manifest.json
#        { version, totalBytes, chunkCount, chunkUriPattern, articles:[{id,title,popularity}] }
#
# COMPACT JSON (no whitespace) + the numeric ids from pack-chunks keep the
# manifest well under CIQ's makeWebRequest response cap (~64 KB on Venu 2 —
# the URL-encoded-id manifest was 92.5 KB and got rc=-402 NETWORK_RESPONSE_TOO_LARGE).
#
# version: pass -Version explicitly (the plan ships v5). The corpus fingerprint
# is recorded so a future auto-bump (Resolve-ManifestVersion) is possible.
param(
    [string]$InDir    = "$PSScriptRoot\cached",
    [string]$ServerDir= "$PSScriptRoot\..\..\docs\server",
    [int]   $Version  = 5
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$packPath = Join-Path $InDir "packed.tsv"
$chunkDir = Join-Path $ServerDir "chunk"
$manPath  = Join-Path $ServerDir "manifest.json"
if (-not (Test-Path $packPath)) { Write-Error "missing $packPath — run pack-chunks.ps1 first"; exit 1 }
if (-not (Test-Path $chunkDir)) { Write-Error "missing $chunkDir — run pack-chunks.ps1"; exit 1 }

# Articles come straight from packed.tsv (numeric-id order = popularity rank).
$articles = [System.Collections.ArrayList]@()
$first = $true
foreach ($line in [System.IO.File]::ReadLines($packPath)) {
    if ($first) { $first = $false; continue }
    $f = $line -split "`t", 3
    if ($f.Count -lt 3) { continue }
    [void]$articles.Add([ordered]@{
        id         = $f[0]
        title      = $f[1]
        popularity = [int]$f[2]
    })
}

# totalBytes = sum of chunk file sizes.
$chunkSizes = @(Get-ChildItem $chunkDir -Filter *.json | ForEach-Object { [int]$_.Length })
$totalBytes = Get-CorpusTotalBytes -ChunkByteSizes $chunkSizes
$chunkCount = $chunkSizes.Count

$manifest = [ordered]@{
    version         = $Version
    totalBytes      = $totalBytes
    chunkCount      = $chunkCount
    chunkUriPattern = "/chunk/{n}.json"
    articles        = $articles.ToArray()
}
# Compact (no whitespace) to stay under the response cap.
$json = $manifest | ConvertTo-Json -Depth 5 -Compress
[System.IO.File]::WriteAllText($manPath, $json, [System.Text.UTF8Encoding]::new($false))

$manKb = [math]::Round((Get-Item $manPath).Length / 1KB, 1)
Write-Host "gen-manifest: v$Version, $($articles.Count) articles, $chunkCount chunks, totalBytes=$totalBytes, manifest=$manKb KB -> $manPath"
