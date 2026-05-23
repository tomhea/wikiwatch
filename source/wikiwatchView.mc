import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchView extends WatchUi.View {
    private var _scrollY as Number;
    private var _lines as Array?;
    private var _contentHeight as Number;
    private var _screenHeight as Number;
    private var _rightMargin as Number;
    private var _middleWidth as Number;

    function initialize() {
        View.initialize();
        _scrollY = 0;
        _lines = null;
        _contentHeight = 0;
        _screenHeight = 0;
        _rightMargin = 25;
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
        var rightAnchorX = screenW - _rightMargin;

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
            var w = ln[:w] as Number;
            if (w >= _middleWidth) {
                dc.drawText(rightAnchorX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_RIGHT);
            } else {
                dc.drawText(centerX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_CENTER);
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

    // M2.4 layout. Per-raw strategy:
    //   firstRaw   -> widths [narrowEdge, narrowSecond, middleWidth, ...]
    //                 (wraps the H1 into 160 / 250 / full-width sub-lines)
    //   middleRaws -> widths [middleWidth] (full screen width, body lines
    //                 are right-anchored at rightMargin in onUpdate so
    //                 their right edge sits 25 px from the screen edge)
    //   lastRaw    -> LineWrap.wrapWithNarrowTail(...)
    //                 (forward-packs into middle-width lines then reserves
    //                 the absolute LAST 2 sub-lines for the 250/160 narrow
    //                 tail - fixes M2.3's defaultWidth cascade where every
    //                 sub-line beyond the second got 160).
    //
    // Justify (in onUpdate):
    //   narrow sub-line (w < middleWidth)  -> CENTER (chord at top/bottom of
    //                                         the round screen is narrow;
    //                                         center-justify keeps text inside)
    //   middle sub-line  (w >= middleWidth) -> RIGHT  (anchored at
    //                                         screenW - rightMargin; gives a
    //                                         clean finger margin on the right
    //                                         where users scroll)
    private function _layout(dc as Dc) as Void {
        var article = Strings.sampleArticle();
        var rawLines = _splitLines(article);
        var screenW = dc.getWidth();
        var spacing = 4;
        var sectionGap = 4;
        var narrowEdge = 160;
        var narrowSecond = 250;
        // middleWidth = full screen width. With right-justify anchored at
        // screenW - rightMargin and a wrap budget of screenW, text may bleed
        // up to rightMargin pixels past the LEFT screen edge - explicitly
        // accepted by the user ("a bit too much if it makes the line nicer").
        _middleWidth = screenW;

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
                    :w => w
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