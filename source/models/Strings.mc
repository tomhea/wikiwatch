import Toybox.Lang;

// Static strings used by the wikiwatch UI. Pure module: no side effects,
// imports only Toybox.Lang. Tested in source/tests/test_Strings.mc.
module Strings {
    // M1 placeholder Hebrew greeting; the production app shows search results
    // and article text, not a hardcoded greeting.
    function hello() as String {
        return "שלום";
    }
}