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

    // Wrap `text` where the k-th output sub-line uses pixel budget
    // widths[startIndex + k]; beyond the array's end, use the last entry.
    // Optimized: pre-computes char array to avoid per-character substring()
    // allocation in the hot loop. The earlier per-char `text.substring(i, i+1)`
    // approach tripped the simulator watchdog on the long article.
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
}