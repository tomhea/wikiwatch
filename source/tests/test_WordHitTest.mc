import Toybox.Lang;
import Toybox.Test;

// M6.1 tests for WordHitTest.findWordPx — pixel-accurate word hit-test
// (replaces the M6 char-count-approximation findWordInLine that caused
// off-by-one bugs and a left-side dead zone).
//
// Contract:
//   findWordPx(contentX, words, wordPx, lineRightX, spacePx):
//     - text is right-anchored at lineRightX (visual right edge).
//     - words[i] visually occupies [rightEdge - wordPx[i], rightEdge]
//       where rightEdge starts at lineRightX and shifts left by
//       (wordPx[i] + spacePx) per word.
//     - For Hebrew RTL, words[0] is logically first AND visually
//       rightmost.
//     - Each word "owns" the space to its LEFT (toward the next word)
//       so taps on whitespace snap to the preceding word — natural
//       for "I just read this word, then tapped just past it".
//     - Returns null when the tap is past the right edge (contentX
//       > lineRightX), past the left edge (contentX < leftmost word's
//       left edge), or when words is empty.

// Common test fixture:
//   words = ["abc", "def", "ghi"]  (3 words, each 30 px wide)
//   spacePx = 10
//   lineRightX = 300
// Layout (visual, right -> left):
//   abc: [270, 300]
//   space: [260, 270]  (owned by abc)
//   def: [230, 260]
//   space: [220, 230]  (owned by def)
//   ghi: [190, 220]

(:test)
function wordHitTest_insideFirstWord(logger as Logger) as Boolean {
    var r = WordHitTest.findWordPx(285, ["abc", "def", "ghi"], [30, 30, 30], 300, 10);
    logger.debug("findWordPx(285) = " + r);
    return r != null && (r as String).equals("abc");
}

(:test)
function wordHitTest_insideMiddleWord(logger as Logger) as Boolean {
    var r = WordHitTest.findWordPx(245, ["abc", "def", "ghi"], [30, 30, 30], 300, 10);
    logger.debug("findWordPx(245) = " + r);
    return r != null && (r as String).equals("def");
}

(:test)
function wordHitTest_insideLastWord(logger as Logger) as Boolean {
    // M6 bug 2: left-side taps returned null. With pixel-accurate math,
    // a tap visually on the leftmost word correctly returns it.
    var r = WordHitTest.findWordPx(205, ["abc", "def", "ghi"], [30, 30, 30], 300, 10);
    logger.debug("findWordPx(205, last word) = " + r);
    return r != null && (r as String).equals("ghi");
}

(:test)
function wordHitTest_onSpaceSnapsToPreviousWord(logger as Logger) as Boolean {
    // Tap on the space [260, 270] between "abc" and "def" → "abc" (the
    // word just read). M6 bug 1: char-count off-by-one made this return
    // "def" instead.
    var r = WordHitTest.findWordPx(265, ["abc", "def", "ghi"], [30, 30, 30], 300, 10);
    logger.debug("findWordPx(265 on space) = " + r);
    return r != null && (r as String).equals("abc");
}

(:test)
function wordHitTest_pastRightEdge(logger as Logger) as Boolean {
    var r = WordHitTest.findWordPx(305, ["abc", "def", "ghi"], [30, 30, 30], 300, 10);
    logger.debug("findWordPx(305 past right) = " + r);
    return r == null;
}

(:test)
function wordHitTest_pastLeftEdge(logger as Logger) as Boolean {
    var r = WordHitTest.findWordPx(185, ["abc", "def", "ghi"], [30, 30, 30], 300, 10);
    logger.debug("findWordPx(185 past left) = " + r);
    return r == null;
}

(:test)
function wordHitTest_emptyWords(logger as Logger) as Boolean {
    var r = WordHitTest.findWordPx(250, [], [], 300, 10);
    logger.debug("findWordPx(empty words) = " + r);
    return r == null;
}
