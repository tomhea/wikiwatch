import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M7 InstallView — full-corpus download view.
//
// Two entry paths:
//   1. First launch (no local manifest) — direct push from wikiwatchApp.
//   2. User confirmed "yes, update" — push from UpdatePromptView after
//      Manifest.wipeArticles() has cleared old article bodies.
//
// Flow:
//   onShow -> Downloader.fetchManifest(...)
//   onManifest -> parseManifestResponse -> Manifest.save -> begin per-article fetches
//   onArticle  -> ArticleStore.putBody -> if more, fetch next; else switchToView(KeyboardView)
//
// Each fetch is sequential — InstallView holds at most one body in memory
// at a time (the just-fetched one). KB delegate's article-array gets the
// rebuilt manifest when the user lands on the keyboard.
//
// On error (network failure mid-download): logs + advances to the next
// article anyway. Final summary "installed N of M" is shown briefly before
// switching to the keyboard.
class InstallView extends WatchUi.View {
    private var _status as String;
    private var _progress as Number;        // articles installed so far
    private var _total as Number;           // total articles to install
    private var _ids as Array<String>;      // ordered ids to install
    private var _cursor as Number;          // index of next id to fetch
    private var _installedCount as Number;
    private var _errorCount as Number;
    private var _switching as Boolean;      // guard against double-switch

    function initialize() {
        View.initialize();
        _status = "Loading wikiwatch...";
        _progress = 0;
        _total = 0;
        _ids = new [0];
        _cursor = 0;
        _installedCount = 0;
        _errorCount = 0;
        _switching = false;
    }

    function onShow() as Void {
        View.onShow();
        System.println("M7 install: fetching manifest from " + Downloader.BASE_URL);
        Downloader.fetchManifest(method(:onManifestReceived));
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 20, Graphics.FONT_TINY,
                    _status,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_total > 0) {
            dc.drawText(w / 2, h / 2 + 20, Graphics.FONT_SMALL,
                        _progress + " / " + _total,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Manifest fetch callback — first stage.
    function onManifestReceived(rc as Number, data as Dictionary?) as Void {
        var parsed = Downloader.parseManifestResponse(rc, data);
        if (parsed[:ok] != true) {
            System.println("M7 install: manifest fetch FAILED — " + parsed[:error]);
            _status = "No network. Try later.";
            WatchUi.requestUpdate();
            _scheduleSwitchToKeyboard(2000);
            return;
        }
        var manifest = parsed[:manifest] as Dictionary;
        var arts = manifest[:articles] as Array;
        if (arts.size() == 0) {
            System.println("M7 install: manifest had 0 articles");
            _status = "Empty corpus.";
            WatchUi.requestUpdate();
            _scheduleSwitchToKeyboard(2000);
            return;
        }
        // Save manifest now so partial-install state is recoverable on
        // re-launch (we know which articles SHOULD be present).
        if (!Manifest.save(manifest)) {
            System.println("M7 install: Manifest.save failed (R4 freeMemory guard)");
            _status = "Out of memory.";
            WatchUi.requestUpdate();
            _scheduleSwitchToKeyboard(2000);
            return;
        }
        _ids = Manifest.articleIds();
        _total = _ids.size();
        _progress = 0;
        _cursor = 0;
        _status = "Loading wikiwatch:";
        WatchUi.requestUpdate();
        _fetchNext();
    }

    // Drive the per-article fetch loop. Each fetch's callback invokes
    // _fetchNext after writing the body, until _cursor reaches _total.
    private function _fetchNext() as Void {
        if (_cursor >= _total) {
            // Done.
            System.println("M7 install: DONE installed=" + _installedCount
                + " errors=" + _errorCount + " of " + _total);
            _switchToKeyboard();
            return;
        }
        var id = _ids[_cursor] as String;
        Downloader.fetchArticle(id, method(:onArticleReceived));
    }

    function onArticleReceived(rc as Number, body as String?) as Void {
        var id = _ids[_cursor] as String;
        if (rc == 200 && body != null) {
            if (ArticleStore.putBody(id, body as String)) {
                _installedCount++;
            } else {
                System.println("M7 install: putBody FAILED for " + id + " (R4 guard)");
                _errorCount++;
            }
        } else {
            System.println("M7 install: article fetch FAILED " + id + " rc=" + rc);
            _errorCount++;
        }
        _progress++;
        _cursor++;
        WatchUi.requestUpdate();
        _fetchNext();
    }

    // Delayed switch (gives the user 2s to read an error message).
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

class InstallDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // M7: ignore taps + back during install. The view auto-switches when
    // done. Future: a "cancel install" button. For M7, just block.
    function onTap(event as WatchUi.ClickEvent) as Boolean { return true; }
    function onBack() as Boolean { return true; }
}
