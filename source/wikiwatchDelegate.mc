import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchDelegate extends WatchUi.BehaviorDelegate {
    private var _view as wikiwatchView;
    private var _lastDragY as Number?;

    function initialize(view as wikiwatchView) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastDragY = null;
    }

    // M2.1: live finger-tracking scroll. onDrag fires repeatedly during a
    // touch drag (CIQ 3.2+ on touchscreen devices like Venu 2). On every
    // CONTINUE event we forward the delta to the view so the article moves
    // with the finger instead of waiting for release.
    function onDrag(event as WatchUi.DragEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var currentY = coords[1];
        var type = event.getType();
        if (type == WatchUi.DRAG_TYPE_START) {
            _lastDragY = currentY;
            return true;
        }
        if (type == WatchUi.DRAG_TYPE_CONTINUE) {
            var last = _lastDragY;
            if (last == null) {
                _lastDragY = currentY;
                return true;
            }
            var delta = currentY - last;
            // finger moves up (delta < 0) -> content scrolls up -> scrollY increases.
            _view.scrollBy(-delta);
            _lastDragY = currentY;
            return true;
        }
        if (type == WatchUi.DRAG_TYPE_STOP) {
            _lastDragY = null;
        }
        return true;
    }

    // Page/button fallback for accessibility and discrete steps.
    function onNextPage() as Boolean {
        _view.scrollBy(60);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollBy(-60);
        return true;
    }
}