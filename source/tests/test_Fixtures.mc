import Toybox.Lang;
import Toybox.Test;

// M4 tests for the Fixtures pure module. No Storage interaction.

(:test)
function fixtures_manifestHasThirtyArticles(logger as Logger) as Boolean {
    // M5.2: corpus expanded from 3 -> 30 fixture articles so the keyboard's
    // "▼ N more" footer + full-screen ResultsView paths get exercised.
    var m = Fixtures.manifest();
    var arts = m[:articles] as Array;
    logger.debug("Fixtures.manifest articles.size = " + arts.size());
    return arts.size() >= 30;
}

(:test)
function fixtures_manifestVersionIsTwo(logger as Logger) as Boolean {
    // M5.2: version bump from 1 -> 2 lets FixtureInstaller detect that an
    // older (M4/M5/M5.1) install needs to be re-seeded with the new corpus.
    var v = Fixtures.manifest()[:version] as Number;
    logger.debug("Fixtures.manifest version = " + v);
    return v == 2;
}

(:test)
function fixtures_allTitlesStartWithShin(logger as Logger) as Boolean {
    // M5.2: all 30 fixture titles start with the Hebrew letter ש so the
    // M5 prefix-match path and the M5.1 "▼ N more" overflow are both
    // exercised by typing ש in the keyboard.
    var arts = Fixtures.manifest()[:articles] as Array;
    for (var i = 0; i < arts.size(); i++) {
        var t = (arts[i] as Dictionary)[:title] as String;
        if (t == null || t.find("ש") != 0) {
            logger.debug("article " + i + " title='" + t + "' does NOT start with ש");
            return false;
        }
    }
    return true;
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
