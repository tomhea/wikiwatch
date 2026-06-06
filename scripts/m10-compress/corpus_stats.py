#!/usr/bin/env python3
"""M10.5 corpus capacity stats.

Measures the NEW read-ranked selection (scripts/m8-corpus/cached/selected.tsv,
bodies in cached/articles/<id>.txt) for article length + compressed size, and
prints distribution + cumulative-vs-budget tables so we can decide how many
articles to ship now and whether more fit later.

Compression uses a model trained on the OLD top-1200 plain bodies (reproduces /
approximates the model baked into the .prg — the shipped corpus is compressed with
that fixed model), so the sizes are realistic-to-slightly-conservative. We try to
verify the trained model == baked (sha) and report it.

Run from this directory:  python corpus_stats.py
"""
import base64, json, os, statistics
import algos, gen_model

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CACHED = os.path.join(REPO, "scripts", "m8-corpus", "cached")
SEL = os.path.join(CACHED, "selected.tsv")           # NEW read-ranked selection
SEL_FULL = os.path.join(CACHED, "selected-full.tsv")  # OLD selection (training ids)
ART = os.path.join(CACHED, "articles")
BAKED = os.path.join(REPO, "resources", "jsonData", "model.json")
OUT = os.path.join(CACHED, "corpus-stats.tsv")

STORAGE_CAP = 9_000_000   # ~9 MB Application.Storage cap (proven on Venu 2)
PER_KEY = 20              # rough Storage per-key overhead (article:<id>)


def read_tsv(path):
    with open(path, encoding="utf-8") as f:
        next(f)
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 4:
                yield p[0], p[1], p[2], p[3]   # idx, id, pop, title


def body_of(aid):
    p = os.path.join(ART, aid + ".txt")
    return open(p, encoding="utf-8").read() if os.path.exists(p) else None


def main():
    # ---- train a baked-equivalent model on the OLD top-1200 plain bodies ----
    print("loading OLD top-1200 training bodies ...", flush=True)
    train = []
    for i, (_idx, aid, _pop, _t) in enumerate(read_tsv(SEL_FULL)):
        if i >= 1200:
            break
        b = body_of(aid)
        if b is not None:
            train.append(b)
    print("  %d training bodies; training BPE-4096 (deterministic) ..." % len(train), flush=True)
    model = algos.bpeE2_train(train, 4096)
    try:
        fresh = gen_model.build_model_bin(model, 1)
        baked = base64.b64decode(json.load(open(BAKED, encoding="utf-8"))["b64"])
        import hashlib
        match = (fresh == baked)
        print("  trained model %s baked (sha %s vs %s)" % (
            "==" if match else "!=",
            hashlib.sha256(fresh).hexdigest()[:12], hashlib.sha256(baked).hexdigest()[:12]))
        if not match:
            print("  (using the trained-equivalent model — sizes are estimates, ~within a few %)")
    except Exception as e:
        print("  (could not verify against baked: %s)" % e)

    # ---- measure the NEW read-ranked selection ----
    rows = []
    rank = 0
    for _idx, aid, _pop, title in read_tsv(SEL):
        b = body_of(aid)
        if b is None:
            continue
        raw = len(b.encode("utf-8"))
        b64 = len(base64.b64encode(algos.bpeE2_compress(b, model)))
        rank += 1
        rows.append((rank, aid, title, raw, b64, len(title.encode("utf-8"))))
    n = len(rows)

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("rank\tid\trawBytes\tb64Bytes\ttitleBytes\ttitle\n")
        for r in rows:
            f.write("%d\t%s\t%d\t%d\t%d\t%s\n" % (r[0], r[1], r[3], r[4], r[5], r[2]))

    def dist(xs):
        s = sorted(xs)
        return (s[0], int(statistics.median(s)), sum(s) // len(s), s[-1], s[int(0.9 * (len(s) - 1))])

    raws = [r[3] for r in rows]
    b64s = [r[4] for r in rows]
    print("\n================ CORPUS STATS (read-ranked, %d articles) ================" % n)
    print("raw  body   bytes  min/median/mean/p90/max: %d / %d / %d / %d / %d" % (
        dist(raws)[0], dist(raws)[1], dist(raws)[2], dist(raws)[4], dist(raws)[3]))
    print("b64  stored bytes  min/median/mean/p90/max: %d / %d / %d / %d / %d" % (
        dist(b64s)[0], dist(b64s)[1], dist(b64s)[2], dist(b64s)[4], dist(b64s)[3]))
    print("overall: stored(b64) = %.1f%% of raw text" % (100.0 * sum(b64s) / sum(raws)))

    # ---- cumulative vs budget (in read-rank order) ----
    print("\n N      download/storage   raw text   index(titles)")
    cb = cr = ct = 0
    fit_n = 0
    cum = {}
    for r in rows:
        cb += r[4] + PER_KEY
        cr += r[3]
        ct += r[5] + 4
        cum[r[0]] = (cb, cr, ct)
        if cb <= STORAGE_CAP:
            fit_n = r[0]
    for m in [500, 1000, 1200, 1462, 1750, 2000, 2250, 2500]:
        if m in cum:
            b, raw, t = cum[m]
            print(" %-5d  %6.2f MB          %6.2f MB   %6.1f KB" % (m, b / 1e6, raw / 1e6, t / 1024))
    print("\n=> Fit under the 9 MB Storage cap (compressed bodies): ~%d articles" % fit_n)
    b, raw, t = cum[rows[-1][0]]
    print("=> At %d articles: download/storage %.2f MB, index titles %.1f KB" % (n, b / 1e6, t / 1024))
    print("   (index-load watchdog is a SEPARATE binary limit (~1462 today) — raised by slicing the load.)")
    print("\nper-article detail -> %s" % OUT)


if __name__ == "__main__":
    main()
