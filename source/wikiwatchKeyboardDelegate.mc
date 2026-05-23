import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M3.3 keyboard delegate. Two-tap state machine + smart onBack.
// SPACE / BACKSPACE taps trigger a ~200 ms "pressed" visual flash on the
// view via setPressed/clearPressed + a one-shot Timer (held as an instance
// field per memory/reference_ciq_quirks.md - local Timer.Timer gets GC'd
// before the delay elapses).
class wikiwatchKeyboardDelegate extends WatchUi.BehaviorDelegate {
    private const PRESS_FLASH_MS = 200;

    private var _view as wikiwatchKeyboardView;
    private var _buffer as String;
    private var _expanded as Dictionary?;
    private var _pressTimer as Timer.Timer?;

    function initialize(view as wikiwatchKeyboardView) {
        BehaviorDelegate.initialize();
        _view = view;
        _buffer = "";
        _expanded = null;
        _pressTimer = null;
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
            }
            _expanded = null;
            _view.clearExpansion();
            return true;
        }

        var b = KeyboardLayout.buttonAt(x, y, w, h);
        if (b == null) { return true; }
        var d = b as Dictionary;
        var t = d[:type] as Symbol;
        if (t == :SPACE) {
            _buffer = InputBuffer.append(_buffer, " ");
            _view.setBuffer(_buffer);
            _flashPressed(d[:centerAngleDeg] as Number);
        } else if (t == :BACKSPACE) {
            _buffer = InputBuffer.popLast(_buffer);
            _view.setBuffer(_buffer);
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
            return true;
        }
        return false;
    }

    // Set _view.setPressed(angle) and schedule clearPressed after 200 ms.
    // Restarting the timer on each press correctly extends the flash.
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