import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M8 LowBatteryView — the battery gate. Shown when an install (first-launch or
// resume) can't safely start/continue because battery is low AND the watch
// isn't charging (BatteryGate.shouldGate / shouldPause). Polls battery once a
// second; when it recovers (>=10%) OR charging begins, auto-transitions to the
// (Resume)InstallView. A tap dismisses to the keyboard (functional only if a
// prior corpus exists).
//
// Two contexts (constructor flag):
//   resumeContext=false — first install pending  ("שדרוג בהמתנה...")
//   resumeContext=true  — interrupted install     ("התקנה לא הסתיימה...")
class LowBatteryView extends WatchUi.View {
    private const POLL_MS = 1000;

    private var _resumeContext as Boolean;
    private var _timer as Timer.Timer?;
    private var _battery as Float;
    private var _charging as Boolean;
    private var _leaving as Boolean;

    function initialize(resumeContext as Boolean) {
        View.initialize();
        _resumeContext = resumeContext;
        _timer = null;
        var stats = System.getSystemStats();
        _battery = stats.battery;
        _charging = stats.charging;
        _leaving = false;
    }

    function onShow() as Void {
        View.onShow();
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onPoll), POLL_MS, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
        View.onHide();
    }

    function onPoll() as Void {
        if (_leaving) { return; }
        var stats = System.getSystemStats();
        _battery = stats.battery;
        _charging = stats.charging;
        // Recovered (>=10%) or now charging -> resume the install.
        if (!BatteryGate.shouldGate(_battery, _charging)) {
            System.println("M8 battery gate: cleared (battery=" + _battery
                + "% charging=" + _charging + ") — starting install");
            _leaving = true;
            var v = _resumeContext ? (new ResumeInstallView()) : (new InstallView(false));
            WatchUi.switchToView(v, new InstallDelegate(), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 56, Graphics.FONT_SMALL, "wikiwatch",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hebrew context message.
        var msg = _resumeContext
            ? "התקנה לא הסתיימה"      // install incomplete
            : "שדרוג בהמתנה";          // update pending
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 24, Graphics.FONT_TINY, msg,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, h / 2 + 2, Graphics.FONT_TINY, "חבר למטען להמשך",  // plug in to continue
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Battery percentage + hint.
        var pct = _battery.toNumber();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 40, Graphics.FONT_XTINY,
                    pct + "% • plug in to install",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class LowBatteryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Tap dismisses the gate and falls back to the keyboard. It's functional
    // only if a prior install left a corpus; otherwise the user gets the
    // degraded (empty) keyboard, same as M7's no-network fallback.
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        System.println("M8 battery gate: dismissed to keyboard");
        var kb = new wikiwatchKeyboardView();
        WatchUi.switchToView(kb, new wikiwatchKeyboardDelegate(kb, ""), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
