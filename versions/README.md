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

**Artifact:** `wikiwatch-M4.prg` (137 516 bytes). Current head of `main`.

---

## What's missing (planned but not yet built)

The bigger ladder beyond M4 is documented in the project memory (`memory/project_ladder.md`):

- **M5** — Live search (prefix + substring + popularity ranking) over `Manifest.articleIds()` / `titleOf()`, results list view; wires `:SEARCH` from the M3 keyboard.
- **M6** — Long-press a word in the article → push a new keyboard layer pre-filled with that word. Layer stack pop/push.
- **M7** — First-run chunked download from `wikiwatch.tomhe.app/` into `Application.Storage`; resumable.
- **M8** — Digits page on the keyboard ("123" toggle). (M3.x already ships the DIGITS wedge with 0..9 expansion; M8 may evolve into a dedicated punctuation/symbols page.)
- **M9** — Polish + measure corpus size; decide whether M10 is needed.
- **M10** (conditional) — Static-dictionary compression if M9 shows storage-constrained.

## Reproducing any version

Every milestone tag points at the merge commit on `main`, and every milestone added a co-located `.prg` archive in this folder. To rebuild from source:

```powershell
git checkout v0.M<N>
& scripts\test.ps1     # 112 tests pass at v0.M4
& scripts\build.ps1    # writes bin\wikiwatch.prg
```

To sideload to a real Venu 2: copy `versions\wikiwatch-M<N>.prg` to `GARMIN\APPS\` over USB (or the equivalent rebuilt `.prg`). Same UUID in `manifest.xml` across versions means the watch treats each as an update of the same app, not a fresh install.