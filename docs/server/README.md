# wikiwatch server static corpus

These files are the M7 server-side payload for https://wikiwatch.tomhe.app/.
Upload them so the paths match this layout:

- wikiwatch.tomhe.app/manifest.json
- wikiwatch.tomhe.app/article/<id>.txt  (36 files)

The Garmin watch app fetches these on first launch (and re-checks on every
launch via a 1-second background race). Content-Type matters:

- manifest.json -> pplication/json (or 	ext/plain; charset=utf-8).
- rticle/<id>.txt -> 	ext/plain; charset=utf-8.

**Do NOT serve pplication/octet-stream** — Garmin's BLE proxy rejects
it with RC=-400 (see project memory eference_ciq_quirks.md).

The TLS cert must be valid (Let's Encrypt or similar). Self-signed certs
will be rejected by the watch with RC=-1003.

Files were generated from source/models/Fixtures.mc at M6.5 via
scripts/gen-server-corpus.ps1. Re-run that script when the corpus
changes.

## Files

36 article bodies + 1 manifest = 37 total files.
Total payload: 6615 bytes of article body content + manifest overhead.