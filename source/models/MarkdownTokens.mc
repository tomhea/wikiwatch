import Toybox.Lang;

// Parse a single line into {level, text}. level 0 = body, 1..4 = header.
// 5+ hashes or a hash sequence without a following space/EOL = body (level 0).
// Pure module: imports only Toybox.Lang.
module MarkdownTokens {
    function parse(line as String) as Dictionary {
        var n = 0;
        var i = 0;
        var len = line.length();
        while (i < len && line.substring(i, i + 1).equals("#")) {
            n++;
            i++;
        }
        var headerEnds = (i == len) || line.substring(i, i + 1).equals(" ");
        if (n >= 1 && n <= 4 && headerEnds) {
            var text = (i == len) ? "" : line.substring(i + 1, len);
            return { :level => n, :text => text };
        }
        return { :level => 0, :text => line };
    }
}