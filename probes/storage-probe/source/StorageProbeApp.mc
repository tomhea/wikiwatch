import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// M11 spike: probe how many Application.Storage keys the Venu 2 sustains, the
// write throughput (install-time proxy), and getValue latency as the key count
// grows — to set the SAFE article-count ceiling for the ~20k-article corpus.
// Standalone app (own UUID + Storage namespace) so it never touches wikiwatch.
class StorageProbeApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [ new StorageProbeView() ];
    }
}

function getApp() as StorageProbeApp {
    return Application.getApp() as StorageProbeApp;
}
