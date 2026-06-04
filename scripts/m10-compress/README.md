# M10 compression bake-off (PC-only)

Throwaway research harness. **Not shipped to the watch.** It measures candidate
compression algorithms on the *real* wikiwatch Hebrew corpus so we can pick ONE
algorithm before writing any Monkey C decoder.

## Why
Article bodies are stored uncompressed (UTF-8 String) and downloaded as plain JSON
today. M10 wants them compressed on the server, stored compressed on the watch, and
decompressed one-article-at-open. The watch has **no native compression** (no
zlib/deflate/gzip), so the decoder is hand-written in Monkey C — the algorithm choice
is hard to reverse. This harness de-risks that choice on the PC first.

**Primary metric: net DOWNLOAD footprint** (with the base64 transport tax charged in).
Secondary: net flash, per-article truncation-cap headroom. Hard gate: the decoder must
be re-implementable in Monkey C with a **buffer-based** decode (no string concat) and
stay comfortably under the watchdog.

## Run
```
python scripts/m10-compress/bakeoff.py --top-n 1200
# writes results/report.md + results/report.json
```

## What it proves
- Every *feasible* algorithm round-trips exactly on all N articles (hard gate).
- A comparison table: ratio, net download (base64-in-JSON), net flash (base64 vs raw
  ByteArray), model size shipped to the watch, decode ops/byte + worst-case (14 KB
  article) vs watchdog headroom.
- Reference rows (gzip, zstd+dict) bound the ratio frontier but are flagged
  not-feasible to hand-decode — they quantify what hand-decodability costs.

## Decision gate
The harness ends at `results/report.md`. The user picks ONE algorithm under the rubric
(min net download, subject to: round-trip PASS, feasibility easy/medium, worst decode
under watchdog, acceptable model size). That selection becomes the spec for the watch
decoder milestone (normal cr-tdd-ladder, proven on hardware).

## Candidates
A raw · B gzip/zlib+dict (ref) · C zstd+dict (ref) · D order-0 Huffman · E1 byte-BPE+fixed ·
E2 byte-BPE+Huffman · G LZSS+shared-dict(+Huffman). See `algos.py`.
