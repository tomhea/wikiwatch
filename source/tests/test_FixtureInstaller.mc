import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// M4 end-to-end tests: FixtureInstaller writes Fixtures into Storage via
// Manifest + ArticleStore.

(:test)
function installer_freshInstallPopulatesManifest(logger as Logger) as Boolean {
    _cleanFixtureStorage();
    var n = FixtureInstaller.installIfEmpty();
    var ids = Manifest.articleIds();
    var firstBody = (ids.size() > 0) ? ArticleStore.bodyOf(ids[0] as String) : null;
    _cleanFixtureStorage();
    logger.debug("install n=" + n + " ids=" + ids.toString()
        + " firstBodyLen=" + (firstBody == null ? -1 : firstBody.length()));
    return n >= 3 && ids.size() >= 3 && firstBody != null && firstBody.length() > 0;
}

(:test)
function installer_secondCallReturnsZero(logger as Logger) as Boolean {
    _cleanFixtureStorage();
    var n1 = FixtureInstaller.installIfEmpty();
    var n2 = FixtureInstaller.installIfEmpty();
    _cleanFixtureStorage();
    logger.debug("first=" + n1 + " second=" + n2);
    return n1 >= 3 && n2 == 0;
}

(:test)
function installer_reinstallsOnVersionBump(logger as Logger) as Boolean {
    // M5.2 migration path: an older-version manifest (e.g. left by M4/M5)
    // should be detected and overwritten by installIfEmpty on next launch.
    // Pre-seed the Storage with a single old-version article, then call
    // installIfEmpty and verify it re-ran (non-zero return + new IDs).
    _cleanFixtureStorage();
    Application.Storage.setValue("manifest", {
        "version" => 1,
        "articles" => [{ "id" => "stale", "title" => "stale", "popularity" => 0 }]
    });
    var n = FixtureInstaller.installIfEmpty();
    var ids = Manifest.articleIds();
    var firstId = (ids.size() > 0) ? (ids[0] as String) : "";
    _cleanFixtureStorage();
    logger.debug("after-version-bump n=" + n + " size=" + ids.size() + " firstId=" + firstId);
    // n>=3 = at least the M4 baseline; firstId != "stale" = old manifest replaced.
    return n >= 3 && ids.size() >= 3 && !firstId.equals("stale");
}

// Helper: wipe the manifest key + every fixture article key so each test
// starts from a known-empty Storage state. Not annotated (:test) so the
// harness does NOT call it as a test.
function _cleanFixtureStorage() as Void {
    Application.Storage.deleteValue("manifest");
    var arts = Fixtures.manifest()[:articles] as Array;
    for (var i = 0; i < arts.size(); i++) {
        var a = arts[i] as Dictionary;
        Application.Storage.deleteValue("article:" + (a[:id] as String));
    }
}
