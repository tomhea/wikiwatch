import Toybox.Lang;
import Toybox.Test;

// M9.7 tests for CloseQuery — centered "Close app?" button hit-test.

(:test)
function closeQuery_centerHits(logger as Logger) as Boolean {
    return CloseQuery.buttonHit(208, 208, 416, 416) == true;   // dead center
}

(:test)
function closeQuery_cornersMiss(logger as Logger) as Boolean {
    return CloseQuery.buttonHit(10, 10, 416, 416) == false
        && CloseQuery.buttonHit(400, 400, 416, 416) == false
        && CloseQuery.buttonHit(208, 10, 416, 416) == false;   // above the button
}

(:test)
function closeQuery_edgesRespectBox(logger as Logger) as Boolean {
    var cx = 208;
    var cy = 208;
    // just inside vs just outside the right edge
    return CloseQuery.buttonHit(cx + CloseQuery.BTN_W / 2 - 1, cy, 416, 416) == true
        && CloseQuery.buttonHit(cx + CloseQuery.BTN_W / 2 + 1, cy, 416, 416) == false;
}
