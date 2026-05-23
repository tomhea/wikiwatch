import Toybox.Lang;
import Toybox.Test;

(:test)
function md_h1(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("# Title");
    logger.debug("parse('# Title') = " + t);
    return t[:level] == 1 && t[:text].equals("Title");
}

(:test)
function md_h2(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("## sub");
    return t[:level] == 2 && t[:text].equals("sub");
}

(:test)
function md_h3(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("### third");
    return t[:level] == 3 && t[:text].equals("third");
}

(:test)
function md_h4(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("#### h4");
    return t[:level] == 4 && t[:text].equals("h4");
}

(:test)
function md_fiveHashesIsBody(logger as Logger) as Boolean {
    // 5 hashes is beyond the spec; treat the whole line as body.
    var t = MarkdownTokens.parse("##### nope");
    return t[:level] == 0 && t[:text].equals("##### nope");
}

(:test)
function md_emptyHeader(logger as Logger) as Boolean {
    // "# " (one hash + space) is a valid empty H1.
    var t = MarkdownTokens.parse("# ");
    return t[:level] == 1 && t[:text].equals("");
}

(:test)
function md_plainBody(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("plain");
    return t[:level] == 0 && t[:text].equals("plain");
}

(:test)
function md_hashWithoutSpaceIsBody(logger as Logger) as Boolean {
    // Markdown requires a space (or end-of-line) after the hashes.
    var t = MarkdownTokens.parse("#nospace");
    return t[:level] == 0 && t[:text].equals("#nospace");
}

(:test)
function md_emptyString(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("");
    return t[:level] == 0 && t[:text].equals("");
}

(:test)
function md_hebrewHeader(logger as Logger) as Boolean {
    var t = MarkdownTokens.parse("## שלום");
    return t[:level] == 2 && t[:text].equals("שלום");
}

(:test)
function md_hashAlone(logger as Logger) as Boolean {
    // Just "#" with no trailing space/text is a valid empty H1.
    var t = MarkdownTokens.parse("#");
    return t[:level] == 1 && t[:text].equals("");
}