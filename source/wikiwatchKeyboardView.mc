import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// M3.1 keyboard view. Pure render (R3-exempt). Draws a central display area
// (typing buffer + stub suggestion lines) and EITHER the 10 outer wedges
// (collapsed) OR the expansion sub-zones (expanded). Wedges are filled
// annular-sector polygons; labels are straight text at each wedge centroid.
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

        if (_expanded == null) {
            // Collapsed mode: outer ring of 10 wedges.
            var bs = KeyboardLayout.buttons();
            for (var i = 0; i < bs.size(); i++) {
                var b = bs[i] as Dictionary;
                _drawWedge(dc, cx, cy, b[:centerAngleDeg] as Number, KeyboardLayout.WEDGE_ARC_DEG,
                           KeyboardLayout.R_INNER, KeyboardLayout.R_OUTER, Graphics.COLOR_DK_GRAY);
                _drawWedgeLabel(dc, cx, cy, b[:centerAngleDeg] as Number,
                                (KeyboardLayout.R_INNER + KeyboardLayout.R_OUTER) / 2,
                                b[:label] as String, Graphics.COLOR_WHITE);
            }
        } else {
            // Expanded mode: only sub-zones (outer ring hidden).
            var subs = KeyboardLayout.subButtons(_expanded as Dictionary, screenW, screenH);
            for (var i = 0; i < subs.size(); i++) {
                var s = subs[i] as Dictionary;
                _drawWedge(dc, cx, cy, s[:centerAngleDeg] as Number, s[:arcDeg] as Number,
                           s[:rInner] as Number, s[:rOuter] as Number, Graphics.COLOR_LT_GRAY);
                _drawWedgeLabel(dc, cx, cy, s[:centerAngleDeg] as Number,
                                ((s[:rInner] as Number) + (s[:rOuter] as Number)) / 2,
                                s[:label] as String, Graphics.COLOR_BLACK);
            }
        }

        // Center display: typing buffer + suggestion lines (drawn LAST so the
        // expansion wedges sit under it if there's any overlap with the
        // central area).
        _drawCenterDisplay(dc, cx, cy);
    }

    // White-filled input band with right-anchored Hebrew text + 3 stub
    // suggestion lines below in DK_GRAY.
    private function _drawCenterDisplay(dc as Dc, cx as Number, cy as Number) as Void {
        var bandW = 160;
        var bandH = 26;
        var bandX = cx - bandW / 2;
        var bandY = cy - bandH - 6;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(bandX, bandY, bandW, bandH);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bandX + bandW - 4, bandY + 3, Graphics.FONT_SMALL, _buffer,
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Suggestion lines (placeholder for M5 search results).
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + bandW / 2 - 4, cy + 4, Graphics.FONT_TINY,
                    "(suggestion 1)", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(cx + bandW / 2 - 4, cy + 22, Graphics.FONT_TINY,
                    "(suggestion 2)", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(cx + bandW / 2 - 4, cy + 40, Graphics.FONT_TINY,
                    "(suggestion 3)", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Draw an annular-sector wedge as a filled polygon with 5 sample points
    // per arc (10 total vertices). Smooth-enough at 36 deg arcs.
    private function _drawWedge(dc as Dc, cx as Number, cy as Number,
                                centerAngleDeg as Number, arcDeg as Number,
                                rInner as Number, rOuter as Number, color as Graphics.ColorType) as Void {
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

    // Draw a wedge label at the wedge centroid (centerAngleDeg, midRadius).
    private function _drawWedgeLabel(dc as Dc, cx as Number, cy as Number,
                                     centerAngleDeg as Number, midRadius as Number,
                                     label as String, color as Graphics.ColorType) as Void {
        var ang = centerAngleDeg * Math.PI / 180.0;
        var lx = (cx + midRadius * Math.sin(ang)).toNumber();
        var ly = (cy - midRadius * Math.cos(ang)).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, ly, Graphics.FONT_TINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}