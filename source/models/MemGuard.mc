import Toybox.Lang;

// M9.6: free-memory gate that refuses to push a new view (open an article, or a
// long-press keyboard layer) when free heap is low.
//
// Every push allocates — the article reader builds a laid-out line list; a
// long-press keyboard builds/holds the shared index. Deep nesting (article ->
// long-press -> keyboard -> article -> ...) keeps stacking those allocations,
// and Monkey C OOM is UNCATCHABLE: crossing the limit silently kills the app.
// There is no after-the-fact defense, so we refuse the push BEFORE it allocates
// once free heap drops under the threshold, and show a yellow notice instead.
//
// Pure (only Lang) so the threshold is unit-testable; callers pass live
// System.getSystemStats().freeMemory.
module MemGuard {
    // Below this many free heap bytes, block opening a new view. 150 KB leaves
    // headroom for one reader/keyboard push (~tens of KB of layout/index state)
    // plus GC slack before the uncatchable ceiling.
    const MIN_FREE_BYTES = 150 * 1024;   // 153600

    // True if there is enough free heap to open a new view.
    function canOpen(freeBytes as Number) as Boolean {
        return freeBytes >= MIN_FREE_BYTES;
    }
}
