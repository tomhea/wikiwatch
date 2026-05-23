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
}