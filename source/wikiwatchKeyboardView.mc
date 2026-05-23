import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// M3.3 keyboard view. Draw order: center -> outer ring -> expansion. The
// expansion overlay sits on top of everything else (covers center + outer
// if they overlap with the expansion wedges). LETTER_GROUP wedges render
// as N mini letter cells side-by-side tangentially; DIGITS wedge renders
// as 4 cells "0 1 _ 9" (middle blank). SPACE / BACKSPACE flash brighter
// for ~200 ms via _pressedAngleDeg.
class wikiwatchKeyboardView extends WatchUi.View {
    private var _buffer as String;
    private var _expanded as Dictionary?;
    private var _pressedAngleDeg as Number?;

    function initialize() {
        View.initialize();
        _buffer = "";
        _expanded = null;
        _pressedAngleDeg = null;
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
                _drawText(dc, cx, cy, s[:centerAngleDeg] as Number, midR,
                          s[:label] as String, Graphics.FONT_TINY, Graphics.COLOR_BLACK);
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
        // M3.4: bandH 26 -> 40 (fits FONT_TINY's full glyph height), and the
        // text is drawn with TEXT_JUSTIFY_VCENTER so it sits centered inside
        // the band (no overflow above or below).
        var bandW = 180;
        var bandH = 40;
        var bandX = cx - bandW / 2;
        var bandY = cy - 95;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(bandX, bandY, bandW, bandH);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bandX + bandW - 6, bandY + bandH / 2, Graphics.FONT_TINY, _buffer,
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 5 stub suggestion lines below the input band.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var rightX = cx + bandW / 2 - 4;
        var lineY = bandY + bandH + 6;
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