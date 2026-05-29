import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M8 InstallView — parallel chunked-download install.
//
// Replaces M7's sequential per-article fetch with a chunked download that is
// unpacked into the SAME per-article Storage layout (article:<id>), so steady-
// state reads stay M7-fast. The scheduling / retry / completion math lives in
// the pure InstallController (unit-tested); this view wires it to the real
// Downloader / ArticleStore / InstallState side effects + renders progress.
//
// Entry contexts (constructor `resuming` flag):
//   false — first launch OR user-accepted update. onManifestReceived wipes the
//           old corpus + begins a fresh install (InstallState.begin).
//   true  — resume after an interrupted install. Seeds the controller from
//           InstallState.getChunksReceived(); re-checks the remote version and
//           discards the partial corpus if the server bumped it mid-install.
//
// Flow:
//   onShow -> Downloader.fetchManifest
//   onManifestReceived -> (wipe/begin or resume/invalidate) -> build controller
//                      -> _fireChunks (up to maxInFlight)
//   onChunkResult(n,..) -> putBatch (durable) -> markChunkReceived -> controller
//                      -> battery/memory checks -> fire next OR complete
//
// Crash safety: putBatch (articles durable) ALWAYS precedes markChunkReceived
// (bitmap). A crash mid-callback re-downloads at most one chunk on resume —
// idempotent because setValue overwrites.
class InstallView extends WatchUi.View {
    // Poll battery once per this many chunk callbacks (not every chunk —
    // System.getSystemStats() isn't free; see plan "Battery monitoring").
    private const BATTERY_CHECK_EVERY = 10;

    private var _resuming as Boolean;
    private var _ctrl as InstallController?;
    private var _pattern as String;
    private var _chunkCount as Number;
    private var _total as Number;            // total articles (progress denominator)
    private var _perChunk as Number;         // est. articles/chunk (resume display)
    private var _status as String;
    private var _started as Boolean;         // controller built + chunks flowing
    private var _switching as Boolean;
    private var _paused as Boolean;
    private var _chunksUntilBatteryCheck as Number;

    function initialize(resuming as Boolean) {
        View.initialize();
        _resuming = resuming;
        _ctrl = null;
        _pattern = "/chunk/{n}.json";
        _chunkCount = 0;
        _total = 0;
        _perChunk = 1;
        _status = resuming ? "Resuming..." : "Loading wikiwatch...";
        _started = false;
        _switching = false;
        _paused = false;
        _chunksUntilBatteryCheck = BATTERY_CHECK_EVERY;
    }

    function onShow() as Void {
        View.onShow();
        if (_started || _switching) { return; }
        System.println("M8 install: resuming=" + _resuming + " fetching manifest");
        Downloader.fetchManifest(method(:onManifestReceived));
    }

    // --- stage 1: manifest ---------------------------------------------------

    function onManifestReceived(rc as Number, data as Dictionary?) as Void {
        var parsed = Downloader.parseManifestResponse(rc, data);
        if (parsed[:ok] != true) {
            System.println("M8 install: manifest fetch FAILED — " + parsed[:error]);
            _status = "No network. Try later.";
            WatchUi.requestUpdate();
            _scheduleSwitchToKeyboard(2000);
            return;
        }
        var manifest = parsed[:manifest] as Dictionary;
        var remoteVersion = manifest[:version] as Number;
        _chunkCount = manifest[:chunkCount] as Number;
        _pattern = manifest[:chunkUriPattern] as String;
        var arts = manifest[:articles] as Array;
        _total = arts.size();

        if (_chunkCount <= 0) {
            System.println("M8 install: manifest chunkCount=0 (no chunked corpus)");
            _status = "Empty corpus.";
            WatchUi.requestUpdate();
            _scheduleSwitchToKeyboard(2000);
            return;
        }
        _perChunk = (_total + _chunkCount - 1) / _chunkCount;
        if (_perChunk < 1) { _perChunk = 1; }

        // Decide fresh vs resume vs invalidated-resume.
        var seedReceived = [] as Array<Number>;
        if (_resuming) {
            var localVersion = InstallState.getManifestVersion();
            if (InstallPlan.shouldInvalidate(localVersion, remoteVersion)) {
                System.println("M8 install: stale partial (local=" + localVersion
                    + " remote=" + remoteVersion + ") — wiping + restarting");
                _freshBegin(manifest, remoteVersion);
            } else {
                // Same version: keep the partial corpus, resume from bitmap.
                seedReceived = InstallState.getChunksReceived();
                System.println("M8 install: resume same-version, chunks_received="
                    + seedReceived.size() + "/" + _chunkCount);
            }
        } else {
            _freshBegin(manifest, remoteVersion);
        }

        var maxInFlight = InstallPlan.maxInFlightForMemory(
            System.getSystemStats().freeMemory);
        _ctrl = new InstallController(_chunkCount, seedReceived, maxInFlight);
        _started = true;
        _status = "Loading wikiwatch:";
        System.println("M8 install: begin chunks total=" + _chunkCount
            + " seeded=" + seedReceived.size() + " maxInFlight=" + maxInFlight);
        WatchUi.requestUpdate();
        _fireChunks();
    }

