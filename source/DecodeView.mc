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
    private const _TICK_MS = 50;        // CIQ Timer minimum

    private var _blob as ByteArray;
    private var _cacheKey as String;
    private var _model as Dictionary?;
    private var _state as Dictionary?;
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

    // Timer callback: parse (tick 1) then decode one slice per tick.
    function onDecodeTick() as Void {
        _timer = null;
        if (_model == null) {
            // Tick 1: parse the baked model (one-time; freeMemory-guarded inside).
            _model = CompModel.model();
            if (_model == null) {
                // Low memory / unreadable model — back out safely (no garbage).
                System.println("M10.1 decode: model unavailable — popping");
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
                return;
            }
            _state = Decompressor.decodeStart(_blob);
            WatchUi.requestUpdate();
            _scheduleTick();
            return;
        }
        var done = Decompressor.decodeStep(_state as Dictionary, _model as Dictionary, _TOKENS_PER_TICK);
        var n = Decompressor.decodeTokenCount(_state as Dictionary);
        var d = Decompressor.decodeTokensDone(_state as Dictionary);
        _pct = (n > 0) ? (d * 100) / n : 100;
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
