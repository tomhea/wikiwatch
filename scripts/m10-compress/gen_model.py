#!/usr/bin/env python3
"""M10.0 - generate the baked compression model + golden test vectors.

Trains byte-level BPE (vocab 4096) + canonical Huffman over token ids on the
shippable top-N corpus -- this is candidate **E2** from the bake-off
(`RECOMMENDATION.md`). The watch only ever *decodes*; this script holds the
encoder side. Outputs:

  - resources/jsonData/model.json  : {"v": <modelVersion>, "b64": base64(model.bin)}
    (baked into the .prg; loaded once on the watch, parsed into the decode tables)
  - scripts/m10-compress/golden.json : the PC record of the sample vectors
  - scripts/m10-compress/golden_tests.mc.txt : ready-to-paste (:test) functions

It also *self-verifies* with a pure-Python "watch-mirror" decoder that parses
model.bin exactly the way the Monkey C `Decompressor` will, so the frozen byte
layout and the decode algorithm are proven correct here before the port.

=====================================================================
model.bin layout (FROZEN -- v1).  All multi-byte integers BIG-ENDIAN.
=====================================================================
  off  size      field
  0    4         magic = 'W','W','M','1'  (0x57 0x57 0x4D 0x31)
  4    2 (u16)   formatVersion = 1        (bump only if this layout changes)
  6    2 (u16)   modelVersion             (corpus/model identity; M10.1 manifest must match)
  8    2 (u16)   V = number of tokens     (<= 65535)
  10   2 (u16)   maxCodeLen               (max Huffman code length, in bits; <= 30)
  12   V         codeLens[i]              (1 byte each: Huffman code length of token id i, 1..maxCodeLen)
  12+V ...       token->bytes table: for i in 0..V-1:  [tokenLen_i : 1 byte][tokenLen_i raw bytes]

Compressed per-article blob (what is base64'd into each corpus value) -- this is
exactly `algos.bpeE2_compress`:
  - 24-bit BIG-ENDIAN token count `n` (MSB first)
  - then `n` canonical-Huffman codes over token ids, packed MSB-first
  - final partial byte left-aligned (low bits zero-padded)

Canonical Huffman: symbols (= token ids) are ordered by (codeLen, id); the first
code of the shortest length is 0; moving to the next symbol does code=(code+1),
and on a length increase the code is left-shifted by the length delta. The watch
reconstructs this from codeLens alone -- identical ordering -> identical codes.
"""
import argparse
import base64
import json
import os
import struct

import algos
import corpus

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

MAGIC = b"WWM1"
FORMAT_VERSION = 1


# --------------------------------------------------------------------------
# Build model.bin from a trained E2 model.
# --------------------------------------------------------------------------
def build_model_bin(model, model_version):
    V = model["V"]
    id_to_bytes = model["id_to_bytes"]
    lengths = model["lengths"]

    # ids must be a contiguous 0..V-1 range (BPE assigns them so).
    assert set(id_to_bytes.keys()) == set(range(V)), "token ids not contiguous 0..V-1"
    assert set(lengths.keys()) == set(range(V)), "code-length table missing ids"
    assert V <= 0xFFFF, "V exceeds u16 (%d)" % V

    max_code_len = max(lengths.values())
    assert max_code_len <= 30, "maxCodeLen %d > 30 (would overflow 32-bit codes)" % max_code_len

    max_tok_len = max(len(b) for b in id_to_bytes.values())
    assert max_tok_len <= 0xFF, "token byte length %d > 255 (needs 2-byte len field)" % max_tok_len

    out = bytearray()
    out += MAGIC
    out += struct.pack(">H", FORMAT_VERSION)
    out += struct.pack(">H", model_version)
    out += struct.pack(">H", V)
    out += struct.pack(">H", max_code_len)
    # code-length table (1 byte per token id, id order)
    for i in range(V):
        cl = lengths[i]
        assert 1 <= cl <= max_code_len
        out.append(cl)
    # token->bytes table (id order): [len][bytes]
    for i in range(V):
        b = id_to_bytes[i]
        out.append(len(b))
        out += b
    return bytes(out)


