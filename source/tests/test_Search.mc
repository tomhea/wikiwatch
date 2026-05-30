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

// M6.3: body-search was pulled out of Search.rank / Search.totalMatches
// because the M6.2 implementation triggered uncatchable OOM in the
// simulator (and would do the same on-watch). Root cause: per-keystroke
// rank+totalMatches both ran _normalize() on every article body that
// missed by title, and the original _normalize used O(N²) string concat
// (out = out + char in a loop). On the ~2 KB shalom sampleArticle that
// works out to ~4 million byte-allocations per pass, ~8 million per
// keystroke. Combined with the M6.2 pre-load (KeyboardDelegate held all
// ~5 KB of bodies resident), the article-reader push then blew the
// heap. M6.3 reverts Search to title-only matching but KEEPS the M6.2
// ASCII normalization (it's safe + small on the per-article-title
// inputs). The three deleted tests asserted the body-search behavior:
// they are intentionally GONE in M6.3 — a future milestone that wants
// body search will need a different architecture (lazy per-keystroke
// loads via ArticleStore, OR a precomputed index, OR something else
// that doesn't keep every body in heap at once).

(:test)
function search_rankIgnoresBodyKey(logger as Logger) as Boolean {
    // M6.3 regression: even when :body contains the query, Search.rank
    // must NOT match on it. (M6.2 did; doing so caused OOM crashes.)
    var arts = [
        { :id => "doc1", :title => "שלום", :popularity => 50,
          :body => "מאמר זה דן בעניין אברהם אבינו." }
    ];
    var r = Search.rank("אברהם", arts);
    logger.debug("rank('אברהם', body-only article) size=" + r.size() + " (want 0)");
    return r.size() == 0;
}

(:test)
function search_totalMatchesIgnoresBodyKey(logger as Logger) as Boolean {
    // M6.3 regression: totalMatches counts TITLE matches only.
    var arts = [
        { :id => "a", :title => "שלום", :popularity => 0, :body => "אברהם" },
        { :id => "b", :title => "אברהם", :popularity => 0, :body => "no match" },
        { :id => "c", :title => "תורה", :popularity => 0, :body => "no match" }
    ];
    var t = Search.totalMatches("אברהם", arts);
    logger.debug("totalMatches('אברהם', mixed with :body) = " + t + " (want 1)");
    return t == 1;
}

(:test)
function search_normalizeFastPathReturnsIdenticalString(logger as Logger) as Boolean {
    // M6.3 regression: when input contains no " / ' / -, _normalize must
    // return the SAME string object (no allocation). Strings.equals checks
    // value equality but the real proof of the fast-path is that no
    // O(N²) concat fires — covered by the runtime no-crash test on the
    // ~2 KB shalom body in R2 evidence.
    var s = "שלום עליכם";
    var n = Search._normalize(s);
    logger.debug("normalize('שלום עליכם')='" + n + "' equals=" + s.equals(n));
    return s.equals(n);
}

// --- M9 perf: merge sort + tier1-fills-TOP_K short-circuit ---

(:test)
function search_mergeSortLargeTierSortedDesc(logger as Logger) as Boolean {
    // 120 prefix-matching articles -> capped at TOP_K=50, popularity DESC.
    var arts = [] as Array<Dictionary>;
    for (var i = 0; i < 120; i++) {
        arts.add({ :id => i.toString(), :title => "ש" + i.toString(), :popularity => (i % 40) });
    }
    var r = Search.rank("ש", arts);
    if (r.size() != 50) { logger.debug("size=" + r.size()); return false; }
    var prevPop = 999;
    for (var i = 0; i < r.size(); i++) {
        var p = (r[i] as Dictionary)[:popularity] as Number;
        if (p > prevPop) { logger.debug("not desc at " + i); return false; }
        prevPop = p;
    }
    return true;
}

(:test)
function search_tier1FillsTopKSkipsTier2(logger as Logger) as Boolean {
    // 60 prefix (tier1) + 60 substring-only (tier2, higher popularity). With
    // tier1 >= 50, result is 50 articles ALL from tier1 — prefix outranks substring.
    var arts = [] as Array<Dictionary>;
    for (var i = 0; i < 60; i++) {
        arts.add({ :id => "p" + i.toString(), :title => "מ" + i.toString(), :popularity => 100 - i });
    }
    for (var i = 0; i < 60; i++) {
        arts.add({ :id => "s" + i.toString(), :title => "אמ" + i.toString(), :popularity => 200 });
    }
    var r = Search.rank("מ", arts);
    if (r.size() != 50) { return false; }
    for (var i = 0; i < r.size(); i++) {
        var id = (r[i] as Dictionary)[:id] as String;
        if (id.substring(0, 1).equals("s")) { logger.debug("tier2 leaked: " + id); return false; }
    }
    return true;
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
