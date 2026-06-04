import Toybox.Lang;
import Toybox.StringUtil;

// M10.0 - pure byte-level-BPE + canonical-Huffman DECODER (candidate E2 from the
// compression bake-off; see scripts/m10-compress/RECOMMENDATION.md).
//
// The watch only ever DECODES. Encoding (BPE + Huffman training) is done
// server-side in scripts/m10-compress/gen_model.py, which also freezes the
// model.bin byte layout and the per-article blob format documented there. That
// reference encoder was verified byte-exact against a watch-mirror decoder over
// all 1200 corpus bodies, so this port is a faithful mirror of a proven decode.
//
// Pure: imports only Lang + StringUtil (encoding conversions, no I/O / no clocks /
// no Storage / no WatchUi), so it lives under models/ and is unit-testable. The
// freeMemory guards for the parse and the decode buffer live in the (impure)
// caller, CompModel (storage/) - matching the MemGuard/InstallPlan pattern where
// models hold the pure logic and the call site reads System freeMemory.
//
// Decode shape (no String concat - the O(N^2) OOM trap): 24-bit token count
// header -> canonical-Huffman bit-walk -> token id -> append that token's bytes to
// a ByteArray -> StringUtil.utf8ArrayToString ONCE at the end.
module Decompressor {

    // base64 String -> ByteArray.
    function b64ToBytes(s as String) as ByteArray {
        return StringUtil.convertEncodedString(s, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :toRepresentation   => StringUtil.REPRESENTATION_BYTE_ARRAY
        }) as ByteArray;
    }

    // UTF-8 ByteArray -> String (StringUtil.utf8ArrayToString wants Array<Number>;
    // convertEncodedString decodes a ByteArray of UTF-8 bytes directly, keeping the
    // memory-cheap ByteArray buffer instead of a boxed Array<Number>).
    function bytesToString(b as ByteArray) as String {
        return StringUtil.convertEncodedString(b, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation   => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :encoding           => StringUtil.CHAR_ENCODING_UTF8
        }) as String;
    }

    // base64-of-UTF8 -> String. Lets tests carry Hebrew expectations as base64
    // instead of raw Hebrew literals in source.
    function b64ToString(s as String) as String {
        return bytesToString(b64ToBytes(s));
    }

    // Parse model.bin into the canonical-Huffman decode tables. Pure. Returns null
    // if the magic/format is unrecognized (safe fallback - caller shows plain/err).
    //
    // model.bin layout (FROZEN v1, big-endian; see gen_model.py):
    //   0..3  magic 'WWM1'        4..5  formatVersion=1   6..7  modelVersion
    //   8..9  V (token count)     10..11 maxCodeLen
    //   12..  codeLens[V] (1 byte each)
    //   then  per id: [tokenLen:1][tokenLen bytes]
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

        var tokenBytes = new [V];
        for (var i = 0; i < V; i++) {
            var tlen = mb[pos] as Number;
            pos++;
            tokenBytes[i] = mb.slice(pos, pos + tlen);
            pos += tlen;
        }

        // --- canonical Huffman reconstruction from code lengths ---
        // count of symbols at each code length
        var countByLen = new [maxCodeLen + 1];
        for (var L = 0; L <= maxCodeLen; L++) { countByLen[L] = 0; }
        for (var i = 0; i < V; i++) {
            var cl = codeLens[i] as Number;
            countByLen[cl] = (countByLen[cl] as Number) + 1;
        }

        // start offset into `order` for each length (prefix sum in length order)
        var firstIndex = new [maxCodeLen + 1];
        var acc = 0;
        for (var L = 1; L <= maxCodeLen; L++) {
            firstIndex[L] = acc;
            acc += countByLen[L] as Number;
        }

        // order = token ids grouped by length, ascending id within a length
        // (the exact ordering the encoder's canonical assignment uses).
        var order = new [V];
        var cursor = new [maxCodeLen + 1];
        for (var L = 0; L <= maxCodeLen; L++) { cursor[L] = firstIndex[L]; }
        for (var i = 0; i < V; i++) {
            var cl = codeLens[i] as Number;
            var c = cursor[cl] as Number;
            order[c] = i;
            cursor[cl] = c + 1;
        }

        // first canonical code at each length
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
                code = code + (cnt - 1);   // last code at this length
                prevLen = L;
            }
        }

        return {
            :modelVersion => modelVersion,
            :V            => V,
            :maxCodeLen   => maxCodeLen,
            :tokenBytes   => tokenBytes,
            :order        => order,
            :firstCode    => firstCode,
            :firstIndex   => firstIndex,
            :countByLen   => countByLen
        };
    }

    // Decode one compressed article blob (the stored base64 -> ByteArray value)
    // into its UTF-8 String. Buffer-based, single utf8ArrayToString at the end.
    function decompress(blob as ByteArray, model as Dictionary) as String {
        var maxCodeLen = model[:maxCodeLen] as Number;
        var firstCode  = model[:firstCode] as Array;
        var firstIndex = model[:firstIndex] as Array;
        var countByLen = model[:countByLen] as Array;
        var order      = model[:order] as Array;
        var tokenBytes = model[:tokenBytes] as Array;

        // 24-bit big-endian token count, then MSB-first Huffman bitstream.
        var n = (blob[0] << 16) | (blob[1] << 8) | blob[2];
        var bitpos = 24;
        var out = []b;

        for (var t = 0; t < n; t++) {
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
                out.addAll(tokenBytes[sym] as ByteArray);
            }
        }
        return bytesToString(out);
    }
}
