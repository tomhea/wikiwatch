import Toybox.Lang;

// M8 pure battery-gating thresholds. The watch refuses to START (or resume)
// an install when battery is critically low and not charging; and PAUSES an
// in-progress install at an even lower threshold. Pure (Toybox.Lang only) so
// the thresholds are unit-testable; callers pass System.Stats.battery +
// .charging.
//
// Rationale for the !charging escape: a watch on the charger at 5% is heading
// up, so the install can safely proceed. We only refuse on low AND unplugged.
//
// R6: this module imports only Toybox.Lang.
module BatteryGate {
    const START_MIN_PCT = 10.0;   // need >=10% (or charging) to begin/resume
    const PAUSE_MIN_PCT  = 5.0;    // pause if drops below 5% (and unplugged)

    // Block starting/resuming an install? True when battery is below the
    // start threshold AND not charging. A watch on the charger is heading up,
    // so an install can safely proceed regardless of the current level.
    function shouldGate(batteryPct as Float, charging as Boolean) as Boolean {
        return batteryPct < START_MIN_PCT && !charging;
    }

    // Pause an already-running install? True when battery has dropped below
    // the (lower) pause threshold AND not charging.
    function shouldPause(batteryPct as Float, charging as Boolean) as Boolean {
        return batteryPct < PAUSE_MIN_PCT && !charging;
    }
}
