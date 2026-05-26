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
function search_emptyQueryCapsAtTopK(logger as Logger) as Boolean {
    // M5.2: TOP_K was 20, bumped to 50. Verify the cap with 60 articles.
    var arts = [];
    for (var i = 0; i < 60; i++) {
        arts.add({ :id => "id" + i, :title => "title" + i, :popularity => i });
    }
    var r = Search.rank("", arts);
    logger.debug("60-articles empty-query size=" + r.size());
    return r.size() == 50;
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

// --- M5.2: Search.totalMatches ---

(:test)
function search_totalMatchesEmptyQueryReturnsArraySize(logger as Logger) as Boolean {
    // Empty query matches every article (matches the empty-query branch of rank).
    var arts = [];
    for (var i = 0; i < 7; i++) {
        arts.add({ :id => "x" + i, :title => "x" + i, :popularity => 0 });
    }
    var t = Search.totalMatches("", arts);
    logger.debug("totalMatches('', size=7) = " + t);
    return t == 7;
}

(:test)
function search_totalMatchesCountsExactly(logger as Logger) as Boolean {
    var arts = [
        { :id => "a", :title => "שלום",  :popularity => 0 },  // matches ש
        { :id => "b", :title => "שבת",   :popularity => 0 },  // matches ש
        { :id => "c", :title => "תורה",  :popularity => 0 },  // no match
        { :id => "d", :title => "אשת",   :popularity => 0 }   // substring contains ש (idx 1)
    ];
    var t = Search.totalMatches("ש", arts);
    logger.debug("totalMatches('ש', 4 mixed) = " + t);
    return t == 3;  // שלום, שבת, אשת
}

(:test)
function search_totalMatchesEmptyArticlesReturnsZero(logger as Logger) as Boolean {
    var t = Search.totalMatches("foo", []);
    logger.debug("totalMatches('foo', []) = " + t);
    return t == 0;
}

// --- M6.2: ASCII-punctuation normalization + body-content search ---

(:test)
function search_normalizeStripsAsciiDoubleQuote(logger as Logger) as Boolean {
    // " (ASCII 0x22) used for gershayim-style Hebrew acronyms (שב"ק, ש"ס).
    // _normalize must strip all occurrences so matching ignores them.
    var got = Search._normalize("שב\"ק");
    logger.debug("normalize('שב\"ק')='" + got + "' (want 'שבק')");
    return got.equals("שבק");
}

(:test)
function search_normalizeStripsAsciiSingleQuote(logger as Logger) as Boolean {
    // ' (ASCII 0x27) used for geresh-style abbreviation (ש'מ for שמואל).
    var got = Search._normalize("ש'מ");
    logger.debug("normalize(\"ש'מ\")='" + got + "' (want 'שמ')");
    return got.equals("שמ");
}

(:test)
function search_normalizeReplacesAsciiHyphenWithSpace(logger as Logger) as Boolean {
    // - (ASCII 0x2D) treated as space — compound terms (שיר-השירים) match
    // the same as their space-separated form.
    var got = Search._normalize("שיר-השירים");
    logger.debug("normalize('שיר-השירים')='" + got + "' (want 'שיר השירים')");
    return got.equals("שיר השירים");
}

(:test)
function search_normalizeAllThreeChars(logger as Logger) as Boolean {
    // Mixed input with " + ' + - : strip the quotes, hyphen becomes space.
    // ש"י-עגנון → שי עגנון.
    var got = Search._normalize("ש\"י-עגנון");
    logger.debug("normalize('ש\"י-עגנון')='" + got + "' (want 'שי עגנון')");
    return got.equals("שי עגנון");
}

(:test)
function search_normalizeEmptyReturnsEmpty(logger as Logger) as Boolean {
    var got = Search._normalize("");
    logger.debug("normalize('')='" + got + "'");
    return got.equals("");
}

(:test)
function search_normalizeIdempotent(logger as Logger) as Boolean {
    // _normalize(_normalize(s)) == _normalize(s) for any input.
    var src = "ש\"י-עגנון";
    var once = Search._normalize(src);
    var twice = Search._normalize(once);
    logger.debug("once='" + once + "' twice='" + twice + "'");
    return once.equals(twice);
}

(:test)
function search_rankMatchesTitleIgnoringQuotes(logger as Logger) as Boolean {
    // Query "שבק" must match title שב"ק (gershayim stripped during ranking).
    var arts = [
        { :id => "sbk", :title => "שב\"ק", :popularity => 50 }
    ];
    var r = Search.rank("שבק", arts);
    logger.debug("rank('שבק', שב\"ק) size=" + r.size());
    return r.size() == 1 && ((r[0] as Dictionary)[:id] as String).equals("sbk");
}

(:test)
function search_rankMatchesHyphenAsSpace(logger as Logger) as Boolean {
    // Query "שיר השירים" matches title "שיר-השירים-המלא" because
    // both sides normalize hyphens to spaces.
    var arts = [
        { :id => "shsh", :title => "שיר-השירים-המלא", :popularity => 50 }
    ];
    var r = Search.rank("שיר השירים", arts);
    logger.debug("rank('שיר השירים', שיר-השירים-המלא) size=" + r.size());
    return r.size() == 1 && ((r[0] as Dictionary)[:id] as String).equals("shsh");
}

(:test)
function search_rankPreservesDisplayedTitleWithPunctuation(logger as Logger) as Boolean {
    // After ranking, the returned dict's :title is the ORIGINAL string
    // (with the gershayim / geresh / hyphen still intact) — normalization
    // is for matching only, never mutates the data.
    var arts = [
        { :id => "sbk", :title => "שב\"ק", :popularity => 50 }
    ];
    var r = Search.rank("שבק", arts);
    if (r.size() != 1) { return false; }
    var got = (r[0] as Dictionary)[:title] as String;
    logger.debug("preserved-title='" + got + "'");
    return got.equals("שב\"ק");
}

(:test)
function search_rankMatchesBodyWhenTitleDoesnt(logger as Logger) as Boolean {
    // Article with :body containing the query but :title that doesn't —
    // M6.2 adds body-fallback as tier 3.
    var arts = [
        { :id => "doc1", :title => "שלום", :popularity => 50,
          :body => "מאמר זה דן בעניין אברהם אבינו ובהמשך גם בשרה." }
    ];
    var r = Search.rank("אברהם", arts);
    logger.debug("rank('אברהם', body-only) size=" + r.size());
    return r.size() == 1 && ((r[0] as Dictionary)[:id] as String).equals("doc1");
}

(:test)
function search_rankTitleMatchesBeforeBodyMatches(logger as Logger) as Boolean {
    // Title-matched articles must come BEFORE body-only matched articles
    // regardless of popularity. body-only article has higher popularity
    // (100) than the title-match article (10); title-match still wins.
    var arts = [
        { :id => "title-hit", :title => "אברהם",
          :popularity => 10,  :body => "no relevant body" },
        { :id => "body-hit",  :title => "שלום",
          :popularity => 100, :body => "אברהם הופיע בפסוק זה." }
    ];
    var r = Search.rank("אברהם", arts);
    logger.debug("rank size=" + r.size() + " ids=" + _searchIdsOf(r));
    return r.size() == 2
        && ((r[0] as Dictionary)[:id] as String).equals("title-hit")
        && ((r[1] as Dictionary)[:id] as String).equals("body-hit");
}

(:test)
function search_totalMatchesIncludesBodyHits(logger as Logger) as Boolean {
    // M6.2: totalMatches counts title-or-body matches (not just title).
    var arts = [
        { :id => "a", :title => "שלום", :popularity => 0,
          :body => "אברהם הופיע בפסוק" },
        { :id => "b", :title => "אברהם", :popularity => 0,
          :body => "no match here either" },
        { :id => "c", :title => "תורה", :popularity => 0,
          :body => "no relevant content" }
    ];
    var t = Search.totalMatches("אברהם", arts);
    logger.debug("totalMatches('אברהם', mixed) = " + t + " (want 2)");
    return t == 2;
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
