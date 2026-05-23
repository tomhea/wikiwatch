# wikiwatch — handoff to the next Claude session

**You are picking up an in-progress Garmin Connect IQ project.** Read this whole
document before touching anything. The previous session shipped M0 through M2.4
(eight tagged milestones, 53 passing tests, full TDD / CR-ist / literal-merge
discipline). The user wants you to continue the same ladder from M2.5 onward
using the same workflow.

---

## 0. Read these first

### Three skills to load

The previous session distilled the hard-won lessons into three project-level
skills. **Use them.** Don't reinvent decisions that are already settled.

| Skill | Path | When you reach for it |
| --- | --- | --- |
| `cr-tdd-ladder` | `~/.claude/skills/cr-tdd-ladder/SKILL.md` | The workflow itself — branch / PR / CR-ist / merge / tag / archive. Reread before every milestone. |
| `garmin-code` | `~/.claude/skills/garmin-code/SKILL.md` | Monkey C + CIQ specifics — project layout, language quirks, font metrics, touch, storage, OOM rules, chord math, `(:test)` framework. |
| `garmin-ciq-simulator` | `~/.claude/skills/garmin-ciq-simulator/SKILL.md` | The build/run/debug loop in the Connect IQ simulator on Windows — how to capture `monkeydo` stdout, simulator-only gotchas, OOM, network. |

These auto-trigger when their description matches the task, but if you're
about to make a decision that feels like it might already have an answer, open
the skill and check. The skill files contain the **proven** approach — your
job is to follow it, not redesign it.

### Project memory files

