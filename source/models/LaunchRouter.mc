import Toybox.Lang;

// M8 pure launch routing. Decides which view the app opens based on install
// lifecycle state, corpus presence, network, and battery. Returns a Symbol
// route that wikiwatchApp.getInitialView maps to a concrete View. Pure so the
// whole branch matrix is unit-testable (M7.1 had this logic inline in
// getInitialView; M8 adds a third install state + a battery axis, so it's
// worth extracting).
//
// Routes:
//   :install        fresh full install   (first launch, network, battery ok)
//   :resume         resume interrupted   (in_progress, network, battery ok)
//   :lowBattery     battery too low to (re)start an install
//   :noConnection   need network to install but none available
//   :updateCheck    has corpus + network  -> M7 update-check race
//   :keyboard       has corpus, no network -> functional keyboard offline
//
// R6: this module imports only Toybox.Lang (delegates battery math to the
// pure BatteryGate module).
module LaunchRouter {
    // These mirror InstallState's STATE_* string values. Duplicated as
    // literals (rather than referencing InstallState) so this module stays
    // pure under source/models/ — R6 forbids a models module from touching a
    // storage module (InstallState imports Application.Storage).
    const STATE_NONE        = "none";
    const STATE_IN_PROGRESS = "in_progress";
    const STATE_COMPLETE    = "complete";

    function route(
        installState as String,
        hasCorpus as Boolean,
        hasNetwork as Boolean,
        batteryPct as Float,
        charging as Boolean
    ) as Symbol {
        // A usable corpus already exists when the last install completed, OR
        // when an M7-era install left article bodies but no install-state key
        // (legacy upgrade — state defaults to "none" but Manifest isn't empty).
        // Either way, don't re-install: go to the M7 update-check / keyboard
        // path. The update check will find the v5 corpus and offer to update,
        // at which point UpdatePromptView begins a fresh chunked install.
        var corpusReady = installState.equals(STATE_COMPLETE)
            || (installState.equals(STATE_NONE) && hasCorpus);
        if (corpusReady) {
            // Battery never blocks USE of an existing corpus — only installs.
            return hasNetwork ? :updateCheck : :keyboard;
        }

        // A (re)install is needed: gate on battery first (hard safety stop),
        // then on network (can't fetch without it).
        if (BatteryGate.shouldGate(batteryPct, charging)) {
            return :lowBattery;
        }
        if (!hasNetwork) {
            return :noConnection;
        }
        return installState.equals(STATE_IN_PROGRESS) ? :resume : :install;
    }
}
