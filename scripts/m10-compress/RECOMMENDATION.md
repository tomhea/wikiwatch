# M10 bake-off — recommendation & decision gate

Corpus: **top-1200 articles, 7.05 MB raw UTF-8** (avg 5877 B, max 7680 B). Today's
raw chunk-JSON download = 7.13 MB. Every feasible algorithm **round-trips exactly on
all 1200** (hard gate). Primary metric = **net download** (base64-in-JSON, +33% tax
charged in). All decode is per-article-open.

## Merged frontier (sorted by net download)

| algo | feasible | ratio | dl% | flash(BA) | model | worst decode ops | watchdog | round-trip |
|---|---|--:|--:|--:|--:|--:|:--:|:--:|
| C zstd+dict64k | **reference only** | 0.248 | 34 | 1.82 MB | 64 KB | — | — | PASS |
| **E2 BPE-8192+Huff** | **easy** | **0.250** | **35** | **1.85 MB** | 80 KB | 36 k | LOW | PASS |
| E2 BPE-4096+Huff | easy | 0.267 | 36 | 1.92 MB | 36 KB | 38 k | LOW | PASS |
| E2 BPE-2048+Huff | easy | 0.284 | 38 | 2.02 MB | 15 KB | 41 k | LOW | PASS |
| B zlib+dict32k | reference only | 0.296 | 40 | 2.12 MB | 32 KB | — | — | PASS |
| E2 BPE-1024+Huff | easy | 0.304 | 40 | 2.15 MB | 6 KB | 45 k | LOW | PASS |
| E1 BPE-2048 fixed | easy | 0.325 | 43 | 2.31 MB | 13 KB | 45 k | LOW | PASS |
| B gzip | reference only | 0.345 | 46 | 2.43 MB | 0 | — | — | PASS |
| G LZSS+dict(+Huff) | medium | 0.37 | 49 | 2.6 MB | 4 KB | 60 k | LOW | PASS |
| D Huffman-0 | easy | 0.481 | 64 | 3.39 MB | 0 | 54 k | LOW | PASS |
| A raw UTF-8 | easy | 1.000 | — | 7.05 MB | 0 | — | — | PASS |

## Verdict
**Winner: byte-level BPE + static Huffman over token ids (candidate E2).**

- It **matches the zstd-with-trained-dictionary ceiling** (0.250 vs 0.248) while being
  **hand-decodable** on the watch: decode = Huffman bit-walk → token id → append the
  token's precomputed bytes to a `ByteArray`. **No back-references, no sliding window,
  no string concat.** Worst-case article decode ≈ 36 k ops → far under the watchdog.
- It **beats every other feasible candidate** (Huffman-0, fixed-width BPE, LZSS) on both
  ratio *and* decode simplicity. LZSS is both worse-compressing and harder to decode.
- The watch only ever **decodes**. Compression (BPE encode) runs server-side in the
  Python corpus pipeline. The watch needs only the static **token→bytes table + Huffman
  code-lengths** (the "model").

### The one open knob: BPE vocab size = ratio vs model size
The model ships **once** (baked into the .prg or downloaded once + stored), so its cost
is amortized to ~0 for download and is a one-time flash line item. Bigger vocab → better
ratio AND fewer tokens (cheaper decode), paying only in model size:

| vocab | dl% | flash(BA) incl. model | model | note |
|--:|--:|--:|--:|---|
| 2048 | 38 | 2.02 MB | 15 KB | safest/smallest model |
| 4096 | 36 | 1.92 MB | 36 KB | **balanced sweet spot** |
| 8192 | 35 | 1.85 MB | 80 KB | matches zstd ceiling; biggest model |

Even at 8192 the 80 KB model is ~4% of the bodies and tiny vs the 9 MB flash budget;
note net flash *decreases* with vocab because the better ratio outweighs the model. The
download gain flattens (38→35%) past 4096.

## What M10 buys (honest framing)
- **Download ≈ ⅓ of today** (7.13 MB → ~2.5 MB) → faster, more-reliable installs.
- **Body flash ~2 MB** (from 7 MB) → big headroom under the 9 MB cap.
- Enables later **raising the 14336-byte per-article truncation cap** for fuller articles.
- Does **NOT** raise the article-count ceiling (that's the separate load-time watchdog
  over the title index) — but it removes flash as a constraint for a future bigger corpus.

## Decision gate (for the user)
Pick: (1) algorithm = **E2 BPE+Huffman** (recommended), and (2) the vocab/model-size
point (recommend **4096**, or 8192 to match the zstd ceiling). A later, separate decision
for the watch milestone: ship the model **baked into the .prg** (simple; rebuild when the
corpus changes) vs **downloaded once** (flexible across corpus regens). Then the watch
decoder goes through the normal cr-tdd-ladder, with round-trip + watchdog proven on
hardware.

## Reproduce
```
python scripts/m10-compress/bakeoff.py --top-n 1200            # main frontier -> results/report.md
python scripts/m10-compress/bakeoff.py --top-n 1200 --bpe-sweep # vocab sweep -> results/report_bpe_sweep.md
```