    // Save the new manifest, wipe the old corpus, reset install state. Used for
    // first-install, update-accept, and stale-resume restart.
    private function _freshBegin(manifest as Dictionary, version as Number) as Void {
        Manifest.wipeArticles();
        Manifest.save(manifest);
        InstallState.begin(version);
    }

    // --- stage 2: chunk fetch loop ------------------------------------------

    private function _fireChunks() as Void {
        if (_ctrl == null || _paused) { return; }
        var ctrl = _ctrl as InstallController;
        var fire = ctrl.nextToFire();
        for (var i = 0; i < fire.size(); i++) {
            var n = fire[i];
            System.println("M8 install: fetch chunk " + n);
            var cb = new ChunkCallback(self, n);
            Downloader.fetchChunk(_pattern, n, cb.method(:onResult));
        }
    }

    // Per-chunk result. `n` is captured by the ChunkCallback, so we know which
    // chunk this is even when the request errored (data == null).
    function onChunkResult(n as Number, rc as Number, data as Dictionary?) as Void {
        if (_ctrl == null) { return; }
        var ctrl = _ctrl as InstallController;

        if (rc == 200 && data != null) {
            var arts = (data as Dictionary)["articles"] as Dictionary?;
            if (arts != null) {
                // Durable write FIRST, then mark the chunk received. A crash
                // between the two only re-downloads this chunk on resume.
                var written = ArticleStore.putBatch(arts as Dictionary);
                InstallState.markChunkReceived(n);
                ctrl.onSuccess(n, written);
                System.println("M8 install: chunk " + n + " ok, +" + written
                    + " arts (" + ctrl.receivedCount() + "/" + _chunkCount + ")");
            } else {
                System.println("M8 install: chunk " + n + " missing articles dict");
                ctrl.onFailure(n);
            }
        } else {
            System.println("M8 install: chunk " + n + " FAILED rc=" + rc
                + " attempt=" + (ctrl.attemptsFor(n) + 1));
            ctrl.onFailure(n);
        }
        // Release parsed dict before firing the next request so peak RAM
        // doesn't compound across in-flight chunks.
        data = null;

        // Self-regulate concurrency on current free memory.
        var freeMem = System.getSystemStats().freeMemory;
        ctrl.setMaxInFlight(InstallPlan.maxInFlightForMemory(freeMem));
        System.println("fm:" + freeMem);

        // Periodic battery check — pause (preserving state) if critically low.
        _chunksUntilBatteryCheck--;
        if (_chunksUntilBatteryCheck <= 0) {
            _chunksUntilBatteryCheck = BATTERY_CHECK_EVERY;
            var stats = System.getSystemStats();
            if (BatteryGate.shouldPause(stats.battery, stats.charging)) {
                System.println("M8 install: battery " + stats.battery
                    + "% — PAUSING install");
                _pauseToLowBattery();
                return;
            }
        }

        if (ctrl.isComplete()) {
            InstallState.markComplete();
            System.println("M8 install: COMPLETE received=" + ctrl.receivedCount()
                + "/" + _chunkCount + " articlesWritten=" + ctrl.articlesWritten());
            WatchUi.requestUpdate();
            _switchToKeyboard();
            return;
        }
        _fireChunks();
        WatchUi.requestUpdate();
    }

