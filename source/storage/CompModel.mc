import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

// M10.0: loads the baked compression model (resources/jsonData/model.json =
// {"v":<modelVersion>,"b64":base64(model.bin)}) once, parses it into the
// Decompressor decode tables, and caches it module-level. Decode itself is the
// pure Decompressor (models/); this wrapper is impure (WatchUi.loadResource +
// System freeMemory) so it lives under storage/.
//
// The decoder is NOT wired into the read path in M10.0 - the app behaves exactly
// as today. M10.1 wires CompModel.decompress() into the article-open path behind
// the manifest bodyCodec/modelVersion check.
//
// Model/corpus coupling: the model is baked into the .prg, so retraining the
// server corpus requires an app rebuild + re-tag (M10.1 adds the manifest
// modelVersion match so a mismatched corpus falls back safely instead of decoding
// to garbage).
module CompModel {
    // Parsing allocates ~36 KB of token bytes + parallel index arrays, with a
    // transient ~48 KB base64 string + ~36 KB byte buffer during load - a few
    // hundred KB peak. Refuse the parse under this much free heap (R5). The parse
    // is only triggered at article-open (M10.1), behind this guard.
    const _MIN_FREE_PARSE = 400 * 1024;     // 409600

    // One decoded article output buffer peaks at the per-article cap (~14 KB) plus
    // a transient String of the same order. Guard the decode buffer alloc (R5).
    const _MIN_FREE_DECODE = 96 * 1024;     // 98304

    var _model as Dictionary? = null;

    // Parsed model (cached). null if the resource is unreadable, the format is
    // unrecognized, or free heap is too low to parse safely.
    function model() as Dictionary? {
        if (_model == null) {
            _model = _load();
        }
        return _model;
    }

    function _load() as Dictionary? {
        if (System.getSystemStats().freeMemory < _MIN_FREE_PARSE) {
            return null;                     // R5: refuse the parse allocation
        }
        var res = WatchUi.loadResource($.Rez.JsonData.compModel) as Dictionary;
        var b64 = res["b64"] as String;
        var bytes = Decompressor.b64ToBytes(b64);
        return Decompressor.parseModel(bytes);
    }

    // modelVersion baked into the .prg. M10.1's read path requires the served
    // manifest's modelVersion to equal this before it will decompress a corpus.
    function bakedVersion() as Number {
        var res = WatchUi.loadResource($.Rez.JsonData.compModel) as Dictionary;
        return res["v"] as Number;
    }

    // Guarded production-style decode of one article blob. Returns the decoded
    // String, or null if the model is unavailable or free heap is too low for the
    // output buffer (R5). M10.1's article-open path calls this.
    function decompress(blob as ByteArray) as String? {
        var m = model();
        if (m == null) { return null; }
        if (System.getSystemStats().freeMemory < _MIN_FREE_DECODE) {
            return null;                     // R5: refuse the output-buffer alloc
        }
        return Decompressor.decompress(blob, m);
    }
}
