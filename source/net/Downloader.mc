import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// M7 network layer — fetches the manifest + per-article bodies from
// wikiwatch.tomhe.app/ on first launch and on user-confirmed updates.
//
// Lives in source/net/ (not source/models/) because it imports
// Communications + System — R6 forbids those in source/models/.
//
// API surface:
//   parseManifestResponse(rc, data) -> {ok, manifest|error}     PURE, tested
//   fetchManifest(callback)                                      side-effecting
//   fetchArticle(id, callback)                                   side-effecting
//
// Server contract (see docs/m7-plan.md):
//   GET /manifest.json -> { version, totalBytes, articles: [{id,title,popularity}] }
//                        Content-Type: application/json
//   GET /article/<id>.txt -> UTF-8 Hebrew Markdown body
//                            Content-Type: text/plain; charset=utf-8
//
// Sim caveat: BLE proxy returns RC=-300/-400 for most endpoints when no
// phone is paired. Real-watch sideload is the truth source for R2.
module Downloader {
    const BASE_URL = "https://wikiwatch.tomhe.app";

    // M7.1: connectivity probe. Skip the manifest fetch entirely if no
    // network connection is up. Specifically guards against the USB-
    // connected-sideload scenario where BLE is deprioritized + requests
    // hang for ~30s, clogging CIQ's event loop (the actual root cause
    // of the M6.4-style stale-render symptom we kept hitting on the
    // watch after every M7-flavor change).
    //
    // Pure helper — takes the relevant DeviceSettings fields, returns
    // true if any network connection is up.
    //   connectionInfo: CIQ-3.3+ dict keyed by CONNECTION_PHONE /
    //                   CONNECTION_WIFI / CONNECTION_LTE. Each value
    //                   has a `state` property. null on older watches.
    //   phoneConnected: pre-3.3 fallback for BLE-only check.
    function _anyConnected(connectionInfo as Dictionary?, phoneConnected as Boolean) as Boolean {
        if (connectionInfo != null) {
            var keys = connectionInfo.keys();
            for (var i = 0; i < keys.size(); i++) {
                var info = connectionInfo[keys[i]];
                if (info != null && info.state == System.CONNECTION_STATE_CONNECTED) {
                    return true;
                }
            }
            return false;
        }
        return phoneConnected;
    }

    function isNetworkAvailable() as Boolean {
        var s = System.getDeviceSettings();
        var ci = (s has :connectionInfo) ? s.connectionInfo : null;
        return _anyConnected(ci, s.phoneConnected);
    }

    // Pure parser. Validates rc + dict shape. Converts the JSON String-keyed
    // shape ({"version", "articles": [{"id", ...}]}) into the in-memory
    // Symbol-keyed shape (:version, :articles => [{:id, ...}]) used across
    // the rest of the codebase (Manifest, Search, KeyboardDelegate). This is
    // the single boundary between "raw server JSON" and "app data model".
    //
    // Returns:
    //   {:ok => true,  :manifest => Dictionary}  on success
    //   {:ok => false, :error => String}         on failure
    function parseManifestResponse(rc as Number, data as Dictionary?) as Dictionary {
        if (rc != 200) {
            return { :ok => false, :error => "http rc=" + rc };
        }
        if (data == null) {
            return { :ok => false, :error => "null response data" };
        }
        var version = data["version"];
        if (version == null || !(version instanceof Number)) {
            return { :ok => false, :error => "missing or non-number version" };
        }
        var rawArts = data["articles"];
        if (rawArts == null || !(rawArts instanceof Array)) {
            return { :ok => false, :error => "missing or non-array articles" };
        }
        var totalBytes = data["totalBytes"];
        if (totalBytes == null) { totalBytes = 0; }
        // Convert each article entry from String-keyed to Symbol-keyed.
        var arts = rawArts as Array<Dictionary>;
        var symArts = [];
        for (var i = 0; i < arts.size(); i++) {
            var a = arts[i] as Dictionary;
            symArts.add({
                :id         => a["id"],
                :title      => a["title"],
                :popularity => a["popularity"]
            });
        }
        return {
            :ok => true,
            :manifest => {
                :version    => version,
                :totalBytes => totalBytes,
                :articles   => symArts
            }
        };
    }

    // Fire-and-forget manifest fetch. Callback signature (per CIQ):
    //   callback.invoke(responseCode as Number, data as Dictionary?)
    // The caller (UpdateCheckView / InstallView) hands the result to
    // parseManifestResponse to get the canonical Symbol-keyed dict.
    function fetchManifest(callback as Lang.Method) as Void {
        System.println("M7 net: GET " + BASE_URL + "/manifest.json");
        Communications.makeWebRequest(
            BASE_URL + "/manifest.json",
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    // Fire-and-forget per-article fetch. Callback signature:
    //   callback.invoke(responseCode as Number, body as String?)
    function fetchArticle(id as String, callback as Lang.Method) as Void {
        var url = BASE_URL + "/article/" + id + ".txt";
        System.println("M7 net: GET " + url);
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            callback
        );
    }
}
