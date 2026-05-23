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
        if (_scrollY < 0) { _scrollY = 0; }
        var maxScroll = _contentHeight - _screenHeight;
        if (maxScroll < 0) { maxScroll = 0; }
        if (_scrollY > maxScroll) { _scrollY = maxScroll; }
        WatchUi.requestUpdate();
    }

    private function _layout(dc as Dc) as Void {
        var article = Strings.sampleArticle();
        var rawLines = _splitLines(article);
        // 280 px width budget keeps text inside the safe chord at the central
        // vertical band of the round display (SafeArea.minSafeY(195, 280) = 60).
        // Lines drawn near the top/bottom of the article may run slightly wider
        // than the chord, but scrolling exposes them in the central band.
        var maxWidth = 280;
        var spacing = 4;
        var sectionGap = 4;
        _lines = [];
        var y = 8;
        for (var i = 0; i < rawLines.size(); i++) {
            var token = MarkdownTokens.parse(rawLines[i] as String);
            var level = token[:level] as Number;
            var text = token[:text] as String;
            var font = _fontForLevel(level);
            var fh = dc.getFontHeight(font);
            var charWidth = dc.getTextWidthInPixels("ש", font);
            if (charWidth < 1) { charWidth = 8; }
            var maxChars = maxWidth / charWidth;
            if (maxChars < 1) { maxChars = 1; }
            var subLines = LineWrap.wrap(text, maxChars);
            for (var j = 0; j < subLines.size(); j++) {
                _lines.add({
                    :text => subLines[j],
                    :font => font,
                    :y => y,
                    :h => fh
                });
                y += fh + spacing;
            }
            y += sectionGap;
        }
        _contentHeight = y;
    }

    private function _fontForLevel(level as Number) as Graphics.FontType {
        if (level == 1) { return Graphics.FONT_LARGE; }
        if (level == 2) { return Graphics.FONT_MEDIUM; }
        if (level == 3) { return Graphics.FONT_SMALL; }
        if (level == 4) { return Graphics.FONT_TINY; }
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