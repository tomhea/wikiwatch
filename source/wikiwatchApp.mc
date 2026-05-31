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
        // M9.4: anti-crash-loop guard. Drop a boot breadcrumb BEFORE any heavy
        // corpus/index work. A hang or uncatchable OOM in the heavy path below
        // (loadCompact during _corpusIntact or the keyboard delegate) never
        // reaches the matching noteReady() in the shown view's onShow, so the
        // count survives to the next boot. Two consecutive unfinished boots ->
        // enter SafeModeView, which does ZERO heavy work, so the watch always
        // recovers to an interactive screen instead of crash-looping (the M9.3
        // black-screen failure).
        var bootAttempts = BootGuard.noteBootStart();
        System.println("M9.4 boot: attempts=" + bootAttempts
            + " free=" + System.getSystemStats().freeMemory);
        if (BootGuard.shouldEnterSafeMode(bootAttempts)) {
            System.println("M9.4 boot: SAFE MODE (>=2 unfinished boots) — skipping heavy load");
            return [ new SafeModeView(), new SafeModeDelegate() ];
        }

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
        // M9.5 (B): prefer the persisted installed-article count — it's the stored
        // contiguous prefix [0, installedCount) and costs no index build. Falls
        // back to a (single) loadCompact for legacy installs that predate it, then
        // to the manifest's articles[] count for M8-era corpora. This removes the
        // double full-index build at launch (was: _corpusIntact + the keyboard
        // delegate each calling loadCompact).
        var count = InstallState.getInstalledCount();
        if (count <= 0) {
            count = (IndexStore.loadCompact()[:titles] as Array).size();
        }
        if (count == 0) {
            var manifestArts = Manifest.load()[:articles] as Array?;
            count = (manifestArts == null) ? 0 : manifestArts.size();
        }
        if (count == 0) { return true; }
        // Sample a few ids (== positions) and check their bodies are present.
        var idxs = InstallPlan.sampleIndices(count, 5);
        var sampleIds = [] as Array<String>;
        for (var i = 0; i < idxs.size(); i++) {
            sampleIds.add((idxs[i] as Number).toString());
        }
        return ArticleStore.allPresent(sampleIds);
    }

}

function getApp() as wikiwatchApp {
    return Application.getApp() as wikiwatchApp;
}
