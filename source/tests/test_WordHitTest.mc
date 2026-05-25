import Toybox.Lang;
import Toybox.Test;

// M6 tests for WordHitTest.findWordInLine — the pure word-at-tap helper
// behind wikiwatchView.findWordAt + wikiwatchDelegate.onHold.
//
// Contract:
//   findWordInLine(contentX, text, lineRightX, charPx):
//     - text is right-anchored at lineRightX (visual right edge).
//     - charPx is an average per-char width (approximate; Hebrew chars
//       vary 6-13 px on built-in fonts).
//     - Returns the word at the tap (logical-order; for Hebrew RTL the
//       FIRST logical word sits visually at the right edge).
//     - Each word "owns" the trailing space so taps on whitespace snap
//       to the preceding word.
//     - Returns null when the tap is past the right edge, past the left
//       edge of the text, or when text is empty.

// Fixtures used by all tests:
//   text = "abc def ghi" (11 chars; "abc" 0-2, ' ' 3, "def" 4-6, ' ' 7, "ghi" 8-10)
//   lineRightX = 300, charPx = 10
//   text_width_px ≈ 110; text_left_x ≈ 190
//   Word ownership (incl. trailing space):
//     "abc" → char 0..3
//     "def" → char 4..7
//     "ghi" → char 8..10

(:test)
function wordHitTest_returnsWordInsideText(logger as Logger) as Boolean {
    // Tap at x=255 → char_index = (300-255)/10 = 4 → first word with end > 4
    // is "def" (which owns chars 4..7).
    var r = WordHitTest.findWordInLine(255, "abc def ghi", 300, 10);
    logger.debug("findWordInLine(255, 'abc def ghi', 300, 10) = " + r);
    return r != null && (r as String).equals("def");
}

(:test)
function wordHitTest_returnsFirstWordAtRightEdge(logger as Logger) as Boolean {
    // Tap at x=297 (close to rightX=300) → char_index = 0 → "abc".
    var r = WordHitTest.findWordInLine(297, "abc def ghi", 300, 10);
    logger.debug("findWordInLine(297, ...) = " + r);
    return r != null && (r as String).equals("abc");
}

(:test)
function wordHitTest_returnsLastWordAtLeftEdge(logger as Logger) as Boolean {
    // Tap at x=192 → char_index = 10 → "ghi" (owns 8..10).
    var r = WordHitTest.findWordInLine(192, "abc def ghi", 300, 10);
    logger.debug("findWordInLine(192, ...) = " + r);
    return r != null && (r as String).equals("ghi");
}

(:test)
function wordHitTest_returnsNullPastLeftEdge(logger as Logger) as Boolean {
    // Tap at x=185 → char_index = 11 >= totalChars(11) → null.
    var r = WordHitTest.findWordInLine(185, "abc def ghi", 300, 10);
    logger.debug("findWordInLine(185, past-left) = " + r);
    return r == null;
}

(:test)
function wordHitTest_returnsNullPastRightEdge(logger as Logger) as Boolean {
    // Tap at x=305 > rightX(300) → null.
    var r = WordHitTest.findWordInLine(305, "abc def ghi", 300, 10);
    logger.debug("findWordInLine(305, past-right) = " + r);
    return r == null;
}

(:test)
function wordHitTest_returnsNullEmptyText(logger as Logger) as Boolean {
    var r = WordHitTest.findWordInLine(250, "", 300, 10);
    logger.debug("findWordInLine(empty text) = " + r);
    return r == null;
}
