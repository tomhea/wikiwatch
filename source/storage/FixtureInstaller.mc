import Toybox.Lang;
import Toybox.System;

// M4 glue: writes the Fixtures manifest + each fixture body into
// Application.Storage on first launch. Idempotent (no-op on subsequent
// launches once Manifest.isEmpty() returns false).
//
// Called once per app lifecycle from wikiwatchApp.onStart.
//
// System.println output is the R2 evidence for this storage-layer
// milestone (no UX change). Once-per-launch, harmless to leave in.
module FixtureInstaller {
    function installIfEmpty() as Number {
        var startEmpty = Manifest.isEmpty();
        var startIds = Manifest.articleIds();
        System.println("M4 install: startEmpty=" + startEmpty + " startIds=" + startIds.toString());
        if (!startEmpty) {
            System.println("M4 install: SKIP (manifest already populated)");
            return 0;
        }
        var m = Fixtures.manifest();
        if (!Manifest.save(m)) {
            System.println("M4 install: ABORT (Manifest.save failed; R4 freeMemory guard)");
            return 0;
        }
        var ids = Manifest.articleIds();
        var count = 0;
        for (var i = 0; i < ids.size(); i++) {
            var id = ids[i] as String;
            var body = Fixtures.bodyOf(id);
            if (body != null && ArticleStore.putBody(id, body)) {
                count++;
            }
        }
        System.println("M4 install: DONE installed=" + count + " of " + ids.size());
        return count;
    }
}
