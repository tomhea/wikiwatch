import Toybox.Lang;

// M5.1 pure geometry for ResultsView's tap-to-open hit-test. Maps a
// screen (y, scrollY) to a row index, accounting for fixed row height
// + total row count. Used by ResultsView.rowAt(x, y) to dispatch taps
// to the right article.
module ResultsLayout {
    // M5.2: footer string for ResultsView when more matches exist beyond
    // what's currently rendered. Returns:
    //   null   - if total <= displayed (no overflow; no footer needed)
    //   "1 more article fits" - singular form
    //   "N more articles fit"  - plural form
    function moreArticlesText(total as Number, displayed as Number) as String? {
        var diff = total - displayed;
        if (diff <= 0) { return null; }
        if (diff == 1) { return "1 more article fits"; }
        return diff + " more articles fit";
    }

    // M5.3: variable-height row hit-test. Given an array of `block` dicts
    // (each with :top => contentY-offset, :height => block height) sorted
    // by :top, return the index of the block whose y range contains
    // contentY, or null if contentY falls in a gap, past the end, or
    // before the start.
    //
    // Used by ResultsView.rowAt to dispatch a tap on ANY of an article's
    // wrapped sub-lines back to the article (block-level dispatch).
    function blockAt(contentY as Number, blocks as Array<Dictionary>) as Number? {
        if (contentY < 0) { return null; }
        var n = blocks.size();
        for (var i = 0; i < n; i++) {
            var b = blocks[i] as Dictionary;
            var top = b[:top] as Number;
            var bottom = top + (b[:height] as Number);
            if (contentY >= top && contentY < bottom) { return i; }
        }
        return null;
    }

    function rowIndexAt(y as Number, scrollY as Number, rowHeight as Number, rowCount as Number) as Number? {
        if (rowHeight <= 0 || rowCount <= 0) { return null; }
        var contentY = y + scrollY;
        if (contentY < 0) { return null; }
        var idx = contentY / rowHeight;
        if (idx >= rowCount) { return null; }
        return idx;
    }
}
