import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M10.2: the model-PARSE gate. Parsing the baked BPE+Huffman model (V=4096 table
// fills) in one event handler trips the watch watchdog, so it's sliced across
// Timer ticks here; once parsed (and cached for the session), this view hands the
// article off to the streaming reader (wikiwatchView.startStreaming), which now
// owns the incremental DECODE+layout. Reached only on the FIRST compressed open
// of a session — afterwards ArticleOpener finds the cached model and pushes the
// streaming reader directly, skipping this gate. Plain corpora never reach here.
//
// Pre-M10.2 this view also decoded the whole body behind a 0-100% bar before any
// text showed; M10.2 moved decode into the reader (text after ~2 screens decode),
// so this gate just shows a brief "..." while the one-time parse runs.
class DecodeView extends WatchUi.View {
    // Per-tick item budget for the (one-time) model parse. The V=4096 table fills
    // must be sliced too — done all at once they trip the watchdog on-device.
    private const _PARSE_ITEMS_PER_TICK = 1000;
    private const _TICK_MS = 50;        // CIQ Timer minimum

    private var _blob as ByteArray;
    private var _cacheKey as String;
    private var _timer as Timer.Timer?;
    private var _w as Number;
    private var _h as Number;

    function initialize(blob as ByteArray, cacheKey as String) {
        View.initialize();
        _blob = blob;
        _cacheKey = cacheKey;
        _timer = null;
        _w = 0;
        _h = 0;
    }

    function onShow() as Void {
        _scheduleTick();
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
        View.onHide();
    }

    function onUpdate(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        // Brief "preparing" indicator while the one-time model parse runs (no
        // 0-100% bar anymore — the reader paints text after the first ~2 screens
        // decode, so there is nothing long to bar-chart here).
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2, Graphics.FONT_MEDIUM, "...",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Timer callback: advance the ONE shared sliced model-parse (a slice per tick
    // so no single event handler exceeds the watchdog budget), then hand off to
    // the streaming reader. M10.3: drives CompModel.parseSlice — the SAME state the
    // eager ModelWarmer advances at keyboard-idle, so if warming already finished
    // (or partly ran) this gate resumes/returns instantly instead of re-parsing.
    function onDecodeTick() as Void {
        _timer = null;
        var st = CompModel.parseSlice(_PARSE_ITEMS_PER_TICK);
        if (st == :more) {
            _scheduleTick();        // still parsing — slice again next tick
            return;
        }
        if (st == :done) {
            _handoffToReader();     // model ready → reader owns decode + layout
            return;
        }
        // :lowmem (not enough heap to begin the parse) or :unreadable (bad model).
        System.println("M10.3 gate: parse " + st + " — popping");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // R5: guard the decode output buffer alloc (the reader's :out grows to the full
    // body) — mirrors CompModel.decompress / the old DecodeView decode guard.
    private function _handoffToReader() as Void {
        if (System.getSystemStats().freeMemory < CompModel.MIN_FREE_DECODE) {
            System.println("M10.3 gate: low memory for decode buffer — popping");
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        var reader = new wikiwatchView("", _cacheKey);
        reader.startStreaming(_blob, CompModel.cachedModel() as Dictionary);
        WatchUi.switchToView(reader, new wikiwatchDelegate(reader), WatchUi.SLIDE_IMMEDIATE);
    }

    private function _scheduleTick() as Void {
        if (_timer != null) { return; }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onDecodeTick), _TICK_MS, false);
    }
}
