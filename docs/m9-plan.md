# M9 — Manifest-chunking: scale the corpus past the single-response cap

**Goal:** lift the ~190-article ceiling (set by the ~12 KB `makeWebRequest`
response cap on the single manifest) so the corpus can fill ~9.2 MB of Storage
(~1000 articles). Per the user, target ~9.2 MB and dial back if the watch hits
its Storage cap.

**Branch:** `m9-manifest-chunking` · **Tag:** `v0.M9` · **Artifact:** `versions/wikiwatch-M9.prg`

---

## The constraint

The manifest lists every article ({id,title,popularity}) for search, and it
arrives in ONE response. At ~64 B/entry the ~12 KB cap → ~190 articles. To go
bigger the article INDEX must be split across multiple responses + stored across
multiple Storage keys (per-key ≤16 KB).

## Architecture — server-generated index parts

The body-chunk stream is unchanged. We add a parallel, smaller **index** stream.

### Server
- `manifest.json` (small, one response): `{version, totalBytes, chunkCount,
  chunkUriPattern, indexCount, indexUriPattern}` — **no `articles[]`**.
- `index/K.json` (K = 0..indexCount-1): `{index:K, articles:[{id,title,popularity},...]}`
  — ~180 entries each (~11 KB, under the response cap). ~1000 articles → ~6 parts.
- `chunk/N.json`: `{chunk:N, articles:{id:body}}` — unchanged.

### Watch Storage
- `article:<id>` = body — unchanged.
- `index:<K>` = the K-th index part's articles Array — NEW (each ≤16 KB).
- `manifest` = the small manifest (no articles[]).
- install-state keys — extended to track index parts received.

### Install (two streams, resumable)
1. Fetch the small manifest.
2. Fetch all `index/K.json` → `IndexStore.putPart(K, articles)`. (Few, fast.)
3. Fetch all `chunk/N.json` → `ArticleStore.putBatch` (as today).
Both streams tracked in `InstallState` for resume; index parts first so search
works even if body chunks are still arriving.

### Search
`KeyboardDelegate` loads the full article list from `IndexStore.load()`
(concatenates `index:0..indexCount-1`) instead of `Manifest.articles`. Ranking
is unchanged (`Search.rank`).

---

## Watch-side changes

| File | Change |
|---|---|
| `Downloader.mc` | `parseManifestResponse`: read `indexCount`/`indexUriPattern`, drop `articles[]`. Add `fetchIndex(pattern, k, cb)` (mirror `fetchChunk`). |
| `Manifest.mc` | schema gains `indexCount`/`indexUriPattern`; `articles` no longer stored in the manifest key. |
| `IndexStore.mc` (NEW, storage) | `putPart(k, arr)` (R4-guarded), `load()` → concat all parts, `isComplete(indexCount)`. |
| `InstallState.mc` | track index parts received (mirror chunk bitmap). |
| `InstallController.mc` / `InstallPlan.mc` | schedule index-part fetches (reuse the chunk-scheduling math). |
| `InstallView.mc` | two-phase fetch (index parts → body chunks); progress counts both. |
| `wikiwatchKeyboardDelegate.mc` / `Search` callers | load articles from `IndexStore.load()`. |
| `wikiwatchApp.mc` | `_corpusIntact` spot-check uses `IndexStore.load()` ids. |

## Corpus tooling
- `select.ps1` — already supports the bigger count (1200 selected).
- `extract.ps1` — unchanged (per-article bodies).
- `pack-chunks.ps1` — unchanged body chunks; accumulate until ~9.2 MB then stop.
- NEW `pack-index.ps1` — write `index/K.json` parts (~180 articles each).
- `gen-manifest.ps1` — emit the small manifest (no articles[]; add indexCount).

## Risks (validate in R2, dial back if needed)
- **Storage cap:** ~9.2 MB may exceed Venu 2's ~9 MB quota → `putBatch`'s
  try/catch skips overflow (degraded, not crash); dial back article count.
- **Install time:** ~1000 chunks over BLE ≈ 8–10 min (resumable).
- **Search resident memory + per-keystroke cost:** ~1000 articles in memory
  (~120 KB) + O(1000) ranking per keystroke. If it lags/OOMs (cf. M6.3), add a
  first-letter bucket index. Measured in R2.
