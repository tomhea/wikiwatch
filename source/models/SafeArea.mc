import Toybox.Lang;
import Toybox.Math;

// Circular-display safe-area geometry. Pure module (no side effects, no
// Toybox.WatchUi / Storage / Application / Communications imports per R6).
// All values are integer-pixel; internal Float from Math.sqrt is immediately
// floor'd back to Number so callers never see Float drift.
module SafeArea {
    // Half-width of the horizontal chord of a circle of radius `r` at vertical
    // offset `dy` from center. Returns 0 if `|dy| > r` (out-of-range guard:
    // we never let Math.sqrt see a negative number).
    function safeChordHalfWidth(r as Number, dy as Number) as Number {
        var absDy = dy < 0 ? -dy : dy;
        if (absDy > r) {
            return 0;
        }
        var sq = (r * r) - (absDy * absDy);
        return Math.floor(Math.sqrt(sq)).toNumber();
    }

    // Full chord width at vertical offset `dy`.
    function safeChordWidth(r as Number, dy as Number) as Number {
        return 2 * safeChordHalfWidth(r, dy);
    }

    // Smallest non-negative Y measured from the top of a 2r x 2r screen where
    // the chord is wide enough to fit `textWidth` pixels. If textWidth > 2r,
    // no Y can fit it: returns r (center) as the best-we-can-do fallback.
    function minSafeY(r as Number, textWidth as Number) as Number {
        if (textWidth > 2 * r) {
            return r;
        }
        for (var y = 0; y <= r; y++) {
            if (safeChordWidth(r, y - r) >= textWidth) {
                return y;
            }
        }
        return r;
    }
}