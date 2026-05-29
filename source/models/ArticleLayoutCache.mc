import Toybox.Lang;

// M8.3 single-entry cache of a fully laid-out article. The article reader
// (wikiwatchView) computes pixel-wrapped sub-lines incrementally — expensive
// for long articles. Caching the LAST-opened article's laid-out lines makes
// re-opening it instant (no re-wrap, no lazy-load ticks).
//
// Single entry only: re-opening the same article hits; opening a different one
// evicts the previous (the common pattern is open → back → re-open the same).
// Pure module-level state (no Storage/WatchUi/System) — R6-clean, like the
// M6.5 KeyboardLayout caches.
module ArticleLayoutCache {
    var _key as String? = null;
    var _lines as Array? = null;
    var _contentHeight as Number = 0;

    // Cached payload for `key`, or null on miss. Shape:
    //   { :lines => Array<Dictionary>, :contentHeight => Number }
    function get(key as String) as Dictionary? {
        if (_key != null && _lines != null && (_key as String).equals(key)) {
            return { :lines => _lines, :contentHeight => _contentHeight };
        }
        return null;
    }

    // Store the laid-out lines + total content height under `key` (evicts any
    // previous entry — single slot).
    function put(key as String, lines as Array, contentHeight as Number) as Void {
        _key = key;
        _lines = lines;
        _contentHeight = contentHeight;
    }

    function clear() as Void {
        _key = null;
        _lines = null;
        _contentHeight = 0;
    }
}
