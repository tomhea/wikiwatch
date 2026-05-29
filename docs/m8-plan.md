# M8 — Real Hebrew Wikipedia corpus from ZIM

**Status:** design phase. M7.2 just shipped; the network pipeline + server layout are proven end-to-end with the synthetic 36-article M6.5 carry-over corpus. M8 replaces only the *content* — same client, same server contract.

**Branch (when implementing):** `m8-real-corpus`
**Tag:** `v0.M8`
**Artifact:** `versions/wikiwatch-M8.prg` (same binary as M7.2; the change is server-side data)

---

## Goal

Generate the corpus served from `https://wikiwatch.tomhe.app/` from a real Hebrew Wikipedia snapshot, packaged as a Kiwix ZIM archive the user already downloaded:

```
C:\Users\tomhe\Downloads\wikipedia_he_top_nopic_2026-04.zim   (≈ 698 MB)
```

`zimdump` 3.6.0 (libzim 9.3.0) is installed locally. The ZIM contains **174,417 entries** total:

| Type | Count |
|------|------:|
| `item` (real entries) | 87,582 |
| `redirect` (aliases) | 86,835 |

Of the items, **57,463 are `text/html`** (the actual articles). The rest are embedded media (mostly SVG icons), CSS, and JS — we ignore all of those.

We need to pick a subset that:

1. Fits in the watch's ~9 MB Storage quota (CIQ 4.x cap on Venu 2; per-key ≤16 KB).
2. Covers articles a user is likely to look up. The ZIM filename hints at this — `_top_nopic_` means the Kiwix selection already picked "top N most-popular pages, no embedded images". We're sampling from an already-popularity-filtered set.
3. Includes the M7 server schema fields (`id`, `title`, `popularity`, body bytes).

The watch-side code does not change. After M8 ships, the only difference the user sees is:

- The keyboard searches now suggest real Wikipedia titles.
- Long-pressing a word in a real article pushes a keyboard pre-filled with that word — and if it matches another real article, the user can navigate the real graph of cross-references.

The R2 evidence for M8 will be a live sim demo: type `ש`, see real ש-prefix titles, open one, long-press a word, jump to that word's article.

---

## ZIM extraction — what we saw

### Lookup mechanics

Direct title lookup via Hebrew URL works for some titles, fails for others:

```powershell
zimdump show --url="ישראל" wikipedia_he_top_nopic_2026-04.zim  # OK — 624 KB raw HTML
zimdump show --url="שלום"  wikipedia_he_top_nopic_2026-04.zim  # "Entry not found"
```

The failures are an encoding edge case in zimdump's URL handler, not the data. Hebrew titles are present in the ZIM (we saw 36 entries with `path:` starting `שלום`). The fix is to **iterate by index** (`--idx=N`) rather than by URL, then read `path:` from the `--details` metadata.

### Article HTML structure

Sample article at index 1016 ("149–140 לפנה\"ס"):

- Full HTML5 document (`<!DOCTYPE html>` + `<head>` + `<body>`).
- Real content lives in `<div id="mw-content-text">`.
- Sections: `<section data-mw-section-id="N">` — section 0 is the lead/intro, 1+ are subsections (history, demography, etc.).
- Lots of MediaWiki-specific markup:
  - `rel="mw:WikiLink"` on every internal link.
  - `typeof="mw:Transclusion"` on templated content.
  - `data-mw-*` attributes everywhere.
- Bloat to strip:
  - `<head>` (all stylesheet + meta tags).
  - `<table class="infobox">` (sidebar facts panel — dense but mostly metadata, not body text).
  - `<table class="navbox">` (footer navigation tables — these can be huge).
  - All `<a>` tags (keep their *text content*, drop the link wrapping).
  - Wikipedia footnote markers like `[1]`, `[2]`.
  - Long URL fragments.

### Size profile

| Article | Raw HTML | Section 0 (lead) | Section 0 after crude HTML strip |
|---------|---------:|-----------------:|---------------------------------:|
| 149–140 לפנה"ס (idx 1016) | 14.4 KB | ~2 KB | ~1 KB |
| ישראל (idx 109253)         | 624 KB   | 49 KB  | 9.5 KB (still includes infobox caption) |

ישראל (Israel, ~45 sections) is at the extreme high end. Most articles are far smaller. After proper extraction (strip infobox + navbox + cross-links):

- Short articles (~80 % of the corpus): 500 B – 3 KB.
- Medium articles: 3 KB – 8 KB.
- Long articles (Israel, Jerusalem, Talmud, etc.): would need truncation at the ~14 KB mark to stay under the 16 KB per-key cap (with safety margin for utf-8 expansion).

---

## Architecture

```
   ┌──────────────────────────────┐
   │  M8 build pipeline (offline) │  Run once per corpus refresh.
   │                              │
   │  1. enumerate.ps1            │  zimdump list --details → all 87,582 items
   │     filter to text/html      │  → 57,463 candidates
   │     emit candidates.tsv      │  (idx, path, title, item-size)
   │                              │
   │  2. select.ps1               │  Pick N articles to ship.
   │     read candidates.tsv      │  Selection criteria — see "Selection" below.
   │     emit selected.tsv        │  (idx, id, title, popularity)
   │                              │
   │  3. extract.ps1              │  For each selected idx:
   │     zimdump show --idx=N     │    raw HTML → Markdown body
   │     html → markdown          │    skip articles whose body > 14 KB
   │     emit article files       │  → docs/server/article/<id>.txt
   │                              │
   │  4. gen-manifest.ps1         │  Build docs/server/manifest.json with
   │     read all extracted bodies │   { version, totalBytes, articles[] }
   └──────────────────────────────┘
                  ↓
   docs/server/   (commit + push as a `Fix:` PR)
                  ↓
   User uploads to wikiwatch.tomhe.app/
                  ↓
   Watch sees version bump, prompts "update?", downloads real corpus
```

All four scripts live under `scripts/m8-corpus/`. They're tools, not part of the watch build — they run on the dev host and produce the same `docs/server/` layout we already established in M7.

### Why split into 4 scripts and not 1?

- Idempotency: rerunning `extract.ps1` after tweaking the HTML-strip logic shouldn't require redoing the slow `zimdump list` enumeration (~minutes for 174k entries).
- Debugging: when one article comes out wrong, you re-run just `extract.ps1 --idx 1016` and inspect; you don't reprocess the whole corpus.
- Composability: M9 (compression) plugs in between `extract` and `gen-manifest` without disturbing the rest.

---

## HTML → text conversion

### Why not just `<text-extract-library>`?

Two reasons we ship a custom extractor:

