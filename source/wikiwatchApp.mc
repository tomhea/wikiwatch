import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // M7: no more fixture-install on startup. The corpus lives on the
        // server (wikiwatch.tomhe.app/) and arrives via Downloader/
        // InstallView on first launch + UpdateCheckView on every
        // subsequent launch.
    }

    function onStop(state as Dictionary?) as Void {
    }

    // M7.1: 2-axis branch on (Storage state) x (network availability).
    //
    //                       network available   network unavailable
    //   Storage empty       InstallView         NoConnectionView
    //   Storage has corpus  UpdateCheckView     KeyboardView (functional)
    //
    // The "no network" branches dodge M7's USB-sideload bug: when USB
    // is connected, BLE is deprioritized + makeWebRequest hangs for
    // ~30s, clogging CIQ's event loop with the M6.4-style stale-render
    // symptom. Detecting no-network at launch and skipping the request
    // entirely keeps the UI thread free.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var hasCorpus = !Manifest.isEmpty();
        var hasNetwork = Downloader.isNetworkAvailable();
        if (hasCorpus) {
            if (hasNetwork) {
                var uv = new UpdateCheckView();
                return [ uv, new UpdateCheckDelegate() ];
            }
            // Offline launch with cached corpus: skip the network check
            // entirely, go straight to a functional keyboard.
            var kb = new wikiwatchKeyboardView();
            return [ kb, new wikiwatchKeyboardDelegate(kb, "") ];
        }
        // First launch (no cached corpus).
        if (hasNetwork) {
            var iv = new InstallView();
            return [ iv, new InstallDelegate() ];
        }
        // First launch with no network: dead-end view, can't proceed.
        var nc = new NoConnectionView();
        return [ nc, new NoConnectionDelegate() ];
    }

}

function getApp() as wikiwatchApp {
    return Application.getApp() as wikiwatchApp;
}