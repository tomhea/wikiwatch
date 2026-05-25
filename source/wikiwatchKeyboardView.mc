import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// M3.3 keyboard view. Draw order: center -> outer ring -> expansion. The
// expansion overlay sits on top of everything else (covers center + outer
// if they overlap with the expansion wedges). LETTER_GROUP wedges render
// as N mini letter cells side-by-side tangentially; DIGITS wedge renders
// as 4 cells "0 1 _ 9" (middle blank). SPACE / BACKSPACE flash brighter
// for ~200 ms via _pressedAngleDeg.
class wikiwatchKeyboardView extends WatchUi.View {
    // M5.1 suggestion-area geometry. Bigger taps: 1-line buffer band
    // (was 2 lines in M5), 3 rows of FONT_TINY at 40 px step (was 5
    // rows of FONT_XTINY at 22 px), and a "▼ N more" footer row that
    // pushes the full-screen ResultsView. Must match the math in
    // suggestionAt + moreHit + _drawCenterDisplay.
    private const _BAND_W = 200;
    private const _BAND_H = 30;
    private const _BAND_Y_OFFSET = -95;       // bandY = cy + _BAND_Y_OFFSET
    private const _SUGGESTION_Y_START_OFFSET = 10;
    private const _SUGGESTION_LINE_STEP = 40;
    private const _MAX_SUGGESTIONS = 3;
    private const _MORE_ROW_OFFSET = 6;
    private const _MORE_ROW_HEIGHT = 22;

    private var _buffer as String;
    private var _expanded as Dictionary?;
    private var _pressedAngleDeg as Number?;
    private var _suggestions as Array<Dictionary>?;
    private var _moreCount as Number;

    function initialize() {
        View.initialize();
        _buffer = "";
        _expanded = null;
        _pressedAngleDeg = null;
        _suggestions = null;
        _moreCount = 0;
    }

    function setBuffer(b as String) as Void {
        _buffer = b;
        WatchUi.requestUpdate();
    }

    function setExpanded(p as Dictionary) as Void {
        _expanded = p;
        WatchUi.requestUpdate();
    }

    function clearExpansion() as Void {
        _expanded = null;
        WatchUi.requestUpdate();
    }

    function setPressed(angleDeg as Number) as Void {
        _pressedAngleDeg = angleDeg;
        WatchUi.requestUpdate();
    }

    function clearPressed() as Void {
        _pressedAngleDeg = null;
        WatchUi.requestUpdate();
    }

    // M5: replace the stub suggestion strings with real ranked results.
    function setSuggestions(s as Array<Dictionary>) as Void {
        _suggestions = s;
        WatchUi.requestUpdate();
    }

    // M5.1: count of results NOT shown inline (= total ranked - 3 visible).
    // Renders as a "▼ N more" footer row when > 0; tapping it pushes the
    // full-screen ResultsView.
    function setMoreCount(n as Number) as Void {
        _moreCount = (n < 0) ? 0 : n;
        WatchUi.requestUpdate();
    }

    // M5: return the suggestion dict at the tapped (x, y), or null. The
    // suggestion area sits entirely within r < R_HIT_INNER (=131), so it
    // never overlaps the outer-ring wedge hit-test — no precedence
    // conflict. x must be inside the band-x range; taps off the side
    // fall through to the wedge hit-test.
    function suggestionAt(x as Number, y as Number) as Dictionary? {
        if (_suggestions == null) { return null; }
        var suggestions = _suggestions as Array<Dictionary>;
        var n = suggestions.size();
        if (n == 0) { return null; }
        if (n > _MAX_SUGGESTIONS) { n = _MAX_SUGGESTIONS; }
        var settings = System.getDeviceSettings();
        var cx = settings.screenWidth / 2;
        var cy = settings.screenHeight / 2;
        var bandX = cx - _BAND_W / 2;
        if (x < bandX || x > bandX + _BAND_W) { return null; }
        var rowsTop = cy + _BAND_Y_OFFSET + _BAND_H + _SUGGESTION_Y_START_OFFSET;
        for (var i = 0; i < n; i++) {
            var top = rowsTop + i * _SUGGESTION_LINE_STEP;
            var bottom = top + _SUGGESTION_LINE_STEP;
            if (y >= top && y < bottom) {
                return suggestions[i] as Dictionary;
            }
        }
        return null;
    }

