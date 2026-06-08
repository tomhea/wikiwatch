# M10.6 handoff — bigger corpus (2,800 read-ranked) + much faster download

> Self-contained brief for a future session. Ships the **read-ranked 2,800-article
> compressed corpus** + a **much faster install** on top of **v0.M10.5** (sliced
> index load, on the user's watch and confirmed working at 1,200). The M10.5 binary
> already decodes the new corpus — **the compression model is REUSED unchanged
> (modelVersion 1)**, verified byte-exact. The user has signed off on: **2,800
> articles**, **read-ranked by pageviews**, **no article-length-cap raise**, and a
> **faster download** as the headline feature.
> **Do NOT start until you've read §0 (workflow) and §3 (the v1-model-reuse method
> — get this wrong and the corpus won't decode on the shipped binary).**

## 0. Workflow (non-negotiable — cr-tdd-ladder)
Branch `m10-6-<slug>` off `main` → TDD (failing test first; R1 FAIL→PASS logs in the
PR body) → build → **all sim gates green** (`scripts/test.ps1`, `watchdog-check.ps1`,
`indexload-check.ps1`, and the NEW install gate from §5) → push → `gh pr create` →
invoke the **`crist`** subagent → fix to APPROVED (posted as a COMMENT review —
GitHub blocks self-approval; documented workaround) → archive
`versions/wikiwatch-M10.6.prg` → literal `git merge --no-ff` → `git tag v0.M10.6`
→ README row (`versions/README.md` quick-ref table) + ladder row (memory) → push.
See [[feedback-workflow]], `docs/cr-rules.md`, [[feedback-watchdog-gate]].

**M10.6 has TWO halves:** a **binary** change (concurrency + `-101` back-off, §2B)
AND a **server corpus** change (§2A). The binary ships as the tag; the corpus
(`docs/server/`) must be **uploaded to wikiwatch.tomhe.app** by the user. The watch
sees manifest **v17 > v16** → update prompt → wipe + reinstall the 2,800 corpus.
On-device confirmation happens on the tag.

## 1. Current state — what's already prepped (uncommitted in the working tree on `main`)
- `scripts/m8-corpus/fetch-pageviews.ps1` — pulls 12 months of Wikimedia
  `top/he.wikipedia` pageviews → `cached/pageviews-he.tsv` (4,340 articles, read-ranked).
- `scripts/m8-corpus/cached/selected.tsv` — read-ranked top **2,500** (re-run `select.ps1`
  at **2,800** for the real build, see §2A).
- `scripts/m8-corpus/cached/articles/` — **2,500 bodies already extracted** from the
  2026-04 ZIM (`C:\Users\tomhe\Downloads\wikipedia_he_top_nopic_2026-04.zim`); ~300 more
  to extract for 2,800.
- `scripts/m10-compress/corpus_stats.py` + `docs/m10-5-corpus-stats.md` +
  `cached/corpus-stats.tsv` — capacity analysis.
- `scripts/m10-compress/verify_v1_reuse.py` — **proves the v1 model is reusable** (§3).
- `bin/plainchunks/` — recovered old plain v15 bodies (throwaway; regenerate from git, §3).

**These prep files are intentionally NOT committed yet** — they land with the M10.6 PR.

## 2. The changes

### 2A. Server corpus: 2,800 read-ranked, compressed with v1, DENSELY packed
The win is **fewer download round-trips**. Today's chunks are only ~1/5 full: the
packer targets ~30 KB of *raw* body/chunk, then M10.1 compression shrank them to
~10–13 KB (measured: 254 chunks, median 10 KB, max 13.8 KB, ~4.7 articles/chunk) and
**never re-packed**. Re-packing the *compressed* bodies into dense chunks cuts the
chunk count massively → fewer BLE round-trips → much faster install.

Pipeline (mostly existing tooling in `scripts/m8-corpus/`, plus a NEW dense-pack step):
1. `select.ps1 -MaxArticles 2800 -TargetBytes <generous>` → read-ranked `selected.tsv`
   (auto-uses `cached/pageviews-he.tsv`). Assigns numeric ids 0..2799 in read-rank order
   (position == id == `article:<i>` key == `titles[i]`).
2. `extract.ps1 -SkipExisting` → `cached/articles/<urlencoded-id>.txt` (the ~300 not yet
   cached). Per-article cap stays **10 KB** (no length-cap raise — user decision).
3. **NEW dense-pack step** (build it — the current pack-plain-then-compress-in-place flow
   leaves chunks sparse; `compress_corpus.py` calls re-packing "a separate optimization"):
   - Load the **v1 model** per §3 (train on recovered plain bodies; assert == baked).
   - For each id 0..2799 in order: `blob = algos.bpeE2_compress(body, v1model)`;
     `b64 = base64(blob)`; **verify round-trip** `decode_with_parsed(parsed_baked, blob)
     == body.utf8` (decodability guarantee).
   - Pack the b64 bodies into **dense chunks** up to a **sim-tested byte target** (§4 gap 5):
     start ~40 KB raw JSON/chunk, find the `-402` ceiling empirically, back off with margin.
     Write `docs/server/chunk/N.json` = `{"articles":{"<id>":"<b64>",...}}`.
   - Pack the index dense too: `docs/server/index/K.json` = `[{id,title,popularity},...]`
     (still ≤ the response cap).
   - `gen-manifest`: **version 17**, `bodyCodec="bpe-huff-1"`, `modelVersion=1`,
     `chunkCount`, `indexCount`, `totalBytes`. (Tiny manifest, no `articles[]` — chunked path.)
4. Round-trip the WHOLE corpus through the parsed baked model before shipping (sha-style
   guarantee, like `compress_corpus.py` does today).

Expected: real compression is **~31%** of raw (verified, better than the 36.7% stats
estimate) → 2,800 articles ≈ ~7 MB stored, well under the 9 MB cap; chunk count should
drop well below today's 254-for-1,200 once packed dense.

### 2B. Binary: faster download via concurrency 4 + adaptive `-101` back-off
Download time ≈ round-trips × latency ÷ concurrency. Current in-flight cap is **2**
(`InstallPlan.maxInFlightForMemory` returns 1–2). Go to **4**, made safe against the
`BLE_QUEUE_FULL` (`rc=-101`) hazard (see §4 gap 6 and the dedicated note below):
1. `InstallPlan.maxInFlightForMemory(freeBytes)` → up to **4** when memory is plentiful
   (keep the low-memory step-down). Pure → unit-test the thresholds.
2. **Adaptive `-101` back-off** in the chunk-response path (`InstallView.onChunkResult`
   + `InstallController`): when `rc == -101`,
   - **re-queue the chunk WITHOUT incrementing its attempt count** (queue-full is not a
     real failure — today `markFailed` burns one of `MAX_ATTEMPTS=3`, which at 4-in-flight
     could exhaust a chunk's retries on queue-full alone → a MISSING article). Add e.g.
     `InstallController.markRequeue(n)` (eligible again, attempts untouched).
   - **ratchet the in-flight ceiling down by 1** (4→3→2, floor 2) for the rest of the
     install. So: optimistic 4 when the watch allows it, automatic graceful degradation
     when it returns `-101`. Pure back-off math → unit-test it.

**Why this is safe:** M9.1 already removed the *synchronous-retry recursion* that made
`-101` a crash (failures now re-queue and re-fire on the next event-loop turn). So `-101`
can no longer crash — it only costs a retry. The two changes above stop `-101` from
(a) burning the retry budget and (b) hammering a too-high concurrency, turning "4" into a
self-tuning "as fast as the watch allows."

## 3. CRITICAL — reuse the v1 model (do NOT re-bake, do NOT retrain on the new corpus)
The compression model is **baked into the .prg (modelVersion 1)** and is corpus-coupled.
`compress_corpus.py` reproduces it by retraining on `corpus.load_bodies(1200)` (which reads
`docs/server/chunk`) and asserts `== baked`. The new corpus's top-1200 are **different
articles**, so a naive retrain mismatches baked and the corpus would NOT decode on the
shipped binary.

**The method (verified — `verify_v1_reuse.py` proves it):**
1. Recover the EXACT old plain bodies: `git show b57ad96:docs/server/chunk/<N>.json` for
   all parts (`b57ad96` = last `codec=plain n=254` v15 corpus) into a temp dir
   (e.g. `bin/plainchunks/`). 254 files, 1,200 ids.
2. Train: load bodies 0..1199 from those plain chunks → `algos.bpeE2_train(bodies, 4096)`.
   `gen_model.build_model_bin(model, 1)` is **byte-identical to baked
   `resources/jsonData/model.json`** (sha `900395cf907baef1`). This IS the v1 encoder.
3. Use THAT model object to compress the new 2,800 bodies (§2A step 3). Byte-level BPE is
   lossless for any input, so new articles compress + round-trip fine (~31% of raw).
4. modelVersion stays **1**; `resources/jsonData/model.json` is **unchanged**; the M10.5
   binary decodes the new corpus with **no model/golden-test/binary-model change.**

If for any reason the recovered bodies don't reproduce baked, STOP and reconsider — the
fallback is a full v2 re-bake (new model resource + regenerated golden decode tests + new
watchdog blob + binary change), which the user has NOT signed up for.

## 4. Gaps / gotchas (found during planning — handle each)
1. **Model coupling — RESOLVED** via §3 (v1 reusable; verified).
2. **Watchdog at 2,800 is UNPROVEN on hardware.** M10.5 was confirmed at 1,200, where even
   the old unsliced load worked — so the sliced index load gets its first real high-N test
   here. Also **search scan is O(N) on a no-match keystroke** (M9.5 capped *matches* but a
   miss still scans all titles; proven at 1,000, 2,800 is 2.8×). Bound both in the sim
   (seed 2,800; confirm per-tick work is small) but the real watchdog proof is on-device.
   If search misbehaves at 2,800, slice/early-exit the scan harder.
3. **Resident index ~180 KB at 2,800** (titles+pops+normTitles) vs MemGuard's 150-KB
   open-article floor. Check headroom (Venu2 ~715 KB free); normTitles mostly aliases titles.
4. **Dense-pack tooling doesn't exist** — build the compress-then-pack-dense step (§2A.3).
5. **Response cap is contested + sim≠watch.** Memory note says ~13 KB (sim `-402`); packer
   assumes ~64 KB; current 13.8 KB chunks work on both. Find the real ceiling **empirically
   in the sim** (pack bigger, install, watch for `-402`), keep a safe margin, confirm on
   device. The cap is on the **decompressed** JSON response (gzip on the wire doesn't lift it).
6. **Concurrency 4 / `-101`** — handled by §2B's adaptive back-off + no-attempt re-queue.
7. **Bigger chunks → bigger per-response JSON-parse spike × concurrency → install peak
   memory.** Keep the memory-adaptive step-down; balance chunk size × concurrency. Watch
   `freeMemory` during the sim install (GC differs on the watch — M6.5 lesson).
8. **`watchdog-check.ps1`'s worst-case blob is the OLD `id=1143`** — re-point it to the new
   corpus's largest article (read it from the new `golden`/`selected` set).
9. **The sim measures round-trips + correctness, NOT BLE seconds.** The "faster download"
   deliverable is the **chunk-count reduction** (old 254-for-1,200 → new N-for-2,800) +
   a correct install; absolute seconds are confirmed on the watch.
10. **The rank 2,000–2,800 tail is low-read filler** (read-ranked tail thins out). Accepted
    by the user; just don't expect those to be high-value.

## 5. Verification
- **R1/R3 unit (`scripts/test.ps1`):**
  - `InstallController`: `-101` re-queue does NOT increment attempts; back-off lowers
    maxInFlight (floor 2); `maxInFlightForMemory` returns up to 4 above the threshold.
  - (v1 reuse already proven by `verify_v1_reuse.py`; keep it in `scripts/m10-compress/`.)
- **R2 sim — the NEW install gate (build `scripts/install-check.ps1`, modeled on the other
  `*-check.ps1`):** seed the manifest to the new v17 server (or a local fixture), run a full
  install in the sim, assert: **no `-402`/`-101`/crash**, **all 2,800 article bodies present
  + decodable**, and **print chunk count (old 254 → new N)** as the round-trip/speed proxy.
  (M7/M8 proved end-to-end sim installs work.)
- **R2 sim — `indexload-check.ps1`:** bump its synthetic index to **2,800**; confirm sliced
  load + search still pass.
- **R2 sim — `watchdog-check.ps1`:** re-point the worst-case blob; confirm green (streaming
  decode unaffected — model unchanged).
- **Hardware-only (call out explicitly in the PR + to the user):** watchdog at 2,800
  (sliced load + search scan), resident memory, the `-101` back-off trigger, and real BLE
  download speed. Confirmed on the `v0.M10.6` tag.

## 6. Key files
- `scripts/m8-corpus/select.ps1` — read-ranked selection (uses `cached/pageviews-he.tsv`).
- `scripts/m8-corpus/extract.ps1` — body extraction (`-SkipExisting`).
- `scripts/m8-corpus/pack-chunks.ps1` / `pack-index.ps1` / `gen-manifest.ps1` /
  `build-corpus.ps1` — packing/manifest tooling to EXTEND for dense compressed chunks.
- `scripts/m10-compress/{algos,gen_model,corpus}.py` — BPE+Huffman; `verify_v1_reuse.py`
  (v1 recovery), `corpus_stats.py` (capacity).
- `source/models/InstallPlan.mc` — `maxInFlightForMemory` (→ up to 4).
- `source/models/InstallController.mc` — `markFailed`/`MAX_ATTEMPTS`/`setMaxInFlight`;
  add `markRequeue` (no-attempt) + the back-off.
- `source/InstallView.mc` — `onChunkResult(n, rc, data)` (detect `rc==-101`, drive back-off);
  the `maxInFlightForMemory` re-eval each tick.
- `source/net/Downloader.mc` — `makeWebRequest` (where `rc` originates).
- `scripts/watchdog-check.ps1` — re-point worst-case blob; `scripts/indexload-check.ps1` →
  2,800; NEW `scripts/install-check.ps1`.
- Server output: `docs/server/{manifest.json,chunk/*.json,index/*.json}` → user uploads.

## 7. Status / decisions locked at handoff
- Shipped through **v0.M10.5** (sliced index load; user-confirmed on watch at 1,200).
  `main` clean; M10.x arc = compression → streaming open → eager parse → recents → sliced load.
- **Locked:** 2,800 articles · read-ranked by 12-month pageviews · NO length-cap raise ·
  **reuse v1 model** (no re-bake — verified) · faster download = **dense compressed chunks**
  + **concurrency 4 with adaptive `-101` back-off**.
- **Open micro-decisions for the build:** the exact dense-chunk byte target (find in sim),
  and how hard to slice/early-exit search if 2,800 stresses it on-device.
- Corpus is **server-side** — after merge+tag, the user uploads `docs/server/` to
  wikiwatch.tomhe.app; the watch wipe-reinstalls v17. On-device confirms watchdog + speed.
