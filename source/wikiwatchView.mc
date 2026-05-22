import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.drawText(
            w / 2,
            h / 2,
            Graphics.FONT_LARGE,
            Strings.hello(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}