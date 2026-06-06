#!/usr/bin/env python3
"""M10.6 experiment: can we REUSE the baked v1 model to compress the NEW corpus
(no binary/model change)?

Trains the BPE+Huffman model on the recovered old plain top-1200 bodies (git
b57ad96, extracted to bin/plainchunks) and checks the resulting model.bin is
byte-identical to the baked resources/jsonData/model.json. If yes, the v1 encoder
is reproducible -> compress the new 2800 corpus with it, modelVersion stays 1, the
shipped M10.5 binary decodes it unchanged. Also sanity-checks that v1 compresses +
round-trips a NEW read-ranked article.
"""
import base64, glob, hashlib, json, os
import algos, gen_model

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PLAIN = os.path.join(REPO, "bin", "plainchunks")
BAKED = os.path.join(REPO, "resources", "jsonData", "model.json")
NEW_ART = os.path.join(REPO, "scripts", "m8-corpus", "cached", "articles")
NEW_SEL = os.path.join(REPO, "scripts", "m8-corpus", "cached", "selected.tsv")


def load_bodies(chunk_dir, top_n=1200):
    by_id = {}
    for p in glob.glob(os.path.join(chunk_dir, "*.json")):
        for sid, body in json.load(open(p, encoding="utf-8"))["articles"].items():
            by_id[int(sid)] = body
    ids = sorted(i for i in by_id if i < top_n)
    return [by_id[i] for i in ids]


def main():
    bodies = load_bodies(PLAIN, 1200)
    print("training on %d recovered plain bodies ..." % len(bodies), flush=True)
    model = algos.bpeE2_train(bodies, 4096)
    fresh = gen_model.build_model_bin(model, 1)
    baked = base64.b64decode(json.load(open(BAKED, encoding="utf-8"))["b64"])
    match = (fresh == baked)
    print("fresh sha=%s" % hashlib.sha256(fresh).hexdigest()[:16])
    print("baked sha=%s" % hashlib.sha256(baked).hexdigest()[:16])
    print("REPRODUCES BAKED v1: %s" % ("YES" if match else "NO"))
    if not match:
        print("-> v1 NOT reproducible from these bodies; reuse path needs the exact")
        print("   bake input, else re-bake v2.")
        return

    # v1 reproduced -> prove it compresses + round-trips a NEW article.
    parsed = gen_model.parse_model_bin(baked)
    with open(NEW_SEL, encoding="utf-8") as f:
        next(f)
        aid = f.readline().split("\t")[1]   # top read-ranked article id
    body = open(os.path.join(NEW_ART, aid + ".txt"), encoding="utf-8").read()
    blob = algos.bpeE2_compress(body, model)
    got = gen_model.decode_with_parsed(parsed, blob)
    ok = (got == body.encode("utf-8"))
    print("new-article round-trip (id=%s, raw=%dB -> blob=%dB, %.1f%%): %s"
          % (aid, len(body.encode("utf-8")), len(blob),
             100.0 * len(base64.b64encode(blob)) / max(1, len(body.encode("utf-8"))),
             "OK" if ok else "FAILED"))
    print("\n=> v1 IS REUSABLE for the new corpus (no model/binary change)."
          if ok else "\n=> round-trip FAILED — investigate.")


if __name__ == "__main__":
    main()
