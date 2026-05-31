"""Load the real wikiwatch corpus for the M10 compression bake-off.

Source of truth = docs/server/chunk/*.json (the exact post-clean, post-cap bodies
that ship), keyed by numeric id (id order == popularity order). We take the top-N
ids as the shippable corpus.
"""
import json
import os
import glob

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CHUNK_DIR = os.path.join(REPO, "docs", "server", "chunk")


def load_bodies(top_n=1200):
    """Return (bodies, raw_chunk_bytes).

    bodies: list[str] of article bodies in id order 0..top_n-1.
    raw_chunk_bytes: total on-disk bytes of the chunk JSON files (what is
        downloaded today) — the ground-truth baseline for the download metric.
    """
    by_id = {}
    raw_chunk_bytes = 0
    files = glob.glob(os.path.join(CHUNK_DIR, "*.json"))
    if not files:
        raise SystemExit("no chunk JSONs under %s" % CHUNK_DIR)
    for path in files:
        with open(path, "rb") as f:
            data = f.read()
        raw_chunk_bytes += len(data)
        obj = json.loads(data.decode("utf-8"))
        arts = obj.get("articles", {})
        for sid, body in arts.items():
            by_id[int(sid)] = body

    ids = sorted(by_id.keys())
    if top_n is not None:
        ids = [i for i in ids if i < top_n]
    bodies = [by_id[i] for i in ids]
    return bodies, raw_chunk_bytes


def stats(bodies):
    sizes = [len(b.encode("utf-8")) for b in bodies]
    total = sum(sizes)
    return {
        "n": len(bodies),
        "total_utf8_bytes": total,
        "avg_bytes": total // max(1, len(bodies)),
        "max_bytes": max(sizes) if sizes else 0,
        "min_bytes": min(sizes) if sizes else 0,
    }


if __name__ == "__main__":
    bodies, raw = load_bodies()
    s = stats(bodies)
    print("loaded", s["n"], "bodies")
    print("total utf8:", s["total_utf8_bytes"], "bytes (%.2f MB)" % (s["total_utf8_bytes"] / 1e6))
    print("avg:", s["avg_bytes"], "max:", s["max_bytes"], "min:", s["min_bytes"])
    print("raw chunk-JSON on disk (today's download):", raw, "bytes (%.2f MB)" % (raw / 1e6))
    print("sample body[0] first 200 chars:\n", bodies[0][:200])
