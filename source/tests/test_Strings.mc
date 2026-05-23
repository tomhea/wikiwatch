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
    var s = Strings.hello();
    return s.length() == 4;
}

(:test)
function strings_hebrewLiteralRoundtripsThroughStorage(logger as Logger) as Boolean {
    var s = "שלום";
    Application.Storage.setValue("test_hebrew_roundtrip", s);
    var back = Application.Storage.getValue("test_hebrew_roundtrip") as String;
    Application.Storage.deleteValue("test_hebrew_roundtrip");
    return back != null && s.equals(back) && back.length() == 4;
}

(:test)
function strings_sampleArticleStartsWithH1(logger as Logger) as Boolean {
    // The sample article exercises every header level; assert it leads with H1.
    var a = Strings.sampleArticle();
    logger.debug("sampleArticle prefix: '" + a.substring(0, 10) + "...'");
    return a.find("# ") == 0;
}

(:test)
function strings_sampleArticleHasH4(logger as Logger) as Boolean {
    var a = Strings.sampleArticle();
    return a.find("\n#### ") != null;
}

(:test)
function strings_sampleArticleIsMultiline(logger as Logger) as Boolean {
    // Must contain at least two newlines to be useful as a multi-line layout demo.
    var a = Strings.sampleArticle();
    var firstNl = a.find("\n");
    if (firstNl == null) { return false; }
    var rest = a.substring(firstNl + 1, a.length());
    return rest.find("\n") != null;
}