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
