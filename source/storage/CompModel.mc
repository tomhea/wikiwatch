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

    // Minimum free heap to begin building the model / the decode output buffer
    // (R5). Public so DecodeView (which drives the incremental parse + decode)
    // can apply the same guards the synchronous decompress()/decodeBody() do.
    const MIN_FREE_PARSE = _MIN_FREE_PARSE;
    const MIN_FREE_DECODE = _MIN_FREE_DECODE;

    var _model as Dictionary? = null;
    // M10.3: the SINGLE in-progress sliced-parse state, shared by every driver of
    // the incremental parse (the eager ModelWarmer at keyboard-idle AND the
    // DecodeView open-gate). Sharing one state means they never double-parse or
    // double the ~137 KB allocation if the user opens an article mid-warm.
    var _parseState as Dictionary? = null;
    var _parseFailed as Boolean = false;   // model resource unreadable — don't retry

    // The cached parsed model, or null if it hasn't been built yet. Does NOT
    // build it — the incremental UI path (DecodeView) builds it across ticks and
    // hands it back via cacheModel().
    function cachedModel() as Dictionary? {
        return _model;
    }

    // Store a model parsed elsewhere (the incremental DecodeView path) so future
    // article opens reuse it instead of re-parsing.
    function cacheModel(m as Dictionary) as Void {
        _model = m;
    }

    // M10.3: advance the ONE shared sliced parse by up to `items` table-fills,
    // returning a status:
    //   :done       — model fully parsed + cached (or already was). Stop slicing.
    //   :more       — progress made; call again next tick.
    //   :lowmem     — not enough free heap to begin the parse (R5 guard); caller
    //                 should stop and retry later (memory may free up).
    //   :unreadable — the baked model resource is malformed; never retry.
    // Both the eager warmer and the open-gate drive THIS, so whoever finishes
    // first caches the model and the other immediately sees :done.
    function parseSlice(items as Number) as Symbol {
        if (_model != null) { return :done; }
        if (_parseFailed) { return :unreadable; }
        if (_parseState == null) {
            if (System.getSystemStats().freeMemory < _MIN_FREE_PARSE) {
                return :lowmem;              // R5: refuse the parse allocation
            }
            _parseState = Decompressor.parseStart(rawModelBytes());
            if (_parseState == null) {
                _parseFailed = true;
                return :unreadable;          // bad magic / format — safe fallback
            }
        }
        if (Decompressor.parseStep(_parseState as Dictionary, items)) {
            _model = _parseState;            // promote the finished state to the cache
            _parseState = null;
            return :done;
        }
        return :more;
    }

    // M10.3: true iff the persisted corpus is compressed AND this binary can decode
    // it (so the eager warmer only parses the model when it will actually be used —
    // a plain corpus never needs it). Mirrors the ArticleOpener routing condition.
    function corpusNeedsModel() as Boolean {
        var man = Manifest.load();
        var codec = man[:bodyCodec] as String?;
        if (codec == null || codec.equals(BodyCodec.PLAIN)) { return false; }
        return BodyCodec.readAction(codec, man[:modelVersion] as Number?, bakedVersion()) == :decompress;
    }

    // The raw model.bin bytes from the baked resource (loadResource + base64
    // decode — both native, watchdog-safe). The expensive table fills happen in
    // Decompressor.parseStep, sliced across ticks.
    function rawModelBytes() as ByteArray {
        var res = WatchUi.loadResource($.Rez.JsonData.compModel) as Dictionary;
        return Decompressor.b64ToBytes(res["b64"] as String);
    }

    // Parsed model (cached), built one-shot. Used by tests + the synchronous
    // decodeBody path. The UI path uses cachedModel()/rawModelBytes() + the
    // incremental parse instead (one-shot parse trips the watchdog on-device).
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
        return Decompressor.parseModel(rawModelBytes());
    }

    // modelVersion baked into the .prg. M10.1's read path requires the served
    // manifest's modelVersion to equal this before it will decompress a corpus.
    function bakedVersion() as Number {
        var res = WatchUi.loadResource($.Rez.JsonData.compModel) as Dictionary;
        return res["v"] as Number;
    }

    // Guarded production-style decode of one article blob. Returns the decoded
    // String, or null if the model is unavailable or free heap is too low for the
    // output buffer (R5). M10.1's article-open path calls this via decodeBody.
    function decompress(blob as ByteArray) as String? {
        var m = model();
        if (m == null) { return null; }
        if (System.getSystemStats().freeMemory < _MIN_FREE_DECODE) {
            return null;                     // R5: refuse the output-buffer alloc
        }
        return Decompressor.decompress(blob, m);
    }

    // M10.1 read-path entry: turn a stored body String into displayable text per
    // the persisted manifest's bodyCodec/modelVersion (see BodyCodec.readAction).
    //   plain corpus / pre-M10.1  -> the stored String verbatim (no model touch)
    //   bpe-huff-1 + version match -> BPE+Huffman decode (base64 -> ByteArray -> text)
    //   compressed but mismatch    -> null (caller must NOT open; never shows garbage)
    // Returns null if free heap is too low to decode (R5) — caller treats a null
    // body as "don't open", exactly as it already handles a missing body.
    function decodeBody(stored as String) as String? {
        var man = Manifest.load();
        var codec = man[:bodyCodec] as String?;
        // Fast path: plain corpus never loads/parses the baked model.
        if (codec == null || codec.equals(BodyCodec.PLAIN)) {
            return stored;
        }
        var action = BodyCodec.readAction(codec, man[:modelVersion] as Number?, bakedVersion());
        if (action == :decompress) {
            return decompress(Decompressor.b64ToBytes(stored));
        }
        return null;   // :unavailable — compressed corpus this binary can't decode
    }
}
