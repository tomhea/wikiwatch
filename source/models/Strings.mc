import Toybox.Lang;

// Static strings used by the wikiwatch UI. Pure module: no side effects,
// imports only Toybox.Lang. Tested in source/tests/test_Strings.mc.
module Strings {
    function hello() as String {
        return "שלום";
    }

    // M2 hardcoded sample article. Uses Markdown headers `#`..`####` for
    // section titles and plain text for body. M4 will replace this with
    // a real ArticleStore.
    function sampleArticle() as String {
        return "# שלום\n"
             + "שלום היא ברכה ופרידה.\n"
             + "## משמעות\n"
             + "המילה מופיעה בתנ\"ך פעמים רבות.\n"
             + "### דוגמאות\n"
             + "שאלו שלום ירושלים.\n"
             + "#### תפילה\n"
             + "עושה שלום במרומיו.\n"
             + "שורת גוף ארוכה שעוטפת לכמה שורות במסך העגול של השעון.";
    }
}