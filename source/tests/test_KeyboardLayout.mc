import Toybox.Lang;
import Toybox.Test;

// M3.1 tests for the rewritten KeyboardLayout (wedge geometry).

(:test)
function kbd_buttonsReturns10Wedges(logger as Logger) as Boolean {
    var b = KeyboardLayout.buttons();
    logger.debug("buttons.size=" + b.size());
    return b.size() == 10;
}

(:test)
function kbd_buttonZeroIsSpace(logger as Logger) as Boolean {
    var b = KeyboardLayout.buttons();
    if (b.size() < 1) { return false; }
    var k = b[0] as Dictionary;
    logger.debug("[0] label=" + k[:label] + " type=" + k[:type] + " angle=" + k[:centerAngleDeg]);
    return (k[:label] as String).equals("_") && k[:type] == :SPACE && (k[:centerAngleDeg] as Number) == 0;
}

(:test)
function kbd_buttonOneIsBackspace(logger as Logger) as Boolean {
    var b = KeyboardLayout.buttons();
    if (b.size() < 2) { return false; }
    var k = b[1] as Dictionary;
    logger.debug("[1] label=" + k[:label] + " type=" + k[:type] + " angle=" + k[:centerAngleDeg]);
    return (k[:label] as String).equals("X") && k[:type] == :BACKSPACE && (k[:centerAngleDeg] as Number) == 36;
}

(:test)
function kbd_buttonTwoIsAlefGroup(logger as Logger) as Boolean {
    var b = KeyboardLayout.buttons();
    if (b.size() < 3) { return false; }
    var k = b[2] as Dictionary;
    var letters = k[:letters] as Array<String>;
    logger.debug("[2] label=" + k[:label] + " type=" + k[:type] + " letters=" + letters + " angle=" + k[:centerAngleDeg]);
    return k[:type] == :LETTER_GROUP
        && (k[:centerAngleDeg] as Number) == 72
        && letters.size() == 3
        && letters[0].equals("א")
        && letters[1].equals("ב")
        && letters[2].equals("ג");
}

(:test)
function kbd_buttonEightIsQuadLetter(logger as Logger) as Boolean {
    // Position 8 is the 4-letter group קרשת at 288 degrees.
    var b = KeyboardLayout.buttons();
    if (b.size() < 9) { return false; }
    var k = b[8] as Dictionary;
    var letters = k[:letters] as Array<String>;
    logger.debug("[8] letters=" + letters + " angle=" + k[:centerAngleDeg]);
    return k[:type] == :LETTER_GROUP
        && (k[:centerAngleDeg] as Number) == 288
        && letters.size() == 4
        && letters[0].equals("ק")
        && letters[3].equals("ת");
}

(:test)
function kbd_buttonNineIsDigits(logger as Logger) as Boolean {
    var b = KeyboardLayout.buttons();
    if (b.size() < 10) { return false; }
    var k = b[9] as Dictionary;
    var letters = k[:letters] as Array<String>;
    logger.debug("[9] label=" + k[:label] + " type=" + k[:type] + " letters.size=" + letters.size());
    return k[:type] == :DIGITS
        && (k[:centerAngleDeg] as Number) == 324
        && letters.size() == 10
        && letters[0].equals("0")
        && letters[9].equals("9");
}

(:test)
function kbd_buttonAtInsideAlefGroupReturnsIt(logger as Logger) as Boolean {
    // M3.2 outer ring is thinner: R_INNER=170, R_OUTER=205, midRadius=187.
    // אבג wedge at angle 72°. Tap at (208 + 187*sin(72°), 208 - 187*cos(72°))
    // = (208+178, 208-58) = (386, 150) sits inside the new ring at the wedge.
    var k = KeyboardLayout.buttonAt(386, 150, 416, 416);
    if (k == null) { logger.debug("buttonAt returned null"); return false; }
    var d = k as Dictionary;
    logger.debug("buttonAt(386,150)=" + d[:label] + " type=" + d[:type]);
    return d[:type] == :LETTER_GROUP && (d[:centerAngleDeg] as Number) == 72;
}

(:test)
function kbd_buttonAtInsideHitHaloReturnsWedge(logger as Logger) as Boolean {
    // M3.3 added a hit halo: visual ring R_INNER=160..R_OUTER=205, but buttonAt
    // accepts r >= R_HIT_INNER=145. A point at angle 72°, r=150 (inside halo,
    // outside visual ring) should still return the אבג wedge.
    // (208 + 150*sin(72°), 208 - 150*cos(72°)) ~ (208+143, 208-46) = (351, 162).
    var k = KeyboardLayout.buttonAt(351, 162, 416, 416);
    if (k == null) { logger.debug("buttonAt(351,162) returned null"); return false; }
    var d = k as Dictionary;
    logger.debug("buttonAt(351,162)=" + d[:label] + " angle=" + d[:centerAngleDeg]);
    return d[:type] == :LETTER_GROUP && (d[:centerAngleDeg] as Number) == 72;
}

(:test)
function kbd_buttonAtJustOutsideHaloReturnsNull(logger as Logger) as Boolean {
    // M3.4: R_HIT_INNER=131 (was 145). r=125 is just outside the new halo.
    // (208 + 125*sin(72°), 208 - 125*cos(72°)) ~ (208+119, 208-39) = (327, 169).
    var k = KeyboardLayout.buttonAt(327, 169, 416, 416);
    logger.debug("buttonAt(327,169) = " + k);
    return k == null;
}

