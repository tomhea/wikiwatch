import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// M10.3: eagerly parse the baked compression model in the BACKGROUND once the
// keyboard (the steady-state interactive screen) is up, so the FIRST compressed
// article you open streams immediately instead of paying the one-time ~1 s parse
// through the DecodeView gate.
//
// Watchdog/boot safety:
//   - The parse is sliced across Timer ticks (CompModel.parseSlice, same per-tick
//     budget as the gate), so no single handler trips the watchdog.
//   - It shares CompModel's SINGLE parse state with the gate, so opening an
//     article mid-warm never double-parses / double-allocates the ~137 KB model.
//   - It is started only from the keyboard's onShow, AFTER BootGuard.noteReady —
//     i.e. after the heavy index load already survived — so it adds no boot risk.
//   - Self-protecting: if free heap is tight the slice is refused (:lowmem) and
//     warming stops; the on-open gate remains the fallback, and the next keyboard
//     onShow retries.
//
// Impure (Timer/System) → lives in source/, not models/. The parse logic it drives
// is the testable CompModel.parseSlice; this is a thin driver.
class ModelWarmer {
    // 1000 table-fills/tick matches the gate's proven-safe parse slice; 100 ms
    // cadence keeps it gentle so it doesn't compete with keypress handling. The
    // full parse is ~1–2 s of idle ticks — well within the time it takes to type a
    // query and tap a result.
    private const _ITEMS_PER_TICK = 1000;
    private const _TICK_MS = 100;

    private var _timer as Timer.Timer?;
    private var _active as Boolean;

    function initialize() {
        _timer = null;
        _active = false;
    }

    // Begin (or resume) background warming. Idempotent: a no-op if the model is
    // already parsed, warming is already running, or the corpus doesn't need the
    // model (plain). Safe to call on every keyboard onShow.
    function start() as Void {
        if (_active) { return; }
        if (CompModel.cachedModel() != null) { return; }
        if (!CompModel.corpusNeedsModel()) { return; }
        _active = true;
        _schedule();
    }

    // Pause warming (e.g. when the keyboard is hidden as an article opens). The
    // shared CompModel parse state is preserved, so the gate — or the next start()
    // — resumes from where this left off; no work is lost.
    function stop() as Void {
        _active = false;
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    private function _schedule() as Void {
        if (_timer != null) { return; }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), _TICK_MS, false);
    }

    function onTick() as Void {
        _timer = null;
        if (!_active) { return; }
        var st = CompModel.parseSlice(_ITEMS_PER_TICK);
        if (st == :more) {
            _schedule();                 // keep warming
            return;
        }
        // :done (cached), :lowmem (retry on next keyboard onShow), :unreadable.
        _active = false;
        if (st == :done) {
            System.println("M10.3 warm: model parsed eagerly (no open-gate needed)");
        } else {
            System.println("M10.3 warm: stopped (" + st + ")");
        }
    }
}
