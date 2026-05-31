import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M9.6 tests for IndexCache — the shared, load-once compact search index.

(:test)
function indexCache_loadsOnceAndCachesAcrossWipe(logger as Logger) as Boolean {
    // The fix: build the index ONCE, then reuse. Proof: load it, then wipe the
    // backing Storage; a cached index still returns the data (a re-loading impl
    // would return empty). This is exactly the redundant-reload the long-press
    // crash came from.
    IndexStore.wipeAll();
    InstallState.reset();
    IndexCache.clear();
    IndexStore.putPart(0, [
        { :id => "0", :title => "אפס", :popularity => 100 },
        { :id => "1", :title => "שלום", :popularity => 90 }
    ] as Array<Dictionary>);

    var first = IndexCache.get();
    var t1 = (first[:titles] as Array<String>).size();

    IndexStore.wipeAll();                 // storage gone; cache must survive
    var second = IndexCache.get();
    var titles = second[:titles] as Array<String>;

    IndexStore.wipeAll();
    IndexCache.clear();
    logger.debug("t1=" + t1 + " t2=" + titles.size());
    return t1 == 2 && titles.size() == 2 && titles[1].equals("שלום");
}

(:test)
function indexCache_clearForcesReload(logger as Logger) as Boolean {
    // clear() must drop the cache so the next get() reflects current Storage.
    IndexStore.wipeAll();
    InstallState.reset();
    IndexCache.clear();
    IndexStore.putPart(0, [ { :id => "0", :title => "אחת", :popularity => 5 } ] as Array<Dictionary>);
    IndexCache.get();                     // cache 1 entry
    IndexStore.wipeAll();                 // storage now empty
    IndexCache.clear();                   // force reload
    var after = IndexCache.get();         // reloads from empty storage
    var n = (after[:titles] as Array<String>).size();
    IndexCache.clear();
    logger.debug("after-clear reload size=" + n);
    return n == 0;
}

(:test)
function indexCache_normTitlesPrecomputed(logger as Logger) as Boolean {
    // normTitles is built (and matches Search.normalize) so the search hot path
    // never normalizes per keystroke.
    IndexStore.wipeAll();
    InstallState.reset();
    IndexCache.clear();
    IndexStore.putPart(0, [ { :id => "0", :title => "שב\"ק", :popularity => 5 } ] as Array<Dictionary>);
    var idx = IndexCache.get();
    var norm = (idx[:normTitles] as Array<String>)[0];
    IndexStore.wipeAll();
    IndexCache.clear();
    logger.debug("norm=" + norm);
    return norm.equals(Search.normalize("שב\"ק")) && norm.equals("שבק");
}

(:test)
function indexCache_respectsInstalledCountCap(logger as Logger) as Boolean {
    // M9.5 (C) cap carries into the cache: a partial install caps the searchable
    // index to installedCount.
    IndexStore.wipeAll();
    InstallState.reset();
    IndexCache.clear();
    IndexStore.putPart(0, [
        { :id => "0", :title => "א", :popularity => 9 },
        { :id => "1", :title => "ב", :popularity => 8 },
        { :id => "2", :title => "ג", :popularity => 7 }
    ] as Array<Dictionary>);
    InstallState.setInstalledCount(2);    // only 2 bodies stored
    var idx = IndexCache.get();
    var n = (idx[:titles] as Array<String>).size();
    IndexStore.wipeAll();
    InstallState.reset();
    IndexCache.clear();
    logger.debug("capped size=" + n);
    return n == 2;
}
