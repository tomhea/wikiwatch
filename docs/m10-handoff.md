# M10 handoff — article-body compression (for a future session)

> Self-contained brief to execute M10. Read this, then `docs/m10-plan.md` (the
> detailed per-file plan) and `scripts/m10-compress/RECOMMENDATION.md` (the
> bake-off result). The algorithm is already chosen and validated on PC; what's
> left is the watch implementation.

## 0. Orientation (project + workflow)
- **wikiwatch** = offline Hebrew Wikipedia reader for the Garmin Venu 2/3 (Monkey C / Connect IQ). Repo: `C:\Users\tomhe\Documents\Garmin\wikiwatch`, Windows + PowerShell 7. GitHub `tomhea/wikiwatch`.
- **Workflow (cr-tdd-ladder, non-negotiable):** branch from `main` → write the failing test FIRST → R1 evidence (test.ps1 FAIL then PASS, captured by stubbing the new fn) → R2 evidence (sim screenshot or `monkeydo` stdout for any UI change) → `scripts/build.ps1` → push → `gh pr create` → invoke the **`crist`** subagent with the PR number (reviews vs `docs/cr-rules.md` R1–R8) → on APPROVED do a literal `git merge --no-ff` → `git tag -a v0.MX.Y` → archive `versions/wikiwatch-MX.Y.prg` + add a row to `versions/README.md` (record the merge-commit hash) → push main + tag. Then the user uploads `docs/server/` to wikiwatch.tomhe.app and sideloads the `.prg`.
- **CR rules cheat-sheet:** R1 FAIL+PASS in PR body; R2 sim/hardware evidence for views; R3 a `(:test)` per new fn under `source/models|storage|net`; R4 freeMemory guard before every `Application.Storage.setValue`; R5 freeMemory guard before any >~4 KB alloc; R6 pure logic (imports only Lang/Math) lives in `source/models/`; R7 branch/title format; R8 build clean vs `docs/known-warnings.md`.
- Status as of this handoff: shipped through **v0.M9.7**, `main` is clean, 317 `(:test)` passing. **Start M10 from a fresh branch off `main`.**

## 1. Goal
Ship article bodies **compressed**: server stores `base64(compressed(body))` per article, the watch stores it compressed and **decompresses one article at open-time**. Net wins (measured on the real top-1200 corpus): **download ≈ 36 % of today** (7.13 MB → ~2.5 MB) and **body flash ≈ 1.9 MB** (from ~7 MB). Also unlocks raising the 14336-byte per-article truncation cap for fuller articles.

**Honest scope:** body compression does NOT raise the article-COUNT ceiling — that's a separate *load-time watchdog* over the title index (`IndexStore.loadCompact` + `_normTitles` over all N titles in `wikiwatchKeyboardDelegate`/`IndexCache`), which scales with title count, not body bytes. M10 is a download/flash win + an enabler for a bigger corpus *after* the load-watchdog is separately addressed. Do not claim "more articles" as an M10 result.

## 2. The decision (already made — don't re-litigate)
A PC bake-off (`scripts/m10-compress/`, Python, throwaway; 9 algorithms on the real top-1200 corpus, every feasible one round-trips exactly) picked:

- **Algorithm: byte-level BPE (vocab 4096) + static Huffman over token ids.** It matches the zstd-trained-dict ceiling (ratio ~0.27 at vocab 4096; 0.25 at 8192) while being *hand-decodable* on the watch. Beat plain Huffman-0, fixed-width BPE, and LZSS on ratio AND decode simplicity.
- **Vocab = 4096** (download 36 %, flash ~1.92 MB, model ~36 KB). 2048 = smaller model/worse ratio; 8192 = best ratio/80 KB model — all valid, 4096 was chosen as the knee.
- **Model delivery: BAKED INTO THE `.prg`** as a resource (~36 KB).
- **The watch only DECODES.** BPE *encoding* stays server-side in the Python pipeline.

**Decode shape (why BPE+Huffman won):** `base64 → ByteArray → Huffman bit-walk → token id → append that token's precomputed bytes to an output ByteArray → StringUtil.utf8ArrayToString ONCE`. No back-references, no sliding window, **no `String + concat`**. Worst article (14 KB) ≈ tens of thousands of ops → far under the watchdog; decode is per-article-open (low risk).

The Python reference encoder/decoder in `scripts/m10-compress/algos.py` (candidate **E2**, `bpeE2_*`) is the validated source of truth — mirror its decode exactly in Monkey C, and reuse its model as golden test vectors.

## 3. Mini-versions (two ladder milestones)
Split so the risky decoder lands proven-but-inert first, then the format flip is small + hardware-verified. Full per-file detail in `docs/m10-plan.md`.

