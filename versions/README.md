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

**Artifact:** `wikiwatch-M2.4.prg` (113 916 bytes). Current head of `main`.

---

## What''s missing (planned but not yet built)

The bigger ladder beyond M2.x is documented in the project memory (`memory/project_ladder.md`):

- **M3** — Static Hebrew touch keyboard (22 letters + space + backspace + delete-all + search). No search wiring yet.
- **M4** — `ArticleStore` + `Manifest` modules; fixture article data persisted in `Application.Storage`.
- **M5** — Live search (prefix + substring + popularity ranking), results list view.
- **M6** — Long-press a word in the article → push a new keyboard layer pre-filled with that word. Layer stack pop/push.
- **M7** — First-run chunked download from `wikiwatch.tomhe.app/` into `Application.Storage`; resumable.
- **M8** — Digits page on the keyboard ("123" toggle).
- **M9** — Polish + measure corpus size; decide whether M10 is needed.
- **M10** (conditional) — Static-dictionary compression if M9 shows storage-constrained.

## Reproducing any version

Every milestone tag points at the merge commit on `main`, and every milestone added a co-located `.prg` archive in this folder. To rebuild from source:

```powershell
git checkout v0.M<N>
& scripts\test.ps1     # 53 tests pass at v0.M2.4
& scripts\build.ps1    # writes bin\wikiwatch.prg
```

To sideload to a real Venu 2: copy `versions\wikiwatch-M<N>.prg` to `GARMIN\APPS\` over USB (or the equivalent rebuilt `.prg`). Same UUID in `manifest.xml` across versions means the watch treats each as an update of the same app, not a fresh install.