import Toybox.Lang;
import Toybox.StringUtil;

// M10.0 - pure byte-level-BPE + canonical-Huffman DECODER (candidate E2 from the
// compression bake-off; see scripts/m10-compress/RECOMMENDATION.md).
//
// The watch only ever DECODES. Encoding (BPE + Huffman training) is done
// server-side in scripts/m10-compress/gen_model.py, which freezes the model.bin
// byte layout and the per-article blob format documented there. That reference
// encoder was verified byte-exact against a watch-mirror decoder over all 1200
// corpus bodies, so this port is a faithful mirror of a proven decode.
//
// Pure: imports only Lang + StringUtil (no I/O / clocks / Storage / WatchUi), so
// it lives under models/ and is unit-testable. The freeMemory guards live in the
// caller (CompModel, storage/), matching the MemGuard/InstallPlan pattern.
//
// M10.1: the parsed model is "flat" — the 36 KB model.bin (`mb`) is kept resident
// and tokens are referenced by offset (`tokenStart`) instead of materializing
// 4096 separate ByteArray objects (which cost ~273 KB resident + a slow parse,
// and tripped the watch watchdog/OOM on article-open). Decode is also INCREMENTAL
// (decodeStart/decodeStep/decodeText) so a long article can be decoded a slice
// per event-loop turn, keeping every handler under the watchdog budget.
//
// Decode shape (no String concat - the O(N^2) OOM trap): 24-bit token count
// header -> canonical-Huffman bit-walk -> token id -> append that token's bytes
// (a slice of mb) to a ByteArray -> StringUtil.convertEncodedString ONCE.
module Decompressor {

