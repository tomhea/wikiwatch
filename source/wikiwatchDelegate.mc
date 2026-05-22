import Toybox.Lang;
import Toybox.WatchUi;

class wikiwatchDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new wikiwatchMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}