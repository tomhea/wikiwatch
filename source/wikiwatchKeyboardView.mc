import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// M3 keyboard view. Pure render (R3-exempt). Draws the typing buffer at the
// top (Hebrew right-anchored, FONT_TINY) and the 5x6 key grid below using
// KeyboardLayout.keys() + the same grid bounds math used by keyAt.
class wikiwatchKeyboardView extends WatchUi.View {
    private var _buffer as String;

    function initialize() {
        View.initialize();
        _buffer = "";
    }

    function setBuffer(b as String) as Void {
        _buffer = b;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();

        // Buffer at top, Hebrew right-anchored at the right side of screen
        // (matches the M2.x reader's right anchor convention).
        dc.drawText(screenW - 15, 8, Graphics.FONT_TINY, _buffer, Graphics.TEXT_JUSTIFY_RIGHT);

        // Grid bounds - mirrors KeyboardLayout.keyAt internal math so view
        // and hit-test agree on the cell rectangles.
        var gridY = 65;
        var gridH = 260;
        var r = screenH / 2;
        var topHalf = SafeArea.safeChordHalfWidth(r, gridY - r);
        var botHalf = SafeArea.safeChordHalfWidth(r, gridY + gridH - r);
        var gridHalfW = (topHalf < botHalf) ? topHalf : botHalf;
        var gridW = 2 * gridHalfW;
        var gridX = (screenW - gridW) / 2;
        var cellW = gridW / 6;
        var cellH = gridH / 5;

        var keys = KeyboardLayout.keys();
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i] as Dictionary;
            if (k[:type] == :EMPTY) { continue; }
            var col = k[:col] as Number;
            var row = k[:row] as Number;
            var cellX = gridX + col * cellW;
            var cellY = gridY + row * cellH;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            dc.drawRectangle(cellX, cellY, cellW, cellH);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cellX + cellW / 2, cellY + cellH / 2, Graphics.FONT_TINY, k[:label] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}