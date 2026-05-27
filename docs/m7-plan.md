# M7 — Real-network corpus from `wikiwatch.tomhe.app/`

**Status:** design phase. Server static files generated; watch-side code not yet written.

**Branch (when implementing):** `m7-network-corpus`
**Tag:** `v0.M7`
**Artifact:** `versions/wikiwatch-M7.prg`

---

## Goal

Replace the hard-coded `Fixtures.mc` corpus with articles pulled at runtime from a server the user owns (`wikiwatch.tomhe.app/`). Every launch performs a brief background check for a newer corpus; if one's available, the user gets a "do you want to update?" prompt that — on confirm — wipes local Storage and re-downloads everything. Otherwise the keyboard becomes functional immediately using whatever local data is present.

After M7, the app fundamentally has the shape it'll keep for the rest of the ladder: a real distributed system with a server (uploaded by you) and a client (the watch). M8 will swap the M6.5 fixture content for real Hebrew Wikipedia articles — same plumbing, real data.

---

## Server contract

Static hosting, no auth, no API. Two endpoint shapes:

### `GET /manifest.json`

```json
{
  "version": 4,
  "totalBytes": 6234,
  "articles": [
    { "id": "shalom",       "title": "שלום",  "popularity": 100 },
    { "id": "shabbat",      "title": "שבת",   "popularity": 99  },
    ...
  ]
}
```

- `version` — integer. Watch compares against the locally-stored version. Mismatch triggers update prompt. The M7-shipped server content matches M6.5 fixtures so `version` stays at `4` (no migration on the existing M6.5 installs that upgrade their `.prg`).
- `totalBytes` — sum of all article body byte sizes (utf-8). Lets the watch compute "estimated remaining bytes vs free Storage" before committing to a download.
- `articles[].id` — kebab-case slug, also used in the article URL.
- `articles[].title` — Hebrew display title (may contain ASCII `"` / `'` / `-` per M6.2; M6.5 `Search._normalize` handles these on the match side).
- `articles[].popularity` — integer 0-100, used for ranking.

