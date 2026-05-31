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
    private const MAX_SUGGESTIONS = 2;

    private var _view as wikiwatchKeyboardView;
    private var _buffer as String;
    private var _expanded as Dictionary?;
    private var _pressTimer as Timer.Timer?;
    // M9.3: compact resident search index (parallel arrays, position == id)
    // instead of an Array<Dictionary> — ~4x fewer live objects so the real
    // watch's GC doesn't choke on the 1462-article corpus.
    private var _titles as Array<String>;
    private var _pops as Array<Number>;
    // M9.5 (D2): titles pre-normalized ONCE at load, so the per-keystroke search
    // matches against these and never calls Search.normalize per title (removes
    // the O(S^2) normalize slow-path from the hot path).
    private var _normTitles as Array<String>;
    private var _ranked as Array<Dictionary>;
    private var _totalMatches as Number;

    // M6: initialBuffer lets the long-press flow push a new keyboard
    // layer with a pre-filled word. Existing callers pass "" for the
    // initial-launch keyboard.
    function initialize(view as wikiwatchKeyboardView, initialBuffer as String) {
        BehaviorDelegate.initialize();
        _view = view;
        _buffer = initialBuffer;
        _view.setBuffer(_buffer);
        _expanded = null;
        _pressTimer = null;
        // M9.6: load the compact index ONCE per session via IndexCache and share
        // it across every keyboard. Previously each keyboard re-ran loadCompact +
        // the manifest fallback + installedCount cap + a full normalize pass; the
        // long-press flow pushes a SECOND keyboard on top of the resident article
        // reader, so at ~1200 articles that redundant second index copy + normalize
        // loop exhausted the heap / tripped the watchdog and crashed. IndexCache
        // (which owns load + cap + normalize) makes every reuse a no-op.
        var idx = IndexCache.get();
        _titles = idx[:titles] as Array<String>;
        _pops = idx[:pops] as Array<Number>;
        _normTitles = idx[:normTitles] as Array<String>;
        // M6.2 pre-loaded every article body into :body so Search.rank could
        // do tier-3 body fallback. That combined with the M6.2 _normalize
        // O(N²) string-concat loop caused uncatchable OOM (the ~2 KB shalom
        // sampleArticle re-normalized twice per keystroke = ~8M byte-allocs;
        // plus the pre-loaded bodies left ~5 KB resident, which on top of
        // the article-reader push's layout allocations blew the Venu 2
        // heap). M6.3 removes the pre-load and the tier-3 path. Body
        // search will return in a later milestone with a different
        // architecture.
        _ranked = new [0];
        _totalMatches = 0;
        _recomputeSuggestions();
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var x = coords[0];
        var y = coords[1];
        var settings = System.getDeviceSettings();
        var w = settings.screenWidth;
        var h = settings.screenHeight;

        // M9.7: while the "Close app?" modal is up, a tap inside the button exits
        // the app entirely; a tap elsewhere cancels. (Physical back also cancels.)
        if (_view.isCloseQuery()) {
            if (CloseQuery.buttonHit(x, y, w, h)) {
                System.println("M9.7: close app confirmed — exiting");
                System.exit();
            } else {
                _view.setCloseQuery(false);
            }
            return true;
        }

        // M9.7: under low memory ("max open articles" shown) allow ONLY backing
        // out — the on-screen backspace (X) wedge + the physical back button
        // (onBack). Block typing/expansion/opening so the user reduces, not grows,
        // the view stack / heap.
        if (!MemGuard.canOpen(System.getSystemStats().freeMemory)) {
            var bk = KeyboardLayout.buttonAt(x, y, w, h);
            if (bk != null && (bk as Dictionary)[:type] == :BACKSPACE) {
                _buffer = InputBuffer.popLast(_buffer);
                _view.setBuffer(_buffer);
                _recomputeSuggestions();
                _flashPressed((bk as Dictionary)[:centerAngleDeg] as Number);
            }
            WatchUi.requestUpdate();
            return true;
        }

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
            System.println("M5.1 more tapped: pushing ResultsView with n=" + _ranked.size()
                + " total=" + _totalMatches);
            var results = new ResultsView(_ranked, _totalMatches);
            WatchUi.pushView(results, new ResultsDelegate(results), WatchUi.SLIDE_LEFT);
            return true;
        }

        // M5: suggestion-tap takes priority over wedge hit-test. The
        // suggestion area lives at r < R_HIT_INNER (= 131), so no overlap
        // with the outer ring.
        var suggestion = _view.suggestionAt(x, y);
        if (suggestion != null) {
            // (low-memory opens are already refused at the top of onTap.)
            var s = suggestion as Dictionary;
            var body = ArticleStore.bodyOf(s[:id] as String);
            if (body != null) {
                var reader = new wikiwatchView(body, s[:id] as String);
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

    // M9.7: long-press the on-screen backspace (X) wedge -> "Close app?" modal.
    // (The physical back button can't emit a touch-hold, and Venu 2 firmware may
    // claim a physical long-press, so the X wedge is the long-pressable "back".)
    function onHold(event as WatchUi.ClickEvent) as Boolean {
        if (_view.isCloseQuery()) { return true; }
        var coords = event.getCoordinates() as Array<Number>;
        var settings = System.getDeviceSettings();
        var b = KeyboardLayout.buttonAt(coords[0], coords[1],
                                        settings.screenWidth, settings.screenHeight);
        if (b != null && (b as Dictionary)[:type] == :BACKSPACE) {
            System.println("M9.7: long-press X — showing close-app query");
            _view.setCloseQuery(true);
        }
        return true;
    }

    function onBack() as Boolean {
        // M9.7: a normal back press cancels the "Close app?" modal.
        if (_view.isCloseQuery()) {
            _view.setCloseQuery(false);
            return true;
        }
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
        // M5.3: empty-buffer guard — show NO suggestions / NO "more" footer
        // until the user types something. Avoids visual noise + skips the
        // rank work entirely.
        if (_buffer.length() == 0) {
            _ranked = new [0];
            _totalMatches = 0;
            System.println("M5 rank: buf='' (empty — no results shown)");
            _view.setSuggestions(_ranked);
            _view.setMoreCount(0);
            return;
        }
        _ranked = Search.rankCompact(_buffer, _titles, _normTitles, _pops);
        _totalMatches = Search.totalMatchesCompact(_buffer, _normTitles);
        var top = _takeTop(_ranked, MAX_SUGGESTIONS);
        var more = _ranked.size() - MAX_SUGGESTIONS;
        if (more < 0) { more = 0; }
        System.println("M5 rank: buf='" + _buffer + "' top=" + _titlesOf(top)
                       + " more=" + more + " total=" + _totalMatches);
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
