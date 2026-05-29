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

    // M8: write a whole chunk's worth of articles to Storage in one call —
    // one Storage key per article (article:<id>), preserving M7's fast direct
    // read path. Each setValue is wrapped in try/catch so a single storage-
    // full error doesn't abort the rest of the batch. Returns the count
    // successfully written.
    //
    // `articles` is a String-keyed Dictionary { "<id>" => "<body>", ... } as
    // it arrives from the parsed chunk JSON. (OOM is uncatchable in Monkey C,
    // so the try/catch here guards Storage exceptions, not heap exhaustion —
    // the bodies are already resident, so writing them allocates only the key
    // string.)
    // M8.3 self-heal: true iff every id has a body in Storage. Used at launch
    // to spot-check corpus integrity (a sampled subset of ids) so a
    // complete-but-empty corpus triggers an auto re-install.
    function allPresent(ids as Array<String>) as Boolean {
        for (var i = 0; i < ids.size(); i++) {
            if (bodyOf(ids[i]) == null) { return false; }
        }
        return true;
    }

    function putBatch(articles as Dictionary) as Number {
        var written = 0;
        var ids = articles.keys();
        for (var i = 0; i < ids.size(); i++) {
            var id = ids[i] as String;
            var body = articles[id] as String;
            try {
                // R4: putBody applies the freeMemory guard per article. The
                // bodies are already resident (they arrived in the parsed
                // chunk dict), so the only fresh allocation is the key String.
                if (putBody(id, body)) {
                    written++;
                }
            } catch (e) {
                // A single Storage-full / serialization error must not abort
                // the rest of the batch. OOM itself is uncatchable, but
                // Storage exceptions (quota) are catchable here.
                System.println("M8 putBatch: setValue failed for " + id);
            }
        }
        return written;
    }
}
