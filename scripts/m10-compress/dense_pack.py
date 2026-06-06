#!/usr/bin/env python3
"""M10.6 — build the 2,800-article read-ranked corpus as DENSE compressed chunks.

The win over the M10.1 flow: M10.1 packed PLAIN bodies to ~30 KB-raw chunks then
compressed them IN PLACE (bodies shrank ~3x, chunk boundaries unchanged -> chunks
left ~1/5 full). This packs the *already-compressed* base64 bodies straight into
dense chunks up to a byte target, cutting the chunk count -> fewer BLE round-trips
-> much faster install.

Model REUSE (ADR of M10.6): the compression model is the v1 model baked into the
shipped .prg. We reproduce it by training on the recovered OLD plain top-1200
bodies (bin/plainchunks, git b57ad96) and assert the rebuilt model.bin is
byte-identical to resources/jsonData/model.json. We then compress the NEW 2,800
bodies with THAT model and round-trip-verify every one against the parsed baked
decoder, so the shipped binary decodes the new corpus with NO model/binary change.

Two passes, so re-packing at a different byte target is cheap:
  1. COMPRESS (slow): selected.tsv + cached/articles -> cached/compressed.tsv
     (numId <TAB> title <TAB> pop <TAB> b64), each round-trip-verified. Skipped if
     cached/compressed.tsv is newer than selected.tsv.
  2. PACK (fast): cached/compressed.tsv -> docs/server/chunk/N.json (dense, to
     --target-bytes) + cached/packed.tsv (for pack-index.ps1).

Usage:
  python dense_pack.py [--target-bytes 40960] [--recompress] [--report-only]
"""
import argparse
import base64
import glob
import hashlib
import json
import os

import algos
import gen_model

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PLAIN = os.path.join(REPO, "bin", "plainchunks")
BAKED = os.path.join(REPO, "resources", "jsonData", "model.json")
M8 = os.path.join(REPO, "scripts", "m8-corpus", "cached")
SEL = os.path.join(M8, "selected.tsv")
ART = os.path.join(M8, "articles")
COMPRESSED = os.path.join(M8, "compressed.tsv")
PACKED = os.path.join(M8, "packed.tsv")
CHUNK_DIR = os.path.join(REPO, "docs", "server", "chunk")


def cache_filename(article_id):
    """Mirror corpus-lib.ps1 Get-CacheFileName: verbatim if <=180 chars, else a
    120-char prefix + '_' + sha1(id)[:16] (stable across processes)."""
    if len(article_id) <= 180:
        return article_id
    sha = hashlib.sha1(article_id.encode("utf-8")).hexdigest()
    return article_id[:120] + "_" + sha[:16]


def load_v1_model():
    """Train the v1 model from the recovered plain top-1200 bodies and prove it
    equals the baked .prg model (decodability guarantee). Returns (model, parsed)."""
    by_id = {}
    for p in glob.glob(os.path.join(PLAIN, "*.json")):
        for sid, body in json.load(open(p, encoding="utf-8"))["articles"].items():
            by_id[int(sid)] = body
    bodies = [by_id[i] for i in sorted(i for i in by_id if i < 1200)]
    print("v1: training on %d recovered plain bodies ..." % len(bodies), flush=True)
    model = algos.bpeE2_train(bodies, 4096)
    fresh = gen_model.build_model_bin(model, 1)
    baked = base64.b64decode(json.load(open(BAKED, encoding="utf-8"))["b64"])
    if fresh != baked:
        raise SystemExit(
            "v1 model.bin != baked (sha %s vs %s) — new corpus would NOT decode on "
            "the shipped binary. STOP." % (hashlib.sha256(fresh).hexdigest()[:16],
                                           hashlib.sha256(baked).hexdigest()[:16]))
    print("v1: reproduces baked model (sha %s) — safe to reuse."
          % hashlib.sha256(baked).hexdigest()[:16])
    return model, gen_model.parse_model_bin(baked)


def read_selected():
    """selected.tsv rows (idx, id, pop, title) in read-rank order, only those with
    an extracted body, assigned a sequential numeric id 0..N-1 (== pack-chunks.ps1)."""
    out = []
    num_id = 0
    with open(SEL, encoding="utf-8") as f:
        next(f)
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) < 4:
                continue
            _, enc_id, pop, title = c[0], c[1], c[2], c[3]
            path = os.path.join(ART, cache_filename(enc_id) + ".txt")
            if not os.path.exists(path):
                continue
            out.append((num_id, title, pop, path))
            num_id += 1
    return out


def compress_pass():
    model, parsed = load_v1_model()
    rows = read_selected()
    print("compress: %d articles with bodies ..." % len(rows), flush=True)
    raw_total = 0
    b64_total = 0
    with open(COMPRESSED, "w", encoding="utf-8", newline="\n") as out:
        for num_id, title, pop, path in rows:
            body = open(path, encoding="utf-8").read()
            blob = algos.bpeE2_compress(body, model)
            got = gen_model.decode_with_parsed(parsed, blob)
            if got != body.encode("utf-8"):
                raise SystemExit("round-trip FAILED for numId=%d (%s)" % (num_id, title))
            b64 = base64.b64encode(blob).decode("ascii")
            raw_total += len(body.encode("utf-8"))
            b64_total += len(b64)
            out.write("%d\t%s\t%s\t%s\n" % (num_id, title.replace("\t", " "), pop, b64))
            if (num_id + 1) % 500 == 0:
                print("  compressed %d/%d ..." % (num_id + 1, len(rows)), flush=True)
    print("compress: %d articles, raw=%.2f MB, stored b64=%.2f MB (%.1f%% of raw) -> %s"
          % (len(rows), raw_total / 1e6, b64_total / 1e6,
             100.0 * b64_total / max(1, raw_total), os.path.basename(COMPRESSED)))


