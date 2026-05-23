import Toybox.Lang;
import Toybox.Test;

// Tests for DoubleTap.isDoubleTap. The intervalMs and yTolerance arguments
// let the caller pick the window; tests use 300 ms / 80 px to match the
// constants the delegate uses, but the function itself is parameter-driven.

(:test)
function doubleTap_noPreviousTapReturnsFalse(logger as Logger) as Boolean {
    // prevMs == 0 is the "no previous tap" sentinel. Even if currentMs is
    // within the interval, the function must return false so the first tap
    // of a session never accidentally fires the action.
    var v = DoubleTap.isDoubleTap(0, 0, 100, 50, 300, 80);
    logger.debug("noPrev: isDoubleTap(0,0,100,50,300,80) = " + v);
    return v == false;
}

(:test)
function doubleTap_timeTooFarApartReturnsFalse(logger as Logger) as Boolean {
    // 500 ms gap with intervalMs = 300 -> outside the window.
    var v = DoubleTap.isDoubleTap(100, 50, 600, 50, 300, 80);
    logger.debug("timeFar: isDoubleTap(100,50,600,50,300,80) = " + v);
    return v == false;
}

(:test)
function doubleTap_yTooFarApartReturnsFalse(logger as Logger) as Boolean {
    // Time delta 100 ms (within 300) but y delta 200 px (outside 80).
    var v = DoubleTap.isDoubleTap(100, 50, 200, 250, 300, 80);
    logger.debug("yFar: isDoubleTap(100,50,200,250,300,80) = " + v);
    return v == false;
}

(:test)
function doubleTap_withinBothWindowsReturnsTrue(logger as Logger) as Boolean {
    // 150 ms gap, 20 px gap - both inside the windows.
    var v = DoubleTap.isDoubleTap(100, 50, 250, 70, 300, 80);
    logger.debug("inWindow: isDoubleTap(100,50,250,70,300,80) = " + v);
    return v == true;
}

(:test)
function doubleTap_negativeTimeDeltaReturnsFalse(logger as Logger) as Boolean {
    // currentMs < prevMs (clock wrap or out-of-order events). Treat as no
    // double-tap rather than letting abs() accidentally match.
    var v = DoubleTap.isDoubleTap(500, 50, 100, 50, 300, 80);
    logger.debug("negDelta: isDoubleTap(500,50,100,50,300,80) = " + v);
    return v == false;
}

(:test)
function doubleTap_intervalBoundaryIsInclusive(logger as Logger) as Boolean {
    // delta == intervalMs is INSIDE the window (<=), delta == intervalMs+1
    // is OUTSIDE. Two assertions in one test: exact boundary AND just past.
    var atEdge = DoubleTap.isDoubleTap(100, 50, 400, 50, 300, 80);
    var justPast = DoubleTap.isDoubleTap(100, 50, 401, 50, 300, 80);
    logger.debug("boundary: at=400ms -> " + atEdge + ", past=401ms -> " + justPast);
    return atEdge == true && justPast == false;
}
