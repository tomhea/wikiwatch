import Toybox.Lang;
import Toybox.Test;

// M8 tests for the pure InstallPlan orchestration module (chunk bitmap +
// fetch scheduling + completion / invalidation math). No Storage/network.

(:test)
function installPlan_sortedInsertIntoEmpty(logger as Logger) as Boolean {
    var r = InstallPlan.sortedInsert([] as Array<Number>, 5);
    logger.debug("insert 5 into [] -> " + r);
    return r.size() == 1 && r[0] == 5;
}

(:test)
function installPlan_sortedInsertKeepsOrder(logger as Logger) as Boolean {
    var r = InstallPlan.sortedInsert([1, 5] as Array<Number>, 3);
    logger.debug("insert 3 into [1,5] -> " + r);
    return r.size() == 3 && r[0] == 1 && r[1] == 3 && r[2] == 5;
}

(:test)
function installPlan_sortedInsertNoDuplicate(logger as Logger) as Boolean {
    var r = InstallPlan.sortedInsert([1, 3, 5] as Array<Number>, 3);
    logger.debug("insert dup 3 -> " + r);
    return r.size() == 3;
}

(:test)
function installPlan_sortedInsertAtEnd(logger as Logger) as Boolean {
    var r = InstallPlan.sortedInsert([1, 2] as Array<Number>, 9);
    return r.size() == 3 && r[2] == 9;
}

(:test)
function installPlan_firstMissingBasic(logger as Logger) as Boolean {
    var r = InstallPlan.firstMissing([0, 1, 5] as Array<Number>, 10);
    logger.debug("firstMissing([0,1,5],10) = " + r);
    return r == 2;
}

(:test)
function installPlan_firstMissingAllPresent(logger as Logger) as Boolean {
    var r = InstallPlan.firstMissing([0, 1, 2] as Array<Number>, 3);
    logger.debug("firstMissing all present -> " + r);
    return r == -1;
}

(:test)
function installPlan_firstMissingEmpty(logger as Logger) as Boolean {
    var r = InstallPlan.firstMissing([] as Array<Number>, 5);
    return r == 0;
}

(:test)
function installPlan_missingChunksBasic(logger as Logger) as Boolean {
    var r = InstallPlan.missingChunks([0, 1, 5] as Array<Number>, 7);
    logger.debug("missingChunks([0,1,5],7) -> " + r);
    return r.size() == 4 && r[0] == 2 && r[1] == 3 && r[2] == 4 && r[3] == 6;
}

(:test)
function installPlan_missingChunksNoneLeft(logger as Logger) as Boolean {
    var r = InstallPlan.missingChunks([0, 1, 2] as Array<Number>, 3);
    return r.size() == 0;
}

(:test)
function installPlan_slotsToFillClamps(logger as Logger) as Boolean {
    var a = InstallPlan.slotsToFill(1, 2, 10);  // 1 free slot
    var b = InstallPlan.slotsToFill(0, 2, 1);   // remaining limits to 1
    var c = InstallPlan.slotsToFill(2, 2, 5);   // full -> 0
    logger.debug("slots a=" + a + " b=" + b + " c=" + c);
    return a == 1 && b == 1 && c == 0;
}

(:test)
function installPlan_slotsToFillNeverNegative(logger as Logger) as Boolean {
    var r = InstallPlan.slotsToFill(3, 2, 5);   // inFlight > max -> 0
    return r == 0;
}

(:test)
function installPlan_isCompleteTrue(logger as Logger) as Boolean {
    return InstallPlan.isComplete(100, 100) == true;
}

(:test)
function installPlan_isCompleteFalse(logger as Logger) as Boolean {
    return InstallPlan.isComplete(99, 100) == false;
}

(:test)
function installPlan_shouldInvalidateOnVersionBump(logger as Logger) as Boolean {
    return InstallPlan.shouldInvalidate(4, 5) == true;
}

(:test)
function installPlan_shouldNotInvalidateSameVersion(logger as Logger) as Boolean {
    return InstallPlan.shouldInvalidate(5, 5) == false;
}

(:test)
function installPlan_maxInFlightTwoWhenAmpleMemory(logger as Logger) as Boolean {
    var r = InstallPlan.maxInFlightForMemory(500 * 1024);
    logger.debug("maxInFlight(500KB) = " + r);
    return r == 2;
}

(:test)
function installPlan_maxInFlightOneUnderPressure(logger as Logger) as Boolean {
    var r = InstallPlan.maxInFlightForMemory(399 * 1024);
    logger.debug("maxInFlight(399KB) = " + r);
    return r == 1;
}

(:test)
function installPlan_sampleIndicesEvenlySpaced(logger as Logger) as Boolean {
    var r = InstallPlan.sampleIndices(180, 5);
    logger.debug("sampleIndices(180,5) = " + r);
    return r.size() == 5 && r[0] == 0 && r[4] == 179
        && r[1] > 0 && r[1] < r[2] && r[2] < r[3] && r[3] < 179;
}

