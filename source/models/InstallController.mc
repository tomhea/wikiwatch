import Toybox.Lang;

// M8 pure install orchestration state machine. Holds the mutable bookkeeping
// for the parallel chunk-download install: which chunks are received, which
// are in-flight, which permanently failed after exhausting retries, and how
// many articles have been written. The InstallView wires this to the real
// Downloader / ArticleStore / InstallState side effects; this class itself
// touches NO Storage / Network / UI / System clocks, so the whole scheduling
// + retry + completion logic is unit-testable in isolation.
//
// Delegates pure set-math (sorted insert, missing chunks) to InstallPlan.
//
// Lifecycle the view drives per event-loop turn:
//   var fire = ctrl.nextToFire();          // chunk indices to request now
//   ... for each n: Downloader.fetchChunk(n, cb) ...
//   // on success callback (AFTER putBatch + markChunkReceived):
//   ctrl.onSuccess(n, articleCount);
//   // on failure callback:
//   ctrl.onFailure(n);
//   if (ctrl.isComplete()) { ... markComplete + switch to keyboard ... }
//
// R6: imports only Toybox.Lang (+ the pure InstallPlan module).
class InstallController {
    public const MAX_ATTEMPTS = 3;

    // M9.5 (D1): per-chunk state for O(1) eligibility, replacing the O(received)
    // `indexOf` scans the old _received/_inFlight/_failed arrays needed on every
    // eligibility check (which made nextToFire O(chunkCount x received) per
    // callback). State codes:
    private const ST_ELIGIBLE = 0;
    private const ST_RECEIVED = 1;
    private const ST_INFLIGHT = 2;
    private const ST_FAILED   = 3;

    private var _chunkCount as Number;
    private var _maxInFlight as Number;
    private var _state as Array<Number>;         // per-chunk ST_* code
    private var _receivedCount as Number;
    private var _inFlightCount as Number;
    private var _failedCount as Number;
    private var _attempts as Dictionary;         // chunkIdx -> attempt count
    private var _articlesWritten as Number;

    // alreadyReceived seeds a resume (from InstallState.getChunksReceived()).
    function initialize(chunkCount as Number, alreadyReceived as Array<Number>, maxInFlight as Number) {
        _chunkCount = chunkCount;
        _maxInFlight = maxInFlight;
        _state = new [chunkCount];
        for (var i = 0; i < chunkCount; i++) { _state[i] = ST_ELIGIBLE; }
        _receivedCount = 0;
        _inFlightCount = 0;
        _failedCount = 0;
        _attempts = {};
        _articlesWritten = 0;
        for (var i = 0; i < alreadyReceived.size(); i++) {
            var n = alreadyReceived[i] as Number;
            if (n >= 0 && n < chunkCount && _state[n] != ST_RECEIVED) {
                _state[n] = ST_RECEIVED;
                _receivedCount++;
            }
        }
    }

    function setMaxInFlight(n as Number) as Void {
        _maxInFlight = n;
    }

    // Chunk indices to request right now (lowest-first), respecting the
    // in-flight cap. Marks the returned indices in-flight. O(chunkCount) — no
    // per-element membership scans.
    function nextToFire() as Array<Number> {
        var freeSlots = _maxInFlight - _inFlightCount;
        if (freeSlots <= 0) {
            return [] as Array<Number>;
        }
        var fire = [] as Array<Number>;
        for (var i = 0; i < _chunkCount && fire.size() < freeSlots; i++) {
            if (_state[i] == ST_ELIGIBLE) {
                fire.add(i);
                _state[i] = ST_INFLIGHT;
                _inFlightCount++;
            }
        }
        return fire;
    }

    // A chunk's articles are durably written. articleCount feeds the progress
    // counter (articles, not chunks — see plan progress UI).
    function onSuccess(n as Number, articleCount as Number) as Void {
        if (n < 0 || n >= _chunkCount) { return; }
        if (_state[n] == ST_INFLIGHT) { _inFlightCount--; }
        if (_state[n] != ST_RECEIVED) {
            _state[n] = ST_RECEIVED;
            _receivedCount++;
        }
        _articlesWritten += articleCount;
    }

    // A chunk request failed. Re-queues it (eligible again) until MAX_ATTEMPTS,
    // then marks it permanently failed so the install can still complete with
    // a degraded corpus.
    function onFailure(n as Number) as Void {
        if (n < 0 || n >= _chunkCount) { return; }
        if (_state[n] == ST_INFLIGHT) { _inFlightCount--; }
        var prior = _attempts.hasKey(n) ? (_attempts[n] as Number) : 0;
        var attempts = prior + 1;
        _attempts[n] = attempts;
        if (attempts >= MAX_ATTEMPTS) {
            if (_state[n] != ST_FAILED) {
                _state[n] = ST_FAILED;
                _failedCount++;
            }
        } else {
            _state[n] = ST_ELIGIBLE;   // retry later
        }
    }

    // M10.6: re-queue a chunk WITHOUT counting an attempt. Used for rc=-101
    // (BLE queue full) — a transient "try again", not a real failure. Releases
    // the in-flight slot and re-arms the chunk as eligible, leaving its attempt
    // count untouched so a queue-full storm can't exhaust MAX_ATTEMPTS.
    function markRequeue(n as Number) as Void {
        if (n < 0 || n >= _chunkCount) { return; }
        if (_state[n] == ST_INFLIGHT) { _inFlightCount--; }
        // Re-arm only if not already terminal — a received/failed chunk stays put.
        if (_state[n] != ST_RECEIVED && _state[n] != ST_FAILED) {
            _state[n] = ST_ELIGIBLE;
        }
        // NOTE: _attempts deliberately untouched — a -101 is not a real failure.
    }

    // Every chunk has reached a terminal state (received or permanently
    // failed) and nothing is still in flight.
    function isComplete() as Boolean {
        return (_receivedCount + _failedCount) >= _chunkCount
            && _inFlightCount == 0;
    }

    function articlesWritten() as Number {
        return _articlesWritten;
    }

    function receivedCount() as Number {
        return _receivedCount;
    }

    function inFlightCount() as Number {
        return _inFlightCount;
    }

    function attemptsFor(n as Number) as Number {
        return _attempts.hasKey(n) ? (_attempts[n] as Number) : 0;
    }
}
