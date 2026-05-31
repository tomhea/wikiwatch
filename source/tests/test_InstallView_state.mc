import Toybox.Lang;
import Toybox.Test;

// M8 tests for the pure InstallController state machine (the testable core of
// InstallView's parallel chunk-fetch orchestration). No Storage / network / UI.

(:test)
function install_capsInFlightAt2(logger as Logger) as Boolean {
    var c = new InstallController(100, [] as Array<Number>, 2);
    var fire1 = c.nextToFire();
    logger.debug("fire1 = " + fire1 + " inFlight=" + c.inFlightCount());
    // Two slots -> two chunks, lowest-first.
    if (!(fire1.size() == 2 && fire1[0] == 0 && fire1[1] == 1)) { return false; }
    // Without resolving, no more slots.
    var fire2 = c.nextToFire();
    logger.debug("fire2 = " + fire2);
    return fire2.size() == 0 && c.inFlightCount() == 2;
}

(:test)
function install_dropsToSerialUnderMemoryPressure(logger as Logger) as Boolean {
    // maxInFlight=1 (as the view would pick via InstallPlan.maxInFlightForMemory
    // under pressure) -> only 1 chunk fired at a time.
    var c = new InstallController(100, [] as Array<Number>, 1);
    var fire = c.nextToFire();
    logger.debug("serial fire = " + fire);
    return fire.size() == 1 && fire[0] == 0;
}

(:test)
function install_setMaxInFlightRaisesCap(logger as Logger) as Boolean {
    var c = new InstallController(100, [] as Array<Number>, 1);
    c.nextToFire();                  // fires chunk 0
    c.setMaxInFlight(2);             // memory recovered
    var fire = c.nextToFire();       // now one more slot
    logger.debug("after raise = " + fire);
    return fire.size() == 1 && fire[0] == 1 && c.inFlightCount() == 2;
}

(:test)
function install_indexPhaseNeverExceedsCapEvenOnRepeatedFailure(logger as Logger) as Boolean {
    // M9 regression (the stack-overflow crash): the index phase drives 9 parts
    // through their own InstallController capped at 2. Even if EVERY fetch
    // fails (the rc=-101 storm that crashed the watch), the number of times the
    // controller offers a part is bounded (9 parts x MAX_ATTEMPTS=3 = 27) and
    // it never offers more than 2 in flight at once — so the view's
    // fire-on-result loop can't recurse without bound.
    var c = new InstallController(9, [] as Array<Number>, 2);
    var totalFires = 0;
    var maxConcurrent = 0;
    for (var iter = 0; iter < 1000; iter++) {
        var f = c.nextToFire();
        if (f.size() == 0 && c.inFlightCount() == 0) { break; }
        if (c.inFlightCount() > maxConcurrent) { maxConcurrent = c.inFlightCount(); }
        // Fail everything we just fired (worst case).
        for (var i = 0; i < f.size(); i++) {
            totalFires++;
            c.onFailure(f[i]);
        }
        if (f.size() == 0) { break; }   // nothing eligible + nothing in flight handled above
    }
    logger.debug("index storm: totalFires=" + totalFires + " maxConcurrent=" + maxConcurrent
        + " complete=" + c.isComplete());
    // Bounded total offers (<=27) + never exceeded the cap of 2 + terminates.
    return totalFires == 27 && maxConcurrent <= 2 && c.isComplete();
}

(:test)
function install_largeChunkCountCompletesViaO1Membership(logger as Logger) as Boolean {
    // M9.5 (D1): drive a large install end-to-end through the O(1) per-chunk
    // state machine (was O(chunkCount x received) indexOf scans per nextToFire).
    // Fire 2-in-flight, succeed each, until complete — proves correctness +
    // termination at a chunk count well past the real corpus.
    var c = new InstallController(500, [] as Array<Number>, 2);
    var iters = 0;
    while (!c.isComplete() && iters < 100000) {
        iters++;
        var f = c.nextToFire();
        if (f.size() == 0) { break; }
        for (var i = 0; i < f.size(); i++) { c.onSuccess(f[i], 6); }
    }
    logger.debug("large install: received=" + c.receivedCount()
        + " complete=" + c.isComplete() + " arts=" + c.articlesWritten());
    return c.isComplete() && c.receivedCount() == 500
        && c.inFlightCount() == 0 && c.articlesWritten() == 3000;
}

(:test)
function install_completesAfterAllChunksReceived(logger as Logger) as Boolean {
    var c = new InstallController(3, [] as Array<Number>, 2);
    c.nextToFire();                  // [0,1]
    c.onSuccess(0, 40);
    c.onSuccess(1, 40);
    c.nextToFire();                  // [2]
    c.onSuccess(2, 20);
    logger.debug("complete? " + c.isComplete() + " received=" + c.receivedCount());
    return c.isComplete() && c.receivedCount() == 3;
}

