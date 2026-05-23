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
}