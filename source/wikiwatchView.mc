import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M2.x article reader, refactored in M5.2 for lazy / progressive layout:
// the first onUpdate lays out a small batch of raw lines (~2 screens
// worth) so first paint is nearly instant, then a Timer wakes the view
// to lay out more batches in the background. Per-word pixel widths
// (dc.getTextWidthInPixels) can only be measured inside onUpdate where
// dc is valid, so the timer just calls WatchUi.requestUpdate() to
// trigger another onUpdate where the next batch can be measured + laid
// out. Scroll clamps to whatever's currently laid-out; a "..." marker
// at the bottom of the screen tells the user more content is loading.
//
// State invariants (held across onUpdate / timer ticks):
//   _rawLines        — for plain bodies: split once, never mutated. For a
//                      compressed STREAM (M10.2): GROWS as decodeTakeLines emits
//                      complete lines; only ever appended to.
//   _lines           — appended to incrementally per batch
//   _layoutCursor    — next raw-line index to lay out
//   _layoutY         — y-offset where the next sub-line will be placed
//   _contentHeight   — same as _layoutY at end of last batch
//   _layoutComplete  — true once decode is done (streaming) AND _layoutCursor
//                      reaches _rawLines.size()
//   _layoutTimer     — instance field per CIQ quirk (local Timer GC'd
//                      before fire); stopped + cleared in onHide
class wikiwatchView extends WatchUi.View {
    private const _RIGHT_MARGIN = 100;
    // M10.2: first paint is no longer a fixed raw-line count — it's a height
    // target (~2 screens) bounded by _FIRST_PAINT_SUBLINE_BUDGET below. The old
    // _INITIAL_LINES=2 (M5.4) is gone; see the height-target loop in onUpdate.
    //
    // M8.3: background incremental batch is 48 raw lines/tick. M5.4 kept this tiny
    // for first-paint parity, but that made FULL layout of long articles slow (the
    // 50 ms/tick floor dominates). 48 lines of per-word px measurement is well
    // under one frame, so no UI hitch; the background fill finishes in ~3-4 ticks.
    private const _INCREMENTAL_LINES = 48;
    private const _LAYOUT_TICK_MS = 50;      // CIQ minimum

    // M10.2 streaming decode (compressed articles). The reader holds the decode
    // state + model and decodes more tokens on demand inside the lazy-layout loop,
    // so text paints after the first ~2 screens decode instead of the whole body.
    // CRITICAL (watchdog): decode AND layout run in the SAME onUpdate handler, so
    // their per-tick budgets must be small enough that their SUM stays under the
    // watchdog. DecodeView's old decode-ONLY budget was 250 tokens/tick; combined
    // with layout that trips, so decode here is a smaller slice. _DECODE_LOOKAHEAD
    // keeps ~this many raw lines decoded ahead of the layout cursor.
    private const _DECODE_TOKENS_PER_TICK = 150;
    private const _DECODE_LOOKAHEAD = 64;
    // First paint decodes a couple of slices (still well under the ~400-token
    // per-handler watchdog ceiling — 500 trips) so ~2 screens of raw lines exist
    // for the first render, instead of the single-slice ~1 screen.
    private const _FIRST_PAINT_DECODE_TOKENS = 300;
    // Cap the per-tick wrapped sub-line layout work so a single dense paragraph
    // (worst case id 1143) plus a decode slice can't exceed the watchdog budget in
    // one handler. First paint fills toward ~2 screens but stops at this cap; the
    // "..." marker shows and the next 50 ms tick continues.
    private const _FIRST_PAINT_SUBLINE_BUDGET = 34;

