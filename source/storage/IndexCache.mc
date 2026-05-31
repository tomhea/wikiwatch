import Toybox.Lang;

// M9.6: process-lifetime cache of the compact search index, shared across ALL
// keyboard instances.
//
// `wikiwatchKeyboardDelegate.initialize` used to load the whole index itself
// (IndexStore.loadCompact + the manifest fallback + installedCount cap + a
// normalize pass over every title). That ran on EVERY keyboard construction —
// including the long-press flow, which pushes a SECOND keyboard on top of the
// resident article reader. At ~1200 articles a second full index copy (~the
// titles/pops/normTitles arrays) plus the redundant normalize loop, on top of
// the reader + first keyboard, exhausted the heap / tripped the watchdog and
// crashed (launch loaded fine because nothing else was resident).
//
// This module builds that index ONCE and hands every keyboard the same arrays.
// `clear()` invalidates it when the corpus is wiped/reinstalled.
//
// Lives in storage/ (it reads IndexStore/Manifest/InstallState). Search is a
// pure import for normalize().
module IndexCache {
    var _titles = null as Array<String>?;
    var _pops = null as Array<Number>?;
    var _normTitles = null as Array<String>?;

    // Shared compact index: { :titles, :pops, :normTitles } (parallel arrays,
    // position == article id). Built on first call, cached thereafter.
    function get() as Dictionary {
        if (_titles == null) {
            _build();
        }
        return { :titles => _titles, :pops => _pops, :normTitles => _normTitles };
    }

    // Drop the cache so the next get() reloads (call on wipe / fresh install).
    function clear() as Void {
        _titles = null;
        _pops = null;
        _normTitles = null;
    }

    // True once the index has been loaded this session (no side effect).
    function isLoaded() as Boolean {
        return _titles != null;
    }

    function _build() as Void {
        // M9.3: compact index from the downloaded index parts. M8-era corpora
        // have no parts -> fall back to the manifest's articles[].
        var compact = IndexStore.loadCompact();
        var titles = compact[:titles] as Array<String>;
        var pops = compact[:pops] as Array<Number>;
        if (titles.size() == 0) {
            var manifestArts = Manifest.load()[:articles] as Array<Dictionary>?;
            if (manifestArts != null) {
                for (var i = 0; i < manifestArts.size(); i++) {
                    var a = manifestArts[i] as Dictionary;
                    var id = (a[:id] as String).toNumber();
                    // M9.5 (B): guard an absurd/sparse id from exploding the pad loop.
                    if (id == null || id < 0 || id > 100000) { continue; }
                    while (titles.size() <= id) { titles.add(""); pops.add(0); }
                    titles[id] = a[:title] as String;
                    pops[id] = a[:popularity] as Number;
                }
            }
        }
        // M9.5 (C): cap the searchable index to the stored article prefix so a
        // budget-stopped partial install never surfaces an id with no body.
        var cap = InstallState.getInstalledCount();
        if (cap > 0 && cap < titles.size()) {
            titles = titles.slice(0, cap);
            pops = pops.slice(0, cap);
        }
        // M9.5 (D2): normalize each title ONCE. For the common (no ASCII
        // punctuation) case normalize returns the SAME string object, so this
        // array mostly aliases `titles` — minimal extra heap.
        var norm = new [titles.size()];
        for (var i = 0; i < titles.size(); i++) {
            norm[i] = Search.normalize(titles[i] as String);
        }
        _titles = titles;
        _pops = pops;
        _normTitles = norm;
    }
}
