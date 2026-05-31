import Toybox.Lang;

// M9.7: clean a long-pressed body word before it seeds the search buffer.
// Keeps only letters (Hebrew U+05D0-05EA incl. final forms, or ASCII A-Za-z),
// digits, and spaces; strips everything else (trailing punctuation, quotes,
// parens, maqaf/geresh, markdown, etc.) so the search bar gets a clean query.
//
// Pure (only Lang) -> unit-testable. The input is a single short word (a body
// token), so the per-char build is cheap.
module WordSanitize {
    function searchable(word as String) as String {
        var chars = word.toCharArray();
        var out = "";
        for (var i = 0; i < chars.size(); i++) {
            var c = (chars[i] as Char).toNumber();
            if (c == 0x20                       // space
                || (c >= 0x30 && c <= 0x39)     // 0-9
                || (c >= 0x41 && c <= 0x5A)     // A-Z
                || (c >= 0x61 && c <= 0x7A)     // a-z
                || (c >= 0x05D0 && c <= 0x05EA) // Hebrew letters (incl. finals)
            ) {
                out = out + (chars[i] as Char).toString();
            }
        }
        return out;
    }
}
