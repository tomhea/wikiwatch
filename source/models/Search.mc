import Toybox.Lang;

// M5 ranking for the live-search keyboard. Pure module — only imports
// Toybox.Lang. Used by wikiwatchKeyboardDelegate on every buffer change.
//
// Ranking contract:
//   Empty query: top-K (=20) by :popularity DESC, stable tiebreak by :title.
//   Non-empty query:
//     tier 1 = titles where title.find(query) == 0   (prefix match)
//     tier 2 = titles where title.find(query) != null && != 0
//                                                     (substring, not prefix)
//     each tier sorted by :popularity DESC, stable tiebreak by :title
//     result = [tier1..., tier2...] capped at TOP_K.
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

    function rank(query as String, articles as Array<Dictionary>) as Array<Dictionary> {
        var n = articles.size();
        if (n == 0) { return []; }

        if (query.length() == 0) {
            var sorted = _copyArray(articles);
            _sortByPopularityThenTitle(sorted);
            return _take(sorted, TOP_K);
        }

        var tier1 = [];
        var tier2 = [];
        for (var i = 0; i < n; i++) {
            var a = articles[i] as Dictionary;
            var title = a[:title] as String;
            var idx = title.find(query);
            if (idx == null) { continue; }
            if (idx == 0) {
                tier1.add(a);
            } else {
                tier2.add(a);
            }
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
}
