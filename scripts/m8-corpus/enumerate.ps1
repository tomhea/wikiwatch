# M8 corpus pipeline — step 1 of 5: enumerate.
#
# Runs `zimdump list --details <zim>` once and parses the per-entry blocks into
# a candidates TSV, keeping only real article items (type=item, mime=text/html).
#
#   in : <zim>
#   out: cached/candidates.tsv   columns: idx <TAB> size <TAB> path <TAB> title
#
# Idempotency: this is the slow step (~minutes for 174k entries). Re-running
# extract/select after tweaking later logic does NOT require re-running this.
param(
    [string]$ZimPath = "C:\Users\tomhe\Downloads\wikipedia_he_top_nopic_2026-04.zim",
    [string]$OutDir  = "$PSScriptRoot\cached"
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $ZimPath)) {
    Write-Error "ZIM not found: $ZimPath`nDownload it (or pass -ZimPath). See README.md."
    exit 1
}
$zd = Get-Command zimdump -ErrorAction SilentlyContinue
if ($null -eq $zd) { Write-Error "zimdump not on PATH. Install zim-tools."; exit 1 }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$rawPath = Join-Path $OutDir "zimdump-list.txt"
$candPath = Join-Path $OutDir "candidates.tsv"

Write-Host "enumerate: running zimdump list --details (this takes a few minutes)..."
& zimdump list --details $ZimPath > $rawPath
Write-Host "enumerate: parsing $([math]::Round((Get-Item $rawPath).Length/1MB,1)) MB of details..."

$sw = [System.IO.StreamWriter]::new($candPath, $false, [System.Text.UTF8Encoding]::new($false))
$sw.WriteLine("idx`tsize`tpath`ttitle")

$path = $null; $title = $null; $idx = $null; $type = $null; $mime = $null; $size = $null
$kept = 0; $seen = 0

function Flush-Entry {
    if ($null -ne $script:idx -and $script:type -eq 'item' -and $script:mime -eq 'text/html') {
        $p = ($script:path -replace "`t", ' ')
        $t = ($script:title -replace "`t", ' ')
        $script:sw.WriteLine("$($script:idx)`t$($script:size)`t$p`t$t")
        $script:kept++
    }
}

foreach ($line in [System.IO.File]::ReadLines($rawPath)) {
    if ($line.StartsWith('path: ')) {
        Flush-Entry
        $seen++
        $path = $line.Substring(6); $title = $null; $idx = $null; $type = $null; $mime = $null; $size = $null
    } elseif ($line -match '^\*\s+title:\s+(.*)$') {
        $title = $Matches[1]
    } elseif ($line -match '^\*\s+idx:\s+(\d+)') {
        $idx = $Matches[1]
    } elseif ($line -match '^\*\s+type:\s+(\S+)') {
        $type = $Matches[1]
    } elseif ($line -match '^\*\s+mime-type:\s+(\S+)') {
        $mime = $Matches[1]
    } elseif ($line -match '^\*\s+item size:\s+(\d+)') {
        $size = $Matches[1]
    }
}
Flush-Entry
$sw.Close()

Write-Host "enumerate: $seen entries seen, $kept text/html items -> $candPath"
