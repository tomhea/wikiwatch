import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// M7 UpdateCheckView — shown for ≤750ms on every launch (when local
// manifest is present). Fires a background fetch of /manifest.json,
// races against a 750ms Timer. The first one to win decides what
// happens next:
//
//   Timer wins (no response yet)     -> switch to KeyboardView (functional)
//   Fetch wins + same version        -> switch to KeyboardView (functional)
//   Fetch wins + newer version       -> switch to UpdatePromptView
//   Fetch wins + error/parse failure -> switch to KeyboardView (functional)
//
// 750ms picked as compromise between 500ms (too tight for cold BLE) and
// 1000ms (eats more startup latency). Bumpable in a hotfix.
//
// Renders the same keyboard layout underneath, with a "checking for
// updates..." text overlay near the bottom (shares pixel real estate
// with M6.5's `fm:` overlay, which keeps rendering — both visible
// at once during the check).
//
// Taps during the check are absorbed by UpdateCheckDelegate (the keyboard
// is non-functional until the race resolves).
class UpdateCheckView extends WatchUi.View {
    private const _CHECK_TIMEOUT_MS = 750;

    private var _timeoutTimer as Timer.Timer?;
    private var _resolved as Boolean;
    private var _kbView as wikiwatchKeyboardView;  // shown underneath for visual continuity

    function initialize() {
        View.initialize();
        _timeoutTimer = null;
        _resolved = false;
        _kbView = new wikiwatchKeyboardView();
    }

    function onShow() as Void {
        View.onShow();
        System.println("M7 update check: starting 750ms race");
        Downloader.fetchManifest(method(:onManifestReceived));
        _timeoutTimer = new Timer.Timer();
        (_timeoutTimer as Timer.Timer).start(method(:onTimeout), _CHECK_TIMEOUT_MS, false);
    }

    function onHide() as Void {
        if (_timeoutTimer != null) {
            (_timeoutTimer as Timer.Timer).stop();
            _timeoutTimer = null;
        }
        View.onHide();
    }

    function onUpdate(dc as Dc) as Void {
        // Show keyboard view underneath for visual continuity (so the
        // transition to functional keyboard isn't jarring), then overlay
        // a "checking..." label near the center.
        _kbView.onUpdate(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 60, Graphics.FONT_XTINY,
                    "checking for updates...",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Race winner #1: timer fires before fetch returns.
    function onTimeout() as Void {
        if (_resolved) { return; }
        _resolved = true;
        System.println("M7 update check: TIMEOUT after " + _CHECK_TIMEOUT_MS + "ms — using stale");
        _toFunctionalKeyboard();
    }

    // Race winner #2: fetch returns before timer fires.
    function onManifestReceived(rc as Number, data as Dictionary?) as Void {
        if (_resolved) { return; }
        _resolved = true;
        if (_timeoutTimer != null) {
            (_timeoutTimer as Timer.Timer).stop();
            _timeoutTimer = null;
        }
        var parsed = Downloader.parseManifestResponse(rc, data);
        if (parsed[:ok] != true) {
            System.println("M7 update check: parse FAILED — " + parsed[:error] + " — using stale");
            _toFunctionalKeyboard();
            return;
        }
        var remote = parsed[:manifest] as Dictionary;
        var remoteVersion = remote[:version] as Number;
        var local = Manifest.load();
        var localVersion = local[:version] as Number;
        if (remoteVersion <= localVersion) {
            System.println("M7 update check: same/older version (local=" + localVersion
                + " remote=" + remoteVersion + ") — using local");
            _toFunctionalKeyboard();
            return;
        }
        System.println("M7 update check: UPDATE AVAILABLE local=" + localVersion
            + " remote=" + remoteVersion + " — prompting");
        var prompt = new UpdatePromptView(remote, localVersion);
        WatchUi.switchToView(prompt, new UpdatePromptDelegate(prompt), WatchUi.SLIDE_LEFT);
    }

    private function _toFunctionalKeyboard() as Void {
        var del = new wikiwatchKeyboardDelegate(_kbView, "");
        WatchUi.switchToView(_kbView, del, WatchUi.SLIDE_LEFT);
    }
}

class UpdateCheckDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Taps are absorbed during the check — keyboard is non-functional
    // until the race resolves.
    function onTap(event as WatchUi.ClickEvent) as Boolean { return true; }
    function onBack() as Boolean { return true; }
}
