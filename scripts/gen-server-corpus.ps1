# gen-server-corpus.ps1 — generate the static server files for wikiwatch.tomhe.app/
# Mirrors the M6.5 Fixtures.mc corpus (36 articles) into docs/server/.
# Run from the project root: powershell -File scripts/gen-server-corpus.ps1

$ErrorActionPreference = "Stop"

# Output directories
$root  = Resolve-Path "$PSScriptRoot\.."
$out   = Join-Path $root "docs\server"
$artDir = Join-Path $out  "article"
New-Item -ItemType Directory -Force -Path $artDir | Out-Null

# Helper: short article body — "# <title>\n<body>\n"
function Short($title, $body) {
    return "# $title`n$body`n"
}

# Long shalom body — Strings.sampleArticle()
$shalomBody = @"
# שלום היא מילה שימושית בהחלט
שלום היא מילה עברית עתיקה המשמשת גם כברכה וגם כפרידה.
המילה מקבלת משמעויות רבות לפי ההקשר שבו היא נאמרת.
## שורש המילה
השורש העברי שלם נמצא בלב המילה הזאת ובמילים רבות אחרות.
ממנו נגזרות המילים שלמות, להשלים, מושלם, ושלום עצמה.
### משמעות פנימית
המשמעות העמוקה היא של שלמות, חוסר מחסור, וקיום מאוזן.
לא רק היעדר מלחמה אלא נוכחות של טוב מלא ומאוזן.
#### מחקר אקדמי
חוקרי הלשון מצביעים על קרבה לשורש הערבי סלאם.
שתי המילים יוצאות ממקור שמי משותף בן אלפי שנים.
## שימוש בתנך
המילה שלום מופיעה בתנך פעמים רבות בהקשרים מגוונים.
היא מציינת לעיתים הסכם מדיני ולעיתים מצב נפשי פנימי.
### בספר בראשית
אברהם נפרד מאבימלך לשלום אחרי שכרתו ברית של אחווה.
יעקב חוזר אל בית אביו בשלום אחרי שנים של גלות.
### בספרי הנביאים
ישעיהו מתאר חזון אחרית הימים שבו לא ילמדו עוד מלחמה.
ירמיהו קורא לעם לבקש את שלום העיר שאליה הוגלה.
#### מזמורי תהילים
מזמור קכב פותח בקריאה שאלו שלום ירושלים.
מזמור פה מבטיח שצדק ושלום ישקו זה את זה.
## שימוש בתפילה
ברכת השלום היא הברכה האחרונה בעמידה ובברכת כהנים.
התפילה נחתמת במילה שלום בכמעט כל הסידורים המוכרים.
#### עושה שלום
המשפט עושה שלום במרומיו הוא יהי שלום עלינו חותם רבים.
אומרים אותו בסוף שמונה עשרה ובסיום ברכת המזון.
## שימוש בעת המודרנית
כיום שלום היא ברכת היומיום הנפוצה ביותר בעברית מדוברת.
אומרים אותה בפגישה, בפרידה, ובכל הזדמנות חברתית רגילה.
### שלום במכתב
מכתב רשמי בעברית נפתח לעיתים קרובות בשורת שלום רב.
מכתב לחבר קרוב מסתפק במילה אחת קצרה ומספיקה.
### שלום בטלפון
כשעונים לטלפון אומרים פשוט שלום או הלו עם נימה שואלת.
כשמסיימים שיחה מסתפקים שוב במילה שלום או להתראות.
## מילים נרדפות וקרובות
ברכה ופרידה, להתראות, לילה טוב, ובוקר טוב הן קרובות.
אך אף אחת מהן אינה משלבת את שני המשמעויות בו זמנית.
#### מילים בשפות אחרות
במילים אלוהה בהוואית או נמסטה בהודית יש מבנה דומה.
גם בהן ברכה ופרידה משתמשות באותה מילה בדיוק.
## סיכום
שלום היא מילה רבת פנים ועוצמה שמלווה אותנו מהבוקר עד הלילה.
היא ברכה, פרידה, איחול, מצב נפשי, וחזון לעתיד טוב יותר.
ראוי להגיד אותה הרבה ולכוון את הלב גם כשאומרים בקצרה. תפילה לשלום היא משאלה אמיתית גם כשנאמרת כדרך אגב בדלת היציאה או על סף הקפה של הבוקר עם המקרובים.
"@

