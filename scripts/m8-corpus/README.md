# M8 corpus-generation pipeline

Offline tools that turn a Kiwix ZIM snapshot of Hebrew Wikipedia into the
`docs/server/` payload the watch downloads. They run on the dev host, not on
the watch. Supersedes `scripts/gen-server-corpus.ps1` (the M6.5/M7 synthetic
36-article generator).

## Prerequisites

- **zimdump** 3.x on PATH (`zim-tools`). Verify: `zimdump --version`.
- The ZIM file (≈700 MB, NOT committed — too big for git):
  `C:\Users\tomhe\Downloads\wikipedia_he_top_nopic_2026-04.zim`
  Pass a different path with `-ZimPath` to each step that needs it.

## Pipeline (run in order, once per corpus refresh)

```powershell
& scripts\m8-corpus\enumerate.ps1   -ZimPath <zim>      # -> cached/candidates.tsv  (slow, minutes)
& scripts\m8-corpus\select.ps1      -TargetBytes 8388608 # -> cached/selected.tsv
& scripts\m8-corpus\extract.ps1     -ZimPath <zim>      # -> cached/articles/<id>.txt  (zimdump show per article)
& scripts\m8-corpus\pack-chunks.ps1                     # -> docs/server/chunk/N.json
& scripts\m8-corpus\gen-manifest.ps1 -Version 5         # -> docs/server/manifest.json
```

Each step is independent and reads the previous step's cached output, so you
can re-run a later step (e.g. tweak the HTML strip + re-`extract`) without
redoing the slow `enumerate`.

## Selection / popularity

`select.ps1` ranks by **Hebrew Wikipedia pageviews** when a dump is present at
`cached/pageviews-he.tsv` (`path<TAB>views`), which is the most faithful
"what users look up" signal. Without that file it falls back to **item-size
rank** — defensible because the ZIM is already `_top_` curated (Kiwix
pre-selected the popular pages). Popularity is log-scaled to 0..100 either way.

## IDs

The article `id` is the ZIM path **URL-encoded** (`[System.Uri]::EscapeDataString`),
e.g. `שלום` → `%D7%A9%D7%9C%D7%95%D7%9D`. Lossless, and the encoded id is what
ends up as the `article:<id>` Storage key + the chunk-JSON key on the watch.

## Tests

`& scripts\m8-corpus\test.ps1` — 12 unit tests over the pure transforms in
`corpus-lib.ps1` (HTML→Markdown strip rules, chunk grouping, popularity range,
totalBytes sum, version bump). No Pester dependency.

## Outputs (committed)

- `docs/server/manifest.json` — `{version, totalBytes, chunkCount, chunkUriPattern, articles[]}`
- `docs/server/chunk/N.json` — `{chunk:N, articles:{ "<id>":"<body>", ... }}`, byte-capped ~80 KB

`cached/` is gitignored (intermediates).
