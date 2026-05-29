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

// --- M8: putBatch (chunk unpacking into per-article keys) ---

(:test)
function articleStore_putBatchWritesEach(logger as Logger) as Boolean {
    Application.Storage.deleteValue("article:b1");
    Application.Storage.deleteValue("article:b2");
    var n = ArticleStore.putBatch({ "b1" => "body one", "b2" => "body two" });
    var a = ArticleStore.bodyOf("b1");
    var b = ArticleStore.bodyOf("b2");
    Application.Storage.deleteValue("article:b1");
    Application.Storage.deleteValue("article:b2");
    logger.debug("putBatch n=" + n + " a=" + a + " b=" + b);
    return n == 2
        && a != null && a.equals("body one")
        && b != null && b.equals("body two");
}

(:test)
function articleStore_putBatchEmptyReturnsZero(logger as Logger) as Boolean {
    var n = ArticleStore.putBatch({});
    logger.debug("putBatch({}) = " + n);
    return n == 0;
}

(:test)
function articleStore_putBatchOverwrites(logger as Logger) as Boolean {
    Application.Storage.deleteValue("article:ow");
    ArticleStore.putBody("ow", "old");
    ArticleStore.putBatch({ "ow" => "new" });
    var back = ArticleStore.bodyOf("ow");
    Application.Storage.deleteValue("article:ow");
    return back != null && back.equals("new");
}

// --- M8.3: allPresent (corpus integrity spot-check) ---

(:test)
function articleStore_allPresentTrueWhenAllExist(logger as Logger) as Boolean {
    ArticleStore.putBody("ap1", "x");
    ArticleStore.putBody("ap2", "y");
    var r = ArticleStore.allPresent(["ap1", "ap2"] as Array<String>);
    Application.Storage.deleteValue("article:ap1");
    Application.Storage.deleteValue("article:ap2");
    logger.debug("allPresent(all exist) = " + r);
    return r == true;
}

(:test)
function articleStore_allPresentFalseWhenOneMissing(logger as Logger) as Boolean {
    ArticleStore.putBody("ap1", "x");
    Application.Storage.deleteValue("article:apMissing");
    var r = ArticleStore.allPresent(["ap1", "apMissing"] as Array<String>);
    Application.Storage.deleteValue("article:ap1");
    logger.debug("allPresent(one missing) = " + r);
    return r == false;
}
