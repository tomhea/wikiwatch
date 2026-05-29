import Toybox.Lang;
import Toybox.Test;

// M8.3 tests for the single-entry laid-out-article cache.

(:test)
function layoutCache_putGetRoundtrip(logger as Logger) as Boolean {
    ArticleLayoutCache.clear();
    var lines = [ { :text => "a" }, { :text => "b" } ];
    ArticleLayoutCache.put("k1", lines, 123);
    var got = ArticleLayoutCache.get("k1");
    logger.debug("get(k1) = " + got);
    return got != null
        && (got[:contentHeight] as Number) == 123
        && (got[:lines] as Array).size() == 2;
}

(:test)
function layoutCache_missReturnsNull(logger as Logger) as Boolean {
    ArticleLayoutCache.clear();
    ArticleLayoutCache.put("k1", [ { :text => "a" } ], 10);
    var got = ArticleLayoutCache.get("other");
    logger.debug("get(other) = " + got);
    return got == null;
}

(:test)
function layoutCache_putReplacesPrevious(logger as Logger) as Boolean {
    ArticleLayoutCache.clear();
    ArticleLayoutCache.put("k1", [ { :text => "a" } ], 10);
    ArticleLayoutCache.put("k2", [ { :text => "b" }, { :text => "c" } ], 20);
    var old = ArticleLayoutCache.get("k1");
    var cur = ArticleLayoutCache.get("k2");
    ArticleLayoutCache.clear();
    return old == null && cur != null && (cur[:contentHeight] as Number) == 20;
}

(:test)
function layoutCache_clearEmpties(logger as Logger) as Boolean {
    ArticleLayoutCache.put("k1", [ { :text => "a" } ], 10);
    ArticleLayoutCache.clear();
    return ArticleLayoutCache.get("k1") == null;
}
