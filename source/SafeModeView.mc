import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M9.4 SafeModeView — the recoverable fallback shown when BootGuard detects two
// consecutive boots that never reached a stable interactive view (the M9.3
// crash-loop signature). It does ZERO heavy work: no IndexStore.loadCompact, no
// keyboard, no corpus reads. Just a static screen with the live free-memory
// readout (the size-sweep instrument) and a tap-to-wipe recovery action.
//
// Reaching this screen counts as a successful boot (onShow -> BootGuard.noteReady),
// so the watch is not stuck in safe mode forever: if the user does nothing and
// relaunches, the next boot tries the normal path again. Tapping wipes the
// corpus + install state so the next launch is a clean first-install (typically
// of a smaller, re-uploaded corpus during the sweep).
class SafeModeView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        View.onShow();
        // We made it to an interactive screen — clear the crash-loop breadcrumb.
        BootGuard.noteReady();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 60, Graphics.FONT_SMALL, "Safe mode",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 22, Graphics.FONT_XTINY,
                    "Search disabled to",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, h / 2 - 4, Graphics.FONT_XTINY,
                    "protect the watch.",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Live free-memory HUD — the hardware reading we cannot get from the sim.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 24, Graphics.FONT_XTINY,
                    MemHud.line(System.getSystemStats().freeMemory),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 60, Graphics.FONT_XTINY,
                    "Tap: wipe + restart",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class SafeModeDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Tap = wipe the corpus + install state so the next launch is a clean
    // first-install. Deletions only (no large allocations), so this is safe to
    // run even under the memory pressure that put us in safe mode. After wiping
    // we exit; the user relaunches into a fresh install of whatever corpus the
    // server currently serves.
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        System.println("M9.4 safe mode: wiping corpus + install state");
        IndexStore.wipeAll();
        ArticleStore.wipeAll();
        InstallState.reset();
        Manifest.wipeArticles();
        BootGuard.noteReady();
        WatchUi.requestUpdate();
        return true;
    }
}
