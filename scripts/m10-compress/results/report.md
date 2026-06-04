# M10 compression bake-off — results
Corpus: top-1200 articles, 1200 bodies, raw UTF-8 7.05 MB (avg 5877 B, max 7680 B). Today's raw chunk-JSON download: 7.13 MB.

**Primary metric: net download** (base64-in-JSON, incl. the +33%% transport tax). `dl%%` = net download vs today's raw download. Flash shown both as raw ByteArray (if Storage accepts it) and base64 String (today's storage type). `model` ships once. Decode cost is per-article-open.

| algo | feas | ratio | dl% | net_dl MB | flash(BA) MB | flash(b64) MB | model KB | dec ops/B | worst ops | wd | ms/art | rt |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|:--:|--:|:--:|
| C zstd+dict64k | reference | 0.248 | 34 | 2.44 | 1.82 | 2.40 | 64 | 1.00 | 7680 | LOW | 0.017 | PASS |
| E2 bpe2048-huff | easy | 0.284 | 38 | 2.71 | 2.02 | 2.69 | 15 | 3.51 | 41359 | LOW | 3.181 | PASS |
| B zlib+dict32k | reference | 0.296 | 40 | 2.84 | 2.12 | 2.82 | 32 | 1.00 | 7680 | LOW | 0.024 | PASS |
| E1 bpe2048-fixed | easy | 0.325 | 43 | 3.09 | 2.31 | 3.07 | 13 | 3.84 | 45036 | LOW | 2.618 | PASS |
| B gzip | reference | 0.345 | 46 | 3.26 | 2.43 | 3.25 | 0 | 1.00 | 7680 | LOW | 0.034 | PASS |
| G lzss+dict+huff | medium | 0.370 | 49 | 3.50 | 2.62 | 3.49 | 4 | 6.95 | 60359 | LOW | 7.051 | PASS |
| G lzss+dict | medium | 0.374 | 50 | 3.54 | 2.64 | 3.52 | 4 | 3.99 | 34191 | LOW | 3.304 | PASS |
| D huffman0 | easy | 0.481 | 64 | 4.54 | 3.39 | 4.52 | 0 | 4.85 | 53945 | LOW | 5.514 | PASS |
| A raw-utf8 | easy | 1.000 | 132 | 9.42 | 7.05 | 9.41 | 0 | 1.00 | 7680 | LOW | 0.0 | PASS |

*feas* = hand-decode feasibility on the watch (reference rows can't win). *wd* = watchdog margin for the worst (largest) article decode. *rt* = exact round-trip over all N.
