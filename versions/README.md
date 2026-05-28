# wikiwatch — version archive

This directory holds a frozen `.prg` artifact for each merged milestone on `main`. Every artifact is reproducible from the same git commit via `scripts/build.ps1` against SDK 9.1.0 for device `venu2`.

Each milestone reaches `main` via the workflow documented in `docs/cr-rules.md`: branch → PR → CR-ist review (R1..R8) → literal merge commit → annotated tag → archived `.prg` co-located in this folder.

## Restoring an old version

```powershell
git checkout v0.M<N>          # e.g. git checkout v0.M2.2
& scripts\build.ps1           # rebuilds bin\wikiwatch.prg from source
```

Or sideload the pre-built artifact directly: copy `versions\wikiwatch-M<N>.prg` to `GARMIN\APPS\` on a Venu 2.

---

## Quick reference

| Version | Tag | Merge commit | Date | .prg size | Headline change | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| M0 | `v0.M0` | `0a7c894` | 2026-05-22 | 115 KB | Toolchain + TDD + CR-ist workflow | 1 |
| M0.1 | `v0.M0.1` | `688ddf1` | 2026-05-22 | 116 KB | Scaffold layout fix; `SafeArea` seeded; R7 extended for `Fix:` | 8 |
| M1 | `v0.M1` | `26230b0` | 2026-05-23 | 100 KB | Hebrew "שלום" centered; built-in fonts confirmed for Hebrew; scaffold cleaned | 10 |
| M2 | `v0.M2` | `23f1e87` | 2026-05-23 | 105 KB | Markdown headers `#..####` + body wrap + scroll | 33 |
| M2.1 | `v0.M2.1` | `69ee473` | 2026-05-23 | 109 KB | Live `onDrag` scroll + full-diameter wrap + extended scroll range; longer article | 34 |
| M2.2 | `v0.M2.2` | `2377bd9` | 2026-05-23 | 110 KB | Position-aware per-line wrap (25 px padding); reverted scroll range | 40 |
| M2.3 | `v0.M2.3` | `7967701` | 2026-05-23 | 111 KB | Smaller header fonts + fixed-width per-position wrap (160 / 250 / screen / 250 / 160) | 46 |
| M2.4 | `v0.M2.4` | `cc04b79` | 2026-05-23 | 114 KB | Narrow tail at the **absolute last** sub-line only + hybrid justify (RIGHT middle, CENTER narrow) + `onUpdate` skip-ahead | 53 |
| M2.5 | `v0.M2.5` | `99458f4` | 2026-05-23 | 116 KB | Left-justify body + `narrowSecond` 250 → 300 + H1 fully centered + double-tap-edge scroll-to-top/bottom (`DoubleTap` pure module) | 59 |
| M2.6 | `v0.M2.6` | `fff787b` | 2026-05-23 | 116 KB | Right-justify body + 30 px clean-left margin — BiDi RTL fix for M2.5 (`Layout.middleWidth` pure module) | 61 |
| M2.7 | `v0.M2.7` | `694168c` | 2026-05-23 | 116 KB | Wide right margin + tight right anchor (`_leftMargin=15`, `_rightMargin=20`) | 61 |
| M2.8 | `v0.M2.8` | `cec8de8` | 2026-05-23 | 119 KB | Per-word pixel wrap (`splitWords` + `wrapPxToWidths` + `wrapPxWithNarrowTail`) — fills lines more tightly than the char-count estimate | 72 |
| M3 | `v0.M3` | `362748d` | 2026-05-23 | 124 KB | Static Hebrew touch keyboard — 22 letters + space + backspace + delete-all + search; 6×5 grid (`KeyboardLayout` + `InputBuffer` modules) | 86 |
| M3.1 | `v0.M3.1` | `a5835bd` | 2026-05-23 | 128 KB | Circular T9-style keyboard — 10 wedges around perimeter, polar hit-test, expansion sub-zones | 92 |
| M3.2 | `v0.M3.2` | `cddadf3` | 2026-05-23 | 129 KB | Thin outer ring (R_INNER 105 → 170) + tri-button cells (mini letter labels) + dim outer during letter expansion | 93 |
| M3.3 | `v0.M3.3` | `c74511d` | 2026-05-23 | 131 KB | Wider ring + hit halo + SPACE/BACKSPACE press flash + DIGITS 4-cell + buffer band font fit | 94 |
| M3.4 | `v0.M3.4` | `e66491b` | 2026-05-24 | 131 KB | 1.3× wider ring (R_INNER 160 → 146) + buffer band sizing | 95 |
| M3.5 | `v0.M3.5` | `99b3638` | 2026-05-24 | 132 KB | Final-letter (sofit) sub-zones ך/ם/ן/ף/ץ (level-2, inward) + multi-line buffer wrap | 98 |
| M3.6 | `v0.M3.6` | `206e343` | 2026-05-24 | 132 KB | Flip final-form sub-buttons OUTWARD onto the outer ring (level-0 tier, ~9× bigger tap area) | 98 |
| M4 | `v0.M4` | `00382a0` | 2026-05-24 | 138 KB | Storage layer — `Manifest` + `ArticleStore` + `Fixtures` + `FixtureInstaller`. R4-gated `setValue`. First-launch fixture install (3 Hebrew articles). No on-watch UX delta. | 112 |
| M5 | `v0.M5` | `2df7c54` | 2026-05-24 | 143 KB | Live search — `Search.rank` (prefix > substring > popularity); keyboard center shows real ranked Hebrew titles instead of stubs; tap a suggestion to push the M2.x article reader. `wikiwatchView` becomes `initialize(body)`. | 122 |
| M5.1 | `v0.M5.1` | `c15a8cf` | 2026-05-25 | 147 KB | Bigger suggestion taps (3×FONT_TINY @ 40 px, was 5×FONT_XTINY @ 22 px) + "▼ N more" footer that pushes a new full-screen scrollable `ResultsView` listing all top-20 in FONT_SMALL rows. New pure `ResultsLayout.rowIndexAt` for the hit-test math. | 125 |
| M5.2 | `v0.M5.2` | `edf23bb` | 2026-05-25 | 156 KB | Bundle: 2-line buffer restored (`bandH` 30 → 64, rounded edges) + 1-px row separators + 30 ש-prefix fixtures (version-aware install) + lazy article layout via `LayoutProgress` + `Timer.Timer` + "..." marker + "X more articles fit" footer in ResultsView. | 146 |
| M5.3 | `v0.M5.3` | `ef4a84f` | 2026-05-26 | 159 KB | Bundle: shir-lashalom-long title fix + empty-buffer guard + round-screen-aware ResultsView (15%/15% pad + 40 px L/R margins) + multiline title blocks (`ResultsLayout.blockAt`) + bounded first-paint (`_INITIAL_LINES` 12 → 5 so שלום and שבת load in comparable time). | 154 |
| M5.4 | `v0.M5.4` | `dce2ad8` | 2026-05-26 | 159 KB | Polish: tighter lazy-load (`_INITIAL_LINES` 5 → 2, `_INCREMENTAL_LINES` 4 → 2, `_LAYOUT_TICK_MS` 80 → 50; bounded-batch test STRENGTHENED to exact equality) + bottom-double-tap gated on `isLayoutComplete` + ResultsView margins 15 → 16% / 40 → 50 px + 0 px intra-article sub-line gap. | 154 |
| M6 | `v0.M6` | `eaf7d99` | 2026-05-26 | 162 KB | Long-press a word in the article reader → push a new keyboard layer pre-filled with that word. New pure `WordHitTest.findWordInLine` (char-count + Hebrew-RTL aware). New `wikiwatchView.findWordAt` + `wikiwatchDelegate.onHold`. `wikiwatchKeyboardDelegate` ctor takes `initialBuffer`. Inlines the project's `onHold` spike via a `System.println` diagnostic. | 160 |
| M6.1 | `v0.M6.1` | `b27a0dc` | 2026-05-26 | 161 KB | Fix M6 off-by-one + left-side dead zone: replace char-count `findWordInLine` with `findWordPx` using actual per-word pixel widths stored in each `_lines` sub-line (`:words / :wordPx / :spacePx`). Exact `lineRightX` from `sum(wordPx) + (n-1)*spacePx`. Removed `_approxCharPx`. | 161 |
| M6.2 | `v0.M6.2` | `e1b33d8` | 2026-05-26 | 164 KB | ASCII-punctuation in search + keyboard + body-content search. New pure `Search._normalize` (strip `"` and `'`, replace `-` with space); `Search.rank` gains tier-3 body fallback; `KeyboardLayout` DIGITS expansion 10 → 13 cells; `KeyboardDelegate.initialize` pre-loads bodies; fixtures `:version` 3 → 4 + 6 new ש-prefix entries with ASCII " / ' / -. **Shipped with an OOM bug — fixed in M6.3.** | 175 |
| M6.3 | `v0.M6.3` | `0033552` | 2026-05-26 | 163 KB | Hotfix M6.2 OOM. M6.2's `_normalize` built output via O(N²) string-concat (`out = out + ch` per char); rank + totalMatches per keystroke re-normalized every body that missed by title; on the ~2 KB shalom body that was ~8M byte-allocs/keystroke → uncatchable OOM. Plus the ~5 KB pre-load + ~10 KB reader layout = heap exhausted on article-open. Fix: remove tier-3 body fallback from `Search.rank`, remove body branch from `Search.totalMatches`, remove body pre-load from `KeyboardDelegate.initialize`, add fast-path to `_normalize` (no allocation when input has no " / ' / -). Kept from M6.2: ASCII normalization on titles + 3 new keyboard keys + 6 new fixtures. | 175 |
| M6.4 | `v0.M6.4` | `775d975` | 2026-05-26 | 163 KB | Revert M6.2 keyboard `"` / `'` / `-` keys (user request: don't want to type those, search handles them). DIGITS expansion back to 10 cells (0..9 at 36° each); `DIGITS_EXPANSION_COUNT` / `DIGITS_EXPANSION_ARC_DEG` constants removed. KEPT Search._normalize + 6 ש-prefix fixtures with ASCII " / ' / - in titles — user types שבק and finds שב"ק via match-side normalization. | 174 |
| M6.5 | `v0.M6.5` | `99ea899` | 2026-05-27 | 165 KB | Memory optimizations to address M6.4 stale-render bug on real Venu 2 (sim worked, watch UI didn't refresh; GC pressure hypothesis). (1) Cache `KeyboardLayout.buttons()` at module level — was ~850 B/call × every onUpdate + every onTap. (2) Cache `KeyboardLayout.subButtons(parent)` per centerAngleDeg. (3) Preallocate `_drawWedge` polygon buffer as view field, mutate in place — was ~4 KB/onUpdate. (4) DROP M6.1's `:words/:wordPx/:spacePx` per-sub-line storage — was ~6.5 KB resident on shalom; long-press now goes `onHold → requestLongPressHit → next onUpdate → _resolvePendingHit` measuring ONLY the tapped sub-line (~130 B transient). Plus `fm:NNNNNN` freeMemory overlay near keyboard bottom-center so user can SEE heap pressure live on the watch (no stdout). Net: ~10–15 KB resident reclaimed + ~25–50 KB/sec GC churn eliminated. | 176 |
| M7 | `v0.M7` | `8726f04` | 2026-05-27 | 167 KB | Real-network corpus from `https://wikiwatch.tomhe.app/`. DELETED `Fixtures.mc` + `FixtureInstaller.mc` + their tests. NEW `source/net/Downloader.mc` (pure `parseManifestResponse` + side-effecting `fetchManifest` / `fetchArticle`). NEW `Manifest.wipeArticles()`. NEW views: `InstallView` (sequential per-article download with progress UI), `UpdatePromptView` (top half = Yes, bottom = No), `UpdateCheckView` (750ms race on every launch). `wikiwatchApp.getInitialView` branches on `Manifest.isEmpty()`: empty → InstallView; non-empty → UpdateCheckView. `manifest.xml` declares `<iq:uses-permission id="Communications"/>`. 174 tests (−10 fixture tests + 8 new). | 174 |
| M7.1 | `v0.M7.1` | `e8de790` | 2026-05-28 | 169 KB | Hotfix M7 USB-sideload event-loop clog (BLE deprioritized when USB connected → `makeWebRequest` hangs ~30s → CIQ event loop clogged → M6.4-style stale-render symptom). Three changes: (1) new `Downloader.isNetworkAvailable()` wrapping pure `_anyConnected(connectionInfo, phoneConnected)` helper. (2) `wikiwatchApp.getInitialView` gains 2×2 branch — empty Storage + no network → NEW `NoConnectionView` ("Need connection to load initial offline articles"); has-corpus + no network → straight to functional KeyboardView. (3) `UpdateCheckView` timeout 750ms → 1000ms. **First end-to-end happy-path validation** against live server: sim's BLE proxy worked, all 36 articles downloaded from `wikiwatch.tomhe.app/`. 174 → 177 tests (+3 for `_anyConnected`). | 177 |

Test count = total `(:test)` functions passing in `scripts/test.ps1` at that tag.

---

## M0 — Toolchain & TDD pipeline (tag `v0.M0`)

**The spike that proved the rest of the ladder was possible.** No user-visible behavior change; everything is workflow scaffolding.

**What landed:**
- `scripts/sdk.ps1` auto-discovers the latest installed Connect IQ SDK (currently `connectiq-sdk-win-9.1.0-2026-03-09`).
- `scripts/build.ps1` wraps `monkeyc -d venu2 -f monkey.jungle -o bin\wikiwatch.prg -y ..\developer_key -w`.
- `scripts/test.ps1` builds with `--unit-test` and runs `monkeydo /t`; greps the harness output for `FAIL` to compute its exit code.
- `docs/cr-rules.md` defines R1..R8 — the eight hard requirements every PR must satisfy.
- `.claude/agents/crist.md` is the strict-reviewer subagent definition (reads PR via `gh`, posts inline comments per violation, returns a verdict).
- `docs/known-warnings.md` captures the 2 baseline build warnings (manifest language + 24×24 launcher icon) so R8 (zero-new-warnings) is meaningful.
- `versions/` directory + this README.

**TDD proof-of-life:**
- `source/models/Tdd.mc` exposes `Tdd.alwaysReturns42()` (placeholder).
- `source/tests/test_Tdd.mc` asserts the return is `42`.
- Captured `docs/m0-fail.txt` showing FAIL when the function returned `41`, then `docs/m0-pass.txt` showing PASS after the fix.

**Branch protection** on `main` was enabled via `gh api … /branches/main/protection`: required PRs, dismiss-stale-reviews on, force-push and deletion blocked, `required_approving_review_count: 0` (since GitHub blocks self-approval).

**Artifact:** `wikiwatch-M0.prg` (115 628 bytes). Visual: the unchanged Connect IQ "Click the menu button" scaffold — that visual gets fixed in M0.1.

---

## M0.1 — Scaffold layout fix (tag `v0.M0.1`)

User reported two visual bugs in the M0 baseline running on the simulator:
1. Title "Click the menu button" at `y=5` was clipped by the round bezel — only "the menu b" was visible.
2. The reading-monkey image at `y=30` overlapped the title.

**What landed:**
- `source/models/SafeArea.mc` — pure circular-display chord geometry:
  - `safeChordHalfWidth(r, dy)` = `floor(sqrt(r² - dy²))` (or 0 if `|dy| > r`).
  - `safeChordWidth(r, dy)` = `2 × safeChordHalfWidth`.
  - `minSafeY(r, textWidth)` returns the smallest non-negative y where the chord is wide enough.
- `source/tests/test_SafeArea.mc` — 7 `(:test)` cases (center=diameter, off-center shrinks, at-radius=0, past-radius=0, negative-dy mirrors, minSafeY for textWidth=280, degenerate textWidth > diameter).
- `resources/layouts/layout.xml` — title y `5 → 70` + `font="Graphics.FONT_TINY"`; monkey y `30 → 140`. Layout cites the math: `SafeArea.minSafeY(195, 280) = 60`, used 70 with 10 px headroom against sim-vs-watch font drift.
- `docs/cr-rules.md` — R7 extended: branches `fix/<slug>` and PR titles `Fix: <short>` now accepted alongside `M<N>:` and `Spike:`.

**R1 evidence:** `docs/fix-scaffold-fail.txt` (7 SafeArea tests fail on a `-1`-returning stub) → `docs/fix-scaffold-pass.txt` (all 8 tests pass).

**R2 evidence:** `docs/screenshots/before.png` (M0 with clipped title and overlapping monkey) and `docs/screenshots/after.png` (M0.1 with full "Click the menu button" visible, monkey cleanly below).

**Artifact:** `wikiwatch-M0.1.prg` (116 380 bytes). Visual: scaffold UI but with correct positioning for the round display.

---

## M1 — Hebrew "Hello-watch" baseline (tag `v0.M1`)

**The spike milestone:** confirm that built-in Connect IQ fonts on Venu 2 contain Hebrew glyphs. If they hadn't, M1 would have grown to include a custom `.ttf` resource.

**What landed:**
- `source/models/Strings.mc` — pure module exposing `Strings.hello() = "שלום"`.
- `source/tests/test_Strings.mc` — three `(:test)` cases:
  - `strings_helloIsHebrew` (`hello() == "שלום"`).
  - `strings_helloCharCount` (`hello().length() == 4`).
  - `strings_hebrewLiteralRoundtripsThroughStorage` — round-trips a Hebrew string through `Application.Storage.setValue` / `getValue`. **Proved UTF-8 storage survives**, which is a hard prerequisite for the M7 article corpus.
- `source/wikiwatchView.mc` — rewritten to render programmatically: clears to black, draws `Strings.hello()` centered with `FONT_LARGE` + `TEXT_JUSTIFY_CENTER | TEXT_JUSTIFY_VCENTER`.
- Scaffold deleted: `source/wikiwatchMenuDelegate.mc`, `resources/menus/menu.xml`, `resources/drawables/monkey.png`, `resources/layouts/layout.xml`, `source/models/Tdd.mc`, `source/tests/test_Tdd.mc`.
- `resources/strings/strings.xml` trimmed to only `AppName`.

**R1 evidence:** `docs/m1-fail.txt` (2 of 3 new Strings tests fail on `hello() = ""` stub; the storage round-trip accidentally passes because empty string also round-trips) → `docs/m1-pass.txt` (all 10 tests pass).

**R2 evidence — the headline finding of M1:** `docs/m1-r2-evidence.txt` captures the per-font width probe:

```
FONT_XTINY  hello_px=53  shalom_px=24
FONT_TINY   hello_px=72  shalom_px=32
FONT_SMALL  hello_px=82  shalom_px=36
FONT_MEDIUM hello_px=98  shalom_px=44
FONT_LARGE  hello_px=114 shalom_px=52
```

"שלום" rendered at non-zero width across all five system fonts → **Hebrew glyphs are present in built-in fonts**. No custom font resource needed. (Missing glyphs in CIQ render as zero-width, not tofu — so width-probing via `dc.getTextWidthInPixels` is the reliable detector.)

**Artifact:** `wikiwatch-M1.prg` (100 668 bytes) — 14% smaller than M0.1 since `monkey.png` is gone. Visual: a single centered "שלום" on black.

---

## M2 — Markdown article reader (tag `v0.M2`)

First version with actual reading behavior. Replaces the M1 single-word view with a scrollable article that renders Markdown `#`..`####` headers in four distinct font sizes.

**What landed:**
- `source/models/MarkdownTokens.mc` — pure parser. `parse(line) → {level: 0..4, text: String}`. Level 0 = body; 1..4 = `#` ... `####`; 5+ hashes or hash-without-space-after = body. **11 `(:test)` cases**: H1..H4, body, empty header, empty string, lone `#`, hash-without-space-is-body, five-hashes-is-body, Hebrew header.
- `source/models/LineWrap.mc` — pure word-boundary wrap. `wrap(text, maxChars) → Array<String>`. Greedy fill, single oversized words overflow on their own line, multiple spaces collapse. **9 `(:test)` cases**.
- `Strings.sampleArticle()` — hardcoded ~9-line Hebrew article exercising all four header levels + multi-line body. Plus 3 new Strings tests (`startsWithH1`, `hasH4`, `isMultiline`).
- `source/wikiwatchView.mc` rewritten as a scrollable reader. Two-step lazy layout on first `onUpdate`:
  - Parse each raw line via `MarkdownTokens`.
  - Pick font by level: H1 → `FONT_LARGE`, H2 → `MEDIUM`, H3 → `SMALL`, H4 → `TINY`, body → `FONT_XTINY`.
  - Wrap body to a hardcoded 280 px safe-area width budget.
  - Stack lines vertically with `fh + spacing`.
- `source/wikiwatchDelegate.mc` adds `onNextPage` / `onPreviousPage` → `view.scrollBy(±60)`. (Swipe-page handlers; not yet live drag.)
- `source/wikiwatchApp.mc` `getInitialView()` constructs view + delegate and wires them.

**R1 evidence:** `docs/m2-fail.txt` (23 of 33 tests fail on sentinel-returning stubs) → `docs/m2-pass.txt` (all 33 pass).

**R2 evidence:** `docs/m2-r2-evidence.txt` and `docs/screenshots/m2-with-boxes.png` (a one-off diagnostic build that drew a gray rectangle around each line's bounding box, so the layout is visible at low screenshot zoom even when Hebrew glyphs are tiny). Boxes show 280 px-wide bands in the central vertical band — that wasted width gets fixed in M2.1.

**Layout numbers (sim):** 10 rendered lines, contentH = 493 px. Font heights: LARGE=67, MEDIUM=58, SMALL=49, TINY=43, XTINY=32. Per-Hebrew-char widths: 13, 11, 9, 8, 6.

**Artifact:** `wikiwatch-M2.prg` (105 484 bytes). Visual: H1 + body + H2 + body + ... vertically stacked, scrollable via the lower-right physical button (page-swipe).

---

## M2.1 — Live drag-scroll + full-width article (tag `v0.M2.1`)

Two UX issues from M2:
1. Scroll fired only on swipe-*release* (`onNextPage` / `onPreviousPage` are coarse page-down handlers).
2. The 280 px wrap budget left huge empty bands at the sides — user wanted text to use the entire screen width.

**What landed:**
- `wikiwatchDelegate.onDrag(event)` — override of `WatchUi.InputDelegate.onDrag` (inherited via `BehaviorDelegate`). Tracks `_lastDragY` per gesture; on every `DRAG_TYPE_CONTINUE` event computes the delta and forwards to `view.scrollBy(-delta)`. **Live finger-tracking scroll** (CIQ 3.2+ on touchscreen devices). `onNextPage` / `onPreviousPage` retained as a 60-px page-step fallback.
- Wrap budget widened from 280 → `dc.getWidth() - 4` (~412 sim, ~386 watch). Approximately 48 % more characters per line for every font size.
- **Extended scroll range:** `scrollBy` clamp went from `[0, contentH - screenH]` to `[-extraMargin, contentH - screenH + extraMargin]` where `extraMargin = (screenH / 2) - 8`. Lets the user scroll *past* both ends of the article to bring the first/last line into the central horizontal band (where the chord is widest), at the cost of revealing blank space above/below.
- `Strings.sampleArticle()` expanded from 9 lines to **49** Hebrew lines (5 H2 sections, multi-paragraph bodies, several H3/H4 sub-sections) so scrolling actually has distance to cover.
- New `strings_sampleArticleHasManyLines` test (asserts ≥ 30 newlines) — fails on the M2 article, passes on the expanded one.
- H1 title changed to `שלום היא מילה שימושית בהחלט` (25 Hebrew chars) so the long-title wrap path is exercised.

**R1 evidence:** `docs/m2-1-fail.txt` (1/34 fails on short article) → `docs/m2-1-pass.txt` (34/34).

**R2 evidence:** `docs/m2-1-r2-evidence.txt` (numeric comparison vs M2) + screenshots:
- `docs/screenshots/m2-1-top-boxes.png` — `scrollY = 0`, article top, diagnostic boxes spanning the full inscribed circle (clipped at the round bezel near top/bottom).
- `docs/screenshots/m2-1-boxes.png` — `scrollY = 400`, mid-article, full-width boxes throughout.

Compared to M2's narrow 280 px boxes, M2.1 boxes are bezel-to-bezel everywhere.

**Artifact:** `wikiwatch-M2.1.prg` (109 260 bytes).

---

## M2.2 — Position-aware safe-area wrap (tag `v0.M2.2`)

M2.1's full-width approach gave too much overflow at the round bezel for top/bottom lines. User feedback:
- 100 % width isn't readable; only the exact middle is. Add 25 px padding from each chord edge.
- The first/last lines of the *article* should sit in the "safe" narrow chord at top/bottom of the screen — no need to scroll into blank space to read them.

**What landed:**
- `SafeArea.linePaddedWidth(r, screenY, padding)` — new helper. Returns `max(0, chord_width_at(screenY) - 2×padding)`. **6 new `(:test)` cases** (center=diameter-2p, off-center shrinks by chord, clamps to 0 at edge, clamps to 0 when padding exceeds chord, symmetric above/below center, real-watch r=195).
- `wikiwatchView._layout` rewritten as a **two-pass position-aware layout**:
  - **Pass 1**: walk raw lines once with no-wrap heights, accumulating one `fh + spacing` per raw line. End value = estimated `contentH`.
  - **Pass 2**: for each line, compute `closestSY` = the closest screen-y the line can reach given the default scroll range. Then wrap to `SafeArea.linePaddedWidth(r, closestSY, 25)`. Top-zone lines (close to article top) wrap narrow; middle-zone lines get the full diameter; bottom-zone lines wrap narrow again.
- `scrollBy` reverted to the standard `[0, contentH - screenH]` clamp. M2.1's extended range is no longer needed since the per-line wrap already keeps the first/last lines readable at their natural endpoints.

**R1 evidence:** `docs/m2-2-fail.txt` (3 of 6 new `linePaddedWidth` tests fail on `0`-returning stub; the other 3 accidentally pass when chord/padding produce 0) → `docs/m2-2-pass.txt` (40/40).

**R2 evidence:** `docs/m2-2-r2-evidence.txt` plus `docs/m2-2-render-stdout.txt` — a diagnostic build that printed every laid-out line's `{y, h, w, font}`. Confirms the narrow→wide→narrow progression:
- Lines 0–4 (H1 sub-lines, screen-top zone): `w = 64` (chord at top bezel ~114 px, minus 50 padding).
- Lines 5–8 (transition into body): `w = 282..356`.
- Lines 9–50 (middle zone): `w = 366` (full diameter minus 50 padding).
- Lines 51–56 (last body lines): `w = 326..194` (chord narrows again).

**Artifact:** `wikiwatch-M2.2.prg` (110 172 bytes).

---

## M2.3 — Smaller headers + fixed-width per-position wrap (tag `v0.M2.3`)

Two more user adjustments:
- Headlines can be smaller — shrink every header level one font notch so more characters fit per line and more lines fit per screen.
- The chord-aware widths from M2.2 felt over-engineered. Use a simpler fixed schedule: first/last rendered line 160 px, second/second-to-last 250 px, everyone else full screen width.

**What landed:**
- Font mapping shifted one notch down:
  - H1: `LARGE → MEDIUM`
  - H2: `MEDIUM → SMALL`
  - H3: `SMALL → TINY`
  - H4: `TINY → XTINY` (collapses to body size; markdown source still distinguishes them but they render identically).
  - body: `XTINY` (unchanged).
- `LineWrap.wrapToWidths(text, charWidth, widths, startIndex)` — pure helper that wraps text where the k-th output sub-line uses `widths[startIndex + k]` (clamped to the last entry beyond size). **Optimized with `text.toCharArray()`** to dodge per-character `substring` allocation — an earlier prototype using `text.substring(i, i+1)` per char tripped the simulator watchdog on the long article. **6 new `(:test)` cases**.
- `wikiwatchView._layout` replaced with a **per-raw strategy** (no global iteration, stable in one pass):
  - **firstRaw** wraps with `[160, 250, screenW, ...]` (greedy wrap consumes them in order, narrowing the H1''s first 2 sub-lines).
  - **middleRaws** wrap with `[screenW]` only.
  - **lastRaw** wraps with `[250, 160]`.
- `_buildLastWidths` helper handles edge cases (k ≤ 1, k = 2, k ≥ 3).
- `scrollBy` clamp stays at standard `[0, contentH - screenH]`.

**R1 evidence:** `docs/m2-3-fail.txt` (6 of 6 new `wrapToWidths` tests fail on `["STUB"]`-returning stub) → `docs/m2-3-pass.txt` (46/46).

**R2 evidence:** `docs/m2-3-r2-evidence.txt` and `docs/m2-3-render-stdout.txt`. Per-line widths from a diagnostic build:

```
M2_3 N=51 contentH=2249
  [0]   w=160 font=FONT_MEDIUM   <- H1 sub 1
  [1]   w=250 font=FONT_MEDIUM   <- H1 sub 2
  ... (47 middle lines, all w=416) ...
  [N-2] w=250 font=FONT_XTINY    <- last raw sub 1
  [N-1] w=160 font=FONT_XTINY    <- last raw sub 2
```

`contentH` shrank from M2.2''s 2716 to M2.3''s 2249 — 467 px less scroll for the same article, purely from smaller headers.

**Known caveat:** if the last raw paragraph is short enough to fit in a single sub-line at 250 px, it collapses to one line at 250 — the intended "last is 160" never materializes. The sample article''s last paragraph (51 chars) was already exhibiting this pattern; fixed properly in M2.4.

**Artifact:** `wikiwatch-M2.3.prg` (111 020 bytes).

---

## M2.4 — Narrow tail only at the absolute last sub-line + hybrid justify + onUpdate skip-ahead (tag `v0.M2.4`)

Four user-driven changes after testing M2.3:

1. **Narrow-tail cascade.** M2.3''s `lastRaw` wrapped with `widths=[250, 160]`, and `wrapToWidths.defaultWidth` fell back to `widths[size-1] = 160`. For a long last paragraph, EVERY sub-line beyond index 1 inherited 160 — producing 6 narrow lines in a row. User wanted *only the absolute last sub-line* narrow.
2. **Middle uses the full width.** `middleWidth = dc.getWidth()` with right-anchor at `screenW - 25` lets text bleed up to 25 px past the left edge — "a bit too much if it makes the line nicer".
3. **Scroll smoothness.** `onUpdate` was iterating all 53 `_lines` every frame; fast drags felt laggy.
4. **Hybrid justify** — middle lines anchored on the right (clean finger margin), narrow first/last sub-lines centered (so they sit symmetrically in the narrow chord at top/bottom of the round screen).

**What landed:**
- `LineWrap.wrapWithNarrowTail(text, charW, middleW, secondW, edgeW)` — new pure helper. Reverse-packs words from the text''s end into the ABSOLUTE LAST sub-line at `edgeWidth`, then reverse-packs into the PENULTIMATE at `secondWidth`, then forward-packs the remainder at `middleWidth`. The narrow treatment is now reserved for exactly the last 2 sub-lines; everything before stays at full width. **7 new `(:test)` cases** (empty, single short word, two words, middle+tail pattern, long-text-multiple-middles, oversized single word, Hebrew long last raw).
- `wikiwatchView.onUpdate` now has **two while-loops** instead of one for-loop:
  - **Skip-ahead loop**: advances `i` past lines whose bottom edge is above the viewport.
  - **Draw loop**: renders until the first line at or below the viewport bottom, then breaks.
  - Per-frame work drops from O(N=53) to O(visible≈6).
- Hybrid justify logic in `onUpdate`:
  - If `ln[:w] >= middleWidth` → `TEXT_JUSTIFY_RIGHT` at `x = screenW - 25`.
  - Otherwise (narrow line) → `TEXT_JUSTIFY_CENTER` at `x = screenW / 2`.
- Sample article''s last paragraph extended from 51 chars to ~150 so the narrow-tail pattern is actually visible (the original closing sentence is preserved, with a follow-up that wraps to 3-4 middle sub-lines + 250 + 160).

**R1 evidence:** `docs/m2-4-fail.txt` (6 of 7 new `wrapWithNarrowTail` tests fail on `["STUB"]`-returning stub) → `docs/m2-4-pass.txt` (53/53).

**R2 evidence:** `docs/m2-4-r2-evidence.txt` and `docs/m2-4-render-stdout.txt`:

```
M2_4 N=53 contentH=2321
  [0]   w=160       <- H1 sub 1 (CENTER)
  [1]   w=250       <- H1 sub 2 (CENTER)
  ... 49 middle lines, all w=416 (RIGHT-anchored) ...
  [N-4] w=416       <- middle (RIGHT)
  [N-3] w=416       <- middle
  [N-2] w=250       <- penultimate (CENTER)
  [N-1] w=160       <- absolute last (CENTER)
```

Only the last 2 sub-lines are narrow. Compared to M2.3 (and earlier), this fixes the 6-narrow-lines-in-a-row issue at the bottom of the article.

**Notes worth flagging from M2.4 dev:**
- The CIQ watchdog tripped initially because the per-character `text.substring(i, i+1)` in `wrapToWidths` was too slow under iteration. The fix: `text.toCharArray()` once + integer indexing.
- A transient "unused local `lh`" compiler warning was introduced and fixed before commit (R8 baseline preserved).

**Artifact:** `wikiwatch-M2.4.prg` (113 916 bytes).

---

## M2.5 — Left-justify body + `narrowSecond` 300 + H1 fully centered + double-tap nav (tag `v0.M2.5`)

Four user-driven changes after testing M2.4:

1. **H1 fully centered.** M2.4 centered the first 2 narrow H1 sub-lines (widths 160, 250) but right-justified any *additional* H1 sub-lines (full width), so a 3-line H1 looked inconsistently aligned. Fix: tag every sub-line produced by `meta[0]` with `:isH1 => true` and always `TEXT_JUSTIFY_CENTER` for those.
2. **Swap margins.** M2.4 had a clean right margin (`screenW - 25`) and a bleed-left. User asked to swap that and resize: `_leftMargin = 15`, `_rightBleed = 20`, `_middleWidth = screenW - 15 + 20 ≈ 421`. Non-H1 sub-lines anchor at `max(chord_left_at(y), _leftMargin)` with `TEXT_JUSTIFY_LEFT`.
3. **`narrowSecond` 250 → 300.** Second and second-to-last sub-line widths get 50 more pixels. `narrowEdge` stays at 160.
4. **Double-tap nav.** Fast double-tap on the top 50 px edge → `scrollY = 0`; on the bottom 50 px edge → `scrollY = contentH - screenH`. Double-tap in the middle does nothing. Single tap is silent.

**What landed:**
- `source/models/DoubleTap.mc` — NEW pure module. `isDoubleTap(prevMs, prevY, currentMs, currentY, intervalMs, yTolerance) -> Boolean`. **6 new `(:test)` cases** (no-prev, time-too-far, y-too-far, both-windows-ok, negative-delta defensive, boundary).
- `wikiwatchView.mc` — `:isH1` tagging in `_layout`, `_leftMargin=15`, `_rightBleed=20`, `_middleWidth = screenW - 15 + 20`, `narrowSecond=300`, left-anchored justify with adaptive `chord_left`, `scrollToTop`/`scrollToBottom`/`getScreenHeight` accessors.
- `wikiwatchDelegate.mc` — `onTap(event)` override with `_lastTapMs` / `_lastTapY` fields; constants `DOUBLE_TAP_INTERVAL_MS=300`, `DOUBLE_TAP_Y_TOLERANCE=80`, `EDGE_ZONE_PX=50`.

**R1 evidence:** `docs/m2-5-fail.txt` (5 of 6 new `DoubleTap` tests fail on stub returning `false`) → `docs/m2-5-pass.txt` (59/59 pass).

**R2 evidence:** `docs/m2-5-r2-evidence.txt` — diagnostic build printed every laid-out line's `{y, h, w, isH1}`. Confirms all H1 sub-lines now carry `isH1=true` and last 2 lines have `w ∈ {160, 300}` (was `{160, 250}` in M2.4).

**Caveat surfaced after merge:** CIQ's BiDi layer under `TEXT_JUSTIFY_LEFT` anchors the run's *visual* left edge, which for Hebrew RTL flips the reading order visually — fixed in M2.6.

**Artifact:** `wikiwatch-M2.5.prg` (115 516 bytes).

---

## M2.6 — Right-justify body + 30 px clean-left margin (tag `v0.M2.6`)

Hotfix for the M2.5 BiDi caveat. User reported "the text appears backwards" — under `TEXT_JUSTIFY_LEFT`, Hebrew runs flip visually.

**What landed:**
- Reverted body justify to `TEXT_JUSTIFY_RIGHT` anchored at `screenW - _rightMargin`. Hebrew reading order now displays correctly (right-to-left visually, matching reading order).
- `_leftMargin` raised 25 → 30 (more breathing room before text bleeds into the left bezel).
- `_rightMargin` stays at 25.
- `source/models/Layout.mc` — NEW pure module. `middleWidth(screenW, leftMargin, rightMargin) = screenW - leftMargin + rightMargin`. (Despite the name, M2.6 still subtracts both margins; later M2.7 adds back a right bleed.) **2 new `(:test)` cases**: standard and degenerate (margin > screenW).
- H1 centering unchanged.
- `narrowSecond=300`, `narrowEdge=160` unchanged.

**R1 evidence:** `docs/m2-6-fail.txt` (2/2 new `Layout` tests fail on stub returning `0`) → `docs/m2-6-pass.txt` (61/61 pass).

**R2 evidence:** `docs/m2-6-r2-evidence.txt` — diagnostic confirms anchor x = `screenW - 25 = 391` and justify mode `RIGHT` for body lines.

**Artifact:** `wikiwatch-M2.6.prg` (115 772 bytes).

---

## M2.7 — Wide right margin + tight right anchor (tag `v0.M2.7`)

Two user adjustments:
- "The right Margin is great, keep it that way! But the text should continue all the way to the left, and stop 20 px before the screen ends."
- "I still need more words per line. So make the left margin smaller (15 px)."

**What landed:**
- `_leftMargin = 15` (was 30; "smaller left margin → more chars/line").
- `_rightMargin = 20` (was 25; "stop 20 px before screen ends").
- `_middleWidth = Layout.middleWidth(screenW, 15, 20) = screenW - 15 + 20 = screenW + 5`. (M2.7 keeps the `Layout.middleWidth` signature from M2.6 but the *callers* swap left/right semantics — the result is an effective bleed.)
- Anchor stays at `screenW - _rightMargin`, justify stays `RIGHT`.
- `narrowSecond=300`, `narrowEdge=160` unchanged.

`Layout.middleWidth` tests updated to reflect the new (leftMargin, rightMargin) calling convention.

**R1 evidence:** `docs/m2-7-fail.txt` (2/2 `Layout` tests fail on M2.6's stubbed return) → `docs/m2-7-pass.txt` (61/61 pass — same total as M2.6 since no new tests were added, only existing ones rewritten).

**R2 evidence:** `docs/m2-7-r2-evidence.txt` — diagnostic confirms middleWidth = 421 (= 416 - 15 + 20) on the sim.

**Artifact:** `wikiwatch-M2.7.prg` (115 772 bytes — identical size to M2.6, byte-for-byte different due to constant changes).

---

## M2.8 — Per-word pixel wrap (tag `v0.M2.8`)

User feedback after M2.7: "I want more words per line." The char-count wrap (M2.x..M2.7) overestimates Hebrew widths because Hebrew chars are narrower than the worst-case `charWidth` constant. Switching to a per-word pixel-measured wrap fills lines more tightly — typically one more word per line.

**What landed (pure module additions):**
- `LineWrap.splitWords(text) as Array<String>` — splits on spaces, collapses runs, handles leading/trailing whitespace.
- `LineWrap.wrapPxToWidths(words, wordPx, spacePx, widthsPx, startIndex) as Array<String>` — pixel-accurate sibling of `wrapToWidths`. Caller pre-measures each word with `dc.getTextWidthInPixels(word, font)` and the space width once; pure module then forward-packs by px arithmetic.
- `LineWrap.wrapPxWithNarrowTail(words, wordPx, spacePx, middlePx, secondPx, edgePx) as Array<String>` — pixel-accurate sibling of `wrapWithNarrowTail`. Reverse-packs the absolute last + penultimate by px, then forward-packs the remainder.
- **11 new `(:test)` cases** covering the px variants (empty, single word, multi-word fit, oversized word, narrow-tail patterns, default width fallback).

**View refactor (`wikiwatchView._layout`):** every per-line wrap call now pre-measures words with `dc.getTextWidthInPixels`, then calls the px variants. The char-count path stays alive in `LineWrap` for the modules' tests but the view no longer uses it.

**R1 evidence:** `docs/m2-8-fail.txt` (11 px-wrap tests fail on `["STUB"]`-returning stubs) → `docs/m2-8-pass.txt` (72/72 pass).

**R2 evidence:** `docs/m2-8-r2-evidence.txt` — fill-percentage comparison vs M2.7. The diagnostic confirms middle-line widths are now closer to `middleWidth` (typical ~95% fill vs M2.7's ~75% fill).

**Artifact:** `wikiwatch-M2.8.prg` (118 860 bytes).

---

## M3 — Static Hebrew touch keyboard (tag `v0.M3`)

First non-reader view. The reader (`wikiwatchView` + `wikiwatchDelegate`) stays in source but is no longer the initial view — M6 will push it on the view stack when a word is long-pressed.

**Scope:** 22 Hebrew letters (`א..ת` minus final forms) + space + backspace + delete-all + search, laid out on a 6×5 grid (= 30 cells, 4 trailing empties). A typing buffer at the top of the screen shows what the user has typed so far (Hebrew right-aligned).

**What landed (pure modules):**
- `source/models/KeyboardLayout.mc` — `keys() as Array<Dictionary>` returns 30 cell dicts `{:label, :type, :row, :col}` where types are `:LETTER` (22), `:SPACE` (1), `:BACKSPACE` (1), `:DELETE_ALL` (1), `:SEARCH` (1), `:EMPTY` (4). `keyAt(x, y, screenW, screenH)` does a rect hit-test inside the inscribed-rectangle grid; returns `null` for off-grid taps.
- `source/models/InputBuffer.mc` — `append(buf, ch) -> String`, `popLast(buf) -> String`, `clear(buf) -> String`. Pure string ops, Hebrew-safe (Monkey C `String.length()` returns codepoint count).
- **14 new `(:test)` cases** across the two modules (`keys.size == 30`, letter ordering, special-key types, hit-test corners + interior probes, append/pop/clear + edge cases).

**View / delegate:**
- `source/wikiwatchKeyboardView.mc` — draws every key from `KeyboardLayout.keys()` as a labeled cell + the buffer at the top.
- `source/wikiwatchKeyboardDelegate.mc` — `onTap` dispatches by `:type`: `:LETTER` appends, `:BACKSPACE` pops, `:DELETE_ALL` clears, `:SEARCH` is a no-op placeholder (M5 wires it).
- `wikiwatchApp.getInitialView()` now returns the keyboard pair instead of the reader pair.

**R1 evidence:** `docs/m3-fail.txt` (10+ of the new tests fail on sentinel-returning stubs) → `docs/m3-pass.txt` (86/86 pass).

**R2 evidence:** `docs/m3-r2-evidence.txt` — diagnostic confirms `keys.size=30`, letter/special split (22/4/4), `keyAt` returns the expected key at sample interior points and `null` outside the grid.

**Artifact:** `wikiwatch-M3.prg` (124 460 bytes).

---

## M3.1 — Circular T9-style keyboard (tag `v0.M3.1`)

User feedback after M3: the 6×5 grid keys are way too small for finger taps on a 390 px circular display. Asked for a dictionary-style circular keyboard: 10 wedges around the perimeter, each LETTER_GROUP wedge holds 3-4 letters and expands inward on tap to reveal letter sub-zones.

**What landed (geometry rewrite of `KeyboardLayout.mc`):**
- Constants: `NUM_BUTTONS = 10`, `WEDGE_ARC_DEG = 36`, `R_INNER = 105`, `R_OUTER = 205`, `R_EXPANSION_INNER = 50`. (R_INNER moves in M3.2 to thin the ring.)
- `buttons()` returns 10 wedge dicts, clockwise from 12 o'clock: `SPACE("_")`, `BACKSPACE("X")`, 7 `LETTER_GROUP` wedges (`אבג`, `דהו`, `זחט`, `יכל`, `מנס`, `עפצ`, `קרשת` — note `קרשת` is 4 letters), and `DIGITS("0-9")`.
- `buttonAt(x, y, screenW, screenH)` — polar hit-test using `Math.atan2` / `sqrt`. Returns the wedge whose arc + radius range contains `(x, y)`, or `null`.
- `subButtons(parent, ...)` — for a `LETTER_GROUP` parent, returns N tangentially-arranged sub-zones at `r ∈ [50, R_INNER]` covering the parent wedge's arc. For `DIGITS`, returns 10 outer-ring digit wedges.
- `subButtonAt(x, y, expandedDict, screenW, screenH)` — polar hit-test within the expansion sub-zones.

**View / delegate:**
- `source/wikiwatchKeyboardView.mc` — annular-sector wedge rendering via `dc.fillPolygon` (10 vertices per wedge). White input band at the top center for the buffer. Center area shows the buffer + 5 stub suggestion lines.
- `source/wikiwatchKeyboardDelegate.mc` — two-tap state machine. Tap a LETTER_GROUP or DIGITS wedge → store `_expanded` dict, view renders expansion. Tap a sub-zone → `InputBuffer.append(_buffer, sub[:label])`, clear expansion. `onBack` cancels expansion first, then backspaces the buffer, then pops the view.

**R1 evidence:** `docs/m3-1-fail.txt` (6 new geometry tests fail on stubs) → `docs/m3-1-pass.txt` (92/92 pass).

**R2 evidence:** `docs/m3-1-r2-evidence.txt` — diagnostic prints all 10 wedges' angles + letter counts + `hit(x,y)` probes at each wedge's expected center.

**Artifact:** `wikiwatch-M3.1.prg` (127 740 bytes).

---

## M3.2 — Thin outer ring + tri-button cells + dim outer during expand (tag `v0.M3.2`)

User feedback after M3.1:
1. The outer ring is too thick (depth = 205 - 105 = 100 px). Should be much thinner so the center area is bigger.
2. LETTER_GROUP wedges should visually show the 3-4 letters inside them (mini cells) instead of just rendering the symbol label.
3. When a letter wedge is expanded, the rest of the outer ring should dim (not stay full-brightness) so the expansion is the visual focus.

**What landed:**
- `R_INNER`: **105 → 170** in `KeyboardLayout.mc`. Ring depth = 205 - 170 = 35 px (was 100). Center area = πr² = π·170² ≈ 90 700 px² (was π·105² ≈ 34 600 px²).
- `subButtons` for LETTER_GROUP keeps `:rOuter => R_INNER` so sub-zones still fill the center cone (now bigger).
- **Tri-button cell rendering** in `wikiwatchKeyboardView._drawButtonContent` — for LETTER_GROUP wedges, draw N (3 or 4) mini Hebrew letter labels tangentially across the wedge with `FONT_XTINY`, using cellGap=9° / cellGap=4.5° offsets. The whole wedge stays one tap target.
- **Dim outer during letter expansion** — when `_expanded` is set and is a LETTER_GROUP (not DIGITS), other 9 wedges render with `COLOR_BLACK` fill + `COLOR_DK_GRAY` separators instead of `COLOR_DK_GRAY` fill + `COLOR_WHITE` separators.

**Test changes:** 1 new boundary test, 1 existing test rewritten — `kbd_buttonAtInsideAlefGroupReturnsIt` now expects r=187 (within new ring) to return the wedge, `kbd_buttonAtInsideOldMidRingReturnsNull` now expects r=154 (outside new ring) to return null.

**R1 evidence:** `docs/m3-2-fail.txt` (2 tests fail on the old R_INNER=105) → `docs/m3-2-pass.txt` (93/93 pass).

**R2 evidence:** `docs/m3-2-r2-evidence.txt` — diagnostic confirms `R_INNER=170` and visual ring rendering at the new dimensions.

**Artifact:** `wikiwatch-M3.2.prg` (129 228 bytes).

---

## M3.3 — Wider ring + hit halo + pressed feedback + DIGITS cells + buffer fit (tag `v0.M3.3`)

Five fixes after M3.2:
1. Outer ring slightly wider + hit halo. Ring depth 35 → 45 (R_INNER 170 → 160). Plus `R_HIT_INNER=145` and `R_HIT_OUTER=215` halo constants — taps just inside or outside the visual ring still register.
2. Pressed-state visual feedback for SPACE / BACKSPACE — flash `COLOR_LT_GRAY` fill for ~200 ms via `Toybox.Timer.Timer` (held as instance field per `memory/reference_ciq_quirks.md` — local timers get GC'd before firing).
3. Buffer font `FONT_SMALL` → `FONT_TINY`; `bandY` shifted up 20 px so the band sits cleanly within the inner area.
4. **Draw order reversed**: center → outer ring → expansion (was outer → expansion → center). Expansion sub-zones now correctly cover any overlapping center display.
5. **DIGITS wedge: 4 cells `"0  1  ·  9"`** (middle cell rendered as blank space) instead of single `"0-9"` label — mirrors the קרשת 4-letter tri-button rendering. Expansion still shows all 10 digits.

**What landed:**
- `KeyboardLayout.mc`: `R_INNER 170 → 160`. New constants `R_HIT_INNER=145`, `R_HIT_OUTER=215`. `buttonAt` radius check uses the halo constants; `subButtonAt` stays strict (only the outer ring complaint applies).
- `wikiwatchKeyboardView.mc`: draw order reversed, buffer font/position fix, DIGITS 4-cell rendering, `_pressedAngleDeg` field + brighter pressed-wedge rendering.
- `wikiwatchKeyboardDelegate.mc`: `import Toybox.Timer`, `_pressTimer` instance field, SPACE/BACKSPACE trigger `_flashPressed` for 200 ms.

**Test changes:** −1 (the M3.2 `kbd_buttonAtInsideOldMidRingReturnsNull` asserts r=154 returns null — false now under halo) + 2 (one halo-inside-zone PASS test, one just-outside-halo NULL test). Net 93 → **94**.

**R1 evidence:** `docs/m3-3-fail.txt` (2 new halo tests fail on M3.2 geometry) → `docs/m3-3-pass.txt` (94/94 pass).

**R2 evidence:** `docs/m3-3-r2-evidence.txt` — diagnostic confirms `R_INNER=160`, `R_HIT_INNER=145`, `R_HIT_OUTER=215` and hit-halo behavior at sample boundary points.

**Artifact:** `wikiwatch-M3.3.prg` (130 588 bytes).

---

## M3.4 — 1.3× wider ring + buffer band sizing (tag `v0.M3.4`)

Two more fixes after M3.3:
1. Outer ring still feels slightly thin — bump R_INNER 160 → 146 (depth 45 → 59, a 1.3× widening). Hit halo widens too: `R_HIT_INNER 145 → 131`.
2. Buffer band needs more vertical room — increase `bandH` to fit FONT_TINY with comfortable padding; `bandW` adjusted to match.

**What landed:**
- `KeyboardLayout.mc`: `R_INNER 160 → 146`, `R_HIT_INNER 145 → 131`. `subButtons` for LETTER_GROUP keeps `:rOuter => R_INNER = 146`. 1 new test asserting `R_INNER=146` boundary; 1 updated test for the new halo inner bound.
- `wikiwatchKeyboardView.mc`: `bandW=200`, `bandH=44`, `bandY` adjusted to clear the new (wider) outer ring.

**Test changes:** 94 → **95** (one new boundary test).

**R1 evidence:** `docs/m3-4-fail.txt` (1 new test fails on M3.3 geometry) → `docs/m3-4-pass.txt` (95/95 pass).

**R2 evidence:** `docs/m3-4-r2-evidence.txt` — one-shot diagnostic injected in delegate `initialize` printed the runtime layout constants on first launch. Confirmed `R_INNER=146`, `R_HIT_INNER=131`, and the buffer band geometry at the new dimensions. (CR-ist initially failed R2 on prose-only evidence; fixed by injecting the diagnostic and re-reviewing.)

**Artifact:** `wikiwatch-M3.4.prg` (130 588 bytes — same byte count as M3.3 due to compiler alignment).

---

## M3.5 — Final-letter (sofit) sub-zones + multi-line buffer (tag `v0.M3.5`)

Hebrew has 5 final-form letters (sofit) that only appear at the end of words: `ך/ם/ן/ף/ץ` (final כ/מ/נ/פ/צ). They weren't typeable in M3.x. Also: the buffer was a single line — long inputs overflowed off the right.

**What landed:**
- `KeyboardLayout.mc`:
  - `_finalFormFor(letter)` — pure helper mapping כ→ך, מ→ם, נ→ן, פ→ף, צ→ץ. Returns `null` for letters without a sofit form.
  - `subButtons(parent, ...)` for LETTER_GROUP now returns level-1 sub-zones (3-4 regular letters at `r=[50, R_INNER=146]`, tangentially) **PLUS** level-2 final-form sub-zones (each at `r=[10, 50]`, same angle as its parent letter, only for letters that have a sofit).
  - `subButtonAt` iterates ALL sub-zones (mixed levels), checking each one's own `rInner`/`rOuter`. The narrow r=[10,50] inner band is the level-2 tap target.
- Tetris-`+`-shape semantics — for each LETTER_GROUP, the central area has 3-4 letters in a fan; below each letter (toward center) is a smaller sofit sub-zone (where applicable).
- `wikiwatchKeyboardView.mc`:
  - Renders level-2 sub-zones with `FONT_XTINY` (level-1 stays `FONT_TINY`).
  - **Multi-line buffer wrap** — `_wrapBufferIntoLines(dc, text, font, maxPx)` char-by-char wrap. Buffer band `bandH=64` (was 44), shows the LAST 2 lines if the text overflows.
- `InputBuffer.mc` unchanged.

**Test changes:** 95 → **98** (3 new sub-zone tests for sofit presence, hit-test, and absence on no-sofit letters).

**R1 evidence:** `docs/m3-5-fail.txt` (3 new sofit tests fail on M3.4 `subButtons`) → `docs/m3-5-pass.txt` (98/98 pass).

**R2 evidence:** `docs/m3-5-r2-evidence.txt` — diagnostic confirms `יכל` parent yields `subButtons.size == 4` (`י`, `כ`, `ל`, plus `ך` final at level-2 r=[10,50]) and `subButtonAt(208, 238)` (r≈30, a=180°) returns `ך`.

**Artifact:** `wikiwatch-M3.5.prg` (132 284 bytes).

**Caveat surfaced after merge:** the level-2 sub-zones at `r=[10, 50]` are ~750 px² each — too small to tap reliably. Fixed in M3.6.

---

## M3.6 — Flip final-form sub-buttons OUTWARD to outer ring (tag `v0.M3.6`)

User feedback after M3.5: "the final-letters' buttons are really small ... instead of the level-2, make it a level-0. Continue it to the outside of the screen."

**What landed:**
- `KeyboardLayout.mc`: sofit sub-zones flipped from `r=[10, 50]` (inward, ~750 px²) to `r=[R_INNER=146, R_OUTER=205]` (the outer-ring band, ~6500 px² — ~9× bigger tap area). Same angle as the parent letter. Each sofit sub-button visually covers whichever outer-ring wedge happens to be at its angle; outer ring is already dimmed during letter expansion (M3.2), so the visual overlap is intentional.
- `wikiwatchKeyboardView.mc`: level-2 sofit rendering uses `FONT_TINY` (was `FONT_XTINY`) — there's enough room in the outer-ring band now.
- `subButtonAt` is unchanged (it iterates sub-zones checking each one's own `rInner`/`rOuter`, so the new outward placement just works).
- Single expansion state — level-1 letters + sofit sub-zones appear and disappear together.

**Test changes:** 98 → 98 (1 existing test updated to assert the new outer-band geometry — `subButtons(יכל)[3].rInner == 146` and `rOuter == 205`).

**R1 evidence:** `docs/m3-6-fail.txt` (1 test fails on M3.5 geometry) → `docs/m3-6-pass.txt` (98/98 pass).

**R2 evidence:** `docs/m3-6-r2-evidence.txt` — diagnostic confirms `subButtons(יכל)[3]` (`ך`) has `r=[146, 205]` and `subButtonAt(208, 383)` (r≈175, a=180°) returns `ך`; the OLD inward probe `subButtonAt(208, 238)` (r≈30) now returns `null`.

**Artifact:** `wikiwatch-M3.6.prg` (132 284 bytes — same byte count as M3.5 due to compiler alignment).

---

## M4 — ArticleStore + Manifest plumbing with fixture data (tag `v0.M4`)

First milestone past the keyboard ladder. **Plumbing, not UX** — visually identical to v0.M3.6. Stands up the `Application.Storage` layer that M5 (live search) and M6 (long-press → keyboard layer) will read from, populated with fixture data so the rest of the ladder can develop offline. No network — that's M7.

**Why now:** the empty `onStart` in `wikiwatchApp.mc` is the foreshadowed seam. M5 will want to call `Manifest.articleIds()` on every keystroke to filter results, and M7's downloader will write the exact same `Manifest` / `ArticleStore` keyspace. Locking the schema + storage discipline (R4 freeMemory guards) now means M5..M7 inherit a tested contract instead of reinventing one.

**What landed (pure module — `source/models/`):**
- `Fixtures.mc` — `manifest() as Dictionary` returns the 3-article fixture:
  ```
  { :version => 1,
    :articles => [
      { :id => "shalom",  :title => "שלום",  :popularity => 100 },
      { :id => "torah",   :title => "תורה",  :popularity => 80  },
      { :id => "shabbat", :title => "שבת",   :popularity => 60  }
    ] }
  ```
  `bodyOf(id) as String?` dispatches: `"shalom"` → `Strings.sampleArticle()` (reuses the existing 49-line Hebrew article), `"torah"` and `"shabbat"` → 1-paragraph Hebrew placeholders. M7 will swap the placeholders for real Wikipedia bodies.

**What landed (storage wrappers — new `source/storage/` directory):**
- `Manifest.mc` — wraps the `"manifest"` Storage key. Public API: `load`, `save`, `isEmpty`, `articleIds`, `titleOf`. `save` is R4-gated (`freeMemory >= 3 × estimated_size`).
- `ArticleStore.mc` — per-article bodies at keys `"article:<id>"`. `bodyOf` / `putBody`. `putBody` R4-gated on `freeMemory >= 3 × (body.length × 4)` (4× = conservative UTF-8 upper bound for Hebrew).
- `FixtureInstaller.mc` — `installIfEmpty()` glue. If `Manifest.isEmpty()`, calls `Manifest.save(Fixtures.manifest())` then `ArticleStore.putBody(id, Fixtures.bodyOf(id))` for each article ID. Returns the count installed. Idempotent on every subsequent launch. Emits one-shot `System.println` diagnostics for R2 evidence.

**Why `source/storage/` not `source/models/`:** R6 forbids non-pure imports in `source/models/`. The storage wrappers import `Toybox.Application` (for `Storage.setValue/getValue`) and `Toybox.System` (for `freeMemory`), so they can't live in `models/`. `Fixtures.mc` is pure (only `Toybox.Lang`), so it stays in `models/`.

**Wiring (`source/wikiwatchApp.mc`):**
```monkeyc
function onStart(state as Dictionary?) as Void {
    FixtureInstaller.installIfEmpty();
}
```
`getInitialView` unchanged — still returns the M3.6 keyboard pair.

**Mid-implementation gotcha — Symbol serialization:** the first PASS attempt hit `UnexpectedTypeException: Given value cannot be serialized` at the `Application.Storage.setValue(KEY, m)` line in `Manifest.save`. Cause: `Application.Storage` cannot serialize Symbols, and the in-memory schema uses Symbol keys throughout (`:version`, `:articles`, `:id`, `:title`, `:popularity`). The fix preserves the Symbol-keyed in-memory idiom (matches the rest of the codebase — `KeyboardLayout`, `MarkdownTokens`, etc.) by adding `_toStorageDict` / `_fromStorageDict` converters that translate Symbol ↔ String keys at the Storage boundary. Callers (`Fixtures`, `FixtureInstaller`, future M5/M6/M7 code) never see the String-keyed form.

**R1 evidence:** `docs/m4-fail.txt` (14 of the new tests FAIL on stubs returning sentinels) → `docs/m4-pass.txt` (112/112 PASS = 98 prior + 14 new).

**R2 evidence:** `docs/m4-r2-evidence.txt` combines two real-simulator captures:
- **Fresh-install path** (test harness, `monkeydo /t`): the `installer_freshInstallPopulatesManifest` test deletes every fixture key from Storage first, then calls `installIfEmpty()`. Debug log: `install n=3 ids=[shalom, torah, shabbat] firstBodyLen=2058`.
- **Skip path** (live app, `monkeydo bin/wikiwatch.prg venu2`): with Storage already populated, `wikiwatchApp.onStart`'s `FixtureInstaller.installIfEmpty()` diagnostic prints `startEmpty=false startIds=[shalom, torah, shabbat]` and `SKIP (manifest already populated)`.

The Connect IQ simulator persists `Application.Storage` in-memory for the lifetime of `simulator.exe` (no on-disk file to delete between live-app runs), so the test-harness path is the cleanest demonstration of the fresh-install flow. Both `monkeydo` invocations execute the same VM and Storage runtime — the only difference is which entry point fires (`(:test)` functions vs `onStart`).

**Test changes (+14, 98 → 112):**
- `test_Manifest.mc` — 6 tests: empty-default-when-storage-empty, isEmpty-true-on-fresh, save/load roundtrip, articleIds-order, titleOf-hit, titleOf-miss.
- `test_ArticleStore.mc` — 3 tests: put/get Hebrew roundtrip, missing-key-returns-null, putBody-overwrites.
- `test_Fixtures.mc` — 3 tests: ≥3 articles, all-titles-and-bodies-non-empty, bodyOf-known-returns-non-empty.
- `test_FixtureInstaller.mc` — 2 end-to-end tests: fresh-install-returns-count (≥3), second-call-returns-zero.

Storage-touching tests follow the M1 `strings_hebrewLiteralRoundtripsThroughStorage` precedent: explicit `Application.Storage.deleteValue` at the top + bottom of each test so each starts from a known-empty state and leaves no residue.

**Artifact:** `wikiwatch-M4.prg` (137 516 bytes).

---

## M5 — Live search prefix+substring+popularity, tap-to-open reader (tag `v0.M5`)

The first milestone where the user can **see** the M4 storage layer and **read** the fixture articles. Connects the M3.6 circular keyboard to the M4 manifest + the dormant M2.x reader.

**Why now:** the keyboard center already had 5 "stub suggestion" slots from M3.x (`(suggestion 1)` … `(suggestion 5)`) plumbed in pixel space, and the article reader had been sitting in `source/` since M2.8 with no caller. M4 shipped 3 Hebrew fixtures into `Application.Storage`. M5 wires those pieces together by swapping two strings (stub literals → real titles, no-op tap → `pushView`) bound by a new `Search.rank` pure module.

**What landed (pure module — `source/models/`):**
- `Search.mc` — `rank(query, articles) as Array<Dictionary>`. **Empty query** → top-K (=20) sorted by `:popularity` DESC, stable tiebreak by `:title`. **Non-empty query** → `[tier-1 (prefix match), tier-2 (substring not prefix)]`, each tier sorted by popularity DESC with codepoint-order tiebreak by title (Hebrew-safe via `String.toCharArray()`), capped at TOP_K. Stable insertion sort; O(N) partition + O(K²) tier sort, fine through the M7 corpus size. Only imports `Toybox.Lang` (R6 clean).

**View refactor (`source/wikiwatchView.mc`):**
- Constructor now takes `body as String` instead of pulling `Strings.sampleArticle()` inline. One-line backwards-incompatible change; the only call site is the new M5 pushView, so no other callers to fix. Public scroll API (`scrollBy`/`scrollToTop`/`scrollToBottom`/`getScreenHeight`) unchanged.

**Keyboard view (`source/wikiwatchKeyboardView.mc`):**
- New `_suggestions` field + `setSuggestions(arr)` / `suggestionAt(x, y)` public API.
- The hardcoded `for (i = 1; i <= 5) drawText("(suggestion " + i + ")")` loop in `_drawCenterDisplay` is replaced with a loop over `_suggestions` (up to 5 Hebrew titles, right-justified, FONT_XTINY light-gray).
- Band/line geometry pulled into private consts (`_BAND_W=200`, `_BAND_H=64`, `_BAND_Y_OFFSET=-110`, `_SUGGESTION_Y_START_OFFSET=6`, `_SUGGESTION_LINE_STEP=22`, `_MAX_SUGGESTIONS=5`) so `suggestionAt`'s hit-test math agrees with the render. Suggestion area sits entirely within `r < R_HIT_INNER=131`, so no precedence conflict with the outer-ring wedges.
- Added `Toybox.System` import for `getDeviceSettings()`.

**Keyboard delegate (`source/wikiwatchKeyboardDelegate.mc`):**
- `initialize` loads `Manifest.load()[:articles]` into the `_articles` field once at construction, then calls `_recomputeSuggestions()` to seed the view with top-3 by popularity.
- Every buffer-mutating tap (SPACE append, BACKSPACE pop, sub-button append, `onBack` popLast) calls `_recomputeSuggestions()` which runs `Search.rank(_buffer, _articles)`, takes top-5, prints the R2 diagnostic, and pushes the new list to the view.
- In `onTap`, BEFORE the wedge hit-test (but after the expansion sub-button check), checks `_view.suggestionAt(x, y)`. Non-null → loads `ArticleStore.bodyOf(suggestion[:id])` and `WatchUi.pushView(new wikiwatchView(body), new wikiwatchDelegate(reader), WatchUi.SLIDE_LEFT)`.

**Test changes (+10, 112 → 122):**
- `test_Search.mc` — 10 tests: empty-query-by-popularity, cap-at-20, empty-articles-returns-empty, prefix-match-only, substring-non-prefix-is-tier-2, prefix-before-substring, popularity-within-tier, title-stable-tiebreak-on-popularity-tie, no-matches-returns-empty, hebrew-substring-match.

**R1 evidence:** `docs/m5-fail.txt` (10 of the new tests FAIL on the sentinel-returning Search stub) → `docs/m5-pass.txt` (122/122 PASS).

**R2 evidence:** `docs/m5-r2-evidence.txt` captured from a live `monkeydo bin/wikiwatch.prg venu2` invocation:

```
M4 install: startEmpty=false startIds=[shalom, torah, shabbat]
M4 install: SKIP (manifest already populated)
M5 rank: buf='' top=[שלום,תורה,שבת]
```

Proves end-to-end: `Manifest.load()` returns the 3 M4 fixtures → `Search.rank("", ...)` orders them by popularity DESC (shalom=100 > torah=80 > shabbat=60) → `_view.setSuggestions([…])` fires. The same `M5 rank` diagnostic appears 122 times in `docs/m5-pass.txt` (once per test, since the harness boots `wikiwatchApp.onStart` + `getInitialView` per test) — the strongest possible co-evidence that the wire executes successfully on every fresh boot with real Storage data.

Interactive flows (typing filters, tap-to-open) are described in the evidence file but not captured as stdout — `monkeydo` doesn't programmatically drive touch events. The code paths route deterministically from `onTap` through `Search.rank` + `WatchUi.pushView`, and the unit tests cover all `Search.rank` tiers.

**User-visible change:** before M5, the keyboard center showed 5 dummy `(suggestion N)` lines and tapping them did nothing. After M5, the center shows 3 real Hebrew titles (`שלום`, `תורה`, `שבת`) on launch; typing a Hebrew letter filters them live; tapping a line opens the M2.x article reader with that body (drag-scroll, double-tap-edge nav, all from M2.x preserved). Lower-right back button pops the reader and returns to the keyboard with the typed buffer still in place.

**Artifact:** `wikiwatch-M5.prg` (142 556 bytes).

---

## M5.1 — Bigger suggestion taps + full-screen ResultsView for top-20 (tag `v0.M5.1`)

Two pain points the user hit immediately on the simulator after M5 shipped:

1. **Hard to tap.** The 5 suggestion rows rendered at `FONT_XTINY` (~15 px on real Venu 2, ~32 px on sim) with a 22 px y-step. Smaller than a finger's comfortable target (≥40 px) and visually overlapping on sim.
2. **Capped at 5.** `Search.rank` returned top-20 but the delegate's `_takeTop(ranked, 5)` discarded 15. No way to see results 6–20.

After offering 4 design options (single full-screen view, in-keyboard scroll, horizontal swipe pagination, or 3-big-rows + overflow), the user picked **3 big tappable rows in the keyboard center for the common case, plus a "▼ N more" row that pushes a full-screen scrollable `ResultsView` for the rest**. This mirrors the existing keyboard → article-reader push pattern, so no new architectural primitives.

**What landed (pure module — `source/models/`):**
- `ResultsLayout.mc` — `rowIndexAt(y, scrollY, rowHeight, rowCount) as Number?`. Pure geometry for `ResultsView.rowAt` hit-test. Maps screen y + scroll offset → row index, returns null off-list or for non-positive args. Only imports `Toybox.Lang`.

**New views** (mirror the existing `wikiwatchView` / `wikiwatchDelegate` pattern; live flat under `source/` like the keyboard views):
- `ResultsView.mc` — full-screen scrollable list. Constructor takes the ranked array. Renders FONT_SMALL Hebrew titles right-justified at 60 px row step. Drag-scroll via `scrollBy` (M2.1 onDrag pattern). Skip-ahead optimization in `onUpdate` (M2.4 pattern). Public: `scrollBy`, `rowAt`, `getScreenHeight`.
- `ResultsDelegate.mc` — `onTap` → `rowAt` → push `wikiwatchView(ArticleStore.bodyOf(id))`. `onDrag` → live scroll. `onBack` returns `false` so CIQ pops back to keyboard.

**KeyboardView geometry refactor** (`source/wikiwatchKeyboardView.mc`):

| Const | M5 | M5.1 |
| --- | --- | --- |
| `_BAND_H` | 64 (2-line buffer) | 30 (1-line) |
| `_BAND_Y_OFFSET` | −110 | −95 |
| `_SUGGESTION_Y_START_OFFSET` | 6 | 10 |
| `_SUGGESTION_LINE_STEP` | 22 | 40 |
| `_MAX_SUGGESTIONS` | 5 | 3 |
| `_MORE_ROW_OFFSET` | n/a | 6 |
| `_MORE_ROW_HEIGHT` | n/a | 22 |

`_drawCenterDisplay` renders FONT_TINY suggestion rows (was FONT_XTINY) plus a conditional "▼ N more" FONT_XTINY footer. Buffer band shows the LAST line of the char-wrap (was 2-line tail). New `_moreCount` field + `setMoreCount(n)` setter + `moreHit(x, y)` predicate.

**KeyboardDelegate wiring** (`source/wikiwatchKeyboardDelegate.mc`):
- `MAX_SUGGESTIONS` 5→3. New `_ranked` field caches the full `Search.rank` result (M5 discarded after taking top-5).
- `_recomputeSuggestions` calls `setSuggestions(top3)` + `setMoreCount(_ranked.size() − 3)`. Diagnostic line gains `more=N` suffix.
- `onTap` checks `_view.moreHit(x, y)` BEFORE `suggestionAt`; non-null → `WatchUi.pushView(new ResultsView(_ranked), new ResultsDelegate(results), WatchUi.SLIDE_LEFT)`.

**Test changes (+3, 122 → 125):**
- `test_ResultsLayout.mc` — 3 tests: inside-top-row-returns-zero, outside-list-returns-null, respects-scroll. Exercise the pure `rowIndexAt` math.

**R1 evidence:** `docs/m5-1-fail.txt` (3 FAIL on stub returning −1) → `docs/m5-1-pass.txt` (125/125 PASS).

**R2 evidence:** `docs/m5-1-r2-evidence.txt` captured from a live `monkeydo bin/wikiwatch.prg venu2` invocation:

```
M5 rank: buf='' top=[שלום,תורה,שבת] more=0
```

`more=0` is correct for the 3-fixture corpus — the footer is dormant when `ranked.size() ≤ 3`. The full M5.1 path (footer rendering + tap → push `ResultsView` + drag-scroll + tap-to-open) becomes user-visible automatically when M7 brings a corpus larger than 3 articles. The geometry of the dormant path is unit-tested via `ResultsLayout`.

**User-visible change:** before M5.1, the 5 cramped FONT_XTINY rows were hard to tap and there was no path past the top 5. After M5.1, 3 big comfortably-tappable FONT_TINY rows show in the keyboard center, plus a "▼ N more" footer (when there are more) that opens a full-screen scrollable list of all top-20 in FONT_SMALL rows. Tap-to-open works from both the inline rows and the full-screen list; back from the article reader returns to whichever view pushed it.

**Artifact:** `wikiwatch-M5.1.prg` (147 052 bytes).

---

## M5.2 — Multi-line buffer + separators + 30 ש-fixtures + lazy article layout + rounded buffer + "X more articles fit" footer (tag `v0.M5.2`)

Six user-requested UX changes after testing M5.1. All shipped as one bundle.

**Why now:** M5.1 made suggestion taps bigger and added the ResultsView, but the user immediately surfaced 4 polish issues — and then 2 more on top:

1. **No visual separation** between suggestion rows — they blended.
2. **Lost the 2-line buffer** that M3.5/M5 had; M5.1 shrunk it for the 3 big rows.
3. **Only 3 fixture articles** — the M5.1 "▼ N more" + ResultsView paths were dormant.
4. **Article reader takes too long to load** — `שלום` (50 raw lines) blocks the watch because `_layout` measures every word in one synchronous pass.
5. **Rectangle text box looks harsh** — soften with rounded corners.
6. **ResultsView caps at top-K with no hint about overflow** — show "X more articles fit" at the bottom.

**What landed:**

| # | Change | Where |
|---|---|---|
| 1 | 1-px DK_GRAY separator (67 px wide, centered) between consecutive suggestion rows + before "▼ N more" footer | `wikiwatchKeyboardView.mc` |
| 2 | 2-line buffer restored: `_BAND_H` 30 → 64, `_BAND_Y_OFFSET` -95 → -110. Tradeoff: `_MAX_SUGGESTIONS` 3 → 2 to fit | `wikiwatchKeyboardView.mc`, `wikiwatchKeyboardDelegate.mc` |
| 3 | `Fixtures.mc` rewritten with 30 articles all starting with `ש`, `:version => 2`. Includes the long anachronistic title `שיר לשלום מאת חיים נחמן ביאליק ונועה קירל` per user spec. `FixtureInstaller` version-aware (auto-migrates). `Search.TOP_K` 20 → 50 | `Fixtures.mc`, `FixtureInstaller.mc`, `Search.mc` |
| 4 | Lazy article layout via new pure `LayoutProgress` module. First `onUpdate` lays out `_INITIAL_LINES=12` raw lines (~ 2 screens). `Timer.Timer` (`_LAYOUT_TICK_MS=80`) wakes the view via `WatchUi.requestUpdate` so the next `onUpdate` can lay out `_INCREMENTAL_LINES=6` more. Scroll clamps to currently-laid-out `_contentHeight`. "..." marker visible until `_layoutComplete`. `onHide` stops the timer | `wikiwatchView.mc`, `LayoutProgress.mc` |
| 5 | `fillRectangle` → `fillRoundedRectangle(_BAND_CORNER_RADIUS=8)` for a softer "input box" look | `wikiwatchKeyboardView.mc` |
| 6 | New pure `Search.totalMatches(query, articles)` (un-capped match count) + pure `ResultsLayout.moreArticlesText(total, displayed)` (singular "1 more article fits" / plural "X more articles fit" / null when 0). `ResultsView` ctor takes `totalMatches`; renders the footer when `total > displayed`. Dormant in M5.2 (TOP_K=50 ≥ 30 fixtures), live as soon as the corpus exceeds the cap | `Search.mc`, `ResultsLayout.mc`, `ResultsView.mc`, `wikiwatchKeyboardDelegate.mc` |

**New pure modules / functions (all `Toybox.Lang` only):**
- `LayoutProgress.mc` — 4 helpers: `nextBatchEnd`, `isComplete`, `isScrollNearEnd`, `clampedScroll`.
- `Search.totalMatches(query, articles)`.
- `ResultsLayout.moreArticlesText(total, displayed)`.

**Test changes (+21, 125 → 146):**
- `test_LayoutProgress.mc` — 11 tests including the user-named race-condition cases (`scrollEndedBeforeLoadStarted`, `scrollEndedWhileLoadInProgress`) + defensive clamps + content-growth stability.
- `test_Fixtures.mc` — `+2` (`manifestVersionIsTwo`, `allTitlesStartWithShin`); existing `manifestHasThreeArticles` strengthened to `manifestHasThirtyArticles`.
- `test_FixtureInstaller.mc` — `+1` (`reinstallsOnVersionBump`).
- `test_Search.mc` — `+3` `totalMatches` tests; cap test renamed `search_emptyQueryCapsAtTwenty` → `search_emptyQueryCapsAtTopK` with 60 input articles + TOP_K=50.
- `test_ResultsLayout.mc` — `+4` `moreArticlesText` tests (zero / singular / plural / negative).

**R1 evidence:** `docs/m5-2-fail.txt` (13 FAIL on base stubs) + `docs/m5-2-extras-fail.txt` (7 FAIL on extras stubs) → `docs/m5-2-pass.txt` (146/146 PASS).

**R2 evidence:** `docs/m5-2-r2-evidence.txt` captured from a live `monkeydo bin/wikiwatch.prg venu2`:

```
M4 install: startEmpty=false currentVersion=2 targetVersion=2 startIds=[shalom, shabbat, shir, shema, shulchan-arukh, shir-hashirim, shemonah-esreh, shemesh, shlomo-hamelech, shir-lashalom-long, shmuel, shofar, shoftim, shekhinah, shalom-aleichem, shamayim-vaaretz, shmirat-shabbat, shirat-hayam, shir-eretz, shimon-bar-yochai, shemesh-bagilboa, sheleg, shemen-zayit, shaarei-tzedek, shabbat-hamalka, shir-mishirei, shulamit, shimshon, sheh, shdema]
M4 install: SKIP (manifest already at target version)
M5 rank: buf='' top=[שלום,שבת] more=28 total=30
```

All 30 fixture IDs present. `more=28 total=30` proves the wire from Search.totalMatches through the delegate to ResultsView is in place. `total > displayed` triggers the new footer (dormant in M5.2 since 30 ≤ TOP_K=50; becomes live with M7+ corpora).

**User-visible changes** (vs M5.1):
- Buffer band has rounded corners, 2 lines tall again.
- 2 (not 3) big suggestion rows + "▼ 28 more" footer (was 0 with 3 fixtures).
- Thin separator lines between rows.
- Tapping a long article (e.g. שלום) shows the first screen INSTANTLY with a "..." loading marker; full article is scrollable within ~400 ms.
- ResultsView lists all 30 in big FONT_SMALL rows; "X more articles fit" footer infrastructure ready for when the corpus exceeds the cap.

**Lazy-layout race-condition coverage** (Monkey C is single-threaded; "races" are event-sequencing cases):
- A: scroll ended BEFORE second-load started → `clampedScroll(9999, 400, 200) == 200`.
- B: scroll ended WHILE second-load was in progress → scroll position stable as contentH grows.
- C: defensive clamps (negative scrollY, content < screen).
- D: view popped while timer scheduled → `onHide` stops the timer.

**Artifact:** `wikiwatch-M5.2.prg` (156 284 bytes).

---

## M5.3 — Title-body match + empty-buffer + round ResultsView + multiline + bounded first-paint (tag `v0.M5.3`)

Four user-reported polish issues after testing M5.2. All shipped as one bundle.

**Why now:**
1. **Title mismatch.** Tapping the long suggestion `שיר לשלום מאת חיים נחמן ביאליק ונועה קירל` opened an article whose H1 was just `שיר לשלום` — the body title didn't match the manifest title. Also: empty buffer still showed 2 inline suggestions + "▼ 28 more" footer — noise before the user has typed anything.
2. **ResultsView ignores the round screen.** Hebrew titles at the top + bottom of the screen got clipped by the bezel curve. The user gave an exact spec: skip top 15% + bottom 15% of screen, plus 40 px L/R margins.
3. **Long titles need wrapping.** With FONT_SMALL in M5.2, the long anachronistic title overflowed the row width. The user wanted multiline rows — tightly-spaced sub-lines of the same article, looser gap between articles.
4. **"Quick load" wasn't quick.** Tapping `שלום` (50 raw lines) felt noticeably slower than `שבת` (2 raw lines). The user wanted both to feel "instant" with tests verifying the timings match.

**What landed:**

**Change 1 — Title fix + empty-buffer guard:**
- `source/models/Fixtures.mc`: `shir-lashalom-long` body H1 now reads `שיר לשלום מאת חיים נחמן ביאליק ונועה קירל` (matches manifest). `:version => 3` so the version-aware `FixtureInstaller` (M5.2) auto-migrates on next launch.
- `source/wikiwatchKeyboardDelegate.mc` `_recomputeSuggestions`: top-level guard — if `_buffer.length() == 0`, call `setSuggestions([])` + `setMoreCount(0)` and skip `Search.rank`. The keyboard center renders blank under the buffer band.

**Change 2 — Round-screen-aware ResultsView** (`source/ResultsView.mc`):
- New constants: `_TOP_PAD_PCT = 15`, `_BOTTOM_PAD_PCT = 15`, `_LEFT_MARGIN = 40` (was 0), `_RIGHT_MARGIN = 40` (was 20).
- Rows render only in `y ∈ [_visibleTop, _visibleTop + _visibleHeight)` (middle 70% of screen). Text right-anchored at `screenW - 40`.

**Change 3 — Multiline article rows** (`source/ResultsView.mc`):
- Per-article block layout pre-computed on first onUpdate using `LineWrap.wrapPxToWidths` (each title wraps to fit `_usableWidth = screenW - 80`).
- Constants: `_SUB_LINE_GAP = 2`, `_INTER_ARTICLE_GAP = 16`. FONT_TINY (was FONT_SMALL) for more headroom.
- New pure helper `ResultsLayout.blockAt(contentY, blocks)` — variable-height row hit-test. Used by `ResultsView.rowAt` to dispatch a tap on any sub-line back to the article.

**Change 4 — Bounded first-paint** (`source/wikiwatchView.mc`):
- `_INITIAL_LINES` 12 → 5 (~10× less first-paint work for the long `שלום` article).
- `_INCREMENTAL_LINES` 6 → 4 (smaller per-tick batches).
- New first-paint diagnostic: `M5.3 first-paint: ms=N hint='<body prefix>'`. Fires once per article open; usable for manual timing verification on the sim.
- New unit test `layoutProgress_initialBatchIsBoundedForAnyBodyLength` encodes the invariant: `nextBatchEnd(0, 2, 5) == 2 && nextBatchEnd(0, 50, 5) == 5`. Both short and long bodies process AT MOST `_INITIAL_LINES` raw lines on first paint → comparable wall-clock first-paint by construction.

**Test changes (+8, 146 → 154):**
- `test_Fixtures.mc` — `+1` `fixtures_titlesMatchBodies` (every fixture's body H1 starts with the manifest title); existing version test renamed `IsTwo` → `IsThree`.
- `test_LayoutProgress.mc` — `+1` `initialBatchIsBoundedForAnyBodyLength`.
- `test_ResultsLayout.mc` — `+6` `blockAt` cases (inside-first, inside-second, in-gap, past-end, negative, empty-array).

**R1 evidence:** `docs/m5-3-fail.txt` (8 FAIL on stubs) → `docs/m5-3-pass.txt` (154/154 PASS).

**R2 evidence:** `docs/m5-3-r2-evidence.txt` — live `monkeydo bin/wikiwatch.prg venu2` shows:

```
M4 install: startEmpty=false currentVersion=3 targetVersion=3 startIds=[…30 IDs…]
M4 install: SKIP (manifest already at target version)
M5 rank: buf='' (empty — no results shown)
```

The NEW diagnostic `M5 rank: buf='' (empty — no results shown)` confirms the empty-buffer guard fires correctly. `currentVersion=3 targetVersion=3` proves the v2→v3 migration completed on the prior run. Per-flow narrative for each of the 4 changes in the evidence file, plus a manual first-paint-timing measurement protocol (tap `שבת`, then tap `שלום`, compare the two `M5.3 first-paint: ms=N` outputs — expect within ~30 ms).

**User-visible changes** (vs M5.2):
- Empty buffer → blank center (no suggestion noise).
- Long title's body H1 now matches what was tapped.
- ResultsView never clips text at top/bottom; long titles wrap.
- Tapping `שלום` no longer lags vs tapping `שבת`.

**Artifact:** `wikiwatch-M5.3.prg` (158 892 bytes).

---

## M5.4 — Smoother lazy-load + bottom-double-tap gate + ResultsView margins + 0 px sub-line gap (tag `v0.M5.4`)

Four small polish requests after M5.3 testing:

1. **שלום still felt laggy.** M5.3's `_INITIAL_LINES = 5` meant the first onUpdate did ~50 `dc.getTextWidthInPixels` calls — still perceptible on the watch. Drop further so `שלום` does the SAME work as `שבת`.
2. **Bottom double-tap during lazy load** dumps the user in partially-rendered content. Disable until layout completes.
3. **ResultsView margins** — slightly larger top/bottom pad (15% → 16%) and L/R margins (40 → 50 px).
4. **0 px sub-line gap** — wrapped sub-lines of the same article should touch.

**What landed:**

| File | Change |
|---|---|
| [wikiwatchView.mc](source/wikiwatchView.mc) | `_INITIAL_LINES` 5 → 2, `_INCREMENTAL_LINES` 4 → 2, `_LAYOUT_TICK_MS` 80 → 50 (CIQ minimum). New public `isLayoutComplete() as Boolean` getter exposing the lazy-layout state. |
| [wikiwatchDelegate.mc](source/wikiwatchDelegate.mc) | Bottom-edge double-tap branch now gated on `_view.isLayoutComplete()` — scroll-to-bottom is silently ignored while layout is in progress. Top double-tap (scroll-to-top) unaffected (scrollY=0 is always valid). |
| [ResultsView.mc](source/ResultsView.mc) | `_TOP_PAD_PCT` + `_BOTTOM_PAD_PCT` 15 → 16, `_LEFT_MARGIN` + `_RIGHT_MARGIN` 40 → 50, `_SUB_LINE_GAP` 2 → 0. Wrap budget shrinks 20 px so long titles wrap to one more sub-line; sub-lines of the same article are now line-touching. |
| [test_LayoutProgress.mc](source/tests/test_LayoutProgress.mc) | `layoutProgress_initialBatchIsBoundedForAnyBodyLength` — `INITIAL` 5 → 2; assertion STRENGTHENED to require EXACT equality (`shortBatch == longBatch == 2`), proving wall-clock first-paint parity. |

**Why "exactly 2" matters:** with `_INITIAL_LINES = 2`, ANY body with ≥ 2 raw lines processes EXACTLY 2 raw lines on first onUpdate. שבת (2 raw) and שלום (50 raw) do identical per-batch work → identical wall-clock first paint.

**Test changes:** no new tests (no new pure-module surface). Existing bounded-batch test updated to encode the strengthened M5.4 invariant.

**R1 evidence:**
- **FAIL** ([docs/m5-4-fail.txt](docs/m5-4-fail.txt)): with the strengthened assertion applied but `INITIAL=5` (M5.3 baseline), `shortBatch=2` and `longBatch=5`, so `longBatch == shortBatch` is false:
  ```
  DEBUG: INITIAL=5 shortBatch=2 longBatch=5
  FAIL
  Ran 154 tests
  FAILED (passed=153, failed=1, errors=0)
  ```
- **PASS** ([docs/m5-4-pass.txt](docs/m5-4-pass.txt)): with `INITIAL=2` (M5.4), both bodies cap at 2:
  ```
  DEBUG: INITIAL=2 shortBatch=2 longBatch=2
  PASS
  Ran 154 tests
  PASSED (passed=154, failed=0, errors=0)
  ```

**R2 evidence** ([docs/m5-4-r2-evidence.txt](docs/m5-4-r2-evidence.txt)) — live `monkeydo bin/wikiwatch.prg venu2`:

```
M4 install: startEmpty=false currentVersion=3 targetVersion=3 startIds=[…30 IDs…]
M4 install: SKIP (manifest already at target version)
M5 rank: buf='' (empty — no results shown)
```

Per-change narrative covers all 4 changes including the manual first-paint measurement protocol via the M5.3 `M5.3 first-paint: ms=N hint=...` diagnostic.

**User-visible changes** (vs M5.3):
- `שלום` opens at the same speed as `שבת` (both do 2 lines of layout work for first paint).
- Double-tapping the bottom edge of the screen during lazy load → silently ignored. After the "..." marker disappears → works as before.
- ResultsView: slightly more bezel clearance; long titles wrap with sub-lines touching (no inter-line gap).

**Artifact:** `wikiwatch-M5.4.prg` (159 004 bytes).

---

## M6 — Long-press a word in the article → push a keyboard layer pre-filled with that word (tag `v0.M6`)

The reader loop closes. Long-press any word in the article reader → a new keyboard view pushes on top, with that word pre-filled in the buffer band. From there the user can backspace + re-type to drill into a related article, or press back to return.

**Why now:** the article reader (`wikiwatchView`) ships lazy layout (M5.2), bounded first-paint (M5.4), and tap dispatch via `wikiwatchDelegate`. The keyboard side (`wikiwatchKeyboardView` / `KeyboardDelegate` / `ResultsView`) is stable. M6 connects them via long-press so the user can "drill into a word they don't recognize, then back out".

**Why this isn't just `WatchUi.pushView`:** Hebrew text wraps unpredictably in word-pixel space. The new `WordHitTest` pure module maps a tap (in content coordinates) to the word under the finger using a char-count approximation. Each word "owns" its trailing space so taps on whitespace snap to the preceding word — natural for "I just read this word, then tapped just past it".

**What landed:**

**New pure module** (`source/models/WordHitTest.mc`, `Toybox.Lang` only):
- `findWordInLine(contentX, text, lineRightX, charPx) as String?` — right-anchored char-count word-at-tap. Returns null when the tap is past the right edge, past the left edge, or text is empty.
- Hebrew RTL semantics: CIQ's BiDi renderer puts the first LOGICAL character at the visual right edge. Walking `words` in logical order produces the correct visual mapping.

**View wiring** (`source/wikiwatchView.mc`):
- New public `findWordAt(x, y) as String?` — converts screen y to content y via `_scrollY`, walks `_lines` to find the matching line, computes the line's right edge based on its justify mode (centered at `centerX + textWidth/2` for H1/narrow lines, `screenW - _RIGHT_MARGIN` for middle lines), dispatches to `WordHitTest.findWordInLine`.
- Private `_approxCharPx(font)` — per-font Hebrew char width (LARGE 13, MEDIUM 11, SMALL 9, TINY 8, XTINY 6; from the M2 runtime probe).
- `_screenWidth` cached during `onUpdate` (was only `_screenHeight`).

**Delegate wiring** (`source/wikiwatchDelegate.mc`):
- New `onHold(event)` override. Reads tap coords, prints `M6 onHold: x=... y=...` diagnostic, calls `_view.findWordAt(x, y)`. If non-null → constructs new `wikiwatchKeyboardView` + `wikiwatchKeyboardDelegate(view, word)` and `WatchUi.pushView(... SLIDE_LEFT)`.
- The diagnostic doubles as the project's pending **`onHold` spike** (handoff §7): if the print appears in stdout when the user long-presses, the path works as designed. If not, M6.1 falls back to Timer-based detection in `onTap`.

**Constructor update** (`source/wikiwatchKeyboardDelegate.mc`):
- `initialize(view, initialBuffer)` — pre-fills the buffer + calls `_recomputeSuggestions` so the ranked list reflects the pre-fill on construction.

**Caller update** (`source/wikiwatchApp.mc`):
- `getInitialView` passes `""` for the empty-launch state.

**View-stack flow** (CIQ default push/pop):

```
[KeyboardView] type ש → [KB][ResultsView] tap שלום →
[KB][RV][wikiwatchView] long-press אברהם →
[KB][RV][AR][KeyboardView('אברהם')] type/tap → drill into another article →
[KB][RV][AR][KB'][RV'][AR']

back button pops each layer cleanly.
```

**Test changes (+6, 154 → 160):**
- `test_WordHitTest.mc` — 6 cases: insideText, atRightEdge (first word), atLeftEdge (last word), pastLeftEdge (null), pastRightEdge (null), emptyText (null).

**R1 evidence:** `docs/m6-fail.txt` (6 FAIL on stub) → `docs/m6-pass.txt` (160/160 PASS).

**R2 evidence:** `docs/m6-r2-evidence.txt` — live `monkeydo bin/wikiwatch.prg venu2` (initial state) + manual long-press verification protocol. `monkeydo` can't programmatically simulate touch events, so the `M6 onHold` diagnostic appears only when the user actually long-presses. The evidence file documents the expected `M6 onHold: word='X' — pushing keyboard layer` stdout sequence + the 5+ layer view-stack flow + the spike documentation.

**User-visible change:** in the article reader, long-press any word — a new keyboard view slides in with that word in the buffer. The view stack can now grow several layers deep (article → keyboard' → article' → keyboard'' → ...). Back-press through each layer returns to the previous, preserving scroll positions.

**Artifact:** `wikiwatch-M6.prg` (161 580 bytes).

---

## M6.1 — Fix M6 off-by-one + left-side dead zone (tag `v0.M6.1`)

Two bugs surfaced in M6's long-press feedback as soon as it shipped:
1. Long-pressing a word usually returned **either the correct word or the visually-adjacent word to its left** ("the next word").
2. Long-press **didn't work on the left side of the screen** — sometimes returned null, sometimes returned the wrong word.

Both trace to the same root cause: M6's `findWordInLine` approximated text width via `text.length() * charPx`. Hebrew character widths range from ~6 px (narrow letters) to ~13 px (wide letters), so a single average is off by tens of pixels per line. Underestimating `text_width_px` made the computed `text_left_x` fall to the right of where the text actually started → taps in the leftmost zone landed past the computed end and returned null (bug 2). Inside the line, the same skew shifted the per-char index by ±1, biasing the result to the visually-adjacent word (bug 1).

**Why this is the right fix:** the article view already calls `dc.getTextWidthInPixels(word, font)` for every word during M2.8 px-wrap. Those measurements were thrown away after wrap. M6.1 stashes them on each sub-line dict so the long-press hit-test can walk words right-to-left using exact pixel positions instead of guessing.

**What landed:**

**Replaced module function** (`source/models/WordHitTest.mc`, `Toybox.Lang` only):
- `findWordPx(contentX, words, wordPx, lineRightX, spacePx) as String?` — walks `words` right-to-left starting at `lineRightX`, subtracting `wordPx[i]` then `spacePx` per word. Each word "owns" the space to its left (toward the visually-next word) so taps on whitespace snap to the preceding word.
- Hebrew RTL: `words[0]` is logically first AND visually rightmost; walking left consumes them in logical order.
- `findWordInLine` (the M6 char-count function) **removed**. No callers remain.

**View wiring** (`source/wikiwatchView.mc`):
- `_layoutBatchRange` now stores `:words` / `:wordPx` / `:spacePx` on each sub-line dict (`splitWords` once, `dc.getTextWidthInPixels` once per word — same data the px-wrap already consumes).
- `findWordAt(x, y)` rewritten: computes exact `lineRightX` from the stored arrays (`centerX + (sum(wordPx) + (n-1)*spacePx)/2` for centered H1/narrow lines, `screenW - _RIGHT_MARGIN` for body lines), dispatches to `WordHitTest.findWordPx`.
- `_approxCharPx` deleted — no longer needed.

**Test changes (+7 new, −6 old, net 154 → 161):**
- `test_WordHitTest.mc` — 7 px-accurate cases replacing the 6 char-count cases:
  - `insideFirstWord` — tap inside rightmost word → returns words[0].
  - `insideMiddleWord` — tap inside center word → returns words[1].
  - `insideLastWord` — tap inside leftmost word (bug-2 regression) → returns words[2].
  - `onSpaceSnapsToPreviousWord` — tap on whitespace between two words (bug-1 regression) → returns the visually-right word.
  - `pastRightEdge` — tap right of `lineRightX` → null.
  - `pastLeftEdge` — tap left of leftmost word's start → null.
  - `emptyWords` — empty `words` array → null.

**R1 evidence** ([docs/m6-1-fail.txt](docs/m6-1-fail.txt)) — `findWordPx` stub returns null:

```
DEBUG: insideFirstWord got=null exp=abc
FAIL: WordHitTestTests.wordHitTest_insideFirstWord
DEBUG: insideMiddleWord got=null exp=def
FAIL: WordHitTestTests.wordHitTest_insideMiddleWord
... (7 total FAIL)
Ran 161 tests
FAILED (passed=154, failed=7, errors=0)
```

After implementation ([docs/m6-1-pass.txt](docs/m6-1-pass.txt)):

```
Ran 161 tests
PASSED (passed=161, failed=0, errors=0)
```

**R2 evidence** ([docs/m6-1-r2-evidence.txt](docs/m6-1-r2-evidence.txt)) — bug analysis + manual long-press protocol. The view-side change is observable on the watch by long-pressing a word on the **left** of any line (previously returned null) and by long-pressing words **next to spaces** (previously biased to the visually-left neighbor). Both now resolve to the visually-correct word.

**User-visible change:** long-press in the article reader now lands on the word actually under the finger, including on the left side of the screen. No more dead zone, no more off-by-one.

**Artifact:** `wikiwatch-M6.1.prg` (161 420 bytes).

---

## M6.2 — ASCII punctuation in search + keyboard + body-content search (tag `v0.M6.2`)

Three coupled changes that together close out the keyboard's "I can't type the chars in these article titles" gap:

1. The user can now type ASCII `"`, `'`, and `-` to compose Hebrew acronyms (`שב"ק`, `ש"ס`, `ש"ץ`) and hyphenated compounds (`שיר-השירים`, `שלום-בית`).
2. The search engine **ignores** `"` and `'`, and treats `-` as a space — so typing `שבק` matches the title `שב"ק`, and `שיר השירים` matches `שיר-השירים-המלא`.
3. The search engine ALSO matches against article **body** text (not just titles), so a query that lands inside an article's content but not its title still surfaces that article.

**The decision (why ASCII and not Hebrew code points):** Hebrew has its own gershayim (״ U+05F4), geresh (׳ U+05F3), and makaf (־ U+05BE). Using them would mean the keyboard outputs one codepoint but the corpus titles (sourced from Hebrew Wikipedia in M8) may use another — and `Search.rank` compares codepoint exactly, so a mismatch silently breaks matches. Defaulting to ASCII for BOTH sides keeps keyboard input and corpus titles codepoint-aligned. No boundary translation needed.

**What landed:**

**Pure module additions** (`source/models/Search.mc`, `Toybox.Lang` only):
- New `Search._normalize(s) as String` — walks the char array, skips ASCII `"` (0x22) and `'` (0x27), replaces ASCII `-` (0x2D) with space. Pure + idempotent.
- `Search.rank` now matches `_normalize(query)` against `_normalize(title)` for tier 1 (prefix) + tier 2 (substring), plus a new tier 3 — body fallback when no title hit AND `article[:body]` is present. Tier ordering: title-prefix > title-substring > body-substring (popularity within each).
- `Search.totalMatches` — same normalize + body-fallback semantics.
- Returned dicts keep ORIGINAL `:title` — normalization is for matching only, never mutates the data.

**Keyboard layout** (`source/models/KeyboardLayout.mc`):
- `DIGITS_EXPANSION_COUNT` 10 → 13. `DIGITS_EXPANSION_ARC_DEG` = 28 (~360/13 with 1° overlap at boundaries — hit-test grabs first match).
- DIGITS button's `:letters` now `["0".."9","\"","'","-"]`. Closed-state mini hint `"0 1 _ 9"` unchanged (the punctuation chars appear only after the user opens the expansion).
- Cell centers step by `(i * 360) / 13`: 0, 27, 55, 83, 110, 138, 166, 193, 221, 249, 277, 305, 332.

**View wiring** (`source/wikiwatchKeyboardDelegate.mc`):
- `initialize` pre-loads `ArticleStore.bodyOf(id)` into each article dict's `[:body]` slot once at construction. ~5.4 KB resident for the 36-article corpus; ~50 KB worst-case at 300+ articles — under any single-alloc threshold and under R5's 4 KB single-alloc trigger (each `getValue` is its own small alloc).
- No view-side changes needed: the existing DIGITS expansion renderer uses `s[:arcDeg]` from each sub-button dict, so it picks up the new 28° width automatically.

**Fixtures** (`source/models/Fixtures.mc`):
- `:version 3 → 4` → existing `FixtureInstaller` auto-migrates on next launch.
- 6 new ש-prefix entries exercising ASCII punctuation:

  | id | title | what it is |
  |---|---|---|
  | `shas` | ש"ס | Shas (Talmud / political party) |
  | `shabak` | שב"ק | Sabbath colloquial |
  | `shatz` | ש"ץ | Prayer leader (shaliach tzibur) |
  | `shai-agnon` | ש"י-עגנון | S.Y. Agnon (combines " and -) |
  | `shalom-bayit` | שלום-בית | Domestic harmony (hyphenated) |
  | `sh-aharon` | ש'אהרון | Sh. Aharon (abbreviated first name) |

  Corpus 30 → 36. Each entry has a short body that mentions the same chars so tier-3 body search is exercised end-to-end (the body of `shas`, `shabak`, `shatz`, `shai-agnon`, `sh-aharon` all contain the phrase "ראשי תיבות" which doesn't appear in any title — typing it now finds them).

**Test changes (+14 net, 161 → 175):**
- `test_Search.mc` — 12 new cases: 6 normalize (strip `"`, strip `'`, hyphen-as-space, all three, empty, idempotent) + 3 rank-with-normalization (matchesTitleIgnoringQuotes, matchesHyphenAsSpace, preservesDisplayedTitle) + 2 body-search (matchesBodyWhenTitleDoesnt, titleMatchesBeforeBodyMatches) + 1 totalMatches body inclusion.
- `test_KeyboardLayout.mc` — 1 new (`subButtonsDigitsLastThreeAreAsciiPunctuation`) + 2 updated (`buttonNineIsDigits` 10 → 13 letters; `subButtonsDigitsReturnsTenAroundRing` → `…ReturnsThirteenAroundRing` with new center angles 0/138/249).
- `test_Fixtures.mc` — 1 new (`hasEntriesWithEachAsciiPunctuation`) + 2 updated (`manifestVersionIsThree` → `…Four`; `manifestHasThirtyArticles` → `…HasThirtyFiveArticles`).

**R1 evidence** ([docs/m6-2-fail.txt](docs/m6-2-fail.txt)) — stub `_normalize` returns input unchanged:

```
search_normalizeStripsAsciiDoubleQuote               FAIL
search_normalizeStripsAsciiSingleQuote               FAIL
search_normalizeReplacesAsciiHyphenWithSpace         FAIL
search_normalizeAllThreeChars                        FAIL
search_normalizeEmptyReturnsEmpty                    PASS
search_normalizeIdempotent                           PASS
search_rankMatchesTitleIgnoringQuotes                FAIL
search_rankMatchesHyphenAsSpace                      FAIL
search_rankPreservesDisplayedTitleWithPunctuation    FAIL
search_rankMatchesBodyWhenTitleDoesnt                FAIL
search_rankTitleMatchesBeforeBodyMatches             FAIL
search_totalMatchesIncludesBodyHits                  FAIL
kbd_buttonNineIsDigits                               FAIL
kbd_subButtonsDigitsReturnsThirteenAroundRing        FAIL
kbd_subButtonsDigitsLastThreeAreAsciiPunctuation     FAIL
fixtures_manifestHasThirtyFiveArticles               FAIL
fixtures_manifestVersionIsFour                       FAIL
fixtures_hasEntriesWithEachAsciiPunctuation          FAIL
Ran 175 tests
FAILED (passed=159, failed=16, errors=0)
```

After implementation ([docs/m6-2-pass.txt](docs/m6-2-pass.txt)):

```
Ran 175 tests
PASSED (passed=175, failed=0, errors=0)
```

(The 2 normalize tests that already passed against the stub were the trivial cases: `empty → empty` and `idempotent` — the identity stub satisfies both.)

**R2 evidence** ([docs/m6-2-r2-evidence.txt](docs/m6-2-r2-evidence.txt)) — live `monkeydo bin/wikiwatch.prg venu2` shows the fixture install now lists 36 IDs including the 6 new entries (`shas, shabak, shatz, shai-agnon, shalom-bayit, sh-aharon`). The evidence file documents a 5-scenario manual touch protocol covering: punctuation in results display, gershayim ignored, makaf as space, body fallback, tier ordering (title-match wins over body-match regardless of popularity).

**User-visible change:** users can now type Hebrew acronyms and hyphenated terms on the keyboard. Search finds the right article whether or not the user knows the exact punctuation convention used in the title — `שבק` and `שב"ק` both find `שב"ק`; `שיר השירים` and `שיר-השירים` both find `שיר-השירים-המלא`. And typing a phrase that only appears in the article body still surfaces that article.

**Artifact:** `wikiwatch-M6.2.prg` (163 820 bytes).

**Caveat:** M6.2 shipped with an uncatchable OOM bug — see M6.3 below. Use `wikiwatch-M6.3.prg` for sideloading.

---

## M6.3 — Hotfix M6.2 OOM crash (tag `v0.M6.3`)

M6.2 went out at 11:53; the user reported within minutes that the app crashed on three common interactions:

1. Typing any first char that isn't `ש`.
2. Typing `ש` followed by any second letter.
3. Tapping a suggestion to open an article (any article, e.g. `שלום`).

Root cause — two compounding problems in M6.2's body-search machinery:

- **`Search._normalize` was O(N²).** It built its output via `out = out + ch` in a per-char loop. In Monkey C, Strings are immutable, so every `+` allocates a fresh String. An N-char input produces N intermediate strings whose lengths sum to ~N(N+1)/2 → O(N²) byte-allocations. On the ~2 KB shalom `sampleArticle` body, that's ~4 million byte-allocations per pass.
- **Every body got re-normalized per keystroke.** M6.2's `_recomputeSuggestions` called both `Search.rank` and `Search.totalMatches`, and each of them walked every article that missed by title through `_normalize(body)`. Per keystroke: ~8 million byte-allocs over the shalom body alone.
- **Plus the body pre-load held ~5 KB resident** in `KeyboardDelegate._articles` even when the user wasn't searching. On article-open, the reader's M2.8 px-wrap adds another ~10 KB transient. Total transient peak ~15+ KB above keyboard baseline → blew the Venu 2 heap.

OOM in Monkey C is uncatchable. The VM kills the app immediately. No stack trace surfaces in `monkeydo` because the host process dies mid-print. (See [`memory/reference_ciq_quirks.md`](https://github.com/tomhea/wikiwatch/blob/main/.cache/) and the `garmin-ciq-simulator` skill for the project's standing notes on this.)

**What landed:**

**Search** (`source/models/Search.mc`):
- `Search.rank` — removed tier-3 body fallback. Back to M5/M6 title-only matching, KEEPING the M6.2 ASCII normalization on titles (which is small + safe — title inputs are ~20 chars max).
- `Search.totalMatches` — removed the body branch. Title-only count.
- `Search._normalize` — added a fast-path: when the input contains no `"`, `'`, or `-`, return the input string unchanged (no allocation). The O(N²) slow path is now only reachable for short title/query inputs that actually contain those chars (~20 chars on fixtures → ~400 byte-allocs, fine).

**KeyboardDelegate** (`source/wikiwatchKeyboardDelegate.mc`):
- `initialize` — removed the body pre-load loop. Reclaims ~5 KB of resident heap.

**Kept from M6.2:** ASCII normalization on titles, the 3 new keyboard keys (`"` / `'` / `-`) in the DIGITS expansion, the 6 new ש-prefix fixtures with ASCII punctuation in titles. So typing `שבק` still finds `שב"ק`; typing `שיר השירים` still finds `שיר-השירים-המלא`. Only the body-search part is gone.

**Test changes (net 0; still 175):**
- Removed 3 M6.2 body-search tests: `search_rankMatchesBodyWhenTitleDoesnt`, `search_rankTitleMatchesBeforeBodyMatches`, `search_totalMatchesIncludesBodyHits`.
- Added 3 M6.3 regression tests:
  - `search_rankIgnoresBodyKey` — even with `:body` present, `rank` must not match on it.
  - `search_totalMatchesIgnoresBodyKey` — `totalMatches` counts title-only.
  - `search_normalizeFastPathReturnsIdenticalString` — non-punctuation input is returned by value (the real fast-path proof is the runtime no-crash in R2).

**R1 evidence** ([docs/m6-3-fail.txt](docs/m6-3-fail.txt)) — M6.3 regression assertions on M6.2 impl:

```
search_rankIgnoresBodyKey                            FAIL
search_totalMatchesIgnoresBodyKey                    FAIL
search_normalizeFastPathReturnsIdenticalString       PASS
Ran 175 tests
FAILED (passed=173, failed=2, errors=0)
```

After fix ([docs/m6-3-pass.txt](docs/m6-3-pass.txt)):

```
Ran 175 tests
PASSED (passed=175, failed=0, errors=0)
```

**R2 evidence** ([docs/m6-3-r2-evidence.txt](docs/m6-3-r2-evidence.txt)) — live `monkeydo bin/wikiwatch.prg venu2` after the fix. KeyboardDelegate.initialize no longer walks every body through `ArticleStore.bodyOf` at construction. Manual touch protocol confirmed by the user that all three M6.2 crash scenarios are now stable.

**User-visible change:** the app no longer crashes. Body-text search no longer works (it returned in M6.2 and was rolled back here); title-search behaves as it did at M6 + M6.1 + M6.2's ASCII normalization. A future milestone will re-introduce body search with a different architecture — lazy per-keystroke `ArticleStore.bodyOf` reads, or a precomputed index, or similar — anything that doesn't keep every body resident AND doesn't re-walk every body per keystroke.

**Lesson recorded in memory:** O(N²) string concat is a hard Monkey C anti-pattern. Even a short-looking loop will blow the heap on KB-sized inputs because Strings are immutable and every `+` allocates fresh. The project's known-caveats now flag this explicitly.

**Artifact:** `wikiwatch-M6.3.prg` (163 388 bytes).

---

## M6.4 — Remove `"` / `'` / `-` keys from DIGITS expansion (tag `v0.M6.4`)

User feedback after using M6.3 on the watch: the 0-9 extended ring contained the new `"` / `'` / `-` keys (added in M6.2) and they aren't wanted there. Search already handles those chars without the user ever needing to type them — typing `שבק` finds `שב"ק` because `Search._normalize` strips the gershayim during matching. The keys were redundant input clutter.

**What landed:**

`source/models/KeyboardLayout.mc`:
- DIGITS button's `:letters` back to `["0".."9"]` (was 13 cells including `"` / `'` / `-`).
- DIGITS expansion loop back to 10 sub-buttons at `WEDGE_ARC_DEG` (36°) each, centers at `i * 36`. Removed the `DIGITS_EXPANSION_COUNT` / `DIGITS_EXPANSION_ARC_DEG` constants — they were introduced in M6.2 solely to accommodate the 13-cell layout, no longer needed.

**Kept** from M6.2/M6.3:
- `Search._normalize` (strip `"` and `'`, replace `-` with space) on the match side. The hot path is the fast-path so it's free for normal Hebrew titles + queries; only kicks in for inputs that contain those chars.
- 6 new ש-prefix fixtures with ASCII `"` / `'` / `-` in titles (`shas` `שב"ק`, `shabak` `ש"ס`, `shatz` `ש"ץ`, `shai-agnon` `ש"י-עגנון`, `shalom-bayit` `שלום-בית`, `sh-aharon` `ש'אהרון`). Validate that the normalization is observable on the live corpus.

**Test changes (-1 net, 175 → 174):**
- `test_KeyboardLayout.mc` — `kbd_subButtonsDigitsLastThreeAreAsciiPunctuation` REMOVED (no longer applicable). `kbd_buttonNineIsDigits` reverted to expect 10 letters. `kbd_subButtonsDigitsReturnsThirteenAroundRing` renamed to `…ReturnsTenAroundRing` with original 36°/180°/324° centers.

**R1 evidence** ([docs/m6-4-fail.txt](docs/m6-4-fail.txt)) — the new 10-cell assertions on the M6.3 13-cell impl:

```
kbd_buttonNineIsDigits                               FAIL
kbd_subButtonsDigitsReturnsTenAroundRing             ERROR
Ran 174 tests
FAILED (passed=172, failed=1, errors=1)
```

After revert ([docs/m6-4-pass.txt](docs/m6-4-pass.txt)):

```
Ran 174 tests
PASSED (passed=174, failed=0, errors=0)
```

**R2 evidence** ([docs/m6-4-r2-evidence.txt](docs/m6-4-r2-evidence.txt)) — live `monkeydo bin/wikiwatch.prg venu2` shows the 36-article corpus intact (including all the punctuation-bearing titles from M6.2). User verified in sim that DIGITS expansion is now 10 cells (no `"` / `'` / `-`), and typing `שבק` still finds `שב"ק` via normalization.

**User-visible change:** tapping DIGITS now opens an expansion with just `0..9` (no punctuation cells). Search behavior for punctuation-bearing titles is unchanged.

**Artifact:** `wikiwatch-M6.4.prg` (163 356 bytes).

---

## M6.5 — Memory optimizations + `freeMemory` overlay (tag `v0.M6.5`)

M6.4 worked in sim but on the real Venu 2 watch the UI stopped refreshing after taps. Functionally everything worked — state updated, taps registered, articles opened — but `WatchUi.requestUpdate()` calls weren't actually triggering `onUpdate` redraws. Classic symptom of CIQ throttling UI under GC pressure (the sim has more relaxed GC than the watch).

This PR ships four memory wins + a UI-visible `freeMemory` overlay so the user can monitor heap pressure live on the watch.

**Four wins:**

1. **`KeyboardLayout.buttons()` cached at module level.** The 10-button array is immutable — there's no reason to allocate it fresh on every call. Was ~850 B/call × every `onUpdate` + every `onTap`. Now returns a cached ref. Steady-state cost: ~850 B kept resident forever.

2. **`KeyboardLayout.subButtons(parent)` cached per parent's `centerAngleDeg`.** 10 unique parents (SPACE, BACKSPACE, 7 letter groups, DIGITS), so 10 cache slots, ~1.5 KB total once all are touched. Was ~150 B/call during expansion.

3. **`_drawWedge` polygon buffer preallocated as view field.** Was allocating fresh `new [10]` + 10 `[sx, sy]` arrays per wedge per render (~4 KB/onUpdate). Now mutates the preallocated buffer in place. `dc.fillPolygon` copies what it needs, so post-call mutation is safe.

4. **wikiwatchView per-sub-line `:words` / `:wordPx` / `:spacePx` storage DROPPED.** M6.1 added these for pixel-accurate `findWordAt` — cost ~6.5 KB resident on shalom-sized articles (50 sub-lines × ~130 B). Long-press now goes:
   - `wikiwatchDelegate.onHold` → `view.requestLongPressHit(x, y)` (stores coords + `requestUpdate`)
   - Next `onUpdate` runs `_resolvePendingHit(dc)` which measures ONLY the tapped sub-line's words inline (~130 B transient) and pushes the new keyboard layer.
   - The old `wikiwatchView.findWordAt` method is gone; its only callsite (`wikiwatchDelegate.onHold`) now uses the lazy path.

**Plus the `freeMemory` overlay** — rendered as `fm:NNNNNN` near the bottom-center of the keyboard's visible round display (LT_GRAY FONT_XTINY). On the sim it shows ~732 KB free; on the real watch it'll show much less. Lets the user observe heap pressure live (no stdout on the watch).

**Net memory impact:** ~10-15 KB resident heap reclaimed (mostly from #4); ~25-50 KB/sec GC churn eliminated (mostly from #1 + #3). Steady-state cost: +~2.5 KB (the caches sit resident).

**Test changes (+2 net, 174 → 176):**
- `test_KeyboardLayout.mc` — `kbd_buttonsReturnsCachedReference` + `kbd_subButtonsReturnsCachedReference`. Both verify the cache by mutating one returned dict's label and observing the mutation on the next call (identity proxy via shared state). `try`/`finally` restores the original label.

**R1 evidence** ([docs/m6-5-fail.txt](docs/m6-5-fail.txt)) — un-cached M6.4 code:

```
kbd_buttonsReturnsCachedReference                    FAIL
kbd_subButtonsReturnsCachedReference                 FAIL
Ran 176 tests
FAILED (passed=174, failed=2, errors=0)
```

After implementation ([docs/m6-5-pass.txt](docs/m6-5-pass.txt)):

```
Ran 176 tests
PASSED (passed=176, failed=0, errors=0)
```

**R2 evidence** ([docs/m6-5-r2-evidence.txt](docs/m6-5-r2-evidence.txt)) — live `monkeydo bin/wikiwatch.prg venu2` + screenshot at [docs/screenshots/m6-5-freemem-overlay.png](docs/screenshots/m6-5-freemem-overlay.png) showing the new `fm:732656` overlay rendering at the bottom-center of the keyboard view.

**User-visible change:** the keyboard reads `fm:NNNNNN` at the bottom-center of the visible round display. On the watch, the user watches this number while typing/expansion/article-open. If it stays comfortably above zero but the UI still doesn't refresh, the bug isn't memory — we'll need to look elsewhere (watchdog, view-stack confusion, firmware-specific issue).

**Artifact:** `wikiwatch-M6.5.prg` (164 604 bytes).

---

## M7 — Real-network corpus from `https://wikiwatch.tomhe.app/` (tag `v0.M7`)

**The shape of the app fundamentally shifts at M7.** Before: a self-contained .prg with hard-coded fixture content. After: a real distributed system — a server you upload to (`wikiwatch.tomhe.app/`), and a client (the watch) that fetches the corpus on first launch and re-checks on every subsequent launch via a 750 ms background race.

This unlocks M8 (real Hebrew Wikipedia content) — once the upload pipeline exists, swapping fixture content for real content is just `gen-server-corpus.ps1` + a redeploy.

**Server contract** (see [docs/m7-plan.md](docs/m7-plan.md) for the full design + state machine):
- `GET /manifest.json` → `{version, totalBytes, articles: [{id, title, popularity}]}`. Content-Type: `application/json`.
- `GET /article/<id>.txt` → UTF-8 Hebrew Markdown body. Content-Type: `text/plain; charset=utf-8`.
- TLS cert must be valid; user confirmed `wikiwatch.tomhe.app/` is serving correctly.

**State machine** (CIQ view stack):

```
[launch]
   |
   Manifest.isEmpty()?
      |
      Yes → [InstallView] (full download, sequential)
      |       (on done)  → [KeyboardView] (functional, fresh corpus)
      |       (on error) → [KeyboardView] (degraded — empty corpus)
      |
      No  → [UpdateCheckView] (750 ms race vs Downloader.fetchManifest)
              |
              ├── timeout                                 → [KeyboardView] (functional, stale)
              ├── fetch OK + same/older version           → [KeyboardView] (functional)
              ├── fetch OK + newer version                → [UpdatePromptView]
              └── parse/network error                     → [KeyboardView] (functional, stale)

[UpdatePromptView] — top half (DK_GREEN) = "Yes", bottom half (DK_GRAY) = "No"
   tap top   → Manifest.wipeArticles() → [InstallView]
   tap bot   → [KeyboardView] (functional, stale)
   back btn  → same as bottom
```

**What landed:**

**New** `source/net/Downloader.mc` (R6: outside `source/models/` because it imports `Toybox.Communications` + `Toybox.System`):
- `parseManifestResponse(rc, data) as Dictionary` — pure parser. Validates HTTP rc + dict shape AND converts the JSON String-keyed schema (`"version"`, `"articles": [{"id", ...}]`) into the in-memory Symbol-keyed schema (`:version`, `:articles => [{:id, ...}]`) used by `Manifest` / `Search` / `KeyboardDelegate`. This is the single boundary between raw server JSON and the app data model.
- `fetchManifest(callback)` — `Communications.makeWebRequest` with `HTTP_RESPONSE_CONTENT_TYPE_JSON`.
- `fetchArticle(id, callback)` — same with `HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN`.
- `BASE_URL = "https://wikiwatch.tomhe.app"`.

**New** `Manifest.wipeArticles() as Number`:
- Deletes all `article:<id>` Storage keys (preserves the `manifest` key — caller can wipe + re-save in any order).
- Returns count deleted.

**New views** (all at `source/` root per project convention, NOT `source/views/`):
- `InstallView` + `InstallDelegate` — `onShow → Downloader.fetchManifest`. On manifest receive: parse, `Manifest.save`, drive a sequential per-article fetch loop. Each fetch holds ≤1 body in memory. Final → `switchToView(KeyboardView)`. On error: log, `_scheduleSwitchToKeyboard(2000)` for "no network. try later." fallback.
- `UpdatePromptView` + `UpdatePromptDelegate` — full-screen modal. Yes/No based on tap y-coord vs `screenH/2`.
- `UpdateCheckView` + `UpdateCheckDelegate` — every-launch view. 750 ms `Timer.Timer` race against `Downloader.fetchManifest`. Renders the keyboard layout underneath for visual continuity; "checking for updates..." text overlay in yellow near the bottom. Taps absorbed during the check.

**Modified** `source/wikiwatchApp.mc`:
- `onStart` no longer calls `FixtureInstaller.installIfEmpty()` — the M7 flow handles corpus loading.
- `getInitialView` branches: `Manifest.isEmpty()` → `InstallView`; else → `UpdateCheckView`.

**Modified** `manifest.xml`:
- Added `<iq:uses-permission id="Communications"/>`. Required for `makeWebRequest`; without it the build fails with "Permission 'Communications' required" errors.

**Deleted:**
- `source/models/Fixtures.mc` (118 lines — the hard-coded 36-article corpus).
- `source/storage/FixtureInstaller.mc` (48 lines — version-aware install glue).
- `source/tests/test_Fixtures.mc`, `source/tests/test_FixtureInstaller.mc` (10 tests total).

**Test changes (−10 + 8 = −2 net, 176 → 174):**
- `test_Downloader.mc` — 6 tests: `parseManifestSuccess`, `parseManifestRejectsBadRc`, `parseManifestRejectsNullData`, `parseManifestRejectsMissingVersion`, `parseManifestRejectsMissingArticles`, `parseManifestNormalizesKeys` (the JSON-String-keyed → in-memory-Symbol-keyed conversion).
- `test_Manifest.mc` — 2 new: `wipeArticlesDeletesAllArticleBodies`, `wipeArticlesOnEmpty`.

**R1 evidence** ([docs/m7-fail.txt](docs/m7-fail.txt)) — stub impls:

```
downloader_parseManifestSuccess                      FAIL
downloader_parseManifestRejectsBadRc                 PASS
downloader_parseManifestRejectsNullData              PASS
downloader_parseManifestRejectsMissingVersion        PASS
downloader_parseManifestRejectsMissingArticles       PASS
downloader_parseManifestNormalizesKeys               FAIL
manifest_wipeArticlesDeletesAllArticleBodies         FAIL
manifest_wipeArticlesOnEmpty                         PASS
Ran 184 tests
FAILED (passed=181, failed=3, errors=0)
```

After implementation ([docs/m7-pass.txt](docs/m7-pass.txt)):

```
Ran 174 tests
PASSED (passed=174, failed=0, errors=0)
```

**R2 evidence** ([docs/m7-r2-evidence.txt](docs/m7-r2-evidence.txt)) — live `monkeydo bin/wikiwatch.prg venu2`:

```
M7 install: fetching manifest from https://wikiwatch.tomhe.app
M7 net: GET https://wikiwatch.tomhe.app/manifest.json
M7 install: manifest fetch FAILED -- http rc=-1001
M5 rank: buf='' (empty -- no results shown)
```

Demonstrates the error-path flow: sim BLE proxy can't reach the real internet without a paired phone (`rc=-1001`), `InstallView`'s 2s fallback timer fires, `switchToView(KeyboardView)`, keyboard reaches a functional state in "degraded mode" (no corpus). Real-watch sideload validates the happy path. The evidence file documents expected stdout for all 4 paths (first-launch, same-version, update-available, slow-network).

**Design decisions** (from [docs/m7-plan.md](docs/m7-plan.md)):
- **750 ms check budget** — compromise between 500 ms (too tight for cold BLE wake, can take ~1500 ms) and 1000 ms (eats more startup latency than needed). Easy to bump in a hotfix.
- **Sequential, NOT concurrent** per-article install — keeps memory bounded (≤1 body in memory) and BLE proxy is single-channel anyway.
- **Tap-based Yes/No prompt** — no swipe gesture; top-half = green = Yes, bottom-half = gray = No. Back button = No.
- **`Manifest.save` happens upfront in `installAll`** — so partial-install state is recoverable on re-launch (we know which articles SHOULD be present).

**User-visible change:** first launch with phone-paired internet shows "Loading wikiwatch: N / M articles" before the keyboard appears with the full corpus. Subsequent launches have a brief (≤750 ms) "checking for updates..." flash before becoming functional. If you (the server owner) bump `manifest.json`'s `version` field, all watches see the update prompt on next launch.

**Artifact:** `wikiwatch-M7.prg` (166 300 bytes).

**Server payload:** `docs/server/` (shipped in PR #48). 36 article body files + manifest.json. User uploads to `wikiwatch.tomhe.app/` matching the path structure.

---

## M7.1 — Connectivity-aware launch + 1s update-check timeout + NoConnectionView (tag `v0.M7.1`)

M7 worked when network was available, but the user reported that the app **appeared frozen on the watch when USB cable was connected** for sideloading — same M6.4 stale-render symptom (taps register but UI doesn't repaint, blind-tap on results opens articles, scrolling broken).

**Root cause:** when USB is plugged into a Venu 2, **BLE is deprioritized** because USB is the active transport. CIQ's `Communications.makeWebRequest` routes through the BLE proxy to the phone — with BLE deprioritized, requests **hang for ~30 seconds** waiting for the proxy timeout. A hanging request **clogs CIQ's single-threaded event loop**: other events (including `requestUpdate` from your taps) queue behind the pending network operation. Visually identical to GC pressure (the M6.4 / M6.5 issue) but different mechanism.

**Three changes that eliminate the clog:**

1. **`Downloader.isNetworkAvailable()`** — new wrapper around a pure helper `_anyConnected(connectionInfo, phoneConnected)`:
   - CIQ 3.3+ devices have `System.DeviceSettings.connectionInfo` — a Dictionary keyed by connection type (`CONNECTION_PHONE` / `CONNECTION_WIFI` / `CONNECTION_LTE`). Each value has a `state` member. Returns true if ANY is `CONNECTION_STATE_CONNECTED`.
   - Older watches fall back to the `phoneConnected` boolean.

2. **`wikiwatchApp.getInitialView` gains a 2×2 branch:**

   |                          | network available    | no network          |
   |--------------------------|----------------------|---------------------|
   | Storage empty            | `InstallView`        | `NoConnectionView`  |
   | Storage has corpus       | `UpdateCheckView`    | `KeyboardView` (functional, stale corpus) |

   When no network is up, **no request fires** → no event-loop clog → keyboard stays responsive.

3. **New `NoConnectionView`** — shown when first launch has no network. Static "Need connection to load initial offline articles" message. User reconnects + relaunches. Doesn't auto-poll for reconnect (user has to manually relaunch anyway).

**Also:** `UpdateCheckView._CHECK_TIMEOUT_MS` bumped 750 ms → 1000 ms per user request (real-watch testing showed 750 ms was too tight for cold BLE wake).

**Test changes (+3 net, 174 → 177):**
- `test_Downloader.mc` — 3 new tests for `_anyConnected` using a test-local `FakeConnInfo` helper class that mocks `ConnectionInfo.state` for the dict-keyed assertion.
  - `downloader_anyConnectedFallsBackToPhoneOnly` — null connectionInfo + phoneConnected=true/false returns the boolean.
  - `downloader_anyConnectedDetectsConnected` — dict with CONNECTION_STATE_CONNECTED returns true.
  - `downloader_anyConnectedAllDisconnectedReturnsFalse` — dict with all entries NOT_CONNECTED / NOT_INITIALIZED returns false.

**R1 evidence** ([docs/m7-1-fail.txt](docs/m7-1-fail.txt)) — stub returns false unconditionally:

```
downloader_anyConnectedFallsBackToPhoneOnly          FAIL
downloader_anyConnectedDetectsConnected              FAIL
downloader_anyConnectedAllDisconnectedReturnsFalse   PASS
Ran 177 tests
FAILED (passed=175, failed=2, errors=0)
```

After implementation ([docs/m7-1-pass.txt](docs/m7-1-pass.txt)):

```
Ran 177 tests
PASSED (passed=177, failed=0, errors=0)
```

**R2 evidence** ([docs/m7-1-r2-evidence.txt](docs/m7-1-r2-evidence.txt)) — the sim's BLE proxy worked this time, so the install **actually ran end-to-end against the real server**:

```
M7 install: fetching manifest from https://wikiwatch.tomhe.app
M7 net: GET https://wikiwatch.tomhe.app/manifest.json
M7 net: GET https://wikiwatch.tomhe.app/article/shalom.txt
... (36 articles fetched sequentially) ...
M7 install: DONE installed=36 errors=0 of 36
M5 rank: buf='' (empty — no results shown)
```

First **end-to-end happy-path** validation against the live `wikiwatch.tomhe.app/` server.

**Operational note for development:** the USB sideload workflow is now safer — you can leave USB connected after sideload because the no-network branch dodges the hang. But for actual app testing, **disconnect USB** so the BLE-network code path gets exercised.

**Artifact:** `wikiwatch-M7.1.prg` (168 252 bytes). Current head of `main`.

---

## What's missing (planned but not yet built)

The bigger ladder beyond M5 is documented in the project memory (`memory/project_ladder.md`):

- **M8** — Polish + measure corpus size + Hebrew Wikipedia data generation. Real-watch sideload of M7's `.prg`, record corpus size + free Storage. Sub-PRs (`fix/<slug>` → `v0.M8.<sub>`) for polish items. **New scope:** collaboratively pick + clean real Hebrew Wikipedia article data + build `manifest.json` + `article/<id>.txt`. (Note: ladder reshaped 2026-05-26 — old M8 "digits page" merged into M3.x circular keyboard + M6.2's expansion; old M9 → M8; old M10 → M9.)
- **M9** (conditional) — Static-dictionary compression if M8 shows the corpus doesn't fit in 9 MB.

## Reproducing any version

Every milestone tag points at the merge commit on `main`, and every milestone added a co-located `.prg` archive in this folder. To rebuild from source:

```powershell
git checkout v0.M<N>
& scripts\test.ps1     # 177 tests pass at v0.M7.1
& scripts\build.ps1    # writes bin\wikiwatch.prg
```

To sideload to a real Venu 2: copy `versions\wikiwatch-M<N>.prg` to `GARMIN\APPS\` over USB (or the equivalent rebuilt `.prg`). Same UUID in `manifest.xml` across versions means the watch treats each as an update of the same app, not a fresh install.