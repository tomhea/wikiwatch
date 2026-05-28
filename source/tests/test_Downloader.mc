import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// M7 tests for Downloader.parseManifestResponse.
//
// This is the only pure-testable seam in the network module. The actual
// HTTP calls (fetchManifest / fetchArticle / installAll) aren't unit-
// testable — they're verified via R2 sim launch + real-watch sideload.

(:test)
function downloader_parseManifestSuccess(logger as Logger) as Boolean {
    var data = {
        "version" => 4,
        "totalBytes" => 6615,
        "articles" => [
            { "id" => "shalom", "title" => "שלום", "popularity" => 100 },
            { "id" => "shabbat", "title" => "שבת", "popularity" => 99 }
        ]
    };
    var r = Downloader.parseManifestResponse(200, data);
    logger.debug("parse 200 + valid -> ok=" + r[:ok]);
    if (r[:ok] != true) { return false; }
    var m = r[:manifest] as Dictionary;
    return (m[:version] as Number) == 4
        && (m[:totalBytes] as Number) == 6615
        && (m[:articles] as Array).size() == 2;
}

(:test)
function downloader_parseManifestRejectsBadRc(logger as Logger) as Boolean {
    var r = Downloader.parseManifestResponse(404, null);
    logger.debug("parse 404 -> ok=" + r[:ok] + " error=" + r[:error]);
    return r[:ok] == false;
}

(:test)
function downloader_parseManifestRejectsNullData(logger as Logger) as Boolean {
    var r = Downloader.parseManifestResponse(200, null);
    logger.debug("parse 200 + null -> ok=" + r[:ok]);
    return r[:ok] == false;
}

(:test)
function downloader_parseManifestRejectsMissingVersion(logger as Logger) as Boolean {
    var data = { "articles" => [] };  // no version
    var r = Downloader.parseManifestResponse(200, data);
    logger.debug("parse 200 + no-version -> ok=" + r[:ok]);
    return r[:ok] == false;
}

(:test)
function downloader_parseManifestRejectsMissingArticles(logger as Logger) as Boolean {
    var data = { "version" => 4 };  // no articles
    var r = Downloader.parseManifestResponse(200, data);
    logger.debug("parse 200 + no-articles -> ok=" + r[:ok]);
    return r[:ok] == false;
}

(:test)
function downloader_parseManifestNormalizesKeys(logger as Logger) as Boolean {
    // JSON response uses String keys ("version", "articles"); the in-memory
    // schema across the rest of the codebase uses Symbol keys (:version,
    // :articles). parseManifestResponse converts at the boundary so
    // downstream code (Manifest.save, KeyboardDelegate._articles loading)
    // never sees the String-keyed form.
    var data = {
        "version" => 5,
        "totalBytes" => 100,
        "articles" => [
            { "id" => "x", "title" => "X", "popularity" => 50 }
        ]
    };
    var r = Downloader.parseManifestResponse(200, data);
    if (r[:ok] != true) { return false; }
    var m = r[:manifest] as Dictionary;
    var arts = m[:articles] as Array;
    if (arts.size() != 1) { return false; }
    var a = arts[0] as Dictionary;
    // Symbol-keyed lookups should work; String-keyed should return null.
    logger.debug("symbol id=" + a[:id] + " title=" + a[:title]
        + " string id=" + a["id"]);
    return ((a[:id] as String).equals("x"))
        && ((a[:title] as String).equals("X"))
        && ((a[:popularity] as Number) == 50);
}


// --- M7.1: connectivity probe ---

class FakeConnInfo {
    var state as Number;
    function initialize(s as Number) { state = s; }
}

(:test)
function downloader_anyConnectedFallsBackToPhoneOnly(logger as Logger) as Boolean {
    // Pre-CIQ-3.3 watches: no connectionInfo, just phoneConnected.
    // _anyConnected should fall back to the bool.
    var a = Downloader._anyConnected(null, true);
    var b = Downloader._anyConnected(null, false);
    logger.debug("null+true=" + a + " null+false=" + b);
    return a == true && b == false;
}

(:test)
function downloader_anyConnectedDetectsConnected(logger as Logger) as Boolean {
    // CIQ 3.3+: connectionInfo is a dict keyed by connection type
    // (CONNECTION_PHONE, CONNECTION_WIFI, CONNECTION_LTE). If ANY is
    // in CONNECTED state, we have network.
    var ci = { :phone => new FakeConnInfo(Toybox.System.CONNECTION_STATE_CONNECTED) };
    var r = Downloader._anyConnected(ci, false);
    logger.debug("phone-connected-only -> " + r);
    return r == true;
}

(:test)
function downloader_anyConnectedAllDisconnectedReturnsFalse(logger as Logger) as Boolean {
    var ci = {
        :phone => new FakeConnInfo(Toybox.System.CONNECTION_STATE_NOT_CONNECTED),
        :wifi  => new FakeConnInfo(Toybox.System.CONNECTION_STATE_NOT_INITIALIZED)
    };
    var r = Downloader._anyConnected(ci, false);
    logger.debug("all-disconnected -> " + r);
    return r == false;
}