    // M5.1: true iff (x, y) falls inside the "▼ N more" footer row. The
    // delegate calls this BEFORE suggestionAt + the wedge hit-test.
    // Returns false if _moreCount is 0 (footer not rendered).
    function moreHit(x as Number, y as Number) as Boolean {
        if (_moreCount <= 0) { return false; }
        var settings = System.getDeviceSettings();
        var cx = settings.screenWidth / 2;
        var cy = settings.screenHeight / 2;
        var bandX = cx - _BAND_W / 2;
        if (x < bandX || x > bandX + _BAND_W) { return false; }
        var rowsBottom = cy + _BAND_Y_OFFSET + _BAND_H + _SUGGESTION_Y_START_OFFSET
                       + _MAX_SUGGESTIONS * _SUGGESTION_LINE_STEP;
        var moreTop = rowsBottom + _MORE_ROW_OFFSET;
        var moreBottom = moreTop + _MORE_ROW_HEIGHT;
        return y >= moreTop && y < moreBottom;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var cx = screenW / 2;
        var cy = screenH / 2;

        // 1. Center display (drawn FIRST so expansion can cover it).
        _drawCenterDisplay(dc, cx, cy);

        // 2. Outer ring (dimmed during letter expansion, hidden during digits expansion).
        var digitsExpanded = (_expanded != null
            && ((_expanded as Dictionary)[:type] as Symbol) == :DIGITS);
        if (!digitsExpanded) {
            var dim = (_expanded != null);
            var defaultFill = dim ? Graphics.COLOR_BLACK : Graphics.COLOR_DK_GRAY;
            var pressedFill = Graphics.COLOR_LT_GRAY;
            var sepColor = dim ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE;
            var bs = KeyboardLayout.buttons();
            for (var i = 0; i < bs.size(); i++) {
                var b = bs[i] as Dictionary;
                var ang = b[:centerAngleDeg] as Number;
                var fill = (_pressedAngleDeg != null && _pressedAngleDeg == ang)
                    ? pressedFill : defaultFill;
                _drawWedge(dc, cx, cy, ang, KeyboardLayout.WEDGE_ARC_DEG,
                           KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, fill);
            }
            _drawSeparators(dc, cx, cy, KeyboardLayout.NUM_BUTTONS, KeyboardLayout.WEDGE_ARC_DEG,
                            KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, sepColor);
            for (var i = 0; i < bs.size(); i++) {
                var b = bs[i] as Dictionary;
                var ang = b[:centerAngleDeg] as Number;
                var isPressed = (_pressedAngleDeg != null && _pressedAngleDeg == ang);
                _drawButtonContent(dc, cx, cy, b, dim, isPressed);
            }
        }

        // 3. Expansion (drawn LAST - on top of center + outer ring).
        if (_expanded != null) {
            var subs = KeyboardLayout.subButtons(_expanded as Dictionary, screenW, screenH);
            for (var i = 0; i < subs.size(); i++) {
                var s = subs[i] as Dictionary;
                _drawWedge(dc, cx, cy, s[:centerAngleDeg] as Number, s[:arcDeg] as Number,
                           s[:rInner] as Number, s[:rOuter] as Number, Graphics.COLOR_LT_GRAY);
            }
            if (digitsExpanded) {
                _drawSeparators(dc, cx, cy, KeyboardLayout.NUM_BUTTONS, KeyboardLayout.WEDGE_ARC_DEG,
                                KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, Graphics.COLOR_WHITE);
            }
            for (var i = 0; i < subs.size(); i++) {
                var s = subs[i] as Dictionary;
                var midR = ((s[:rInner] as Number) + (s[:rOuter] as Number)) / 2;
                // M3.5: level-2 sub-zones (finals, r in [10, 50]) are smaller —
                // use FONT_XTINY so the Hebrew glyph fits in the tighter radial depth.
                var font = ((s[:rOuter] as Number) <= 50)
                    ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
                _drawText(dc, cx, cy, s[:centerAngleDeg] as Number, midR,
                          s[:label] as String, font, Graphics.COLOR_BLACK);
            }
        }
    }

