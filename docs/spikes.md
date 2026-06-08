# Spikes & on-device probes

Throwaway-but-kept diagnostic apps + experiments. They are **separate Connect IQ
apps** (own UUID + own `Application.Storage` namespace), each self-contained under
`probes/<name>/`, so they never touch the wikiwatch app or its data. The root
wikiwatch build only compiles `source/`, so `probes/` does not affect it.

Each builds to **`C:\Temp\<Name>.prg`** (monkeyc can't write under the
`Documents\Garmin` tree — a scanner/indexer locks the freshly-written binary; see
`reference_toolchain` memory). Sideload the `.prg` to `GARMIN\APPS\` on the watch.

## probes/cap-probe — makeWebRequest response-cap probe (M10.x)
**Question:** what's the real Venu 2 `makeWebRequest` response-size cap (the
`-402 NETWORK_RESPONSE_TOO_LARGE` ceiling)?
**How:** `gen_payloads.py` writes exact-size JSON (`server/probe/<KB>.json`, 12–64
KB, incompressible base64 pad so wire ≈ decompressed). `build.ps1` builds the app
(BASE = `wikiwatch.tomhe.app/probe/`); upload the payloads there, sideload, and the
app fetches each size in turn and shows a colour grid + `CAP = N KB`.
`sim-check.ps1` validates it against the local HTTPS fixture first.
**Finding (on-device, ×3 trials): the real cap is between 48 KB and 64 KB** (48→200,
64→−402) — far above the simulator's **16 KB**. This is why M10.7 ships 48 KB chunks.
See `reference_install_check_sim_cap` memory.

## probes/storage-probe — Application.Storage key-count / throughput probe (M11.0)
**Question:** how many `Application.Storage` keys can the Venu 2 hold (the ceiling
for the ~20k-article corpus once bodies are ~250-byte summaries — storage *bytes*
fit 25k+, so the limit is key count / write throughput / read latency)?
**How:** `build.ps1` → `C:\Temp\StorageProbe.prg`. Sideload + open; it writes keys
`k0..kN` (each ~250 B) in batches across Timer ticks (watchdog-safe), counting up
on-screen to 30k or until it fails. A persisted `_hi` high-water key survives an
uncatchable crash so the next launch shows the furthest count reached. Reports:
max keys (`OK 30000` / `LIMIT N` / crash high-water), getValue latency (`get=Xms`)
as the count grows, write throughput (elapsed), and free memory (`fm:`).
**Finding:** _pending the user's on-device run (sets the M11 safe article ceiling)._
See `project_m11_plan` memory + `docs/m11-handoff.md`.
