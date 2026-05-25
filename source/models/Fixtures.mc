import Toybox.Lang;

// M5.2: 30 Hebrew fixture articles ALL starting with the letter ש so that
// typing ש in the keyboard exercises both the inline top-2 suggestion
// path AND the "▼ N more" → full-screen ResultsView path (which was
// dormant in M4/M5/M5.1 with only 3 fixtures).
//
// Schema bumped from :version => 1 (M4) to :version => 2. FixtureInstaller
// detects the mismatch and re-seeds automatically on next launch — no
// manual sim wipe needed.
//
// Titles are mostly real Hebrew Wikipedia-shaped entries (שלום, שבת,
// שיר השירים, ...). The deliberately-anachronistic title
// "שיר לשלום מאת חיים נחמן ביאליק ונועה קירל" is shipped per the user's
// explicit example — doubles as a long-title wrap stress test.
//
// Bodies: "shalom" keeps Strings.sampleArticle() (~50 raw lines, ~2 KB)
// to exercise the lazy article-layout in wikiwatchView. The other 29
// articles get short hardcoded 2–4 line Hebrew bodies (< 200 bytes each)
// so the total fixture install stays well under the 9 MB Storage cap +
// 16 KB per-value cap.
//
// Pure — only imports Toybox.Lang.
module Fixtures {
    function manifest() as Dictionary {
        return {
            :version => 2,
            :articles => [
                { :id => "shalom",            :title => "שלום",                                                    :popularity => 100 },
                { :id => "shabbat",           :title => "שבת",                                                     :popularity => 99  },
                { :id => "shir",              :title => "שיר",                                                     :popularity => 96  },
                { :id => "shema",             :title => "שמע ישראל",                                               :popularity => 95  },
                { :id => "shulchan-arukh",    :title => "שולחן ערוך",                                              :popularity => 92  },
                { :id => "shir-hashirim",     :title => "שיר השירים",                                              :popularity => 90  },
                { :id => "shemonah-esreh",    :title => "שמונה עשרה",                                              :popularity => 88  },
                { :id => "shemesh",           :title => "שמש",                                                     :popularity => 86  },
                { :id => "shlomo-hamelech",   :title => "שלמה המלך",                                               :popularity => 85  },
                { :id => "shir-lashalom-long",:title => "שיר לשלום מאת חיים נחמן ביאליק ונועה קירל",               :popularity => 84  },
                { :id => "shmuel",            :title => "שמואל",                                                   :popularity => 82  },
                { :id => "shofar",            :title => "שופר",                                                    :popularity => 80  },
                { :id => "shoftim",           :title => "שופטים",                                                  :popularity => 78  },
                { :id => "shekhinah",         :title => "שכינה",                                                   :popularity => 76  },
                { :id => "shalom-aleichem",   :title => "שלום עליכם",                                              :popularity => 74  },
                { :id => "shamayim-vaaretz", :title => "שמיים וארץ",                                              :popularity => 72  },
                { :id => "shmirat-shabbat",   :title => "שמירת שבת",                                               :popularity => 70  },
                { :id => "shirat-hayam",      :title => "שירת הים",                                                :popularity => 68  },
                { :id => "shir-eretz",        :title => "שיר ארץ ישראל",                                           :popularity => 66  },
                { :id => "shimon-bar-yochai", :title => "שמעון בר יוחאי",                                          :popularity => 64  },
                { :id => "shemesh-bagilboa",  :title => "שמש בגלבוע",                                              :popularity => 62  },
                { :id => "sheleg",            :title => "שלג",                                                     :popularity => 60  },
                { :id => "shemen-zayit",      :title => "שמן זית",                                                 :popularity => 58  },
                { :id => "shaarei-tzedek",    :title => "שערי צדק",                                                :popularity => 56  },
                { :id => "shabbat-hamalka",   :title => "שבת המלכה",                                               :popularity => 54  },
                { :id => "shir-mishirei",     :title => "שיר משירי דוד",                                           :popularity => 52  },
                { :id => "shulamit",          :title => "שולמית",                                                  :popularity => 50  },
                { :id => "shimshon",          :title => "שמשון",                                                   :popularity => 48  },
                { :id => "sheh",              :title => "שה",                                                      :popularity => 46  },
                { :id => "shdema",            :title => "שדמה",                                                    :popularity => 44  }
            ]
        };
    }

