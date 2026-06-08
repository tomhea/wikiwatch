#!/usr/bin/env python3
"""M11 research: how small can a meaningful article summary get, stored?

For a sample of the cached full articles, truncate the body to a raw UTF-8 byte
budget (at a char boundary) — a proxy for the "lede" (first paragraph) summary —
compress with the SAME v1 model the watch decodes, and measure the STORED size
(base64). Tells us what raw budget yields ~250 stored bytes, and the compression
ratio on short texts (which differs from full-article ~37%).

Also estimates the resident search-index RAM at 20k titles (the real ceiling).
"""
import base64
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "m10-compress"))
import algos          # noqa: E402
import dense_pack     # noqa: E402

ART = os.path.join(HERE, "..", "m8-corpus", "cached", "articles")
SEL = os.path.join(HERE, "..", "m8-corpus", "cached", "selected.tsv")
RAW_BUDGETS = [256, 384, 512, 768, 1024]
SAMPLE = 800


def truncate_utf8(text, max_bytes):
    b = text.encode("utf-8")
    if len(b) <= max_bytes:
        return text
    b = b[:max_bytes]
    # back off to a valid char boundary, then to the last space (word boundary)
    while b and (b[-1] & 0xC0) == 0x80:
        b = b[:-1]
    s = b.decode("utf-8", "ignore")
    sp = s.rfind(" ")
    return s[:sp] if sp > max_bytes * 0.6 else s


def main():
    model, parsed = dense_pack.load_v1_model()
    files = sorted(glob.glob(os.path.join(ART, "*.txt")))[:SAMPLE]
    print("sampled %d cached articles\n" % len(files))
    print("raw_budget  stored: median  mean  max   ratio(stored/raw)  ~articles_in_8MB")
    for budget in RAW_BUDGETS:
        stored = []
        for p in files:
            body = open(p, encoding="utf-8").read()
            lede = truncate_utf8(body, budget)
            blob = algos.bpeE2_compress(lede, model)
            b64 = base64.b64encode(blob).decode("ascii")
            stored.append(len(b64))
        stored.sort()
        med = stored[len(stored) // 2]
        mean = sum(stored) / len(stored)
        mx = stored[-1]
        # +~18 bytes Storage key overhead per article (Application.Storage)
        per = mean + 18
        fit = int(8_000_000 / per)
        print("  %4d      %6d  %6.0f  %5d   %4.0f%%              %d"
              % (budget, med, mean, mx, 100.0 * mean / budget, fit))

    # --- resident search-index RAM at 20k titles (the real ceiling) ---
    print("\n--- resident index RAM estimate (titles in RAM for search) ---")
    titles = []
    with open(SEL, encoding="utf-8") as f:
        next(f)
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) >= 4:
                titles.append(c[3])
    avg_title_chars = sum(len(t) for t in titles) / max(1, len(titles))
    # Monkey C String ~ 2 bytes/char + ~16 bytes object overhead; titles[] + pops[]
    # (Number ~8B) + normTitles[] (mostly aliases titles on the no-punct fast path).
    per_title = avg_title_chars * 2 + 16 + 8
    for n in (2800, 5000, 10000, 20000):
        kb = n * per_title / 1024
        print("  %5d titles: ~%4.0f KB resident  (Venu2 free heap ~700 KB; MemGuard floor 150 KB)"
              % (n, kb))


if __name__ == "__main__":
    main()
