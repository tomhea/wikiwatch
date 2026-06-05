import Toybox.Lang;
import Toybox.System;

// M9.6: process-lifetime cache of the compact search index, shared across ALL
// keyboard instances (built once, every keyboard gets the same arrays; the
// long-press flow's second keyboard reuses it instead of re-loading).
//
// M10.5: the build is now SLICEABLE across Timer ticks. Building the whole index
// (deserialize every `index:<K>` part + normalize every title) in ONE event
// handler trips the watch watchdog once the corpus is large (~1462 tripped it on
// the Venu 2 — the reason the corpus was capped at 1200). `buildStep(maxParts)`
// processes a bounded number of parts per call (interleaving the normalize), so
// the keyboard can drive it across ticks and the corpus can grow past the old cap.
// `get()` still returns the finished arrays (and lazily sync-builds as a fallback
// for any non-keyboard caller).
//
// Lives in storage/ (reads IndexStore/Manifest/InstallState). Search is a pure
// import for normalize().
module IndexCache {
    var _titles = null as Array<String>?;
    var _pops = null as Array<Number>?;
    var _normTitles = null as Array<String>?;
    // M10.5 sliced-build accumulators (non-null only while a build is in progress).
    var _bTitles = null as Array<String>?;
    var _bPops = null as Array<Number>?;
    var _bNorm = null as Array<String>?;
    var _bk = 0;
    var _bMisses = 0;

    // Shared compact index: { :titles, :pops, :normTitles } (parallel arrays,
    // position == article id). Lazily sync-builds if not yet loaded — but the
    // keyboard drives buildStep() across ticks and only calls this once isLoaded().
    function get() as Dictionary {
        if (_titles == null) {
            while (!buildStep(100)) {}
        }
        return { :titles => _titles, :pops => _pops, :normTitles => _normTitles };
    }

    // Drop the cache (+ any in-flight build) so the next build reloads.
    function clear() as Void {
        _titles = null;
        _pops = null;
        _normTitles = null;
        _bTitles = null;
        _bPops = null;
        _bNorm = null;
        _bk = 0;
        _bMisses = 0;
    }

    // True once the index has finished loading this session (no side effect).
    function isLoaded() as Boolean {
        return _titles != null;
    }

    // M10.5: advance the index build by up to `maxParts` index parts, returning
    // true once the whole index is loaded + cached. Each part = a Storage
    // getValue (deserialize ~150 entries) + filling titles/pops/normTitles for
    // those ids — bounded work, so a few parts per tick stays under the watchdog.
    function buildStep(maxParts as Number) as Boolean {
        if (_titles != null) { return true; }       // already loaded
        if (_bTitles == null) {
            // Begin a fresh sliced build. Mirror loadCompact's low-memory guard:
            // degrade to an empty index rather than risk an OOM.
            if (System.getSystemStats().freeMemory < 360000) {
                System.println("M10.5 IndexCache: low memory — empty index");
                _commit([] as Array<String>, [] as Array<Number>, [] as Array<String>);
                return true;
            }
            _bTitles = [] as Array<String>;
            _bPops = [] as Array<Number>;
            _bNorm = [] as Array<String>;
            _bk = 0;
            _bMisses = 0;
        }
        var titles = _bTitles as Array<String>;
        var pops = _bPops as Array<Number>;
        var norm = _bNorm as Array<String>;
        var processed = 0;
        // Probe parts in order; two consecutive misses (or the 100-part ceiling)
        // ends the index, exactly like the one-shot loadCompact.
        while (processed < maxParts && _bMisses < 2 && _bk < 100) {
            var raw = IndexStore.rawPart(_bk);
            _bk++;
            processed++;
            if (raw == null) { _bMisses++; continue; }
            _bMisses = 0;
            for (var j = 0; j < raw.size(); j++) {
                var a = raw[j] as Dictionary;
                var idn = (a["id"] as String).toNumber();
                // M9.5 (B): clamp an absurd/sparse id from exploding the pad loop.
                if (idn == null || idn < 0 || idn > 100000) { continue; }
                var id = idn as Number;
                while (titles.size() <= id) { titles.add(""); pops.add(0); norm.add(""); }
                var t = a["title"] as String;
                titles[id] = t;
                pops[id] = a["popularity"] as Number;
                norm[id] = Search.normalize(t);   // M9.5 (D2): normalize once, inline
            }
        }
        if (_bMisses >= 2 || _bk >= 100) {
            _finish(titles, pops, norm);
            return true;
        }
        return false;
    }

    // Apply the M8-era manifest fallback + the installed-prefix cap, then commit.
    function _finish(titles as Array<String>, pops as Array<Number>, norm as Array<String>) as Void {
        // M9.3: M8-era corpora have no index parts -> fall back to manifest.articles[]
        // (small — fits one handler).
        if (titles.size() == 0) {
            var manifestArts = Manifest.load()[:articles] as Array<Dictionary>?;
            if (manifestArts != null) {
                for (var i = 0; i < manifestArts.size(); i++) {
                    var a = manifestArts[i] as Dictionary;
                    var idn = (a[:id] as String).toNumber();
                    if (idn == null || idn < 0 || idn > 100000) { continue; }
                    var id = idn as Number;
                    while (titles.size() <= id) { titles.add(""); pops.add(0); norm.add(""); }
                    var t = a[:title] as String;
                    titles[id] = t;
                    pops[id] = a[:popularity] as Number;
                    norm[id] = Search.normalize(t);
                }
            }
        }
        // M9.5 (C): cap to the stored article prefix so a budget-stopped partial
        // install never surfaces an id with no body.
        var cap = InstallState.getInstalledCount();
        if (cap > 0 && cap < titles.size()) {
            titles = titles.slice(0, cap);
            pops = pops.slice(0, cap);
            norm = norm.slice(0, cap);
        }
        _commit(titles, pops, norm);
    }

    function _commit(titles as Array<String>, pops as Array<Number>, norm as Array<String>) as Void {
        _titles = titles;
        _pops = pops;
        _normTitles = norm;
        _bTitles = null;
        _bPops = null;
        _bNorm = null;
    }
}
