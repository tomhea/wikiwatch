import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchDelegate extends WatchUi.BehaviorDelegate {
    private var _view as wikiwatchView;

    function initialize(view as wikiwatchView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Swipe up (or KEY_DOWN button on the simulator) - scroll article downward.
    function onNextPage() as Boolean {
        _view.scrollBy(60);
        return true;
    }

    // Swipe down (or KEY_UP) - scroll article upward.
    function onPreviousPage() as Boolean {
        _view.scrollBy(-60);
        return true;
    }
}