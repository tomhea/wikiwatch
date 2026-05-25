import Toybox.Lang;

// M5.2 pure state-machine helpers for wikiwatchView's lazy article layout.
//
// Lazy layout pattern: the article view lays out a small batch of raw
// lines per onUpdate(dc) — keeping the first paint nearly instant —
// then schedules a Timer that wakes the view to lay out more batches
// in the background. These helpers encode the cursor advance, the
// completion test, the "is the user about to scroll past the end?"
// predicate, and the scroll clamp that stays stable as the content
// height grows during incremental layout.
//
// Pure — only imports Toybox.Lang.
module LayoutProgress {
    function nextBatchEnd(cursor as Number, totalLines as Number, batchSize as Number) as Number {
        var end = cursor + batchSize;
        if (end > totalLines) { end = totalLines; }
        return end;
    }

    function isComplete(cursor as Number, totalLines as Number) as Boolean {
        return cursor >= totalLines;
    }

    function isScrollNearEnd(scrollY as Number, contentHeight as Number, screenHeight as Number, lookahead as Number) as Boolean {
        var bottom = scrollY + screenHeight;
        var gap = contentHeight - bottom;
        return gap < lookahead;
    }

    function clampedScroll(scrollY as Number, contentHeight as Number, screenHeight as Number) as Number {
        var maxScroll = contentHeight - screenHeight;
        if (maxScroll < 0) { maxScroll = 0; }
        if (scrollY < 0) { return 0; }
        if (scrollY > maxScroll) { return maxScroll; }
        return scrollY;
    }
}