    private function _drawButtonContent(dc as Dc, cx as Number, cy as Number,
                                        b as Dictionary, dim as Boolean,
                                        isPressed as Boolean) as Void {
        var midR = (KeyboardLayout.R_INNER + KeyboardLayout.R_OUTER) / 2;
        var labelColor = isPressed
            ? Graphics.COLOR_BLACK
            : (dim ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE);
        var t = b[:type] as Symbol;
        var centerAngle = b[:centerAngleDeg] as Number;
        if (t == :LETTER_GROUP) {
            var letters = b[:letters] as Array<String>;
            var n = letters.size();
            var cellGapDeg = (n == 4) ? 9 : 12;
            var firstOffset = -((n - 1) * cellGapDeg) / 2;
            for (var i = 0; i < n; i++) {
                var off = firstOffset + i * cellGapDeg;
                _drawText(dc, cx, cy, centerAngle + off, midR,
                          letters[i] as String, Graphics.FONT_XTINY, labelColor);
            }
        } else if (t == :DIGITS) {
            // Display 4 mini cells "0 1 _ 9" (middle is a blank space - placeholder
            // for "more digits between 1 and 9"). Same tangential layout as 4-letter
            // group. Full expansion still shows all 10 digits.
            var cells = ["0", "1", " ", "9"];
            var cellGapDeg = 9;
            var firstOffset = -((cells.size() - 1) * cellGapDeg) / 2;
            for (var i = 0; i < cells.size(); i++) {
                var off = firstOffset + i * cellGapDeg;
                _drawText(dc, cx, cy, centerAngle + off, midR,
                          cells[i] as String, Graphics.FONT_XTINY, labelColor);
            }
        } else {
            // SPACE / BACKSPACE: single centered label, slightly larger.
            _drawText(dc, cx, cy, centerAngle, midR,
                      b[:label] as String, Graphics.FONT_TINY, labelColor);
        }
    }

