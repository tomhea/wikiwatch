import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M8 resume / version-bump / state-persistence tests. These compose the
// Storage-backed InstallState with the pure InstallPlan scheduling math to
// exercise the end-to-end resume behaviour the InstallView relies on. Each
// resets InstallState before + after to stay isolated.

(:test)
function resume_pickUpFromInstallChunksReceived(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markChunkReceived(0);
    InstallState.markChunkReceived(1);
    InstallState.markChunkReceived(5);
    var received = InstallState.getChunksReceived();
    var next = InstallPlan.firstMissing(received, 100);
    logger.debug("resume firstMissing = " + next);
    InstallState.reset();
    return next == 2;
}

(:test)
function resume_skipsDownloadedChunks(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    // 50 of 100 done.
    for (var i = 0; i < 50; i++) {
        InstallState.markChunkReceived(i);
    }
    var missing = InstallPlan.missingChunks(InstallState.getChunksReceived(), 100);
    logger.debug("missing after 50 = " + missing.size());
    InstallState.reset();
    return missing.size() == 50 && missing[0] == 50;
}

(:test)
function resume_invalidatedByVersionBump(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(4);
    InstallState.markChunkReceived(0);
    var localVer = InstallState.getManifestVersion();
    var stale = InstallPlan.shouldInvalidate(localVer, 5);  // server bumped to 5
    logger.debug("stale (local=" + localVer + ", remote=5) = " + stale);
    InstallState.reset();
    return stale == true;
}

(:test)
function resume_preservesCompletedChunksOnSameVersion(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markChunkReceived(0);
    InstallState.markChunkReceived(1);
    var localVer = InstallState.getManifestVersion();
    var stale = InstallPlan.shouldInvalidate(localVer, 5);  // same version
    var preserved = InstallState.getChunksReceived().size();
    logger.debug("same-version stale=" + stale + " preserved=" + preserved);
    InstallState.reset();
    return stale == false && preserved == 2;
}

(:test)
function state_completeAfterAllChunksReceived(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    for (var i = 0; i < 3; i++) {
        InstallState.markChunkReceived(i);
    }
    var done = InstallPlan.isComplete(InstallState.getChunksReceived().size(), 3);
    if (done) {
        InstallState.markComplete();
    }
    var ok = InstallState.getState().equals(InstallState.STATE_COMPLETE);
    InstallState.reset();
    return done && ok;
}

(:test)
function state_inProgressAfterFirstChunk(logger as Logger) as Boolean {
    InstallState.reset();
    InstallState.begin(5);
    InstallState.markChunkReceived(0);
    var ok = InstallState.getState().equals(InstallState.STATE_IN_PROGRESS)
        && InstallState.getChunksReceived().size() == 1;
    InstallState.reset();
    return ok;
}

(:test)
function state_persistedAcrossReload(logger as Logger) as Boolean {
    // Simulate "view recreated" by reading the values back fresh from Storage
    // through a second logical access (InstallState has no instance state — all
    // reads hit Storage), proving persistence survives a view teardown.
    InstallState.reset();
    InstallState.begin(7);
    InstallState.markChunkReceived(2);
    InstallState.markChunkReceived(4);
    // ... "view destroyed + recreated" — same Storage ...
    var stateAfter = InstallState.getState();
    var verAfter = InstallState.getManifestVersion();
    var recvAfter = InstallState.getChunksReceived();
    logger.debug("persisted state=" + stateAfter + " ver=" + verAfter + " recv=" + recvAfter);
    var ok = stateAfter.equals(InstallState.STATE_IN_PROGRESS)
        && verAfter == 7
        && recvAfter.size() == 2 && recvAfter[0] == 2 && recvAfter[1] == 4;
    InstallState.reset();
    return ok;
}
