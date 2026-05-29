import Toybox.Lang;
import Toybox.Test;

// M8 tests for the pure LaunchRouter routing matrix.
// route(installState, hasCorpus, hasNetwork, batteryPct, charging, corpusIntact) -> Symbol

(:test)
function launchRouter_firstLaunchInstalls(logger as Logger) as Boolean {
    var r = LaunchRouter.route("none", false, true, 80.0, false, true);
    logger.debug("first-launch route -> " + r);
    return r == :install;
}

(:test)
function launchRouter_firstLaunchNoNetwork(logger as Logger) as Boolean {
    var r = LaunchRouter.route("none", false, false, 80.0, false, true);
    return r == :noConnection;
}

(:test)
function launchRouter_firstLaunchLowBattery(logger as Logger) as Boolean {
    var r = LaunchRouter.route("none", false, true, 5.0, false, true);
    logger.debug("first-launch low-batt -> " + r);
    return r == :lowBattery;
}

(:test)
function launchRouter_inProgressResumes(logger as Logger) as Boolean {
    var r = LaunchRouter.route("in_progress", false, true, 80.0, false, true);
    return r == :resume;
}

(:test)
function launchRouter_inProgressLowBattery(logger as Logger) as Boolean {
    var r = LaunchRouter.route("in_progress", false, true, 8.0, false, true);
    return r == :lowBattery;
}

(:test)
function launchRouter_inProgressNoNetwork(logger as Logger) as Boolean {
    var r = LaunchRouter.route("in_progress", false, false, 80.0, false, true);
    return r == :noConnection;
}

(:test)
function launchRouter_completeWithNetworkChecksUpdate(logger as Logger) as Boolean {
    var r = LaunchRouter.route("complete", true, true, 80.0, false, true);
    return r == :updateCheck;
}

(:test)
function launchRouter_completeNoNetworkKeyboard(logger as Logger) as Boolean {
    var r = LaunchRouter.route("complete", true, false, 80.0, false, true);
    return r == :keyboard;
}

(:test)
function launchRouter_lowBatteryDoesNotBlockExistingCorpus(logger as Logger) as Boolean {
    // Battery only gates installs. With a corpus already present, a low
    // battery must NOT stop the user from using it.
    var r = LaunchRouter.route("complete", true, true, 3.0, false, true);
    logger.debug("complete+low-batt -> " + r);
    return r == :updateCheck;
}

// --- M8.3 self-heal: corpusIntact=false means "marked complete but bodies
//     missing" -> auto re-install. ---

(:test)
function launchRouter_completeBrokenCorpusReinstalls(logger as Logger) as Boolean {
    var r = LaunchRouter.route("complete", true, true, 80.0, false, false);
    logger.debug("complete+broken+net -> " + r);
    return r == :install;
}

(:test)
function launchRouter_completeBrokenNoNetworkDegrades(logger as Logger) as Boolean {
    // Can't re-install offline; fall back to the (partial) keyboard, not a
    // dead-end NoConnectionView, since some corpus exists.
    var r = LaunchRouter.route("complete", true, false, 80.0, false, false);
    return r == :keyboard;
}

(:test)
function launchRouter_completeBrokenLowBatteryGates(logger as Logger) as Boolean {
    // Re-install is an install -> battery still gates it.
    var r = LaunchRouter.route("complete", true, true, 5.0, false, false);
    return r == :lowBattery;
}

(:test)
function launchRouter_noneWithCorpusButBrokenReinstalls(logger as Logger) as Boolean {
    // Legacy/edge: state defaulted to "none" but a corpus is present yet the
    // bodies don't verify -> re-install rather than trust it.
    var r = LaunchRouter.route("none", true, true, 80.0, false, false);
    return r == :install;
}
