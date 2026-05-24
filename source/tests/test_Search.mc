import Toybox.Lang;
import Toybox.Test;

// M5 tests for Search.rank.
//
// Ranking contract:
//   Empty query: top-K (=20) by :popularity DESC, stable tiebreak by :title.
//   Non-empty query:
//     tier 1 = titles where title.find(query) == 0  (prefix match)
//     tier 2 = titles where title.find(query) != null && != 0 (substring,
//                                                              not prefix)
//     each tier sorted by :popularity DESC, stable tiebreak by :title
//     result = [tier1..., tier2...] capped at TOP_K.

(:test)
function search_emptyQueryReturnsTopByPopularity(logger as Logger) as Boolean {
    var arts = [
        { :id => "a", :title => "alpha",   :popularity => 50 },
        { :id => "b", :title => "bravo",   :popularity => 100 },
        { :id => "c", :title => "charlie", :popularity => 75 }
    ];
    var r = Search.rank("", arts);
    logger.debug("empty-query size=" + r.size() + " ids=" + _searchIdsOf(r));
    return r.size() == 3
        && ((r[0] as Dictionary)[:id] as String).equals("b")
        && ((r[1] as Dictionary)[:id] as String).equals("c")
        && ((r[2] as Dictionary)[:id] as String).equals("a");
}

(:test)
function search_emptyQueryCapsAtTwenty(logger as Logger) as Boolean {
    var arts = [];
    for (var i = 0; i < 25; i++) {
        arts.add({ :id => "id" + i, :title => "title" + i, :popularity => i });
    }
    var r = Search.rank("", arts);
    logger.debug("25-articles empty-query size=" + r.size());
    return r.size() == 20;
}

(:test)
function search_emptyArticlesReturnsEmpty(logger as Logger) as Boolean {
    var r = Search.rank("foo", []);
    logger.debug("empty-articles size=" + r.size());
    return r.size() == 0;
}

(:test)
function search_prefixMatchOnly(logger as Logger) as Boolean {
    var arts = [
        { :id => "sh", :title => "שלום", :popularity => 100 },
        { :id => "tr", :title => "תורה", :popularity => 80 },
        { :id => "sb", :title => "שבת",  :popularity => 60 }
    ];
    var r = Search.rank("ש", arts);
    logger.debug("prefix-ש size=" + r.size() + " ids=" + _searchIdsOf(r));
    // Both "שלום" and "שבת" start with ש; higher-popularity "שלום" first.
    return r.size() == 2
        && ((r[0] as Dictionary)[:id] as String).equals("sh")
        && ((r[1] as Dictionary)[:id] as String).equals("sb");
}

(:test)
function search_substringNonPrefixIsTier2(logger as Logger) as Boolean {
    var arts = [
        { :id => "sh", :title => "שלום", :popularity => 100 }
    ];
    // "לו" appears in "שלום" at index 1 (substring, not prefix).
    var r = Search.rank("לו", arts);
    logger.debug("substring-לו size=" + r.size());
    return r.size() == 1 && ((r[0] as Dictionary)[:id] as String).equals("sh");
}

(:test)
function search_prefixBeforeSubstring(logger as Logger) as Boolean {
    var arts = [
        { :id => "love",  :title => "love",  :popularity => 10 },
        { :id => "alove", :title => "alove", :popularity => 100 },
        { :id => "lover", :title => "lover", :popularity => 50 }
    ];
    var r = Search.rank("love", arts);
    logger.debug("prefix-vs-sub size=" + r.size() + " ids=" + _searchIdsOf(r));
    // tier 1 (prefix): lover pop=50, love pop=10 -> [lover, love]
    // tier 2 (substring): alove pop=100 -> [alove]
    // combined: [lover, love, alove]
    return r.size() == 3
        && ((r[0] as Dictionary)[:id] as String).equals("lover")
        && ((r[1] as Dictionary)[:id] as String).equals("love")
        && ((r[2] as Dictionary)[:id] as String).equals("alove");
}

(:test)
function search_popularityWithinTier(logger as Logger) as Boolean {
    var arts = [
        { :id => "low",  :title => "abc1", :popularity => 10 },
        { :id => "high", :title => "abc2", :popularity => 90 }
    ];
    var r = Search.rank("abc", arts);
    logger.debug("popularity ids=" + _searchIdsOf(r));
    return r.size() == 2
        && ((r[0] as Dictionary)[:id] as String).equals("high")
        && ((r[1] as Dictionary)[:id] as String).equals("low");
}

(:test)
function search_titleStableTiebreakOnPopularityTie(logger as Logger) as Boolean {
    var arts = [
        { :id => "z", :title => "ZZZ", :popularity => 50 },
        { :id => "a", :title => "AAA", :popularity => 50 }
    ];
    var r = Search.rank("", arts);
    logger.debug("tiebreak ids=" + _searchIdsOf(r));
    // Equal popularity, codepoint-order on title: 'A' (65) < 'Z' (90).
    return r.size() == 2
        && ((r[0] as Dictionary)[:id] as String).equals("a")
        && ((r[1] as Dictionary)[:id] as String).equals("z");
}

(:test)
function search_noMatchesReturnsEmpty(logger as Logger) as Boolean {
    var arts = [{ :id => "sh", :title => "שלום", :popularity => 100 }];
    var r = Search.rank("xyz", arts);
    logger.debug("no-match size=" + r.size());
    return r.size() == 0;
}

(:test)
function search_hebrewSubstringMatch(logger as Logger) as Boolean {
    var arts = [
        { :id => "torah",  :title => "תורה",   :popularity => 80 },
        { :id => "elohim", :title => "אלוהים", :popularity => 50 }
    ];
    var r = Search.rank("תור", arts);
    logger.debug("hebrew-prefix size=" + r.size() + " ids=" + _searchIdsOf(r));
    // "תור" is a prefix of "תורה"; "אלוהים" doesn't contain it.
    return r.size() == 1 && ((r[0] as Dictionary)[:id] as String).equals("torah");
}

// Helper: render an array of article dicts as "[id1,id2,...]" for debug logs.
// Non-test (no `(:test)` annotation) so the harness doesn't try to run it.
function _searchIdsOf(arr as Array) as String {
    var s = "[";
    for (var i = 0; i < arr.size(); i++) {
        if (i > 0) { s = s + ","; }
        s = s + ((arr[i] as Dictionary)[:id] as String);
    }
    return s + "]";
}