(:test)
function kbd_buttonAtNewWiderHaloReturnsWedge(logger as Logger) as Boolean {
    // M3.4 widened ring + halo: R_HIT_INNER=131 (was 145). A tap at r=135
    // (between old and new halos) at angle 72° should now hit the אבג wedge.
    // (208 + 135*sin(72°), 208 - 135*cos(72°)) ~ (208+128, 208-42) = (336, 166).
    var k = KeyboardLayout.buttonAt(336, 166, 416, 416);
    if (k == null) { logger.debug("buttonAt(336,166) returned null"); return false; }
    var d = k as Dictionary;
    logger.debug("buttonAt(336,166)=" + d[:label]);
    return d[:type] == :LETTER_GROUP && (d[:centerAngleDeg] as Number) == 72;
}

(:test)
function kbd_buttonAtCenterReturnsNull(logger as Logger) as Boolean {
    // Screen center (208, 208) is at radius 0 - inside R_INNER=105. No wedge.
    var k = KeyboardLayout.buttonAt(208, 208, 416, 416);
    logger.debug("buttonAt(208,208) = " + k);
    return k == null;
}

(:test)
function kbd_buttonAtOffRingReturnsNull(logger as Logger) as Boolean {
    // Top-left corner of bezel (0, 0) is far past R_OUTER=205 from center.
    var k = KeyboardLayout.buttonAt(0, 0, 416, 416);
    logger.debug("buttonAt(0,0) = " + k);
    return k == null;
}

(:test)
function kbd_subButtonsLetterGroupReturnsThree(logger as Logger) as Boolean {
    // For אבג parent (centerAngleDeg=72), expansion is 3 sub-zones at
    // 72-36=36, 72, 72+36=108 degrees.
    var parent = { :label => "אבג", :type => :LETTER_GROUP, :letters => ["א", "ב", "ג"], :centerAngleDeg => 72 };
    var subs = KeyboardLayout.subButtons(parent, 416, 416);
    logger.debug("subButtons(אבג).size=" + subs.size());
    if (subs.size() != 3) { return false; }
    var s0 = subs[0] as Dictionary;
    var s1 = subs[1] as Dictionary;
    var s2 = subs[2] as Dictionary;
    return (s0[:label] as String).equals("א") && (s0[:centerAngleDeg] as Number) == 36
        && (s1[:label] as String).equals("ב") && (s1[:centerAngleDeg] as Number) == 72
        && (s2[:label] as String).equals("ג") && (s2[:centerAngleDeg] as Number) == 108;
}

(:test)
function kbd_subButtonsLetterGroupFourReturnsFour(logger as Logger) as Boolean {
    // For קרשת parent (centerAngleDeg=288), expansion is 4 sub-zones at
    // 288-54, 288-18, 288+18, 288+54 = 234, 270, 306, 342 degrees.
    var parent = { :label => "קרשת", :type => :LETTER_GROUP, :letters => ["ק", "ר", "ש", "ת"], :centerAngleDeg => 288 };
    var subs = KeyboardLayout.subButtons(parent, 416, 416);
    logger.debug("subButtons(קרשת).size=" + subs.size());
    if (subs.size() != 4) { return false; }
    var s0 = subs[0] as Dictionary;
    var s3 = subs[3] as Dictionary;
    return (s0[:label] as String).equals("ק") && (s0[:centerAngleDeg] as Number) == 234
        && (s3[:label] as String).equals("ת") && (s3[:centerAngleDeg] as Number) == 342;
}

(:test)
function kbd_subButtonsDigitsReturnsTenAroundRing(logger as Logger) as Boolean {
    // For DIGITS expansion, 10 sub-zones each 36° wide at angles 0, 36, ..., 324.
    var parent = { :label => "0-9", :type => :DIGITS, :letters => ["0","1","2","3","4","5","6","7","8","9"], :centerAngleDeg => 324 };
    var subs = KeyboardLayout.subButtons(parent, 416, 416);
    logger.debug("subButtons(digits).size=" + subs.size());
    if (subs.size() != 10) { return false; }
    var s0 = subs[0] as Dictionary;
    var s5 = subs[5] as Dictionary;
    var s9 = subs[9] as Dictionary;
    return (s0[:label] as String).equals("0") && (s0[:centerAngleDeg] as Number) == 0
        && (s5[:label] as String).equals("5") && (s5[:centerAngleDeg] as Number) == 180
        && (s9[:label] as String).equals("9") && (s9[:centerAngleDeg] as Number) == 324;
}

(:test)
function kbd_subButtonAtInsideLetterExpansionReturnsLabel(logger as Logger) as Boolean {
    // אבג parent at 72°. Sub-zone for ב is at 72°. Tap at r=80 (inside expansion ring),
    // angle 72°: (cx + 80*sin(72°), cy - 80*cos(72°)) = (208+76, 208-24) = (284, 184).
    var parent = { :label => "אבג", :type => :LETTER_GROUP, :letters => ["א", "ב", "ג"], :centerAngleDeg => 72 };
    var s = KeyboardLayout.subButtonAt(284, 184, parent, 416, 416);
    if (s == null) { logger.debug("subButtonAt returned null"); return false; }
    var d = s as Dictionary;
    logger.debug("subButtonAt(284,184) = " + d[:label]);
    return (d[:label] as String).equals("ב");
}

(:test)
function kbd_subButtonAtOutsideExpansionReturnsNull(logger as Logger) as Boolean {
    // For LETTER_GROUP expansion, taps inside R_EXPANSION_INNER (center) return null.
    var parent = { :label => "אבג", :type => :LETTER_GROUP, :letters => ["א", "ב", "ג"], :centerAngleDeg => 72 };
    var s = KeyboardLayout.subButtonAt(208, 208, parent, 416, 416);
    logger.debug("subButtonAt(208,208) center = " + s);
    return s == null;
}