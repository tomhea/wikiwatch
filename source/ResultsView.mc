import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// M5.1 full-screen scrollable results view. Pushed by the keyboard
// delegate when the user taps the "▼ N more" row in the keyboard
// center. Lists up to top-20 article titles in large FONT_SMALL rows,
// drag-scrollable, tap a row to push the article reader.
//
// Mirrors wikiwatchView's M2.1 onDrag + M2.4 skip-ahead pattern. Row
// hit-test geometry delegated to the pure ResultsLayout module so
// it's unit-testable.
class ResultsView extends WatchUi.View {
    private const _ROW_HEIGHT = 60;
    private const _RIGHT_MARGIN = 20;
    private const _FOOTER_HEIGHT = 30;        // M5.2: room for "X more articles fit"
    private const _FOOTER_GAP = 6;            // gap above footer

    private var _ranked as Array<Dictionary>;
    private var _totalMatches as Number;
    private var _scrollY as Number;
    private var _screenHeight as Number;
    private var _contentHeight as Number;

    // M5.2: totalMatches = un-capped count of articles that matched the
    // query in the corpus. When totalMatches > ranked.size(), the footer
    // "X more articles fit" tells the user there are matches the
    // capped/displayed list excluded.
    function initialize(ranked as Array<Dictionary>, totalMatches as Number) {
        View.initialize();
        _ranked = ranked;
        _totalMatches = totalMatches;
        _scrollY = 0;
        _screenHeight = 0;
        var hasFooter = ResultsLayout.moreArticlesText(totalMatches, ranked.size()) != null;
        _contentHeight = ranked.size() * _ROW_HEIGHT
                       + (hasFooter ? _FOOTER_GAP + _FOOTER_HEIGHT : 0);
    }

    function onUpdate(dc as Dc) as Void {
        _screenHeight = dc.getHeight();
        var screenW = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var rightX = screenW - _RIGHT_MARGIN;
        var n = _ranked.size();
        // Skip ahead to the first row whose bottom edge is in view.
        var i = 0;
        while (i < n) {
            var rowTop = i * _ROW_HEIGHT - _scrollY;
            if (rowTop + _ROW_HEIGHT > 0) { break; }
            i++;
        }
        // Draw until past the bottom of the viewport.
        while (i < n) {
            var rowTop = i * _ROW_HEIGHT - _scrollY;
            if (rowTop >= _screenHeight) { break; }
            var a = _ranked[i] as Dictionary;
            var title = a[:title] as String;
            // Center text vertically within the row.
            var ty = rowTop + _ROW_HEIGHT / 2;
            dc.drawText(rightX, ty, Graphics.FONT_SMALL, title,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            i++;
        }

        // M5.2: "X more articles fit" footer (only when total > displayed).
        var footerText = ResultsLayout.moreArticlesText(_totalMatches, n);
        if (footerText != null) {
            var footerTop = n * _ROW_HEIGHT + _FOOTER_GAP - _scrollY;
            var footerBottom = footerTop + _FOOTER_HEIGHT;
            if (footerBottom > 0 && footerTop < _screenHeight) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenW / 2, footerTop + _FOOTER_HEIGHT / 2,
                            Graphics.FONT_XTINY, footerText as String,
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // Returns the article dict at the tapped (x, y), or null. Defers
    // the row math to ResultsLayout (pure, tested).
    function rowAt(x as Number, y as Number) as Dictionary? {
        var idx = ResultsLayout.rowIndexAt(y, _scrollY, _ROW_HEIGHT, _ranked.size());
        if (idx == null) { return null; }
        return _ranked[idx as Number] as Dictionary;
    }

    function getScreenHeight() as Number {
        return _screenHeight;
    }
}