    // --- progress UI ---------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = w / 2;
        var pct = _percent();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 80, Graphics.FONT_SMALL, "wikiwatch",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Status line: once chunks are flowing this is the loading %, but
        // before then (manifest stage / error) it carries _status — the
        // "Resuming..." label or a fetch-failure message before we fall back.
        var statusLine = _started ? ("Loading: " + pct + "%") : _status;
        dc.drawText(cx, h / 2 - 44, Graphics.FONT_TINY, statusLine,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Progress chrome only appears once chunks are actually flowing — not
        // during the manifest stage or a fetch-error message.
        if (!_started) { return; }

        // "Don't close the app" warning in red.
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 16, Graphics.FONT_SMALL,
                    "Don't close the app",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Progress bar (outline + filled portion).
        var barW = (w * 6) / 10;        // 60% of display width
        var barH = 14;
        var barX = cx - barW / 2;
        var barY = h / 2 + 12;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barX, barY, barW, barH);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        var fillW = (barW * pct) / 100;
        if (fillW > 0) {
            dc.fillRectangle(barX, barY, fillW, barH);
        }

        // N / M articles counter.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 50, Graphics.FONT_TINY,
                    _articlesDisplay() + " / " + _total + " articles",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _percent() as Number {
        if (_ctrl == null || _chunkCount <= 0) { return 0; }
        var p = (_ctrl as InstallController).receivedCount() * 100 / _chunkCount;
        if (p > 100) { p = 100; }
        return p;
    }

    private function _articlesDisplay() as Number {
        if (_ctrl == null) { return 0; }
        var est = (_ctrl as InstallController).receivedCount() * _perChunk;
        if (est > _total) { est = _total; }
        return est;
    }

    // --- transitions ---------------------------------------------------------

    private function _pauseToLowBattery() as Void {
        if (_switching) { return; }
        _paused = true;
        _switching = true;
        var v = new LowBatteryView(true);   // resumed-install context
        WatchUi.switchToView(v, new LowBatteryDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    private function _scheduleSwitchToKeyboard(delayMs as Number) as Void {
        if (_switching) { return; }
        _switching = true;
        var timer = new Toybox.Timer.Timer();
        timer.start(method(:_switchToKeyboard), delayMs, false);
    }

    function _switchToKeyboard() as Void {
        var kb = new wikiwatchKeyboardView();
        var del = new wikiwatchKeyboardDelegate(kb, "");
        WatchUi.switchToView(kb, del, WatchUi.SLIDE_LEFT);
    }
}

// M8 ResumeInstallView — InstallView in resume mode. Pushed by the launch
// router when installState == "in_progress". Identical behaviour; the
// `resuming` flag drives the version-mismatch check + the "Resuming..."
// subtitle on first paint.
class ResumeInstallView extends InstallView {
    function initialize() {
        InstallView.initialize(true);
    }
}

// Bound per-chunk callback: carries the chunk index so the view's result
// handler knows which chunk resolved, even on a failed (data == null)
// response. Kept alive by makeWebRequest's reference to the Method until the
// response arrives.
class ChunkCallback {
    private var _view as InstallView;
    private var _n as Number;

    function initialize(view as InstallView, n as Number) {
        _view = view;
        _n = n;
    }

    function onResult(rc as Number, data as Dictionary?) as Void {
        _view.onChunkResult(_n, rc, data);
    }
}

class InstallDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Taps + back absorbed during install — the view auto-switches when done
    // (or pauses to LowBatteryView). "Don't close the app" tells the user why.
    function onTap(event as WatchUi.ClickEvent) as Boolean { return true; }
    function onBack() as Boolean { return true; }
}
