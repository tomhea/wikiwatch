import Toybox.Lang;
import Toybox.Math;

// M3.1 Circular T9-style keyboard layout. Pure module (Toybox.Lang + Math
// only; no WatchUi / Storage / Communications per R6). See plan for design.
//
// M6.5 memory optimization: buttons() and subButtons() return the SAME
// cached Array on every call (the data is immutable — there's no reason
// to allocate a fresh array every time). Eliminates per-keystroke +
// per-render allocation churn that was overwhelming CIQ's GC on the real
// Venu 2 (sim has more relaxed GC). Steady-state cost: ~2 KB of cached
// dicts kept resident. Per-render savings: ~850 B (buttons) + up to
// ~150 B per LETTER_GROUP/DIGITS expansion (subButtons), times every
// onUpdate AND every onTap. The cache never invalidates — the layout
// data is module-level constant.
module KeyboardLayout {
    const NUM_BUTTONS = 10;
    const WEDGE_ARC_DEG = 36;
    const R_INNER = 146;
    const R_HIT_INNER = 131;
    const R_HIT_OUTER = 215;
    const R_OUTER = 205;
    const R_EXPANSION_INNER = 50;

    // M6.5 caches. Initialized lazily on first call.
    var _cachedButtons as Array<Dictionary>? = null;
    var _cachedSubButtons as Dictionary? = null;  // keyed by parent's centerAngleDeg

    function buttons() as Array<Dictionary> {
        if (_cachedButtons != null) {
            return _cachedButtons as Array<Dictionary>;
        }
        _cachedButtons = [
            { :label => "_",    :type => :SPACE,        :letters => [],                              :centerAngleDeg => 0 },
            { :label => "X",    :type => :BACKSPACE,    :letters => [],                              :centerAngleDeg => 36 },
            { :label => "אבג",  :type => :LETTER_GROUP, :letters => ["א","ב","ג"],                   :centerAngleDeg => 72 },
            { :label => "דהו",  :type => :LETTER_GROUP, :letters => ["ד","ה","ו"],                   :centerAngleDeg => 108 },
            { :label => "זחט",  :type => :LETTER_GROUP, :letters => ["ז","ח","ט"],                   :centerAngleDeg => 144 },
            { :label => "יכל",  :type => :LETTER_GROUP, :letters => ["י","כ","ל"],                   :centerAngleDeg => 180 },
            { :label => "מנס",  :type => :LETTER_GROUP, :letters => ["מ","נ","ס"],                   :centerAngleDeg => 216 },
            { :label => "עפצ",  :type => :LETTER_GROUP, :letters => ["ע","פ","צ"],                   :centerAngleDeg => 252 },
            { :label => "קרשת", :type => :LETTER_GROUP, :letters => ["ק","ר","ש","ת"],               :centerAngleDeg => 288 },
            { :label => "0-9",  :type => :DIGITS,       :letters => ["0","1","2","3","4","5","6","7","8","9"], :centerAngleDeg => 324 }
        ];
        return _cachedButtons as Array<Dictionary>;
    }

    // Polar hit-test against the outer ring. Returns the wedge whose
    // r in [R_HIT_INNER, R_HIT_OUTER] and angular slot contains (x, y), or null.
    function buttonAt(x as Number, y as Number, screenW as Number, screenH as Number) as Dictionary or Null {
        var cx = screenW / 2;
        var cy = screenH / 2;
        var dx = x - cx;
        var dy = y - cy;
        var rSq = dx * dx + dy * dy;
        if (rSq < R_HIT_INNER * R_HIT_INNER || rSq > R_HIT_OUTER * R_HIT_OUTER) {
            return null;
        }
        var thetaDeg = _angleDeg(dx, dy);
        var idx = ((thetaDeg + WEDGE_ARC_DEG / 2) / WEDGE_ARC_DEG) % NUM_BUTTONS;
        var bs = buttons();
        return bs[idx];
    }

