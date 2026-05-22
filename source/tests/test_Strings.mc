import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function strings_helloIsHebrew(logger as Logger) as Boolean {
    var s = Strings.hello();
    logger.debug("Strings.hello() = '" + s + "'");
    return s.equals("שלום");
}

(:test)
function strings_helloCharCount(logger as Logger) as Boolean {
    // "שלום" is 4 Hebrew code points: ש (U+05E9), ל (U+05DC), ו (U+05D5), ם (U+05DD).
    var s = Strings.hello();
    logger.debug("Strings.hello().length() = " + s.length());
    return s.length() == 4;
}

(:test)
function strings_hebrewLiteralRoundtripsThroughStorage(logger as Logger) as Boolean {
    // Decoupled from Strings.hello() on purpose: this asserts UTF-8 survives
    // Application.Storage serialization (critical for M7 article-corpus storage),
    // independent of whether the Strings module is implemented yet.
    var s = "שלום";
    Application.Storage.setValue("test_hebrew_roundtrip", s);
    var back = Application.Storage.getValue("test_hebrew_roundtrip") as String;
    Application.Storage.deleteValue("test_hebrew_roundtrip");
    logger.debug("roundtrip back = '" + back + "' (length=" + (back != null ? back.length() : -1) + ")");
    return back != null && s.equals(back) && back.length() == 4;
}