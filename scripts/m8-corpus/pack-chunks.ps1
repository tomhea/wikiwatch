# M8 corpus pipeline — step 4 of 5: pack-chunks.
#
# Packs the extracted article bodies into chunk JSON files for install-time
# transport, and assigns each article a COMPACT NUMERIC id.
#
#   in : cached/selected.tsv  + cached/articles/<encodedId>.txt
#   out: docs/server/chunk/N.json    { "chunk": N, "articles": { "<numId>": "<body>", ... } }
#        cached/packed.tsv           numId <TAB> title <TAB> popularity   (for gen-manifest)
#
# ID scheme — DEVIATION from the m8-plan's "Hebrew URL-encoded" id:
#   The URL-encoded Hebrew id is ~150-220 bytes EACH; with ~585 articles that
#   blew manifest.json past CIQ's makeWebRequest response cap (rc=-402
#   NETWORK_RESPONSE_TOO_LARGE; the 92.5 KB v5 manifest was rejected by the
#   Venu 2 sim, ~64 KB cap). The watch treats `id` as an opaque String, so a
#   compact numeric id ("0".."N-1", popularity-rank order) costs nothing
#   practical and shrinks the manifest ~3x. The extraction cache is still keyed
#   by the URL-encoded id (filename); the numeric id is the public/transport id.
#
# Grouping is BYTE-AWARE: greedily fill to ~ChunkByteTarget, then start a new
# chunk, so no chunk approaches the response cap either (a 14 KB article landing
# last keeps a 30 KB-target chunk well under 64 KB).
param(
    [string]$InDir           = "$PSScriptRoot\cached",
    [string]$OutDir          = "$PSScriptRoot\..\..\docs\server\chunk",
    [int]   $ChunkByteTarget = 30720,   # ~30 KB raw per chunk (cap ~64 KB)
    [int]   $MaxPerChunk     = 60
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$selPath  = Join-Path $InDir "selected.tsv"
$artDir   = Join-Path $InDir "articles"
$packPath = Join-Path $InDir "packed.tsv"
if (-not (Test-Path $selPath)) { Write-Error "missing $selPath — run select.ps1"; exit 1 }

# Fresh output dir.
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Read selected articles in order; assign a sequential numeric id to each one
# that actually has an extracted body. (Get-CacheFileName — stable, shared with
# extract.ps1 — maps the encoded id to its cache filename.)
$articles = [System.Collections.ArrayList]@()
$first = $true
$numId = 0
foreach ($line in [System.IO.File]::ReadLines($selPath)) {
    if ($first) { $first = $false; continue }
    $f = $line -split "`t", 4
    if ($f.Count -lt 4) { continue }
    $encId = $f[1]; $pop = $f[2]; $title = $f[3]
    $file = Join-Path $artDir ((Get-CacheFileName $encId) + ".txt")
    if (-not (Test-Path $file)) { continue }
    $body = [System.IO.File]::ReadAllText($file, [System.Text.UTF8Encoding]::new($false))
    [void]$articles.Add(@{
        id    = "$numId"
        body  = $body
        bytes = [System.Text.Encoding]::UTF8.GetByteCount($body)
        title = $title
        pop   = $pop
    })
    $numId++
}
Write-Host "pack: $($articles.Count) article bodies to pack"

$chunkIdx = 0
$curr = [ordered]@{}
$currBytes = 0
$currCount = 0

function Write-Chunk {
    param([int]$N, $Dict)
    $obj = [ordered]@{ chunk = $N; articles = $Dict }
    $json = $obj | ConvertTo-Json -Depth 5 -Compress
    $out = Join-Path $OutDir "$N.json"
    [System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
}

foreach ($a in $articles) {
    $wouldExceed = ($currBytes + $a.bytes -gt $ChunkByteTarget) -or ($currCount -ge $MaxPerChunk)
    if ($currCount -gt 0 -and $wouldExceed) {
        Write-Chunk -N $chunkIdx -Dict $curr
        $chunkIdx++
        $curr = [ordered]@{}
        $currBytes = 0
        $currCount = 0
    }
    $curr[$a.id] = $a.body
    $currBytes += $a.bytes
    $currCount++
}
if ($currCount -gt 0) {
    Write-Chunk -N $chunkIdx -Dict $curr
    $chunkIdx++
}

# Authoritative packed-article manifest input (numeric id order).
$sw = [System.IO.StreamWriter]::new($packPath, $false, [System.Text.UTF8Encoding]::new($false))
$sw.WriteLine("id`ttitle`tpopularity")
foreach ($a in $articles) { $sw.WriteLine("$($a.id)`t$($a.title)`t$($a.pop)") }
$sw.Close()

Write-Host "pack: wrote $chunkIdx chunk files -> $OutDir"
$sizes = Get-ChildItem $OutDir -Filter *.json | ForEach-Object { $_.Length }
$max = ($sizes | Measure-Object -Maximum).Maximum
Write-Host "pack: largest chunk = $([math]::Round($max/1KB,1)) KB (cap ~64 KB)"
Write-Host "pack: packed.tsv with $($articles.Count) articles -> $packPath"
