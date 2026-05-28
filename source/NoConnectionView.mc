import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// M7.1 NoConnectionView — shown on FIRST LAUNCH when Storage is empty
// AND Downloader.isNetworkAvailable() returns false. The app can't
// usefully proceed (no corpus, no way to fetch one), so we show a
// static message instead of pushing a doomed InstallView whose hung
// network requests would lock up the event loop (M6.4-style stale
// render symptom).
//
// User resolution: connect phone via BLE (or WiFi/LTE on supported
// watches), relaunch the app. We don't poll for reconnection here
// because the user has to manually trigger the relaunch anyway.
class NoConnectionView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 50, Graphics.FONT_TINY,
                    "wikiwatch",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 15, Graphics.FONT_XTINY,
                    "Need connection to",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h / 2 + 5, Graphics.FONT_XTINY,
                    "load initial offline",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h / 2 + 25, Graphics.FONT_XTINY,
                    "articles.",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 70, Graphics.FONT_XTINY,
                    "Connect phone, restart app.",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class NoConnectionDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Taps absorbed (nothing to do here). Back-button = default behavior
    // (exits the app). User reconnects + relaunches.
    function onTap(event as WatchUi.ClickEvent) as Boolean { return true; }
}
