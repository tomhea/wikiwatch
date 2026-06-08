# M10.5 corpus stats — read-ranked selection (2026-06-05)

New corpus = top articles by **real 12-month Hebrew pageviews** (`fetch-pageviews.ps1`
→ `select.ps1`), extracted from the 2026-04 ZIM. 2,500 selected, 2,482 with usable
bodies measured. Per-article detail: `scripts/m8-corpus/cached/corpus-stats.tsv`.

Sizes use a **baked-equivalent** model (trained on the old top-1200 plain bodies;
sha ≠ baked because 1186≠1200 training bodies, so sizes are estimates ~within a few
% — the 36.7% ratio matches the shipped 35.6%).

## Length
- raw body: min 15 · **median 9.3 KB** · mean 8.0 KB · p90 10.1 KB · max 10.24 KB (extract cap)
- stored/downloaded (base64 of compressed): median 3.3 KB · mean 2.9 KB
- overall: **stored = 36.7% of raw** (compression)
- **12%** of articles hit the 10 KB extract cap (truncated); **6%** are short stubs (<2 KB)

## Capacity (cumulative, read-rank order)
| Articles | Download / Storage (compressed) | Raw text | Index (titles) |
|---|---|---|---|
| 500   | 1.56 MB | 4.3 MB  | 12 KB |
| 1,000 | 3.16 MB | 8.7 MB  | 24 KB |
| 1,200 | 3.81 MB | 10.5 MB | 28 KB |
| 1,462 | 4.63 MB | 12.7 MB | 35 KB |
| 1,750 | 5.54 MB | 15.1 MB | 42 KB |
| 2,000 | 6.33 MB | 17.2 MB | 48 KB |
| 2,250 | 6.85 MB | 18.6 MB | 54 KB |
| 2,482 | 7.30 MB | —       | 60 KB |

## Findings
1. **Storage is no longer the limit.** All 2,482 fit in **7.3 MB** (9 MB cap) → ~2,700+ would fit. Compression removed the storage ceiling.
2. **The real ceiling is the index-load watchdog (~1462 today)** — CPU-per-handler when the keyboard builds the title index in one event handler, NOT storage. Lifting it = slice that load across ticks (M10.5 binary work); after that you're storage-bound (~2,700).
3. **Truncation:** 12% of (popular) articles are cut at the 10 KB raw cap, set pre-compression to fit the ~13 KB response limit. Bodies now ship compressed (~37%), so the cap could be raised (e.g. 10 KB → ~18–20 KB raw ≈ ~7 KB compressed) to ship fuller articles.

## Recommended next steps (M10.5)
- Slice the keyboard index load across ticks (watchdog-safe) → raises the article ceiling toward the storage limit.
- Pack + ship the new read-ranked corpus at **~2,000–2,500** articles.
- Optional: raise the per-article extract cap for fuller popular articles.
- Separately, "faster download" = pack more articles per chunk (fewer round-trips) + tune concurrency.