    private function _drawCenterDisplay(dc as Dc, cx as Number, cy as Number) as Void {
        // M5.1: 1-line buffer band (was 2 in M3.5/M5). bandH 64 -> 30 to
        // give the suggestion area more room for bigger tap targets.
        // Long buffers tail-truncate to one line — acceptable for typical
        // search queries (1-4 chars).
        var bandX = cx - _BAND_W / 2;
        var bandY = cy + _BAND_Y_OFFSET;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(bandX, bandY, _BAND_W, _BAND_H);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        // Buffer text: take the LAST line of the char-wrap so long inputs
        // show the most-recent tail.
        var lines = _wrapBufferIntoLines(dc, _buffer, Graphics.FONT_TINY, _BAND_W - 12);
        var lastIdx = lines.size() - 1;
        if (lastIdx >= 0) {
            dc.drawText(bandX + _BAND_W - 6, bandY + _BAND_H / 2,
                        Graphics.FONT_TINY, lines[lastIdx] as String,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // M5.1: render up to 3 real ranked suggestions in FONT_TINY, big
        // tappable rows. Right-justified Hebrew titles vertically centered
        // within each 40-px row. Light gray for contrast against the
        // black background; the M5 dark-gray was too dim once the rows
        // grew.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var rightX = cx + _BAND_W / 2 - 4;
        var rowsTop = bandY + _BAND_H + _SUGGESTION_Y_START_OFFSET;
        var sugs = _suggestions;
        var sn = (sugs == null) ? 0 : (sugs as Array<Dictionary>).size();
        if (sn > _MAX_SUGGESTIONS) { sn = _MAX_SUGGESTIONS; }
        for (var i = 0; i < sn; i++) {
            var s = (sugs as Array<Dictionary>)[i] as Dictionary;
            var rowY = rowsTop + i * _SUGGESTION_LINE_STEP + _SUGGESTION_LINE_STEP / 2;
            dc.drawText(rightX, rowY, Graphics.FONT_TINY,
                        s[:title] as String,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // M5.1: "▼ N more" footer row (only when there are more results
        // than fit inline). Tap target for the full-screen ResultsView.
        if (_moreCount > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            var moreY = rowsTop + _MAX_SUGGESTIONS * _SUGGESTION_LINE_STEP
                      + _MORE_ROW_OFFSET + _MORE_ROW_HEIGHT / 2;
            dc.drawText(cx, moreY, Graphics.FONT_XTINY,
                        "▼ " + _moreCount + " more",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Greedy char-based wrap: build lines that fit in maxPx by measuring
    // the candidate substring with dc.getTextWidthInPixels. Each char that
    // doesn't fit triggers a new line. Returns empty array for empty input.
    private function _wrapBufferIntoLines(dc as Dc, text as String, font as Graphics.FontType, maxPx as Number) as Array<String> {
        var lines = [];
        if (text.length() == 0) { return lines; }
        var len = text.length();
        var lineStart = 0;
        var i = lineStart + 1;
        while (i <= len) {
            var candidate = text.substring(lineStart, i);
            if (dc.getTextWidthInPixels(candidate, font) > maxPx) {
                // Emit the substring up to i-1 if non-empty, else single char (overflow).
                if (i - 1 > lineStart) {
                    lines.add(text.substring(lineStart, i - 1));
                    lineStart = i - 1;
                } else {
                    lines.add(text.substring(lineStart, i));
                    lineStart = i;
                }
                i = lineStart + 1;
            } else {
                i = i + 1;
            }
        }
        if (lineStart < len) {
            lines.add(text.substring(lineStart, len));
        }
        return lines;
    }

    private function _drawWedge(dc as Dc, cx as Number, cy as Number,
                                centerAngleDeg as Number, arcDeg as Number,
                                rInner as Number, rOuter as Number,
                                color as Graphics.ColorType) as Void {
        var halfArc = arcDeg / 2;
        var step = arcDeg / 4;
        var pts = new [10];
        for (var i = 0; i < 5; i++) {
            var off = -halfArc + i * step;
            var ang = (centerAngleDeg + off) * Math.PI / 180.0;
            var sx = (cx + rOuter * Math.sin(ang)).toNumber();
            var sy = (cy - rOuter * Math.cos(ang)).toNumber();
            pts[i] = [sx, sy];
        }
        for (var i = 0; i < 5; i++) {
            var off = halfArc - i * step;
            var ang = (centerAngleDeg + off) * Math.PI / 180.0;
            var sx = (cx + rInner * Math.sin(ang)).toNumber();
            var sy = (cy - rInner * Math.cos(ang)).toNumber();
            pts[5 + i] = [sx, sy];
        }
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.fillPolygon(pts);
    }

    private function _drawSeparators(dc as Dc, cx as Number, cy as Number,
                                     numWedges as Number, arcDeg as Number,
                                     rInner as Number, rOuter as Number,
                                     color as Graphics.ColorType) as Void {
        var halfArc = arcDeg / 2;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.setPenWidth(2);
        for (var i = 0; i < numWedges; i++) {
            var boundary = i * arcDeg - halfArc;
            var ang = boundary * Math.PI / 180.0;
            var ix = (cx + rInner * Math.sin(ang)).toNumber();
            var iy = (cy - rInner * Math.cos(ang)).toNumber();
            var ox = (cx + rOuter * Math.sin(ang)).toNumber();
            var oy = (cy - rOuter * Math.cos(ang)).toNumber();
            dc.drawLine(ix, iy, ox, oy);
        }
        dc.setPenWidth(1);
    }

    private function _drawText(dc as Dc, cx as Number, cy as Number,
                               angleDeg as Number, radius as Number,
                               text as String, font as Graphics.FontType,
                               color as Graphics.ColorType) as Void {
        var ang = angleDeg * Math.PI / 180.0;
        var tx = (cx + radius * Math.sin(ang)).toNumber();
        var ty = (cy - radius * Math.cos(ang)).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, ty, font, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}