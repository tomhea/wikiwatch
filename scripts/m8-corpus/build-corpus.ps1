# M9.4 corpus size-sweep orchestrator.
#
# Regenerates the docs/server/ payload at a chosen article count + manifest
# version, reusing the already-extracted bodies in cached/. Used to bisect the
# real-watch survivable corpus size after the M9.3 hardware hang: re-run with a
# larger -MaxArticles, re-upload docs/server/, reinstall on the watch, read the
# on-screen free-memory HUD, record whether it stayed stable.
#
# Prereq: a prior full pipeline run populated cached/ — specifically a
# popularity-ranked master selection. This script PREFERS cached/selected-full.tsv
# (the full ranked list) and takes its top-N, so the sweep subsets are the N most
# popular articles AND are guaranteed to have extracted bodies. If that master is
# absent it falls back to running select.ps1 (which ranks by pageviews if the
# dump is present, else by item size).
#
# Each size MUST get a fresh -Version (higher than the last installed) so the
# watch treats it as an update and re-installs instead of keeping the old corpus.
#
# Pipeline ORDER matters: pack-chunks writes cached/packed.tsv, which pack-index
# then reads — so chunks BEFORE index.
#
# Example sweep:
#   build-corpus.ps1 -MaxArticles 300  -Version 11
#   build-corpus.ps1 -MaxArticles 600  -Version 12
#   build-corpus.ps1 -MaxArticles 1000 -Version 13
param(
    [Parameter(Mandatory=$true)][int] $MaxArticles,
    [Parameter(Mandatory=$true)][int] $Version,
    [long] $TargetBytes = 10485760   # 10 MB ceiling; the count cap usually binds
)
$ErrorActionPreference = "Stop"
$here   = $PSScriptRoot
$cached = Join-Path $here "cached"
$master = Join-Path $cached "selected-full.tsv"
$sel    = Join-Path $cached "selected.tsv"

Write-Host "=== build-corpus: MaxArticles=$MaxArticles Version=$Version ==="

if (Test-Path $master) {
    # Take the top-N of the popularity-ranked master (header + first N rows).
    $lines = [System.IO.File]::ReadAllLines($master)
    $take  = [Math]::Min($MaxArticles, $lines.Length - 1)
    $out   = New-Object System.Collections.Generic.List[string]
    $out.Add($lines[0])                                  # header
    for ($i = 1; $i -le $take; $i++) { $out.Add($lines[$i]) }
    [System.IO.File]::WriteAllLines($sel, $out, [System.Text.UTF8Encoding]::new($false))
    Write-Host "build-corpus: took top $take of $($lines.Length - 1) popularity-ranked master rows"
} else {
    Write-Host "build-corpus: no selected-full.tsv master — running select.ps1 fresh"
    & "$here\select.ps1" -MaxArticles $MaxArticles -TargetBytes $TargetBytes
    if ($LASTEXITCODE) { Write-Error "select failed"; exit 1 }
}

# chunks BEFORE index (pack-index reads the packed.tsv that pack-chunks writes).
& "$here\pack-chunks.ps1"
if ($LASTEXITCODE) { Write-Error "pack-chunks failed"; exit 1 }

& "$here\pack-index.ps1"
if ($LASTEXITCODE) { Write-Error "pack-index failed"; exit 1 }

& "$here\gen-manifest.ps1" -Version $Version -IndexMode $true
if ($LASTEXITCODE) { Write-Error "gen-manifest failed"; exit 1 }

$server   = Resolve-Path "$here\..\..\docs\server"
$idxParts = @(Get-ChildItem "$server\index" -Filter *.json -ErrorAction SilentlyContinue).Count
$chunks   = @(Get-ChildItem "$server\chunk" -Filter *.json -ErrorAction SilentlyContinue).Count
Write-Host "=== done: v$Version -> $idxParts index parts, $chunks chunks under $server ==="
Write-Host "Next: upload docs/server/ to wikiwatch.tomhe.app, reinstall on the watch, read the free-mem HUD."
