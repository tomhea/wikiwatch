import Toybox.Lang;
import Toybox.Test;

// M10.4 tests for the recently-read list: pure Recents.add (front-insert / dedup /
// cap) and the RecentsStore persistence roundtrip.

// --- pure Recents.add ---

(:test)
function recents_addToEmptyPutsEntryFirst(logger as Logger) as Boolean {
    var r = Recents.add([], "3", "שלום", 12);
    logger.debug("add to empty size=" + r.size());
    return r.size() == 1
        && (r[0] as Dictionary)[:id].equals("3")
        && (r[0] as Dictionary)[:title].equals("שלום");
}

(:test)
function recents_addMovesExistingToFrontNoDup(logger as Logger) as Boolean {
    // Open 3, then 7, then 3 again -> 3 is first, only ONE copy of 3.
    var r = Recents.add([], "3", "a", 12);
    r = Recents.add(r, "7", "b", 12);
    r = Recents.add(r, "3", "a", 12);
    logger.debug("after re-open 3: " + _ids(r));
    return r.size() == 2
        && (r[0] as Dictionary)[:id].equals("3")
        && (r[1] as Dictionary)[:id].equals("7");
}

(:test)
function recents_capsToOldestDropped(logger as Logger) as Boolean {
    // Cap 3: opening 1,2,3,4 keeps 4,3,2 (1 falls off the tail).
    var r = [];
    r = Recents.add(r, "1", "t1", 3);
    r = Recents.add(r, "2", "t2", 3);
    r = Recents.add(r, "3", "t3", 3);
    r = Recents.add(r, "4", "t4", 3);
    logger.debug("capped: " + _ids(r));
    return r.size() == 3
        && (r[0] as Dictionary)[:id].equals("4")
        && (r[1] as Dictionary)[:id].equals("3")
        && (r[2] as Dictionary)[:id].equals("2");
}

// --- RecentsStore persistence (sim Storage) ---

(:test)
function recentsStore_recordLoadRoundtrip(logger as Logger) as Boolean {
    RecentsStore.clear();
    RecentsStore.record("5", "תורה");
    RecentsStore.record("9", "שבת");
    var r = RecentsStore.load();
    logger.debug("store roundtrip: " + _ids(r));
    var ok = r.size() == 2
        && (r[0] as Dictionary)[:id].equals("9")        // most-recent first
        && (r[0] as Dictionary)[:title].equals("שבת")
        && (r[1] as Dictionary)[:id].equals("5");
    RecentsStore.clear();
    return ok;
}

(:test)
function recentsStore_dedupAndClear(logger as Logger) as Boolean {
    RecentsStore.clear();
    RecentsStore.record("5", "a");
    RecentsStore.record("8", "b");
    RecentsStore.record("5", "a");      // re-open 5 -> front, no dup
    var r = RecentsStore.load();
    var dedup = r.size() == 2 && (r[0] as Dictionary)[:id].equals("5");
    RecentsStore.clear();
    var empty = RecentsStore.load().size() == 0;
    logger.debug("dedup=" + dedup + " emptyAfterClear=" + empty);
    return dedup && empty;
}

(:test)
function recentsStore_loadEmptyWhenUnset(logger as Logger) as Boolean {
    RecentsStore.clear();
    var r = RecentsStore.load();
    logger.debug("load unset size=" + r.size());
    return r.size() == 0;
}

function _ids(r as Array) as String {
    var s = "[";
    for (var i = 0; i < r.size(); i++) {
        if (i > 0) { s = s + ","; }
        s = s + ((r[i] as Dictionary)[:id] as String);
    }
    return s + "]";
}
