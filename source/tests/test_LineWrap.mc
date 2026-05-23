import Toybox.Lang;
import Toybox.Test;

(:test)
function wrap_emptyInput(logger as Logger) as Boolean {
    // Empty input collapses to a single empty line so callers can iterate uniformly.
    var l = LineWrap.wrap("", 10);
    logger.debug("wrap('', 10) = " + l);
    return l.size() == 1 && l[0].equals("");
}

(:test)
function wrap_singleWordFits(logger as Logger) as Boolean {
    var l = LineWrap.wrap("hello", 10);
    return l.size() == 1 && l[0].equals("hello");
}

(:test)
function wrap_twoWordsFitOnOneLine(logger as Logger) as Boolean {
    // "hi bye" is 6 chars; maxChars 10 means it fits.
    var l = LineWrap.wrap("hi bye", 10);
    return l.size() == 1 && l[0].equals("hi bye");
}

(:test)
function wrap_twoWordsSecondOverflows(logger as Logger) as Boolean {
    // "hello world" = 11 chars (5+1+5). maxChars=7 -> first line "hello" (5), then "world" (5).
    var l = LineWrap.wrap("hello world", 7);
    logger.debug("wrap('hello world', 7) = " + l);
    return l.size() == 2 && l[0].equals("hello") && l[1].equals("world");
}

(:test)
function wrap_greedyFill(logger as Logger) as Boolean {
    // "a b c d" with maxChars=3: line1 "a b" (3 chars), line2 "c d" (3 chars).
    var l = LineWrap.wrap("a b c d", 3);
    return l.size() == 2 && l[0].equals("a b") && l[1].equals("c d");
}

(:test)
function wrap_singleLongWordOverflowsAlone(logger as Logger) as Boolean {
    // A single word longer than maxChars overflows its own line (don't break inside a word).
    var l = LineWrap.wrap("supercalifragilistic", 5);
    return l.size() == 1 && l[0].equals("supercalifragilistic");
}

(:test)
function wrap_longWordThenShort(logger as Logger) as Boolean {
    // The long word gets its own line; the short follows on the next.
    var l = LineWrap.wrap("supercalifragilistic ok", 5);
    return l.size() == 2 && l[0].equals("supercalifragilistic") && l[1].equals("ok");
}

(:test)
function wrap_hebrewWords(logger as Logger) as Boolean {
    // "שלום שלום" = 9 chars (4+1+4). maxChars=5 forces two lines.
    var l = LineWrap.wrap("שלום שלום", 5);
    logger.debug("wrap hebrew result size=" + l.size() + " [0]=" + l[0] + " [1]=" + (l.size() > 1 ? l[1] : "(none)"));
    return l.size() == 2 && l[0].equals("שלום") && l[1].equals("שלום");
}

(:test)
function wrap_extraSpacesCollapse(logger as Logger) as Boolean {
    // Multiple consecutive spaces shouldn't produce empty "word" lines.
    var l = LineWrap.wrap("a  b", 10);
    return l.size() == 1 && l[0].equals("a b");
}
(:test)
function wtw_emptyText(logger as Logger) as Boolean {
    var l = LineWrap.wrapToWidths("", 6, [60], 0);
    return l.size() == 1 && l[0].equals("");
}

(:test)
function wtw_uniformWidthsWrapsOnOverflow(logger as Logger) as Boolean {
    // 60 px / 6 px-per-char = 10 char max. "hello world" = 11 chars - wraps.
    var l = LineWrap.wrapToWidths("hello world", 6, [60], 0);
    logger.debug("wtw_uniform = " + l);
    return l.size() == 2 && l[0].equals("hello") && l[1].equals("world");
}

(:test)
function wtw_variableWidthsNarrowsFirst(logger as Logger) as Boolean {
    // widths = [12, 24, 60]. line 0 max 2 chars; line 1 max 4 chars; line 2 max 10.
    // "a b c d e" greedy pack: "a" / "b c" / "d e".
    var l = LineWrap.wrapToWidths("a b c d e", 6, [12, 24, 60], 0);
    logger.debug("wtw_variable = " + l);
    return l.size() == 3 && l[0].equals("a") && l[1].equals("b c") && l[2].equals("d e");
}

(:test)
function wtw_startIndexOffsetSkipsEarlyEntries(logger as Logger) as Boolean {
    // startIndex = 2 -> first output uses widths[2] = 60 (10 chars). "a b c d e" = 9 chars fits.
    var l = LineWrap.wrapToWidths("a b c d e", 6, [12, 24, 60], 2);
    return l.size() == 1 && l[0].equals("a b c d e");
}

(:test)
function wtw_defaultBeyondArray(logger as Logger) as Boolean {
    // widths has only 1 entry. wrap beyond uses last entry (= 60).
    var l = LineWrap.wrapToWidths("hello world", 6, [60], 0);
    return l.size() == 2;
}

