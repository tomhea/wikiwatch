import Toybox.Lang;

// Wrap text into lines of at most `maxChars` code points each, splitting at
// whitespace. A single word longer than maxChars overflows on its own line
// (don't break mid-word). Multiple consecutive spaces collapse. Pure module.
module LineWrap {
    function wrap(text as String, maxChars as Number) as Array<String> {
        if (text.equals("") || maxChars <= 0) {
            return [""];
        }
        var lines = [];
        var line = "";
        var word = "";
        for (var i = 0; i <= text.length(); i++) {
            var ch = (i < text.length()) ? text.substring(i, i + 1) : null;
            if (ch == null || ch.equals(" ")) {
                if (!word.equals("")) {
                    var sepLen = line.equals("") ? 0 : 1;
                    if (line.length() + sepLen + word.length() <= maxChars) {
                        line = line.equals("") ? word : (line + " " + word);
                    } else {
                        if (!line.equals("")) {
                            lines.add(line);
                        }
                        line = word;
                    }
                    word = "";
                }
            } else {
                word = word + ch;
            }
        }
        if (!line.equals("")) {
            lines.add(line);
        }
        if (lines.size() == 0) {
            lines.add("");
        }
        return lines;
    }

    function wrapToWidths(text as String, charWidth as Number, widths as Array<Number>, startIndex as Number) as Array<String> {
        if (text.equals("") || widths.size() == 0 || charWidth <= 0) {
            return [""];
        }
        var defaultWidth = widths[widths.size() - 1];
        var chars = text.toCharArray();
        var len = chars.size();
        var lines = [];
        var line = "";
        var wordStart = 0;
        for (var i = 0; i <= len; i++) {
            var atBoundary = (i == len) || chars[i] == ' ';
            if (atBoundary) {
                if (i > wordStart) {
                    var word = text.substring(wordStart, i);
                    var k = startIndex + lines.size();
                    var widthPx = (k < widths.size()) ? widths[k] : defaultWidth;
                    var maxChars = widthPx / charWidth;
                    if (maxChars < 1) { maxChars = 1; }
                    var sepLen = line.equals("") ? 0 : 1;
                    if (line.length() + sepLen + word.length() <= maxChars) {
                        line = line.equals("") ? word : (line + " " + word);
                    } else {
                        if (!line.equals("")) {
                            lines.add(line);
                        }
                        line = word;
                    }
                }
                wordStart = i + 1;
            }
        }
        if (!line.equals("")) {
            lines.add(line);
        }
        if (lines.size() == 0) {
            lines.add("");
        }
        return lines;
    }

    // M2.4: wrap a text where the ABSOLUTE LAST sub-line uses edgeWidth, the
    // PENULTIMATE uses secondWidth, and everything before uses middleWidth.
    // Algorithm: reverse-pack the last sub-line at edgeWidth (greedy from the
    // text's end), then reverse-pack the penultimate at secondWidth, then
    // forward-pack the remainder at middleWidth. Pure module.
    //
    // Single oversized words (longer than the target width) still emit on
    // their own line - never break inside a word.
    function wrapWithNarrowTail(text as String, charWidth as Number, middleWidth as Number, secondWidth as Number, edgeWidth as Number) as Array<String> {
        if (text.equals("") || charWidth <= 0) {
            return [""];
        }
        var maxLast = edgeWidth / charWidth;
        var maxSecond = secondWidth / charWidth;
        var maxMiddle = middleWidth / charWidth;
        if (maxLast < 1) { maxLast = 1; }
        if (maxSecond < 1) { maxSecond = 1; }
        if (maxMiddle < 1) { maxMiddle = 1; }

        var words = [];
        var chars = text.toCharArray();
        var len = chars.size();
        var wordStart = 0;
        for (var i = 0; i <= len; i++) {
            if (i == len || chars[i] == ' ') {
                if (i > wordStart) {
                    words.add(text.substring(wordStart, i));
                }
                wordStart = i + 1;
            }
        }

        if (words.size() == 0) {
            return [""];
        }

        // Reverse-pack the LAST sub-line at edgeWidth.
        var lastSub = "";
        var idx = words.size() - 1;
        while (idx >= 0) {
            var w = words[idx] as String;
            var newLen = lastSub.length() + (lastSub.equals("") ? 0 : 1) + w.length();
            if (newLen > maxLast && !lastSub.equals("")) {
                break;
            }
            lastSub = lastSub.equals("") ? w : (w + " " + lastSub);
            idx--;
        }

        // Reverse-pack the PENULTIMATE sub-line at secondWidth.
        var penultimate = "";
        while (idx >= 0) {
            var w = words[idx] as String;
            var newLen = penultimate.length() + (penultimate.equals("") ? 0 : 1) + w.length();
            if (newLen > maxSecond && !penultimate.equals("")) {
                break;
            }
            penultimate = penultimate.equals("") ? w : (w + " " + penultimate);
            idx--;
        }

        // Forward-pack the REMAINDER at middleWidth.
        var middleLines = [];
        var line = "";
        for (var j = 0; j <= idx; j++) {
            var w = words[j] as String;
            var sepLen = line.equals("") ? 0 : 1;
            if (line.length() + sepLen + w.length() <= maxMiddle) {
                line = line.equals("") ? w : (line + " " + w);
            } else {
                if (!line.equals("")) {
                    middleLines.add(line);
                }
                line = w;
            }
        }
        if (!line.equals("")) {
            middleLines.add(line);
        }

        var result = [];
        for (var j = 0; j < middleLines.size(); j++) {
            result.add(middleLines[j]);
        }
        if (!penultimate.equals("")) {
            result.add(penultimate);
        }
        if (!lastSub.equals("")) {
            result.add(lastSub);
        }
        if (result.size() == 0) {
            result.add("");
        }
        return result;
    }

