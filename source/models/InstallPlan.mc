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
        return freeBytes < MEM_PRESSURE_BYTES ? 1 : 2;
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