(:test)
function install_notCompleteWhileInFlight(logger as Logger) as Boolean {
    var c = new InstallController(2, [] as Array<Number>, 2);
    c.nextToFire();                  // [0,1] in flight
    c.onSuccess(0, 40);
    // chunk 1 still in flight -> not complete
    return c.isComplete() == false;
}

(:test)
function install_retriesFailedChunkUpTo3Times(logger as Logger) as Boolean {
    var c = new InstallController(1, [] as Array<Number>, 1);
    var fireCount = 0;
    // Keep firing + failing until the chunk stops being offered.
    for (var i = 0; i < 10; i++) {
        var f = c.nextToFire();
        if (f.size() == 0) { break; }
        fireCount += f.size();
        c.onFailure(f[0]);
    }
    logger.debug("fired " + fireCount + " times, attempts=" + c.attemptsFor(0));
    // Offered exactly MAX_ATTEMPTS (3) times, then permanently failed.
    return fireCount == 3;
}

(:test)
function install_continuesAfterChunkPermanentFailure(logger as Logger) as Boolean {
    var c = new InstallController(3, [] as Array<Number>, 3);
    c.nextToFire();                  // [0,1,2] all in flight
    c.onSuccess(0, 40);
    c.onSuccess(2, 40);              // inFlight = {1}
    // chunk 1's request fails repeatedly. The view fails whatever it fired;
    // after each failure the chunk becomes eligible again until retries run
    // out, then it's permanently failed.
    c.onFailure(1);                  // attempt 1 (was in flight)
    c.onFailure(c.nextToFire()[0]);  // attempt 2 (re-fired)
    c.onFailure(c.nextToFire()[0]);  // attempt 3 -> permanent
    logger.debug("complete after perm-fail? " + c.isComplete()
        + " attempts=" + c.attemptsFor(1));
    // received {0,2} + failed {1} == 3 chunks, none in flight -> complete.
    return c.isComplete() && c.attemptsFor(1) == 3;
}

(:test)
function install_handlesOutOfOrderResponses(logger as Logger) as Boolean {
    var c = new InstallController(4, [] as Array<Number>, 4);
    c.nextToFire();                  // [0,1,2,3]
    // Resolve out of order.
    c.onSuccess(3, 10);
    c.onSuccess(1, 10);
    c.onSuccess(0, 10);
    c.onSuccess(2, 10);
    logger.debug("OOO received=" + c.receivedCount() + " written=" + c.articlesWritten());
    return c.isComplete() && c.receivedCount() == 4 && c.articlesWritten() == 40;
}

(:test)
function install_progressCountsArticlesNotChunks(logger as Logger) as Boolean {
    var c = new InstallController(2, [] as Array<Number>, 2);
    c.nextToFire();
    c.onSuccess(0, 40);
    c.onSuccess(1, 37);              // last chunk has fewer
    logger.debug("articlesWritten = " + c.articlesWritten());
    return c.articlesWritten() == 77;
}

(:test)
function install_storedCountIsArticlesNotChunkIndex(logger as Logger) as Boolean {
    // M9.6: the "stored X / N" install readout must show the ARTICLE count
    // (articlesWritten), NOT the chunk count. Regression fixed here: the view
    // derived the displayed count from receivedCount * _perChunk, and on the M9
    // chunked path _perChunk stayed 1 (computed before the article total was
    // known), so the line showed the chunk index — capped at chunkCount (~314 on
    // the v14 corpus) instead of climbing toward 1462. Drive 5 chunks each
    // writing 9 articles: the article total (45) must exceed the chunk count (5).
    var c = new InstallController(5, [] as Array<Number>, 2);
    while (!c.isComplete()) {
        var f = c.nextToFire();
        if (f.size() == 0) { break; }
        for (var i = 0; i < f.size(); i++) { c.onSuccess(f[i], 9); }
    }
    logger.debug("stored=" + c.articlesWritten() + " chunks=" + c.receivedCount());
    return c.articlesWritten() == 45
        && c.receivedCount() == 5
        && c.articlesWritten() > c.receivedCount();
}

(:test)
function install_resumeSeedsReceivedChunks(logger as Logger) as Boolean {
    // Resume: chunks 0,1,5 already durably written. Next fired must skip them.
    var c = new InstallController(10, [0, 1, 5] as Array<Number>, 2);
    var fire = c.nextToFire();
    logger.debug("resume fire = " + fire + " receivedCount=" + c.receivedCount());
    return c.receivedCount() == 3 && fire.size() == 2 && fire[0] == 2 && fire[1] == 3;
}
