import Toybox.Lang;
import Toybox.Test;

// M8 tests for the pure BatteryGate thresholds.

(:test)
function batteryGate_gatesBelow10NotCharging(logger as Logger) as Boolean {
    var r = BatteryGate.shouldGate(9.0, false);
    logger.debug("shouldGate(9%,unplugged) = " + r);
    return r == true;
}

(:test)
function batteryGate_allowsAt10NotCharging(logger as Logger) as Boolean {
    // exactly the threshold is allowed (>= 10)
    return BatteryGate.shouldGate(10.0, false) == false;
}

(:test)
function batteryGate_allowsLowWhenCharging(logger as Logger) as Boolean {
    // 5% but on the charger -> heading up, proceed
    return BatteryGate.shouldGate(5.0, true) == false;
}

(:test)
function batteryGate_pausesBelow5NotCharging(logger as Logger) as Boolean {
    var r = BatteryGate.shouldPause(4.0, false);
    logger.debug("shouldPause(4%,unplugged) = " + r);
    return r == true;
}

(:test)
function batteryGate_doesNotPauseAt5(logger as Logger) as Boolean {
    return BatteryGate.shouldPause(5.0, false) == false;
}

(:test)
function batteryGate_doesNotPauseWhenCharging(logger as Logger) as Boolean {
    return BatteryGate.shouldPause(2.0, true) == false;
}
