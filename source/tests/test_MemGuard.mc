import Toybox.Lang;
import Toybox.Test;

// M9.6 tests for MemGuard — the free-memory gate on view pushes.

(:test)
function memGuard_blocksBelowThreshold(logger as Logger) as Boolean {
    logger.debug("min=" + MemGuard.MIN_FREE_BYTES);
    return MemGuard.canOpen(MemGuard.MIN_FREE_BYTES - 1) == false
        && MemGuard.canOpen(0) == false
        && MemGuard.canOpen(100000) == false;     // 100 KB < 150 KB
}

(:test)
function memGuard_allowsAtOrAboveThreshold(logger as Logger) as Boolean {
    return MemGuard.canOpen(MemGuard.MIN_FREE_BYTES) == true
        && MemGuard.canOpen(MemGuard.MIN_FREE_BYTES + 1) == true
        && MemGuard.canOpen(700000) == true;       // healthy heap
}

(:test)
function memGuard_thresholdIs150kb(logger as Logger) as Boolean {
    return MemGuard.MIN_FREE_BYTES == 150 * 1024;
}
