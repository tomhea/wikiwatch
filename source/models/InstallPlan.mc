import Toybox.Lang;

// M8 pure install-orchestration logic. No Storage, no Network, no System —
// just the math of "which chunks still need fetching", "how many requests to
// fire next", and "is the install done / stale". Storage-backed state lives
// in source/storage/InstallState.mc, which delegates the algorithmic
// decisions here so they're unit-testable in isolation.
//
// R6: this module imports only Toybox.Lang.
module InstallPlan {
    // Memory-pressure threshold: below this many free heap bytes, the install
    // drops to a single concurrent chunk request (see maxInFlightForMemory).
    const MEM_PRESSURE_BYTES = 400 * 1024;

    // M10.6: with this much free heap (or more) the install goes optimistic and
    // fires up to MAX_IN_FLIGHT concurrent chunk requests — fewer BLE round-trips,
    // much faster download. Venu 2 launches the install with ~600-700 KB free, so
    // 4-in-flight engages at the start and the -101 back-off / memory step-down
    // trim it automatically as parse buffers grow. Tunable against the sim
    // install-check + the on-device BLE behaviour.
    const MEM_AMPLE_BYTES = 550 * 1024;

    // M10.6: optimistic concurrency ceiling and the floor the -101 back-off
    // ratchets toward (keeps a little parallelism even when the BLE stack is
    // returning queue-full).
    const MAX_IN_FLIGHT = 4;
    const MIN_IN_FLIGHT = 2;

    // M9.5: hard cap on how much article-body data we write to Application.Storage
    // (flash) during an install. The Venu 2 flash quota is invisible to the API
    // (System.getSystemStats reports only RAM), and overflowing it crashes the
    // overflowing setValue UNCATCHABLY (the 1462/9.2 MB corpus hard-wedged the
    // watch). We stop the install at this budget and run search over the stored
    // prefix (the most-popular articles, since chunks arrive id/popularity order).
    // 9 MB: the 1000-article corpus (5.9 MB) installed fine, so this admits it in
    // full while staying below the catastrophic 9.2 MB point.
    const STORAGE_BUDGET_BYTES = 9000000;

    // Estimate the UTF-8 byte size of a STORED body from its character length.
    // Since M10.1 the corpus is compressed: bodies are stored as base64 (ASCII,
    // 1 byte/char), so the stored UTF-8 byte count equals the char count. (Before
    // compression, plain-Hebrew bodies were ~2 bytes/char and this returned 2x —
    // but on the compressed corpus 2x over-counts and falsely trips
    // STORAGE_BUDGET_BYTES at ~half a large corpus.) Used to accumulate install
    // bytes against the budget without allocating a UTF-8 array per body in the
    // install hot path.
    function estimateBytes(charLen as Number) as Number {
        return charLen;
    }

    // True once the running install byte total has reached the storage budget —
    // the install should stop writing further chunks (graceful partial install).
    function shouldStopAtBudget(bytesWritten as Number) as Boolean {
        return bytesWritten >= STORAGE_BUDGET_BYTES;
    }

    // Insert n into a sorted Array<Number> with no duplicates. Returns a NEW
    // array (does not mutate the input). Maintains the "chunks received so
    // far" bitmap as each chunk lands.
    function sortedInsert(arr as Array<Number>, n as Number) as Array<Number> {
        var out = [] as Array<Number>;
        var inserted = false;
        for (var i = 0; i < arr.size(); i++) {
            var v = arr[i];
            if (v == n) {
                return arr.slice(0, null);  // already present — return a copy unchanged
            }
            if (!inserted && n < v) {
                out.add(n);
                inserted = true;
            }
            out.add(v);
        }
        if (!inserted) {
            out.add(n);
        }
        return out;
    }

    // Lowest chunk index in [0, chunkCount) that is NOT in `received`.
    // Returns -1 if every chunk is present.
    function firstMissing(received as Array<Number>, chunkCount as Number) as Number {
        for (var i = 0; i < chunkCount; i++) {
            if (!_contains(received, i)) {
                return i;
            }
        }
        return -1;
    }

    // All chunk indices in [0, chunkCount) not in `received`, ascending.
    function missingChunks(received as Array<Number>, chunkCount as Number) as Array<Number> {
        var out = [] as Array<Number>;
        for (var i = 0; i < chunkCount; i++) {
            if (!_contains(received, i)) {
                out.add(i);
            }
        }
        return out;
    }

    // How many new requests to fire right now: clamp (maxInFlight - inFlight)
    // to the number of remaining items, never negative.
    function slotsToFill(inFlight as Number, maxInFlight as Number, remaining as Number) as Number {
        var free = maxInFlight - inFlight;
        if (free < 0) { free = 0; }
        if (free > remaining) { free = remaining; }
        return free;
    }

    // True once every chunk has been received.
    function isComplete(receivedCount as Number, chunkCount as Number) as Boolean {
        return receivedCount >= chunkCount;
    }

    // True if a partial install for localVersion is stale against the
    // server's remoteVersion (server bumped the corpus mid-install).
    function shouldInvalidate(localVersion as Number, remoteVersion as Number) as Boolean {
        return localVersion < remoteVersion;
    }

    // Self-regulating in-flight cap: under memory pressure (free heap below
    // the MEM_PRESSURE_BYTES threshold) we only allow 1 concurrent chunk
    // request (peak ~190 KB) instead of 2 (peak ~270 KB). Pure so the
    // threshold is unit-testable; the view passes System freeMemory.
    function maxInFlightForMemory(freeBytes as Number) as Number {
        if (freeBytes < MEM_PRESSURE_BYTES) { return 1; }
        if (freeBytes < MEM_AMPLE_BYTES) { return 2; }
        return MAX_IN_FLIGHT;
    }

    // M10.6: adaptive back-off. On a -101 (BLE_QUEUE_FULL) the install lowers
    // its in-flight ceiling by one (4 -> 3 -> 2), never below MIN_IN_FLIGHT, so
    // concurrency self-tunes to whatever the watch's BLE stack can sustain.
    function backoffMaxInFlight(current as Number) as Number {
        var n = current - 1;
        return n < MIN_IN_FLIGHT ? MIN_IN_FLIGHT : n;
    }

    // M10.8: the install's live in-flight ceiling — the lower of the memory tier
    // and the persistent -101 back-off ceiling. Pure so InstallView can apply it
    // each tick AND show the effective concurrency on the telemetry HUD.
    function effectiveMaxInFlight(memoryMax as Number, backoffCeiling as Number) as Number {
        return memoryMax < backoffCeiling ? memoryMax : backoffCeiling;
    }

    // M8.3 self-heal: up to `n` evenly-spaced indices in [0, count) for spot-
    // checking that the installed corpus actually has bodies (cheap O(1)
    // integrity probe at launch — full count would be too many getValue calls).
    // Always includes 0 and count-1 when count > 1; deduped + ascending.
    function sampleIndices(count as Number, n as Number) as Array<Number> {
        var out = [] as Array<Number>;
        if (count <= 0) { return out; }
        if (count <= n) {
            for (var i = 0; i < count; i++) { out.add(i); }
            return out;
        }
        var last = -1;
        for (var k = 0; k < n; k++) {
            // round(k * (count-1) / (n-1)) — evenly spaced, includes 0 and count-1.
            var idx = ((k * (count - 1).toFloat() / (n - 1)) + 0.5).toNumber();
            if (idx != last) { out.add(idx); last = idx; }
        }
        return out;
    }

    function _contains(arr as Array<Number>, n as Number) as Boolean {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == n) { return true; }
        }
        return false;
    }
}
