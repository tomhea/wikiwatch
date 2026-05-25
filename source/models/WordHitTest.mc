import Toybox.Lang;

// M6 long-press word hit-test. Pure module — only Toybox.Lang.
//
// Used by wikiwatchView.findWordAt() → wikiwatchDelegate.onHold to map
// a long-press in the article reader to the word under the finger, which
// is then pre-filled into a new keyboard layer.
//
// Hebrew RTL note: CIQ's BiDi renderer puts the first LOGICAL character
// at the visual right edge for right-anchored text. The math here treats
// the text as right-anchored at lineRightX (visual right edge) and the
// char_index 0 == first logical char == visually rightmost. Walking
// `words` in logical order produces the correct visual mapping under
// BiDi.
//
// Each word "owns" its trailing space — a tap that lands on whitespace
// snaps to the preceding word. This matches the natural "I just read this
// word, then tapped just past it" interaction.
module WordHitTest {
    function findWordInLine(
        contentX as Number,
        text as String,
        lineRightX as Number,
        charPx as Number
    ) as String? {
        if (text.length() == 0) { return null; }
        if (contentX > lineRightX) { return null; }
        if (charPx <= 0) { return null; }
        var charIndex = (lineRightX - contentX) / charPx;
        if (charIndex < 0) { return null; }
        var totalChars = text.length();
        if (charIndex >= totalChars) { return null; }
        var words = LineWrap.splitWords(text);
        var n = words.size();
        if (n == 0) { return null; }
        var charsSoFar = 0;
        for (var i = 0; i < n; i++) {
            var word = words[i] as String;
            var endExclusive = charsSoFar + word.length();
            if (i < n - 1) {
                endExclusive = endExclusive + 1;   // +1 for the trailing space
            }
            if (charIndex < endExclusive) { return word; }
            charsSoFar = endExclusive;
        }
        return null;
    }
}
