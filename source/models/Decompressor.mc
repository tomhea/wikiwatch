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
    // store. INCREMENTAL: the V=4096 fill loops are too many iterations for one
    // event handler (they trip the watchdog on-device), so parsing is sliced
    // across event-loop turns via parseStart/parseStep, exactly like decode.
    //
    // model.bin layout (FROZEN v1, big-endian; see gen_model.py):
    //   0..3  magic 'WWM1'        4..5  formatVersion=1   6..7  modelVersion
    //   8..9  V (token count)     10..11 maxCodeLen
    //   12..  codeLens[V] (1 byte each)
    //   then  per id: [tokenLen:1][tokenLen bytes]
    //
    // The state dict (which IS the finished model) keeps `mb` resident and records
    // each token's byte START offset in `mb`; the token's length is derived at
    // decode (the byte before the next token's start is that token's length byte).

    // Begin parsing: validate the header, allocate the tables, set phase 0.
    // Returns null if the magic/format is unrecognized (safe fallback). Cheap
    // (no fill loops) — the fills happen in parseStep.
    function parseStart(mb as ByteArray) as Dictionary? {
        if (mb.size() < 12) { return null; }
        // magic 'WWM1' = 0x57 0x57 0x4D 0x31
        if (!(mb[0] == 0x57 && mb[1] == 0x57 && mb[2] == 0x4D && mb[3] == 0x31)) {
            return null;
        }
        var formatVersion = (mb[4] << 8) | mb[5];
        if (formatVersion != 1) { return null; }
        var V          = (mb[8] << 8) | mb[9];
        var maxCodeLen = (mb[10] << 8) | mb[11];
        return {
            :modelVersion => (mb[6] << 8) | mb[7],
            :V            => V,
            :maxCodeLen   => maxCodeLen,
            :mb           => mb,
            :codeLens     => new [V],
            :tokenStart   => new [V],
            :order        => new [V],
            :countByLen   => new [maxCodeLen + 1],
            :firstIndex   => new [maxCodeLen + 1],
            :firstCode    => new [maxCodeLen + 1],
            :cursor       => new [maxCodeLen + 1],
            :phase        => 0,
            :i            => 0,
            :pos          => 12 + V          // read cursor for the tokenStart phase
        };
    }

    // Do up to ~budget items of the current parse phase. Returns true once the
    // model is fully built. Phases: 0 codeLens, 1 tokenStart, 2 countByLen,
    // 3 order, 4 done. The small per-length loops (firstIndex/firstCode, ~21
    // iterations) run at phase transitions.
    function parseStep(state as Dictionary, budget as Number) as Boolean {
        var phase      = state[:phase] as Number;
        var V          = state[:V] as Number;
        var maxCodeLen = state[:maxCodeLen] as Number;
        var i          = state[:i] as Number;
        var end        = i + budget;
        if (end > V) { end = V; }

        if (phase == 0) {                       // codeLens[i] = mb[12+i]
            var mb = state[:mb] as ByteArray;
            var codeLens = state[:codeLens] as Array;
            for (; i < end; i++) { codeLens[i] = mb[12 + i]; }
            state[:i] = i;
            if (i >= V) { state[:phase] = 1; state[:i] = 0; }
            return false;
        }
        if (phase == 1) {                       // tokenStart[i] (sequential pos)
            var mb = state[:mb] as ByteArray;
            var tokenStart = state[:tokenStart] as Array;
            var pos = state[:pos] as Number;
            for (; i < end; i++) {
                var tlen = mb[pos] as Number;
                pos++;
                tokenStart[i] = pos;
                pos += tlen;
            }
            state[:i] = i;
            state[:pos] = pos;
            if (i >= V) {
                state[:phase] = 2;
                state[:i] = 0;
                var cb = state[:countByLen] as Array;     // init counts (small)
                for (var L = 0; L <= maxCodeLen; L++) { cb[L] = 0; }
            }
            return false;
        }
        if (phase == 2) {                       // countByLen[codeLens[i]]++
            var codeLens = state[:codeLens] as Array;
            var cb = state[:countByLen] as Array;
            for (; i < end; i++) {
                var cl = codeLens[i] as Number;
                cb[cl] = (cb[cl] as Number) + 1;
            }
            state[:i] = i;
            if (i >= V) {
                state[:phase] = 3;
                state[:i] = 0;
                // firstIndex prefix sum + cursor seed (small per-length loops).
                var fi = state[:firstIndex] as Array;
                var cur = state[:cursor] as Array;
                var acc = 0;
                for (var L = 1; L <= maxCodeLen; L++) {
                    fi[L] = acc;
                    acc += cb[L] as Number;
                }
                for (var L = 0; L <= maxCodeLen; L++) { cur[L] = fi[L]; }
            }
            return false;
        }
        if (phase == 3) {                       // order = ids grouped by length
            var codeLens = state[:codeLens] as Array;
            var order = state[:order] as Array;
            var cur = state[:cursor] as Array;
            for (; i < end; i++) {
                var cl = codeLens[i] as Number;
                var c = cur[cl] as Number;
                order[c] = i;
                cur[cl] = c + 1;
            }
            state[:i] = i;
            if (i >= V) {
                state[:phase] = 4;
                state[:i] = 0;
                // first canonical code per length (small per-length loop).
                var cb = state[:countByLen] as Array;
                var fc = state[:firstCode] as Array;
                for (var L = 0; L <= maxCodeLen; L++) { fc[L] = 0; }
                var code = 0;
                var prevLen = 0;
                for (var L = 1; L <= maxCodeLen; L++) {
                    var cnt = cb[L] as Number;
                    if (cnt > 0) {
                        if (prevLen != 0) { code = (code + 1) << (L - prevLen); }
                        fc[L] = code;
                        code = code + (cnt - 1);
                        prevLen = L;
                    }
                }
            }
            return false;
        }
        return true;                            // phase 4 — fully parsed
    }

    // One-shot parse (tests + non-UI callers). The UI path uses parseStart +
    // parseStep across ticks to stay watchdog-safe. Returns null on bad header.
    function parseModel(mb as ByteArray) as Dictionary? {
        var st = parseStart(mb);
        if (st == null) { return null; }
        while (!parseStep(st, 1000000)) {}
        return st;
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
