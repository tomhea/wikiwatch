import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class wikiwatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // M7+: no fixture-install on startup. The corpus lives on the server
        // (wikiwatch.tomhe.app/) and arrives via the InstallView chunked
        // download on first launch / accepted update.
    }

    function onStop(state as Dictionary?) as Void {
    }

    // M8: 3-state launch matrix. The pure LaunchRouter decides the route from
    // (installState) x (corpus present) x (network) x (battery); this method
    // just gathers the live inputs and maps the route Symbol to a concrete
    // View + Delegate pair.
    //
    //   :install      first full install        (InstallView)
    //   :resume       resume interrupted install (ResumeInstallView)
    //   :lowBattery   battery too low to install (LowBatteryView)
    //   :noConnection need network, none present (NoConnectionView)
    //   :updateCheck  corpus + network -> M7 update-check race (UpdateCheckView)
    //   :keyboard     corpus, no network -> functional offline keyboard
    //
    // The no-network branches still dodge M7's USB-sideload event-loop clog
    // (a hung makeWebRequest on a deprioritised BLE channel), because the
    // router never routes to a network-dependent view when hasNetwork is false.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var installState = InstallState.getState();
        var hasCorpus = !Manifest.isEmpty();
        var hasNetwork = Downloader.isNetworkAvailable();
        var stats = System.getSystemStats();
        // M8.3 self-heal: spot-check that the corpus the manifest claims is
        // actually present in Storage (a few sampled article ids). A
        // complete-but-empty corpus (e.g. a stale manifest from a failed
        // install) then routes to a fresh install instead of a broken keyboard.
        var corpusIntact = _corpusIntact();
        var route = LaunchRouter.route(
            installState, hasCorpus, hasNetwork, stats.battery, stats.charging, corpusIntact);
        System.println("M8 launch: state=" + installState + " corpus=" + hasCorpus
            + " intact=" + corpusIntact + " net=" + hasNetwork
            + " batt=" + stats.battery + " -> " + route);

        if (route == :install) {
            var iv = new InstallView(false);
            return [ iv, new InstallDelegate() ];
        }
        if (route == :resume) {
            var rv = new ResumeInstallView();
            return [ rv, new InstallDelegate() ];
        }
        if (route == :lowBattery) {
            var resumeContext = installState.equals(InstallState.STATE_IN_PROGRESS);
            var lb = new LowBatteryView(resumeContext);
            return [ lb, new LowBatteryDelegate() ];
        }
        if (route == :noConnection) {
            var nc = new NoConnectionView();
            return [ nc, new NoConnectionDelegate() ];
        }
        if (route == :updateCheck) {
            var uc = new UpdateCheckView();
            return [ uc, new UpdateCheckDelegate() ];
        }
        // :keyboard — functional offline keyboard with the cached corpus.
        var kb = new wikiwatchKeyboardView();
        return [ kb, new wikiwatchKeyboardDelegate(kb, "") ];
    }

    // True iff a spot-check sample of the installed article ids all have
    // bodies in Storage. Reads from IndexStore (M9) or Manifest.articles[]
    // (M8 fallback). Empty corpus -> true (the hasCorpus=false path handles
    // first install). O(1)-ish: at most ~5 Storage reads.
    private function _corpusIntact() as Boolean {
        // M9: use the index parts if available.
        var arts = IndexStore.load();
        if (arts.size() == 0) {
            // M8 fallback: articles[] embedded in the manifest.
            var manifestArts = Manifest.load()[:articles] as Array<Dictionary>?;
            arts = (manifestArts == null) ? ([] as Array<Dictionary>) : manifestArts;
        }
        if (arts.size() == 0) { return true; }
        var idxs = InstallPlan.sampleIndices(arts.size(), 5);
        var sampleIds = [] as Array<String>;
        for (var i = 0; i < idxs.size(); i++) {
            sampleIds.add((arts[idxs[i]] as Dictionary)[:id] as String);
        }
        return ArticleStore.allPresent(sampleIds);
    }

}

function getApp() as wikiwatchApp {
    return Application.getApp() as wikiwatchApp;
}
