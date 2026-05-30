import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M9 tests for IndexStore — persistent per-part article index.

(:test)
function indexStore_putGetRoundtrip(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    var arts = [
        { :id => "0", :title => "אחד", :popularity => 100 },
        { :id => "1", :title => "שתיים", :popularity => 90 }
    ] as Array<Dictionary>;
    IndexStore.putPart(0, arts);
    var got = IndexStore.getPart(0);
    IndexStore.wipeAll();
    logger.debug("getPart(0) = " + got);
    return got != null && (got as Array<Dictionary>).size() == 2
        && ((got as Array<Dictionary>)[0] as Dictionary)[:id].equals("0")
        && ((got as Array<Dictionary>)[1] as Dictionary)[:title].equals("שתיים");
}

(:test)
function indexStore_getPartMissingIsNull(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    var got = IndexStore.getPart(99);
    return got == null;
}

(:test)
function indexStore_loadConcatenatesAllParts(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    var p0 = [ { :id => "0", :title => "א", :popularity => 100 } ] as Array<Dictionary>;
    var p1 = [ { :id => "1", :title => "ב", :popularity => 90 },
               { :id => "2", :title => "ג", :popularity => 80 } ] as Array<Dictionary>;
    IndexStore.putPart(0, p0);
    IndexStore.putPart(1, p1);
    var all = IndexStore.load();
    IndexStore.wipeAll();
    logger.debug("load() size = " + all.size());
    return all.size() == 3
        && (all[0] as Dictionary)[:id].equals("0")
        && (all[2] as Dictionary)[:title].equals("ג");
}

(:test)
function indexStore_loadEmptyReturnsEmpty(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    return IndexStore.load().size() == 0;
}

(:test)
function indexStore_loadCompactIndexesById(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    // ids out of order across parts -> compact arrays must place by id.
    IndexStore.putPart(0, [
        { :id => "0", :title => "אפס", :popularity => 100 },
        { :id => "1", :title => "אחת", :popularity => 90 }
    ] as Array<Dictionary>);
    IndexStore.putPart(1, [
        { :id => "2", :title => "שתיים", :popularity => 80 }
    ] as Array<Dictionary>);
    var c = IndexStore.loadCompact();
    var titles = c[:titles] as Array<String>;
    var pops = c[:pops] as Array<Number>;
    IndexStore.wipeAll();
    logger.debug("compact titles=" + titles.size());
    return titles.size() == 3
        && titles[0].equals("אפס") && titles[2].equals("שתיים")
        && pops[1] == 90;
}

(:test)
function indexStore_loadCompactEmpty(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    var c = IndexStore.loadCompact();
    return (c[:titles] as Array).size() == 0 && (c[:pops] as Array).size() == 0;
}

(:test)
function indexStore_isCompleteWhenAllPartsPresent(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    IndexStore.putPart(0, [ { :id => "0", :title => "א", :popularity => 100 } ] as Array<Dictionary>);
    IndexStore.putPart(1, [ { :id => "1", :title => "ב", :popularity => 90 } ] as Array<Dictionary>);
    var ok = IndexStore.isComplete(2);
    IndexStore.wipeAll();
    logger.debug("isComplete(2) = " + ok);
    return ok == true;
}

(:test)
function indexStore_isIncompleteWhenPartMissing(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    IndexStore.putPart(0, [ { :id => "0", :title => "א", :popularity => 100 } ] as Array<Dictionary>);
    // part 1 missing
    var ok = IndexStore.isComplete(2);
    IndexStore.wipeAll();
    return ok == false;
}

(:test)
function indexStore_wipeAllClearsEverything(logger as Logger) as Boolean {
    IndexStore.wipeAll();
    IndexStore.putPart(0, [ { :id => "0", :title => "א", :popularity => 100 } ] as Array<Dictionary>);
    IndexStore.putPart(1, [ { :id => "1", :title => "ב", :popularity => 90 } ] as Array<Dictionary>);
    IndexStore.wipeAll();
    return IndexStore.getPart(0) == null
        && IndexStore.getPart(1) == null
        && IndexStore.load().size() == 0;
}
