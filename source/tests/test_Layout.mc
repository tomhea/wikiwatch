import Toybox.Lang;
import Toybox.Test;

// Tests for Layout.middleWidth. Two cases: the M2.5 input that produced
// _middleWidth=421, and the M2.6 input that produces 406. Both are real
// configurations used by the view, so this also serves as a regression net
// for any future margin tweak.

(:test)
function layout_middleWidthM25Baseline(logger as Logger) as Boolean {
    // M2.5: screenW=416, leftMargin=15, rightBleed=20 -> 421.
    var v = Layout.middleWidth(416, 15, 20);
    logger.debug("Layout.middleWidth(416, 15, 20) = " + v);
    return v == 421;
}

(:test)
function layout_middleWidthM26Inputs(logger as Logger) as Boolean {
    // M2.6: screenW=416, leftMargin=30, rightBleed=20 -> 406.
    var v = Layout.middleWidth(416, 30, 20);
    logger.debug("Layout.middleWidth(416, 30, 20) = " + v);
    return v == 406;
}