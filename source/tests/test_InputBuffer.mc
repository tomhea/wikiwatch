import Toybox.Lang;
import Toybox.Test;

// Tests for InputBuffer (M3). 6 cases covering append / popLast / clear with
// Hebrew strings.

(:test)
function inputbuf_appendToEmpty(logger as Logger) as Boolean {
    var r = InputBuffer.append("", "ש");
    logger.debug("append('', 'ש') = '" + r + "'");
    return r.equals("ש");
}

(:test)
function inputbuf_appendHebrew(logger as Logger) as Boolean {
    var r = InputBuffer.append("ש", "ל");
    logger.debug("append('ש', 'ל') = '" + r + "'");
    return r.equals("של");
}

(:test)
function inputbuf_appendSpace(logger as Logger) as Boolean {
    var r = InputBuffer.append("ש", " ");
    logger.debug("append('ש', ' ') = '" + r + "'");
    return r.equals("ש ");
}

(:test)
function inputbuf_popLastFromTwoChars(logger as Logger) as Boolean {
    var r = InputBuffer.popLast("של");
    logger.debug("popLast('של') = '" + r + "'");
    return r.equals("ש");
}

(:test)
function inputbuf_popLastFromEmpty(logger as Logger) as Boolean {
    // Defensive: empty input should not crash; just return empty.
    var r = InputBuffer.popLast("");
    logger.debug("popLast('') = '" + r + "'");
    return r.equals("");
}

(:test)
function inputbuf_clearReturnsEmpty(logger as Logger) as Boolean {
    var r = InputBuffer.clear("שלום");
    logger.debug("clear('שלום') = '" + r + "'");
    return r.equals("");
}