# --------------------------------------------------------------------------
# Pure-Python "watch-mirror" decoder: parse model.bin and decode a blob the
# EXACT way the Monkey C Decompressor will. If this matches the bodies, the
# frozen layout + the decode algorithm are correct.
# --------------------------------------------------------------------------
def parse_model_bin(mb):
    assert mb[0:4] == MAGIC, "bad magic"
    fmt = struct.unpack_from(">H", mb, 4)[0]
    model_version = struct.unpack_from(">H", mb, 6)[0]
    V = struct.unpack_from(">H", mb, 8)[0]
    max_code_len = struct.unpack_from(">H", mb, 10)[0]
    assert fmt == FORMAT_VERSION, "format version mismatch"

    pos = 12
    code_lens = list(mb[pos:pos + V])
    pos += V
    token_bytes = []
    for _ in range(V):
        ln = mb[pos]; pos += 1
        token_bytes.append(mb[pos:pos + ln]); pos += ln
    assert pos == len(mb), "trailing bytes in model.bin (%d != %d)" % (pos, len(mb))

    # Reconstruct the canonical decode table from code lengths.
    # Order symbols by (length, id) -- the SAME order the encoder used.
    order = sorted(range(V), key=lambda i: (code_lens[i], i))
    first_code_by_len = {}     # len -> first canonical code at that length
    first_index_by_len = {}    # len -> index into `order` where that length starts
    count_by_len = {}          # len -> how many symbols have that length
    code = 0
    prev_len = None
    for idx, sym in enumerate(order):
        ln = code_lens[sym]
        if prev_len is not None:
            code = (code + 1) << (ln - prev_len)
        if ln not in first_code_by_len:
            first_code_by_len[ln] = code
            first_index_by_len[ln] = idx
            count_by_len[ln] = 0
        count_by_len[ln] += 1
        prev_len = ln
    return {
        "modelVersion": model_version,
        "V": V,
        "maxCodeLen": max_code_len,
        "tokenBytes": token_bytes,
        "order": order,
        "firstCodeByLen": first_code_by_len,
        "firstIndexByLen": first_index_by_len,
        "countByLen": count_by_len,
    }


def _bit_at(blob, bitpos):
    return (blob[bitpos >> 3] >> (7 - (bitpos & 7))) & 1


def decode_with_parsed(parsed, blob):
    """Mirror of the Monkey C decode: 24-bit n header, canonical bit-walk,
    append token bytes, single utf8 decode at the end."""
    n = (blob[0] << 16) | (blob[1] << 8) | blob[2]
    bitpos = 24
    order = parsed["order"]
    first_code = parsed["firstCodeByLen"]
    first_index = parsed["firstIndexByLen"]
    count = parsed["countByLen"]
    max_len = parsed["maxCodeLen"]
    token_bytes = parsed["tokenBytes"]

    out = bytearray()
    for _ in range(n):
        code = 0
        ln = 0
        sym = None
        while ln < max_len:
            code = (code << 1) | _bit_at(blob, bitpos)
            bitpos += 1
            ln += 1
            if ln in first_code:
                offset = code - first_code[ln]
                if 0 <= offset < count[ln]:
                    sym = order[first_index[ln] + offset]
                    break
        if sym is None:
            raise ValueError("bad huffman stream")
        out += token_bytes[sym]
    return bytes(out)


