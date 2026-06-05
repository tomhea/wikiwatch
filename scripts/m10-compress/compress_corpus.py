#!/usr/bin/env python3
"""M10.1 - flip the served corpus to compressed bodies.

Transforms docs/server/chunk/*.json IN PLACE: each article body (plain UTF-8
text) is replaced by base64(BPE+Huffman(body)) using the SAME model that is
baked into the .prg (resources/jsonData/model.json). BPE training is
deterministic, so a fresh retrain reproduces the baked model byte-for-byte; we
assert that (sha) before touching anything, guaranteeing the served corpus is
decodable by the shipped binary.

Then patches docs/server/manifest.json: adds bodyCodec="bpe-huff-1" +
modelVersion, bumps version, recomputes totalBytes. The chunk boundaries are
left unchanged (same chunkCount / index parts) — only the body VALUES shrink to
~1/3. Re-packing to denser chunks is a separate optimization.

The watch only DECODES; this encode step is server-side Python (the M10 rule).
Idempotency guard: refuses to run if the corpus is already compressed.

Usage:  python scripts/m10-compress/compress_corpus.py [--model-version 1] [--new-version 16]
"""
import argparse
import base64
import glob
import hashlib
import json
import os

import algos
import corpus
import gen_model

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SERVER = os.path.join(REPO, "docs", "server")
CHUNK_DIR = os.path.join(SERVER, "chunk")
MANIFEST = os.path.join(SERVER, "manifest.json")
BAKED_MODEL_JSON = os.path.join(REPO, "resources", "jsonData", "model.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-version", type=int, default=1)
    ap.add_argument("--new-version", type=int, default=16)
    args = ap.parse_args()

    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    if manifest.get("bodyCodec", "plain") != "plain":
        raise SystemExit("manifest bodyCodec=%r — corpus already compressed; refusing "
                         "(restore plain chunks from git first)." % manifest.get("bodyCodec"))

    # ---- train the model and prove it equals the baked one (decodability) ----
    print("training BPE-4096 + Huffman (deterministic) ...")
    bodies, _ = corpus.load_bodies(1200)
    model = algos.bpeE2_train(bodies, 4096)
    fresh = gen_model.build_model_bin(model, args.model_version)
    baked = base64.b64decode(json.load(open(BAKED_MODEL_JSON, encoding="utf-8"))["b64"])
    if fresh != baked:
        raise SystemExit("trained model.bin != baked resources/jsonData/model.json "
                         "(sha %s vs %s) — corpus would not decode on the shipped binary."
                         % (hashlib.sha256(fresh).hexdigest()[:16],
                            hashlib.sha256(baked).hexdigest()[:16]))
    print("  model matches baked .prg model (sha %s) — safe to compress."
          % hashlib.sha256(baked).hexdigest()[:16])
    parsed = gen_model.parse_model_bin(baked)   # watch-mirror decoder for verification

    # ---- compress every chunk in place, verifying round-trip ----
    files = sorted(glob.glob(os.path.join(CHUNK_DIR, "*.json")),
                   key=lambda p: int(os.path.splitext(os.path.basename(p))[0]))
    raw_total = 0          # original plain body bytes (utf-8)
    comp_b64_total = 0     # stored base64 bytes (what the watch keeps + downloads)
    n_articles = 0
    new_disk_total = 0
    for path in files:
        obj = json.load(open(path, encoding="utf-8"))
        arts = obj["articles"]
        for aid, body in arts.items():
            blob = algos.bpeE2_compress(body, model)
            # verify the watch will recover this body byte-exactly
            got = gen_model.decode_with_parsed(parsed, blob)
            if got != body.encode("utf-8"):
                raise SystemExit("round-trip FAILED for article id=%s in %s"
                                 % (aid, os.path.basename(path)))
            b64 = base64.b64encode(blob).decode("ascii")
            raw_total += len(body.encode("utf-8"))
            comp_b64_total += len(b64)
            n_articles += 1
            arts[aid] = b64
        data = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(data)
        new_disk_total += len(data.encode("utf-8"))

    # ---- patch the manifest ----
    manifest["version"] = args.new_version
    manifest["bodyCodec"] = "bpe-huff-1"
    manifest["modelVersion"] = args.model_version
    manifest["totalBytes"] = new_disk_total
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, separators=(",", ":"), ensure_ascii=False)

    print("\ncompressed %d articles across %d chunks" % (n_articles, len(files)))
    print("  raw bodies (utf-8):       %8.2f MB" % (raw_total / 1e6))
    print("  stored base64 (compressed): %6.2f MB  (%.1f%% of raw)"
          % (comp_b64_total / 1e6, 100.0 * comp_b64_total / raw_total))
    print("  chunk-JSON on disk (download): %.2f MB -> manifest totalBytes=%d"
          % (new_disk_total / 1e6, new_disk_total))
    print("  manifest: version=%d bodyCodec=%s modelVersion=%d"
          % (manifest["version"], manifest["bodyCodec"], manifest["modelVersion"]))


if __name__ == "__main__":
    main()
