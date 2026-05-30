import Toybox.Lang;
import Toybox.Test;
import Toybox.Application;

// M9.4: BootGuard is the anti-crash-loop safety net. The real-watch M9.3 hang
// crash-looped the device (every relaunch re-hit the OOM) until a forced reboot.
// BootGuard drops a persisted breadcrumb at boot start (before any heavy index
// work) and clears it only when a stable interactive view is reached. If two
// consecutive boots fail to reach "ready", the next boot enters safe mode and
// skips all heavy loading — so a too-large corpus degrades to a visible safe
// screen instead of wedging the watch. These tests pin the pure threshold +
// the Storage-backed counter lifecycle.

(:test)
function bootGuard_shouldEnterSafeModeAtThreshold(logger as Logger) as Boolean {
    // Pure decision: 0/1 unfinished boots are fine; the 2nd triggers safe mode.
    logger.debug("0=" + BootGuard.shouldEnterSafeMode(0)
        + " 1=" + BootGuard.shouldEnterSafeMode(1)
        + " 2=" + BootGuard.shouldEnterSafeMode(2)
        + " 3=" + BootGuard.shouldEnterSafeMode(3));
    return BootGuard.shouldEnterSafeMode(0) == false
        && BootGuard.shouldEnterSafeMode(1) == false
        && BootGuard.shouldEnterSafeMode(2) == true
        && BootGuard.shouldEnterSafeMode(3) == true;
}

(:test)
function bootGuard_noteBootStartIncrements(logger as Logger) as Boolean {
    BootGuard.noteReady();                 // reset to a known clean state
    var a = BootGuard.noteBootStart();     // 0 -> 1
    var b = BootGuard.noteBootStart();     // 1 -> 2
    logger.debug("first=" + a + " second=" + b + " stored=" + BootGuard.getAttempts());
    return a == 1 && b == 2 && BootGuard.getAttempts() == 2;
}

(:test)
function bootGuard_noteReadyResets(logger as Logger) as Boolean {
    BootGuard.noteReady();
    BootGuard.noteBootStart();             // 1
    BootGuard.noteBootStart();             // 2
    BootGuard.noteReady();                 // a successful boot clears the breadcrumb
    logger.debug("after ready attempts=" + BootGuard.getAttempts());
    return BootGuard.getAttempts() == 0;
}

(:test)
function bootGuard_safeModeRecoversAfterReady(logger as Logger) as Boolean {
    // Two failed boots -> safe mode; reaching ready in safe mode clears it so
    // the NEXT boot is normal again (the watch isn't stuck in safe mode forever).
    BootGuard.noteReady();
    BootGuard.noteBootStart();             // 1
    var second = BootGuard.noteBootStart();// 2 -> safe mode this boot
    var inSafe = BootGuard.shouldEnterSafeMode(second);
    BootGuard.noteReady();                 // safe-mode screen reached + interacted
    var nextBoot = BootGuard.noteBootStart();
    logger.debug("inSafe=" + inSafe + " nextBoot=" + nextBoot);
    return inSafe == true && nextBoot == 1 && BootGuard.shouldEnterSafeMode(nextBoot) == false;
}
