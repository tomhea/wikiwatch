import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class wikiwatchDelegate extends WatchUi.BehaviorDelegate {
    private const DOUBLE_TAP_INTERVAL_MS = 300;
    private const DOUBLE_TAP_Y_TOLERANCE = 80;
    private const EDGE_ZONE_PX = 50;

    private var _view as wikiwatchView;
    private var _lastDragY as Number?;
    private var _lastTapMs as Number;
    private var _lastTapY as Number;

    function initialize(view as wikiwatchView) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastDragY = null;
        _lastTapMs = 0;
        _lastTapY = 0;
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

    // M2.5: double-tap nav. A fast double-tap near the top jumps the
    // article to scrollY=0; near the bottom jumps to maxScroll. In the
    // middle does nothing. Single tap is silent (handled implicitly by the
    // (prevMs == 0) branch of isDoubleTap on the first tap). State is
    // updated on EVERY tap so the next tap can pair with it.
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var y = coords[1];
        var now = System.getTimer();
        var isDouble = DoubleTap.isDoubleTap(_lastTapMs, _lastTapY,
                                             now, y,
                                             DOUBLE_TAP_INTERVAL_MS,
                                             DOUBLE_TAP_Y_TOLERANCE);
        if (isDouble) {
            if (y < EDGE_ZONE_PX) {
                _view.scrollToTop();
            } else if (y > _view.getScreenHeight() - EDGE_ZONE_PX
                       && _view.isLayoutComplete()) {
                // M5.4: ignore bottom double-tap until lazy layout is
                // done — there's no fully-laid-out bottom yet, and the
                // scroll-clamp would dump the user in the middle of
                // partially-rendered content.
                _view.scrollToBottom();
            }
        }
        _lastTapMs = now;
        _lastTapY = y;
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
