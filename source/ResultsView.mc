import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M5.3 full-screen scrollable results view. Refactored from M5.1/M5.2:
//   - Round-screen aware: render-area = middle 70% of the screen + 40 px
//     L/R margins so titles never get clipped by the bezel.
//   - Multiline blocks: long titles wrap onto multiple sub-lines
//     (2 px intra-article gap, 16 px inter-article gap). Tapping any
//     sub-line opens the article (block-level dispatch via
//     ResultsLayout.blockAt).
//   - Font reduced to FONT_TINY (was FONT_SMALL) so long titles fit
//     with fewer sub-lines.
//   - "X more articles fit" footer (M5.2) preserved.
//
// State invariants:
//   _blocks   — populated lazily on first onUpdate (needs dc for per-word
//               pixel measurement). Each block = {:subs, :top, :height}.
//   _contentHeight — sum of block heights + inter-article gaps.
class ResultsView extends WatchUi.View {
    private const _ROW_FONT = Graphics.FONT_TINY;
    private const _TOP_PAD_PCT = 16;        // M5.4: 15->16
    private const _BOTTOM_PAD_PCT = 16;     // M5.4: 15->16
    private const _LEFT_MARGIN = 50;        // M5.4: 40->50
    private const _RIGHT_MARGIN = 50;       // M5.4: 40->50
    private const _SUB_LINE_GAP = 0;        // M5.4: 2->0 (line-touching for same article)
    private const _INTER_ARTICLE_GAP = 16;  // M5.3: between articles
    private const _FOOTER_HEIGHT = 30;      // "X more articles fit"
    private const _FOOTER_GAP = 6;

    private var _ranked as Array<Dictionary>;
    private var _totalMatches as Number;
    private var _scrollY as Number;
    private var _screenWidth as Number;
    private var _screenHeight as Number;
    private var _visibleTop as Number;
    private var _visibleHeight as Number;
    private var _blocks as Array<Dictionary>?;
    private var _contentHeight as Number;

    function initialize(ranked as Array<Dictionary>, totalMatches as Number) {
        View.initialize();
        _ranked = ranked;
        _totalMatches = totalMatches;
        _scrollY = 0;
        _screenWidth = 0;
        _screenHeight = 0;
        _visibleTop = 0;
        _visibleHeight = 0;
        _blocks = null;
        _contentHeight = 0;
    }

