# M11 handoff — ~20,000 articles via tiered bodies (full + ~250-byte summaries)

> Self-contained brief for a future session. The user wants **much more articles
> on the watch — ~20,000** (vs the current 2,800), accepting that most are tiny
> "summary" stubs as long as the content is still useful. The mechanism (user's
> idea, 2026-06-07): **tier the body size by popularity** — keep the most-read
> articles as full bodies, and store the long tail as ~250-byte lede summaries.
> 20k × ~250 B ≈ 5 MB of tail + the popular full bodies in the rest of the budget.
>
> **READ §2 FIRST.** Research this session (measurements below) found the idea is
> sound for STORAGE but that storage was never the real ceiling — the **on-watch
> search index** is. At 20k, the current "load every title into RAM" search needs
> **~920 KB of heap (the watch has ~700 KB free)**. So the headline work of M11 is
> **not** the summaries — it's a search index that scales to 20k without holding
> all titles in RAM. The summaries are the easy half.

## 0. Workflow (non-negotiable — cr-tdd-ladder)
Same as every milestone: branch `mN-slug` off `main` → TDD (failing test first, R1
FAIL→PASS in the PR body) → build (`scripts/build.ps1`; **outputs to `C:\Temp` —
see [[reference-toolchain]], monkeyc can't write under the repo tree**) → all sim
gates green (`test.ps1`, `watchdog-check.ps1`, `indexload-check.ps1`,
`install-check.ps1 -SimPackKB 16`) → push → `gh pr create` → invoke the **`crist`**
subagent → fix to APPROVED → archive `versions/wikiwatch-MN.prg` → literal
`git merge --no-ff` → `git tag v0.MN` → README row + ladder memory. See
[[feedback-workflow]], `docs/cr-rules.md`, [[feedback-watchdog-gate]],
[[reference-install-check-sim-cap]].
Current head: **v0.M10.8** (close-app everywhere + install telemetry); live corpus
**v19** = 2,800 articles, 169 chunks @ 48 KB (the M10.7 corpus, re-versioned).

## 1. The idea (user, 2026-06-07)
- Goal: ~**20,000** articles on the watch.
- Mechanism: **tiered body sizes.** Top-read articles = full bodies; the long tail
  = ~250-byte summaries ("if I can narrow an article to ~250 B, 20k = ~5 MB, and
  fit the most-read in the other ~4 MB"). Big articles use more bytes, lesser-known
  ones fewer.
- "I do want much more articles, even if small, as long as their content is still
  important." Quality of the *important* bit matters; exhaustiveness doesn't.
- Open question the user flagged: **"I don't know how to decide what 250 bytes are
  best."** → §3A answers this (the lede).

## 2. CRITICAL reframe — storage was never the ceiling; the SEARCH INDEX is
Measured this session (`scripts/m11-summaries/measure_summary.py`, v1 model on
truncated ledes from the 2,800 cached bodies):

**Storage: the 250-byte idea works, with room to spare.**
| lede raw budget | stored (compressed b64) | ratio | articles in 8 MB |
| --- | --- | --- | --- |
| 256 B | ~116 B | 45% | ~59,000 |
| 512 B | ~207 B | 40% | ~35,600 |
| **~640 B** | **~250 B** | ~40% | **~28,000** |
| 768 B | ~296 B | 39% | ~25,500 |
| 1024 B | ~387 B | 38% | ~19,800 |
To hit **~250 stored bytes → ~640 raw bytes** of lede (≈ 2–3 sentences). Short-text
compression (~40–45%) is worse than full-article (~37%) but fine. **25k+ summaries
fit in 8 MB.** Storage is NOT the constraint for 20k.

**RAM: the resident search index is the wall.** The keyboard loads ALL titles into
RAM (`IndexCache` builds parallel `titles[]/pops[]/normTitles[]`) for prefix+
substring search:
| titles | resident RAM | |
| --- | --- | --- |
| 2,800 | ~130 KB | ✅ (today) |
| 5,000 | ~230 KB | ⚠️ |
| 10,000 | ~460 KB | ⚠️ leaves <240 KB for everything else |
| **20,000** | **~920 KB** | ❌ **exceeds the ~700 KB free heap** |
Venu 2 free heap ≈ 700 KB; MemGuard refuses opens below a 150 KB floor; the keyboard
+ streaming decode + open article also need heap. The load-all-titles design dies
somewhere around **5–8k**. **20k is impossible without a new index.** (This is the
same family of limit as the M9.6→M10.5 saga — the index-load watchdog at ~1462 and
the sliced load to reach 2,800 — but now it's the *resident bytes*, not just the
one-shot load time.)

**Conclusion:** M11's headline deliverable is a **search index that scales to 20k
without holding all titles in RAM** (§3B). The tiered summaries (§3A) are the easy,
low-risk half. Do NOT start the corpus work expecting it to be the hard part.

## 3. The two halves

### 3A. Server: tiered corpus generation (the EASY half)
- **Tier 1 — full bodies:** top ~800–1,000 by 12-month pageviews (the
  `cached/pageviews-he.tsv` ranking already wired into `select.ps1`). Current 10 KB
  raw cap → ~2.86 KB stored each → ~1,000 × 2.86 KB ≈ ~2.9 MB.
- **Tier 2 — ~250-byte summaries:** the next ~19,000 articles → the **lede**
  truncated to ~640 raw bytes → ~250 B stored → ~19,000 × ~268 B (incl. key) ≈
  ~5.1 MB.
- **Index storage** (20k titles+pops, bucketed per §3B): ~0.5 MB.
- Total ≈ **~8.5 MB** — tune the tier-1 count / tail length to land under the
  proven-safe ~8 MB (the user's 5 MB-tail / 4 MB-popular split is the right shape;
  exact numbers above).
- **HOW to pick the ~250 bytes (the user's open question): the LEDE.** Wikipedia's
  first paragraph is a definitional summary by construction ("X הוא/היא … " = "X is
  a …"). Take the first paragraph of the extracted markdown, **truncate to ~640 raw
  bytes at a sentence boundary** (fall back to a word boundary). Simple,
  deterministic, no LLM, high-quality for the "what is this" use case. The extract
  pipeline already produces markdown (`extract.ps1` → `Convert-WikiHtmlToMarkdown`),
  so this is a small per-article truncation step + a per-tier cap.
  - **Fallbacks:** disambiguation pages, list articles, and stubs have weak/empty
    first paragraphs — detect (very short / list-only) and either skip them from the
    tail or keep the title-only. Wikidata/Wikipedia "short description" one-liners
    are an alternative source if available for Hebrew.
  - **Upgrade path (later, not v1):** LLM abstractive summaries (server-side) — better
    prose for ~250 B, but a heavy 20k-article pass; not needed if lede truncation is
    good enough. Decide after eyeballing a sample of lede summaries.
- **Selection to 20k:** pageviews rank only ~4,340 articles; fill the tail from the
  ~**57,463** ZIM candidates (`cached/candidates.tsv`, the `_top_`-curated Hebrew
  Wikipedia) by ZIM curation / size. The tail is "less known" by definition — the
  user accepts this. (A fuller/newer ZIM would be needed for hyper-recent topics;
  out of scope.)
- **Compression: REUSE the v1 model** (no re-bake) — byte-level BPE compresses the
  short ledes fine (measured ~40–45%). The shipped binary decodes them with no
  model/golden/binary change, exactly like M10.6/M10.7. (`modelVersion` stays 1.)
- **Manifest:** bump version (v20+). Consider a per-article **tier flag** (or a
  count split) so the reader can label a stub "(summary)".

### 3B. Binary: a 20k-scale search index (the HARD half — the real work)
The problem: can't hold 20k titles in RAM (~920 KB) and can't scan 20k per keystroke
(watchdog). Need an index that loads **only what a query needs**.

**Recommended approach — prefix-bucketed, load-on-demand:**
- Partition titles into buckets by leading character (22 Hebrew letters → ~900
  titles/bucket on average for 20k). Store each bucket as its own Storage part
  (downloaded at install). One bucket ≈ ~900 titles ≈ ~42 KB resident — fits easily.
- On the **first keystroke**, load only the bucket for that prefix letter into RAM
  + search within it. As more letters are typed, filter the already-loaded bucket
  (cheap, ≤ bucket size). Switching first letter swaps the resident bucket.
- Bounds **RAM** (one bucket, not 20k) and the **watchdog** (search ≤ bucket size).
- **Tradeoff — substring search goes away at scale.** Today's tier-2 (substring-not-
  prefix) match needs to scan all titles; impossible at 20k. Either drop substring
  (prefix-only search — type the *start* of the title) or limit substring to the
  loaded bucket. **CONFIRM with the user that prefix-only is acceptable at 20k**
  (very likely yes for 7× the articles; Hebrew search is prefix-first anyway).
- This replaces the load-all `IndexCache`/`IndexStore.loadCompact` path. `Recents`
  (empty-buffer view) is unaffected (doesn't need the index).
- **Alternative if buckets are uneven** (some Hebrew letters are very common):
  sub-bucket by the first *two* characters, or fixed-size sorted shards with a small
  in-RAM "shard directory" (first-title-per-shard) + binary-search to the right
  shard, load it, search it. Same RAM/watchdog bound, more even.

**Storage-shape decision (affects key count — see gap 2):**
- Keeping per-article keys (`article:<id>`) → **20k+ Storage keys**. Unknown if CIQ
  `Application.Storage` tolerates that many (and per-key overhead × 20k ≈ 300 KB).
- **Option: pack summaries into blocks** (e.g. 50 summaries per Storage value, keyed
  by block) → ~400 keys instead of 20k; article-open reads the block + extracts.
  Sidesteps the key-count risk at the cost of a block-read indirection on open.
  **Decide early** — it shapes the install + the reader.

## 4. Gaps / risks (handle each — the index ones are the milestone)
1. **Resident-index RAM + watchdog at 20k** — the centerpiece (§3B). Prototype the
   bucketed search at 20k *synthetic* titles in the sim AND prove the bucket-load is
   watchdog-safe on hardware BEFORE committing to the corpus.
2. **CIQ `Application.Storage` key-count limit at ~20k keys — UNKNOWN.** Could cap the
   article count regardless of bytes; also lookup/write perf with 20k keys. Verify on
   hardware early (write N keys, time getValue, watch for failure). The block-packing
   option (§3B) is the mitigation.
3. **Install of 20k articles:** ~20k `setValue` calls (slow install + watchdog during
   writes) + the download (~6–8 MB, ~150–200 chunks @ 48 KB — comparable to today;
   summaries pack ~190/chunk). Measure install time; the M9.5 budget guard + battery
   guard still apply. Block-packing also cuts the write count.
4. **Short-text compression ratio** — measured ~40–45% (vs 37% full). Folded into the
   §2 budget; re-confirm on the real summary set.
5. **Lede quality / fallbacks** — disambig/list/stub first paragraphs (gap handled in
   §3A). Eyeball a sample before shipping 19k of them.
6. **Search UX downgrade** — prefix-only (no global substring) at 20k. CONFIRM
   acceptable (§3B).
7. **The rank 5k–20k tail has no pageview signal** — ranked by ZIM curation/size;
   quality varies. Accepted by the user ("less known, less words").
8. **Reader display of a 250-byte stub** — show the lede; consider a "(summary —
   full article not on the watch)" note so it's not mistaken for a truncated full
   article. Tier flag in the manifest (§3A).
9. **modelVersion** — reuse v1 (no cascade). Only if a short-text-specific model is
   ever needed does the full v2 re-bake (binary + golden decode tests + watchdog
   blob) apply — avoid it.
10. **Index download/storage** — the bucketed index must be generated server-side,
    downloaded, and stored at install; the current single-compact-index install path
    (`IndexStore` parts) becomes bucketed parts.

## 5. Research done this session (grounding)
- `scripts/m11-summaries/measure_summary.py` — the §2 tables (summary compression at
  raw budgets; resident-index RAM at 2.8k/5k/10k/20k). Reuses `dense_pack.load_v1_model`
  (the verified v1 model) + `algos.bpeE2_compress`.
- Key numbers: **~640 raw B → ~250 stored B** (lede); **20k titles → ~920 KB
  resident** (over the ~700 KB heap) — the index is the wall; storage fits 25k+.
- ZIM candidate pool: **57,463** (`cached/candidates.tsv`); pageview ranking covers
  ~4,340 (`cached/pageviews-he.tsv`).

## 6. Suggested milestone ladder (de-risk the index FIRST)
- **M11.0 — spike (`s11-bucket-index`, throwaway, document in `docs/spikes.md`):**
  prototype the prefix-bucketed search over **20k synthetic titles** in the sim
  (seed Storage like `indexload-check.ps1` does at 2,800; push to 20k) — prove
  bucket-load + filter is RAM-bounded and the per-keystroke work is watchdog-safe.
  Probe the **Storage key-count limit** on real hardware (write 20k keys; time a
  getValue; does it fail?). This spike decides per-article-keys vs block-packing and
  whether 20k is even feasible. **Do not build the corpus until this passes.**
- **M11.1 — bucketed index (binary):** replace load-all `IndexCache` with the
  prefix-bucketed on-demand index + bucketed `IndexStore` parts; prefix-only search.
  Sim gate at 20k synthetic + hardware watchdog/RAM confirm.
- **M11.2 — tiered corpus (server):** lede-summary extraction (~640 B cap, sentence-
  boundary) + tier-1 full; select to 20k; reuse v1; manifest v20 + tier flag. New
  dense-pack handles the mixed sizes (existing `dense_pack.py` already byte-targets
  chunks — should "just work" with smaller bodies → ~190 summaries/chunk).
- **M11.3 — install + reader at 20k:** install the bucketed index + 20k bodies
  (key-count/block decision, install time), summary "(summary)" label, integration.
- Adjust per the spike. If the Storage key-count or watchdog blocks 20k, fall back to
  a smaller target (e.g. 8–10k) — still a big jump from 2,800, and the bucketed index
  + summaries are the enablers either way.

## 7. Key files
- `scripts/m8-corpus/select.ps1` (read-ranked selection, uses pageviews),
  `extract.ps1` (markdown extraction — add the lede-truncate step), `build_v17.ps1`
  / `dense_pack.py` (`scripts/m10-compress/`, dense compressed chunks, `--out-dir`,
  `-Version`), `pack-index.ps1` (→ becomes bucketed), `gen-manifest.ps1`.
- `scripts/m11-summaries/measure_summary.py` (this session's research).
- `source/storage/IndexCache.mc` + `IndexStore.mc` + `source/models/Search.mc` +
  the keyboard load path — the index redesign lives here.
- `source/InstallView.mc` / `InstallController.mc` (install the bucketed index +
  20k bodies; telemetry already added in M10.8).
- `source/storage/ArticleStore.mc` (per-article keys vs block-packing).
- `scripts/indexload-check.ps1` (extend its synthetic seed to 20k for the gate),
  `install-check.ps1`, `watchdog-check.ps1`.
- Server output: `docs/server/{manifest.json, chunk/*.json, index/*.json (bucketed)}`
  → user uploads.

## 8. Decisions — CONFIRMED by the user (2026-06-07)
- **Prefix-only search at 20k** (no global substring) — ✅ **YES, acceptable.**
- **Article-count target** — ✅ **let the M11.0 spike set a SAFE CEILING** (do NOT
  hard-commit to 20k; the spike finds the max the Storage key-count + watchdog + RAM
  sustain on hardware, and we ship that). 20k is the aspiration, not a promise.
- **Tier-1 full count** (~800–1,000 full + the rest as ~250 B lede summaries) —
  ✅ **YES, that split.**
- **Summary source** — lede-truncation for v1 (recommended); LLM summaries deferred.

→ Because the ceiling is spike-determined, **M11.0's first job is to find it**: probe
the `Application.Storage` key-count/perf limit on real hardware (a CapProbe-style
`StorageProbe` app) AND prototype the prefix-bucketed search at synthetic scale.
