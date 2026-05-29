# M8 corpus pipeline — step 2 of 5: select.
#
# Picks which articles ship from the enumerated candidates and assigns each a
# 0..100 popularity score.
#
#   in : cached/candidates.tsv
#        cached/pageviews-he.tsv   (OPTIONAL: path<TAB>views — preferred ranking)
#   out: cached/selected.tsv       columns: idx <TAB> id <TAB> popularity <TAB> title
#
# Ranking:
#   - If a pageview dump is present, rank by views (most faithful to "what a
#     user looks up"). Join on path/title.
#   - Otherwise fall back to item-size rank. The ZIM is already `_top_` curated
#     (Kiwix pre-selected the popular pages), so within it size is a reasonable
#     proxy for substance; popularity is log-scaled from the chosen metric.
#
# Selection stops at -TargetBytes (estimated extracted bytes) or -MaxArticles,
# whichever comes first. extract.ps1 enforces the real 14 KB per-article cap.
param(
    [string]$InDir       = "$PSScriptRoot\cached",
    [long]  $TargetBytes = 8388608,   # ~8 MB extracted-body budget
    [int]   $MaxArticles = 4000
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$candPath = Join-Path $InDir "candidates.tsv"
$pvPath   = Join-Path $InDir "pageviews-he.tsv"
$selPath  = Join-Path $InDir "selected.tsv"
if (-not (Test-Path $candPath)) { Write-Error "missing $candPath — run enumerate.ps1 first"; exit 1 }

# Load candidates.
$cands = [System.Collections.ArrayList]@()
$first = $true
foreach ($line in [System.IO.File]::ReadLines($candPath)) {
    if ($first) { $first = $false; continue }   # header
    $f = $line -split "`t", 4
    if ($f.Count -lt 4) { continue }
    [void]$cands.Add([pscustomobject]@{
        idx   = [int]$f[0]
        size  = [long]$f[1]
        path  = $f[2]
        title = $f[3]
        metric = [long]$f[1]   # default metric = size; overwritten if pageviews present
    })
}
Write-Host "select: $($cands.Count) candidates loaded"

# Optional pageview join.
$usePageviews = $false
if (Test-Path $pvPath) {
    $views = @{}
    foreach ($line in [System.IO.File]::ReadLines($pvPath)) {
        $f = $line -split "`t", 2
        if ($f.Count -lt 2) { continue }
        $views[$f[0]] = [long]$f[1]
    }
    foreach ($c in $cands) {
        $key = $c.title
        if ($views.ContainsKey($key)) { $c.metric = $views[$key] }
        elseif ($views.ContainsKey($c.path)) { $c.metric = $views[$c.path] }
        else { $c.metric = 0 }
    }
    $usePageviews = $true
    Write-Host "select: joined pageview dump ($($views.Count) titles) — ranking by views"
} else {
    Write-Host "select: no pageviews-he.tsv — ranking by item size (ZIM is already _top_ curated)"
}

# Rank by metric DESC.
$ranked = $cands | Sort-Object -Property metric -Descending
$maxMetric = [long]($ranked | Select-Object -First 1).metric
if ($maxMetric -le 0) { $maxMetric = 1 }

# Select until budget / count limit.
$sw = [System.IO.StreamWriter]::new($selPath, $false, [System.Text.UTF8Encoding]::new($false))
$sw.WriteLine("idx`tid`tpopularity`ttitle")
$accBytes = 0L
$n = 0
foreach ($c in $ranked) {
    if ($n -ge $MaxArticles) { break }
    # Estimate extracted bytes: markdown is far smaller than raw HTML; cap at 14 KB.
    $est = [Math]::Min([long]($c.size * 0.25), 14336L)
    if ($est -lt 200) { $est = 200 }
    if (($accBytes + $est) -gt $TargetBytes) { break }
    $accBytes += $est
    $id = [System.Uri]::EscapeDataString($c.path)
    $pop = Get-PopularityScore -Views $c.metric -MaxViews $maxMetric
    $t = ($c.title -replace "`t", ' ')
    $sw.WriteLine("$($c.idx)`t$id`t$pop`t$t")
    $n++
}
$sw.Close()
Write-Host "select: chose $n articles (est ~$([math]::Round($accBytes/1MB,2)) MB extracted) -> $selPath"