The user's auto-memory holds the project state. These persist across sessions
under `C:\Users\tomhe\.claude\projects\C--Users-tomhe-Documents-Garmin-wikiwatch\memory\`:

- `MEMORY.md` — index
- `project_snapshot.md` — what wikiwatch is, current head of `main`
- `project_ladder.md` — the locked-in M0..M10 ladder + status table (read this)
- `feedback_workflow.md` — the four must-rules + CR-ist gating + literal merge
- `feedback_self_approval.md` — why CR-ist self-approve becomes COMMENTED, not APPROVED
- `reference_toolchain.md` — SDK path, `monkeydo /t` (Windows slash), sim preconditions
- `reference_ciq_quirks.md` — Hebrew glyphs in built-in fonts, UTF-8 Storage, font draw gotchas
- `reference_sim_screenshot.md` — PrintWindow + System.Drawing for R2 evidence (fragile)
- `feedback_screenshots.md` — prefer stdout diagnostic; only screenshot when pixel-level UX is the claim
- `feedback_file_write_ebadf.md` — Write/Edit fail when sim has files mapped; use `[System.IO.File]::WriteAllText`

### Repo references

- `docs/cr-rules.md` — R1..R8, the eight rules CR-ist mechanically enforces
- `docs/known-warnings.md` — the 2 baseline warnings R8 ignores
- `versions/README.md` — every milestone documented with R1/R2 evidence
- `.claude/agents/crist.md` — the CR-ist subagent definition

---

## 1. Current state of `main`

| Item | Value |
| --- | --- |
| Head | `v0.M2.4` — commit `cc04b79` |
| Tests | **53** `(:test)` functions, all passing |
| Build | clean with 2 known warnings (manifest language + 24×24 launcher icon) |
| Visual | Hebrew article reader: H1 centered (160/250 narrow), middle body right-anchored at `screenW - 25`, last 2 sub-lines narrow (250/160) centered; live drag scroll via `onDrag`; `onUpdate` skip-ahead optimization |

The full layout contract is in `memory/project_ladder.md` under "Article reader
contract (as of M2.4)" — copy-paste worthy.

### Verifying you're in a clean state

```powershell
git checkout main
git pull
& scripts\test.ps1     # expect 53/53 pass
& scripts\build.ps1    # expect "BUILD SUCCESSFUL"
```

If anything fails, **stop and ask the user.** Don't paper over it.

---

## 2. The four must-rules (non-negotiable)

These are documented in `cr-tdd-ladder` but bear repeating because they're
the entire reason this project is shippable:

1. **TDD** — every PR body has BOTH a FAILing run (before implementation) AND a
   PASSing run (after). One block alone fails R1.
2. **Mini versions** — every PR is one tagged version with a `.prg` archived in
   `versions/`. Never bundle two milestones into one PR.
3. **Simulator validation** — every layout/UX change includes either a
   screenshot or `monkeydo` stdout evidence in the PR body (R2).
4. **No code on main** — every change goes through `branch → PR → CR-ist review
   → literal merge commit → annotated tag → archived .prg`. Force-push and
   straight commits to `main` are blocked by branch protection.

If you're tempted to skip a step "just this once", don't. The previous session
hit every one of these temptations and the discipline is what made M2.x ship
cleanly.

---

## 3. M2.5 — next up

The plan file already exists at:
`C:\Users\tomhe\.claude\plans\lazy-fluttering-sonnet.md`

It was approved by the user but not executed — they redirected the previous
session to write skills + documentation instead. **Just execute that plan as
M2.5.** Below is the same content distilled for quick reference, in case the
plan file is gone by the time you read this.

### M2.5 — branch `fix/left-align-second-300-double-tap`, tag `v0.M2.5`

**PR title:** `Fix: left-justify body + narrowSecond 300 + H1 all-centered + double-tap nav`

Four user-driven fixes after testing M2.4:

#### 2.5.1 H1 fully centered

M2.4 centered the first 2 narrow H1 sub-lines (widths 160, 250) but
right-justified any *additional* H1 sub-lines (width = screenW), so a 3-line
H1 looked inconsistently aligned. Fix: tag every sub-line produced by
`meta[0]` (the firstRaw) with `:isH1 => true`. In `onUpdate`:

```monkeyc
if (ln[:isH1]) {
    dc.drawText(centerX, screenY, ln[:font], ln[:text],
                Graphics.TEXT_JUSTIFY_CENTER);
} else {
    // left-anchored at chord_left (see 2.5.2)
    var anchorX = max(chord_left_at(screenY), _leftMargin);
    dc.drawText(anchorX, screenY, ln[:font], ln[:text],
                Graphics.TEXT_JUSTIFY_LEFT);
}
```

#### 2.5.2 Swap margins (left clean, right bleed)

M2.4: clean margin on the right (`screenW - 25`), bleed on the left (up to 25 px
past edge). User asked to swap that and resize:

- `_leftMargin = 15` (was 25, "biggest -10").
- `_rightBleed = 20` (was 25, "smallest +5", the budget text may extend past
  the right edge).
- `_middleWidth = dc.getWidth() - _leftMargin + _rightBleed` (≈ 421 sim).

Non-H1 sub-lines anchor at `max(chord_left_at(y), _leftMargin)` using
`SafeArea.safeChordHalfWidth(r, dy)` so the narrow tail at the bottom of the
chord still sits inside the round bezel (don't anchor at x=15 there — it'd
clip on the right). Justify mode: `TEXT_JUSTIFY_LEFT`.

**CIQ BiDi caveat** (untested): under `TEXT_JUSTIFY_LEFT`, CIQ's BiDi layer
anchors the run's *visual* left edge at the anchor x. For Hebrew RTL, the
first reading-order codepoint sits at the visual right edge of the run
(`anchorX + textWidth`). If the visual result feels backwards to a Hebrew
reader, flip to `TEXT_JUSTIFY_RIGHT` with `anchorX + textWidth` as the anchor
in a follow-up hotfix.

#### 2.5.3 `narrowSecond` 250 → 300

The second and second-to-last sub-line widths get 50 more pixels. Affects:

- `firstWidths = [narrowEdge=160, narrowSecond=300, _middleWidth=421]` in
  `_layout`.
- `wrapWithNarrowTail(text, charW, _middleWidth, secondWidth=300,
  edgeWidth=160)` for the last raw.

`narrowEdge` stays at 160 (absolute last + absolute first).

#### 2.5.4 Double-tap nav (top → scrollY=0, bottom → scrollY=maxScroll)

A fast double-tap on the very top of the screen jumps to `scrollY = 0`; a
fast double-tap on the very bottom jumps to `scrollY = contentH - screenH`.
A double-tap in the middle does nothing. Single tap is silent.

**New pure module** `source/models/DoubleTap.mc`:

```monkeyc
module DoubleTap {
    // Returns true iff (currentMs, currentY) is the second of a double-tap
    // relative to (prevMs, prevY): within intervalMs in time AND within
    // yTolerance in y. prevMs == 0 indicates "no previous tap" -> false.
    function isDoubleTap(prevMs as Number, prevY as Number,
                         currentMs as Number, currentY as Number,
                         intervalMs as Number, yTolerance as Number) as Boolean;
}
```

**Tests** in `source/tests/test_DoubleTap.mc` (6 cases):
- prevMs = 0 → false
- taps too far apart in time → false
- taps too far apart in y → false
- within both windows → true
- negative time delta (defensive) → false
- edge of interval (boundary) → true at `<=`, false at `>`

**View additions** (`source/wikiwatchView.mc`):
- `scrollToTop()` — `_scrollY = 0; WatchUi.requestUpdate();`
- `scrollToBottom()` — `_scrollY = max(0, _contentHeight - _screenHeight); WatchUi.requestUpdate();`
- `getScreenHeight()` accessor.

**Delegate additions** (`source/wikiwatchDelegate.mc`):
- Fields `_lastTapMs` (init 0), `_lastTapY` (init 0).
- Constants `DOUBLE_TAP_INTERVAL_MS = 300`, `DOUBLE_TAP_Y_TOLERANCE = 80`,
  `EDGE_ZONE_PX = 50`.
- Override `onTap(event)`:
  1. Read `(x, y)` and `now = System.getTimer()`.
  2. `var isDouble = DoubleTap.isDoubleTap(_lastTapMs, _lastTapY, now, y, 300, 80);`
  3. If `isDouble`:
     - `if (y < EDGE_ZONE_PX) _view.scrollToTop();`
     - `else if (y > _view.getScreenHeight() - EDGE_ZONE_PX) _view.scrollToBottom();`
     - else do nothing
  4. Always update `_lastTapMs = now; _lastTapY = y;`

`onDrag`, `onNextPage`, `onPreviousPage` stay unchanged.

### M2.5 files changed

| File | Change |
| --- | --- |
| `source/models/DoubleTap.mc` | **NEW** pure module with `isDoubleTap` |
| `source/tests/test_DoubleTap.mc` | **NEW** 6 `(:test)` cases |
| `source/wikiwatchView.mc` | `:isH1` flag; `_leftMargin=15`, `_rightBleed=20`, `_middleWidth=screenW-15+20`; `narrowSecond=300`; left-anchored justify with adaptive chord_left; `scrollToTop`/`scrollToBottom`/`getScreenHeight` |
| `source/wikiwatchDelegate.mc` | `onTap` with double-tap detection; `_lastTapMs`/`_lastTapY` fields |

### M2.5 TDD evidence flow

1. Add 6 `DoubleTap` tests with a stub returning `false`. Run `scripts/test.ps1`
   → expect ~5 of 6 to FAIL (the "true" expectations fail; "false"
   expectations accidentally pass). Capture `docs/m2-5-fail.txt`.
2. Implement `DoubleTap.isDoubleTap`. Re-run → 59/59 pass. Capture
   `docs/m2-5-pass.txt`.

The view/delegate changes don't introduce new pure-module logic (they wire up
existing helpers and the new `DoubleTap` module), so R1 coverage is via the
`DoubleTap` cycle.

### M2.5 verification

1. `scripts/test.ps1` → exit 0, 59 tests pass.
2. `scripts/build.ps1` → exit 0, same 2 baseline warnings.
3. Simulator: load `bin\wikiwatch.prg`. With a one-shot diagnostic build
   (`System.println` per line of `:isH1` + `:w`), confirm:
   - All H1 sub-lines (rows 0..N-1 where row is from meta[0]) have `:isH1 = true`.
   - Last 2 lines have `w` ∈ `{160, 300}` (was `{160, 250}` in M2.4).
   - Other lines render with `TEXT_JUSTIFY_LEFT` and adaptive anchorX.
4. Manual sim test:
   - Drag-scroll still works.
   - Single tap → nothing.
   - Double-tap near top → article jumps to `scrollY = 0`.
   - Double-tap near bottom → article jumps to `maxScroll`.
   - Double-tap in middle → nothing.
5. CR-ist review → APPROVED.
6. Archive `versions/wikiwatch-M2.5.prg`. Merge with `--merge`. Tag `v0.M2.5`.
   Delete branch.

---

## 4. M3 — Static Hebrew touch keyboard (`v0.M3`)

**Branch:** `m3-static-keyboard`. **PR title:** `M3: Static Hebrew touch keyboard`.

### Scope

Render a static keyboard (no search wiring yet — that's M5). The display:
- 22 Hebrew letters (`א ב ג ד ה ו ז ח ט י כ ל מ נ ס ע פ צ ק ר ש ת`).
- Special keys: `space`, `backspace` (`⌫`), `delete-all` (`✕`), `search` (`🔍`
  or a clearer ASCII glyph if the system font lacks it).
- A typing buffer area at the top of the screen that shows what the user has
  typed so far (read RTL).
- Tapping a letter appends to the buffer. Tapping backspace deletes the last
  codepoint. Tapping delete-all clears the buffer. Tapping search does nothing
  (placeholder — M5 wires it).

### Approach

- New pure module `source/models/KeyboardLayout.mc` with:
  - `keys() as Array<Dictionary>` returning `[{:label, :type, :row, :col}, ...]`.
    Types: `:LETTER`, `:SPACE`, `:BACKSPACE`, `:DELETE_ALL`, `:SEARCH`.
  - `keyAt(x, y, screenW, screenH) as Dictionary?` returning the key whose hit
    rectangle contains (x, y), or `null`.
  - The grid math: rows × cols laid out across the inscribed circle's
    rectangle (use `SafeArea.minSafeY` for vertical bounds). Probably 6 rows ×
    5 cols (= 30 cells; 22 letters + 4 specials + 4 empty cells, fill the
    bottom row).
- New pure module `source/models/InputBuffer.mc` with:
  - `append(buf, ch)`, `popLast(buf)`, `clear(buf)` — pure string ops.
  - Tests for empty buffer behavior, multi-byte Hebrew character handling
    (Hebrew is 2 UTF-8 bytes per glyph; `String.length()` returns char count
    in Monkey C, so simple appends work as long as you don't slice mid-codepoint).
- New view `source/views/KeyboardView.mc` extending `WatchUi.View`:
  - Draws the buffer at the top (Hebrew right-aligned).
  - Draws every key from `KeyboardLayout.keys()` as a labeled rectangle.
- New delegate `source/delegates/KeyboardDelegate.mc` extending
  `WatchUi.BehaviorDelegate`:
  - `onTap(event)` → `KeyboardLayout.keyAt(...)` → dispatch.
  - On `:LETTER` → `buf = InputBuffer.append(buf, key[:label])`.
  - On `:BACKSPACE` → `buf = InputBuffer.popLast(buf)`.
  - On `:DELETE_ALL` → `buf = InputBuffer.clear(buf)`.
  - On `:SEARCH` → no-op (M5 will overload this).
  - `_view.setBuffer(buf); WatchUi.requestUpdate();`

The reader view from M2.4 stays around for now (we'll wire navigation in M6).
For M3, `wikiwatchApp.getInitialView()` returns the `KeyboardView` instead.

### Tests

- `KeyboardLayout.keys()` returns 22 letters + 4 specials in the expected order.
- `KeyboardLayout.keyAt(x, y, w, h)` returns `null` outside the grid, returns
  the correct key for several interior probe points.
- `InputBuffer.append("", "ש")` → `"ש"`; `append("ש", "ל")` → `"של"`.
- `InputBuffer.popLast("של")` → `"ש"`; `popLast("")` → `""`.
- `InputBuffer.clear("שלום")` → `""`.

Probably 10-12 new tests. R3 covers the views (pure render code — exempt) but
R2 needs a screenshot of the laid-out keyboard.

### Spike to do before M3

None. The keyboard is straightforward grid math; we already have chord geometry
from M0.1 if we need to inset the grid for the round bezel.

### Artifact

`versions/wikiwatch-M3.prg`.

---

## 5. M4 — ArticleStore + Manifest plumbing (`v0.M4`)

**Branch:** `m4-articlestore-manifest`. **PR title:** `M4: ArticleStore + Manifest plumbing with fixture data`.

### Scope

Stand up the storage layer the M5+ search uses, with fixture data. No
network, no download — that's M7.

- `source/storage/Manifest.mc` — wraps `Application.Storage` for the article
  manifest. Schema (Monkey C `Dictionary`):
  ```
  {
    :version => 1,
    :articles => [
      { :id => "...", :title => "...", :popularity => 0..100 },
      ...
    ]
  }
  ```
  - `load() as Dictionary` — reads `Storage.getValue("manifest")` and returns
    the parsed dict, or an empty default if absent.
  - `save(manifest as Dictionary) as Void` — gated on R4: must check
    `System.getSystemStats().freeMemory >= 3 * serialized_size`.
  - `articleIds() as Array<String>`.
  - `titleOf(id) as String?`.
- `source/storage/ArticleStore.mc` — wraps per-article storage.
  - `bodyOf(id) as String?` — reads `Storage.getValue("article:" + id)`.
  - `putBody(id, body as String) as Void` — R4-gated.
- `source/models/Fixtures.mc` — pure helper that returns the hardcoded fixture
  manifest and a few small Hebrew article bodies (use the M2.4 sample article
  as one of them).
- `wikiwatchApp.onStart` — if `Manifest.load()` returns the empty default,
  call `Fixtures.installIntoStorage()` (a single helper that writes the
  fixture manifest + bodies via the R4-guarded paths). First launch installs
  fixtures; subsequent launches skip.

### Tests

- `Manifest.load()` returns an empty default when storage is empty.
- `Manifest.save / load` roundtrip preserves the manifest dict.
- `Manifest.articleIds()` returns the IDs in the order they appear.
- `Manifest.titleOf("known-id")` returns the title; `titleOf("missing")` returns
  `null`.
- `ArticleStore.putBody / bodyOf` roundtrip with Hebrew text.
- `Fixtures` returns at least 3 articles with non-empty titles and bodies.

A few of these require the storage runtime — wrap them in `(:test)` and run
under `monkeydo /t` like always. The previous session's M1 storage round-trip
test (`strings_hebrewLiteralRoundtripsThroughStorage`) is the template.

### R4 / R5 considerations

Every `setValue` call must be preceded by a `freeMemory >= 3 * size` check.
The fixture bodies are small (~1 KB each), but the discipline matters now so
M7's download path inherits it. Document the helper:

```monkeyc
// Returns true if `bytes` can safely be allocated. R4/R5 guard.
private function _hasFreeMemory(bytes) {
    return System.getSystemStats().freeMemory >= bytes * 3;
}
```

### Artifact

`versions/wikiwatch-M4.prg`.

---

## 6. M5 — Live search (`v0.M5`)

**Branch:** `m5-live-search`. **PR title:** `M5: Live search prefix+substring+popularity, results list view`.

### Scope

The first end-to-end "watch app" experience. Typing in the M3 keyboard's
buffer filters articles live; tapping search shows a results list; tapping
a result opens the article in the M2.4 reader.

- `source/models/Search.mc` — pure ranking module:
  - `rank(query as String, articles as Array<Dictionary>) as Array<Dictionary>`
    where input articles have `{:id, :title, :popularity}`. Output is the
    same shape, sorted by:
    1. Articles whose title **starts with** the query (prefix matches).
    2. Articles whose title **contains** the query as a substring.
    3. Within each tier, descending by `:popularity`.
    4. Stable tiebreak by title.
  - Empty query returns top-K by popularity (use K=20).
- `KeyboardView` shows the top suggestion above the buffer:
  - Every key-tap recomputes `Search.rank(buf, Manifest.articleIds-resolved)`
    and updates the top-1 result.
  - **Performance check** — with ≤500 articles, recomputing rank on every
    keypress is fine. With 10 000 (post-M7), it'll need an index. M5 stays
    fixture-sized, so a linear scan is correct here.
- New view `source/views/ResultsView.mc`:
  - Lists ranked results (up to 20). Each row is the Hebrew title.
  - Tapping a row → push `ArticleView` (M2.4 reader, parameterized to take
    an article body string instead of `Strings.sampleArticle()`).
- `KeyboardDelegate.onSearch()` → `WatchUi.pushView(new ResultsView(rankedResults), ...)`.
- `ResultsDelegate.onSelect(article)` → `WatchUi.pushView(new ArticleView(article[:body]), ...)`.

### M2.4 reader becomes parameterized

Refactor `wikiwatchView` (the M2.4 reader) into `source/views/ArticleView.mc`
that takes the article text in its constructor instead of calling
`Strings.sampleArticle()`. The existing layout / wrap / scroll behavior is
unchanged. This refactor needs R3 coverage on the constructor wiring (one
new test that constructs an `ArticleView` and asserts a public method returns
something derived from the input).

### Tests

- `Search.rank("של", articles)` puts prefix matches first.
- Ties within prefix tier ordered by popularity (descending).
- Stable across calls (same input → same order).
- Empty query returns top-20 by popularity.
- No matches → empty array.
- Hebrew substring match works (`Search.rank("לום", [...])` finds "שלום").

Probably 8-10 tests.

### Artifact

`versions/wikiwatch-M5.prg`.

---

## 7. M6 — Long-press word, layer stack (`v0.M6`)

**Branch:** `m6-longpress-layers`. **PR title:** `M6: Long-press word push keyboard layer`.

### Spike required before implementation

**`onHold` for long-press inside a custom view** — listed as a pending spike
in `project_ladder.md`. Open `s6-onhold-spike` as a `Spike:` branch first.

What we need to confirm:
- Does `WatchUi.BehaviorDelegate.onHold(event)` fire on a touchscreen press-and-hold?
- What's the threshold? Is it configurable?
- Does it fire **once** at the threshold, or once + on every subsequent frame?
- Does `onDrag` still fire if `onHold` has been triggered?

A 1-day spike with diagnostic `System.println` per event should answer all
four. If `onHold` doesn't work as expected (e.g. fires only on physical
buttons), the fallback is to detect long-press in `onTap` via
`System.getTimer()` deltas — like the M2.5 double-tap, but the second event
is `onRelease` (or a synthesized timeout).

Document findings in `docs/spikes/s6-onhold.md`. **No code merge from a spike
branch** — close it after capturing the writeup.

### Scope (assuming `onHold` works)

- `source/models/WordHitTest.mc` — pure module. Given a list of laid-out
  lines (the `_lines` array from `ArticleView`) and a tap (x, y), returns
  the word under the tap or `null`. Algorithm: find the line whose y-range
  contains the tap, then split that line's text on spaces and walk widths.
  Hebrew-aware (use the per-line `:w` and `charW` already on hand).
- `ArticleDelegate.onHold(event)`:
  - `WordHitTest.findWord(_view.lines, x, y + _scrollY)` → word String or null.
  - If non-null, push a `KeyboardView` initialized with that word in the
    buffer. The keyboard is now a *new layer* on the view stack.
- The existing back behavior (Connect IQ back button) pops the layer.
  Drag-to-go-back is also worth confirming during the spike — depends on
  device profile.

### Layer stack

Connect IQ's `WatchUi.View` stack handles push/pop natively. The "layer stack"
language in the original spec just means: keyboard view on top of article
view on top of keyboard view on top of article view, all via `pushView` /
`popView`. No custom stack needed.

### Tests

- `WordHitTest.findWord` on a known laid-out line returns the expected word
  for a tap inside that word's pixel range.
- Returns `null` for taps in whitespace or off the line.
- Returns `null` for taps outside any line (above/below all `_lines`).

### Artifact

`versions/wikiwatch-M6.prg`.

---

## 8. M7 — Chunked download from `wikiwatch.tomhe.app/` (`v0.M7`)

**Branch:** `m7-chunked-download`. **PR title:** `M7: First-run chunked download resumable`.

### Server contract

Server at `wikiwatch.tomhe.app/` serves:
- `GET /manifest.json` — the article manifest (`{version, articles: [{id, title, popularity}], totalBytes}`).
- `GET /article/<id>.txt` — UTF-8 Hebrew Markdown body.

The user controls the server, so any minor server-side adjustments are on the
table — but propose them in the plan, don't change them without asking.

### Simulator caveat (from `garmin-ciq-simulator` skill)

The simulator's BLE-proxy network:
- Returns `RC=-400` for `Content-Type: application/octet-stream` responses.
  Use `text/plain; charset=utf-8` (or `application/json` for the manifest).
- Doesn't support POST. We're GET-only anyway.
- `RC=-200` immediately on URLs ≥ 4 KB. Keep URLs short.
- Real network behavior must be confirmed on the actual watch — the simulator
  may also report `RC=-300` (no network) consistently.

### Scope

- `source/net/Downloader.mc`:
  - `fetchManifest(callback)` — `Communications.makeWebRequest(...)` for
    `/manifest.json` with `:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON`.
    Callback `(rc, data)`; on rc==200 + dict, hand to `Manifest.save` (R4-gated).
  - `fetchArticle(id, callback)` — same idea, plain text response.
  - `installAll(progress)` — fetches manifest, then iterates article IDs,
    fetching one at a time (don't blast a swarm of concurrent requests),
    storing each via `ArticleStore.putBody` (R4-gated). Calls `progress(i, n)`
    on each completion.
- `source/views/InstallView.mc` — first-run progress UI: `"Loading wikiwatch:
  N / M articles"`. Visible until install finishes; then `WatchUi.switchToView`
  to `KeyboardView`.