# --------------------------------------------------------------------------
def pick_golden_ids(bodies):
    """Spread of sizes: smallest, a few percentiles, and the largest."""
    sizes = [(len(b.encode("utf-8")), i) for i, b in enumerate(bodies)]
    sizes.sort()
    n = len(sizes)
    picks = [
        sizes[0][1],                 # smallest
        sizes[n // 4][1],            # 25th pct
        sizes[n // 2][1],            # median
        sizes[(3 * n) // 4][1],      # 75th pct
        sizes[-1][1],                # largest (worst-case decode)
    ]
    # de-dup preserving order
    seen = set()
    out = []
    for p in picks:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top-n", type=int, default=1200)
    ap.add_argument("--vocab", type=int, default=4096)
    ap.add_argument("--model-version", type=int, default=1)
    args = ap.parse_args()

    print("loading corpus top-%d ..." % args.top_n)
    bodies, raw = corpus.load_bodies(args.top_n)
    s = corpus.stats(bodies)
    print("  %d bodies, %.2f MB utf8, max %d B" % (s["n"], s["total_utf8_bytes"] / 1e6, s["max_bytes"]))

    print("training BPE-%d + Huffman (E2) ..." % args.vocab)
    model = algos.bpeE2_train(bodies, args.vocab)
    print("  V=%d  maxCodeLen=%d" % (model["V"], max(model["lengths"].values())))

    mb = build_model_bin(model, args.model_version)
    print("model.bin = %d bytes (%.1f KB)" % (len(mb), len(mb) / 1024.0))

    # ---- self-verify: round-trip ALL bodies with the watch-mirror decoder ----
    parsed = parse_model_bin(mb)
    assert parsed["modelVersion"] == args.model_version
    print("verifying watch-mirror decode over all %d bodies ..." % len(bodies))
    bad = 0
    for i, body in enumerate(bodies):
        blob = algos.bpeE2_compress(body, model)
        got = decode_with_parsed(parsed, blob)
        if got != body.encode("utf-8"):
            bad += 1
            if bad <= 3:
                print("  MISMATCH id=%d" % i)
    if bad:
        raise SystemExit("watch-mirror decode FAILED on %d/%d bodies" % (bad, len(bodies)))
    print("  OK - watch-mirror decode is byte-exact on all bodies.")

    # ---- emit the baked resource (model.json) ----
    res_dir = os.path.join(REPO, "resources", "jsonData")
    os.makedirs(res_dir, exist_ok=True)
    model_b64 = base64.b64encode(mb).decode("ascii")
    model_json = {"v": args.model_version, "b64": model_b64}
    with open(os.path.join(res_dir, "model.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(model_json, f, separators=(",", ":"))
    print("wrote resources/jsonData/model.json (b64 %d chars)" % len(model_b64))

    # ---- golden vectors ----
    golden_ids = pick_golden_ids(bodies)
    golden = []

    # a tiny, human-readable synthetic vector (round-trips through the same model)
    tiny_text = "אבא"  # "אבא"
    tiny_blob = algos.bpeE2_compress(tiny_text, model)
    assert decode_with_parsed(parsed, tiny_blob) == tiny_text.encode("utf-8")
    golden.append({
        "id": "tiny-aba",
        "blob_b64": base64.b64encode(tiny_blob).decode("ascii"),
        "expected_b64": base64.b64encode(tiny_text.encode("utf-8")).decode("ascii"),
        "expected_len": len(tiny_text.encode("utf-8")),
        "expected_preview": tiny_text,
    })

    for cid in golden_ids:
        body = bodies[cid]
        blob = algos.bpeE2_compress(body, model)
        golden.append({
            "id": str(cid),
            "blob_b64": base64.b64encode(blob).decode("ascii"),
            "expected_b64": base64.b64encode(body.encode("utf-8")).decode("ascii"),
            "expected_len": len(body.encode("utf-8")),
            "expected_preview": body[:40],
        })

    with open(os.path.join(HERE, "golden.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(golden, f, ensure_ascii=False, indent=1)
    print("wrote scripts/m10-compress/golden.json (%d vectors)" % len(golden))

    # ---- emit ready-to-paste Monkey C (:test) functions (zero release footprint:
    #      all data lives inside (:test) functions, stripped from non-test builds) ----
    emit_mc_tests(golden)

    print("\nDONE. model %d B, %d golden vectors (largest body %d B)." %
          (len(mb), len(golden), s["max_bytes"]))


def emit_mc_tests(golden):
    lines = []
    lines.append("// AUTO-GENERATED by scripts/m10-compress/gen_model.py -- do not hand-edit.")
    lines.append("// Golden round-trip vectors for the M10 Decompressor. All data lives")
    lines.append("// inside (:test) functions, so it is stripped from non-unit-test builds.")
    lines.append("")
    for v in golden:
        slug = v["id"].replace("-", "_")
        lines.append("(:test)")
        lines.append("function decompressGolden_%s(logger as Logger) as Boolean {" % slug)
        lines.append("    var model = CompModel.model();")
        lines.append('    if (model == null) { logger.error("model() returned null"); return false; }')
        lines.append('    var blob = Decompressor.b64ToBytes("%s");' % v["blob_b64"])
        lines.append('    var want = Decompressor.b64ToString("%s");' % v["expected_b64"])
        lines.append("    var got = Decompressor.decompress(blob, model as Dictionary);")
        lines.append('    logger.debug("id=%s got=" + got.length() + " want=" + want.length());'
                     % v["id"])
        lines.append("    return got.equals(want);")
        lines.append("}")
        lines.append("")
    out_path = os.path.join(HERE, "golden_tests.mc.txt")
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote scripts/m10-compress/golden_tests.mc.txt")


if __name__ == "__main__":
    main()
