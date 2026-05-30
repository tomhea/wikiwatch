# M8 corpus pipeline — step 3 of 5: extract.
#
# For each selected article: `zimdump show --idx=N` -> raw HTML ->
# Convert-WikiHtmlToMarkdown -> cached/articles/<id>.txt (UTF-8, LF, <=14 KB).
#
#   in : cached/selected.tsv  + <zim>
#   out: cached/articles/<id>.txt   (one per selected article)
#
# -Idx N  extracts a single article (debugging the HTML strip on one page).
# -Limit  caps how many to extract (smoke test).
param(
    [string]$ZimPath  = "C:\Users\tomhe\Downloads\wikipedia_he_top_nopic_2026-04.zim",
    [string]$InDir    = "$PSScriptRoot\cached",
    [int]   $Idx      = -1,
    [int]   $Limit    = 0,
    # Per-article body cap. Must stay under the CIQ makeWebRequest response cap
    # so the article fits in a chunk (the Venu 2 sim rejects responses ≳13 KB
    # with rc=-402/-101). Default 10 KB leaves margin + room for chunk JSON
    # overhead.
    [int]   $MaxBytes = 10240,
    # Skip articles whose cache file already exists. Makes incremental
    # extraction fast (e.g. extending from 585 -> 1200 reuses cached files).
    [switch]$SkipExisting = $false
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$selPath = Join-Path $InDir "selected.tsv"
$artDir  = Join-Path $InDir "articles"
New-Item -ItemType Directory -Force -Path $artDir | Out-Null
$zdExe = (Get-Command zimdump -ErrorAction SilentlyContinue).Source
if ($null -eq $zdExe) { Write-Error "zimdump not on PATH"; exit 1 }

# Capture zimdump's UTF-8 stdout deterministically (avoids console-encoding
# mangling of Hebrew that `& zimdump` is prone to).
function Invoke-ZimShow {
    param([int]$Index)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $zdExe
    $psi.ArgumentList.Add("show"); $psi.ArgumentList.Add("--idx=$Index"); $psi.ArgumentList.Add($ZimPath)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $p.StandardError.ReadToEnd() | Out-Null
    $p.WaitForExit()
    return $out
}

function Write-ArticleFile {
    param([string]$Id, [string]$Markdown)
    # Get-CacheFileName (corpus-lib) gives a stable, path-safe name shared with
    # pack-chunks.ps1. LF endings; UTF-8 no BOM.
    $fname = Get-CacheFileName $Id
    $body = $Markdown -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText((Join-Path $artDir ($fname + ".txt")), $body, [System.Text.UTF8Encoding]::new($false))
}

# Build the work list.
$rows = [System.Collections.ArrayList]@()
$first = $true
foreach ($line in [System.IO.File]::ReadLines($selPath)) {
    if ($first) { $first = $false; continue }
    $f = $line -split "`t", 4
    if ($f.Count -lt 4) { continue }
    [void]$rows.Add([pscustomobject]@{ idx = [int]$f[0]; id = $f[1]; pop = $f[2]; title = $f[3] })
}

if ($Idx -ge 0) {
    $rows = @($rows | Where-Object { $_.idx -eq $Idx })
    if ($rows.Count -eq 0) { Write-Error "idx $Idx not in selected.tsv"; exit 1 }
}

$count = 0; $done = 0; $skipped = 0
foreach ($r in $rows) {
    if ($Limit -gt 0 -and $done -ge $Limit) { break }
    if ($SkipExisting) {
        $cachedPath = Join-Path $artDir ((Get-CacheFileName $r.id) + ".txt")
        if (Test-Path $cachedPath) { $skipped++; $count++; continue }
    }
    $html = Invoke-ZimShow -Index $r.idx
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title $r.title -MaxBytes $MaxBytes
    Write-ArticleFile -Id $r.id -Markdown $md
    $done++; $count++
    if ($count % 200 -eq 0) { Write-Host "extract: $count / $($rows.Count)..." }
}
Write-Host "extract: wrote $done new + $skipped cached = $($done+$skipped) total -> $artDir"
