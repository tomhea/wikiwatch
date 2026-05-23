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