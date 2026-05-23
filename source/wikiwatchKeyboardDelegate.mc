import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M3 keyboard delegate. onTap routes the tap through KeyboardLayout.keyAt
// and dispatches on :type. SEARCH is intentionally no-op for M3 (M5 wires it).
// Uses System.getDeviceSettings() for screen dimensions instead of cached dc
// state - delegate has no dc, and DeviceSettings is stable.
class wikiwatchKeyboardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as wikiwatchKeyboardView;
    private var _buffer as String;

    function initialize(view as wikiwatchKeyboardView) {
        BehaviorDelegate.initialize();
        _view = view;
        _buffer = "";
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var x = coords[0];
        var y = coords[1];
        var settings = System.getDeviceSettings();
        var key = KeyboardLayout.keyAt(x, y, settings.screenWidth, settings.screenHeight);
        if (key == null) { return true; }
        var k = key as Dictionary;
        var t = k[:type] as Symbol;
        if (t == :LETTER) {
            _buffer = InputBuffer.append(_buffer, k[:label] as String);
        } else if (t == :SPACE) {
            _buffer = InputBuffer.append(_buffer, " ");
        } else if (t == :BACKSPACE) {
            _buffer = InputBuffer.popLast(_buffer);
        } else if (t == :DELETE_ALL) {
            _buffer = InputBuffer.clear(_buffer);
        }
        // :SEARCH = no-op for M3 (M5 will push the results view)
        _view.setBuffer(_buffer);
        return true;
    }
}