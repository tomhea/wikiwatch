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
//   _rawLines        — parsed once, never mutated
//   _lines           — appended to incrementally per batch
//   _layoutCursor    — next raw-line index to lay out
//   _layoutY         — y-offset where the next sub-line will be placed
//   _contentHeight   — same as _layoutY at end of last batch
//   _layoutComplete  — true once _layoutCursor reaches _rawLines.size()
//   _layoutTimer     — instance field per CIQ quirk (local Timer GC'd
//                      before fire); stopped + cleared in onHide
class wikiwatchView extends WatchUi.View {
    private const _RIGHT_MARGIN = 100;
    // M5.4: tightened further — _INITIAL_LINES 5->2 so first paint is
    // essentially the H1 + first body line only (~20 dc.getTextWidthInPixels
    // calls). _INCREMENTAL_LINES 4->2 for finer-grained ticks.
    // _LAYOUT_TICK_MS 80->50 (CIQ minimum) so subsequent batches arrive as
    // fast as the platform allows.
    private const _INITIAL_LINES = 2;
    private const _INCREMENTAL_LINES = 2;
    private const _LAYOUT_TICK_MS = 50;      // CIQ minimum

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

    function initialize(body as String) {
        View.initialize();
        _body = body;
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
    }

    function onUpdate(dc as Dc) as Void {
        // Lazy init on first onUpdate (we need dc to compute middleWidth).
        if (_rawLines == null) {
            _rawLines = _splitLines(_body);
            _lines = [];
            _middleWidth = Layout.middleWidth(dc.getWidth(), _leftMargin, _RIGHT_MARGIN);
        }
        _screenHeight = dc.getHeight();
        _screenWidth = dc.getWidth();

        // Lay out the next batch (firstPass gets the bigger initial budget).
        var totalRaw = (_rawLines as Array<String>).size();
        var firstPass = (_layoutCursor == 0);
        var batch = firstPass ? _INITIAL_LINES : _INCREMENTAL_LINES;
        var newCursor = LayoutProgress.nextBatchEnd(_layoutCursor, totalRaw, batch);
        if (newCursor > _layoutCursor) {
            _layoutBatchRange(dc, _layoutCursor, newCursor);
            _layoutCursor = newCursor;
        }
        _layoutComplete = LayoutProgress.isComplete(_layoutCursor, totalRaw);

        _renderVisibleLines(dc);

        // Loading marker + schedule next tick while incremental layout has work.
        if (!_layoutComplete) {
            _drawLoadingMarker(dc);
            _scheduleNextTick();
        }

        // M5.3: log first-paint wall-clock time (constructor -> first render
        // returning). Used to verify the bounded-first-batch invariant
        // perceptually matches: e.g. שבת and שלום should be within ~30 ms.
        if (!_firstPaintLogged) {
            _firstPaintLogged = true;
            var elapsed = System.getTimer() - _ctorTimeMs;
            // Body's first ~24 chars (typically the H1 line incl. "# ").
            var hint = (_body.length() > 24) ? _body.substring(0, 24) : _body;
            System.println("M5.3 first-paint: ms=" + elapsed + " hint='" + hint + "'");
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

    // M6: long-press hit-test. Given a screen (x, y), returns the word at
    // that point or null. Used by wikiwatchDelegate.onHold to push a new
    // keyboard layer pre-filled with the tapped word. Returns null if the
    // tap is outside any laid-out line, outside the line's text, or if
    // _lines hasn't been initialized yet (e.g. first onUpdate hasn't run).
    //
    // M6.1: pixel-accurate. Uses the per-word px widths stored in each
    // line dict (:words / :wordPx / :spacePx) via the new pure
    // WordHitTest.findWordPx — fixes the M6 char-count off-by-one and
    // left-side dead zone.
    function findWordAt(x as Number, y as Number) as String? {
        if (_lines == null) { return null; }
        var contentY = y + _scrollY;
        var lines = _lines as Array<Dictionary>;
        for (var i = 0; i < lines.size(); i++) {
            var ln = lines[i] as Dictionary;
            var top = ln[:y] as Number;
            var height = ln[:h] as Number;
            if (contentY < top || contentY >= top + height) { continue; }
            // Pull pre-measured per-word px from the line dict.
            var words = ln[:words] as Array<String>;
            var wordPx = ln[:wordPx] as Array<Number>;
            var spacePx = ln[:spacePx] as Number;
            if (words == null || words.size() == 0) { return null; }
            // Compute this line's exact right edge based on its justify
            // mode (mirrors _renderVisibleLines). Use sum(wordPx) +
            // (n-1)*spacePx for the EXACT rendered text width — replaces
            // M6's char-count estimate (text.length() * charPx) that
            // caused the off-by-one + left-side bugs.
            var w = ln[:w] as Number;
            var isH1 = ln[:isH1] as Boolean;
            var lineRightX;
            if (isH1 || w < _middleWidth) {
                // Centered at screenW/2.
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
                // Right-justified at screenW - _RIGHT_MARGIN.
                lineRightX = _screenWidth - _RIGHT_MARGIN;
            }
            return WordHitTest.findWordPx(x, words, wordPx, lineRightX, spacePx);
        }
        return null;
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
            } else if (i == totalRaw - 1) {
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
                // M6.1: also measure per-word px for the SUB-LINE's words
                // so findWordAt → WordHitTest.findWordPx can do pixel-
                // accurate hit-test. Re-split the sub-line text (which
                // is a join of N of the original words via wrapPx*) and
                // measure each — straightforward since dc is in hand.
                var subText = subs[j] as String;
                var subWords = LineWrap.splitWords(subText);
                var subWordPx = [];
                for (var swi = 0; swi < subWords.size(); swi++) {
                    subWordPx.add(dc.getTextWidthInPixels(subWords[swi] as String, font));
                }
                lines.add({
                    :text => subText,
                    :font => font,
                    :y => y,
                    :h => fh,
                    :w => w,
                    :isH1 => isH1,
                    :words => subWords,
                    :wordPx => subWordPx,
                    :spacePx => spacePx
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

    private function _splitLines(text as String) as Array<String> {
        var lines = [];
        var start = 0;
        var len = text.length();
        while (start <= len) {
            var rest = text.substring(start, len);
            var nl = rest.find("\n");
            if (nl == null) {
                lines.add(rest);
                start = len + 1;
            } else {
                lines.add(rest.substring(0, nl));
                start = start + nl + 1;
            }
        }
        return lines;
    }
}
