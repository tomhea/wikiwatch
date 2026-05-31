import Toybox.Lang;

// M9.7: detect a long press of the PHYSICAL back button by timing its key
// down/up (the physical button doesn't emit a touch-hold/onHold event). Pure ->
// unit-testable; the delegate passes System.getTimer() millis.
module LongPress {
    // Hold this long (ms) for the back button to mean "close app" instead of
    // a normal back.
    const BACK_HOLD_MS = 600;

    function isLong(downMs as Number, upMs as Number, thresholdMs as Number) as Boolean {
        if (downMs < 0 || upMs < downMs) { return false; }
        return (upMs - downMs) >= thresholdMs;
    }
}
