import Toybox.Lang;

// M9.7: geometry for the "Close app?" confirmation prompt shown when the user
// long-presses the on-screen backspace (X) wedge. A centered button; tapping
// inside it exits the app, a physical back press cancels. Pure -> unit-testable.
module CloseQuery {
    const BTN_W = 220;
    const BTN_H = 90;

    // True if (x, y) is inside the centered Close-app button.
    function buttonHit(x as Number, y as Number, screenW as Number, screenH as Number) as Boolean {
        var cx = screenW / 2;
        var cy = screenH / 2;
        return x >= cx - BTN_W / 2 && x <= cx + BTN_W / 2
            && y >= cy - BTN_H / 2 && y <= cy + BTN_H / 2;
    }
}
