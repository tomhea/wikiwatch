import Toybox.Lang;

// Double-tap detection for touch input. Pure module (no side effects, no
// Toybox.WatchUi / Storage / Application / Communications imports per R6).
// Caller tracks the previous tap's (ms, y) and asks whether the current tap
// closes a double-tap window relative to it.
module DoubleTap {
    // True iff (currentMs, currentY) is the second of a double-tap relative
    // to (prevMs, prevY): the two taps must be within intervalMs of each
    // other AND within yTolerance pixels of each other. prevMs == 0 means
    // "no previous tap" and always returns false. Negative time deltas
    // (clock weirdness, defensive) also return false.
    function isDoubleTap(prevMs as Number, prevY as Number,
                         currentMs as Number, currentY as Number,
                         intervalMs as Number, yTolerance as Number) as Boolean {
        if (prevMs == 0) { return false; }
        var dt = currentMs - prevMs;
        if (dt < 0) { return false; }
        if (dt > intervalMs) { return false; }
        var dy = currentY - prevY;
        if (dy < 0) { dy = -dy; }
        if (dy > yTolerance) { return false; }
        return true;
    }
}
