import Toybox.Lang;

// M6.1 pixel-accurate word hit-test for long-press. Pure module —
// only Toybox.Lang.
//
// Replaces M6's char-count approximation (findWordInLine) which used
// `text.length() * charPx` — for mixed-width Hebrew that produces ±1
// word error inside lines AND a dead zone on the left side (when the
// estimated text_width was smaller than the actual rendered width,
// taps on visually-present leftmost words computed a char_index past
// totalChars and returned null).
//
// New algorithm walks words right-to-left using the actual per-word
// pixel widths (which wikiwatchView._layoutBatchRange already measures
// via dc.getTextWidthInPixels and now stashes in each line dict's
// :words / :wordPx / :spacePx fields).
//
// Hebrew RTL: CIQ's BiDi renderer puts the first LOGICAL char (and
// first logical WORD) at the visual right edge. words[0] is logically
// first AND visually rightmost. Walking left from lineRightX subtracts
// wordPx + spacePx per word.
//
// Each word "owns" the space to its left (toward the next word). A tap
// on whitespace snaps to the preceding word — natural for "I just read
// this word, then tapped just past it".
module WordHitTest {
    function findWordPx(
        contentX as Number,
        words as Array<String>,
        wordPx as Array<Number>,
        lineRightX as Number,
        spacePx as Number
    ) as String? {
        var n = words.size();
        if (n == 0) { return null; }
        if (contentX > lineRightX) { return null; }
        var rightEdge = lineRightX;
        for (var i = 0; i < n; i++) {
            var wordW = wordPx[i] as Number;
            // This word's bounds (its own glyphs, no space yet).
            var leftEdge = rightEdge - wordW;
            // "Own" the trailing space (toward the next word, visually LEFT
            // since we're walking right-to-left). Last word has no trailing
            // space.
            var leftEdgeWithSpace = leftEdge;
            if (i < n - 1) {
                leftEdgeWithSpace = leftEdgeWithSpace - spacePx;
            }
            if (contentX >= leftEdgeWithSpace) {
                return words[i] as String;
            }
            rightEdge = leftEdgeWithSpace;
        }
        return null;  // contentX < leftmost word's left edge
    }

    // M6 char-count helper REMOVED in M6.1 — replaced by findWordPx
    // (pixel-accurate). The view no longer calls findWordInLine.
}
