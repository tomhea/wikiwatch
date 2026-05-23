import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchView extends WatchUi.View {
    private var _scrollY as Number;
    private var _lines as Array?;
    private var _contentHeight as Number;
    private var _screenHeight as Number;

    function initialize() {
        View.initialize();
        _scrollY = 0;
        _lines = null;
        _contentHeight = 0;
        _screenHeight = 0;
    }

    function onUpdate(dc as Dc) as Void {
        if (_lines == null) {
            _layout(dc);
        }
        _screenHeight = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var centerX = dc.getWidth() / 2;
        var lines = _lines as Array<Dictionary>;
        for (var i = 0; i < lines.size(); i++) {
            var ln = lines[i] as Dictionary;
            var ly = ln[:y] as Number;
            var lh = ln[:h] as Number;
            var screenY = ly - _scrollY;
            if (screenY + lh > 0 && screenY < _screenHeight) {
                dc.drawText(centerX, screenY, ln[:font], ln[:text] as String, Graphics.TEXT_JUSTIFY_CENTER);
            }
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

    // M2.3 layout. Per-raw strategy (no global iteration):
    //   firstRaw   -> widths [narrowEdge, narrowSecond, middleWidth, ...]
    //                 greedy wrap consumes them in order, so the first
    //                 rendered sub-line ends up 160 wide and the second 250.
    //   middleRaws -> widths [middleWidth] (full screen width)
    //   lastRaw    -> widths [narrowSecond, narrowEdge]
    //                 forces last raw's sub-lines into the narrow tail; the
    //                 typical body paragraph wraps to 2 sub-lines at 250/160.
    private function _layout(dc as Dc) as Void {
        var article = Strings.sampleArticle();
        var rawLines = _splitLines(article);
        var screenW = dc.getWidth();
        var spacing = 4;
        var sectionGap = 4;
        var narrowEdge = 160;
        var narrowSecond = 250;
        var middleWidth = screenW;

        var meta = [];
        for (var i = 0; i < rawLines.size(); i++) {
            var token = MarkdownTokens.parse(rawLines[i] as String);
            var font = _fontForLevel(token[:level] as Number);
            var fh = dc.getFontHeight(font);
            var charW = dc.getTextWidthInPixels("ש", font);
            if (charW < 1) { charW = 8; }
            meta.add({ :token => token, :font => font, :fh => fh, :charW => charW });
        }

        var firstWidths = [narrowEdge, narrowSecond, middleWidth];
        var middleOnly = [middleWidth];
        var lastWidths = [narrowSecond, narrowEdge];

        _lines = [];
        var y = 8;
        for (var i = 0; i < meta.size(); i++) {
            var m = meta[i] as Dictionary;
            var text = (m[:token] as Dictionary)[:text] as String;
            var charW = m[:charW] as Number;
            var subs;
            var widthsUsed;
            if (i == 0) {
                subs = LineWrap.wrapToWidths(text, charW, firstWidths, 0);
                widthsUsed = firstWidths;
            } else if (i == meta.size() - 1) {
                subs = LineWrap.wrapToWidths(text, charW, lastWidths, 0);
                widthsUsed = lastWidths;
            } else {
                subs = LineWrap.wrapToWidths(text, charW, middleOnly, 0);
                widthsUsed = middleOnly;
            }
            for (var j = 0; j < subs.size(); j++) {
                var w;
                if (j < widthsUsed.size()) {
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

    // M2.3: shrunk header fonts by one notch so more content fits per screen.
    // H4 collapses to body size (XTINY); markdown source still distinguishes
    // them but they render with identical metrics.
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