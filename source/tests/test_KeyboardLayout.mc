import Toybox.Lang;
import Toybox.Test;

// Tests for KeyboardLayout (M3). 8 cases covering keys() structure + keyAt
// hit-testing on the 416-px simulator screen.

(:test)
function kbd_keysHas30Entries(logger as Logger) as Boolean {
    var k = KeyboardLayout.keys();
    logger.debug("keys size=" + k.size());
    return k.size() == 30;
}

(:test)
function kbd_keysHas22Letters(logger as Logger) as Boolean {
    var k = KeyboardLayout.keys();
    var count = 0;
    for (var i = 0; i < k.size(); i++) {
        if ((k[i] as Dictionary)[:type] == :LETTER) { count++; }
    }
    logger.debug("letter count=" + count);
    return count == 22;
}

(:test)
function kbd_keysHasFourSpecials(logger as Logger) as Boolean {
    var k = KeyboardLayout.keys();
    var space = 0; var back = 0; var del = 0; var search = 0;
    for (var i = 0; i < k.size(); i++) {
        var t = (k[i] as Dictionary)[:type];
        if (t == :SPACE) { space++; }
        else if (t == :BACKSPACE) { back++; }
        else if (t == :DELETE_ALL) { del++; }
        else if (t == :SEARCH) { search++; }
    }
    logger.debug("specials: space=" + space + " back=" + back + " del=" + del + " search=" + search);
    return space == 1 && back == 1 && del == 1 && search == 1;
}

(:test)
function kbd_firstLetterIsAlef(logger as Logger) as Boolean {
    // Iterate row-major; the first :LETTER entry should be "א" (aleph).
    var k = KeyboardLayout.keys();
    for (var i = 0; i < k.size(); i++) {
        if ((k[i] as Dictionary)[:type] == :LETTER) {
            var label = (k[i] as Dictionary)[:label] as String;
            logger.debug("first letter = '" + label + "'");
            return label.equals("א");
        }
    }
    return false;
}

(:test)
function kbd_lastLetterIsTav(logger as Logger) as Boolean {
    // The last :LETTER entry should be "ת" (tav, 22nd Hebrew letter).
    var k = KeyboardLayout.keys();
    var lastLabel = "";
    for (var i = 0; i < k.size(); i++) {
        if ((k[i] as Dictionary)[:type] == :LETTER) {
            lastLabel = (k[i] as Dictionary)[:label] as String;
        }
    }
    logger.debug("last letter = '" + lastLabel + "'");
    return lastLabel.equals("ת");
}

(:test)
function kbd_keyAtTopLeftLetterCell(logger as Logger) as Boolean {
    // Center of cell (row 0, col 0) on the 416-px sim returns the first letter (א).
    // Grid bounds: y=65, h=260; chord at y=65 (dy=-143) half=151; gridW=302; cellW=50.
    // gridX = (416-302)/2 = 57. Cell (0,0) spans x=57..107, y=65..117. Center=(82, 91).
    var k = KeyboardLayout.keyAt(82, 91, 416, 416);
    logger.debug("keyAt(82, 91) = " + k);
    return k != null && ((k as Dictionary)[:label] as String).equals("א");
}

(:test)
function kbd_keyAtOutsideGridReturnsNull(logger as Logger) as Boolean {
    // Top-left bezel corner is outside any cell.
    var k = KeyboardLayout.keyAt(0, 0, 416, 416);
    logger.debug("keyAt(0, 0) = " + k);
    return k == null;
}

(:test)
function kbd_keyAtBufferAreaReturnsNull(logger as Logger) as Boolean {
    // y=10 is in the buffer area (above gridY=65). No key.
    var k = KeyboardLayout.keyAt(208, 10, 416, 416);
    logger.debug("keyAt(208, 10) = " + k);
    return k == null;
}