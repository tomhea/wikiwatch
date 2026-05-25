import Toybox.Lang;
import Toybox.Test;

// M5.1 tests for ResultsLayout.rowIndexAt — the pure geometry helper
// behind ResultsView's tap-to-open hit-test.
//
// Contract:
//   rowIndexAt(y, scrollY, rowHeight, rowCount):
//     - returns row index (0-based) at the given SCREEN y, accounting
//       for the current scroll offset.
//     - returns null when the (y + scrollY) is past the end of the list
//       or before the top.
//     - returns null when rowHeight <= 0 or rowCount <= 0 (defensive).

(:test)
function resultsLayout_rowIndexAtInsideTopRowReturnsZero(logger as Logger) as Boolean {
    var r = ResultsLayout.rowIndexAt(30, 0, 60, 5);
    logger.debug("rowIndexAt(30,0,60,5) = " + r);
    return r != null && (r as Number) == 0;
}

(:test)
function resultsLayout_rowIndexAtOutsideListReturnsNull(logger as Logger) as Boolean {
    var r = ResultsLayout.rowIndexAt(9999, 0, 60, 5);
    logger.debug("rowIndexAt(9999,0,60,5) = " + r);
    return r == null;
}

(:test)
function resultsLayout_rowIndexAtRespectsScroll(logger as Logger) as Boolean {
    // y=30 at scrollY=120 puts contentY=150 -> row 150/60 = 2 (3rd row).
    var r = ResultsLayout.rowIndexAt(30, 120, 60, 5);
    logger.debug("rowIndexAt(30,120,60,5) = " + r);
    return r != null && (r as Number) == 2;
}
