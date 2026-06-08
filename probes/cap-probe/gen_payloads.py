#!/usr/bin/env python3
"""Generate exact-byte-size JSON probe payloads for the watch response-cap probe.

Each /probe/<KB>.json is EXACTLY KB*1024 bytes of valid JSON:
  {"kb":<KB>,"pad":"AAAA...AAAA"}
The watch's makeWebRequest rc=-402 (NETWORK_RESPONSE_TOO_LARGE) triggers on the
response byte size, so a KB*1024-byte file probes the cap at exactly that size.
(gzip on the wire doesn't matter — the cap is on the decompressed JSON.)

Upload the whole `server/probe/` folder to wikiwatch.tomhe.app so the files live
at https://wikiwatch.tomhe.app/probe/<KB>.json — matching ProbeView.BASE.
"""
import base64
import json
import os

SIZES_KB = [12, 13, 14, 15, 16, 17, 18, 20, 24, 32, 48, 64]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server", "probe")


def incompressible(n):
    """n base64 chars of high-entropy data (JSON-string-safe: A-Za-z0-9+/). Keeps
    the file incompressible so gzip on the wire ~= the decompressed size — the
    probe then measures the cap correctly whether it's enforced on wire or
    decompressed bytes."""
    raw = os.urandom(n)  # b64 of n bytes is > n chars; slice to exactly n
    return base64.b64encode(raw).decode("ascii")[:n]


def main():
    os.makedirs(OUT, exist_ok=True)
    for kb in SIZES_KB:
        target = kb * 1024
        # Build the envelope with an empty pad, measure it, then pad to exact size.
        head = '{"kb":%d,"pad":"' % kb
        tail = '"}'
        pad_len = target - len(head) - len(tail)
        if pad_len < 0:
            raise SystemExit("target %d too small for envelope" % target)
        body = head + incompressible(pad_len) + tail
        assert len(body.encode("ascii")) == target, (kb, len(body), target)
        # sanity: valid JSON
        json.loads(body)
        path = os.path.join(OUT, "%d.json" % kb)
        with open(path, "w", encoding="ascii", newline="") as f:
            f.write(body)
        print("wrote %s  (%d bytes = %d KB)" % (path, target, kb))
    print("\n%d files -> %s" % (len(SIZES_KB), OUT))
    print("Upload server/probe/ so files are at https://wikiwatch.tomhe.app/probe/<KB>.json")


if __name__ == "__main__":
    main()
