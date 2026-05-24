import Toybox.Lang;
import Toybox.Test;

// M4 tests for the Fixtures pure module. No Storage interaction.

(:test)
function fixtures_manifestHasThreeArticles(logger as Logger) as Boolean {
    var m = Fixtures.manifest();
    var arts = m[:articles] as Array;
    logger.debug("Fixtures.manifest articles.size = " + arts.size());
    return arts.size() >= 3;
}

(:test)
function fixtures_allArticlesHaveNonEmptyTitleAndBody(logger as Logger) as Boolean {
    var arts = Fixtures.manifest()[:articles] as Array;
    if (arts.size() < 3) {
        logger.debug("less than 3 fixtures: " + arts.size());
        return false;
    }
    for (var i = 0; i < arts.size(); i++) {
        var a = arts[i] as Dictionary;
        var title = a[:title] as String;
        var id = a[:id] as String;
        var body = Fixtures.bodyOf(id);
        if (title == null || title.length() == 0) {
            logger.debug("article " + i + " has empty title");
            return false;
        }
        if (body == null || body.length() == 0) {
            logger.debug("article " + i + " (" + id + ") has empty body");
            return false;
        }
    }
    return true;
}

(:test)
function fixtures_bodyOfKnownReturnsNonEmpty(logger as Logger) as Boolean {
    var arts = Fixtures.manifest()[:articles] as Array;
    if (arts.size() == 0) { return false; }
    var firstId = (arts[0] as Dictionary)[:id] as String;
    var body = Fixtures.bodyOf(firstId);
    logger.debug("bodyOf('" + firstId + "') len = " + (body == null ? -1 : body.length()));
    return body != null && body.length() > 0;
}