    // base64 String -> ByteArray.
    function b64ToBytes(s as String) as ByteArray {
        return StringUtil.convertEncodedString(s, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :toRepresentation   => StringUtil.REPRESENTATION_BYTE_ARRAY
        }) as ByteArray;
    }

    // UTF-8 ByteArray -> String (utf8ArrayToString wants Array<Number>;
    // convertEncodedString decodes a ByteArray of UTF-8 bytes directly).
    function bytesToString(b as ByteArray) as String {
        return StringUtil.convertEncodedString(b, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation   => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :encoding           => StringUtil.CHAR_ENCODING_UTF8
        }) as String;
    }

    // base64-of-UTF8 -> String. Lets tests carry Hebrew expectations as base64.
    function b64ToString(s as String) as String {
        return bytesToString(b64ToBytes(s));
    }

    // Parse model.bin into the canonical-Huffman decode tables + a flat token
    // store. Pure. Returns null if the magic/format is unrecognized.
    //
    // model.bin layout (FROZEN v1, big-endian; see gen_model.py):
    //   0..3  magic 'WWM1'        4..5  formatVersion=1   6..7  modelVersion
    //   8..9  V (token count)     10..11 maxCodeLen
    //   12..  codeLens[V] (1 byte each)
    //   then  per id: [tokenLen:1][tokenLen bytes]
    //
    // The returned dict keeps `mb` (the whole model.bin) resident and records each
    // token's byte START offset in `mb`; the token's length is derived at decode
    // (the byte before the next token's start is that token's length byte).
    function parseModel(mb as ByteArray) as Dictionary? {
        if (mb.size() < 12) { return null; }
        // magic 'WWM1' = 0x57 0x57 0x4D 0x31
        if (!(mb[0] == 0x57 && mb[1] == 0x57 && mb[2] == 0x4D && mb[3] == 0x31)) {
            return null;
        }
        var formatVersion = (mb[4] << 8) | mb[5];
        if (formatVersion != 1) { return null; }
        var modelVersion = (mb[6] << 8) | mb[7];
        var V            = (mb[8] << 8) | mb[9];
        var maxCodeLen   = (mb[10] << 8) | mb[11];

        var pos = 12;
        var codeLens = new [V];
        for (var i = 0; i < V; i++) {
            codeLens[i] = mb[pos + i];
        }
        pos += V;

        // Record each token's byte-start offset in mb (no per-token allocation).
        var tokenStart = new [V];
        for (var i = 0; i < V; i++) {
            var tlen = mb[pos] as Number;   // length byte
            pos++;
            tokenStart[i] = pos;            // bytes start right after the length
            pos += tlen;
        }

        // --- canonical Huffman reconstruction from code lengths ---
        var countByLen = new [maxCodeLen + 1];
        for (var L = 0; L <= maxCodeLen; L++) { countByLen[L] = 0; }
        for (var i = 0; i < V; i++) {
            var cl = codeLens[i] as Number;
            countByLen[cl] = (countByLen[cl] as Number) + 1;
        }

        var firstIndex = new [maxCodeLen + 1];
        var acc = 0;
        for (var L = 1; L <= maxCodeLen; L++) {
            firstIndex[L] = acc;
            acc += countByLen[L] as Number;
        }

        // order = token ids grouped by length, ascending id within a length.
        var order = new [V];
        var cursor = new [maxCodeLen + 1];
        for (var L = 0; L <= maxCodeLen; L++) { cursor[L] = firstIndex[L]; }
        for (var i = 0; i < V; i++) {
            var cl = codeLens[i] as Number;
            var c = cursor[cl] as Number;
            order[c] = i;
            cursor[cl] = c + 1;
        }

        var firstCode = new [maxCodeLen + 1];
        for (var L = 0; L <= maxCodeLen; L++) { firstCode[L] = 0; }
        var code = 0;
        var prevLen = 0;
        for (var L = 1; L <= maxCodeLen; L++) {
            var cnt = countByLen[L] as Number;
            if (cnt > 0) {
                if (prevLen != 0) {
                    code = (code + 1) << (L - prevLen);
                }
                firstCode[L] = code;
                code = code + (cnt - 1);
                prevLen = L;
            }
        }

        return {
            :modelVersion => modelVersion,
            :V            => V,
            :maxCodeLen   => maxCodeLen,
            :mb           => mb,           // model.bin kept resident (token bytes)
            :tokenStart   => tokenStart,   // per-token byte offset into mb
            :order        => order,
            :firstCode    => firstCode,
            :firstIndex   => firstIndex,
            :countByLen   => countByLen
        };
    }

    // ---- incremental decode (so a long article decodes a slice per turn) ----

    // Start decoding a blob: read the 24-bit token count, return mutable state.
    function decodeStart(blob as ByteArray) as Dictionary {
        var n = (blob[0] << 16) | (blob[1] << 8) | blob[2];
        return { :blob => blob, :n => n, :t => 0, :bitpos => 24, :out => []b };
    }

    function decodeTokenCount(state as Dictionary) as Number { return state[:n] as Number; }
    function decodeTokensDone(state as Dictionary) as Number { return state[:t] as Number; }

    // Decode up to maxTokens more tokens into state[:out]. Returns true once all
    // n tokens are done. O(maxTokens) work — the caller bounds the per-turn cost.
    function decodeStep(state as Dictionary, model as Dictionary, maxTokens as Number) as Boolean {
        var blob       = state[:blob] as ByteArray;
        var out        = state[:out] as ByteArray;
        var bitpos     = state[:bitpos] as Number;
        var t          = state[:t] as Number;
        var n          = state[:n] as Number;
        var maxCodeLen = model[:maxCodeLen] as Number;
        var firstCode  = model[:firstCode] as Array;
        var firstIndex = model[:firstIndex] as Array;
        var countByLen = model[:countByLen] as Array;
        var order      = model[:order] as Array;
        var mb         = model[:mb] as ByteArray;
        var tokenStart = model[:tokenStart] as Array;
        var V          = model[:V] as Number;
        var mbSize     = mb.size();

        var limit = t + maxTokens;
        if (limit > n) { limit = n; }

        while (t < limit) {
            var code = 0;
            var ln = 0;
            var sym = 0;
            var found = false;
            while (ln < maxCodeLen) {
                var bit = (blob[bitpos >> 3] >> (7 - (bitpos & 7))) & 1;
                bitpos++;
                code = (code << 1) | bit;
                ln++;
                var cnt = countByLen[ln] as Number;
                if (cnt > 0) {
                    var offset = code - (firstCode[ln] as Number);
                    if (offset >= 0 && offset < cnt) {
                        sym = order[(firstIndex[ln] as Number) + offset] as Number;
                        found = true;
                        break;
                    }
                }
            }
            if (found) {
                var s = tokenStart[sym] as Number;
                // token length = (next token's start - 1) - s, or to mb end for the last id.
                var e = (sym < V - 1) ? (tokenStart[sym + 1] as Number) - 1 : mbSize;
                out.addAll(mb.slice(s, e));
            }
            t++;
        }
        state[:bitpos] = bitpos;
        state[:t] = t;
        return t >= n;
    }

    // Finished decoded text (call once decodeStep returns true).
    function decodeText(state as Dictionary) as String {
        return bytesToString(state[:out] as ByteArray);
    }

    // One-shot decode (tests + small/non-UI callers). For the UI read path the
    // article-open flow uses the incremental API above to stay watchdog-safe.
    function decompress(blob as ByteArray, model as Dictionary) as String {
        var st = decodeStart(blob);
        decodeStep(st, model, st[:n] as Number);
        return decodeText(st);
    }
}
