import Toybox.Lang;

// M10.2 pure helpers for wikiwatchView's STREAMING-decode layout. Companion to
// LayoutProgress: where LayoutProgress drives the lazy layout of an already-known
// raw-line array, StreamProgress drives the two new streaming decisions —
//   1. when to pump more decode (top up the GROWING _rawLines), and
//   2. when the first paint has filled ~2 screens (height target, watchdog-capped).
//
// Pure — only imports Toybox.Lang. Kept separate from LayoutProgress so M5.2's
// tested contract stays untouched.
module StreamProgress {
    // True while the layout cursor is within `lookahead` raw lines of the decoded
    // tail — i.e. we should decode more so layout never starves. `decodedCount` is
    // _rawLines.size() (grows as decode emits lines); `cursor` is _layoutCursor.
    function needMoreRawLines(cursor as Number, decodedCount as Number, lookahead as Number) as Boolean {
        return (decodedCount - cursor) < lookahead;
    }

    // True while the first paint should keep laying out one more raw line: stop
    // once ~2 screens of content height are filled OR the per-tick sub-line budget
    // is reached (the budget caps a single dense paragraph so one handler can't
    // exceed the watchdog; the next tick continues toward 2 screens).
    function firstPaintShouldContinue(layoutY as Number, screenHeight as Number,
                                      subLineCount as Number, budget as Number) as Boolean {
        return (layoutY < 2 * screenHeight) && (subLineCount < budget);
    }
}
