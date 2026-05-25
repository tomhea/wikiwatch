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

// --- M5.2: ResultsLayout.moreArticlesText ---

(:test)
function resultsLayout_moreArticlesTextZeroReturnsNull(logger as Logger) as Boolean {
    var r = ResultsLayout.moreArticlesText(10, 10);
    logger.debug("moreArticlesText(10, 10) = " + r);
    return r == null;
}

(:test)
function resultsLayout_moreArticlesTextOneReturnsSingular(logger as Logger) as Boolean {
    var r = ResultsLayout.moreArticlesText(11, 10);
    logger.debug("moreArticlesText(11, 10) = " + r);
    return r != null && (r as String).equals("1 more article fits");
}

(:test)
function resultsLayout_moreArticlesTextMultipleReturnsPlural(logger as Logger) as Boolean {
    var r = ResultsLayout.moreArticlesText(15, 10);
    logger.debug("moreArticlesText(15, 10) = " + r);
    return r != null && (r as String).equals("5 more articles fit");
}

(:test)
function resultsLayout_moreArticlesTextNegativeReturnsNull(logger as Logger) as Boolean {
    // Defensive: displayed > total shouldn't happen but must be safe.
    var r = ResultsLayout.moreArticlesText(5, 10);
    logger.debug("moreArticlesText(5, 10) = " + r);
    return r == null;
}