- `wikiwatchApp.onStart` — if `Manifest.load().isEmpty()`, show `InstallView`
  + kick off `Downloader.installAll`. Otherwise skip directly to `KeyboardView`.

### Resumability

- The manifest is one atomic fetch — re-run from scratch if it fails.
- Per-article fetches check `ArticleStore.bodyOf(id) != null` *before*
  re-fetching. If a previous run got 1500 / 2000 articles done, the second
  run only fetches the missing 500.
- `Downloader.installAll` skips already-stored IDs and only counts remaining
  work in the progress total.

### R4 storage cap awareness

Total corpus must fit in ~9 MB (Storage cap on Venu 2, per `garmin-code` skill).
At M7 we don't know the actual corpus size — `Downloader.installAll` should:
- Check `freeMemory` before each `setValue` (R4).
- Check **estimated remaining bytes vs. available storage** after fetching
  the manifest — if `manifest.totalBytes > Storage.getStorageInfoMaxSize()`,
  abort with a friendly error in the install view. (Sizing is measured in
  M9.)

### Tests

Network code can't be unit-tested cleanly. R3 covers `source/models/`,
`source/state/`, `source/storage/`, `source/net/`. For `source/net/`, the
test target is the **shape of the data the Downloader passes to storage**
— mock-ish: stub `Communications.makeWebRequest` if possible, or write tests
against a pure parsing helper (`Downloader.parseManifestResponse(rc, data)`
→ `{ok, manifest}`).

