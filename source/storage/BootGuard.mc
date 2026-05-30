import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// M9.4: anti-crash-loop safety net.
//
// The M9.3 real-watch hang was self-perpetuating: the install→keyboard
// transition tipped the device into an uncatchable OOM, the firmware
// relaunched the app, and every relaunch re-hit the same wall — a crash loop
// that presented as a permanent black screen until a forced reboot wedged the
// watch badly enough that the firmware did a recovery reset.
//
// BootGuard breaks that loop with a persisted breadcrumb:
//   - noteBootStart() runs at the very top of getInitialView, BEFORE any heavy
//     index/corpus work, and increments a stored counter.
//   - noteReady() runs when a stable, interactive view is actually on screen
//     (keyboard ready / article reader / the safe screen) and clears it.
// A boot that hangs or OOMs never reaches noteReady(), so the counter survives
// to the next boot. Once two consecutive boots fail to finish, the next boot
// enters SAFE MODE (shouldEnterSafeMode) and skips ALL heavy loading, showing a
// minimal recoverable screen instead. This guarantees the watch can always be
// brought back to an interactive state — a too-large corpus degrades to a
// visible safe screen rather than bricking the device.
//
// R6: source/storage — touches Application.Storage.
module BootGuard {
    const KEY_ATTEMPTS = "bootAttempts";
    // Enter safe mode on the 2nd consecutive boot that never reached ready.
    // A successful boot always resets the counter to 0, so this only fires
    // after a genuine repeated failure — recovery is fast, false-positives need
    // two un-finished boots in a row.
    const SAFE_MODE_THRESHOLD = 2;

    // Pure: given this many consecutive unfinished boots, should this boot skip
    // the heavy path and show the safe screen?
    function shouldEnterSafeMode(attempts as Number) as Boolean {
        return attempts >= SAFE_MODE_THRESHOLD;
    }

    function getAttempts() as Number {
        var a = Application.Storage.getValue(KEY_ATTEMPTS) as Number?;
        return a == null ? 0 : a;
    }

    // Increment + persist the breadcrumb, returning the new count. Call once at
    // the very start of getInitialView. The counter is a single small Number;
    // R4 guard is token (boot-time free memory is plentiful) but unconditional.
    function noteBootStart() as Number {
        var next = getAttempts() + 1;
        if (System.getSystemStats().freeMemory >= 64) {
            Application.Storage.setValue(KEY_ATTEMPTS, next);
        }
        return next;
    }

    // Clear the breadcrumb — the boot reached a stable interactive state.
    function noteReady() as Void {
        Application.Storage.deleteValue(KEY_ATTEMPTS);
    }
}
