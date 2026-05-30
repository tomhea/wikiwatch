import Toybox.Lang;

// M9.4: pure formatting for the on-screen free-memory HUD. The simulator can't
// reproduce the real-watch OOM/GC freeze, so the watch screen itself is our
// only instrument during the corpus size sweep — every heavy phase draws a
// MemHud line so a too-large corpus reports its last free-memory value + the
// phase it died in. Pure (Toybox.Lang only) so the formatting is unit-pinned;
// the live System.getSystemStats().freeMemory read happens at the call site.
//
// R6: source/models — imports only Toybox.Lang.
module MemHud {
    // Whole kilobytes (floor). 412874 -> 403.
    function kb(bytes as Number) as Number {
        return bytes / 1024;
    }

    // Compact HUD line, e.g. "free 403k". Drawn in a screen corner during
    // install / index-build / keyboard-ready and on the safe screen.
    function line(freeBytes as Number) as String {
        return "free " + kb(freeBytes) + "k";
    }

    // Phase-tagged variant, e.g. "idx free 403k" — `tag` names the phase the
    // reading was taken in so a hardware hang report pins the exact step.
    function tagged(tag as String, freeBytes as Number) as String {
        return tag + " " + line(freeBytes);
    }
}
