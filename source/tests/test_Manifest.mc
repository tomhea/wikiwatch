import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M4 tests for the Manifest storage wrapper. Each test starts and ends
// with deleteValue("manifest") to keep Storage clean across runs (M1
// test_Strings hebrew round-trip pattern).

(:test)
function manifest_emptyDefaultWhenStorageEmpty(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var m = Manifest.load();
    Application.Storage.deleteValue("manifest");
    var arts = m[:articles] as Array;
    var version = m[:version] as Number;
    logger.debug("load() empty default = version=" + version + " articles.size=" + arts.size());
    return version == 1 && arts.size() == 0;
}

(:test)
function manifest_isEmptyTrueOnFresh(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var e = Manifest.isEmpty();
    Application.Storage.deleteValue("manifest");
    logger.debug("isEmpty() on fresh = " + e);
    return e == true;
}

(:test)
function manifest_saveLoadRoundtrip(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var orig = {
        :version => 1,
        :articles => [
            { :id => "a1", :title => "כותרת אחת", :popularity => 50 },
            { :id => "a2", :title => "כותרת שתיים", :popularity => 30 }
        ]
    };
    var saved = Manifest.save(orig);
    var loaded = Manifest.load();
    Application.Storage.deleteValue("manifest");
    var arts = loaded[:articles] as Array;
    logger.debug("roundtrip saved=" + saved + " loaded.articles.size=" + arts.size());
    return saved && arts.size() == 2 && (arts[0] as Dictionary)[:id].equals("a1");
}

(:test)
function manifest_articleIdsOrder(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var orig = {
        :version => 1,
        :articles => [
            { :id => "alpha",   :title => "א", :popularity => 100 },
            { :id => "bravo",   :title => "ב", :popularity => 80 },
            { :id => "charlie", :title => "ג", :popularity => 60 }
        ]
    };
    Manifest.save(orig);
    var ids = Manifest.articleIds();
    Application.Storage.deleteValue("manifest");
    logger.debug("articleIds = " + ids.toString());
    return ids.size() == 3
        && (ids[0] as String).equals("alpha")
        && (ids[1] as String).equals("bravo")
        && (ids[2] as String).equals("charlie");
}

(:test)
function manifest_titleOfHit(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var orig = {
        :version => 1,
        :articles => [{ :id => "shalom", :title => "שלום", :popularity => 100 }]
    };
    Manifest.save(orig);
    var t = Manifest.titleOf("shalom");
    Application.Storage.deleteValue("manifest");
    logger.debug("titleOf('shalom') = '" + t + "'");
    return t != null && t.equals("שלום");
}

(:test)
function manifest_titleOfMiss(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var orig = {
        :version => 1,
        :articles => [{ :id => "shalom", :title => "שלום", :popularity => 100 }]
    };
    Manifest.save(orig);
    var t = Manifest.titleOf("nonexistent");
    Application.Storage.deleteValue("manifest");
    logger.debug("titleOf('nonexistent') = " + t);
    return t == null;
}