(:test)
function installPlan_sampleIndicesFewerThanN(logger as Logger) as Boolean {
    var r = InstallPlan.sampleIndices(3, 5);
    logger.debug("sampleIndices(3,5) = " + r);
    return r.size() == 3 && r[0] == 0 && r[1] == 1 && r[2] == 2;
}

(:test)
function installPlan_sampleIndicesEmpty(logger as Logger) as Boolean {
    return InstallPlan.sampleIndices(0, 5).size() == 0;
}

(:test)
function installPlan_sampleIndicesOne(logger as Logger) as Boolean {
    var r = InstallPlan.sampleIndices(1, 5);
    return r.size() == 1 && r[0] == 0;
}

(:test)
function installPlan_storageBudgetStop(logger as Logger) as Boolean {
    // Below budget -> keep going; at/above -> stop.
    var b = InstallPlan.STORAGE_BUDGET_BYTES;
    logger.debug("budget=" + b);
    return b == 9000000
        && InstallPlan.shouldStopAtBudget(0) == false
        && InstallPlan.shouldStopAtBudget(b - 1) == false
        && InstallPlan.shouldStopAtBudget(b) == true
        && InstallPlan.shouldStopAtBudget(b + 100) == true;
}

(:test)
function installPlan_estimateBytesFromChars(logger as Logger) as Boolean {
    // M10.6: the install stores COMPRESSED bodies — base64 (ASCII, 1 byte/char),
    // not raw 2-byte Hebrew. The install-budget byte estimate must therefore be
    // 1x the stored-string length. At 2x it over-counts and falsely trips
    // STORAGE_BUDGET_BYTES at ~half the corpus (the sim install stalled at
    // 1447/2800 with budgetStopped=true before this fix).
    return InstallPlan.estimateBytes(0) == 0
        && InstallPlan.estimateBytes(100) == 100;
}

// --- M10.6: concurrency 4 when memory is plentiful + adaptive -101 back-off ---

(:test)
function installPlan_maxInFlightFourWhenPlentiful(logger as Logger) as Boolean {
    // At/above MEM_AMPLE_BYTES (550 KB) we go optimistic with 4 concurrent
    // chunk requests — fewer BLE round-trips. The -101 back-off + memory
    // step-down degrade it automatically when the watch can't keep up.
    var a = InstallPlan.maxInFlightForMemory(550 * 1024);  // boundary
    var b = InstallPlan.maxInFlightForMemory(700 * 1024);  // plentiful
    logger.debug("maxInFlight(550KB)=" + a + " (700KB)=" + b);
    return a == 4 && b == 4;
}

(:test)
function installPlan_maxInFlightTwoJustBelowAmple(logger as Logger) as Boolean {
    // Just under the ample threshold stays at the comfortable 2 (the existing
    // 500KB->2 band is unchanged).
    var r = InstallPlan.maxInFlightForMemory(549 * 1024);
    logger.debug("maxInFlight(549KB) = " + r);
    return r == 2;
}

(:test)
function installPlan_backoffRatchetsDownByOne(logger as Logger) as Boolean {
    // On a -101 (BLE queue full) the in-flight ceiling drops by one.
    var r = InstallPlan.backoffMaxInFlight(4);
    logger.debug("backoff(4) = " + r);
    return r == 3;
}

(:test)
function installPlan_backoffFloorsAtTwo(logger as Logger) as Boolean {
    // The ceiling never falls below 2 — the install keeps a little parallelism.
    var a = InstallPlan.backoffMaxInFlight(3);
    var b = InstallPlan.backoffMaxInFlight(2);
    logger.debug("backoff(3)=" + a + " backoff(2)=" + b);
    return a == 2 && b == 2;
}

// --- M10.8: effective concurrency = min(memory tier, back-off ceiling) ---

(:test)
function installPlan_effectiveMaxInFlightIsMin(logger as Logger) as Boolean {
    // The install's live concurrency is the lower of the memory-derived tier and
    // the persistent -101 back-off ceiling, so neither a memory-recovery tick nor
    // a high memory tier can re-raise concurrency past what the BLE stack proved.
    var a = InstallPlan.effectiveMaxInFlight(4, 4);   // both 4
    var b = InstallPlan.effectiveMaxInFlight(4, 2);   // ceiling caps -> 2
    var c = InstallPlan.effectiveMaxInFlight(2, 4);   // memory caps -> 2
    var d = InstallPlan.effectiveMaxInFlight(1, 3);   // memory pressure -> 1
    logger.debug("eff: " + a + " " + b + " " + c + " " + d);
    return a == 4 && b == 2 && c == 2 && d == 1;
}
