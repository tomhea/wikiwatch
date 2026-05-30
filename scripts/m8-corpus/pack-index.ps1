# M9 corpus pipeline — pack-index.
#
# Splits the full article index ({id, title, popularity}) into small parts
# that each fit in a single makeWebRequest response (~11 KB <= ~12 KB cap).
# The body chunks (chunk/N.json) are written by pack-chunks.ps1 unchanged.
#
#   in : cached/packed.tsv  (authoritative ordered list from pack-chunks.ps1)
#   out: docs/server/index/K.json  { "index":K, "articles":[{id,title,popularity},...] }
#        cached/index-meta.json    { "indexCount": K, "indexUriPattern": "/index/{n}.json" }
#
# The watch fetches all K parts during install and concatenates them into the
# full searchable article list (IndexStore.load()). Part size is limited so
# each response stays under the ~12 KB response cap.
param(
    [string]$InDir       = "$PSScriptRoot\cached",
    [string]$OutDir      = "$PSScriptRoot\..\..\docs\server\index",
    [int]   $PartMaxBytes = 10240   # ~10 KB per part, safely under the ~12 KB cap
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$packPath = Join-Path $InDir "packed.tsv"
if (-not (Test-Path $packPath)) { Write-Error "missing $packPath — run pack-chunks.ps1 first"; exit 1 }

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Read articles in order from packed.tsv.
$articles = [System.Collections.ArrayList]@()
$first = $true
foreach ($line in [System.IO.File]::ReadLines($packPath)) {
    if ($first) { $first = $false; continue }
    $f = $line -split "`t", 3
    if ($f.Count -lt 3) { continue }
    [void]$articles.Add([ordered]@{ id = $f[0]; title = $f[1]; popularity = [int]$f[2] })
}
Write-Host "pack-index: $($articles.Count) articles to split into parts"

$partIdx  = 0
$currPart = [System.Collections.ArrayList]@()
$currBytes = 0

function Write-IndexPart {
    param([int]$N, $Items)
    $obj = [ordered]@{ index = $N; articles = $Items.ToArray() }
    $json = $obj | ConvertTo-Json -Depth 3 -Compress
    $out = Join-Path $OutDir "$N.json"
    [System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
}

foreach ($a in $articles) {
    # estimate bytes for this entry: id (~6) + title (~40) + pop (~3) + overhead (~30) = ~80
    $est = 30 + ($a.id.Length) + ([System.Text.Encoding]::UTF8.GetByteCount($a.title)) + 10
    if ($currPart.Count -gt 0 -and ($currBytes + $est -gt $PartMaxBytes)) {
        Write-IndexPart -N $partIdx -Items $currPart
        $partIdx++
        $currPart = [System.Collections.ArrayList]@()
        $currBytes = 0
    }
    [void]$currPart.Add($a)
    $currBytes += $est
}
if ($currPart.Count -gt 0) {
    Write-IndexPart -N $partIdx -Items $currPart
    $partIdx++
}

# Write metadata for gen-manifest.ps1.
$meta = [ordered]@{ indexCount = $partIdx; indexUriPattern = "/index/{n}.json" }
[System.IO.File]::WriteAllText(
    (Join-Path $InDir "index-meta.json"),
    ($meta | ConvertTo-Json -Compress),
    [System.Text.UTF8Encoding]::new($false))

$sizes = @(Get-ChildItem $OutDir -Filter *.json | ForEach-Object { $_.Length })
$max = ($sizes | Measure-Object -Maximum).Maximum
$over = @($sizes | Where-Object { $_ -gt 12288 }).Count
Write-Host "pack-index: wrote $partIdx parts -> $OutDir (max=$([math]::Round($max/1KB,1))KB over12KB=$over)"
