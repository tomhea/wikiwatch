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
function fixtures_manifestVersionIsThree(logger as Logger) as Boolean {
    // M5.2: version bump from 1 -> 2 lets FixtureInstaller detect that an
    // older (M4/M5/M5.1) install needs to be re-seeded with the new corpus.
    // M5.3: bump to 3 because the shir-lashalom-long body changed (its H1
    // now matches the long manifest title).
    var v = Fixtures.manifest()[:version] as Number;
    logger.debug("Fixtures.manifest version = " + v);
    return v == 3;
}

(:test)
function fixtures_titlesMatchBodies(logger as Logger) as Boolean {
    // M5.3: each fixture's BODY H1 must START WITH the manifest title.
    // (The manifest title can be a prefix of a longer H1 — e.g. shalom's
    // body H1 is "# שלום היא מילה שימושית בהחלט" but its manifest title is
    // just "שלום". What we want to catch is the OLD bug where shir-
    // lashalom-long's body had a shorter H1 than its manifest title —
    // tapping the long suggestion opened an article whose H1 was just
    // "# שיר לשלום".)
    var arts = Fixtures.manifest()[:articles] as Array;
    for (var i = 0; i < arts.size(); i++) {
        var a = arts[i] as Dictionary;
        var id = a[:id] as String;
        var title = a[:title] as String;
        var body = Fixtures.bodyOf(id);
        if (body == null) {
            logger.debug("article " + i + " (" + id + ") has null body");
            return false;
        }
        var expectedPrefix = "# " + title;
        if ((body as String).find(expectedPrefix) != 0) {
            logger.debug("article " + i + " (" + id + ") title MISMATCH: body must start with '" + expectedPrefix + "'");
            return false;
        }
    }
    return true;
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
