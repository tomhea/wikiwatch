import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// M7/M8 network layer — fetches the manifest + corpus chunks from
// wikiwatch.tomhe.app/ on first launch and on user-confirmed updates.
//
// Lives in source/net/ (not source/models/) because it imports
// Communications + System — R6 forbids those in source/models/.
//
// API surface:
//   parseManifestResponse(rc, data) -> {ok, manifest|error}     PURE, tested
//   _substituteChunkIndex / chunkUrl                             PURE, tested
//   fetchManifest(callback)                                      side-effecting
//   fetchChunk(pattern, n, callback)                             side-effecting
//
// Server contract (M8, see docs/m8-plan.md):
//   GET /manifest.json -> { version, totalBytes, chunkCount, chunkUriPattern,
//                           articles: [{id,title,popularity}] }
//                        Content-Type: application/json
//   GET /chunk/<N>.json -> { chunk: N, articles: { "<id>": "<body>", ... } }
//                          Content-Type: application/json  (install-time only)
//
// M8 removed the M7 per-article GET /article/<id>.txt endpoint — all body
// data now arrives packed in chunks during install + is unpacked into the
// same per-article Storage layout.
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
        // M9: articles[] is OPTIONAL (M9 manifests omit it; the index
        // arrives via fetchIndex). M8/M7 manifests still include it.
        var rawArts = data["articles"];
        var totalBytes = data["totalBytes"];
        if (totalBytes == null) { totalBytes = 0; }
        // M8: chunked-install fields.
        var chunkFields = _chunkFieldsFrom(data);
        var chunkCount = chunkFields[:chunkCount];
        var chunkUriPattern = chunkFields[:chunkUriPattern];
        // M9: index-part fields (stub values returned until real impl).
        var indexFields = _indexFieldsFrom(data);
        var indexCount = indexFields[:indexCount];
        var indexUriPattern = indexFields[:indexUriPattern];
        // Convert articles[] when present (M7/M8); produce empty list for M9.
        var symArts = [];
        if (rawArts instanceof Array) {
            var arts = rawArts as Array<Dictionary>;
            for (var i = 0; i < arts.size(); i++) {
                var a = arts[i] as Dictionary;
                symArts.add({
                    :id         => a["id"],
                    :title      => a["title"],
                    :popularity => a["popularity"]
                });
            }
        }
        return {
            :ok => true,
            :manifest => {
                :version          => version,
                :totalBytes       => totalBytes,
                :chunkCount       => chunkCount,
                :chunkUriPattern  => chunkUriPattern,
                :indexCount       => indexCount,
                :indexUriPattern  => indexUriPattern,
                :articles         => symArts
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

    // M8: extract the chunked-install fields from a manifest JSON dict,
    // defaulting for M7-era manifests that lack them (chunkCount=0 means "no
    // chunks"; the conventional pattern keeps the field a usable String).
    function _chunkFieldsFrom(data as Dictionary) as Dictionary {
        var chunkCount = data["chunkCount"];
        if (chunkCount == null) { chunkCount = 0; }
        var chunkUriPattern = data["chunkUriPattern"];
        if (chunkUriPattern == null) { chunkUriPattern = "/chunk/{n}.json"; }
        return { :chunkCount => chunkCount, :chunkUriPattern => chunkUriPattern };
    }

    // M8: pure URL builder. The manifest carries a `chunkUriPattern` like
    // "/chunk/{n}.json"; substitute {n} with the chunk index. Pure +
    // testable (no network). If the pattern lacks the {n} marker (malformed
    // manifest), fall back to appending the index.
    function _substituteChunkIndex(pattern as String, n as Number) as String {
        var marker = "{n}";
        var idx = pattern.find(marker);
        if (idx == null) {
            // Malformed pattern (no {n}) — fall back to appending the index.
            return pattern + n.toString();
        }
        var before = pattern.substring(0, idx) as String;
        var after = pattern.substring(idx + marker.length(), pattern.length()) as String;
        return before + n.toString() + after;
    }

    function chunkUrl(pattern as String, n as Number) as String {
        return BASE_URL + _substituteChunkIndex(pattern, n);
    }

    // M8: fire-and-forget chunk fetch (install-time only). Callback signature:
    //   callback.invoke(responseCode as Number, data as Dictionary?)
    // where data is the parsed chunk JSON { "chunk": N, "articles": {...} }.
    function fetchChunk(pattern as String, n as Number, callback as Lang.Method) as Void {
        var url = chunkUrl(pattern, n);
        System.println("M8 net: GET " + url);
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    // M9: extract index-part fields from a manifest JSON dict, defaulting for
    // M8-era manifests that lack them (indexCount=0 = "no index parts — use
    // articles[] from the manifest itself").
    function _indexFieldsFrom(data as Dictionary) as Dictionary {
        var indexCount = data["indexCount"];
        if (indexCount == null) { indexCount = 0; }
        var indexUriPattern = data["indexUriPattern"];
        if (indexUriPattern == null) { indexUriPattern = "/index/{n}.json"; }
        return { :indexCount => indexCount, :indexUriPattern => indexUriPattern };
    }

    // M9: pure index-part URL builder (mirrors _substituteChunkIndex /
    // chunkUrl). indexUrl("/index/{n}.json", 3) -> BASE_URL + "/index/3.json".
    function indexUrl(pattern as String, n as Number) as String {
        return BASE_URL + _substituteChunkIndex(pattern, n);
    }

    // M9: fire-and-forget index-part fetch. Callback signature:
    //   callback.invoke(responseCode as Number, data as Dictionary?)
    // where data is { "index": K, "articles": [{id,title,popularity},...] }.
    function fetchIndex(pattern as String, n as Number, callback as Lang.Method) as Void {
        var url = indexUrl(pattern, n);
        System.println("M9 net: GET " + url);
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }
}
