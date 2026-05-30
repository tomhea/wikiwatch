# M8/M9 corpus pipeline — step 5 of 5: gen-manifest.
#
# Builds docs/server/manifest.json from the chunk dir + (M9) index metadata.
#
# M8 mode (-IndexMode $false, default): emits articles[] inline in the manifest.
# M9 mode (-IndexMode $true): omits articles[]; instead emits indexCount +
#   indexUriPattern pointing at index/K.json parts written by pack-index.ps1.
#
#   in (M8): cached/packed.tsv + docs/server/chunk/*.json
#   in (M9): cached/packed.tsv + docs/server/chunk/*.json + cached/index-meta.json
#   out: docs/server/manifest.json
param(
    [string]$InDir     = "$PSScriptRoot\cached",
    [string]$ServerDir = "$PSScriptRoot\..\..\docs\server",
    [int]   $Version   = 5,
    [bool]  $IndexMode = $false   # $true = M9 (no articles[], uses index parts)
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$packPath = Join-Path $InDir "packed.tsv"
$chunkDir = Join-Path $ServerDir "chunk"
$manPath  = Join-Path $ServerDir "manifest.json"
if (-not (Test-Path $packPath))  { Write-Error "missing $packPath — run pack-chunks.ps1 first"; exit 1 }
if (-not (Test-Path $chunkDir))  { Write-Error "missing $chunkDir — run pack-chunks.ps1"; exit 1 }

# totalBytes = sum of chunk file sizes.
$chunkSizes = @(Get-ChildItem $chunkDir -Filter *.json | ForEach-Object { [int]$_.Length })
$totalBytes = Get-CorpusTotalBytes -ChunkByteSizes $chunkSizes
$chunkCount = $chunkSizes.Count

# Read packed.tsv for article count + (M8 mode) the articles[] array.
$articles = [System.Collections.ArrayList]@()
$first = $true
foreach ($line in [System.IO.File]::ReadLines($packPath)) {
    if ($first) { $first = $false; continue }
    $f = $line -split "`t", 3
    if ($f.Count -lt 3) { continue }
    [void]$articles.Add([ordered]@{ id = $f[0]; title = $f[1]; popularity = [int]$f[2] })
}

$manifest = [ordered]@{
    version         = $Version
    totalBytes      = $totalBytes
    chunkCount      = $chunkCount
    chunkUriPattern = "/chunk/{n}.json"
}

if ($IndexMode) {
    # M9: read index metadata written by pack-index.ps1.
    $metaPath = Join-Path $InDir "index-meta.json"
    if (-not (Test-Path $metaPath)) { Write-Error "missing $metaPath — run pack-index.ps1 first"; exit 1 }
    $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
    $manifest.indexCount      = $meta.indexCount
    $manifest.indexUriPattern = $meta.indexUriPattern
    # No articles[] — the watch fetches index parts during install.
} else {
    # M8: embed articles[] directly.
    $manifest.articles = $articles.ToArray()
}

# Compact (no whitespace) to stay under the response cap.
$json = $manifest | ConvertTo-Json -Depth 5 -Compress
[System.IO.File]::WriteAllText($manPath, $json, [System.Text.UTF8Encoding]::new($false))

$manKb = [math]::Round((Get-Item $manPath).Length / 1KB, 1)
$mode = if ($IndexMode) { "M9-index" } else { "M8-inline" }
Write-Host "gen-manifest: v$Version $mode, $($articles.Count) articles, $chunkCount chunks, totalBytes=$totalBytes, manifest=$manKb KB -> $manPath"
