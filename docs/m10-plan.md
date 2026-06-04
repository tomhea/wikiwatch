# M10 — Article-body compression (BPE-4096 + Huffman)

**Goal:** store article bodies **compressed** on the watch and decompress one article
at open-time. Cuts downloads to ~36% of today (7.13 MB → ~2.5 MB) and body flash to
~1.9 MB (from ~7 MB), and enables later raising the 14336-byte per-article cap. Does
**not** change the article-count ceiling (that's the separate load-time watchdog).

**Algorithm (decided via the PC bake-off — see `scripts/m10-compress/RECOMMENDATION.md`):**
byte-level **BPE, vocab 4096**, with **static Huffman over token ids**. It matched the
zstd-trained-dict ceiling (ratio 0.250) while being hand-decodable. The watch **only
decodes**; compression (BPE encode) stays server-side in the Python corpus pipeline.
The static model (token→bytes table + Huffman code-lengths, ~36 KB) is **baked into the
.prg** as a resource.

**Decode shape (the whole reason BPE+Huffman won):** base64 → `ByteArray` → Huffman
bit-walk yields a token id → append that token's precomputed bytes to an output
`ByteArray` → `StringUtil.utf8ArrayToString` ONCE at the end. No back-references, no
sliding window, **no `String + concat`** (the O(N²) OOM trap). Worst article ≈ 38 k
decode ops → far under the watchdog; decode is per-article-open (low risk).

> Split into two ladder milestones so the risky decoder lands proven-but-inert first,
> then the format flip is a small, hardware-verified step.

---

## M10.0 — `Decompressor` module + baked model + golden vectors (additive, no behavior change)

**Branch:** `m10-0-decompressor` · **Tag:** `v0.M10.0` · **Artifact:** `versions/wikiwatch-M10.0.prg`

Ships the decoder and the baked model, fully unit-tested against golden round-trip
vectors, but **not yet wired into the read path** — the app behaves exactly as today.
Zero user-visible risk; de-risks the hard part in isolation.

### PC side (extend `scripts/m10-compress/`)
- `gen_model.py` — train BPE-4096 + Huffman on the corpus; emit:
  - **`model.bin`** (watch resource): a compact binary = `[token count][Huffman code-length per token][token→bytes table: per-token (len, bytes)]`. Target ~36 KB. Define the exact byte layout here and keep it stable.
  - **`golden.json`** — N sample articles (mix of sizes incl. the largest), each as
    `{id, blob_b64, expected_text}` where `blob_b64` = base64(BPE+Huffman(body)). These
    are the TDD vectors the Monkey C decoder must reproduce **exactly**.
  - Reuse the validated `algos.py` E2 encoder/decoder as the reference.
- The model artifact lands as a Connect IQ resource (e.g. `resources/model/model.bin`,
  loaded via `WatchUi.loadResource` / `Toybox.Application.Resources`) — confirm the
  resource-blob load path + size limits when implementing.

### Watch side
| File | Change |
|---|---|
| `source/models/Decompressor.mc` (NEW) | Pure-ish decoder. `decompress(blob as ByteArray, model) as String`. Reads the Huffman canonical table + token→bytes table from the loaded model; bit-walk → token id → `buffer.addAll(table[id])`; final `StringUtil.utf8ArrayToString(buffer)`. Helpers: `_bitReader`, canonical `_decodeSymbol`. NO string concat. Lives in `models/` only if it imports just `Lang`/`StringUtil`; if it must `loadResource`, place it under `storage/` or pass the parsed model in. |
| `source/models/HuffTable.mc` (NEW, optional) | Parse code-length array → canonical decode structure (first-code-per-length + symbol lists), mirroring `algos.py:build_decode_table`. |
| model loader | Parse `model.bin` → `{tokenBytes: Array<ByteArray>, huff: decodeTable}` once at first use; cache module-level (avoid re-parsing per article). |

### TDD evidence (R1/R3)
- `source/tests/test_Decompressor.mc`: for each golden vector, `Decompressor.decompress(base64→ByteArray(blob_b64), model).equals(expected_text)`. **R1:** stub `decompress`→`""` (or wrong table) → vectors FAIL; implement → PASS. Include the largest-article vector (worst-case decode).
- A tiny hand-checked vector (e.g. "אבא" → known tokens) for a readable first test.
- **R2:** `monkeydo` stdout printing decode of one golden vector == expected (+ optional `freeMemory`/timing line) to show it runs in the sim. (Hardware decode timing is verified for real in M10.1 when it's wired to the UI.)
- **R8:** baked `model.bin` resource must not introduce build warnings; note .prg size growth (~+36 KB).

### Done when
Decoder passes all golden vectors on the sim, model is baked, app behavior unchanged. CR-ist → merge → tag `v0.M10.0`.

---

## M10.1 — wire compression end-to-end (corpus format + install + read), hardware-proven

**Branch:** `m10-1-compress-wire` · **Tag:** `v0.M10.1` · **Artifact:** `versions/wikiwatch-M10.1.prg`

Flips the corpus to compressed and routes read/write through the M10.0 decoder, behind a
**manifest format flag** so the binary stays backward-compatible with the current plain
(v15) corpus.

### Format flag (backward compatibility — critical)
- `manifest.json` gains `"bodyCodec": "plain" | "bpe-huff-1"` (default `plain` if absent).
- The binary reads it once and routes: `plain` → bodies used as today; `bpe-huff-1` →
  bodies are base64(compressed), decompress on open. So the M10.1 binary reads BOTH the
  existing v15 plain corpus AND a new compressed corpus. Ship the binary first, then flip
  the server corpus — never a window where an old binary meets a compressed corpus.

### Server / corpus pipeline (`scripts/m8-corpus/`)
| File | Change |
|---|---|
| `pack-chunks.ps1` (or a new `pack-chunks-compressed`) | per body: `blob = BPE+Huffman(body)`; emit `base64(blob)` as the article value. Re-pack to the ~30 KB/chunk target on the COMPRESSED+base64 size (more articles per chunk now). |
| `gen-manifest.ps1` | add `bodyCodec: "bpe-huff-1"`; bump version. |
| `gen_model.py` (M10.0) | the model is regenerated whenever the corpus changes; **since the model is baked into the .prg, a corpus/model change requires an app rebuild + re-tag** (call this out in the milestone + versions/README). |
| (decision) raise the 14336 cap in `corpus-lib.ps1` if we want fuller articles now that flash is cheap — optional, can be its own follow-up. |

> **Model/corpus coupling:** because the model is baked in, the shipped model and the
> served corpus must be trained together and versioned together. Add a model-version
> field to the manifest (`modelVersion`) and have the binary refuse/ignore a compressed
> corpus whose `modelVersion` ≠ the baked one (fall back to a safe message), so a
> mismatched server corpus can't silently produce garbage.

### Watch side
| File | Change |
|---|---|
| `Downloader.mc` / `Manifest.mc` | parse + persist `bodyCodec` (+ `modelVersion`). |
| `InstallView.mc` (`onChunkResult`, ~271-286) | store the body value **as received** (still a base64 String) via `ArticleStore.putBatch` — no change to putBatch itself; the value is just smaller. Byte-accounting (`InstallPlan.estimateBytes`) now sums the *compressed* base64 lengths (already smaller → budget rarely binds). |
| `ArticleStore.mc` | unchanged storage (String key `article:<id>`); the stored String is now base64(compressed). (Open question still: storing a decoded `ByteArray` instead of base64 String would save the +33% flash — measure/decide; base64-String is the safe default.) |
| read path: `ResultsDelegate.mc:23`, `wikiwatchKeyboardDelegate.mc:141` | after `ArticleStore.bodyOf(id)`: if `bodyCodec == bpe-huff-1`, `body = Decompressor.decompress(StringUtil base64→ByteArray(stored), model)`; else use as-is. Then `new wikiwatchView(body, id)` as today. |

### TDD evidence
- **R1/R3:** corpus-tooling tests (`scripts/m8-corpus/test.ps1`) for the compressed pack
  (chunk sizes, base64 validity, manifest `bodyCodec`/`modelVersion`); a watch test that
  `bodyOf` → decompress round-trips a stored compressed body to expected text (reuse a
  golden vector through the storage layer).
- **R2 (the real proof, on HARDWARE):** install the compressed corpus on the Venu 2;
  open several articles incl. the largest; confirm **correct Hebrew renders** and **no
  watchdog** on open; read the free-mem HUD. Confirm install download is visibly smaller.
- **R8:** clean build.

### Done when
Compressed corpus installs and every opened article renders correct Hebrew with no
watchdog on real hardware; backward-compat with a plain corpus verified. CR-ist → merge
→ tag `v0.M10.1`. Then regenerate + upload the compressed corpus; sideload the binary.

---

## Open questions to resolve during implementation
1. **Resource blob load:** confirm how to bake `model.bin` as a CIQ resource and read it
   as bytes (`Rez`/`loadResource` returning a `ByteArray`?), and any per-resource size cap.
2. **Storage as ByteArray vs base64 String:** does `Application.Storage` accept a raw
   `ByteArray`? If yes, store the decoded compressed bytes (saves the +33% flash vs base64
   String). If unsure, ship base64-String (safe) and optimize later.
3. **Model parse cost / residency:** parse `model.bin` once and cache; ensure the ~36 KB
   token table resident during a decode is within RAM budget (it is, vs ~8 MB free heap).
4. **Transport base64 tax:** bodies ride as base64 in the JSON chunk (+33%). Net download
   still ~36% of today. A non-JSON response type could drop the tax later — out of scope.

## Hard-won constraints (do not relearn)
- **Never build a String via `s = s + ch` in a loop** — O(N²) allocations → uncatchable
  OOM (killed M6.2). Decode into a `ByteArray`/`Array<Number>`, convert ONCE.
- **OOM and flash-overflow are uncatchable**; the watchdog ("Code Executed Too Long") is
  per-handler. Per-article decode is low-risk but keep it O(output), no per-symbol heap
  churn.
- **Simulator ≠ watch** for memory/watchdog/storage — any such claim is hardware-only.
- Build text files with `[System.IO.File]::WriteAllText(path, content, UTF8Encoding($false))`
  (no BOM) — `Out-File -utf8` adds a BOM that breaks `monkeyc`.
- R1 stubs go in source files (`return ""` / dummy), backed up to `%TEMP%/wwbak/`, **never**
  in a `.cache/` subdir (the jungle compiles all `.mc` recursively → "Redefinition").

## Prereq / sequencing note
**M9.6 is still open** (branch `m9.6-full-corpus`): the "stored X / 1462" readout fix +
the 1200-article (v15) cap are committed but await the user's hardware re-test (install
v15, confirm graceful + correct readout + fast search). M9.6 touches the same install/read
paths M10.1 will, so **land M9.6 first** (hardware-proof → crist → merge → tag `v0.M9.6`),
then branch M10.0 off the merged main.
