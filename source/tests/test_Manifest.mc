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

// --- M7: wipeArticles ---

(:test)
function manifest_wipeArticlesDeletesAllArticleBodies(logger as Logger) as Boolean {
    // Pre-seed Storage with a manifest + 3 article bodies. wipeArticles()
    // should delete all 3 article:<id> keys; the manifest key stays.
    Application.Storage.deleteValue("manifest");
    Application.Storage.deleteValue("article:a1");
    Application.Storage.deleteValue("article:a2");
    Application.Storage.deleteValue("article:a3");
    var m = {
        :version => 7,
        :articles => [
            { :id => "a1", :title => "א", :popularity => 50 },
            { :id => "a2", :title => "ב", :popularity => 40 },
            { :id => "a3", :title => "ג", :popularity => 30 }
        ]
    };
    Manifest.save(m);
    Application.Storage.setValue("article:a1", "body-1");
    Application.Storage.setValue("article:a2", "body-2");
    Application.Storage.setValue("article:a3", "body-3");
    var deleted = Manifest.wipeArticles();
    // Manifest should still exist:
    var manifestStillPresent = (Application.Storage.getValue("manifest") != null);
    // Bodies should be gone:
    var b1 = Application.Storage.getValue("article:a1");
    var b2 = Application.Storage.getValue("article:a2");
    var b3 = Application.Storage.getValue("article:a3");
    Application.Storage.deleteValue("manifest");
    logger.debug("wipeArticles deleted=" + deleted
        + " manifestStillPresent=" + manifestStillPresent
        + " b1=" + b1 + " b2=" + b2 + " b3=" + b3);
    return deleted == 3
        && manifestStillPresent
        && b1 == null && b2 == null && b3 == null;
}

(:test)
function manifest_wipeArticlesOnEmpty(logger as Logger) as Boolean {
    // No manifest, no articles -> wipeArticles returns 0, doesn't crash.
    Application.Storage.deleteValue("manifest");
    var deleted = Manifest.wipeArticles();
    logger.debug("wipeArticles on empty = " + deleted);
    return deleted == 0;
}

// --- M10.1: bodyCodec / modelVersion persistence ---

(:test)
function manifest_persistsCodecFields(logger as Logger) as Boolean {
    Application.Storage.deleteValue("manifest");
    var saved = Manifest.save({
        :version => 16, :articles => [],
        :bodyCodec => "bpe-huff-1", :modelVersion => 1
    });
    var loaded = Manifest.load();
    Application.Storage.deleteValue("manifest");
    logger.debug("persist codec=" + loaded[:bodyCodec] + " mv=" + loaded[:modelVersion]);
    return saved
        && (loaded[:bodyCodec] as String).equals("bpe-huff-1")
        && (loaded[:modelVersion] as Number) == 1;
}

(:test)
function manifest_loadDefaultsCodecForOldStored(logger as Logger) as Boolean {
    // A manifest stored before M10.1 (String-keyed, no codec keys) -> plain / 0.
    Application.Storage.deleteValue("manifest");
    Application.Storage.setValue("manifest", { "version" => 15, "articles" => [] });
    var loaded = Manifest.load();
    Application.Storage.deleteValue("manifest");
    logger.debug("old-stored codec=" + loaded[:bodyCodec] + " mv=" + loaded[:modelVersion]);
    return (loaded[:bodyCodec] as String).equals("plain") && (loaded[:modelVersion] as Number) == 0;
}
