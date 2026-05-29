# wikiwatch server static corpus (M8)

These files are the server-side payload for https://wikiwatch.tomhe.app/.
Upload them so the paths match this layout:

- `wikiwatch.tomhe.app/manifest.json`
- `wikiwatch.tomhe.app/chunk/0.json` … `chunk/<N-1>.json`  (`chunkCount` files)

The Garmin watch app fetches `manifest.json` on every launch (1-second
background race). When it sees a newer `version`, it prompts the user and — on
accept — downloads all `chunk/N.json` files, unpacking each into per-article
Storage. **The watch never fetches individual articles** (M7's
`/article/<id>.txt` endpoint is gone — M8 ships the bodies inside chunks).

## Content-Type

- `manifest.json` → `application/json` (or `text/plain; charset=utf-8`).
- `chunk/<N>.json` → `application/json`.

**Do NOT serve `application/octet-stream`** — Garmin's BLE proxy rejects it
with RC=-400 (see project memory `reference_ciq_quirks.md`).

The TLS cert must be valid (Let's Encrypt or similar). Self-signed certs are
rejected by the watch with RC=-1003.

## Response-size cap (IMPORTANT)

The Venu 2 simulator rejects any `makeWebRequest` response larger than ~12-13 KB
with `rc=-402` (NETWORK_RESPONSE_TOO_LARGE). The cap is on the **decompressed**
size, so it bounds the *content* size, not the wire size. This is why:

- `manifest.json` is kept ≤ ~12 KB (compact JSON + numeric ids) → ~180 articles.
- each `chunk/N.json` is kept ≤ ~12 KB (`pack-chunks.ps1 -ChunkByteTarget 10240`).

If you regenerate a larger corpus, the article count is bounded by the manifest
fitting under this cap (a single un-chunked response). Don't raise the chunk
byte target above ~10 KB.

## gzip

Hebrew JSON compresses ~4×. CIQ's `makeWebRequest` sends `Accept-Encoding: gzip`
by default and decompresses transparently. gzip does NOT lift the response cap
(that's on the decompressed size), but it roughly quarters install transfer
time over BLE, so keep it on. The static files do NOT need to be pre-gzipped —
configure the web server to gzip on the fly:

- **Caddy:** add `encode gzip` to the site block (NOT on by default — confirm it).
- **nginx:** `gzip on; gzip_types application/json;`
- **Cloudflare:** auto-gzips JSON; nothing to do.

Confirm: `curl -I -H "Accept-Encoding: gzip" https://wikiwatch.tomhe.app/chunk/0.json`
→ should show `Content-Encoding: gzip`.

## Regenerating

Generated from a Hebrew Wikipedia ZIM by `scripts/m8-corpus/*` (see that
folder's README). Re-run the 5-step pipeline when the corpus changes;
`gen-manifest.ps1` bumps `version`, which is what triggers the watch update
prompt.
