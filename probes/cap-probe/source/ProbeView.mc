import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// Fetches /probe/<KB>.json for an ascending list of sizes, ONE AT A TIME (a small
// delay between requests so the BLE queue clears and rc=-101 can't confound the
// rc=-402 size signal), and renders a color grid: green=200 OK, red=failed,
// gray=pending. The largest green size = the watch's real response cap.
class ProbeView extends WatchUi.View {
    // Override at build time for the sim test; ships pointing at the real server.
    const BASE = "https://wikiwatch.tomhe.app/probe/";
    const GAP_MS = 500;   // pause between probes (clear the BLE queue)

    private var _sizes as Array<Number>;
    private var _results as Array<Number>;   // per size: 0 pending, 200 ok, else rc
    private var _idx as Number;
    private var _maxOk as Number;
    private var _firstFailKb as Number;
    private var _firstFailRc as Number;
    private var _done as Boolean;
    private var _started as Boolean;

    function initialize() {
        View.initialize();
        // Fine resolution around the proven-13.8 / sim-17 zone, coarser up to 64.
        _sizes = [12, 13, 14, 15, 16, 17, 18, 20, 24, 32, 48, 64];
        _results = new [_sizes.size()];
        for (var i = 0; i < _sizes.size(); i++) { _results[i] = 0; }
        _idx = 0;
        _maxOk = 0;
        _firstFailKb = 0;
        _firstFailRc = 0;
        _done = false;
        _started = false;
    }

    function onShow() as Void {
        if (_started) { return; }
        _started = true;
        _fetchNext();
    }

    private function _fetchNext() as Void {
        if (_idx >= _sizes.size()) {
            _done = true;
            WatchUi.requestUpdate();
            return;
        }
        var url = BASE + _sizes[_idx].toString() + ".json";
        System.println("probe GET " + url);
        Communications.makeWebRequest(
            url, {},
            { :method => Communications.HTTP_REQUEST_METHOD_GET,
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onResult));
        WatchUi.requestUpdate();
    }

    function onResult(rc as Number, data as Dictionary?) as Void {
        if (_idx < _sizes.size()) {
            var kb = _sizes[_idx];
            _results[_idx] = rc;
            if (rc == 200) {
                _maxOk = kb;
            } else if (_firstFailKb == 0) {
                _firstFailKb = kb;
                _firstFailRc = rc;
            }
            System.println("probe " + kb + "KB rc=" + rc);
        }
        data = null;
        _idx++;
        // Space the next request out so the BLE queue is clear.
        var t = new Timer.Timer();
        t.start(method(:_tick), GAP_MS, false);
        WatchUi.requestUpdate();
    }

    function _tick() as Void {
        _fetchNext();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var cx = w / 2;

        dc.drawText(cx, 14, Graphics.FONT_XTINY, "response-cap probe", Graphics.TEXT_JUSTIFY_CENTER);

        // Headline: testing N / done CAP=N.
        var headline;
        var hc;
        if (_done) {
            headline = "CAP = " + _maxOk + " KB";
            hc = Graphics.COLOR_GREEN;
        } else {
            headline = "testing " + (_idx < _sizes.size() ? _sizes[_idx] : _maxOk) + " KB";
            hc = Graphics.COLOR_YELLOW;
        }
        dc.setColor(hc, Graphics.COLOR_BLACK);
        dc.drawText(cx, 44, Graphics.FONT_MEDIUM, headline, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var sub = "max OK " + _maxOk + "KB";
        if (_firstFailKb != 0) { sub += "  fail@" + _firstFailKb + " rc=" + _firstFailRc; }
        dc.drawText(cx, 86, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER);

        // 3-column color grid of the sizes.
        var cols = 3;
        var x0 = cx - 78;
        var dx = 78;
        var y = 116;
        var dy = 30;
        for (var i = 0; i < _sizes.size(); i++) {
            var col = i % cols;
            var row = i / cols;
            var r = _results[i];
            var color;
            if (r == 0) { color = (_idx == i && !_done) ? Graphics.COLOR_YELLOW : Graphics.COLOR_DK_GRAY; }
            else if (r == 200) { color = Graphics.COLOR_GREEN; }
            else { color = Graphics.COLOR_RED; }
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.drawText(x0 + col * dx, y + row * dy, Graphics.FONT_XTINY,
                _sizes[i].toString(), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
