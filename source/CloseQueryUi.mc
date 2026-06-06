import Toybox.Graphics;
import Toybox.Lang;

// M10.8: shared renderer for the "Close app?" confirmation modal so the article
// reader (wikiwatchView) and the results list (ResultsView) show the exact same
// prompt the keyboard does. Geometry/hit-test comes from the pure CloseQuery
// module (source/models/, unit-tested); the drawing lives HERE (outside models/
// — R6 — because it imports Graphics). Tapping inside the button exits the app
// (handled in each delegate via CloseQuery.buttonHit); back/elsewhere cancels.
module CloseQueryUi {
    function draw(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var bw = CloseQuery.BTN_W;
        var bh = CloseQuery.BTN_H;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bw / 2, cy - bh / 2, bw, bh);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, "close app",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + bh / 2 + 24, Graphics.FONT_XTINY, "back = cancel",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
