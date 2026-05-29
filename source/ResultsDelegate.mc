import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M5.1 delegate for ResultsView. Drag-to-scroll + tap-to-open. Back
// returns false so CIQ pops the view (back to keyboard with buffer
// preserved).
class ResultsDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ResultsView;
    private var _lastDragY as Number?;

    function initialize(view as ResultsView) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastDragY = null;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var hit = _view.rowAt(coords[0], coords[1]);
        if (hit != null) {
            var s = hit as Dictionary;
            var body = ArticleStore.bodyOf(s[:id] as String);
            if (body != null) {
                var reader = new wikiwatchView(body, s[:id] as String);
                WatchUi.pushView(reader, new wikiwatchDelegate(reader), WatchUi.SLIDE_LEFT);
            }
        }
        return true;
    }

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
            _view.scrollBy(-delta);
            _lastDragY = currentY;
            return true;
        }
        if (type == WatchUi.DRAG_TYPE_STOP) {
            _lastDragY = null;
        }
        return true;
    }

    function onNextPage() as Boolean {
        _view.scrollBy(60);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollBy(-60);
        return true;
    }

    function onBack() as Boolean {
        return false;
    }
}
