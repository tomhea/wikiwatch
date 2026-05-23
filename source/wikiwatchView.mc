import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchView extends WatchUi.View {
    private var _scrollY as Number;
    private var _lines as Array?;
    private var _contentHeight as Number;
    private var _screenHeight as Number;
    private var _leftMargin as Number;
    private var _middleWidth as Number;

    function initialize() {
        View.initialize();
        _scrollY = 0;
        _lines = null;
        _contentHeight = 0;
        _screenHeight = 0;
        _leftMargin = 15;
        _middleWidth = 0;
    }

    function onUpdate(dc as Dc) as Void {
        if (_lines == null) {
            _layout(dc);
        }
        _screenHeight = dc.getHeight();
        var screenW = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var centerX = screenW / 2;
        var r = _screenHeight / 2;

        var lines = _lines as Array<Dictionary>;
        var n = lines.size();
        // Skip ahead to the first line whose bottom edge is in view.
        var i = 0;
        while (i < n) {
            var ln = lines[i] as Dictionary;
            var lh = ln[:h] as Number;
            var screenY = (ln[:y] as Number) - _scrollY;
            if (screenY + lh > 0) { break; }
            i++;
        }
        // Draw until past the bottom of the viewport. Early-exit on the
        // first line below the viewport - the lines array is monotonically
        // ordered by y, so anything after is also below the viewport.
        while (i < n) {
            var ln = lines[i] as Dictionary;
            var screenY = (ln[:y] as Number) - _scrollY;
            if (screenY >= _screenHeight) { break; }
            if (ln[:isH1] as Boolean) {
                dc.drawText(centerX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                var anchorX = centerX - SafeArea.safeChordHalfWidth(r, screenY - r);
                if (anchorX < _leftMargin) { anchorX = _leftMargin; }
                dc.drawText(anchorX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_LEFT);
            }
            i++;
        }
    }

    function scrollBy(delta as Number) as Void {
        _scrollY += delta;
        var maxScroll = _contentHeight - _screenHeight;
        if (maxScroll < 0) { maxScroll = 0; }
        if (_scrollY < 0) { _scrollY = 0; }
        if (_scrollY > maxScroll) { _scrollY = maxScroll; }
        WatchUi.requestUpdate();
    }

    function scrollToTop() as Void {
        _scrollY = 0;
        WatchUi.requestUpdate();
    }

    function scrollToBottom() as Void {
        var maxScroll = _contentHeight - _screenHeight;
        if (maxScroll < 0) { maxScroll = 0; }
        _scrollY = maxScroll;
        WatchUi.requestUpdate();
    }

    function getScreenHeight() as Number {
        return _screenHeight;
    }

    // M2.5 layout. Per-raw strategy:
    //   firstRaw (H1) -> widths [narrowEdge, narrowSecond, middleWidth, ...]
    //                    every sub-line tagged :isH1 => true
    //   middleRaws    -> widths [middleWidth] (full screen width + right bleed)
    //   lastRaw       -> LineWrap.wrapWithNarrowTail(...) with narrowSecond=300
    //                    so the absolute LAST sub-line is at 160 px and the
    //                    PENULTIMATE at 300 px.
    //
    // Justify (in onUpdate):
    //   :isH1 sub-line  -> CENTER at screenW/2 (every H1 sub-line, regardless
    //                      of width)
    //   non-H1 sub-line -> LEFT-justify, anchored at max(chord_left_at(y),
    //                      _leftMargin). In the middle band the chord is
    //                      wider than the screen so the anchor falls back to
    //                      _leftMargin (clean 15 px gap on the left). In the
    //                      narrow chord zones the anchor moves inward to the
    //                      chord's left edge so the text stays inside the
    //                      round bezel.
    //
    // Margins: _leftMargin = 15 (clean left), _rightBleed = 20 (text may
    // extend up to 20 px past the right screen edge if it makes the line
    // nicer). _middleWidth = screenW - _leftMargin + _rightBleed.
    private function _layout(dc as Dc) as Void {
        var article = Strings.sampleArticle();
        var rawLines = _splitLines(article);
        var screenW = dc.getWidth();
        var spacing = 4;
        var sectionGap = 4;
        var narrowEdge = 160;
        var narrowSecond = 300;
        var rightBleed = 20;
        _middleWidth = screenW - _leftMargin + rightBleed;

        var meta = [];
        for (var i = 0; i < rawLines.size(); i++) {
            var token = MarkdownTokens.parse(rawLines[i] as String);
            var font = _fontForLevel(token[:level] as Number);
            var fh = dc.getFontHeight(font);
            var charW = dc.getTextWidthInPixels("ש", font);
            if (charW < 1) { charW = 8; }
            meta.add({ :token => token, :font => font, :fh => fh, :charW => charW });
        }

        var firstWidths = [narrowEdge, narrowSecond, _middleWidth];
        var middleOnly = [_middleWidth];

        _lines = [];
        var y = 8;
        for (var i = 0; i < meta.size(); i++) {
            var m = meta[i] as Dictionary;
            var text = (m[:token] as Dictionary)[:text] as String;
            var charW = m[:charW] as Number;
            var subs;
            var perSubWidth = null;
            var widthsUsed;
            var isH1 = (i == 0);
            if (i == 0) {
                subs = LineWrap.wrapToWidths(text, charW, firstWidths, 0);
                widthsUsed = firstWidths;
            } else if (i == meta.size() - 1) {
                subs = LineWrap.wrapWithNarrowTail(text, charW, _middleWidth, narrowSecond, narrowEdge);
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
                subs = LineWrap.wrapToWidths(text, charW, middleOnly, 0);
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
                _lines.add({
                    :text => subs[j],
                    :font => m[:font],
                    :y => y,
                    :h => m[:fh] as Number,
                    :w => w,
                    :isH1 => isH1
                });
                y += (m[:fh] as Number) + spacing;
            }
            y += sectionGap;
        }
        _contentHeight = y;
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
