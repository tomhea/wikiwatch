import Toybox.Lang;

// M5 ranking for the live-search keyboard. Pure module — only imports
// Toybox.Lang. Used by wikiwatchKeyboardDelegate on every buffer change.
//
// Ranking contract (M6.3 — body-search REMOVED):
//   Empty query: top-K (=50) by :popularity DESC, stable tiebreak by :title.
//   Non-empty query, with normalization on both sides (see _normalize):
//     tier 1 = titles where normTitle.find(normQuery) == 0   (title prefix)
//     tier 2 = titles where normTitle.find(normQuery) != null && != 0
//                                                              (title substring)
//     each tier sorted by :popularity DESC, stable tiebreak by :title.
//     result = [tier1..., tier2...] capped at TOP_K.
//
// M6.2 had a tier 3 (body fallback) that combined with a per-keystroke
// re-normalization of every body to cause uncatchable OOM. Specifically,
// the M6.2 _normalize walked the char array building output via
// `out = out + ch`, which is O(N²) byte-allocations on Monkey C strings
// (each + allocates a fresh String). On the ~2 KB shalom sampleArticle
// that produced ~4 million allocations per pass; running it twice per
// keystroke (rank + totalMatches) over a corpus that mostly missed by
// title pushed the heap past the Venu 2 limit. M6.3 reverts to
// title-only matching. Body search will return in a later milestone
// with a different architecture (per-keystroke lazy ArticleStore reads
// OR a precomputed index OR similar — anything that doesn't keep every
// body resident AND doesn't re-walk every body per keystroke).
//
// Normalization (M6.2, kept in M6.3):
//   ASCII " and ' are stripped (matching ignores them).
//   ASCII - is converted to space (matches treat hyphenated words like
//   space-separated words). Decision: keyboard input + corpus titles
//   both use ASCII forms (not Hebrew U+05F4/U+05F3/U+05BE).
//   M6.3 added a fast-path: when input contains no " / ' / -, return
//   the original string without allocation. Means the title-side normalize
//   in the hot path is free for the common case (most titles don't have
//   punctuation).
//
// Hebrew strings work because Monkey C String.find/length operate on
// codepoints (proved by M1 storage round-trip + M3 InputBuffer tests).
//
// Complexity: O(N) partition + O(K^2) insertion sort where K is the size
// of each tier. Fine for the M4 fixture corpus (N=3) and the M7 corpus
// up to a few thousand articles. If M7 grows to tens of thousands and
// per-keystroke rank lags, a per-prefix index can be added in M5.x.
module Search {
    // M5.2: bumped 20 -> 50 to fit the 30-fixture corpus without losing
    // any articles to the cap. The cap still exists as a safety net for
    // future huge corpora (M7+); ResultsView paginates whatever fits.
    const TOP_K = 50;

    // M5.2: count of articles that match `query` BEFORE the TOP_K cap.
    // Empty query matches every article (consistent with rank's empty-query
    // branch returning top-K of the whole corpus). Used by KeyboardDelegate
    // to give ResultsView the un-capped match total, so the
    // "X more articles fit" footer can be rendered when total > displayed.
    function totalMatches(query as String, articles as Array<Dictionary>) as Number {
        var n = articles.size();
        if (query.length() == 0) { return n; }
        var normQuery = _normalize(query);
        var count = 0;
        for (var i = 0; i < n; i++) {
            var a = articles[i] as Dictionary;
            var normTitle = _normalize(a[:title] as String);
            if (normTitle.find(normQuery) != null) {
                count++;
            }
        }
        return count;
    }