### M10.0 — `Decompressor` + baked model + golden vectors (additive, no behavior change)
Branch `m10-0-decompressor` · tag `v0.M10.0`.
- **PC:** add `scripts/m10-compress/gen_model.py` — train BPE-4096 + Huffman on the corpus; emit (a) `model.bin` (compact binary: token count, per-token Huffman code-length, token→bytes table — define + FREEZE the byte layout), and (b) `golden.json` = N sample articles `{id, blob_b64, expected_text}` to TDD the Monkey C decoder against. Reuse `algos.py` E2 as the reference.
- **Watch:** `source/models/Decompressor.mc` (+ a `HuffTable` helper if useful). `decompress(blob as ByteArray, model) as String` — buffer-based, single final `utf8ArrayToString`. Bake `model.bin` as a CIQ resource; parse it ONCE and cache module-level.
- **Decoder is NOT wired into the read path yet** — app behaves exactly as today. Zero risk.
- R1: stub `decompress`→`""` → golden-vector tests FAIL → implement → PASS. R2: `monkeydo` stdout decoding one golden vector == expected. R8: note ~+36 KB `.prg` growth.

### M10.1 — wire compression end-to-end (corpus + install + read), hardware-proven
Branch `m10-1-compress-wire` · tag `v0.M10.1`.
- **Format flag (backward-compat, critical):** `manifest.json` gains `"bodyCodec": "plain" | "bpe-huff-1"` + a `modelVersion`. The binary reads it and routes: `plain` → today's path; `bpe-huff-1` → decompress on open. Ship the binary FIRST (understands both), THEN flip the server corpus — never a window where an old binary meets a compressed corpus. The binary must refuse/ignore a compressed corpus whose `modelVersion` ≠ the baked one (safe fallback, no garbage).
- **Server pipeline (`scripts/m8-corpus/`):** `pack-chunks` emits `base64(BPE+Huffman(body))` as each article value; `gen-manifest` adds `bodyCodec`/`modelVersion` + bumps version. **Because the model is baked in, a corpus/model retrain ⇒ app rebuild + re-tag** — call this out in the milestone + README.
- **Watch:** `Downloader`/`Manifest` parse + persist `bodyCodec`/`modelVersion`. `InstallView.onChunkResult` stores the body value as received (now smaller base64 String) via `ArticleStore.putBatch` — unchanged. Read path: after `ArticleStore.bodyOf(id)` in `ResultsDelegate` (~line 23) and `wikiwatchKeyboardDelegate` (~line 141 region, the suggestion-open), if `bodyCodec==bpe-huff-1` then `body = Decompressor.decompress(base64→ByteArray(stored), model)`; else use as-is. Then `new wikiwatchView(body, id)`.
- Optional: raise the 14336 cap in `scripts/m8-corpus/corpus-lib.ps1` now that flash is cheap (own follow-up; M10 only quantifies the headroom).
- R2 is **hardware**: install the compressed corpus, open several articles incl. the largest, confirm correct Hebrew renders + no watchdog on open; verify a plain corpus still works (backward-compat). R8 clean.

## 4. History (how we got here)
- M0–M5: scaffold, circular Hebrew T9 keyboard, live search, markdown reader.
- M6.x: long-press word → search; **OOM lesson** — O(N²) `String + concat` per keystroke killed the app (M6.2→M6.3).
- M7: real network corpus from wikiwatch.tomhe.app (manifest + per-article fetch).
- M8: real Hebrew Wikipedia ZIM corpus + chunked install.
- M9: manifest-chunking (index parts + body chunks) to scale past the ~12 KB single-response cap → ~1462 articles.
- M9.1–M9.5: a string of real-watch crash fixes — install stack-overflow, search **watchdog** (made search N-independent), GC-stall post-install freeze (compact parallel-array index), **BootGuard/SafeMode** anti-crash-loop harness, 9 MB install budget.
- M9.6: **stabilize at 1200 articles** — the full 1462 tripped a *load-time watchdog*; capped to 1200 (v15). Fixed the "stored X/N" readout, added `IndexCache` (load index once, shared across keyboards — fixed a long-press crash), added `MemGuard` (refuse view pushes under 150 KB free).
- M9.7: UX polish + **close-app** (long-press physical back → KEY_MENU → modal → System.exit).
- **M10 (this):** compression. The bake-off + algorithm decision are done; only the watch implementation remains.

