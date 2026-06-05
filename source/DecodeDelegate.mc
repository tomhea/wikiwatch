import Toybox.Lang;
import Toybox.WatchUi;

// M10.1: minimal delegate for DecodeView. The physical back button cancels the
// decompression (CIQ pops the view back to the keyboard); taps are ignored while
// decoding.
class DecodeDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        return false;   // let CIQ pop DecodeView back to the keyboard
    }
}
