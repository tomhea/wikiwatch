import Toybox.Lang;
import Toybox.Test;

// Tests for Layout.middleWidth. M2.7 semantics: both leftMargin and
// rightMargin are CLEAN gaps (subtracted from screen width). Case 1 is the
// real M2.7 configuration (the regression target); Case 2 uses a different
// screen size to exercise the formula independently of the sim screen.

(:test)
function layout_middleWidthM27Baseline(logger as Logger) as Boolean {
    // M2.7: screenW=416, leftMargin=25, rightMargin=100 -> 291.
    var v = Layout.middleWidth(416, 25, 100);
    logger.debug("Layout.middleWidth(416, 25, 100) = " + v);
    return v == 291;
}

(:test)
function layout_middleWidthDifferentScreen(logger as Logger) as Boolean {
    // Sanity at a different screen size: 400, 20, 80 -> 300.
    var v = Layout.middleWidth(400, 20, 80);
    logger.debug("Layout.middleWidth(400, 20, 80) = " + v);
    return v == 300;
}