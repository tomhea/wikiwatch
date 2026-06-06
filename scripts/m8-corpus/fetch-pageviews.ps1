# M8 corpus pipeline — pageviews fetcher (feeds select.ps1's preferred ranking).
#
# Builds cached/pageviews-he.tsv (article<TAB>views, NO header — the format
# select.ps1 reads) from Wikimedia's Pageviews REST API "top" endpoint, summed
# over the last N available months. Summing months gives both coverage (the union
# of monthly top-~1000 lists ≈ a few thousand distinct articles) and a natural
# damping of one-off spikes: a steadily-read "timeless" article accumulates across
# every month, while a one-month event contributes only that month. No artificial
# topic/recency penalties — ranking by what people actually read is the whole fix
# (the old corpus fell back to BYTE-SIZE ranking, which inflated long math pages).
#
#   out: cached/pageviews-he.tsv   (article<TAB>views, most-viewed first)
param(
    [int]$Months  = 12,
    [string]$Project = "he.wikipedia",
    [string]$OutDir  = "$PSScriptRoot\cached"
)
$ErrorActionPreference = "Stop"
$ua = "wikiwatch-corpus/1.0 (offline Hebrew Wikipedia watch app; contact tomherman4@gmail.com)"

# Hebrew + English non-article namespace prefixes (and the main page) to drop.
$nsRe = '^(מיוחד|ויקיפדיה|עזרה|קטגוריה|תבנית|פורטל|משתמש|שיחה|מדיה|ספר|יחידה|נושא|טיוטה|Special|Wikipedia|Help|Category|Template|Portal|User|Talk|Media|Module|Draft|Book|Portal_talk):'
function Is-Article([string]$title) {
    if ($title -eq 'עמוד_ראשי' -or $title -eq 'Main_Page' -or $title -eq '-') { return $false }
    if ($title -match $nsRe) { return $false }
    return $true
}

$totals = @{}
$gotMonths = 0
# Walk backward from the current month, skipping months the API doesn't have yet,
# until we've aggregated $Months successful months (try up to 3x that many).
$cursor = (Get-Date).Date.AddDays(1 - (Get-Date).Day)   # first of this month
for ($attempt = 0; $attempt -lt ($Months * 3) -and $gotMonths -lt $Months; $attempt++) {
    $cursor = $cursor.AddMonths(-1)
    $y = $cursor.Year; $m = '{0:D2}' -f $cursor.Month
    $uri = "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/$Project/all-access/$y/$m/all-days"
    try {
        $r = Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = $ua } -TimeoutSec 30
    } catch {
        Write-Host "  $y-$m : unavailable (skip)"
        continue
    }
    $arts = $r.items[0].articles
    $kept = 0
    foreach ($a in $arts) {
        if (-not (Is-Article $a.article)) { continue }
        $totals[$a.article] = ([long]($totals[$a.article])) + [long]$a.views
        $kept++
    }
    $gotMonths++
    Write-Host "  $y-$m : $kept articles (running distinct=$($totals.Count))"
}

if ($gotMonths -eq 0) { Write-Error "no pageview months fetched"; exit 1 }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outPath = Join-Path $OutDir "pageviews-he.tsv"
$sw = [System.IO.StreamWriter]::new($outPath, $false, [System.Text.UTF8Encoding]::new($false))
foreach ($kv in ($totals.GetEnumerator() | Sort-Object -Property Value -Descending)) {
    $sw.WriteLine("$($kv.Key)`t$($kv.Value)")
}
$sw.Close()
Write-Host "fetch-pageviews: $gotMonths months, $($totals.Count) distinct articles -> $outPath"
