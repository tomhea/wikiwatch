import Toybox.Lang;
import Toybox.Test;

// M9.7 tests for WordSanitize — strip non letter/space/number from a word.

(:test)
function wordSanitize_stripsTrailingPunctuation(logger as Logger) as Boolean {
    logger.debug("'" + WordSanitize.searchable("שלום,") + "'");
    return WordSanitize.searchable("שלום,").equals("שלום")
        && WordSanitize.searchable("שלום.").equals("שלום")
        && WordSanitize.searchable("\"שלום\"").equals("שלום");
}

(:test)
function wordSanitize_keepsDigitsAndStripsParens(logger as Logger) as Boolean {
    return WordSanitize.searchable("(2018)").equals("2018");
}

(:test)
function wordSanitize_keepsSpacesAndLatin(logger as Logger) as Boolean {
    return WordSanitize.searchable("שלום עליכם").equals("שלום עליכם")
        && WordSanitize.searchable("PayPal").equals("PayPal");
}

(:test)
function wordSanitize_stripsHyphenAndApostrophe(logger as Logger) as Boolean {
    // strip = remove (not convert to space): per the rule "non letter/space/number".
    logger.debug("'" + WordSanitize.searchable("בן-גוריון") + "'");
    return WordSanitize.searchable("בן-גוריון").equals("בןגוריון")
        && WordSanitize.searchable("d'or").equals("dor");
}

(:test)
function wordSanitize_allPunctuationBecomesEmpty(logger as Logger) as Boolean {
    return WordSanitize.searchable("—!?:;").equals("")
        && WordSanitize.searchable("").equals("");
}
