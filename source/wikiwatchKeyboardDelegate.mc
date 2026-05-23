import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M3.1 keyboard delegate. Two-tap state machine on top of KeyboardLayout's
// wedge geometry. Smart Back: cancel expansion, then backspace, then default
// pop.
class wikiwatchKeyboardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as wikiwatchKeyboardView;
    private var _buffer as String;
    private var _expanded as Dictionary?;

    function initialize(view as wikiwatchKeyboardView) {
        BehaviorDelegate.initialize();
        _view = view;
        _buffer = "";
        _expanded = null;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates() as Array<Number>;
        var x = coords[0];
        var y = coords[1];
        var settings = System.getDeviceSettings();
        var w = settings.screenWidth;
        var h = settings.screenHeight;

        if (_expanded != null) {
            // Expanded: tap-2 selects a sub-zone, anywhere else cancels.
            var sub = KeyboardLayout.subButtonAt(x, y, _expanded as Dictionary, w, h);
            if (sub != null) {
                var s = sub as Dictionary;
                _buffer = InputBuffer.append(_buffer, s[:label] as String);
                _view.setBuffer(_buffer);
            }
            _expanded = null;
            _view.clearExpansion();
            return true;
        }

        // Collapsed: tap-1 either appends (SPACE/BACKSPACE) or starts expansion.
        var b = KeyboardLayout.buttonAt(x, y, w, h);
        if (b == null) { return true; }
        var d = b as Dictionary;
        var t = d[:type] as Symbol;
        if (t == :SPACE) {
            _buffer = InputBuffer.append(_buffer, " ");
            _view.setBuffer(_buffer);
        } else if (t == :BACKSPACE) {
            _buffer = InputBuffer.popLast(_buffer);
            _view.setBuffer(_buffer);
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
            return true;
        }
        return false;
    }
}