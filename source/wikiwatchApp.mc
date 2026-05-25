import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        FixtureInstaller.installIfEmpty();
    }

    function onStop(state as Dictionary?) as Void {
    }

    // M3: initial view is the static Hebrew keyboard. The article reader
    // (wikiwatchView / wikiwatchDelegate) stays in source for M6 to push
    // on top of the view stack when a word is long-pressed in an article.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new wikiwatchKeyboardView();
        // M6: KeyboardDelegate ctor now takes an initial-buffer string.
        // First launch starts with an empty buffer.
        return [ view, new wikiwatchKeyboardDelegate(view, "") ];
    }

}

function getApp() as wikiwatchApp {
    return Application.getApp() as wikiwatchApp;
}