    function rank(query as String, articles as Array<Dictionary>) as Array<Dictionary> {
        var n = articles.size();
        if (n == 0) { return []; }

        if (query.length() == 0) {
            var sorted = _copyArray(articles);
            _sortByPopularityThenTitle(sorted);
            return _take(sorted, TOP_K);
        }

        var normQuery = _normalize(query);
        var tier1 = [];
        var tier2 = [];
        for (var i = 0; i < n; i++) {
            var a = articles[i] as Dictionary;
            var normTitle = _normalize(a[:title] as String);
            var titleIdx = normTitle.find(normQuery);
            if (titleIdx == 0) {
                tier1.add(a);
            } else if (titleIdx != null) {
                tier2.add(a);
            }
            // No tier 3 — see module doc for why M6.2's body fallback was
            // removed in M6.3.
        }
        _sortByPopularityThenTitle(tier1);
        _sortByPopularityThenTitle(tier2);

        var combined = [];
        for (var i = 0; i < tier1.size(); i++) { combined.add(tier1[i]); }
        for (var i = 0; i < tier2.size(); i++) { combined.add(tier2[i]); }
        return _take(combined, TOP_K);
    }

    function _take(arr as Array, n as Number) as Array {
        if (arr.size() <= n) { return arr; }
        var result = [];
        for (var i = 0; i < n; i++) { result.add(arr[i]); }
        return result;
    }

    function _copyArray(arr as Array) as Array {
        var c = [];
        for (var i = 0; i < arr.size(); i++) { c.add(arr[i]); }
        return c;
    }

    // Stable insertion sort by :popularity DESC, tiebreak :title ASC
    // (codepoint order). N is small (<= TOP_K most of the time), so O(N^2)
    // is fine and stability matters for the tiebreak guarantee.
    function _sortByPopularityThenTitle(arr as Array) as Void {
        var n = arr.size();
        for (var i = 1; i < n; i++) {
            var current = arr[i] as Dictionary;
            var j = i - 1;
            while (j >= 0 && _compare(arr[j] as Dictionary, current) > 0) {
                arr[j + 1] = arr[j];
                j--;
            }
            arr[j + 1] = current;
        }
    }

    // < 0 iff a should come BEFORE b. Higher popularity first; on ties,
    // lower codepoint title first.
    function _compare(a as Dictionary, b as Dictionary) as Number {
        var pa = a[:popularity] as Number;
        var pb = b[:popularity] as Number;
        if (pa != pb) { return pb - pa; }
        return _compareStrings(a[:title] as String, b[:title] as String);
    }

    function _compareStrings(a as String, b as String) as Number {
        var ca = a.toCharArray();
        var cb = b.toCharArray();
        var la = ca.size();
        var lb = cb.size();
        var minLen = (la < lb) ? la : lb;
        for (var i = 0; i < minLen; i++) {
            var x = (ca[i] as Char).toNumber();
            var y = (cb[i] as Char).toNumber();
            if (x != y) { return x - y; }
        }
        return la - lb;
    }

    // M6.2: normalize for matching. ASCII " (0x22) and ' (0x27) are stripped
    // (Hebrew acronyms like שב"ק / ש'מ become שבק / שמ for matching). ASCII
    // - (0x2D) becomes a space so hyphenated compounds (שיר-השירים) match the
    // same as their space-separated form. Pure — only walks the char array.
    //
    // M6.3 fast-path: when the input contains none of " / ' / -, return the
    // input string with no allocation. The slow path's `out = out + ch`
    // construction is O(N²) byte-allocations in Monkey C (each + makes a
    // fresh String), so on a long input it can blow the heap. Most titles
    // and queries have no punctuation; the fast-path means the hot path
    // pays nothing.
    function _normalize(s as String) as String {
        if (s.length() == 0) { return s; }
        if (s.find("\"") == null && s.find("'") == null && s.find("-") == null) {
            return s;
        }
        var chars = s.toCharArray();
        var n = chars.size();
        var out = "";
        for (var i = 0; i < n; i++) {
            var c = (chars[i] as Char).toNumber();
            if (c == 0x22 || c == 0x27) {
                continue;
            }
            if (c == 0x2D) {
                out = out + " ";
                continue;
            }
            out = out + (chars[i] as Char).toString();
        }
        return out;
    }
}
