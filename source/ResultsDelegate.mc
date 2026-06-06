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

        // M10.8: while the "Close app?" modal is up, tap-in-button exits, tap
        // elsewhere cancels (physical back also cancels).
        if (_view.isCloseQuery()) {
            var s = System.getDeviceSettings();
            if (CloseQuery.buttonHit(coords[0], coords[1], s.screenWidth, s.screenHeight)) {
                System.println("M10.8: close app confirmed (results) — exiting");
                System.exit();
            } else {
                _view.setCloseQuery(false);
            }
            return true;
        }

        var hit = _view.rowAt(coords[0], coords[1]);
        if (hit != null) {
            // M9.6: low-memory gate — don't open the reader (uncatchable OOM risk).
            // ResultsView renders the yellow "max open articles" notice.
            if (!MemGuard.canOpen(System.getSystemStats().freeMemory)) {
                System.println("M9.6: open-article blocked (low memory)");
                WatchUi.requestUpdate();
                return true;
            }
            var s = hit as Dictionary;
            var stored = ArticleStore.bodyOf(s[:id] as String);
            // M10.1: route plain vs compressed. A compressed body is decoded
            // across event-loop turns (DecodeView) to stay watchdog-safe.
            // M10.4: ArticleOpener records the open into the recently-read list.
            if (stored != null) {
                ArticleOpener.open(stored, s[:id] as String, s[:title] as String);
            }
        }
        return true;
    }

    function onDrag(event as WatchUi.DragEvent) as Boolean {
        if (_view.isCloseQuery()) { return true; }   // M10.8: no scroll behind the modal
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
        if (_view.isCloseQuery()) { return true; }
        _view.scrollBy(60);
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_view.isCloseQuery()) { return true; }
        _view.scrollBy(-60);
        return true;
    }

    // M10.8: long-press back (KEY_MENU on the Venu 2) -> "Close app?" modal.
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_MENU) {
            System.println("M10.8: long-press BACK (MENU) in results — close-app query");
            _view.setCloseQuery(true);
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        // M10.8: short back cancels the modal if up; otherwise pop (return false).
        if (_view.isCloseQuery()) {
            _view.setCloseQuery(false);
            return true;
        }
        return false;
    }
}
