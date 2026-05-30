# M9.4 corpus size-sweep orchestrator.
#
# Regenerates the docs/server/ payload at a chosen article count + manifest
# version, reusing the already-extracted bodies in cached/. Used to bisect the
# real-watch survivable corpus size after the M9.3 hardware hang: re-run with a
# larger -MaxArticles, re-upload docs/server/, reinstall on the watch, read the
# on-screen free-memory HUD, record whether it stayed stable.
#
# Prereq: enumerate.ps1 + extract.ps1 have already populated cached/
# (candidates.tsv + articles/<id>.txt). This script does NOT re-extract — it
# only re-selects a subset and re-packs, so it is fast.
#
# Each size MUST get a fresh -Version (higher than the last installed) so the
# watch treats it as an update and re-installs instead of keeping the old corpus.
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
$here = $PSScriptRoot

Write-Host "=== build-corpus: MaxArticles=$MaxArticles Version=$Version ==="

& "$here\select.ps1"      -MaxArticles $MaxArticles -TargetBytes $TargetBytes
if ($LASTEXITCODE) { Write-Error "select failed"; exit 1 }

& "$here\pack-index.ps1"
if ($LASTEXITCODE) { Write-Error "pack-index failed"; exit 1 }

& "$here\pack-chunks.ps1"
if ($LASTEXITCODE) { Write-Error "pack-chunks failed"; exit 1 }

& "$here\gen-manifest.ps1" -Version $Version -IndexMode $true
if ($LASTEXITCODE) { Write-Error "gen-manifest failed"; exit 1 }

$server = Resolve-Path "$here\..\..\docs\server"
$idxParts = @(Get-ChildItem "$server\index" -Filter *.json -ErrorAction SilentlyContinue).Count
$chunks   = @(Get-ChildItem "$server\chunk" -Filter *.json -ErrorAction SilentlyContinue).Count
Write-Host "=== done: v$Version -> $idxParts index parts, $chunks chunks under $server ==="
Write-Host "Next: upload docs/server/ to wikiwatch.tomhe.app, reinstall on the watch, read the free-mem HUD."
