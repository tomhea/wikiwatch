import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// M9.3: pin the index/catalog-phase progress text. Before M9.3 the install
// screen drew "Loading 0% / 0 of 0" during the index phase (the article total
// isn't known until the index parts arrive), which looked broken. onUpdate now
// renders InstallView.indexPhaseLines() instead. These tests assert the exact
// three lines (top status / red warning / bottom counter) so the wording +
// "catalog N / M" counter can't silently regress.

(:test)
function installLabel_indexPhaseShowsPreparing(logger as Logger) as Boolean {
    var v = new InstallView(false);
    var lines = v.indexPhaseLines(0, 9);
    logger.debug("lines = " + lines);
    return lines.size() == 3
        && lines[0].equals("Preparing download...")
        && lines[1].equals("Don't close the app")
        && lines[2].equals("catalog 0 / 9");
}

(:test)
function installLabel_indexPhaseCounterTracksProgress(logger as Logger) as Boolean {
    var v = new InstallView(false);
    var lines = v.indexPhaseLines(3, 9);
    logger.debug("counter line = " + lines[2]);
    // The bottom counter reflects how many index parts have arrived so far.
    return lines[2].equals("catalog 3 / 9");
}

(:test)
function installLabel_notZeroOfZero(logger as Logger) as Boolean {
    // Regression guard: the misleading "0 of 0" / "0%" readout must NOT appear
    // anywhere in the index-phase lines.
    var v = new InstallView(false);
    var lines = v.indexPhaseLines(0, 9);
    for (var i = 0; i < lines.size(); i++) {
        if (lines[i].find("0 of 0") != null) { return false; }
        if (lines[i].find("%") != null) { return false; }
    }
    return true;
}