def read_compressed():
    rows = []
    with open(COMPRESSED, encoding="utf-8") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) < 4:
                continue
            rows.append((int(c[0]), c[1], c[2], c[3]))   # numId, title, pop, b64
    return rows


def _chunk_bytes(chunk_idx, articles):
    """UTF-8 byte size of the chunk JSON exactly as written (separators + wrapper)."""
    obj = {"chunk": chunk_idx, "articles": articles}
    return len(json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8"))


def pack_pass(target_bytes, write=True, out_chunk_dir=None, out_packed=None):
    chunk_dir = out_chunk_dir or CHUNK_DIR
    packed = out_packed or PACKED
    rows = read_compressed()
    chunks = []          # list of dict{id:b64}
    cur = {}
    chunk_idx = 0
    for num_id, title, pop, b64 in rows:
        # would adding this body push the chunk JSON past the target?
        trial = dict(cur)
        trial[str(num_id)] = b64
        if cur and _chunk_bytes(chunk_idx, trial) > target_bytes:
            chunks.append(cur)
            chunk_idx += 1
            cur = {}
        cur[str(num_id)] = b64
    if cur:
        chunks.append(cur)
    sizes = [_chunk_bytes(i, c) for i, c in enumerate(chunks)]
    arts_per = [len(c) for c in chunks]
    stats = {
        "target": target_bytes,
        "chunks": len(chunks),
        "max_bytes": max(sizes),
        "median_bytes": sorted(sizes)[len(sizes) // 2],
        "min_arts": min(arts_per),
        "max_arts": max(arts_per),
        "total_bytes": sum(sizes),
    }
    if write:
        if os.path.isdir(chunk_dir):
            for p in glob.glob(os.path.join(chunk_dir, "*.json")):
                os.remove(p)
        else:
            os.makedirs(chunk_dir)
        for i, c in enumerate(chunks):
            obj = {"chunk": i, "articles": c}
            with open(os.path.join(chunk_dir, "%d.json" % i), "w",
                      encoding="utf-8", newline="\n") as f:
                f.write(json.dumps(obj, separators=(",", ":"), ensure_ascii=False))
        # packed.tsv for pack-index.ps1 (numId, title, pop) in id order.
        with open(packed, "w", encoding="utf-8", newline="\n") as f:
            f.write("id\ttitle\tpopularity\n")
            for num_id, title, pop, _ in rows:
                f.write("%d\t%s\t%s\n" % (num_id, title, pop))
    return stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target-bytes", type=int, default=40960)
    ap.add_argument("--recompress", action="store_true",
                    help="force the compress pass even if compressed.tsv is fresh")
    ap.add_argument("--report-only", action="store_true",
                    help="don't write chunks; print a chunk-count table across targets")
    ap.add_argument("--out-dir", default=None,
                    help="write chunks here (+ packed.tsv alongside) instead of docs/server/chunk; "
                         "for building a sim-safe temp fixture without touching the shipped corpus")
    args = ap.parse_args()

    fresh = (os.path.exists(COMPRESSED)
             and os.path.getmtime(COMPRESSED) >= os.path.getmtime(SEL))
    if args.recompress or not fresh:
        compress_pass()
    else:
        print("compress: reusing %s (newer than selected.tsv)" % os.path.basename(COMPRESSED))

    if args.report_only:
        print("\ntarget_KB  chunks  max_KB  median_KB  arts/chunk(min..max)")
        for kb in (13, 16, 20, 24, 32, 40, 48, 56, 64):
            s = pack_pass(kb * 1024, write=False)
            print("  %5d  %6d  %6.1f  %8.1f   %d..%d"
                  % (kb, s["chunks"], s["max_bytes"] / 1024.0,
                     s["median_bytes"] / 1024.0, s["min_arts"], s["max_arts"]))
        return

    out_chunk_dir = args.out_dir
    out_packed = os.path.join(args.out_dir, "packed.tsv") if args.out_dir else None
    s = pack_pass(args.target_bytes, write=True, out_chunk_dir=out_chunk_dir, out_packed=out_packed)
    print("\npack: target=%d B -> %d chunks (max=%.1f KB, median=%.1f KB, %d..%d arts/chunk)"
          % (args.target_bytes, s["chunks"], s["max_bytes"] / 1024.0,
             s["median_bytes"] / 1024.0, s["min_arts"], s["max_arts"]))
    print("pack: total chunk bytes=%d (%.2f MB) -> %s"
          % (s["total_bytes"], s["total_bytes"] / 1e6, out_chunk_dir or CHUNK_DIR))


if __name__ == "__main__":
    main()
