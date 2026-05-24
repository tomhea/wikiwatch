import Toybox.Lang;

// M4 fixture manifest + bodies. Pure module (no Storage / WatchUi /
// Communications). Caller (FixtureInstaller) is responsible for writing
// the fixture data into Application.Storage via Manifest / ArticleStore.
//
// "shalom" reuses the existing Strings.sampleArticle() so the M2.x article
// reader sees real content when M6 wires the long-press flow. "torah" and
// "shabbat" are 1-paragraph Hebrew placeholders; M7 will replace them
// with real Wikipedia bodies pulled from wikiwatch.tomhe.app/.
module Fixtures {
    function manifest() as Dictionary {
        return {
            :version => 1,
            :articles => [
                { :id => "shalom",  :title => "שלום",  :popularity => 100 },
                { :id => "torah",   :title => "תורה",  :popularity => 80 },
                { :id => "shabbat", :title => "שבת",   :popularity => 60 }
            ]
        };
    }

    function bodyOf(id as String) as String? {
        if (id.equals("shalom"))  { return Strings.sampleArticle(); }
        if (id.equals("torah"))   { return _torah(); }
        if (id.equals("shabbat")) { return _shabbat(); }
        return null;
    }

    function _torah() as String {
        return "# תורה\n"
             + "התורה היא חמשת ספרי משה.\n"
             + "## ספרים\n"
             + "בראשית, שמות, ויקרא, במדבר, דברים.\n";
    }

    function _shabbat() as String {
        return "# שבת\n"
             + "השבת היא היום השביעי בשבוע.\n"
             + "## ברכות\n"
             + "קידוש, המוציא, ברכת המזון.\n";
    }
}
