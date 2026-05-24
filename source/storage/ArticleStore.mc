import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// M4 per-article body storage. Each body is one Storage value at key
// "article:<id>". UTF-8 Hebrew round-trips cleanly (proved in the M1
// strings_hebrewLiteralRoundtripsThroughStorage test).
//
// putBody() is R4-gated: returns false when freeMemory is below 3x the
// upper-bound byte size (length * 4 for worst-case UTF-8). R5: same guard
// mitigates the uncatchable OOM.
module ArticleStore {
    const KEY_PREFIX = "article:";

    function bodyOf(id as String) as String? {
        return Application.Storage.getValue(KEY_PREFIX + id) as String?;
    }

    function putBody(id as String, body as String) as Boolean {
        var bytes = body.length() * 4;
        if (System.getSystemStats().freeMemory < bytes * 3) {
            return false;
        }
        Application.Storage.setValue(KEY_PREFIX + id, body);
        return true;
    }
}
