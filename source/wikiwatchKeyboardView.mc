import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// M3.2 keyboard view. Pure render (R3-exempt). Thin outer ring (depth 35 px
// at R_INNER=170..R_OUTER=205), with each LETTER_GROUP wedge rendered as a
// tri-button: N small letter cells laid out tangentially within the wedge.
// Bolder white separators between wedges. During letter expansion, outer
// ring is dimmed (not hidden) so the user keeps spatial context.
class wikiwatchKeyboardView extends WatchUi.View {
    private var _buffer as String;
    private var _expanded as Dictionary?;

    function initialize() {
        View.initialize();
        _buffer = "";
        _expanded = null;
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

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var screenW = dc.getWidth();
        var screenH = dc.getHeight();
        var cx = screenW / 2;
        var cy = screenH / 2;

        // 1. Outer ring (always drawn). Dimmer fill when letter expansion is
        //    active so the active expansion stands out without losing context.
        //    Note: when DIGITS expansion is active, the OUTER ring is the
        //    digits sub-zones - skip the regular outer ring draw entirely.
        var digitsExpanded = (_expanded != null
            && ((_expanded as Dictionary)[:type] as Symbol) == :DIGITS);
        if (!digitsExpanded) {
            var dim = (_expanded != null);
            var fillColor = dim ? Graphics.COLOR_BLACK : Graphics.COLOR_DK_GRAY;
            var sepColor = dim ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE;
            var bs = KeyboardLayout.buttons();
            for (var i = 0; i < bs.size(); i++) {
                var b = bs[i] as Dictionary;
                _drawWedge(dc, cx, cy, b[:centerAngleDeg] as Number, KeyboardLayout.WEDGE_ARC_DEG,
                           KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, fillColor);
            }
            _drawSeparators(dc, cx, cy, KeyboardLayout.NUM_BUTTONS, KeyboardLayout.WEDGE_ARC_DEG,
                            KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, sepColor);
            for (var i = 0; i < bs.size(); i++) {
                _drawButtonContent(dc, cx, cy, bs[i] as Dictionary, dim);
            }
        }

        // 2. Expansion sub-zones (drawn on top of dimmed outer ring).
        if (_expanded != null) {
            var subs = KeyboardLayout.subButtons(_expanded as Dictionary, screenW, screenH);
            for (var i = 0; i < subs.size(); i++) {
                var s = subs[i] as Dictionary;
                _drawWedge(dc, cx, cy, s[:centerAngleDeg] as Number, s[:arcDeg] as Number,
                           s[:rInner] as Number, s[:rOuter] as Number, Graphics.COLOR_LT_GRAY);
            }
            // Separators around the active expansion (for digits these are
            // the regular outer-ring boundaries).
            if (digitsExpanded) {
                _drawSeparators(dc, cx, cy, KeyboardLayout.NUM_BUTTONS, KeyboardLayout.WEDGE_ARC_DEG,
                                KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, Graphics.COLOR_WHITE);
            }
            for (var i = 0; i < subs.size(); i++) {
                var s = subs[i] as Dictionary;
                var midR = ((s[:rInner] as Number) + (s[:rOuter] as Number)) / 2;
                _drawText(dc, cx, cy, s[:centerAngleDeg] as Number, midR,
                          s[:label] as String, Graphics.FONT_TINY, Graphics.COLOR_BLACK);
            }
        }

        // 3. Center display: typing buffer + 5 stub suggestion lines.
        //    Drawn LAST so it sits on top of any expansion overlap into the
        //    central area (but expansion wedges are confined to r in [50, 170]
        //    so they don't overlap the very-center input band at r < ~50).
        _drawCenterDisplay(dc, cx, cy);
    }

    // Draw the content of one outer button: a single label for SPACE/
    // BACKSPACE/DIGITS, or N small letter cells tangentially for LETTER_GROUP.
    // `dim` darkens the text color when the outer ring is in dimmed state.
    private function _drawButtonContent(dc as Dc, cx as Number, cy as Number,
                                        b as Dictionary, dim as Boolean) as Void {
        var midR = (KeyboardLayout.R_INNER + KeyboardLayout.R_OUTER) / 2;
        var labelColor = dim ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE;
        var t = b[:type] as Symbol;
        var centerAngle = b[:centerAngleDeg] as Number;
        if (t == :LETTER_GROUP) {
            var letters = b[:letters] as Array<String>;
            var n = letters.size();
            // N evenly-spaced angular offsets covering ~24 deg of the 36 deg wedge.
            // For N=3: -12, 0, +12. For N=4: -13.5 (=>13), -4.5 (=>-4), 4.5 (=>5), 13.5 (=>14).
            var cellGapDeg = (n == 4) ? 9 : 12;
            var firstOffset = -((n - 1) * cellGapDeg) / 2;
            for (var i = 0; i < n; i++) {
                var off = firstOffset + i * cellGapDeg;
                _drawText(dc, cx, cy, centerAngle + off, midR,
                          letters[i] as String, Graphics.FONT_XTINY, labelColor);
            }
        } else {
            _drawText(dc, cx, cy, centerAngle, midR,
                      b[:label] as String, Graphics.FONT_TINY, labelColor);
        }
    }

    private function _drawCenterDisplay(dc as Dc, cx as Number, cy as Number) as Void {
        // Input band: white-filled, Hebrew right-anchored.
        var bandW = 180;
        var bandH = 28;
        var bandX = cx - bandW / 2;
        var bandY = cy - 70;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(bandX, bandY, bandW, bandH);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bandX + bandW - 4, bandY + 4, Graphics.FONT_SMALL, _buffer,
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // 5 stub suggestion lines.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var rightX = cx + bandW / 2 - 4;
        var lineY = bandY + bandH + 4;
        var lineStep = 22;
        for (var i = 1; i <= 5; i++) {
            dc.drawText(rightX, lineY, Graphics.FONT_XTINY,
                        "(suggestion " + i + ")", Graphics.TEXT_JUSTIFY_RIGHT);
            lineY = lineY + lineStep;
        }
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

    // Draw radial separator lines at each wedge boundary (between adjacent
    // wedges) so the wedge edges are visually distinct from the wedge fill.
    private function _drawSeparators(dc as Dc, cx as Number, cy as Number,
                                     numWedges as Number, arcDeg as Number,
                                     rInner as Number, rOuter as Number,
                                     color as Graphics.ColorType) as Void {
        var halfArc = arcDeg / 2;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.setPenWidth(2);
        for (var i = 0; i < numWedges; i++) {
            // Boundary between wedge i-1 and wedge i sits at angle i*arcDeg - halfArc.
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

    // Draw `text` centered at the (angle, radius) polar point relative to
    // (cx, cy). Helper shared by outer ring labels + expansion sub-zone labels.
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