(:test)
function wtw_hebrewWithVariableWidths(logger as Logger) as Boolean {
    // "שלום שלום שלום" = 14 chars (4+1+4+1+4). widths = [24, 60] -> 4 chars / 10 chars.
    // Line 0 (max 4): "שלום". Line 1 (max 10): "שלום שלום" = 9 chars.
    var l = LineWrap.wrapToWidths("שלום שלום שלום", 6, [24, 60], 0);
    logger.debug("wtw_hebrew = " + l);
    return l.size() == 2 && l[0].equals("שלום") && l[1].equals("שלום שלום");
}
(:test)
function wnt_emptyText(logger as Logger) as Boolean {
    var l = LineWrap.wrapWithNarrowTail("", 6, 60, 30, 18);
    return l.size() == 1 && l[0].equals("");
}

(:test)
function wnt_singleShortWord(logger as Logger) as Boolean {
    // "hi" fits in edgeWidth (18 / 6 = 3 chars). Single line at edge.
    var l = LineWrap.wrapWithNarrowTail("hi", 6, 60, 30, 18);
    return l.size() == 1 && l[0].equals("hi");
}

(:test)
function wnt_twoWords(logger as Logger) as Boolean {
    // "hello world" = 11 chars. edge=18 (3 max), second=30 (5 max), middle=60 (10 max).
    // last sub: pack from end: "world" (5) > 3, but line empty so add anyway. last="world".
    // penultimate: "hello" (5) ≤ 5 ✓. penultimate="hello".
    // middle: empty.
    // Result: ["hello", "world"].
    var l = LineWrap.wrapWithNarrowTail("hello world", 6, 60, 30, 18);
    logger.debug("twoWords = " + l);
    return l.size() == 2 && l[0].equals("hello") && l[1].equals("world");
}

(:test)
function wnt_middlePlusTailPattern(logger as Logger) as Boolean {
    // "a b c d e f g h i j" = 10 single-char words = 19 chars.
    // edge=18 (3 max): pack from end: "j" (1). + " i" → 3 ✓. + " h" → 5 > 3. Stop. last="i j".
    // second=30 (5 max): pack from end: "h" (1). + " g" → 3 ✓. + " f" → 5 ✓. + " e" → 7 > 5. Stop. penultimate="f g h".
    // middle: remaining "a b c d e". Wrap at 60 (10 max): all fits in one. ["a b c d e"].
    // Final: ["a b c d e", "f g h", "i j"]
    var l = LineWrap.wrapWithNarrowTail("a b c d e f g h i j", 6, 60, 30, 18);
    logger.debug("middlePlusTail = " + l);
    return l.size() == 3 && l[0].equals("a b c d e") && l[1].equals("f g h") && l[2].equals("i j");
}

(:test)
function wnt_longTextMultipleMiddleLines(logger as Logger) as Boolean {
    // 20 single-char words. edge max 3, second max 5, middle max 10.
    // last: "s t" (3). penultimate: "p q r" (5). remaining 15 words "a b c ... o" (29 chars).
    // wrap at middle 10: line1 max 10 chars: pack "a b c d e" (9). next " f" → 11 > 10. commit.
    // line2: "f g h i j" (9). " k" → 11 > 10. commit.
    // line3: "k l m n o" (9). end. commit.
    // Total middle: ["a b c d e", "f g h i j", "k l m n o"]. + penultimate + last.
    // Total 5 sub-lines.
    var l = LineWrap.wrapWithNarrowTail("a b c d e f g h i j k l m n o p q r s t", 6, 60, 30, 18);
    logger.debug("longText size=" + l.size());
    return l.size() == 5 && l[0].equals("a b c d e") && l[3].equals("p q r") && l[4].equals("s t");
}

(:test)
function wnt_oversizedSingleWord(logger as Logger) as Boolean {
    // edge=18 (3 chars). "supercali" (9 chars). Can't fit in 3, but it's the only word.
    // Reverse-pack last: word=supercali, line empty -> add anyway. last="supercali".
    // No more words. penultimate, middle = empty.
    // Result: ["supercali"]
    var l = LineWrap.wrapWithNarrowTail("supercali", 6, 60, 30, 18);
    return l.size() == 1 && l[0].equals("supercali");
}

(:test)
function wnt_hebrewLongLastRaw(logger as Logger) as Boolean {
    // Hebrew last-raw scenario. Use big article-style widths so semantics match production.
    // text: 10 Hebrew words (~50 chars). middle=416 (69 max), second=250 (41 max), edge=160 (26 max).
    // last: pack from end up to 26 chars.
    // penultimate: pack next up to 41 chars.
    // middle: rest at 69 max.
    var l = LineWrap.wrapWithNarrowTail("שלום היא ברכה ופרידה בעברית עתיקה ובברית קדומה", 6, 416, 250, 160);
    logger.debug("hebrewLongLastRaw size=" + l.size() + " lines=" + l);
    // Expect at least 1 line. Last line non-empty.
    return l.size() >= 1 && !l[l.size() - 1].equals("");
}
// M2.8 (option B): tests for the pixel-accurate wrap functions.

