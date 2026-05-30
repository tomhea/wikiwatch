import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// M9 article-index storage. The article index (all {id,title,popularity}
// entries) is too large to fit in a single manifest response once the corpus
// exceeds ~190 articles. Instead the server serves it as K small `index/N.json`
// parts (~180 entries each, ~11 KB — under the ~12 KB response cap).
//
// During install each part is written here under "index:<K>". At steady state,
// KeyboardDelegate reads the full concatenated list via load() instead of
// Manifest.load()[:articles].
//
// R4: every setValue is guarded by a freeMemory check.
// R6: source/storage — imports Toybox.Application.
module IndexStore {
    const KEY_PREFIX = "index:";
    const KEY_COUNT  = "indexPartsCount";

    // Write one index part (an Array of Symbol-keyed article Dicts) to Storage.
    // Returns true on success, false if the freeMemory guard fired (R4).
    function putPart(k as Number, articles as Array<Dictionary>) as Boolean {
        // Estimate: 100-byte overhead + 80 bytes per article (id ~16, title
        // ~40, popularity ~4, dict overhead ~20).
        var est = 100 + articles.size() * 80;
        if (System.getSystemStats().freeMemory < est * 3) { return false; }
        // Serialise: Symbol keys aren't Storage-safe; convert to String keys.
        var storage = [] as Array<Dictionary>;
        for (var i = 0; i < articles.size(); i++) {
            var a = articles[i] as Dictionary;
            storage.add({
                "id" => a[:id], "title" => a[:title], "popularity" => a[:popularity]
            });
        }
        Application.Storage.setValue(KEY_PREFIX + k.toString(), storage);
        return true;
    }

    // Read one part back; null if not yet written.
    function getPart(k as Number) as Array<Dictionary>? {
        var raw = Application.Storage.getValue(KEY_PREFIX + k.toString()) as Array?;
        if (raw == null) { return null; }
        var out = [] as Array<Dictionary>;
        for (var i = 0; i < raw.size(); i++) {
            var a = raw[i] as Dictionary;
            out.add({ :id => a["id"], :title => a["title"], :popularity => a["popularity"] });
        }
        return out;
    }

    // Concatenate all stored parts in order by probing each key until the
    // first miss (or up to a hard ceiling of 100 parts). Parts missing from
    // Storage are silently skipped to provide a degraded-but-not-crashed result.
    // R5: ~80 B/article × up to 1500 articles ≈ 120 KB. Guard that 3× that
    // is free before building the array; return empty on low memory so the
    // caller (KeyboardDelegate / _corpusIntact) degrades gracefully.
    function load() as Array<Dictionary> {
        if (System.getSystemStats().freeMemory < 360000) {   // 3 × 120 KB
            System.println("M9 IndexStore.load: skipped (low memory)");
            return [] as Array<Dictionary>;
        }
        var out = [] as Array<Dictionary>;
        var k = 0;
        var misses = 0;
        while (k < 100 && misses < 2) {
            var part = getPart(k);
            if (part == null) {
                misses++;
            } else {
                misses = 0;
                for (var i = 0; i < part.size(); i++) {
                    out.add(part[i] as Dictionary);
                }
            }
            k++;
        }
        return out;
    }

    // M9.3: compact load for the keyboard search index. Returns
    //   { :titles => Array<String>, :pops => Array<Number> }
    // indexed BY ARTICLE ID (titles[i] = title of article id i, so the array
    // position is the id and points straight at the "article:<i>" body key —
    // no separate id array needed). Reads the raw String-keyed parts directly
    // and never materialises the ~1462 Symbol-keyed dicts that load() builds,
    // so the resident search structure is ~4x fewer objects (the real watch's
    // GC chokes on the dict form). R5: guarded like load().
    function loadCompact() as Dictionary {
        var titles = [] as Array<String>;
        var pops = [] as Array<Number>;
        if (System.getSystemStats().freeMemory < 360000) {
            System.println("M9 IndexStore.loadCompact: skipped (low memory)");
            return { :titles => titles, :pops => pops };
        }
        var k = 0;
        var misses = 0;
        while (k < 100 && misses < 2) {
            var raw = Application.Storage.getValue(KEY_PREFIX + k.toString()) as Array?;
            if (raw == null) {
                misses++;
            } else {
                misses = 0;
                for (var j = 0; j < raw.size(); j++) {
                    var a = raw[j] as Dictionary;
                    var id = (a["id"] as String).toNumber();
                    if (id == null) { continue; }
                    while (titles.size() <= id) { titles.add(""); pops.add(0); }
                    titles[id] = a["title"] as String;
                    pops[id] = a["popularity"] as Number;
                }
            }
            k++;
        }
        return { :titles => titles, :pops => pops };
    }

    // True iff every index part K in [0, indexCount) is present in Storage.
    function isComplete(indexCount as Number) as Boolean {
        for (var k = 0; k < indexCount; k++) {
            if (Application.Storage.getValue(KEY_PREFIX + k.toString()) == null) {
                return false;
            }
        }
        return true;
    }

    // Delete all index:<K> keys up to 100 parts + the count key.
    function wipeAll() as Void {
        for (var k = 0; k < 100; k++) {
            var key = KEY_PREFIX + k.toString();
            if (Application.Storage.getValue(key) == null) { break; }
            Application.Storage.deleteValue(key);
        }
        Application.Storage.deleteValue(KEY_COUNT);
    }
}
