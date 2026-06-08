import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Minimal standalone app: probes the real watch's makeWebRequest response cap by
// fetching exact-size JSON files from wikiwatch.tomhe.app/probe/ and showing which
// sizes return 200 vs rc=-402 (NETWORK_RESPONSE_TOO_LARGE). Does nothing else.
class ProbeApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [ new ProbeView() ];
    }
}

function getApp() as ProbeApp {
    return Application.getApp() as ProbeApp;
}
