import Toybox.Lang;
import Toybox.Test;

// M9.7 tests for LongPress — physical-back hold-duration check.

(:test)
function longPress_longHoldIsLong(logger as Logger) as Boolean {
    return LongPress.isLong(1000, 1700, 600) == true
        && LongPress.isLong(1000, 1600, 600) == true;   // exactly the threshold
}

(:test)
function longPress_shortHoldIsNot(logger as Logger) as Boolean {
    return LongPress.isLong(1000, 1200, 600) == false
        && LongPress.isLong(1000, 1000, 600) == false;  // 0 ms held
}

(:test)
function longPress_guardsBadInput(logger as Logger) as Boolean {
    return LongPress.isLong(-1, 5000, 600) == false      // no down recorded
        && LongPress.isLong(1000, 900, 600) == false;    // up before down
}

(:test)
function longPress_backHoldThreshold(logger as Logger) as Boolean {
    return LongPress.BACK_HOLD_MS == 600;
}
