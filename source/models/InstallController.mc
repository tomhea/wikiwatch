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

    private var _chunkCount as Number;
    private var _maxInFlight as Number;
    private var _received as Array<Number>;     // durably written, sorted
    private var _inFlight as Array<Number>;      // currently requested
    private var _failed as Array<Number>;        // permanently failed (retries gone)
    private var _attempts as Dictionary;         // chunkIdx -> attempt count
    private var _articlesWritten as Number;

    // alreadyReceived seeds a resume (from InstallState.getChunksReceived()).
    function initialize(chunkCount as Number, alreadyReceived as Array<Number>, maxInFlight as Number) {
        _chunkCount = chunkCount;
        _maxInFlight = maxInFlight;
        _received = alreadyReceived;
        _inFlight = [];
        _failed = [];
        _attempts = {};
        _articlesWritten = 0;
    }

    function setMaxInFlight(n as Number) as Void {
        _maxInFlight = n;
    }

    // Chunk indices to request right now (lowest-first), respecting the
    // in-flight cap. Marks the returned indices in-flight.
    function nextToFire() as Array<Number> {
        var freeSlots = _maxInFlight - _inFlight.size();
        if (freeSlots <= 0) {
            return [] as Array<Number>;
        }
        var fire = [] as Array<Number>;
        for (var i = 0; i < _chunkCount && fire.size() < freeSlots; i++) {
            if (_isEligible(i)) {
                fire.add(i);
                _inFlight.add(i);
            }
        }
        return fire;
    }

    // A chunk's articles are durably written. articleCount feeds the progress
    // counter (articles, not chunks — see plan progress UI).
    function onSuccess(n as Number, articleCount as Number) as Void {
        _inFlight.remove(n);
        _received = InstallPlan.sortedInsert(_received, n);
        _articlesWritten += articleCount;
    }

    // A chunk request failed. Re-queues it (eligible again) until MAX_ATTEMPTS,
    // then marks it permanently failed so the install can still complete with
    // a degraded corpus.
    function onFailure(n as Number) as Void {
        _inFlight.remove(n);
        var prior = _attempts.hasKey(n) ? (_attempts[n] as Number) : 0;
        var attempts = prior + 1;
        _attempts[n] = attempts;
        if (attempts >= MAX_ATTEMPTS) {
            _failed = InstallPlan.sortedInsert(_failed, n);
        }
        // else: not in _received / _inFlight / _failed -> eligible again.
    }

    // Every chunk has reached a terminal state (received or permanently
    // failed) and nothing is still in flight.
    function isComplete() as Boolean {
        return (_received.size() + _failed.size()) >= _chunkCount
            && _inFlight.size() == 0;
    }

    function articlesWritten() as Number {
        return _articlesWritten;
    }

    function receivedCount() as Number {
        return _received.size();
    }

    function inFlightCount() as Number {
        return _inFlight.size();
    }

    function attemptsFor(n as Number) as Number {
        return _attempts.hasKey(n) ? (_attempts[n] as Number) : 0;
    }

    // Eligible = a real chunk index not yet received, not in flight, not
    // permanently failed.
    private function _isEligible(i as Number) as Boolean {
        return _received.indexOf(i) < 0
            && _inFlight.indexOf(i) < 0
            && _failed.indexOf(i) < 0;
    }
}
