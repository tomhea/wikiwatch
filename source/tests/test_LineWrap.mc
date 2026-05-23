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