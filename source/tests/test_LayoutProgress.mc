import Toybox.Lang;
import Toybox.Test;

// M5.2 tests for LayoutProgress — the pure state-machine helpers behind
// wikiwatchView's lazy article layout.
//
// Contract:
//   nextBatchEnd(cursor, total, batch):
//     - returns min(cursor + batch, total).
//   isComplete(cursor, total):
//     - true iff cursor >= total.
//   isScrollNearEnd(scrollY, contentH, screenH, lookahead):
//     - true iff (contentH - (scrollY + screenH)) < lookahead.
//     - i.e. the bottom of the viewport is within `lookahead` px of the
//       end of the laid-out content.
//   clampedScroll(scrollY, contentH, screenH):
//     - clamps to [0, max(0, contentH - screenH)].
//     - stable as contentH grows (scroll position preserved) or shrinks
//       (scroll snaps to the new max if it was past it).

// --- nextBatchEnd ---

(:test)
function layoutProgress_nextBatchEndAdvancesByBatchSize(logger as Logger) as Boolean {
    var r = LayoutProgress.nextBatchEnd(0, 50, 12);
    logger.debug("nextBatchEnd(0,50,12) = " + r);
    return r == 12;
}

(:test)
function layoutProgress_nextBatchEndClampsAtTotal(logger as Logger) as Boolean {
    var r = LayoutProgress.nextBatchEnd(48, 50, 12);
    logger.debug("nextBatchEnd(48,50,12) = " + r);
    return r == 50;
}

(:test)
function layoutProgress_nextBatchEndIdempotentAtTotal(logger as Logger) as Boolean {
    var r = LayoutProgress.nextBatchEnd(50, 50, 12);
    logger.debug("nextBatchEnd(50,50,12) = " + r);
    return r == 50;
}

// --- isComplete ---

(:test)
function layoutProgress_isCompleteWhenCursorAtTotal(logger as Logger) as Boolean {
    var r = LayoutProgress.isComplete(50, 50);
    logger.debug("isComplete(50,50) = " + r);
    return r == true;
}

(:test)
function layoutProgress_isNotCompleteWhenCursorBelowTotal(logger as Logger) as Boolean {
    var r = LayoutProgress.isComplete(40, 50);
    logger.debug("isComplete(40,50) = " + r);
    return r == false;
}

// --- isScrollNearEnd ---

(:test)
function layoutProgress_isScrollNearEndWithinLookahead(logger as Logger) as Boolean {
    // bottom of viewport = scrollY + screenH = 500 + 200 = 700
    // gap to contentH (=800) = 100 < lookahead (=150) -> true
    var r = LayoutProgress.isScrollNearEnd(500, 800, 200, 150);
    logger.debug("isScrollNearEnd(500,800,200,150) = " + r);
    return r == true;
}

(:test)
function layoutProgress_isScrollNotNearEndWhenFar(logger as Logger) as Boolean {
    // bottom = 100 + 200 = 300; gap to 2000 = 1700 >= 150 -> false
    var r = LayoutProgress.isScrollNearEnd(100, 2000, 200, 150);
    logger.debug("isScrollNearEnd(100,2000,200,150) = " + r);
    return r == false;
}

// --- clampedScroll: the user-named race-condition cases ---

(:test)
function layoutProgress_scrollEndedBeforeLoadStarted(logger as Logger) as Boolean {
    // User scrolled past the laid-out boundary BEFORE the first incremental
    // batch fired. Currently laid-out content is 400 px tall; target was
    // far past it. Scroll must clamp at currentContentH - screenH.
    var r = LayoutProgress.clampedScroll(9999, 400, 200);
    logger.debug("scrollEndedBeforeLoadStarted clampedScroll(9999,400,200) = " + r);
    return r == 200;
}

(:test)
function layoutProgress_scrollEndedWhileLoadInProgress(logger as Logger) as Boolean {
    // User holding scroll at the current bottom (scrollY=200, contentH=400,
    // screenH=200 -> already at max). A timer tick then grows contentH to
    // 600. scrollPosition must stay at 200 (still valid, more content
    // scrollable below).
    var rBefore = LayoutProgress.clampedScroll(200, 400, 200);
    var rAfter  = LayoutProgress.clampedScroll(200, 600, 200);
    logger.debug("scrollEndedWhileLoadInProgress before=" + rBefore + " after=" + rAfter);
    return rBefore == 200 && rAfter == 200;
}

(:test)
function layoutProgress_clampedScrollNegativeBecomesZero(logger as Logger) as Boolean {
    var r = LayoutProgress.clampedScroll(-50, 500, 200);
    logger.debug("clampedScroll(-50,500,200) = " + r);
    return r == 0;
}

(:test)
function layoutProgress_clampedScrollContentSmallerThanScreen(logger as Logger) as Boolean {
    // Content fits in one screen -> no scrollable range. Any positive scroll
    // clamps to 0.
    var r = LayoutProgress.clampedScroll(50, 100, 200);
    logger.debug("clampedScroll(50,100,200) = " + r);
    return r == 0;
}

// M5.3/M5.4: bounded-batch invariant for nextBatchEnd — capping a batch never
// reads past the body. (M10.2 replaced the view's fixed first-batch with a
// height target, but nextBatchEnd's clamp contract is unchanged and still drives
// the background fill; this exercises it with a small cap.)
(:test)
function layoutProgress_initialBatchIsBoundedForAnyBodyLength(logger as Logger) as Boolean {
    var INITIAL = 2;  // a small batch cap
    var shortBatch = LayoutProgress.nextBatchEnd(0, 2, INITIAL);    // שבת (2 raw lines)
    var longBatch  = LayoutProgress.nextBatchEnd(0, 50, INITIAL);   // שלום (50 raw lines)
    logger.debug("INITIAL=" + INITIAL + " shortBatch=" + shortBatch + " longBatch=" + longBatch);
    // Short body: processes all 2 of its lines.
    // Long body: capped at INITIAL=2.
    // Both bodies process EXACTLY the same number of raw lines on first
    // paint when the body has >= INITIAL lines, so wall-clock first-paint
    // becomes effectively identical.
    return shortBatch == 2 && longBatch == INITIAL && longBatch == shortBatch;
}
