import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M10.1: decompresses one article's body across event-loop turns (a slice of
// tokens per Timer tick) and then switchToView()s to the article reader. Doing
// the whole BPE+Huffman decode of a long article in a single event handler
// trips the watch watchdog ("Code Executed Too Long"); slicing keeps every
// handler well under budget. Plain corpora never reach here — ArticleOpener
// pushes the reader directly.
//
// Tick 1 parses the baked model once (CompModel.model(), freeMemory-guarded);
// ticks 2.. each decode _TOKENS_PER_TICK tokens. A small "%" progress is shown.
class DecodeView extends WatchUi.View {
    // ~250 tokens/tick ≈ a small fraction of the worst article (1392 tokens) —
    // far under the per-handler watchdog budget on real hardware.
    private const _TOKENS_PER_TICK = 250;
    // Per-tick item budget for the (one-time) model parse. The V=4096 table fills
    // must be sliced too — done all at once they trip the watchdog on-device.
    private const _PARSE_ITEMS_PER_TICK = 1000;
    private const _TICK_MS = 50;        // CIQ Timer minimum

    private var _blob as ByteArray;
    private var _cacheKey as String;
    private var _model as Dictionary?;
    private var _state as Dictionary?;
    private var _parseState as Dictionary?;
    private var _timer as Timer.Timer?;
    private var _pct as Number;
    private var _w as Number;
    private var _h as Number;

    function initialize(blob as ByteArray, cacheKey as String) {
        View.initialize();
        _blob = blob;
        _cacheKey = cacheKey;
        _model = null;
        _state = null;
        _parseState = null;
        _timer = null;
        _pct = 0;
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
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2, Graphics.FONT_MEDIUM, _pct + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Timer callback: incrementally parse the model (first open only; reused from
    // cache afterwards), then incrementally decode — a slice per tick so no single
    // event handler exceeds the watchdog budget.
    function onDecodeTick() as Void {
        _timer = null;

        // --- phase A: ensure the model is parsed (sliced across ticks) ---
        if (_model == null) {
            _model = CompModel.cachedModel();          // reuse if already built
        }
        if (_model == null) {
            if (_parseState == null) {
                if (System.getSystemStats().freeMemory < CompModel.MIN_FREE_PARSE) {
                    System.println("M10.1 decode: low memory — popping");
                    WatchUi.popView(WatchUi.SLIDE_RIGHT);
                    return;
                }
                _parseState = Decompressor.parseStart(CompModel.rawModelBytes());
                if (_parseState == null) {
                    System.println("M10.1 decode: unreadable model — popping");
                    WatchUi.popView(WatchUi.SLIDE_RIGHT);
                    return;
                }
            } else if (Decompressor.parseStep(_parseState as Dictionary, _PARSE_ITEMS_PER_TICK)) {
                CompModel.cacheModel(_parseState as Dictionary);
                _model = _parseState;
            }
            // coarse progress: parse fills the first half of the bar.
            var ph = (_parseState == null) ? 0 : (_parseState[:phase] as Number);
            _pct = (ph * 50) / 4;
            WatchUi.requestUpdate();
            _scheduleTick();
            return;
        }

        // --- phase B: decode the article body (sliced across ticks) ---
        if (_state == null) {
            // R5: guard the decode output buffer alloc (grows to the full body).
            // The cached-model branch skips phase A's MIN_FREE_PARSE check, so the
            // decode path needs its own guard (mirrors CompModel.decompress).
            if (System.getSystemStats().freeMemory < CompModel.MIN_FREE_DECODE) {
                System.println("M10.1 decode: low memory for output buffer — popping");
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
                return;
            }
            _state = Decompressor.decodeStart(_blob);
        }
        var done = Decompressor.decodeStep(_state as Dictionary, _model as Dictionary, _TOKENS_PER_TICK);
        var n = Decompressor.decodeTokenCount(_state as Dictionary);
        var d = Decompressor.decodeTokensDone(_state as Dictionary);
        _pct = 50 + ((n > 0) ? (d * 50) / n : 50);     // decode fills the second half
        if (done) {
            var text = Decompressor.decodeText(_state as Dictionary);
            var reader = new wikiwatchView(text, _cacheKey);
            WatchUi.switchToView(reader, new wikiwatchDelegate(reader), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        WatchUi.requestUpdate();
        _scheduleTick();
    }

    private function _scheduleTick() as Void {
        if (_timer != null) { return; }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onDecodeTick), _TICK_MS, false);
    }
}
