"""M10 compression bake-off runner.

For each candidate: train a static model on the corpus, compress every article,
VALIDATE exact round-trip (hard gate), measure decode-op cost, and compute the
download / flash / model metrics. Writes results/report.md + results/report.json.

    python scripts/m10-compress/bakeoff.py --top-n 1200
"""
import argparse
import json
import os
import time

import corpus
from algos import ALGOS

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, "results")


def b64len(n):
    return ((n + 2) // 3) * 4


def json_value_bytes(s):
    """Bytes a string occupies as a JSON string value (quotes + escapes, UTF-8)."""
    return len(json.dumps(s, ensure_ascii=False).encode("utf-8"))


def download_formula(per_article_value_bytes, ids):
    """Model the chunk-JSON download: per article  "<id>":<value>,  plus a small
    per-corpus wrapper. Same formula for raw and every algo, so ratios compare."""
    total = 0
    for vb, i in zip(per_article_value_bytes, ids):
        total += len(('"%d":' % i).encode()) + vb + 1   # key + value + comma
    total += 64  # chunk wrappers (amortized, negligible)
    return total


def watchdog_margin(worst_ops):
    if worst_ops < 200_000:
        return "LOW"
    if worst_ops < 1_000_000:
        return "OK"
    return "RISK"


def run_algo(spec, bodies, ids, raw_bytes, raw_download):
    name = spec["name"]
    t0 = time.time()
    model = spec["train"](bodies)
    train_s = time.time() - t0
    model_bytes = spec["model_size"](model)

    comp_bytes = 0
    b64_flash = 0
    dl_values = []
    total_ops = 0
    worst_ops = 0
    worst_size = 0
    fails = 0
    t1 = time.time()
    dec_time = 0.0
    for b in bodies:
        blob = spec["compress"](b, model)
        comp_bytes += len(blob)
        b64_flash += b64len(len(blob))
        dl_values.append(b64len(len(blob)) + 2)   # base64 string in JSON: + 2 quotes
        td = time.time()
        out, ops = spec["decompress"](blob, model)
        dec_time += time.time() - td
        total_ops += ops
        if ops > worst_ops:
            worst_ops = ops
            worst_size = len(out)
        if out != b.encode("utf-8"):
            fails += 1
    work_s = time.time() - t1

    net_download = download_formula(dl_values, ids) + b64len(model_bytes)
    row = {
        "name": name,
        "feasible": spec["feasible"],
        "raw_bytes": raw_bytes,
        "comp_bytes": comp_bytes,
        "ratio": comp_bytes / raw_bytes,
        "model_bytes": model_bytes,
        "net_flash_bytearray": comp_bytes + model_bytes,
        "net_flash_base64": b64_flash + model_bytes,
        "net_download": net_download,
        "dl_vs_raw_pct": 100.0 * net_download / raw_download,
        "decode_ops_per_byte": total_ops / raw_bytes,
        "worst_decode_ops": worst_ops,
        "worst_article_bytes": worst_size,
        "watchdog_margin": watchdog_margin(worst_ops),
        "roundtrip": "PASS" if fails == 0 else ("FAIL(%d)" % fails),
        "train_s": round(train_s, 2),
        "work_s": round(work_s, 2),
        "decode_ms_per_article": round(1000.0 * dec_time / len(bodies), 3),
    }
    return row


def fmt_kb(n):
    return "%.0f" % (n / 1024.0)


def write_report(rows, meta, stem="report"):
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, stem + ".json"), "w", encoding="utf-8") as f:
        json.dump({"meta": meta, "rows": rows}, f, ensure_ascii=False, indent=2)

    lines = []
    lines.append("# M10 compression bake-off — results\n")
    lines.append("Corpus: top-%d articles, %d bodies, raw UTF-8 %.2f MB "
                 "(avg %d B, max %d B). Today's raw chunk-JSON download: %.2f MB.\n"
                 % (meta["top_n"], meta["n"], meta["raw_bytes"] / 1e6,
                    meta["avg_bytes"], meta["max_bytes"], meta["raw_download"] / 1e6))
    lines.append("\n**Primary metric: net download** (base64-in-JSON, incl. the +33%% transport tax). "
                 "`dl%%` = net download vs today's raw download. Flash shown both as raw ByteArray "
                 "(if Storage accepts it) and base64 String (today's storage type). "
                 "`model` ships once. Decode cost is per-article-open.\n")
    lines.append("\n| algo | feas | ratio | dl% | net_dl MB | flash(BA) MB | flash(b64) MB | model KB | dec ops/B | worst ops | wd | ms/art | rt |\n")
    lines.append("|---|---|--:|--:|--:|--:|--:|--:|--:|--:|:--:|--:|:--:|\n")
    for r in rows:
        lines.append("| %s | %s | %.3f | %.0f | %.2f | %.2f | %.2f | %s | %.2f | %d | %s | %s | %s |\n" % (
            r["name"], r["feasible"], r["ratio"], r["dl_vs_raw_pct"],
            r["net_download"] / 1e6, r["net_flash_bytearray"] / 1e6, r["net_flash_base64"] / 1e6,
            fmt_kb(r["model_bytes"]), r["decode_ops_per_byte"], r["worst_decode_ops"],
            r["watchdog_margin"], r["decode_ms_per_article"], r["roundtrip"]))
    lines.append("\n*feas* = hand-decode feasibility on the watch (reference rows can't win). "
                 "*wd* = watchdog margin for the worst (largest) article decode. "
                 "*rt* = exact round-trip over all N.\n")
    with open(os.path.join(RESULTS, stem + ".md"), "w", encoding="utf-8") as f:
        f.write("".join(lines))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top-n", type=int, default=1200)
    ap.add_argument("--only", type=str, default=None, help="substring filter on algo name")
    ap.add_argument("--bpe-sweep", action="store_true", help="sweep E2 BPE vocab sizes")
    args = ap.parse_args()

    bodies, raw_download = corpus.load_bodies(args.top_n)
    ids = list(range(len(bodies)))
    st = corpus.stats(bodies)
    raw_bytes = st["total_utf8_bytes"]
    # raw download via the SAME formula (sanity vs on-disk ~ raw_download)
    raw_dl_formula = download_formula([json_value_bytes(b) for b in bodies], ids)

    meta = dict(top_n=args.top_n, n=st["n"], raw_bytes=raw_bytes,
                avg_bytes=st["avg_bytes"], max_bytes=st["max_bytes"],
                raw_download=raw_dl_formula, raw_download_ondisk=raw_download)

    print("corpus: %d bodies, %.2f MB raw, raw-dl(formula) %.2f MB (on-disk %.2f MB)" %
          (st["n"], raw_bytes / 1e6, raw_dl_formula / 1e6, raw_download / 1e6))

    specs = ALGOS
    if args.bpe_sweep:
        from algos import bpeE2_train, bpeE2_model_size, bpeE2_compress, bpeE2_decompress
        specs = [dict(name="E2 bpe%d-huff" % v, feasible="easy",
                      train=(lambda b, vv=v: bpeE2_train(b, vv)),
                      model_size=bpeE2_model_size, compress=bpeE2_compress,
                      decompress=bpeE2_decompress)
                 for v in (512, 1024, 2048, 4096, 8192)]

    rows = []
    for spec in specs:
        if args.only and args.only not in spec["name"]:
            continue
        print("running", spec["name"], "...", flush=True)
        r = run_algo(spec, bodies, ids, raw_bytes, raw_dl_formula)
        print("   ratio=%.3f dl%%=%.0f flash(BA)=%.2fMB model=%sKB worst_ops=%d %s rt=%s (%.1fs)" % (
            r["ratio"], r["dl_vs_raw_pct"], r["net_flash_bytearray"] / 1e6,
            fmt_kb(r["model_bytes"]), r["worst_decode_ops"], r["watchdog_margin"],
            r["roundtrip"], r["train_s"] + r["work_s"]), flush=True)
        rows.append(r)

    rows.sort(key=lambda r: r["net_download"])
    stem = "report_bpe_sweep" if args.bpe_sweep else "report"
    write_report(rows, meta, stem)
    print("\nwrote", os.path.join(RESULTS, stem + ".md"))


if __name__ == "__main__":
    main()