    function bodyOf(id as String) as String? {
        if (id.equals("shalom"))             { return Strings.sampleArticle(); }
        if (id.equals("shabbat"))            { return _short("שבת", "השבת היא היום השביעי בשבוע ויום מנוחה במסורת היהודית."); }
        if (id.equals("shir"))               { return _short("שיר", "שיר הוא יצירה אומנותית של מילים ולחן."); }
        if (id.equals("shema"))              { return _short("שמע ישראל", "תפילה מרכזית הפותחת בפסוק מן ספר דברים."); }
        if (id.equals("shulchan-arukh"))     { return _short("שולחן ערוך", "ספר הלכה מקיף שכתב יוסף קארו במאה השש עשרה."); }
        if (id.equals("shir-hashirim"))      { return _short("שיר השירים", "מגילה מקראית של אהבה בין דוד לרעיה."); }
        if (id.equals("shemonah-esreh"))     { return _short("שמונה עשרה", "תפילה מרכזית הנאמרת שלוש פעמים ביום."); }
        if (id.equals("shemesh"))            { return _short("שמש", "השמש היא הכוכב במרכז מערכת השמש שלנו."); }
        if (id.equals("shlomo-hamelech"))    { return _short("שלמה המלך", "מלך ישראל הידוע בחכמתו ובבניית המקדש."); }
        if (id.equals("shir-lashalom-long")) { return _short("שיר לשלום", "השיר נכתב במקור על ידי יעקב רוטבליט. הכותרת בקטלוג היא דוגמת קצה לבדיקת גלישת שורות."); }
        if (id.equals("shmuel"))             { return _short("שמואל", "נביא ושופט אחרון בתקופת השופטים."); }
        if (id.equals("shofar"))             { return _short("שופר", "כלי נשיפה מקרני בעלי חיים, נשמע בראש השנה."); }
        if (id.equals("shoftim"))            { return _short("שופטים", "ספר מקראי המתאר את תקופת השופטים בישראל."); }
        if (id.equals("shekhinah"))          { return _short("שכינה", "מושג קבלי לנוכחות אלוהית בעולם."); }
        if (id.equals("shalom-aleichem"))    { return _short("שלום עליכם", "ברכה מסורתית הנאמרת בליל שבת."); }
        if (id.equals("shamayim-vaaretz"))   { return _short("שמיים וארץ", "ביטוי מקראי לכל היקום הנברא."); }
        if (id.equals("shmirat-shabbat"))    { return _short("שמירת שבת", "ההלכה והמנהג של קדושת היום השביעי."); }
        if (id.equals("shirat-hayam"))       { return _short("שירת הים", "שיר ההודיה לאחר קריעת ים סוף."); }
        if (id.equals("shir-eretz"))         { return _short("שיר ארץ ישראל", "סוגה מוזיקלית מן המאה העשרים."); }
        if (id.equals("shimon-bar-yochai"))  { return _short("שמעון בר יוחאי", "מקובל מן המאה השנייה לספירה."); }
        if (id.equals("shemesh-bagilboa"))   { return _short("שמש בגלבוע", "פסוק קינה של דוד על שאול ויהונתן."); }
        if (id.equals("sheleg"))             { return _short("שלג", "משקעים מוצקים של גבישי קרח."); }
        if (id.equals("shemen-zayit"))       { return _short("שמן זית", "שמן מסחיטת זיתים, מרכיב מרכזי במטבח."); }
        if (id.equals("shaarei-tzedek"))     { return _short("שערי צדק", "ביטוי מן הספרות העברית, גם שם של מוסד."); }
        if (id.equals("shabbat-hamalka"))    { return _short("שבת המלכה", "כינוי פיוטי ליום השבת."); }
        if (id.equals("shir-mishirei"))      { return _short("שיר משירי דוד", "פתיחה רגילה למזמורי תהילים."); }
        if (id.equals("shulamit"))           { return _short("שולמית", "דמות מן שיר השירים."); }
        if (id.equals("shimshon"))           { return _short("שמשון", "אחד משופטי ישראל, הידוע בכוחו."); }
        if (id.equals("sheh"))               { return _short("שה", "בעל חיים, צאן."); }
        if (id.equals("shdema"))             { return _short("שדמה", "שדה זרוע, מן ספרי הנביאים."); }
        return null;
    }

    // Small helper to build short Hebrew article bodies with a header.
    function _short(title as String, body as String) as String {
        return "# " + title + "\n" + body + "\n";
    }
}
