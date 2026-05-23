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
        // M2.2: reverted to standard clamp. The per-line wrap budget already
        // narrows top/bottom lines so they read cleanly at the article's
        // natural endpoints - no need to scroll past the content boundaries.
        _scrollY += delta;
        var maxScroll = _contentHeight - _screenHeight;
        if (maxScroll < 0) { maxScroll = 0; }
        if (_scrollY < 0) { _scrollY = 0; }
        if (_scrollY > maxScroll) { _scrollY = maxScroll; }
        WatchUi.requestUpdate();
    }

    // Two-pass position-aware layout (M2.2).
    //
    // Pass 1: walk raw lines once assuming no wrap, accumulating fh+spacing
    // per raw line. The end value is an estimate of contentH used solely to
    // bucket each line into "top zone / middle zone / bottom zone" so we
    // can pick the right wrap budget.
    //
    // Pass 2: for each raw line, the closest screen_y the line can reach
    // given default scroll range [0, estContentH - screenH] determines the
    // chord width available there; we wrap to that chord minus 25 px padding
    // on each side. Top-zone lines (estY < center) stick to screen-top with
    // a narrow chord; bottom-zone lines (estY > maxScroll + center) stick
    // to screen-bottom with a narrow chord; middle lines reach center and
    // get the full diameter minus padding.
    private function _layout(dc as Dc) as Void {
        var article = Strings.sampleArticle();
        var rawLines = _splitLines(article);
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var r = screenW / 2;
        var center = screenH / 2;
        var padding = 25;
        var spacing = 4;
        var sectionGap = 4;
        var minWrapWidth = 60;

        var meta = [];
        var estY = 8;
        for (var i = 0; i < rawLines.size(); i++) {
            var token = MarkdownTokens.parse(rawLines[i] as String);
            var font = _fontForLevel(token[:level] as Number);
            var fh = dc.getFontHeight(font);
            var charWidth = dc.getTextWidthInPixels("ש", font);
            if (charWidth < 1) { charWidth = 8; }
            meta.add({
                :token => token,
                :font => font,
                :fh => fh,
                :charWidth => charWidth,
                :estY => estY
            });
            estY += fh + spacing + sectionGap;
        }
        var estContentH = estY;
        var maxScroll = estContentH - screenH;
        if (maxScroll < 0) { maxScroll = 0; }

        _lines = [];
        var y = 8;
        for (var i = 0; i < meta.size(); i++) {
            var m = meta[i] as Dictionary;
            var token = m[:token] as Dictionary;
            var font = m[:font];
            var fh = m[:fh] as Number;
            var charWidth = m[:charWidth] as Number;
            var lineEstY = m[:estY] as Number;

            var targetScroll = lineEstY - center;
            var closestSY;
            if (targetScroll < 0) {
                closestSY = lineEstY;
            } else if (targetScroll > maxScroll) {
                closestSY = lineEstY - maxScroll;
            } else {
                closestSY = center;
            }

            var wrapBudget = SafeArea.linePaddedWidth(r, closestSY, padding);
            if (wrapBudget < minWrapWidth) { wrapBudget = minWrapWidth; }
            var maxChars = wrapBudget / charWidth;
            if (maxChars < 1) { maxChars = 1; }

            var subLines = LineWrap.wrap(token[:text] as String, maxChars);
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