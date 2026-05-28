import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// M7.2: pin the post-check transition to SLIDE_IMMEDIATE. The previous
// SLIDE_LEFT value made the keyboard look like it slid in on top of
// itself (UpdateCheckView already renders the keyboard underneath, so
// any sliding animation produces a duplicate-keyboard-on-top illusion).
// SLIDE_IMMEDIATE removes the animation: "checking for updates..."
// text just vanishes + the delegate gets swapped to the functional one.

(:test)
function updateCheck_usesImmediateTransition(logger as Logger) as Boolean {
    var v = new UpdateCheckView();
    var t = v.transitionToKeyboard();
    logger.debug("transitionToKeyboard() = " + t
        + " (SLIDE_IMMEDIATE = " + WatchUi.SLIDE_IMMEDIATE + ")");
    return t == WatchUi.SLIDE_IMMEDIATE;
}