    // M2.8 (option B): pixel-accurate wrap helpers. Caller measures each word's
    // pixel width with dc.getTextWidthInPixels(word, font) and the space width
    // once; pure module then packs words by px arithmetic. Avoids the per-line
    // variance that the char-count estimate misses (some lines could fit one
    // more word but get rejected by the char-count check).

    // Split text into words at spaces, collapsing multiple/leading/trailing
    // spaces. Empty input returns [].
    function splitWords(text as String) as Array<String> {
        var words = [];
        if (text.equals("")) { return words; }
        var chars = text.toCharArray();
        var len = chars.size();
        var wordStart = -1;
        for (var i = 0; i < len; i++) {
            if (chars[i] == ' ') {
                if (wordStart >= 0) {
                    words.add(text.substring(wordStart, i));
                    wordStart = -1;
                }
            } else {
                if (wordStart < 0) { wordStart = i; }
            }
        }
        if (wordStart >= 0) {
            words.add(text.substring(wordStart, len));
        }
        return words;
    }

    // Forward-pack words into lines such that line k's total width
    // (sum of wordPx for words in line k + spacePx between adjacent words)
    // <= widthsPx[startIndex + k]. Beyond the array, falls back to
    // widthsPx[size - 1]. A single word wider than its budget overflows
    // alone (never break inside a word).
    function wrapPxToWidths(words as Array<String>, wordPx as Array<Number>, spacePx as Number, widthsPx as Array<Number>, startIndex as Number) as Array<String> {
        if (words.size() == 0 || widthsPx.size() == 0) {
            return [""];
        }
        var defaultWidth = widthsPx[widthsPx.size() - 1];
        var lines = [];
        var line = "";
        var lineW = 0;
        for (var i = 0; i < words.size(); i++) {
            var word = words[i] as String;
            var wpx = wordPx[i] as Number;
            var k = startIndex + lines.size();
            var maxPx = (k < widthsPx.size()) ? widthsPx[k] : defaultWidth;
            var sepW = line.equals("") ? 0 : spacePx;
            if (lineW + sepW + wpx <= maxPx) {
                line = line.equals("") ? word : (line + " " + word);
                lineW = lineW + sepW + wpx;
            } else {
                if (!line.equals("")) {
                    lines.add(line);
                }
                line = word;
                lineW = wpx;
            }
        }
        if (!line.equals("")) {
            lines.add(line);
        }
        if (lines.size() == 0) {
            lines.add("");
        }
        return lines;
    }

    // Reverse-pack the ABSOLUTE LAST sub-line at edgePx, then the PENULTIMATE
    // at secondPx, then forward-pack the remainder at middlePx. Pixel-precise
    // sibling of wrapWithNarrowTail.
    function wrapPxWithNarrowTail(words as Array<String>, wordPx as Array<Number>, spacePx as Number, middlePx as Number, secondPx as Number, edgePx as Number) as Array<String> {
        if (words.size() == 0) {
            return [""];
        }
        var n = words.size();

        // Reverse-pack last sub-line at edgePx.
        var lastSub = "";
        var lastSubW = 0;
        var idx = n - 1;
        while (idx >= 0) {
            var w = words[idx] as String;
            var wpx = wordPx[idx] as Number;
            var sepW = lastSub.equals("") ? 0 : spacePx;
            if (lastSubW + sepW + wpx > edgePx && !lastSub.equals("")) {
                break;
            }
            lastSub = lastSub.equals("") ? w : (w + " " + lastSub);
            lastSubW = lastSubW + sepW + wpx;
            idx--;
        }

        // Reverse-pack penultimate at secondPx.
        var penult = "";
        var penultW = 0;
        while (idx >= 0) {
            var w = words[idx] as String;
            var wpx = wordPx[idx] as Number;
            var sepW = penult.equals("") ? 0 : spacePx;
            if (penultW + sepW + wpx > secondPx && !penult.equals("")) {
                break;
            }
            penult = penult.equals("") ? w : (w + " " + penult);
            penultW = penultW + sepW + wpx;
            idx--;
        }

        // Forward-pack remainder [0..idx] at middlePx.
        var middleLines = [];
        var line = "";
        var lineW = 0;
        for (var j = 0; j <= idx; j++) {
            var w = words[j] as String;
            var wpx = wordPx[j] as Number;
            var sepW = line.equals("") ? 0 : spacePx;
            if (lineW + sepW + wpx > middlePx && !line.equals("")) {
                middleLines.add(line);
                line = w;
                lineW = wpx;
            } else {
                line = line.equals("") ? w : (line + " " + w);
                lineW = lineW + sepW + wpx;
            }
        }
        if (!line.equals("")) {
            middleLines.add(line);
        }

        var result = [];
        for (var j = 0; j < middleLines.size(); j++) {
            result.add(middleLines[j]);
        }
        if (!penult.equals("")) {
            result.add(penult);
        }
        if (!lastSub.equals("")) {
            result.add(lastSub);
        }
        if (result.size() == 0) {
            result.add("");
        }
        return result;
    }
}