    function onUpdate(dc as Dc) as Void {
        _screenWidth = dc.getWidth();
        _screenHeight = dc.getHeight();
        _visibleTop = _screenHeight * _TOP_PAD_PCT / 100;
        var bottomPad = _screenHeight * _BOTTOM_PAD_PCT / 100;
        _visibleHeight = _screenHeight - _visibleTop - bottomPad;

        // Lazy layout: compute per-block wrap once dc is available.
        if (_blocks == null) {
            _layoutBlocks(dc);
        }

        // Background.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var rightX = _screenWidth - _RIGHT_MARGIN;
        var blocks = _blocks as Array<Dictionary>;
        var n = blocks.size();

        // Render visible sub-lines.
        var fh = dc.getFontHeight(_ROW_FONT);
        for (var i = 0; i < n; i++) {
            var b = blocks[i] as Dictionary;
            var top = b[:top] as Number;
            var height = b[:height] as Number;
            var screenTop = _visibleTop + top - _scrollY;
            // Skip-if-above / break-if-below.
            if (screenTop + height < _visibleTop) { continue; }
            if (screenTop >= _visibleTop + _visibleHeight) { break; }
            var subs = b[:subs] as Array<String>;
            for (var s = 0; s < subs.size(); s++) {
                var lineY = screenTop + s * (fh + _SUB_LINE_GAP) + fh / 2;
                // Skip sub-lines outside the visible band.
                if (lineY + fh / 2 < _visibleTop) { continue; }
                if (lineY - fh / 2 >= _visibleTop + _visibleHeight) { break; }
                dc.drawText(rightX, lineY, _ROW_FONT, subs[s] as String,
                            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // M5.2: "X more articles fit" footer (only when total > displayed).
        var footerText = ResultsLayout.moreArticlesText(_totalMatches, n);
        if (footerText != null) {
            // Footer sits after the last block in content space.
            var footerTop;
            if (n > 0) {
                var last = blocks[n - 1] as Dictionary;
                footerTop = (last[:top] as Number) + (last[:height] as Number) + _FOOTER_GAP;
            } else {
                footerTop = _FOOTER_GAP;
            }
            var footerScreenTop = _visibleTop + footerTop - _scrollY;
            if (footerScreenTop + _FOOTER_HEIGHT > _visibleTop
                    && footerScreenTop < _visibleTop + _visibleHeight) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_screenWidth / 2, footerScreenTop + _FOOTER_HEIGHT / 2,
                            Graphics.FONT_XTINY, footerText as String,
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // M9.6: low-memory warning — taps to open an article are refused (the
        // delegate gates on MemGuard) to avoid an uncatchable OOM.
        if (!MemGuard.canOpen(System.getSystemStats().freeMemory)) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_screenWidth / 2, _screenHeight - 26, Graphics.FONT_XTINY,
                        "max open articles",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function scrollBy(delta as Number) as Void {
        _scrollY = LayoutProgress.clampedScroll(_scrollY + delta, _contentHeight, _visibleHeight);
        WatchUi.requestUpdate();
    }

    // Returns the article dict at the tapped (x, y), or null. Variable-
    // height block dispatch via ResultsLayout.blockAt (pure, tested).
    // Taps outside the visible band or outside the L/R margins fall
    // through (null) so the user's tap on the bezel area is a no-op.
    function rowAt(x as Number, y as Number) as Dictionary? {
        if (_blocks == null) { return null; }
        if (y < _visibleTop || y >= _visibleTop + _visibleHeight) { return null; }
        if (x < _LEFT_MARGIN || x > _screenWidth - _RIGHT_MARGIN) { return null; }
        var contentY = (y - _visibleTop) + _scrollY;
        var idx = ResultsLayout.blockAt(contentY, _blocks as Array<Dictionary>);
        if (idx == null) { return null; }
        return _ranked[idx as Number] as Dictionary;
    }

    function getScreenHeight() as Number {
        return _screenHeight;
    }

    // Pre-compute the per-article block layout (each title wrapped onto
    // 1+ sub-lines via the M2.8 px-based wrap). Sub-lines of the same
    // article are tightly spaced (_SUB_LINE_GAP); inter-article gap
    // is larger (_INTER_ARTICLE_GAP).
    private function _layoutBlocks(dc as Dc) as Void {
        var usableWidth = _screenWidth - _LEFT_MARGIN - _RIGHT_MARGIN;
        var widthsPx = [usableWidth];
        var spacePx = dc.getTextWidthInPixels(" ", _ROW_FONT);
        var fh = dc.getFontHeight(_ROW_FONT);
        var blocks = [];
        var y = 0;
        for (var i = 0; i < _ranked.size(); i++) {
            var a = _ranked[i] as Dictionary;
            var title = a[:title] as String;
            var words = LineWrap.splitWords(title);
            var wordPx = [];
            for (var wi = 0; wi < words.size(); wi++) {
                wordPx.add(dc.getTextWidthInPixels(words[wi] as String, _ROW_FONT));
            }
            var subs = LineWrap.wrapPxToWidths(words, wordPx, spacePx, widthsPx, 0);
            var nSubs = subs.size();
            var blockH = nSubs * fh + (nSubs - 1) * _SUB_LINE_GAP;
            blocks.add({ :subs => subs, :top => y, :height => blockH });
            y = y + blockH + _INTER_ARTICLE_GAP;
        }
        // Strip the trailing inter-article gap (no following article).
        if (blocks.size() > 0) { y -= _INTER_ARTICLE_GAP; }
        _blocks = blocks;
        _contentHeight = y;
        // Add space for the footer (if it'll render).
        if (ResultsLayout.moreArticlesText(_totalMatches, blocks.size()) != null) {
            _contentHeight = _contentHeight + _FOOTER_GAP + _FOOTER_HEIGHT;
        }
    }
}
