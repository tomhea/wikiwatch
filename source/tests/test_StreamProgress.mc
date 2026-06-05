import Toybox.Lang;
import Toybox.Test;

// M10.2 tests for StreamProgress — the pure helpers behind wikiwatchView's
// streaming-decode layout.
//
// Contract:
//   needMoreRawLines(cursor, decodedCount, lookahead):
//     - true iff (decodedCount - cursor) < lookahead  (layout closing on the
//       decoded tail -> pump more decode). Boundary gap == lookahead is false.
//   firstPaintShouldContinue(layoutY, screenHeight, subLineCount, budget):
//     - true iff layoutY < 2*screenHeight AND subLineCount < budget. Stops at/above
//       2 screens, and stops at the budget even below 2 screens (watchdog cap).

// --- needMoreRawLines ---

(:test)
function streamProgress_needMoreWhenCursorNearTail(logger as Logger) as Boolean {
    var r = StreamProgress.needMoreRawLines(0, 10, 64);
    logger.debug("needMoreRawLines(0,10,64) = " + r);
    return r == true;
}

(:test)
function streamProgress_noMoreWhenFarAhead(logger as Logger) as Boolean {
    // 200 decoded, cursor at 100 -> gap 100 >= 64 -> enough buffered.
    var r = StreamProgress.needMoreRawLines(100, 200, 64);
    logger.debug("needMoreRawLines(100,200,64) = " + r);
    return r == false;
}

(:test)
function streamProgress_gapEqualsLookaheadIsFalse(logger as Logger) as Boolean {
    // gap == lookahead (64) is NOT < lookahead -> false (boundary).
    var r = StreamProgress.needMoreRawLines(0, 64, 64);
    logger.debug("needMoreRawLines(0,64,64) = " + r);
    return r == false;
}

// --- firstPaintShouldContinue ---

(:test)
function streamProgress_firstPaintContinuesBelowTwoScreens(logger as Logger) as Boolean {
    // layoutY 100 < 2*390, subLines 5 < 40 -> keep going.
    var r = StreamProgress.firstPaintShouldContinue(100, 390, 5, 40);
    logger.debug("firstPaintShouldContinue(100,390,5,40) = " + r);
    return r == true;
}

(:test)
function streamProgress_firstPaintStopsAtTwoScreens(logger as Logger) as Boolean {
    // layoutY 780 == 2*390 -> not < -> stop (2 screens filled).
    var r = StreamProgress.firstPaintShouldContinue(780, 390, 5, 40);
    logger.debug("firstPaintShouldContinue(780,390,5,40) = " + r);
    return r == false;
}

(:test)
function streamProgress_firstPaintStopsAtBudget(logger as Logger) as Boolean {
    // Below 2 screens (layoutY 200) but sub-line budget hit (40 == 40) -> stop
    // (watchdog cap; the next tick continues).
    var r = StreamProgress.firstPaintShouldContinue(200, 390, 40, 40);
    logger.debug("firstPaintShouldContinue(200,390,40,40) = " + r);
    return r == false;
}