# 36-entry corpus. Mirrors source/models/Fixtures.mc (M6.5).
# Order matters for popularity ordering downstream.
$articles = @(
    @{ id = "shalom";             title = "שלום";                                                  popularity = 100; body = $shalomBody                                                                                                                                                       }
    @{ id = "shabbat";            title = "שבת";                                                   popularity = 99;  body = Short "שבת"                                            "השבת היא היום השביעי בשבוע ויום מנוחה במסורת היהודית."                                                                                  }
    @{ id = "shir";               title = "שיר";                                                   popularity = 96;  body = Short "שיר"                                            "שיר הוא יצירה אומנותית של מילים ולחן."                                                                                                                                  }
    @{ id = "shema";              title = "שמע ישראל";                                             popularity = 95;  body = Short "שמע ישראל"                                      "תפילה מרכזית הפותחת בפסוק מן ספר דברים."                                                                                                                                  }
    @{ id = "shulchan-arukh";     title = "שולחן ערוך";                                            popularity = 92;  body = Short "שולחן ערוך"                                     "ספר הלכה מקיף שכתב יוסף קארו במאה השש עשרה."                                                                                                                                  }
    @{ id = "shir-hashirim";      title = "שיר השירים";                                            popularity = 90;  body = Short "שיר השירים"                                     "מגילה מקראית של אהבה בין דוד לרעיה."                                                                                                                                  }
    @{ id = "shemonah-esreh";     title = "שמונה עשרה";                                            popularity = 88;  body = Short "שמונה עשרה"                                     "תפילה מרכזית הנאמרת שלוש פעמים ביום."                                                                                                                                  }
    @{ id = "shemesh";            title = "שמש";                                                   popularity = 86;  body = Short "שמש"                                            "השמש היא הכוכב במרכז מערכת השמש שלנו."                                                                                                                                  }
    @{ id = "shlomo-hamelech";    title = "שלמה המלך";                                             popularity = 85;  body = Short "שלמה המלך"                                      "מלך ישראל הידוע בחכמתו ובבניית המקדש."                                                                                                                                  }
    @{ id = "shir-lashalom-long"; title = "שיר לשלום מאת חיים נחמן ביאליק ונועה קירל";              popularity = 84;  body = Short "שיר לשלום מאת חיים נחמן ביאליק ונועה קירל"     "השיר נכתב במקור על ידי יעקב רוטבליט. הכותרת בקטלוג היא דוגמת קצה לבדיקת גלישת שורות."                                                                                  }
    @{ id = "shmuel";             title = "שמואל";                                                 popularity = 82;  body = Short "שמואל"                                          "נביא ושופט אחרון בתקופת השופטים."                                                                                                                                  }
    @{ id = "shofar";             title = "שופר";                                                  popularity = 80;  body = Short "שופר"                                           "כלי נשיפה מקרני בעלי חיים, נשמע בראש השנה."                                                                                                                                  }
    @{ id = "shoftim";            title = "שופטים";                                                popularity = 78;  body = Short "שופטים"                                         "ספר מקראי המתאר את תקופת השופטים בישראל."                                                                                                                                  }
    @{ id = "shekhinah";          title = "שכינה";                                                 popularity = 76;  body = Short "שכינה"                                          "מושג קבלי לנוכחות אלוהית בעולם."                                                                                                                                  }
    @{ id = "shalom-aleichem";    title = "שלום עליכם";                                            popularity = 74;  body = Short "שלום עליכם"                                     "ברכה מסורתית הנאמרת בליל שבת."                                                                                                                                  }
    @{ id = "shamayim-vaaretz";   title = "שמיים וארץ";                                            popularity = 72;  body = Short "שמיים וארץ"                                     "ביטוי מקראי לכל היקום הנברא."                                                                                                                                  }
    @{ id = "shmirat-shabbat";    title = "שמירת שבת";                                             popularity = 70;  body = Short "שמירת שבת"                                      "ההלכה והמנהג של קדושת היום השביעי."                                                                                                                                  }
    @{ id = "shirat-hayam";       title = "שירת הים";                                              popularity = 68;  body = Short "שירת הים"                                       "שיר ההודיה לאחר קריעת ים סוף."                                                                                                                                  }
    @{ id = "shir-eretz";         title = "שיר ארץ ישראל";                                         popularity = 66;  body = Short "שיר ארץ ישראל"                                  "סוגה מוזיקלית מן המאה העשרים."                                                                                                                                  }
    @{ id = "shimon-bar-yochai";  title = "שמעון בר יוחאי";                                        popularity = 64;  body = Short "שמעון בר יוחאי"                                 "מקובל מן המאה השנייה לספירה."                                                                                                                                  }
    @{ id = "shemesh-bagilboa";   title = "שמש בגלבוע";                                            popularity = 62;  body = Short "שמש בגלבוע"                                     "פסוק קינה של דוד על שאול ויהונתן."                                                                                                                                  }
    @{ id = "sheleg";             title = "שלג";                                                   popularity = 60;  body = Short "שלג"                                            "משקעים מוצקים של גבישי קרח."                                                                                                                                  }
    @{ id = "shemen-zayit";       title = "שמן זית";                                               popularity = 58;  body = Short "שמן זית"                                        "שמן מסחיטת זיתים, מרכיב מרכזי במטבח."                                                                                                                                  }
    @{ id = "shaarei-tzedek";     title = "שערי צדק";                                              popularity = 56;  body = Short "שערי צדק"                                       "ביטוי מן הספרות העברית, גם שם של מוסד."                                                                                                                                  }
    @{ id = "shabbat-hamalka";    title = "שבת המלכה";                                             popularity = 54;  body = Short "שבת המלכה"                                      "כינוי פיוטי ליום השבת."                                                                                                                                  }
    @{ id = "shir-mishirei";      title = "שיר משירי דוד";                                         popularity = 52;  body = Short "שיר משירי דוד"                                  "פתיחה רגילה למזמורי תהילים."                                                                                                                                  }
    @{ id = "shulamit";           title = "שולמית";                                                popularity = 50;  body = Short "שולמית"                                         "דמות מן שיר השירים."                                                                                                                                  }
    @{ id = "shimshon";           title = "שמשון";                                                 popularity = 48;  body = Short "שמשון"                                          "אחד משופטי ישראל, הידוע בכוחו."                                                                                                                                  }
    @{ id = "sheh";               title = "שה";                                                    popularity = 46;  body = Short "שה"                                             "בעל חיים, צאן."                                                                                                                                  }
    @{ id = "shdema";             title = "שדמה";                                                  popularity = 44;  body = Short "שדמה"                                           "שדה זרוע, מן ספרי הנביאים."                                                                                                                                  }
    @{ id = "shas";               title = "ש`"ס";                                                  popularity = 45;  body = Short "ש`"ס"                                           "ראשי תיבות של שישה סדרים, ספרי המשנה והתלמוד."                                                                                                                                  }
    @{ id = "shabak";             title = "שב`"ק";                                                 popularity = 43;  body = Short "שב`"ק"                                          "ראשי תיבות של שבת קודש, כינוי קצר ליום השבת."                                                                                                                                  }
    @{ id = "shatz";              title = "ש`"ץ";                                                  popularity = 41;  body = Short "ש`"ץ"                                           "ראשי תיבות של שליח ציבור, המוביל את התפילה."                                                                                                                                  }
    @{ id = "shai-agnon";         title = "ש`"י-עגנון";                                            popularity = 39;  body = Short "ש`"י-עגנון"                                     "ראשי תיבות של שמואל יוסף, סופר ישראלי וחתן פרס נובל."                                                                                                                                  }
    @{ id = "shalom-bayit";       title = "שלום-בית";                                              popularity = 37;  body = Short "שלום-בית"                                       "ערך הרמוניה בין בני הזוג במשפחה היהודית."                                                                                                                                  }
    @{ id = "sh-aharon";          title = "ש'אהרון";                                               popularity = 35;  body = Short "ש'אהרון"                                        "ראשי תיבות של שמואל אהרון, דמות בספרות העברית."                                                                                                                                  }
)

# Write article bodies as UTF-8 WITHOUT BOM (Garmin CIQ string parser doesn't expect BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$totalBytes = 0
foreach ($a in $articles) {
    $path = Join-Path $artDir "$($a.id).txt"
    [System.IO.File]::WriteAllText($path, $a.body, $utf8NoBom)
    $bodyBytes = ([System.Text.Encoding]::UTF8.GetByteCount($a.body))
    $totalBytes += $bodyBytes
    Write-Host ("  wrote {0,-22} {1,5} B" -f $a.id, $bodyBytes)
}

# Build the manifest. Match the in-memory schema: { version, totalBytes, articles[] }
$manifest = [ordered]@{
    version    = 4
    totalBytes = $totalBytes
    articles   = $articles | ForEach-Object {
        [ordered]@{
            id         = $_.id
            title      = $_.title
            popularity = $_.popularity
        }
    }
}
$manifestJson = ConvertTo-Json $manifest -Depth 5
$manifestPath = Join-Path $out "manifest.json"
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)
Write-Host ""
Write-Host ("wrote manifest.json: {0} articles, totalBytes={1}" -f $articles.Count, $totalBytes)

# README for the upload destination
$readme = @"
# wikiwatch server static corpus

These files are the M7 server-side payload for `https://wikiwatch.tomhe.app/`.
Upload them so the paths match this layout:

- `wikiwatch.tomhe.app/manifest.json`
- `wikiwatch.tomhe.app/article/<id>.txt`  (36 files)

The Garmin watch app fetches these on first launch (and re-checks on every
launch via a 1-second background race). Content-Type matters:

- `manifest.json` -> `application/json` (or `text/plain; charset=utf-8`).
- `article/<id>.txt` -> `text/plain; charset=utf-8`.

**Do NOT serve `application/octet-stream`** — Garmin's BLE proxy rejects
it with RC=-400 (see project memory `reference_ciq_quirks.md`).

The TLS cert must be valid (Let's Encrypt or similar). Self-signed certs
will be rejected by the watch with RC=-1003.

Files were generated from `source/models/Fixtures.mc` at M6.5 via
`scripts/gen-server-corpus.ps1`. Re-run that script when the corpus
changes.

## Files

$($articles.Count) article bodies + 1 manifest = $($articles.Count + 1) total files.
Total payload: $totalBytes bytes of article body content + manifest overhead.
"@
[System.IO.File]::WriteAllText((Join-Path $out "README.md"), $readme, $utf8NoBom)
Write-Host "wrote README.md"
Write-Host ""
Write-Host "OK — server corpus generated under docs/server/"
