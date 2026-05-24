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