1. **Cross-reference preservation.** When the long-press feature matches a word back to a known article, the title must be in the body. Generic HTML-to-text strips link wrappers but loses the *fact* that "תורה" was a link — for our purposes that's fine, because the *text* "תורה" still appears, and `WordHitTest` matches on raw characters. So we don't need anchor metadata, just clean inline text.
2. **Wikipedia-specific noise.** Generic tools don't know that `<table class="infobox">` is metadata-bloat-not-content for our use case. We need MediaWiki-aware filtering.

### Algorithm

```
input:  raw HTML of one article
output: Markdown body, ≤14 KB, UTF-8, LF endings

steps:
  1. parse <h1 class="firstHeading"> → title  (already in selected.tsv, sanity check)
  2. find <div id="mw-content-text">
  3. drop:
       - <table class="infobox"> + <table class="navbox">
       - <span typeof="mw:Transclusion"> empty containers
       - <div class="nomobile"> and <div class="mobileonly"> wrappers (keep contents of mobile-only)
       - <sup class="reference"> footnote markers
       - <span typeof="mw:Entity"> (turn into the entity text)
       - all <style>, <script>, <link>
  4. emit:
       - first line: "# <title>"
       - blank line
       - lead paragraph(s) from section 0
       - blank line + "## <heading>" + blank line + paragraphs for sections 1..N
  5. text transforms inside paragraphs:
       - <a ...>text</a>           → text   (drop wrapper, keep text)
       - <b>text</b>               → text   (keep text, drop bold)
       - <i>text</i>               → text
       - <br>                      → newline
       - <ul><li>x</li>...</ul>    → "- x\n- ..."
       - paragraphs separated by blank lines
  6. cleanup:
       - decode HTML entities (&nbsp; → space, &amp; → &, etc.)
       - collapse runs of whitespace
       - trim trailing whitespace per line
  7. truncate at 14 KB by *paragraph boundary* (never mid-sentence)
       - if truncated, append "...\n\n(המשך בערך המלא)" so the user sees it's cut
```

### Implementation language

PowerShell with .NET regex. We considered `pandoc`, but:

- pandoc's HTML-to-Markdown emits real Markdown links (`[text](url)`) and footnote syntax we'd then have to strip back out.
- We need MediaWiki-specific filters anyway, so we're not saving any effort.
- The existing `scripts/gen-server-corpus.ps1` is PowerShell — same toolchain.

### Per-article size cap

14 KB target (not the 16 KB hard limit). Headroom rationale:

- UTF-8 Hebrew chars are 2 bytes each, ASCII (digits, punctuation) is 1 byte. Mix averages ~1.7 B/char in body text.
- The watch stores body + key name + ~20 B overhead in one Storage value. The 16 KB cap is *bytes after encoding*, not chars. A 14 KB Markdown source lands at ≈14.0–14.2 KB encoded — comfortable margin.

---

## Selection — which articles ship?

The M7 server schema requires `popularity: 0-100`. The ZIM doesn't carry per-article popularity directly. Options:

### A. ZIM index order

Articles in the ZIM are clustered (1,951 clusters of related content). Index order is *not* popularity-sorted — it's a build artifact of cluster packing.

### B. Item size

Article byte-size is a *very* rough proxy for "importance" — Wikipedia gives more space to topics that matter — but it's noisy: list-articles ("רשימת ראשי ממשלת ישראל") are huge but not what users search for first.

### C. External popularity list

