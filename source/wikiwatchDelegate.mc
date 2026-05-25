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

    // M6: long-press a word → push a keyboard layer pre-filled with the
    // tapped word. Lets the user drill down into a related article from
    // the reader. Words are dispatched via wikiwatchView.findWordAt (which
    // delegates to the pure WordHitTest module).
    //
    // Diagnostic stays in the shipped build — one System.println per
    // long-press, harmless. Doubles as R2 evidence that BehaviorDelegate
    // .onHold fires on the Venu 2 touchscreen (the project's "pending
    // spike" from the handoff).
    function onHold(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var x = coords[0];
        var y = coords[1];
        System.println("M6 onHold: x=" + x + " y=" + y);
        var word = _view.findWordAt(x, y);
        if (word != null) {
            System.println("M6 onHold: word='" + word + "' — pushing keyboard layer");
            var kbView = new wikiwatchKeyboardView();
            var kbDelegate = new wikiwatchKeyboardDelegate(kbView, word as String);
            WatchUi.pushView(kbView, kbDelegate, WatchUi.SLIDE_LEFT);
        } else {
            System.println("M6 onHold: no word at tap — ignored");
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