    function subButtons(parent as Dictionary, screenW as Number, screenH as Number) as Array<Dictionary> {
        // M6.5: cache by parent's centerAngleDeg. The sub-button layout
        // depends only on parent's type + letters + centerAngleDeg, all
        // of which are determined by centerAngleDeg in our 10-button
        // layout. screenW/H aren't even used in the body (kept in the
        // signature for backward compat).
        var key = parent[:centerAngleDeg] as Number;
        if (_cachedSubButtons == null) {
            _cachedSubButtons = {};
        }
        var cache = _cachedSubButtons as Dictionary;
        var cached = cache[key];
        if (cached != null) {
            return cached as Array<Dictionary>;
        }
        var t = parent[:type] as Symbol;
        if (t == :DIGITS) {
            var digits = parent[:letters] as Array<String>;
            var result = [];
            // 10 cells (0..9) at 36° each. M6.2 had grown this to 13 to fit
            // ASCII " / ' / -, M6.4 reverted: Search._normalize handles those
            // chars on the match side so the user types שבק and finds שב"ק
            // without ever needing to enter the quote on the keyboard.
            for (var i = 0; i < 10; i++) {
                result.add({
                    :label => digits[i],
                    :centerAngleDeg => i * WEDGE_ARC_DEG,
                    :rInner => R_INNER,
                    :rOuter => R_OUTER,
                    :arcDeg => WEDGE_ARC_DEG
                });
            }
            cache.put(key, result);
            return result;
        }
        if (t == :LETTER_GROUP) {
            var letters = parent[:letters] as Array<String>;
            var n = letters.size();
            var centerAngle = parent[:centerAngleDeg] as Number;
            var firstOffset = -((n - 1) * WEDGE_ARC_DEG) / 2;
            var result = [];
            // Level-1 sub-zones (regular letters) at r ∈ [R_EXPANSION_INNER, R_INNER].
            for (var i = 0; i < n; i++) {
                var ang = centerAngle + firstOffset + i * WEDGE_ARC_DEG;
                if (ang < 0) { ang = ang + 360; }
                if (ang >= 360) { ang = ang - 360; }
                result.add({
                    :label => letters[i],
                    :centerAngleDeg => ang,
                    :rInner => R_EXPANSION_INNER,
                    :rOuter => R_INNER,
                    :arcDeg => WEDGE_ARC_DEG
                });
            }
            // M3.6 final-form (sofit) sub-zones — flipped OUTWARD from M3.5.
            // Each final-form button now sits in the outer-ring band
            // (r ∈ [R_INNER, R_OUTER]) at the parent letter's angle,
            // visually covering whichever outer-ring button is at that angle.
            // Much larger tap target than the M3.5 inward sub-zones at r=[10, 50].
            for (var i = 0; i < n; i++) {
                var letter = letters[i] as String;
                var finalForm = _finalFormFor(letter);
                if (!finalForm.equals("")) {
                    var ang = centerAngle + firstOffset + i * WEDGE_ARC_DEG;
                    if (ang < 0) { ang = ang + 360; }
                    if (ang >= 360) { ang = ang - 360; }
                    result.add({
                        :label => finalForm,
                        :centerAngleDeg => ang,
                        :rInner => R_INNER,
                        :rOuter => R_OUTER,
                        :arcDeg => WEDGE_ARC_DEG
                    });
                }
            }
            cache.put(key, result);
            return result;
        }
        // SPACE/BACKSPACE: no sub-buttons. Cache the empty array too so
        // future calls are short-circuited.
        var empty = [];
        cache.put(key, empty);
        return empty;
    }

    function subButtonAt(x as Number, y as Number, parent as Dictionary, screenW as Number, screenH as Number) as Dictionary or Null {
        var subs = subButtons(parent, screenW, screenH);
        if (subs.size() == 0) { return null; }
        var cx = screenW / 2;
        var cy = screenH / 2;
        var dx = x - cx;
        var dy = y - cy;
        var rSq = dx * dx + dy * dy;
        var thetaDeg = _angleDeg(dx, dy);
        // M3.5: each sub-zone has its own r range (level-1 vs level-2 finals),
        // so check radial bounds per sub-zone rather than using subs[0]'s range.
        for (var i = 0; i < subs.size(); i++) {
            var s = subs[i] as Dictionary;
            var sRin = s[:rInner] as Number;
            var sRout = s[:rOuter] as Number;
            if (rSq < sRin * sRin || rSq > sRout * sRout) {
                continue;
            }
            var sAngle = s[:centerAngleDeg] as Number;
            var sArc = s[:arcDeg] as Number;
            var diff = thetaDeg - sAngle;
            while (diff < -180) { diff = diff + 360; }
            while (diff > 180) { diff = diff - 360; }
            if (diff >= -(sArc / 2) && diff < (sArc / 2)) {
                return s;
            }
        }
        return null;
    }

    // Returns the final-form (sofit) of a Hebrew letter, or "" if none.
    // M3.5: drives level-2 sub-zones in subButtons.
    function _finalFormFor(letter as String) as String {
        if (letter.equals("כ")) { return "ך"; }
        if (letter.equals("מ")) { return "ם"; }
        if (letter.equals("נ")) { return "ן"; }
        if (letter.equals("פ")) { return "ף"; }
        if (letter.equals("צ")) { return "ץ"; }
        return "";
    }

    // Polar angle in [0, 360) degrees, clockwise from 12 o'clock (up).
    // dx > 0 = right, dy < 0 = up. 12 o'clock direction = (dx=0, dy=-r).
    function _angleDeg(dx as Number, dy as Number) as Number {
        var rad = Math.atan2(dx, -dy);
        var deg = (rad * 180 / Math.PI).toNumber();
        if (deg < 0) { deg = deg + 360; }
        return deg;
    }
}