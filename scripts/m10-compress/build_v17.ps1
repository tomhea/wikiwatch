# M10.6 one-command v17 corpus build at a chosen dense-chunk byte target.
#   dense_pack (compress reuse-v1 + dense pack) -> pack-index -> gen-manifest v17
#   -> patch bodyCodec/modelVersion. Reuses cached/compressed.tsv so re-targets
#   are fast (no recompress). Used to bisect the sim -402 ceiling.
param([int]$TargetBytes = 16384, [int]$Version = 17)
$ErrorActionPreference = "Stop"
$repo = Resolve-Path "$PSScriptRoot\..\.."
$m8   = Join-Path $repo "scripts\m8-corpus"

python (Join-Path $PSScriptRoot "dense_pack.py") --target-bytes $TargetBytes | Select-Object -Last 1
if ($LASTEXITCODE) { throw "dense_pack failed" }
& (Join-Path $m8 "pack-index.ps1") | Select-Object -Last 1
& (Join-Path $m8 "gen-manifest.ps1") -Version $Version -IndexMode $true | Select-Object -Last 1
$man = Join-Path $repo "docs\server\manifest.json"
python -c "import json,sys; p=sys.argv[1]; m=json.load(open(p,encoding='utf-8')); m['bodyCodec']='bpe-huff-1'; m['modelVersion']=1; json.dump(m,open(p,'w',encoding='utf-8',newline='\n'),separators=(',',':'),ensure_ascii=False); print('  manifest:',json.dumps(m))" $man