[Wikipedia "most-viewed pages" reports](https://stats.wikimedia.org/) publish monthly view counts. We could download the Hebrew Wikipedia top-N-viewed list (text file, ~few KB), join against the ZIM titles, and use *that* as popularity. Most-faithful to user expectations.

### D. Inverse-correlated to index, since `_top_` selection already happened

The ZIM is `wikipedia_he_top_nopic_2026-04` — Kiwix's "top" curation already picked the popular articles. Within that curated set, any ordering works.

**Recommendation:** **C** for popularity scoring, **truncate to fit Storage** for selection.

Pipeline:

1. Download the Hebrew Wikipedia monthly pageview dump (≈3 MB, text file).
2. Join page-titles to ZIM `path:` values. Keep titles present in both.
3. Rank by views. Top 1.
4. Extract them in order, accumulating byte total. Stop when `sum(bodies) > 8 MB` (leave 1 MB headroom under the ~9 MB Storage cap for safety + future growth).

Estimated yield: at an average body size of 2 KB, **~4,000 articles**. (Compared to M7.2's 36-article carry-over corpus, that's >100× larger.)

The `articles[].popularity` field gets normalized to 0-100 based on log of view count.

---

## ID scheme

The ID is the URL-safe slug that becomes `/article/<id>.txt`. Today (M7) it's hand-typed kebab-case English: `shalom`, `shabbat`. M8 needs something automatable and stable across runs.

### Options

| Scheme | Example for "שלום" | Pros | Cons |
|---|---|---|---|
| Hebrew, URL-encoded | `%D7%A9%D7%9C%D7%95%D7%9D` | Lossless | Looks bad in URLs; encode/decode each side |
| Latin transliteration | `shalom` | Pretty URLs | Lossy (יוסף → yosef vs josef); ambiguous |
| Numeric (ZIM idx) | `109253` | Stable, simple | Doesn't survive a corpus regen if articles shift |
| SHA-1 of title, base32 hex prefix | `7q2g9k` | Stable across regen | Opaque |
| Sequential (1..N) by popularity | `00042` | Smallest URLs; ranking visible | Not stable across regen |

**Recommendation:** Hebrew, URL-encoded.

Rationale: the watch-side `Downloader.fetchArticle(id, callback)` already accepts an opaque String. URLs are never user-facing on the watch. URL-encoding is widely supported (CIQ's `Communications.makeWebRequest` URL-encodes the id automatically). And the encoded id matches what the user would see if they pasted the URL into a browser — which makes debugging the server side trivial ("does `https://wikiwatch.tomhe.app/article/%D7%A9%D7%9C%D7%95%D7%9D.txt` 200?").

Trade-off: the manifest.json gets bigger because each id is ~30 bytes instead of ~6. With 4,000 articles, that's ~96 KB extra in the manifest — still well under the manifest size cap.

---

## Server contract — chunked download, per-article storage

**Changed from M7 (network only).** The 4,000-article × 1-sec-per-fetch math gives a 70-minute install, which is not acceptable. The user's targets are <1 min (best case), ≤5 min (worst case), and **≤200-300 KB transient RAM** above the M7 baseline at any moment during install.

Design tension: chunking the *download* saves request overhead, but chunking the *storage* makes per-article reads slow (need to deserialize a 200 KB chunk JSON every cold-cache lookup). The right answer **splits the two concerns**:

| Layer | M7 | M8 |
|---|---|---|
| HTTP transport | 4000 per-article requests | 50 chunked requests (download only) |
| Watch Storage | 1 key per article (`article:<id>`) | **Same** — 1 key per article (unchanged) |
| Read path | `Storage.getValue("article:<id>")` → ~10-20 ms | **Same** — direct O(1) lookup |

The chunked download is unpacked into per-article Storage values during install. After install completes, the watch is byte-equivalent to a freshly-installed M7 — except the corpus is 100× bigger.

### Memory budget (≤300 KB transient above baseline)

This drives the chunk-size choice. The dominant transient costs are:

| Component | Cost |
|---|---:|
| Raw response buffer per in-flight chunk (held by CIQ until callback returns) | ~ chunk-bytes |
| JSON-parsed Dictionary during unpack (overhead ~1.3-1.5× raw) | ~ chunk-bytes × 1.4 |
| Temporary key/body Strings during `Storage.setValue` loop | small (~1 KB transient per iter) |

To fit 2 in-flight + 1 unpack within 300 KB:

```
2 × chunk_raw + 1 × chunk_raw × 1.4  ≤  300 KB
3.4 × chunk_raw                        ≤  300 KB
chunk_raw                              ≤  ~88 KB
```

**Chunk sizing: 80 KB raw / ~40 articles per chunk. 100 chunks total.**

| Component during install | Bytes |
|---|---:|
| 2 raw response buffers in flight | ~160 KB |
| 1 chunk being JSON-parsed + unpacked | ~110 KB |
| **Transient peak** | **~270 KB** |

Under 300 KB. Self-regulating: if `freeMemory` drops below 400 KB, in-flight cap drops from 2 → 1 (peak ~190 KB).

### Install time budget breakdown

The architecture is **parallel download + sequential unpack** (CIQ event loop is single-threaded — `Storage.setValue` blocks until done). Storage writes overlap with the *next* chunk's network transit but cannot run in parallel with each other.

| Step | Cost per chunk | Total (100 chunks) |
|---|---|---|
| Network round-trip (~80 KB gzipped to ~20 KB on wire) | WiFi: ~50 ms; BLE: ~1 sec | WiFi: ~5 sec; BLE: ~50 sec |
| `putBatch` unpacks 40 articles → 40 `setValue` calls (~10-20 ms each) | ~400-800 ms | ~40-80 sec |
| 1 manifest setValue + ArticleStore wipeAll | one-time ~1 sec | ~1 sec |

Since `setValue` is sequential and downloads parallelize: total install ≈ max(network total, storage total).

**End-to-end:**
- **WiFi happy path:** ~40-80 sec (storage dominates).
- **BLE typical:** ~80-100 sec (~1.5 min — storage and network roughly balanced with 2-in-flight).
- **BLE worst case (serial, slow writes):** ~3-4 min.

All within the ≤5 min budget. **Whether <1 min on WiFi is achievable depends on actual `Storage.setValue` throughput on Venu 2.** Old M5.2 notes suggested 50-100 ms per call for heavier values; modern small-string writes may be 5-15 ms. The R2 evidence step measures this empirically.

### Plan B if storage writes are slow

If R2 measurement shows `setValue` averages >25 ms (i.e., the 4000-write install would exceed 100 sec on WiFi alone), the fallback is a **micro-batch** layout:

- Group articles into 4-per-key buckets: `articles:N` Storage key holds Dictionary `{id1: body1, id2: body2, id3: body3, id4: body4}`.
- Storage writes drop from 4000 → 1000.
- Read path: lookup which bucket N the id lives in (precomputed at manifest-load), `Storage.getValue("articles:N")`, dict lookup.
- Per-cold-read cost: ~30-40 ms (parse a ~6-8 KB Dict + 1 lookup) vs M7's ~10-20 ms. ~2× slower but still under any perceivable threshold.
- Memory cost: zero additional resident — buckets aren't cached between reads (one bucket transiently held during the lookup, ~8 KB).

This trade is *small read penalty for big install win* — would only invoke if R2 measurement forces it. The plan ships with per-article keys (Plan A) by default; Plan B is a documented escape hatch implementable as a Fix: M8.1.

### New server endpoints

#### `GET /manifest.json` (schema bumped)

```json
{
  "version": 5,
  "totalBytes": 8123456,
  "chunkCount": 50,
  "chunkUriPattern": "/chunk/{n}.json",
  "articles": [
    {
      "id": "%D7%A9%D7%9C%D7%95%D7%9D",
      "title": "שלום",
      "popularity": 100
    },
    ...
  ]
}
```

New fields vs M7:
- `chunkCount` — number of `/chunk/N.json` files to download during install.
- `chunkUriPattern` — `{n}` substitution template, for forward-compat.

Removed vs M7: `articles[].chunk` is **not needed** (the watch doesn't need to know which chunk an article came from once it's unpacked into per-article Storage).

The `id` field is now Hebrew URL-encoded (per the answered question above).

#### `GET /chunk/<N>.json`  (install-time only)

A JSON object packing ~40 articles:

```json
{
  "chunk": 0,
  "articles": {
    "%D7%A9%D7%9C%D7%95%D7%9D": "# שלום\n\nשלום הוא מילה בעברית...",
    "%D7%99%D7%A9%D7%A8%D7%90%D7%9C": "# ישראל\n\nישראל היא מדינה...",
    ...
  }
}
```

Sized to **~80 KB raw, ~20 KB gzipped** (Hebrew text compresses well). 100 chunks total. Used **only during install**; after install completes, chunk responses are discarded and never re-requested. Chunk size was driven by the 300 KB RAM ceiling (see Memory budget below).

#### `GET /article/<id>.txt` — REMOVED

The watch never makes per-article requests. All article body data arrives via chunks during install.

#### Web-server gzip

The static files don't need to be pre-gzipped. Configure the web server (nginx / Cloudflare / Caddy / whatever serves wikiwatch.tomhe.app) to apply `Content-Encoding: gzip` on responses where `Accept-Encoding: gzip` is in the request header. CIQ's `Communications.makeWebRequest` sends `Accept-Encoding: gzip` by default and transparently decompresses. Documented in `docs/server/README.md`.

### Watch-side impact

- **`source/storage/ArticleStore.mc`** — public API stays identical to M7. Per-article Storage keys (`article:<id>`). Reads are direct + fast (M7-equivalent). New internal helper: `putBatch(articlesDict)` that the install can call once per unpacked chunk (loops over the dict and calls `Storage.setValue` for each id, with a `try/catch` around each in case Storage is full).

- **`source/storage/Manifest.mc`** — `wipeArticles()` unchanged from M7; still iterates `article:` keys.

- **`source/net/Downloader.mc`** — keeps `fetchManifest`, **adds** `fetchChunk(n, callback)` (uses `manifest.chunkUriPattern` to build URL). `fetchArticle` is removed.

- **`source/InstallView.mc`** — orchestrates parallel chunk fetches + per-chunk unpacking + resumability. State machine:
  ```
  init:
      InstallState.markInProgress(manifest.version)
      _chunksReceived = InstallState.getChunksReceived()  (sorted Array<Number>, possibly empty)
      _remaining = computeMissingChunks(_chunksReceived, manifest.chunkCount)
      _inFlight = 0
      _articlesWritten = countArticlesAlreadyInStorage()  ← supports resume
      _maxInFlight = 2  (drop to 1 if free memory < 400 KB)
      _chunksUntilBatteryCheck = 10
      fire up to _maxInFlight chunks (popped off _remaining)

  onChunkReceived(N, json):
      _inFlight--
      // Critical: write to Storage BEFORE updating bitmap, so a crash
      // mid-callback re-downloads the chunk on resume (safe — setValue
      // is idempotent on overwrites) rather than leaves articles
      // half-written without the bitmap entry.
      ArticleStore.putBatch(json.articles)        ← ~40 setValue calls, ~0.4-0.8 sec
      _articlesWritten += json.articles.size()
      InstallState.markChunkReceived(N)            ← single setValue, updates persistent bitmap
      // Release the raw chunk + parsed dict before firing next request,
      // so peak RAM doesn't compound.
      json = null
      checkMemory()
      _chunksUntilBatteryCheck--
      if _chunksUntilBatteryCheck <= 0:
          _chunksUntilBatteryCheck = 10
          if battery < 5% and not charging:
              pause → push LowBatteryView; return
      if _remaining not empty and _inFlight < _maxInFlight:
          fire next chunk from _remaining
          _inFlight++
      else if _inFlight == 0 and _remaining empty:
          InstallState.markComplete()
          switchToView(KeyboardView)
      requestUpdate()  ← triggers onUpdate → redraws progress %
  ```
  Per-chunk `putBatch` runs in the chunk-received callback (CIQ event-loop friendly — no UI block longer than ~1 sec). **`installChunksReceived` is updated only after the articles are durable** — guarantees that on crash, partial-chunk articles remain in Storage but the chunk is *not* marked received, so it gets re-downloaded (idempotent overwrite). Worst-case redundant work on resume: 40 articles per killed-mid-callback chunk.

- **`source/models/Search.mc` / wikiwatchKeyboardDelegate / wikiwatchDelegate** — *unchanged* from M7. All call `ArticleStore.load(id)` with the same semantics. Steady-state read performance matches M7.

### What we lose

- **Granular fault tolerance.** If one chunk download fails, ~80 articles don't arrive. **Mitigation:** install retries each chunk up to 3 times (~3 sec backoff). After all retries exhausted, the chunk is marked failed and the install continues with the other chunks; user gets degraded mode with the articles that did arrive. UX pattern matches M7's existing fallback.
- **Browser-pasteability per article.** Chunk URLs are still browser-pasteable (`https://wikiwatch.tomhe.app/chunk/0.json` returns the chunk JSON) but you no longer can curl an individual article URL — you'd have to grep inside the chunk. Acceptable for debugging.
- **Incremental updates** (theoretical M7 feature). Not changed from M7 — both wipe everything on update-prompt-accept.

### Watch-side numbers (recap)

- Peak transient RAM during install: ~270 KB (under 300 KB cap; self-regulates to ~190 KB under memory pressure).
- Steady-state RAM: M7-equivalent (no chunk caching after install).
- Storage layout: ~4000 `article:<id>` keys (matches M7 model exactly).
- Per-article read latency: ~10-20 ms (M7-equivalent).
- Total install time: ~40-80 sec WiFi / ~1.5 min BLE / ~3-4 min bad BLE.

---

## Crash recovery + battery gate + UX

The install touches Storage thousands of times over a 1-5 minute window. The user can close the app, the watch can die, the connection can drop. The install must be **resumable** — re-launching the app after any interruption picks up where it left off, not from zero.

### Storage state model

Three new Storage keys track install lifecycle:

| Key | Type | Meaning |
|---|---|---|
| `installState` | String | `"none"` \| `"in_progress"` \| `"complete"` |
| `installManifestVersion` | Number | The manifest `version` this install is for. Used to invalidate stale partial installs after the server bumps version. |
| `installChunksReceived` | Array<Number> | Sorted list of chunk indices already written to Storage. E.g. `[0, 1, 2, 5, 7]` means chunks 0,1,2,5,7 are done; 3,4,6,8..99 still need fetching. |

These keys are written **inside the same callback** that writes each chunk's articles, *after* `putBatch` completes. If the app dies mid-chunk-write, the partial chunk's articles are in Storage but the chunk isn't marked received → it gets re-downloaded on resume (idempotent: `Storage.setValue` overwrites). If the app dies mid-callback, worst case we re-download one chunk's worth on resume (~40 articles redundant — acceptable).

### Launch state machine (replaces M7.1's 2×2 branch)

```
[launch]
   |
   installState =
       "complete"      → M7 path (UpdateCheckView or KeyboardView depending on network)
       "in_progress"   → check battery + network
                            battery <10% → LowBatteryView (with resume context)
                            no network   → NoConnectionView (with resume context)
                            otherwise    → ResumeInstallView (download remaining chunks)
       "none" (or key absent)  → first-launch path
                            has network  → check battery
                                              <10% → LowBatteryView (with first-install context)
                                              ≥10% → InstallView (full install)
                            no network   → NoConnectionView
```

### Resume detection on `UpdatePromptView.onYes` (after user accepts update)

When the user accepts an update:
1. Set `installState = "in_progress"`.
2. Set `installManifestVersion = newManifest.version`.
3. Set `installChunksReceived = []`.
4. Call `ArticleStore.wipeAll()` (removes old article:<id> keys to make room).
5. Push `InstallView`.

If the app dies between step 1 and the first chunk write, on next launch we see `installState=="in_progress"` with `installChunksReceived==[]` — the entire install needs to happen. That's correct.

### Manifest-version mismatch on resume

If the server has bumped its `version` since the partial install started (`installManifestVersion < remoteManifest.version`), the partial corpus is for an obsolete manifest. **Discard it** and start fresh: `ArticleStore.wipeAll()`, reset `installChunksReceived=[]`, set `installManifestVersion=remote.version`. The user gets the full re-install. (Rare case; the user would have to have started an install, killed it, waited for a server bump, then re-opened — but it's important to get right because otherwise the corpus would be inconsistent.)

### Battery gate

Before starting **or resuming** an install:

```monkeyc
var stats = System.getSystemStats();
var battery = stats.battery;            // Float 0.0 - 100.0
var charging = stats.charging;          // Boolean
if (battery < 10.0 && !charging) {
    push LowBatteryView;
    return;
}
```

The `!charging` check is important: a watch plugged in at 5 % is still progressing toward more battery and the install can run safely. Only refuse on **low + not charging**.

LowBatteryView messaging:
- First install: `"שדרוג בהמתנה — חבר למטען להמשך"` (Update pending — plug in to continue).
- Resumed install: `"התקנה לא הסתיימה — חבר למטען להמשך"` (Install incomplete — plug in to continue).
- Below the message: tiny battery percentage in MEDIUM font (`X% • plug in to install`).

The view polls battery once per second; when it rises ≥10% (or charging becomes true), it auto-transitions to `InstallView` (resumes from `installChunksReceived`). User can also tap the screen to dismiss the gate and fall back to the keyboard (functional only if any prior install completed — otherwise still degraded).

### Battery during install

The InstallView also periodically polls battery (once every 10 chunks). If battery drops below 5 % AND not charging, **pause the install**: stop firing new chunk requests, allow in-flight to complete + write, then transition to LowBatteryView. State is preserved in `installChunksReceived`. Resume on next launch when battery recovers.

### Progress UI

`InstallView` rendering:

```
              wikiwatch
            
            Loading: 35%
            
         Don't close the app
         
        ──────────────────────
        ┃███████░░░░░░░░░░░░░┃   <- progress bar
        ──────────────────────
        
        1,400 / 4,000 articles
```

- **Percentage** computed as `_articlesWritten / totalArticles × 100`, integer. Updates every chunk (~every 0.5-1 sec).
- **"Don't close the app"** in red (Graphics.COLOR_RED), FONT_SMALL, just below the percentage. Always present during install.
- **Progress bar** is a horizontal pixel bar — empty rectangle outline + filled portion. Width = % of inner display width. Color = COLOR_BLUE.
- **N / M articles** counter at the bottom, FONT_TINY, gray.

`ResumeInstallView` is the same view + extra "Resuming…" subtitle for the first second after launch.

### Tests for crash recovery

New test file `source/tests/test_InstallResume.mc` (pure state-machine tests; no real Storage or network):

| Test | What it asserts |
|---|---|
| `resume_pickUpFromInstallChunksReceived` | Pre-populate `installChunksReceived=[0, 1, 5]`, manifest has 100 chunks. Next chunk fetched is 2 (lowest missing). |
| `resume_skipsDownloadedChunks` | With 50 chunks already done, only the remaining 50 are requested. |
| `resume_invalidatedByVersionBump` | `installManifestVersion=4`, remote `version=5` → wipeAll + restart. |
| `resume_preservesCompletedChunksOnSameVersion` | Same version → resume from current state, no wipe. |
| `state_completeAfterAllChunksReceived` | `installChunksReceived.size() == chunkCount` → `installState="complete"`. |
| `state_inProgressAfterFirstChunk` | One chunk written → `installState=="in_progress"`. |
| `state_persistedAcrossViewRecreate` | Destroy + recreate InstallView, state survives via Storage. |

### Tests for battery gate

| Test | What it asserts |
|---|---|
| `battery_blocksInstallBelow10Percent` | `battery=9.0, charging=false` → install not started, LowBatteryView shown. |
| `battery_allowsInstallWhenCharging` | `battery=5.0, charging=true` → install proceeds. |
| `battery_pausesInstallBelow5Percent` | During install, battery drops to 4 % not charging → no new chunks fired. |
| `battery_autoResumesWhenChargingStarts` | LowBatteryView observes charging=true → transitions to InstallView. |

### R2 evidence — adversarial scenarios

In addition to the happy-path live demo, the R2 sim run must capture:

1. **Mid-install app kill.** Launch app, start install, kill simulator at ~30 % progress. Re-launch. Verify ResumeInstallView picks up at ~30 %, completes correctly. Stdout shows `M8 resume: chunks_received=37/100`.
2. **Mid-install power-off model.** Same as #1 but with the simulator's "Stop App" menu (which closes the CIQ app process cleanly — closer to a real watch sleep-out).
3. **Battery low at launch.** Use simulator's battery slider, set to 8 %, launch with stale manifest (force an update available). LowBatteryView shows. Drag battery to 15 %. Verify auto-transition to InstallView.
4. **Battery dies during install.** Start install, mid-progress drag battery to 4 %. Verify install pauses, LowBatteryView appears, state preserved in Storage.

The stdout for each scenario gets saved to `docs/m8-r2-evidence.txt` with clear `=== SCENARIO N ===` separators.

---

## Files

```
docs/
  m8-plan.md                    <-- THIS DOC
  server/                       <-- regenerated by scripts/m8-corpus/*
    manifest.json               <-- bumps version=5, adds chunkCount + per-article chunk field
    chunk/
      0.json                    (100 chunks, ~80 KB each, ~40 articles each)
      1.json
      ...
      99.json
    README.md                   <-- updated upload instructions + gzip config
scripts/
  gen-server-corpus.ps1         <-- DELETED (superseded by m8-corpus/)
  m8-corpus/
    enumerate.ps1               <-- NEW: zimdump list → candidates.tsv
    select.ps1                  <-- NEW: candidates + pageviews → selected.tsv
    extract.ps1                 <-- NEW: zimdump show + HTML strip → cached/articles/<id>.txt
    pack-chunks.ps1             <-- NEW: cached/articles/* → docs/server/chunk/N.json
    gen-manifest.ps1            <-- NEW: chunks + selected.tsv → manifest.json
    README.md                   <-- NEW: how to refresh the corpus
    cached/
      candidates.tsv            <-- gitignored: intermediate
      pageviews-he.tsv          <-- gitignored: downloaded pageview dump
      selected.tsv              <-- gitignored: intermediate
      articles/                 <-- gitignored: per-article extracted text
        <urlencoded>.txt
        ...
source/
  storage/
    ArticleStore.mc             <-- ADDED: putBatch(dict) helper for chunk unpacking
    Manifest.mc                 <-- unchanged (same article: key prefix)
    InstallState.mc             <-- NEW: get/setInstallState, chunksReceived bitmap mgmt
  net/
    Downloader.mc               <-- UPDATED: fetchArticle → fetchChunk
  InstallView.mc                <-- REWRITTEN: parallel chunk fetch + per-chunk unpack + progress UI
  LowBatteryView.mc             <-- NEW: gate view (first-install + resume contexts)
  wikiwatchKeyboardDelegate.mc  <-- unchanged (still ArticleStore.load(id))
  wikiwatchDelegate.mc          <-- unchanged
  wikiwatchApp.mc               <-- UPDATED: 3-state launch (none/in_progress/complete) × battery/network
  tests/
    test_ArticleStore.mc        <-- ADDED: tests for putBatch
    test_Downloader.mc          <-- UPDATED for fetchChunk
    test_InstallView_state.mc   <-- NEW: pure state-machine tests for parallel fetch
    test_InstallResume.mc       <-- NEW: resume / version-bump / state-persistence tests
    test_InstallState.mc        <-- NEW: chunksReceived bitmap + installState transitions
    test_BatteryGate.mc         <-- NEW: battery threshold + charging logic
    test_wikiwatchApp.mc        <-- UPDATED: 3-state launch branches
```

The corpus-generation scripts are pure transforms. Tests for them are unit-style PowerShell `Pester` blocks (lightweight; no new framework dependencies on the watch side).

**Watch-side changes are substantial this time.** M8 is the first milestone since M5 that materially changes the storage layer.

---

## Tests (R3 coverage)

### Corpus-generation tooling (PowerShell / Pester)

| Test | What it asserts |
|---|---|
| `extractor.test.ps1` :: `strips_infobox_table` | Given HTML with `<table class="infobox">…</table>`, output omits the table. |
| `…` :: `strips_navbox_table` | Same for `<table class="navbox">`. |
| `…` :: `preserves_link_text` | `<a rel="mw:WikiLink" href="…">תורה</a>` → `תורה`. |
| `…` :: `converts_ul_to_dash_list` | `<ul><li>א</li><li>ב</li></ul>` → `- א\n- ב`. |
| `…` :: `decodes_nbsp_entity` | `שלום&nbsp;לכם` → `שלום לכם`. |
| `…` :: `emits_h1_first_line` | First line of output is `# <title>`. |
| `…` :: `truncates_at_paragraph_boundary` | A 20 KB input truncates to ≤14 KB, ending on a paragraph break. |
| `pack.test.ps1` :: `groups_articles_into_chunks` | 200 articles + chunkSize=80 → 3 chunks (80, 80, 40). |
| `…` :: `chunk_index_matches_manifest` | manifest.json article[i].chunk == chunk N where article[i] appears. |
| `manifest.test.ps1` :: `sums_total_bytes_correctly` | totalBytes = sum of chunk file sizes. |
| `…` :: `popularity_in_0_100` | All articles emit popularity in [0,100]. |
| `…` :: `version_bumps_on_change` | Re-running with a different selection bumps `version`. |

### Watch-side tests (Monkey C)

| Test | What it asserts |
|---|---|
| `test_ArticleStore.mc` :: `articleStore_putBatchWritesEachArticle` | `putBatch({id1: b1, id2: b2})` → 2 Storage keys written: `article:id1`, `article:id2`. |
| `…` :: `articleStore_putBatchSurvivesPartialFailure` | If one setValue throws (StorageFull), other articles in the batch still get written. |
| `test_Downloader.mc` :: `downloader_buildsChunkUrlFromPattern` | `chunkUriPattern="/chunk/{n}.json"` + N=42 → `/chunk/42.json`. |
| `test_InstallView_state.mc` :: `install_capsInFlightAt2` | With chunkCount=100, no more than 2 outstanding requests at any moment. |
| `…` :: `install_dropsToSerialUnderMemoryPressure` | When freeMem < 400 KB threshold, _maxInFlight drops from 2 → 1. |
| `…` :: `install_completesAfterAllChunksReceived` | When _chunksReceived == chunkCount, state = COMPLETE. |
| `…` :: `install_retriesFailedChunkUpTo3Times` | Failing fetch retries 3 times before giving up. |
| `…` :: `install_continuesAfterChunkPermanentFailure` | Chunk that exhausts retries is skipped; install completes with degraded corpus. |
| `…` :: `install_handlesOutOfOrderResponses` | Chunks arriving in 3, 1, 0, 2 order all unpack correctly. |
| `…` :: `install_progressCountsArticles` | Progress count tracks `_articlesWritten`, not `_chunksReceived`. |
| `…` :: `install_writesChunkToStorageBeforeReturning` | After chunk-received callback returns, all that chunk's `article:<id>` keys are in Storage AND `installChunksReceived` includes N. (Verified by mocking Storage.) |
| `test_InstallResume.mc` :: `resume_pickUpFromInstallChunksReceived` | Pre-populate `installChunksReceived=[0,1,5]`, 100 chunks total → next request targets chunk 2. |
| `…` :: `resume_skipsDownloadedChunks` | With 50 chunks done, only 50 remaining requested. |
| `…` :: `resume_invalidatedByVersionBump` | `installManifestVersion=4`, remote=5 → wipeAll + reset chunksReceived=[]. |
| `…` :: `resume_preservesCompletedChunksOnSameVersion` | Same version → resume from current state, no wipe. |
| `…` :: `state_completeAfterAllChunksReceived` | `chunksReceived.size()==chunkCount` → `installState="complete"`. |
| `…` :: `state_inProgressAfterFirstChunk` | One chunk written → `installState=="in_progress"`. |
| `…` :: `state_persistedAcrossViewRecreate` | Destroy + recreate InstallView, state survives via Storage. |
| `test_InstallState.mc` :: `installState_initialIsNone` | Fresh Storage → `getInstallState()=="none"`. |
| `…` :: `installState_setAndGetRoundtrip` | After `setInstallState("in_progress")`, `getInstallState()=="in_progress"`. |
| `…` :: `installState_chunksReceivedSortedInsert` | Insert 5, 1, 3 → bitmap is `[1, 3, 5]`. |
| `…` :: `installState_missingChunks_returnsLowestUnseen` | bitmap `[0,1,5]`, total 10 → first missing is 2. |
| `test_BatteryGate.mc` :: `battery_blocksInstallBelow10Percent` | `battery=9.0, charging=false` → install gated. |
| `…` :: `battery_allowsInstallWhenChargingEvenAtLowBattery` | `battery=5.0, charging=true` → install proceeds. |
| `…` :: `battery_pausesInstallBelow5Percent` | Battery drops to 4 % not charging during install → install pauses. |
| `…` :: `battery_autoResumesWhenChargingStarts` | LowBatteryView observes charging=true → transitions to InstallView. |
| `test_wikiwatchApp.mc` :: `app_installStateInProgress_routesToResume` | `installState="in_progress"` + battery OK + network → ResumeInstallView path. |
| `…` :: `app_installStateComplete_routesToM7Path` | `installState="complete"` → M7 UpdateCheckView path. |

37 tests total (12 PowerShell + 25 Monkey C). Existing 162 watch-side tests are mostly untouched; only `test_Downloader.mc` adds `fetchChunk` (drops `fetchArticle` tests). Net watch test count: ~187.

---

## R-rule applicability

| Rule | Status |
|------|--------|
| R1 TDD | ✅ FAIL → PASS for 37 new tests (12 PowerShell + 25 Monkey C). |
| R2 Sim | ✅ Five scenarios captured: (1) happy-path install + use, (2) mid-install app kill + resume, (3) mid-install "stop app" (clean shutdown) + resume, (4) battery low at launch with update available, (5) battery dies during install → pause → recover. Each gets its own `=== SCENARIO N ===` block in `docs/m8-r2-evidence.txt`. |
| R3 Coverage | ✅ HTML extractor + chunk packer + manifest generator unit-tested. Watch-side `ArticleStore`, `Downloader`, `InstallView` state machine, `InstallState` bitmap, `BatteryGate`, resumability logic, `wikiwatchApp` 3-state launch all covered. |
| R4 Storage | ✅ Per-article Storage layout unchanged from M7 (M7's `Manifest.wipeArticles()` already covers it). New `ArticleStore.putBatch` wraps each setValue in try/catch to survive transient storage-full errors. Per-chunk size ≤200 KB (enforced by `pack-chunks.ps1`). |
| R5 Memory | ✅ Peak transient ~270 KB during install (2 in-flight × 80 KB raw + 1 unpack ~110 KB) — under 300 KB user cap. Steady-state ~0 KB additional vs M7 (no chunk caching after install). Self-regulates: in-flight cap drops 2 → 1 if `freeMemory` < 400 KB (peak then ~190 KB). |
| R6 Purity | ✅ `ArticleStore.mc` adds `putBatch` but stays module-style. Corpus-generation scripts live outside `source/`. |
| R7 Branch + title | ✅ `m8-real-corpus` + `M8: Real Hebrew Wikipedia corpus from ZIM`. |
| R8 Warnings | ⚠️ Substantial watch-side rewrite. Goal: 2 baseline warnings only. Add to `docs/m8-pass.txt` review during CR-ist. |

---

## Per-step sequence

```powershell
git checkout main; git pull
git checkout -b m8-real-corpus

# Phase 1: corpus-generation tooling (TDD)
#   Write the 12 Pester tests with mock HTML fixtures + a 3-article sample.
& scripts\m8-corpus\test.ps1 *>&1 | Tee-Object docs\m8-tooling-fail.txt   # expect 12 FAIL

#   Implement enumerate, select, extract, pack-chunks, gen-manifest.
& scripts\m8-corpus\test.ps1 *>&1 | Tee-Object docs\m8-tooling-pass.txt   # expect 12/12

# Phase 2: watch-side rework (TDD)
#   Write the 25 Monkey C tests (ArticleStore, Downloader, InstallView state machine,
#   InstallResume, InstallState bitmap, BatteryGate, wikiwatchApp 3-state launch).
& scripts\test.ps1 *>&1 | Tee-Object docs\m8-fail.txt   # expect 25 FAIL

#   Implement ArticleStore.putBatch, Downloader.fetchChunk, InstallState module,
#   LowBatteryView, rewritten InstallView, updated wikiwatchApp launch branching.
& scripts\test.ps1 *>&1 | Tee-Object docs\m8-pass.txt   # expect ~187/187

# Phase 3: corpus generation (one-shot offline)
& scripts\m8-corpus\enumerate.ps1 -ZimPath "C:\Users\tomhe\Downloads\wikipedia_he_top_nopic_2026-04.zim"
& scripts\m8-corpus\select.ps1     -TargetBytes 8388608    # 8 MB
& scripts\m8-corpus\extract.ps1                            # writes cached/articles/<id>.txt
& scripts\m8-corpus\pack-chunks.ps1 -ChunkSize 40          # writes docs\server\chunk\N.json (~80 KB each)
& scripts\m8-corpus\gen-manifest.ps1 -Version 5            # writes docs\server\manifest.json

# Sanity check
Get-ChildItem docs\server\chunk -File | Measure-Object -Sum Length     # expect ~8 MB
Get-ChildItem docs\server\chunk -File | Where-Object { $_.Length -gt 102400 }  # expect EMPTY (100 KB cap)
Get-Content docs\server\manifest.json | ConvertFrom-Json | % { $_.articles.Count }  # expect ~4000

# Phase 4: build + server upload
& scripts\build.ps1
Copy-Item bin\wikiwatch.prg versions\wikiwatch-M8.prg

#   User uploads docs/server/ to wikiwatch.tomhe.app/.
#   Configure gzip on the web server (nginx: gzip_types application/json; on)
#   Confirm:
#     curl -I -H "Accept-Encoding: gzip" https://wikiwatch.tomhe.app/chunk/0.json
#     → should show Content-Encoding: gzip
#   Confirm: https://wikiwatch.tomhe.app/manifest.json returns version=5

# Phase 5: R2 sim — five scenarios captured into docs\m8-r2-evidence.txt
#
#   === SCENARIO 1: happy path ===
#   Launch sim with new M8 .prg. Watch sees update available (4→5), prompt appears.
#   Accept → InstallView shows "Loading: 35%" / progress bar / "Don't close the app".
#   Completes ≤5 min. Type ש → real Hebrew titles. Open one → real content.
#   Long-press a word that maps to another article → jump.
#
#   === SCENARIO 2: mid-install app kill (force-quit) ===
#   Restart at v0.M7.2 baseline. Start install, wait until ~30% progress.
#   Force-kill the simulator process. Re-launch.
#   Verify: ResumeInstallView shows, resumes from ~30%, completes correctly.
#   Stdout should show: "M8 resume: chunks_received=37/100" or similar.
#
#   === SCENARIO 3: mid-install clean shutdown ===
#   Same as #2 but use simulator's "Stop App" menu (closer to a real watch sleep).
#   Same expected resume behavior.
#
#   === SCENARIO 4: battery low at launch ===
#   Set simulator battery slider to 8%. Launch with stale manifest → update detected.
#   Expect LowBatteryView: "Updates pending — plug in to continue".
#   Drag battery to 15%. Expect auto-transition to InstallView, install proceeds.
#
#   === SCENARIO 5: battery dies during install ===
#   Start install at 50% battery. Mid-install (around 30% progress), drag
#   battery slider to 4%. Expect install to pause (stop firing chunks),
#   LowBatteryView appears with "Install incomplete" message. Restore battery
#   to 20%. Expect auto-resume from saved chunksReceived state.
#
#   Each scenario gets a "=== SCENARIO N ===" header in m8-r2-evidence.txt.
#   Capture stdout (incl. fm:NNNNNN heap overlay), screenshot the progress UI
#   for at least scenarios 1, 4, and 5.

# Phase 6: ship
git add scripts/m8-corpus docs/server docs/m8-plan.md docs/m8-fail.txt docs/m8-pass.txt docs/m8-tooling-fail.txt docs/m8-tooling-pass.txt docs/m8-r2-evidence.txt versions/wikiwatch-M8.prg source/
git commit -m "M8: Real Hebrew Wikipedia corpus from ZIM"
git push -u origin m8-real-corpus
gh pr create --title "M8: Real Hebrew Wikipedia corpus from ZIM" --body ...
# CR-ist review → APPROVE → merge --merge --delete-branch → tag v0.M8
```

---

## Risks / non-goals

- **BLE-proxy concurrency unverified.** The plan assumes 2 in-flight `makeWebRequest`s work. CIQ docs say up to 4 is supported. Worst case discovered in R2: serializes to 1 in flight, install time goes from ~2 min → ~4 min over BLE. Still ≤5 min budget.

- **Storage write throughput unmeasured.** Plan assumes ~10-20 ms per `setValue`. If it's actually closer to 50-100 ms (as old M5.2 notes suggested for heavier values), the 4000-write install becomes 200-400 sec instead of 40-80 sec. Total install would be 4-7 min over BLE — could blow the budget. **Mitigation:** Plan B (documented above — 4-articles-per-key micro-batch). Decision point: after R2 measurement, before declaring M8 done.

- **CIQ response-size cap.** Undocumented in the CIQ reference; community sources put it at 32-64 KB for older firmware, ~200-500 KB for CIQ 4.x on Venu 2. Our chunks target 80 KB raw / ~20 KB gzipped on the wire — comfortably under historical limits. **If rejected:** halve chunk size again (20 articles each, 200 chunks total) — still fits both install time + RAM budget.

- **gzip support.** CIQ's `makeWebRequest` sends `Accept-Encoding: gzip` by default and decodes transparently. If the user's web server doesn't return gzip, install time over BLE goes from ~2 min → ~4 min (still acceptable). The server config is documented in `docs/server/README.md`.

- **ZIM file not committed to repo.** 698 MB. Dev host needs the .zim manually; documented in `scripts/m8-corpus/README.md`. Script complains clearly if path is missing.

- **Pageview dump URL may break over time.** stats.wikimedia.org changes URL schemes periodically. `select.ps1` documents the current URL + accepts a manual override.

- **`zimdump show` is slow.** ~50ms per article × 4,000 = 3-4 min to extract the full corpus. Acceptable for an offline build step. Cached in `scripts/m8-corpus/cached/`.

- **HTML structure varies.** Wikipedia infobox templates differ across article types (people, places, dates, concepts). Extractor regex is conservative (drop only `class="infobox"` exactly) — articles with non-standard templates won't have their infoboxes stripped. Acceptable; the 14 KB size cap catches outliers.

- **Article search depends on title-only ranking (M6.5).** Real Wikipedia titles include disambiguation suffixes ("יוסף (שופט)", "יוסף (בן יעקב)"). When the user types "יוסף", multiple results appear — *correct* behavior, real Wikipedia UX. M8 doesn't change ranking; if it's a pain point, M8.1 could add ambiguity-aware ranking.

- **Long-press → keyboard prefilled with a Wikipedia link.** Real cross-references in body text often have parenthesized disambiguation ("ראה דוד המלך (תנ״ך)"). Long-press picks one word at a time — picking "דוד" pre-fills the keyboard with "דוד" not "דוד המלך". The user can then type more or backspace. Same trade-off as M6.

- **Sim can't simulate true power-off.** The simulator's "Stop App" is a clean shutdown — `onStop` runs, the runtime gets to flush. A true watch power-off (dead battery, hardware reset) skips all teardown. We approximate true power-off by force-killing the simulator process (Task Manager → End Task on simulator.exe). This won't catch every edge case (e.g. a write that's in CIQ's Storage staging buffer but not yet flushed to non-volatile storage when the SoC dies). The fundamental guard against that is the *idempotent* `setValue` model — re-downloading a half-written chunk is safe. Worst case: 1-2 chunks of redundant work per crash.

- **The chunksReceived bitmap can itself be lost on crash.** If we crash *after* `putBatch` but *before* `markChunkReceived`, on resume we'll re-download that chunk's 40 articles (idempotent overwrite is safe). If we crash *after* `markChunkReceived`'s `setValue` is called but before it persists, we either redo (if not persisted) or use the new state (if persisted) — both correct. The order matters: `putBatch` *then* `markChunkReceived`, never reversed. Tested by `install_writesChunkToStorageBeforeReturning`.

- **Battery monitoring during install is poll-based, not interrupt-based.** Polling every 10 chunks (~10 sec on BLE) means battery can drop to ~3 % between polls before we react. Acceptable for our use case — the 5 % pause threshold has 5 % margin. A more aggressive (per-chunk) poll has measurable cost (~5 ms per `System.getSystemStats()` × 100 chunks = 500 ms added install time) and isn't worth it.

- **No spike branch.** Per project convention, mini-version-style improvements (M8.1+) handle anything surfaced by R2. The plan stays inline.

---

## Decisions locked in

1. **Target corpus size:** ~4,000 articles totalling ~8 MB body bytes (fills most of the 9 MB Storage cap).
2. **ID scheme:** Hebrew URL-encoded (e.g. `%D7%A9%D7%9C%D7%95%D7%9D` for שלום). Lossless + debuggable in browser.
3. **Popularity source:** Hebrew Wikipedia monthly pageview dump.
4. **Install UX:** Must complete in ≤5 min (target <1 min on WiFi). Achieved via chunked-download + per-article-storage + 2-in-flight parallelism, within the ≤300 KB transient RAM cap.
5. **RAM budget during install:** ≤300 KB transient above M7 baseline. Drives chunk size to ~80 KB raw / ~40 articles per chunk → 100 chunks total.
6. **Resumability:** install state persisted in Storage after every chunk write. Crash / power-off / app-close mid-install → next launch picks up at last successful chunk via `ResumeInstallView`. Version-mismatch detection invalidates stale partial corpora.
7. **Progress UI:** percentage (integer 0-100), progress bar, "Don't close the app" warning in red, `N / M articles` counter. Updates on every chunk callback.
8. **Battery gate:** install (first or resumed) refuses to start when `battery < 10% && !charging`. During install, pauses when `battery < 5% && !charging`. `LowBatteryView` shown in both cases; auto-resumes when charging or battery recovers.
