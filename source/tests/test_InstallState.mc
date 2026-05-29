import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M8 tests for InstallState (Storage-backed install lifecycle). These touch
// real Application.Storage (same pattern as test_ArticleStore) and reset()
// before + after to stay isolated.

(:test)
function installState_initialIsNone(logger as Logger) as Boolean {
    InstallState.reset();
    var s = InstallState.getState();
    logger.debug("initial state = " + s);
    return s.equals(InstallState.STATE_NONE);
}

(:test)
function installState_beginSetsInProgress(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    var ok = InstallState.getState().equals(InstallState.STATE_IN_PROGRESS)
        && InstallState.getManifestVersion() == 5
        && InstallState.getChunksReceived().size() == 0;
    logger.debug("after begin(5): state=" + InstallState.getState()
        + " ver=" + InstallState.getManifestVersion());
    InstallState.reset();
    return ok;
}

(:test)
function installState_markChunkReceivedPersists(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markChunkReceived(3);
    InstallState.markChunkReceived(1);
    var rec = InstallState.getChunksReceived();
    logger.debug("received = " + rec);
    var ok = rec.size() == 2 && rec[0] == 1 && rec[1] == 3;  // sorted
    InstallState.reset();
    return ok;
}

(:test)
function installState_markChunkIdempotent(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markChunkReceived(2);
    InstallState.markChunkReceived(2);
    var rec = InstallState.getChunksReceived();
    InstallState.reset();
    return rec.size() == 1;
}

(:test)
function installState_markCompleteSetsState(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markComplete();
    var ok = InstallState.getState().equals(InstallState.STATE_COMPLETE);
    InstallState.reset();
    return ok;
}

(:test)
function installState_resetClearsEverything(logger as Logger) as Boolean {
    InstallState.begin(7);
    InstallState.markChunkReceived(1);
    InstallState.reset();
    var ok = InstallState.getState().equals(InstallState.STATE_NONE)
        && InstallState.getChunksReceived().size() == 0;
    return ok;
}

(:test)
function installState_beginClearsPriorReceived(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markChunkReceived(1);
    InstallState.markChunkReceived(2);
    InstallState.begin(6);  // fresh restart -> received cleared, version bumped
    var rec = InstallState.getChunksReceived();
    var ok = rec.size() == 0 && InstallState.getManifestVersion() == 6;
    InstallState.reset();
    return ok;
}