(:test)
function splitWords_empty(logger as Logger) as Boolean {
    var w = LineWrap.splitWords("");
    logger.debug("splitWords('') size=" + w.size());
    return w.size() == 0;
}

(:test)
function splitWords_collapsesMultiSpace(logger as Logger) as Boolean {
    // Multi/leading/trailing spaces should collapse to no empty word entries.
    var w = LineWrap.splitWords("  hello   world  ");
    logger.debug("splitWords spaces = " + w);
    return w.size() == 2 && w[0].equals("hello") && w[1].equals("world");
}

(:test)
function splitWords_hebrew(logger as Logger) as Boolean {
    var w = LineWrap.splitWords("שלום עולם");
    logger.debug("splitWords hebrew size=" + w.size());
    return w.size() == 2 && w[0].equals("שלום") && w[1].equals("עולם");
}

(:test)
function wptw_empty(logger as Logger) as Boolean {
    // Empty word list -> single empty output line so callers iterate uniformly.
    var l = LineWrap.wrapPxToWidths([], [], 5, [100], 0);
    logger.debug("wptw empty size=" + l.size());
    return l.size() == 1 && l[0].equals("");
}

(:test)
function wptw_singleWordFits(logger as Logger) as Boolean {
    var l = LineWrap.wrapPxToWidths(["hello"], [50], 5, [100], 0);
    logger.debug("wptw single = " + l);
    return l.size() == 1 && l[0].equals("hello");
}

(:test)
function wptw_twoWordsFitOnOneLine(logger as Logger) as Boolean {
    // 20 + 5 + 20 = 45 <= 100, both fit.
    var l = LineWrap.wrapPxToWidths(["a", "b"], [20, 20], 5, [100], 0);
    logger.debug("wptw twoFit = " + l);
    return l.size() == 1 && l[0].equals("a b");
}

(:test)
function wptw_perLineWidthCascade(logger as Logger) as Boolean {
    // Line 0 budget 50: "a"(30) fits; add "b"? 30+5+30=65 > 50. Emit "a". Carry "b".
    // Line 1 budget 70: "b"(30) fits; add "c"? 30+5+30=65 <= 70. Emit "b c".
    var l = LineWrap.wrapPxToWidths(["a", "b", "c"], [30, 30, 30], 5, [50, 70], 0);
    logger.debug("wptw cascade = " + l);
    return l.size() == 2 && l[0].equals("a") && l[1].equals("b c");
}

(:test)
function wptw_oversizedWordOverflowsAlone(logger as Logger) as Boolean {
    // Word "huge" (200 px) > budget (50). Must emit on its own line.
    var l = LineWrap.wrapPxToWidths(["x", "huge", "y"], [10, 200, 10], 5, [50], 0);
    logger.debug("wptw oversized = " + l);
    return l.size() == 3 && l[0].equals("x") && l[1].equals("huge") && l[2].equals("y");
}

(:test)
function wpnt_empty(logger as Logger) as Boolean {
    var l = LineWrap.wrapPxWithNarrowTail([], [], 5, 100, 70, 60);
    logger.debug("wpnt empty size=" + l.size());
    return l.size() == 1 && l[0].equals("");
}

(:test)
function wpnt_middlePlusTail(logger as Logger) as Boolean {
    // 5 words of 20 px each, space 5. middle=100, second=50, edge=30.
    // Reverse-pack last at edge=30: "e"(20) fits; "d"? 20+5+20=45 > 30. last="e".
    // Reverse-pack penultimate at second=50: "d"(20) fits; "c"? 20+5+20=45 <= 50. fits. "b"? 45+5+20=70 > 50. penultimate="c d".
    // Forward-pack remainder ["a","b"] at middle=100: "a"(20) + " " + "b"(20) = 45 <= 100. line = "a b".
    // Result: ["a b", "c d", "e"].
    var l = LineWrap.wrapPxWithNarrowTail(["a","b","c","d","e"], [20,20,20,20,20], 5, 100, 50, 30);
    logger.debug("wpnt middlePlusTail = " + l);
    return l.size() == 3 && l[0].equals("a b") && l[1].equals("c d") && l[2].equals("e");
}

(:test)
function wpnt_oversizedLastWordOnly(logger as Logger) as Boolean {
    // Last word 200 px overflows edge=30; emits alone. Penultimate "x" (10) fits in second=50.
    // Forward remainder empty.
    // Result: ["x", "verylongword"].
    var l = LineWrap.wrapPxWithNarrowTail(["x", "verylongword"], [10, 200], 5, 100, 50, 30);
    logger.debug("wpnt oversized = " + l);
    return l.size() == 2 && l[0].equals("x") && l[1].equals("verylongword");
}