## 5. Hard-won lessons (do not relearn)
- **NEVER build a String with `s = s + ch` in a loop** — O(N²) heap allocations → uncatchable OOM (killed M6.2). Decode into a `ByteArray`/`Array<Number>` and convert ONCE with `StringUtil.utf8ArrayToString`. This is THE rule for the decoder.
- **OOM and flash-overflow are UNCATCHABLE** (no try/catch). Guard with `System.getSystemStats().freeMemory` before big allocs (R4/R5). The watchdog ("Code Executed Too Long") is per-event-handler — per-article decode is low risk, but keep it O(output), no per-symbol heap churn.
- **Simulator ≠ watch.** The sim doesn't enforce the watchdog, flash quota, or true GC/memory pressure. Any claim about memory/speed/storage/keys is **hardware-only** — the user must confirm on the Venu 2. (E.g. the M9.7 close-app key code was only discoverable on-device.)
- **No native compression on Connect IQ** (no zlib/deflate/gzip). Available: `Toybox.Lang.ByteArray` (add/addAll/slice/index/decodeNumber), bitwise ops (`& | ^ << >>`), `String.toCharArray`, `Char.toNumber/toString`, `StringUtil.convertEncodedString` (base64/hex↔ByteArray/String), `StringUtil.utf8ArrayToString`.
- **Transport tax:** chunks are fetched as `HTTP_RESPONSE_CONTENT_TYPE_JSON` → auto-parsed to `Dictionary<String,String>`, so compressed bytes must ride as **base64 (+33 %)** inside the JSON. The 36 % net-download figure already includes this. `Application.Storage` stores Strings; storing a raw `ByteArray` (to avoid the +33 % in flash) is an OPEN QUESTION — ship base64-String (safe) and optimize later if confirmed.
- **Tooling gotchas:** build text files with `[System.IO.File]::WriteAllText(p, c, [System.Text.UTF8Encoding]::new($false))` (no BOM — `Out-File -utf8` adds a BOM that breaks `monkeyc`). R1 stubs go in source files (`return ""`/dummy), backed up to `%TEMP%/wwbak/`, **never** in a `.cache/` subdir (the jungle compiles all `.mc` recursively → "Redefinition"). `monkeydo` uses Windows-style `/t`.
- **Simulator screenshots are flaky** (needed for R2): the sim `MainWindowHandle` is 0 until a window exists; PowerShell 7's `System.Drawing.Common` won't compile inside `Add-Type -TypeDefinition` (split the user32 P/Invoke into C# and do the `Bitmap` in pure PS); repeated launches trip M9.4 SafeMode (unfinished-boot counter) so the app may not reach the keyboard. Recipe that worked for M9.7: relaunch the sim via `<sdk>/bin/connectiq.bat`, wait ~12 s, `monkeydo <prg> venu2`, then `PrintWindow(handle, hdc, 2)` on the simulator window. To force a specific screen, temporarily bypass `getInitialView` + set the view flag, screenshot, then revert. **Prefer a `monkeydo` stdout artifact over a screenshot when the claim isn't pixel-level.**

## 6. Do / Avoid (M10-specific)
**Do:**
- Mirror `algos.py` E2 decode byte-for-byte in Monkey C; use its model as golden vectors so the watch decoder is provably correct before it's wired in (that's the whole point of the M10.0/M10.1 split).
- Freeze the `model.bin` byte layout early and document it (encoder + decoder must agree forever; the baked model and served corpus are versioned together via `modelVersion`).
- Keep the decoder pure-ish + buffer-based; parse the model once and cache.
- Ship the M10.1 binary (handles both `plain` and `bpe-huff-1`) BEFORE flipping the server corpus.

**Avoid:**
- Any `String + concat` in the decoder (see lessons).
- Decompressing at INSTALL time / storing decompressed (decode 1200 bodies in one go = watchdog/flash blowup, and loses the flash win). Store compressed; decode per-open.
- Claiming M10 lets you ship more articles (it doesn't — that's the load-watchdog, separate).
- Re-running the bake-off / second-guessing the algorithm — it's decided (BPE-4096 + Huffman, baked).

## 7. Key files
- `docs/m10-plan.md` — the detailed per-file M10.0/M10.1 plan.
- `scripts/m10-compress/RECOMMENDATION.md` + `results/report*.md` — the bake-off frontier + decision.
- `scripts/m10-compress/algos.py` — validated Python reference (candidate **E2** = BPE+Huffman). Reuse for `gen_model.py` + golden vectors.
- `scripts/m10-compress/corpus.py` — loads the real corpus from `docs/server/chunk/*.json`.
- `source/storage/ArticleStore.mc` — per-article store/read (String today; ByteArray storability = open question).
- `source/InstallView.mc` (`onChunkResult` ~271-286) — chunk write path.
- `source/ResultsDelegate.mc` (~23) + `source/wikiwatchKeyboardDelegate.mc` (suggestion-open) — `bodyOf()` read path (decode hooks here).
- `source/net/Downloader.mc` + `source/storage/Manifest.mc` — manifest/`bodyCodec` parsing.
- `scripts/m8-corpus/` (`pack-chunks*`, `gen-manifest.ps1`, `build-corpus.ps1`) — server pipeline.
- `scripts/m8-corpus/corpus-lib.ps1:~268` — the 14336-byte cap.

## 8. Verify the bake-off (reproduce the decision)
```
python scripts/m10-compress/bakeoff.py --top-n 1200             # frontier -> results/report.md
python scripts/m10-compress/bakeoff.py --top-n 1200 --bpe-sweep # vocab sweep -> results/report_bpe_sweep.md
```
Then start M10.0: `git checkout main && git pull && git checkout -b m10-0-decompressor`.
