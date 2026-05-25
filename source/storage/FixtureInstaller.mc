import Toybox.Lang;
import Toybox.System;

// M4 glue: writes the Fixtures manifest + each fixture body into
// Application.Storage on first launch. M5.2 made it version-aware so
// that bumping Fixtures.manifest()[:version] from N -> N+1 triggers
// an automatic re-install on next launch (no manual sim wipe).
//
// Migration logic: install when Manifest.isEmpty() OR the persisted
// :version differs from the fixture's :version. Otherwise no-op.
//
// Called once per app lifecycle from wikiwatchApp.onStart.
//
// System.println output is the R2 evidence for this storage-layer
// milestone (no UX change). Once-per-launch, harmless to leave in.
module FixtureInstaller {
    function installIfEmpty() as Number {
        var current = Manifest.load();
        var currentVersion = current[:version] as Number;
        var targetVersion = Fixtures.manifest()[:version] as Number;
        var startIds = Manifest.articleIds();
        var isEmpty = Manifest.isEmpty();
        System.println("M4 install: startEmpty=" + isEmpty
            + " currentVersion=" + currentVersion
            + " targetVersion=" + targetVersion
            + " startIds=" + startIds.toString());
        if (!isEmpty && currentVersion == targetVersion) {
            System.println("M4 install: SKIP (manifest already at target version)");
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
