import Toybox.Lang;

// Layout policy helpers. Pure module (no side effects, no Toybox.WatchUi /
// Storage / Application / Communications imports per R6). Centralizes the
// margin / wrap-budget math so the view doesn't re-derive it on every layout
// and so the calculations have explicit test coverage.
module Layout {
    // Wrap budget (max line width in pixels) given the screen width and the
    // clean LEFT and RIGHT margins. For a right-justified anchor at
    // `screenW - rightMargin`, a wrap budget of this size makes the text's
    // visual left edge land exactly at `leftMargin` on the screen.
    function middleWidth(screenW as Number, leftMargin as Number, rightMargin as Number) as Number {
        return screenW - leftMargin - rightMargin;
    }
}