import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M7 UpdatePromptView — yes/no modal asking the user to confirm a
// corpus update. Tap top half = Yes (wipe + reinstall). Tap bottom half
// = No (keep stale corpus, continue to keyboard). Back button = No.
//
// Pushed by UpdateCheckView when a newer server version is detected.
class UpdatePromptView extends WatchUi.View {
    private var _serverManifest as Dictionary;
    private var _localVersion as Number;
    private var _serverVersion as Number;

    function initialize(serverManifest as Dictionary, localVersion as Number) {
        View.initialize();
        _serverManifest = serverManifest;
        _localVersion = localVersion;
        _serverVersion = serverManifest[:version] as Number;
    }

    function getServerManifest() as Dictionary {
        return _serverManifest;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Top half: green-ish "Yes, update" zone.
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 4 - 16, Graphics.FONT_TINY,
                    "wikiwatch update",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, h / 4 + 10, Graphics.FONT_SMALL,
                    "Yes",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, h / 4 + 40, Graphics.FONT_XTINY,
                    "v" + _localVersion + " -> v" + _serverVersion,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom half: dim "No" zone.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, h / 2, w, h / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + h / 4 - 10, Graphics.FONT_SMALL,
                    "No",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, h / 2 + h / 4 + 20, Graphics.FONT_XTINY,
                    "keep current",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Divider line.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawLine(0, h / 2, w, h / 2);
    }
}

class UpdatePromptDelegate extends WatchUi.BehaviorDelegate {
    // M7 simplicity: we don't keep a reference to the view. The yes/no
    // decision is made entirely from the tap y-coord; the view's cached
    // manifest is currently unused (InstallView re-fetches on its own
    // for simplicity — one tiny wasted request, acceptable for M7).
    // ctor takes view for API symmetry with the other delegates.
    function initialize(view as UpdatePromptView) {
        BehaviorDelegate.initialize();
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var y = coords[1];
        var settings = System.getDeviceSettings();
        var h = settings.screenHeight;
        if (y < h / 2) {
            // M8: don't wipe here. InstallView(false) re-fetches the manifest
            // and only wipes + begins (InstallState) AFTER a successful parse,
            // so a failed update fetch leaves the old corpus intact.
            System.println("M8 update prompt: YES — starting chunked reinstall");
            var iv = new InstallView(false);
            WatchUi.switchToView(iv, new InstallDelegate(), WatchUi.SLIDE_LEFT);
        } else {
            System.println("M7 update prompt: NO — continuing with stale corpus");
            _continueWithStale();
        }
        return true;
    }

    function onBack() as Boolean {
        System.println("M7 update prompt: back-button — treated as NO");
        _continueWithStale();
        return true;
    }

    private function _continueWithStale() as Void {
        var kb = new wikiwatchKeyboardView();
        var del = new wikiwatchKeyboardDelegate(kb, "");
        WatchUi.switchToView(kb, del, WatchUi.SLIDE_LEFT);
    }
}
