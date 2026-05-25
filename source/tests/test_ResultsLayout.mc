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

// --- M5.3: ResultsLayout.blockAt (variable-height row hit-test) ---

(:test)
function resultsLayout_blockAtInsideFirstReturnsZero(logger as Logger) as Boolean {
    var blocks = [
        { :top => 0,  :height => 50 },
        { :top => 66, :height => 30 }
    ];
    var r = ResultsLayout.blockAt(30, blocks);
    logger.debug("blockAt(30, ...) = " + r);
    return r != null && (r as Number) == 0;
}

(:test)
function resultsLayout_blockAtInsideSecondReturnsOne(logger as Logger) as Boolean {
    var blocks = [
        { :top => 0,  :height => 50 },
        { :top => 66, :height => 30 }
    ];
    var r = ResultsLayout.blockAt(80, blocks);
    logger.debug("blockAt(80, ...) = " + r);
    return r != null && (r as Number) == 1;
}

(:test)
function resultsLayout_blockAtInGapReturnsNull(logger as Logger) as Boolean {
    var blocks = [
        { :top => 0,  :height => 50 },
        { :top => 66, :height => 30 }
    ];
    // contentY=60 is in the gap between block 0 (ends at 50) and block 1 (starts at 66).
    var r = ResultsLayout.blockAt(60, blocks);
    logger.debug("blockAt(60 in gap) = " + r);
    return r == null;
}

(:test)
function resultsLayout_blockAtPastEndReturnsNull(logger as Logger) as Boolean {
    var blocks = [
        { :top => 0,  :height => 50 },
        { :top => 66, :height => 30 }
    ];
    var r = ResultsLayout.blockAt(9999, blocks);
    logger.debug("blockAt(9999 past end) = " + r);
    return r == null;
}

(:test)
function resultsLayout_blockAtNegativeReturnsNull(logger as Logger) as Boolean {
    var blocks = [
        { :top => 0, :height => 50 }
    ];
    var r = ResultsLayout.blockAt(-5, blocks);
    logger.debug("blockAt(-5) = " + r);
    return r == null;
}

(:test)
function resultsLayout_blockAtEmptyArrayReturnsNull(logger as Logger) as Boolean {
    var r = ResultsLayout.blockAt(0, []);
    logger.debug("blockAt(0, []) = " + r);
    return r == null;
}