    private var _body as String;
    private var _rawLines as Array<String>?;
    private var _lines as Array<Dictionary>?;
    private var _layoutCursor as Number;
    private var _layoutY as Number;
    private var _layoutComplete as Boolean;
    private var _layoutTimer as Timer.Timer?;
    private var _scrollY as Number;
    private var _contentHeight as Number;
    private var _screenHeight as Number;
    private var _leftMargin as Number;
    private var _middleWidth as Number;
    private var _ctorTimeMs as Number;       // M5.3: first-paint timing
    private var _firstPaintLogged as Boolean;
    private var _screenWidth as Number;      // M6: cached for findWordAt
    // M6.5: pending long-press hit, resolved in next onUpdate (which has dc).
    // Replaces the M6 / M6.1 findWordAt + per-sub-line :words/:wordPx
    // storage. -1 sentinel = no pending hit.
    private var _pendingHitX as Number;
    private var _pendingHitY as Number;
    // M8.3: laid-out-article cache. _cacheKey identifies the article (its id);
    // if ArticleLayoutCache has a matching entry, re-open restores the
    // pixel-wrapped lines instantly instead of re-laying-out. _storedToCache
    // guards a one-time write when this view's own layout completes.
    private var _cacheKey as String;
    private var _storedToCache as Boolean;
    // M10.2 streaming-decode state. _streaming=false (default) keeps the plain /
    // cached-layout path byte-identical. _decodeDone starts true so non-streaming
    // mode's _layoutComplete test (which now ANDs _decodeDone) is unchanged.
    private var _streaming as Boolean;
    private var _decodeState as Dictionary?;
    private var _model as Dictionary?;
    private var _decodeDone as Boolean;

    function initialize(body as String, cacheKey as String) {
        View.initialize();
        _body = body;
        _cacheKey = cacheKey;
        _storedToCache = false;
        _rawLines = null;
        _lines = null;
        _layoutCursor = 0;
        _layoutY = 8;
        _layoutComplete = false;
        _layoutTimer = null;
        _scrollY = 0;
        _contentHeight = 0;
        _screenHeight = 0;
        _leftMargin = 15;
        _middleWidth = 0;
        _ctorTimeMs = System.getTimer();
        _firstPaintLogged = false;
        _screenWidth = 0;
        _pendingHitX = -1;
        _pendingHitY = -1;
        _streaming = false;
        _decodeState = null;
        _model = null;
        _decodeDone = true;
    }

    // M10.2: enter streaming-decode mode for a compressed article. Called right
    // after construction (with an empty body) by ArticleOpener / the DecodeView
    // parse gate. The reader decodes `blob` against the already-parsed `model`
    // incrementally inside its lazy-layout loop, growing _rawLines as complete
    // lines become available. _rawLines / _lines are initialised on the first
    // onUpdate (where dc — needed for _middleWidth — is valid).
    function startStreaming(blob as ByteArray, model as Dictionary) as Void {
        _streaming = true;
        _decodeState = Decompressor.decodeStart(blob);
        _model = model;
        _decodeDone = false;
    }