Real network testing in the simulator may not work at all (`RC=-300` for
many endpoints). Plan to do an R2 sideload-to-watch test for the actual
download.

### Artifact

`versions/wikiwatch-M7.prg`.

---

## 9. M8 — Digits page on keyboard (`v0.M8`)

**Branch:** `m8-digits-page`. **PR title:** `M8: Digits page keyboard toggle`.

### Scope

Small UX increment on top of M3 / M5:
- New key on the bottom row: `123` toggle (or `123/אב` toggle if there's room).
- Tapping it swaps `KeyboardLayout.keys()` between the Hebrew letter set and
  a digits-and-punctuation set (`0..9`, `.`, `-`, plus the same backspace /
  delete-all / search / `אב`-toggle).
- Toggle state lives in `KeyboardView` (instance field `_mode`).
- Search ranking is unaffected — `Search.rank` already works on any UTF-8
  query string.

### Tests

- `KeyboardLayout.digitKeys()` returns the expected digit + punctuation set.
- `KeyboardLayout.keys(mode = :LETTERS)` returns the M3 letter set.
- `KeyboardLayout.keys(mode = :DIGITS)` returns the digit set.

### Artifact

`versions/wikiwatch-M8.prg`.

---

## 10. M9 — Polish + measure corpus size (`v0.M9`)

**Branch:** `m9-polish-measure`. **PR title:** `M9: Polish + corpus sizing decision`.

### Scope

This is where we actually pull the trigger on:
1. **Real corpus install on a real watch.** Sideload M7's `.prg`, let it
   fully install with the production article set from `wikiwatch.tomhe.app/`,
   and record:
   - Articles installed: N.
   - `Storage.getStorageInfoFreeSpace()` after install.
   - Average bytes per article.
2. **Decision on M10:** if free space < 1 MB OR the install hit storage cap
   before completing, M10 (static-dictionary compression) is required.
   Otherwise M10 is skipped.
3. Polish items that the user wants to land before claiming "v1.0":
   - Tighter font choices if any look wrong on the real watch.
   - Header tap targets (long-press inside an H1 — should it work? probably yes).
   - Settings screen (placeholder) for "clear local data" — useful for testing.
   - Any final layout adjustments after using the full corpus.

### Polish R2 evidence

Every polish change is a separate sub-PR (`fix/<slug>` → tag `v0.M9.<sub>`),
each with its own R2 evidence. Don't bundle.

### Artifact

`versions/wikiwatch-M9.prg`. Plus `docs/m9-corpus-measurement.md` capturing
the storage numbers and the M10 decision.

---

## 11. M10 (conditional) — Static-dictionary compression (`v0.M10`)

**Branch:** `m10-static-dict`. **PR title:** `M10: Static-dictionary compression`. **Only if M9 says so.**

### Scope

If the corpus doesn't fit in 9 MB, compress it server-side and decompress
on-watch:

- **Server-side**: pre-compute a static Huffman or LZSS dictionary from the
  full corpus. Compress every article body against it. Serve compressed
  bodies + the dictionary as `wikiwatch.tomhe.app/dict.bin` and
  `wikiwatch.tomhe.app/article/<id>.bin`.
- **Watch-side**: `source/net/Decompressor.mc` decompresses on read. Cache
  decoded bodies in memory only as long as the article is visible (don't
  store decompressed forms in `Storage`).

### Big risks here

- Decompression speed in pure Monkey C may be slow on Venu 2 hardware.
- Dictionary itself takes storage (~64-128 KB).

If M10 is needed, plan it carefully — it's the milestone most likely to need
a spike branch first (`s10-decompress-bench`).

### Artifact

`versions/wikiwatch-M10.prg`. (Conditional.)

---

## 12. Per-milestone command sequence

For every milestone (and every `Fix:` sub-version), run through this checklist.
It's lifted from `cr-tdd-ladder/SKILL.md` — that's the canonical version, but
keeping it here for fast reference.

```powershell
# 0. Start clean
git checkout main; git pull

# 1. New branch
git checkout -b mN-feature-slug          # or fix/<slug>

# 2. Write the test(s) first with a stub implementation
#    (function returns sentinel that ensures FAIL)
& scripts\test.ps1  *>&1 | Tee-Object docs\mN-fail.txt
#    -> expect non-zero exit; verify the FAIL lines are the new tests

# 3. Implement the change. Repeat until tests pass.
& scripts\test.ps1  *>&1 | Tee-Object docs\mN-pass.txt
#    -> expect exit 0, total = (prev + new)

# 4. Build
& scripts\build.ps1
#    -> expect "BUILD SUCCESSFUL", no new warnings

# 5. Sideload to simulator (manual or scripted) and capture R2 evidence
#    monkeydo stdout -> docs/mN-r2-evidence.txt
#    OR screenshot   -> docs/screenshots/mN-after.png

# 6. Commit + push
git add .
git commit -m "M<N>: <feature> — <one-line summary>"
git push -u origin mN-feature-slug

# 7. Open PR with the body template (R1 evidence + R2 evidence + a "Why" + a
#    "Files" section). PR title exact format `M<N>: <feature>` or `Fix: <short>`.
gh pr create --title "M<N>: <feature>" --body "$(cat <<'EOF'
## Why
<one paragraph>

## TDD evidence
### Failing run
```
<paste of docs/mN-fail.txt — just the relevant lines>
```

### Passing run
```
<paste of docs/mN-pass.txt summary>
```

## Simulator evidence
<screenshot link or paste of monkeydo stdout>

## Files changed
- <file>: <one-line change>
- ...
EOF
)"

# 8. Invoke the CR-ist
#    Use the Agent tool with subagent_type "crist" and a prompt of the PR number.
#    Expect either APPROVED or CHANGES REQUESTED with R<id> reasons.
#    Fix violations, re-push, re-invoke until APPROVED. (Note: each new commit
#    invalidates the previous approval via dismiss_stale_reviews=true.)

# 9. After approval, archive the .prg and merge
Copy-Item bin\wikiwatch.prg versions\wikiwatch-M<N>.prg
git add versions\wikiwatch-M<N>.prg
git commit -m "Archive wikiwatch-M<N>.prg"
git push
#    -> this commit invalidates the prior review; re-invoke CR-ist one more time
#    -> upon re-approval:
gh pr merge --merge --delete-branch        # LITERAL merge commit, not squash
git checkout main; git pull
git tag -a v0.M<N> -m "M<N>: <feature>"
git push --tags

# 10. Update memory + versions/README.md
#     Edit memory/project_ladder.md to flip status to "merged YYYY-MM-DD (tag v0.M<N>)".
#     Add the new row to versions/README.md's quick-reference table and a
#     per-version section below.
```

---

## 13. Working with the user

The user gives feedback fast. Patterns to expect:

- **Plan mode first.** For anything beyond a 1-line fix, enter plan mode and
  present a numbered, scoped plan. The user will respond with edits,
  rejections, or `yes go`.
- **Numbered feedback.** When testing M2.x, every round of feedback was
  4 numbered items (`1. ... 2. ... 3. ... 4. ...`). Match that structure
  in your plans so it's obvious which fix maps to which complaint.
- **One milestone at a time.** Even if the user lists 4 items, they may want
  them in separate hotfix sub-versions (M2.5.1, M2.5.2...) rather than one
  big bundle. Ask if it's ambiguous.
- **"Yes go" means start now.** Don't ask another clarifying question after
  you have explicit approval — execute.
- **Skill triggers.** When you reach for a skill, trust its content. If it
  contradicts what you'd do from training, the skill wins — it captures
  what was actually tested in this codebase.
- **Memory matters.** When something nontrivial happens (a new gotcha, a
  decided convention, a discovered API quirk), write it to a memory file.
  The next session inherits it.

---

## 14. Final notes

### Things that look obvious but aren't

- `monkeydo /t` not `-t`. Windows-style flag. Tripped the previous session
  for an hour at M0.
- The `developer_key` lives at `..\developer_key` (parent of the repo).
  Don't move it.
- `git tag -a` (annotated), not `git tag` (lightweight). The CR-ist enforces
  this.
- `gh pr merge --merge`, not `--squash` and not `--rebase`. Literal merge
  commit per the workflow.
- `(:test)` functions must be top-level functions, NOT methods of a class.
  Annotate before the function keyword.
- File-write errors (`EBADF: bad file descriptor`) on `.mc` files happen
  when the simulator has them mapped. Fall back to PowerShell
  `[System.IO.File]::WriteAllText($path, $content)`. Documented in the
  `garmin-ciq-simulator` skill.
- PowerShell `.Replace()` with multi-line content silently fails sometimes.
  Prefer rewriting whole files via the Write tool over targeted Replace
  calls.

### When in doubt

Read the skill. The previous session left detailed writeups of every quirk
they hit. Don't re-discover problems.

### What the user has explicitly said

- Tests-first, evidence-first. No "I'll add the test later".
- Mini-versions, never bundle. One R-rule violation kills the merge.
- The watchdog WILL trip on tight wrap loops. `text.toCharArray()` + integer
  indexing is the proven pattern.
- Hebrew is the source-of-truth language. Don't substitute English placeholders.
- Storage is precious (9 MB cap). Don't write throwaway data.
- The user can tell from a screenshot whether the layout is right. Don't
  argue UX — fix it.

Good luck. The ladder works. Walk it one rung at a time.
