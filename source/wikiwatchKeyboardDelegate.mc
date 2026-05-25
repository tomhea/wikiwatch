import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M5 keyboard delegate. Adds live-search wiring on top of the M3.3 two-tap
// state machine + SPACE/BACKSPACE press flash:
//   - On initialize, loads Manifest.articles (M4) and seeds the view with
//     top-3 suggestions for the empty query.
//   - Every buffer-mutating tap (SPACE / BACKSPACE / sub-button append /
//     onBack popLast) re-ranks via Search.rank and updates the view's
//     suggestion list.
//   - In onTap, BEFORE the outer-ring wedge hit-test, checks if the tap
//     fell inside the center suggestion area. If yes, ArticleStore.bodyOf
//     loads the body and WatchUi.pushView opens the M2.x reader on top of
//     the keyboard.
//
// Per memory/reference_ciq_quirks.md, the press-flash Timer is held as an
// instance field — local Timer.Timer gets GC'd before the delay elapses.
class wikiwatchKeyboardDelegate extends WatchUi.BehaviorDelegate {
    private const PRESS_FLASH_MS = 200;
    private const MAX_SUGGESTIONS = 3;

    private var _view as wikiwatchKeyboardView;
    private var _buffer as String;
    private var _expanded as Dictionary?;
    private var _pressTimer as Timer.Timer?;
    private var _articles as Array<Dictionary>;
    private var _ranked as Array<Dictionary>;

    function initialize(view as wikiwatchKeyboardView) {
        BehaviorDelegate.initialize();
        _view = view;
        _buffer = "";
        _expanded = null;
        _pressTimer = null;
        var arts = Manifest.load()[:articles] as Array<Dictionary>?;
        _articles = (arts == null) ? new [0] : arts;
        _ranked = new [0];
        _recomputeSuggestions();
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var x = coords[0];
        var y = coords[1];
        var settings = System.getDeviceSettings();
        var w = settings.screenWidth;
        var h = settings.screenHeight;

        if (_expanded != null) {
            var sub = KeyboardLayout.subButtonAt(x, y, _expanded as Dictionary, w, h);
            if (sub != null) {
                var s = sub as Dictionary;
                _buffer = InputBuffer.append(_buffer, s[:label] as String);
                _view.setBuffer(_buffer);
                _recomputeSuggestions();
            }
            _expanded = null;
            _view.clearExpansion();
            return true;
        }

        // M5.1: "▼ N more" footer row → push the full-screen ResultsView.
        // Check before suggestionAt so the footer takes priority over an
        // ambiguous overlap at the row boundary.
        if (_view.moreHit(x, y)) {
            System.println("M5.1 more tapped: pushing ResultsView with n=" + _ranked.size());
            var results = new ResultsView(_ranked);
            WatchUi.pushView(results, new ResultsDelegate(results), WatchUi.SLIDE_LEFT);
            return true;
        }

        // M5: suggestion-tap takes priority over wedge hit-test. The
        // suggestion area lives at r < R_HIT_INNER (= 131), so no overlap
        // with the outer ring.
        var suggestion = _view.suggestionAt(x, y);
        if (suggestion != null) {
            var s = suggestion as Dictionary;
            var body = ArticleStore.bodyOf(s[:id] as String);
            if (body != null) {
                var reader = new wikiwatchView(body);
                var readerDelegate = new wikiwatchDelegate(reader);
                WatchUi.pushView(reader, readerDelegate, WatchUi.SLIDE_LEFT);
            }
            return true;
        }

        var b = KeyboardLayout.buttonAt(x, y, w, h);
        if (b == null) { return true; }
        var d = b as Dictionary;
        var t = d[:type] as Symbol;
        if (t == :SPACE) {
            _buffer = InputBuffer.append(_buffer, " ");
            _view.setBuffer(_buffer);
            _recomputeSuggestions();
            _flashPressed(d[:centerAngleDeg] as Number);
        } else if (t == :BACKSPACE) {
            _buffer = InputBuffer.popLast(_buffer);
            _view.setBuffer(_buffer);
            _recomputeSuggestions();
            _flashPressed(d[:centerAngleDeg] as Number);
        } else if (t == :LETTER_GROUP || t == :DIGITS) {
            _expanded = d;
            _view.setExpanded(d);
        }
        return true;
    }

    function onBack() as Boolean {
        if (_expanded != null) {
            _expanded = null;
            _view.clearExpansion();
            return true;
        }
        if (_buffer.length() > 0) {
            _buffer = InputBuffer.popLast(_buffer);
            _view.setBuffer(_buffer);
            _recomputeSuggestions();
            return true;
        }
        return false;
    }

    private function _recomputeSuggestions() as Void {
        _ranked = Search.rank(_buffer, _articles);
        var top = _takeTop(_ranked, MAX_SUGGESTIONS);
        var more = _ranked.size() - MAX_SUGGESTIONS;
        if (more < 0) { more = 0; }
        System.println("M5 rank: buf='" + _buffer + "' top=" + _titlesOf(top)
                       + " more=" + more);
        _view.setSuggestions(top);
        _view.setMoreCount(more);
    }

    private function _takeTop(arr as Array<Dictionary>, n as Number) as Array<Dictionary> {
        if (arr.size() <= n) { return arr; }
        var top = new [0];
        for (var i = 0; i < n; i++) { top.add(arr[i]); }
        return top;
    }

    private function _titlesOf(arr as Array<Dictionary>) as String {
        var s = "[";
        for (var i = 0; i < arr.size(); i++) {
            if (i > 0) { s = s + ","; }
            s = s + ((arr[i] as Dictionary)[:title] as String);
        }
        return s + "]";
    }

    private function _flashPressed(angleDeg as Number) as Void {
        _view.setPressed(angleDeg);
        if (_pressTimer == null) {
            _pressTimer = new Timer.Timer();
        }
        (_pressTimer as Timer.Timer).start(method(:onPressClearTimer), PRESS_FLASH_MS, false);
    }

    function onPressClearTimer() as Void {
        _view.clearPressed();
    }
}
