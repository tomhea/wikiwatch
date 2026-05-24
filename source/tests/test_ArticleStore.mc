import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M4 tests for the ArticleStore storage wrapper. Keys "article:<id>".

(:test)
function articleStore_putGetRoundtrip(logger as Logger) as Boolean {
    Application.Storage.deleteValue("article:test-rt");
    var body = "# כותרת\n\nתוכן עברי לבדיקה.";
    var ok = ArticleStore.putBody("test-rt", body);
    var back = ArticleStore.bodyOf("test-rt");
    Application.Storage.deleteValue("article:test-rt");
    logger.debug("put=" + ok + " back len=" + (back == null ? -1 : back.length()));
    return ok && back != null && back.equals(body);
}

(:test)
function articleStore_bodyOfMissingReturnsNull(logger as Logger) as Boolean {
    Application.Storage.deleteValue("article:does-not-exist");
    var r = ArticleStore.bodyOf("does-not-exist");
    logger.debug("bodyOf('does-not-exist') = " + r);
    return r == null;
}

(:test)
function articleStore_putBodyOverwrites(logger as Logger) as Boolean {
    Application.Storage.deleteValue("article:overwrite-test");
    ArticleStore.putBody("overwrite-test", "first");
    ArticleStore.putBody("overwrite-test", "second");
    var back = ArticleStore.bodyOf("overwrite-test");
    Application.Storage.deleteValue("article:overwrite-test");
    logger.debug("after-overwrite = '" + back + "'");
    return back != null && back.equals("second");
}
