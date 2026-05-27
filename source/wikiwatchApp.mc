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

    // M7: branch on Storage state.
    //   Storage empty           -> InstallView (full first-time download)
    //   Storage has a manifest  -> UpdateCheckView (750ms background race;
    //                              functional keyboard wins by default)
    function getInitialView() as [Views] or [Views, InputDelegates] {
        if (Manifest.isEmpty()) {
            var iv = new InstallView();
            return [ iv, new InstallDelegate() ];
        }
        var uv = new UpdateCheckView();
        return [ uv, new UpdateCheckDelegate() ];
    }

}

function getApp() as wikiwatchApp {
    return Application.getApp() as wikiwatchApp;
}