# M10 compression bake-off — results
Corpus: top-1200 articles, 1200 bodies, raw UTF-8 7.05 MB (avg 5877 B, max 7680 B). Today's raw chunk-JSON download: 7.13 MB.

**Primary metric: net download** (base64-in-JSON, incl. the +33%% transport tax). `dl%%` = net download vs today's raw download. Flash shown both as raw ByteArray (if Storage accepts it) and base64 String (today's storage type). `model` ships once. Decode cost is per-article-open.

| algo | feas | ratio | dl% | net_dl MB | flash(BA) MB | flash(b64) MB | model KB | dec ops/B | worst ops | wd | ms/art | rt |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|:--:|--:|:--:|
| E2 bpe8192-huff | easy | 0.250 | 35 | 2.48 | 1.85 | 2.44 | 80 | 3.19 | 36101 | LOW | 2.836 | PASS |
| E2 bpe4096-huff | easy | 0.267 | 36 | 2.57 | 1.92 | 2.55 | 36 | 3.34 | 38479 | LOW | 2.963 | PASS |
| E2 bpe2048-huff | easy | 0.284 | 38 | 2.71 | 2.02 | 2.69 | 15 | 3.51 | 41359 | LOW | 3.2 | PASS |
| E2 bpe1024-huff | easy | 0.304 | 40 | 2.88 | 2.15 | 2.87 | 6 | 3.71 | 44958 | LOW | 3.332 | PASS |
| E2 bpe512-huff | easy | 0.332 | 44 | 3.13 | 2.34 | 3.12 | 2 | 4.00 | 48846 | LOW | 3.565 | PASS |

*feas* = hand-decode feasibility on the watch (reference rows can't win). *wd* = watchdog margin for the worst (largest) article decode. *rt* = exact round-trip over all N.
