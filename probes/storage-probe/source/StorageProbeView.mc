import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.Application.Storage;

// Writes Application.Storage keys "k0","k1",... each holding a ~250-byte value
// (a stored-summary proxy), in small batches across Timer ticks (watchdog-safe,
// like a real install's putBatch). Tracks how far it gets, the write throughput,
// and getValue latency as the count grows. A "_hi" high-water key persists across
// runs so even an UNCATCHABLE crash (the likely failure mode) leaves the last
// reached count readable on the next launch.
class StorageProbeView extends WatchUi.View {
    const BATCH = 50;          // keys per tick (~ an install chunk's putBatch)
    const MAX = 30000;         // stop here (past the 20k goal; 30k*250B=7.5MB < 9MB)
    const VAL_LEN = 250;

    private var _val as String;
    private var _written as Number;
    private var _startMs as Number;
    private var _lastGetMs as Number;
    private var _failAt as Number;
    private var _failMsg as String;
    private var _failed as Boolean;
    private var _done as Boolean;
    private var _started as Boolean;
    private var _prevHi as Number;
    private var _timer as Timer.Timer?;
    private var _milestone as Number;   // next milestone (every 1000)

    function initialize() {
        View.initialize();
        var s = "";
        for (var i = 0; i < VAL_LEN / 10; i++) { s += "abcdefghij"; }
        _val = s;
        _written = 0;
        _startMs = 0;
        _lastGetMs = -1;
        _failAt = -1;
        _failMsg = "";
        _failed = false;
        _done = false;
        _started = false;
        _prevHi = 0;
        _milestone = 1000;
    }

    function onShow() as Void {
        if (_started) { return; }
        _started = true;
        var hi = Storage.getValue("_hi");
        _prevHi = (hi == null) ? 0 : (hi as Number);
        _startMs = System.getTimer();
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:_tick), 50, true);
    }

    function _tick() as Void {
        if (_done || _failed) { return; }
        var i = 0;
        while (i < BATCH && _written < MAX) {
            try {
                Storage.setValue("k" + _written.toString(), _val);
            } catch (e) {
                _failed = true;
                _failAt = _written;
                _failMsg = e.getErrorMessage();
                (_timer as Timer.Timer).stop();
                WatchUi.requestUpdate();
                return;
            }
            _written++;
            i++;
        }
        // persist high-water mark (survives an uncatchable crash for next launch)
        if (_written > _prevHi) { Storage.setValue("_hi", _written); }
        // milestone: time a getValue of a mid key
        if (_written >= _milestone) {
            var t0 = System.getTimer();
            Storage.getValue("k" + (_written / 2).toString());
            _lastGetMs = System.getTimer() - t0;
            _milestone += 1000;
        }
        if (_written >= MAX) {
            _done = true;
            (_timer as Timer.Timer).stop();
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(cx, 14, Graphics.FONT_XTINY, "storage probe", Graphics.TEXT_JUSTIFY_CENTER);

        var big; var bc;
        if (_failed) { big = "LIMIT " + _failAt.toString(); bc = Graphics.COLOR_RED; }
        else if (_done) { big = "OK " + _written.toString(); bc = Graphics.COLOR_GREEN; }
        else { big = _written.toString(); bc = Graphics.COLOR_YELLOW; }
        dc.setColor(bc, Graphics.COLOR_BLACK);
        dc.drawText(cx, 44, Graphics.FONT_NUMBER_MILD, big, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var elapsed = (System.getTimer() - _startMs) / 1000;
        dc.drawText(cx, 96, Graphics.FONT_XTINY, "keys, " + elapsed.toString() + "s", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 120, Graphics.FONT_XTINY,
            "get=" + (_lastGetMs < 0 ? "-" : _lastGetMs.toString() + "ms"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_prevHi > 0) {
            dc.drawText(cx, 144, Graphics.FONT_XTINY, "prev hi: " + _prevHi.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_failed) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(cx, 168, Graphics.FONT_XTINY, _failMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(cx, w - 22, Graphics.FONT_XTINY,
            "fm:" + System.getSystemStats().freeMemory.toString(), Graphics.TEXT_JUSTIFY_CENTER);
    }
}