Content-Type: `application/json` (sim's BLE proxy rejects `application/octet-stream`).

### `GET /article/<id>.txt`

UTF-8 Hebrew Markdown body. First non-empty line is the H1 (`# <title>`) — matches the `fixtures_titlesMatchBodies` invariant tested in M5.3. Content-Type: `text/plain; charset=utf-8`.

### Hosting requirements

- HTTPS preferred (Garmin allows HTTP but most setups force HTTPS).
- Stable URLs. Each article id maps 1:1 to `/article/<id>.txt`.
- CORS not relevant (no browser involvement).
- 36 article files at M7, each <500 B → total `~10 KB`. Will grow with M8's real corpus.

---

## Watch-side flow

### State machine

```
[launch]
   |
   Storage.manifest empty?
      |
      Yes → [InstallView] (full download)
      |       |
      |       (on complete) → [KeyboardView] (functional)
      |       (on error)    → [KeyboardView] (degraded — no corpus, search returns nothing)
      |
      No  → [UpdateCheckView] (keyboard rendered NON-functional + "checking..." overlay)
              |
              (1 sec Timer race against manifest fetch)
              |
              ├── Network OK + remote.version == local.version → [KeyboardView] (functional)
              ├── Network OK + remote.version >  local.version → [UpdatePromptView]
              └── Timeout / error / other failure              → [KeyboardView] (functional, stale)
```

### `UpdatePromptView`

Full-screen modal-ish view:
- Title: "wikiwatch update available"
- Body: "<N> new articles" (or "version M4 → M5") — whichever the data supports
- Two tap zones: top half = "Yes, update" → wipe Storage → push `InstallView`. Bottom half = "No, later" → pop back to `KeyboardView` (functional with stale data).
- Back button = same as "No, later".

### `InstallView`

Full-screen during download:
- "Loading wikiwatch: N / M articles" + a tiny progress arc or bar around the perimeter.
- Articles installed sequentially (NOT concurrently — keeps memory bounded; BLE proxy is single-channel anyway).
- On complete: `WatchUi.switchToView(KeyboardView)` (replace, don't push — the keyboard is the new root).
- On any per-article fetch error: log + skip + continue. Final summary on the view: "Installed N of M (K failures, retry from menu)". For M7 simple-mode we just bail; M8 can add retry.

### `UpdateCheckView`

Renders the keyboard layout but with `setBuffer("")` + a "checking for updates..." text overlay at the bottom (where M6.5's `fm:NNNNNN` overlay lives — shares that real estate during the check).

While in this view, taps are silently absorbed (no `KeyboardDelegate` attached — uses a dedicated `UpdateCheckDelegate` that does nothing on tap).

After the race resolves:
- Success same-version → `WatchUi.switchToView(KeyboardView)` (replace, not push, so back button doesn't re-trigger the check).
- Success newer-version → `WatchUi.switchToView(UpdatePromptView)`.
- Timeout/error → `WatchUi.switchToView(KeyboardView)`.

---

## Modules / files

### New

- `source/net/Downloader.mc` — pure-ish (imports `Communications`, `System`). API:
  - `fetchManifest(callback as Method) as Void` — fires `callback.invoke(rc, manifestDict?)` on completion.
  - `fetchArticle(id as String, callback as Method) as Void` — fires `callback.invoke(rc, id, body?)`.
  - `installAll(progressCallback as Method, doneCallback as Method) as Void` — iterates manifest IDs, calls `fetchArticle` sequentially, R4-guarded `ArticleStore.putBody` on each, fires `progressCallback.invoke(i, n)` per completion, `doneCallback.invoke(installedCount)` at end.
  - `parseManifestResponse(rc as Number, data as Dictionary?) as Dictionary` — pure helper for tests: returns `{:ok, :manifest}` or `{:ok => false, :error => reason}`.

- `source/views/UpdateCheckView.mc` + `UpdateCheckDelegate.mc` — temporary view shown for ≤1 second on every launch.
- `source/views/UpdatePromptView.mc` + `UpdatePromptDelegate.mc` — yes/no prompt.
- `source/views/InstallView.mc` + `InstallDelegate.mc` — progress UI during full download.

### Modified

- `source/wikiwatchApp.mc` — `getInitialView()` branches on `Manifest.isEmpty()` → first-launch path; otherwise → UpdateCheckView.
- `source/storage/Manifest.mc` — gain `wipeArticles()` helper (deletes all `article:<id>` keys). Used by the "yes, update" path.

### Deleted

- `source/models/Fixtures.mc` — articles only come from network now.
- `source/storage/FixtureInstaller.mc` — replaced by `Downloader.installAll` triggered from `InstallView`.
- `source/tests/test_Fixtures.mc` + `source/tests/test_FixtureInstaller.mc` — corresponding tests gone. Net test count: 176 - 9 (estimated removed) + new Downloader tests (~5).

---

## Tests

R3 coverage extends to `source/net/`. New tests:

1. `downloader_parseManifestSuccess` — given `rc=200` + valid dict, returns `{:ok=true, :manifest=...}`.
2. `downloader_parseManifestRejectsBadRc` — `rc=404` returns `{:ok=false, :error=...}`.
3. `downloader_parseManifestRejectsMissingVersion` — manifest without `:version` returns `{:ok=false}`.
4. `downloader_parseManifestRejectsMissingArticles` — same.
5. `manifest_wipeArticles` — write a manifest + 3 article bodies, `wipeArticles()`, verify all `article:<id>` keys are gone and `manifest` key remains.

UpdateCheckView's 1-second timer race + view-switching logic isn't directly testable — relies on R2.

---

## R-rule status (anticipated)

| Rule | Plan |
|---|---|
| R1 | TDD on Downloader pure helpers + Manifest.wipeArticles (FAIL→PASS captured). |
| R2 | Sim launch + screenshots of UpdateCheckView + InstallView. **Real-watch sideload is REQUIRED** for full network testing (sim BLE proxy returns RC=-300 / -400 for many endpoints; truth comes from a Garmin actually hitting `wikiwatch.tomhe.app/`). |
| R3 | New `source/net/` covered by Downloader tests. |
| R4 | All `setValue` calls (Manifest.save, ArticleStore.putBody) keep their existing freeMemory guards. New: `Manifest.wipeArticles` only calls `deleteValue` (no allocation, no R4 trigger). |
| R5 | Per-article fetch holds at most one body in memory at a time (sequential install). Peak transient = body size + manifest. Well under M6.5's reclaimed budget. |
| R6 | `Downloader` lives in new `source/net/` directory (NOT `source/models/`) because it imports `Communications` + `System`. |
| R7 | `m7-network-corpus` (milestone branch, not `fix/`) + `M7: Real-network corpus + update-check flow` title. |
| R8 | Build clean with the 2 baseline warnings. |

---

## Server static files (this PR)

Generated under `docs/server/` for you to upload to `wikiwatch.tomhe.app/`:

- `docs/server/manifest.json` — the v4 manifest, 36 articles.
- `docs/server/article/<id>.txt` — 36 individual UTF-8 body files.
- `docs/server/README.md` — upload instructions for you.

Upload destination preserves the same path structure:
- `wikiwatch.tomhe.app/manifest.json`
- `wikiwatch.tomhe.app/article/shalom.txt`
- `wikiwatch.tomhe.app/article/shabbat.txt`
- ... etc.

---

## Risks / open questions

- **HTTPS cert.** Garmin CIQ requires server TLS cert to be valid. If `wikiwatch.tomhe.app/` uses self-signed or expired, fetches fail with `RC=-1003` (cert error). User confirms cert is valid before M7 testing.
- **Per-article request latency.** Each `Communications.makeWebRequest` over BLE proxy costs ~500-2000 ms. 36 articles × 1 sec ≈ 36 seconds for first install. Acceptable for one-time setup; M9 might add resumability.
- **Storage commit during install.** If user backgrounds the app mid-install, `Manifest.save` happens once at the start of `installAll` (so partial-install state is recoverable by re-running install). Per-article `ArticleStore.putBody` happens after each fetch — each one's atomic.
- **No way to test 1-second race in sim cleanly.** R2 evidence for `UpdateCheckView` will rely on either a long-network-delay simulation or just the real watch.

---

## User decisions (locked in 2026-05-27)

1. **TLS cert** — `https://wikiwatch.tomhe.app/` is serving with a valid cert. ✓
2. **Update prompt UX** — "Yes" = tap top half, "No" = tap bottom half. ✓
3. **`UpdateCheckView` budget** — **750 ms**. Compromise between 500 ms (too tight for cold BLE wake — Garmin's BLE proxy can take ~1500 ms when the phone hasn't talked to the watch recently) and 1000 ms (eats more startup latency than needed when network is warm). Easy to bump in a hotfix if real-watch testing shows it's too short.