    // M6.5: delegate calls this on long-press. We can't measure word widths
    // without a live dc, so we just save the tap coords + requestUpdate.
    // The next onUpdate runs _resolvePendingHit which measures + pushes
    // the new keyboard layer.
    function requestLongPressHit(x as Number, y as Number) as Void {
        _pendingHitX = x;
        _pendingHitY = y;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        _screenHeight = dc.getHeight();
        _screenWidth = dc.getWidth();

        // Lazy init on first onUpdate (we need dc to compute middleWidth).
        if (_lines == null) {
            _middleWidth = Layout.middleWidth(dc.getWidth(), _leftMargin, _RIGHT_MARGIN);
            if (_streaming) {
                // M10.2: compressed stream — raw lines arrive from the decoder.
                _rawLines = [];
                _lines = [];
            } else {
                // M8.3: instant re-open — if this article's layout is cached, adopt
                // it whole and skip the lazy-load entirely.
                var cached = (_cacheKey.length() > 0) ? ArticleLayoutCache.get(_cacheKey) : null;
                if (cached != null) {
                    _lines = cached[:lines] as Array<Dictionary>;
                    _contentHeight = cached[:contentHeight] as Number;
                    _layoutComplete = true;
                    _storedToCache = true;   // already in cache
                    System.println("M8.3 cache HIT key=" + _cacheKey + " lines="
                        + (_lines as Array).size());
                } else {
                    _rawLines = Decompressor.splitLines(_body);
                    _lines = [];
                }
            }
        }

        // M10.2: streaming decode pump — decode ONE bounded slice to top up
        // _rawLines before laying out, when the layout cursor is nearing the
        // decoded tail (or on the very first pass). BOTH this decode and the layout
        // below are bounded per handler so a single tick can't trip the watchdog
        // (verified on id 1143). The first ~2 screens fill over the first few ticks
        // rather than one big handler.
        if (_streaming && !_decodeDone
                && (_layoutCursor == 0
                    || StreamProgress.needMoreRawLines(_layoutCursor,
                            (_rawLines as Array).size(), _DECODE_LOOKAHEAD))) {
            // First pass decodes up to _FIRST_PAINT_DECODE_TOKENS (a couple of
            // slices) for a ~2-screen first paint; background ticks decode ONE
            // slice. Slice count stays under the per-handler watchdog ceiling.
            var tokenCap = (_layoutCursor == 0) ? _FIRST_PAINT_DECODE_TOKENS : _DECODE_TOKENS_PER_TICK;
            var decoded = 0;
            while (!_decodeDone && decoded < tokenCap) {
                _decodeDone = Decompressor.decodeStep(_decodeState as Dictionary,
                    _model as Dictionary, _DECODE_TOKENS_PER_TICK);
                var newLines = Decompressor.decodeTakeLines(_decodeState as Dictionary, _decodeDone);
                if (newLines.size() > 0) { (_rawLines as Array<String>).addAll(newLines); }
                decoded += _DECODE_TOKENS_PER_TICK;
            }
        }

        // Lay out the next batch. Skipped when the layout came from cache
        // (_rawLines stays null).
        if (_rawLines != null && !_layoutComplete) {
            var totalRaw = (_rawLines as Array<String>).size();
            var firstPass = (_layoutCursor == 0);
            if (firstPass) {
                // M10.2: height-target first paint — lay out raw lines one at a
                // time until ~2 screens are filled, or the per-tick sub-line budget
                // caps us (dense paragraph / watchdog guard). The "..." marker +
                // next tick continue the fill. Replaces the old fixed 2-line batch.
                while (_layoutCursor < totalRaw
                        && StreamProgress.firstPaintShouldContinue(_layoutY, _screenHeight,
                                (_lines as Array).size(), _FIRST_PAINT_SUBLINE_BUDGET)) {
                    _layoutBatchRange(dc, _layoutCursor, _layoutCursor + 1);
                    _layoutCursor += 1;
                }
            } else {
                var newCursor = LayoutProgress.nextBatchEnd(_layoutCursor, totalRaw, _INCREMENTAL_LINES);
                if (newCursor > _layoutCursor) {
                    _layoutBatchRange(dc, _layoutCursor, newCursor);
                    _layoutCursor = newCursor;
                }
            }
            // M10.2: complete means BOTH decode finished AND all raw lines laid out
            // (non-streaming keeps _decodeDone=true, so this is the old test).
            _layoutComplete = _decodeDone && LayoutProgress.isComplete(_layoutCursor, totalRaw);
        }

        // M8.3: cache the finished layout for instant re-open next time.
        if (_layoutComplete && !_storedToCache && _cacheKey.length() > 0) {
            ArticleLayoutCache.put(_cacheKey, _lines as Array, _contentHeight);
            _storedToCache = true;
            System.println("M8.3 full-layout: ms=" + (System.getTimer() - _ctorTimeMs)
                + " lines=" + (_lines as Array).size() + " key=" + _cacheKey);
        }

        _renderVisibleLines(dc);

        // M6.5: resolve a pending long-press now that dc is in hand.
        if (_pendingHitX >= 0) {
            _resolvePendingHit(dc);
        }

        // Loading marker + schedule next tick while incremental layout has work.
        if (!_layoutComplete) {
            _drawLoadingMarker(dc);
            _scheduleNextTick();
        }

        // M5.3: log first-paint wall-clock time (constructor -> first render
        // returning). M10.2: also log sublines / contentH / screenH so the
        // watchdog gate can assert the first paint now covers ~2 screens, and (for
        // streaming) the decode progress so it can assert text rendered BEFORE the
        // full decode finished (tokensDone < tokenCount).
        if (!_firstPaintLogged) {
            _firstPaintLogged = true;
            var elapsed = System.getTimer() - _ctorTimeMs;
            // First laid-out sub-line (streaming has no _body); else body prefix.
            var hint;
            if ((_lines as Array).size() > 0) {
                hint = ((_lines as Array<Dictionary>)[0] as Dictionary)[:text] as String;
            } else {
                hint = _body;
            }
            if (hint.length() > 24) { hint = hint.substring(0, 24); }
            System.println("M5.3 first-paint: ms=" + elapsed
                + " sublines=" + (_lines as Array).size()
                + " contentH=" + _contentHeight + " screenH=" + _screenHeight
                + " hint='" + hint + "'");
            if (_streaming && _decodeState != null) {
                System.println("M10.2 stream first-paint: tokensDone="
                    + Decompressor.decodeTokensDone(_decodeState as Dictionary)
                    + " tokenCount=" + Decompressor.decodeTokenCount(_decodeState as Dictionary));
            }
        }

        // M9.6: low-memory warning — long-press to open the search keyboard is
        // refused (see _resolvePendingHit) to avoid an uncatchable OOM.
        if (!MemGuard.canOpen(System.getSystemStats().freeMemory)) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            // M9.7: 10 px higher than M9.6 (was screenH-22).
            dc.drawText(_screenWidth / 2, _screenHeight - 32, Graphics.FONT_XTINY,
                        "max open articles",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Wake-up callback: re-enter onUpdate where dc is valid for the next batch.
    function onLayoutTimer() as Void {
        _layoutTimer = null;
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        if (_layoutTimer != null) {
            (_layoutTimer as Timer.Timer).stop();
            _layoutTimer = null;
        }
        View.onHide();
    }

    function scrollBy(delta as Number) as Void {
        _scrollY = LayoutProgress.clampedScroll(_scrollY + delta, _contentHeight, _screenHeight);
        WatchUi.requestUpdate();
    }

    function scrollToTop() as Void {
        _scrollY = 0;
        WatchUi.requestUpdate();
    }

    function scrollToBottom() as Void {
        _scrollY = LayoutProgress.clampedScroll(_contentHeight, _contentHeight, _screenHeight);
        WatchUi.requestUpdate();
    }

    function getScreenHeight() as Number {
        return _screenHeight;
    }

    // M5.4: exposed so the delegate can gate behavior that doesn't make sense
    // mid-load (e.g. double-tap-to-bottom — there's no fully-laid-out bottom
    // yet). Returns false until the lazy layout has consumed all raw lines.
    function isLayoutComplete() as Boolean {
        return _layoutComplete;
    }

    // M6.5: resolve a pending long-press tap. Called from onUpdate where
    // dc is valid. Locates the sub-line under (contentY = y + _scrollY),
    // measures THAT sub-line's words on the fly, runs WordHitTest, and
    // pushes a new keyboard layer if a word was hit. Replaces the M6 /
    // M6.1 findWordAt + per-sub-line :words/:wordPx storage (which kept
    // ~6.5 KB resident on shalom-sized articles). Peak transient memory
    // here is ~130 B (one sub-line's worth) — discarded as soon as the
    // method returns.
    private function _resolvePendingHit(dc as Dc) as Void {
        var x = _pendingHitX;
        var y = _pendingHitY;
        _pendingHitX = -1;
        _pendingHitY = -1;
        if (_lines == null) { return; }
        var contentY = y + _scrollY;
        var lines = _lines as Array<Dictionary>;
        for (var i = 0; i < lines.size(); i++) {
            var ln = lines[i] as Dictionary;
            var top = ln[:y] as Number;
            var height = ln[:h] as Number;
            if (contentY < top || contentY >= top + height) { continue; }
            // Measure THIS sub-line's words on demand.
            var subText = ln[:text] as String;
            var font = ln[:font] as Graphics.FontType;
            var words = LineWrap.splitWords(subText);
            if (words.size() == 0) { return; }
            var wordPx = [];
            for (var wi = 0; wi < words.size(); wi++) {
                wordPx.add(dc.getTextWidthInPixels(words[wi] as String, font));
            }
            var spacePx = dc.getTextWidthInPixels(" ", font);
            // Compute this line's exact right edge based on its justify
            // mode (mirrors _renderVisibleLines).
            var w = ln[:w] as Number;
            var isH1 = ln[:isH1] as Boolean;
            var lineRightX;
            if (isH1 || w < _middleWidth) {
                var centerX = _screenWidth / 2;
                var nWords = words.size();
                var textPx = 0;
                for (var twi = 0; twi < nWords; twi++) {
                    textPx = textPx + (wordPx[twi] as Number);
                }
                if (nWords > 1) {
                    textPx = textPx + (nWords - 1) * spacePx;
                }
                lineRightX = centerX + textPx / 2;
            } else {
                lineRightX = _screenWidth - _RIGHT_MARGIN;
            }
            var word = WordHitTest.findWordPx(x, words, wordPx, lineRightX, spacePx);
            if (word != null) {
                // M9.7: strip punctuation etc. so the search bar gets a clean query.
                word = WordSanitize.searchable(word as String);
                // M9.6: refuse the long-press when free heap is low — pushing a
                // keyboard layer (which holds the shared index) on top of the
                // resident reader could OOM uncatchably. Show the yellow notice.
                if (!MemGuard.canOpen(System.getSystemStats().freeMemory)) {
                    System.println("M9.6: long-press blocked (low memory)");
                    WatchUi.requestUpdate();   // reader render shows the yellow notice
                    return;
                }
                System.println("M6 onHold(lazy): word='" + word + "' — pushing keyboard layer");
                var kbView = new wikiwatchKeyboardView();
                var kbDelegate = new wikiwatchKeyboardDelegate(kbView, word as String);
                WatchUi.pushView(kbView, kbDelegate, WatchUi.SLIDE_LEFT);
            } else {
                System.println("M6 onHold(lazy): no word at tap");
            }
            return;
        }
        System.println("M6 onHold(lazy): no sub-line under tap");
    }

    private function _scheduleNextTick() as Void {
        if (_layoutTimer != null) { return; }
        _layoutTimer = new Timer.Timer();
        (_layoutTimer as Timer.Timer).start(method(:onLayoutTimer), _LAYOUT_TICK_MS, false);
    }

    // Lay out raw lines in [startIdx, endIdx). Uses dc.getTextWidthInPixels
    // for per-word px measurement (M2.8 px-based wrap). Appends sub-line
    // dicts to _lines and advances _layoutY / _contentHeight.
    //
    // The "narrow tail" branch only fires when this batch reaches the
    // ABSOLUTE last raw line — which means the bottom paragraph keeps its
    // 250 / 160 px taper regardless of how the layout was batched.
    private function _layoutBatchRange(dc as Dc, startIdx as Number, endIdx as Number) as Void {
        var rawLines = _rawLines as Array<String>;
        var lines = _lines as Array<Dictionary>;
        var totalRaw = rawLines.size();
        var y = _layoutY;
        var spacing = 4;
        var sectionGap = 4;
        var narrowEdge = 160;
        var narrowSecond = 250;
        var firstWidths = [narrowEdge, narrowSecond, _middleWidth];
        var middleOnly = [_middleWidth];

        for (var i = startIdx; i < endIdx; i++) {
            var token = MarkdownTokens.parse(rawLines[i] as String);
            var font = _fontForLevel(token[:level] as Number);
            var fh = dc.getFontHeight(font);
            var text = token[:text] as String;
            var words = LineWrap.splitWords(text);
            var wordPx = [];
            for (var wi = 0; wi < words.size(); wi++) {
                wordPx.add(dc.getTextWidthInPixels(words[wi] as String, font));
            }
            var spacePx = dc.getTextWidthInPixels(" ", font);

            var subs;
            var perSubWidth = null;
            var widthsUsed;
            var isH1 = (i == 0);
            if (i == 0) {
                subs = LineWrap.wrapPxToWidths(words, wordPx, spacePx, firstWidths, 0);
                widthsUsed = firstWidths;
            } else if (i == totalRaw - 1 && (!_streaming || _decodeDone)) {
                // M10.2: only the GENUINE last line gets the narrow tail. While a
                // compressed body is still streaming, _rawLines is growing, so a
                // mid-stream line transiently at totalRaw-1 must NOT be tapered
                // (it would be permanently mis-wrapped). Apply the tail only once
                // decode is done (or for non-streaming bodies).
                subs = LineWrap.wrapPxWithNarrowTail(words, wordPx, spacePx, _middleWidth, narrowSecond, narrowEdge);
                perSubWidth = [];
                var sCount = subs.size();
                for (var k = 0; k < sCount; k++) {
                    if (k == sCount - 1) {
                        (perSubWidth as Array<Number>).add(narrowEdge);
                    } else if (k == sCount - 2) {
                        (perSubWidth as Array<Number>).add(narrowSecond);
                    } else {
                        (perSubWidth as Array<Number>).add(_middleWidth);
                    }
                }
                widthsUsed = middleOnly;
            } else {
                subs = LineWrap.wrapPxToWidths(words, wordPx, spacePx, middleOnly, 0);
                widthsUsed = middleOnly;
            }
            for (var j = 0; j < subs.size(); j++) {
                var w;
                if (perSubWidth != null) {
                    w = (perSubWidth as Array<Number>)[j];
                } else if (j < widthsUsed.size()) {
                    w = widthsUsed[j];
                } else {
                    w = widthsUsed[widthsUsed.size() - 1];
                }
                // M6.5: per-sub-line :words / :wordPx / :spacePx storage
                // (added in M6.1 for pixel-accurate findWordAt) was a heap
                // hog — ~6.5 KB resident for shalom-sized articles.
                // Dropped here. Long-press hit-test now measures words
                // lazily in _resolvePendingHit (during onUpdate where dc
                // is valid), so we keep only the sub-line :text and
                // recompute words/widths only for the ONE sub-line under
                // the tap. Peak transient ~130 B vs ~6.5 KB resident.
                var subText = subs[j] as String;
                lines.add({
                    :text => subText,
                    :font => font,
                    :y => y,
                    :h => fh,
                    :w => w,
                    :isH1 => isH1
                });
                y += fh + spacing;
            }
            y += sectionGap;
        }
        _layoutY = y;
        _contentHeight = y;
    }

    private function _renderVisibleLines(dc as Dc) as Void {
        var screenW = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var centerX = screenW / 2;
        var rightAnchorX = screenW - _RIGHT_MARGIN;

        var lines = _lines as Array<Dictionary>;
        var n = lines.size();
        // M2.4 skip-ahead.
        var i = 0;
        while (i < n) {
            var ln = lines[i] as Dictionary;
            var lh = ln[:h] as Number;
            var screenY = (ln[:y] as Number) - _scrollY;
            if (screenY + lh > 0) { break; }
            i++;
        }
        // M2.4 early-exit on first off-bottom line.
        while (i < n) {
            var ln = lines[i] as Dictionary;
            var screenY = (ln[:y] as Number) - _scrollY;
            if (screenY >= _screenHeight) { break; }
            var w = ln[:w] as Number;
            if (ln[:isH1] as Boolean) {
                dc.drawText(centerX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_CENTER);
            } else if (w < _middleWidth) {
                dc.drawText(centerX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(rightAnchorX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_RIGHT);
            }
            i++;
        }
    }

    // "..." marker drawn at the bottom of the screen while incremental
    // layout still has work. Disappears once _layoutComplete is true.
    private function _drawLoadingMarker(dc as Dc) as Void {
        var screenW = dc.getWidth();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW / 2, _screenHeight - 18, Graphics.FONT_XTINY, "...",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _fontForLevel(level as Number) as Graphics.FontType {
        if (level == 1) { return Graphics.FONT_MEDIUM; }
        if (level == 2) { return Graphics.FONT_SMALL; }
        if (level == 3) { return Graphics.FONT_TINY; }
        if (level == 4) { return Graphics.FONT_XTINY; }
        return Graphics.FONT_XTINY;
    }

}
