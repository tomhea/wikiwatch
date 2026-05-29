import Toybox.Application;
import Toybox.Lang;

// M8 install-lifecycle persistence. Three Storage keys track an install so it
// survives app-close / power-off / crash mid-download and resumes on next
// launch. Algorithmic decisions (sorted-insert into the received-set, etc.)
// delegate to the pure InstallPlan module.
//
//   installState           "none" | "in_progress" | "complete"
//   installManifestVersion the manifest version this install is for
//   installChunksReceived  sorted Array<Number> of chunk indices written
//
// Lives in source/storage/ (imports Application). The received-set is updated
// AFTER a chunk's articles are durably written, so a crash mid-callback
// re-downloads at most one chunk (idempotent overwrite) rather than leaving
// the bitmap ahead of the data.
module InstallState {
    const KEY_STATE   = "installState";
    const KEY_VERSION = "installManifestVersion";
    const KEY_CHUNKS  = "installChunksReceived";

    const STATE_NONE        = "none";
    const STATE_IN_PROGRESS = "in_progress";
    const STATE_COMPLETE    = "complete";

    function getState() as String {
        var s = Application.Storage.getValue(KEY_STATE) as String?;
        return s == null ? STATE_NONE : s;
    }

    function getManifestVersion() as Number {
        var v = Application.Storage.getValue(KEY_VERSION) as Number?;
        return v == null ? 0 : v;
    }

    function getChunksReceived() as Array<Number> {
        var c = Application.Storage.getValue(KEY_CHUNKS) as Array<Number>?;
        return c == null ? ([] as Array<Number>) : c;
    }

    // Begin (or restart) an install for the given version: state=in_progress,
    // version recorded, received-set cleared. NOT called on resume.
    //
    // R4: the three values are tiny (a short String, a Number, an empty
    // Array) — well under the freeMemory floor; the guard would be noise, so
    // we set directly. (Subsequent chunk-index inserts grow the array to at
    // most chunkCount Numbers ~ 100 × 4 B = 400 B; still trivial.)
    function begin(version as Number) as Void {
        Application.Storage.setValue(KEY_STATE, STATE_IN_PROGRESS);
        Application.Storage.setValue(KEY_VERSION, version);
        Application.Storage.setValue(KEY_CHUNKS, [] as Array<Number>);
    }

    // Record one chunk as durably written (sorted-insert, idempotent). The
    // sorted-insert math lives in the pure InstallPlan module.
    function markChunkReceived(n as Number) as Void {
        var updated = InstallPlan.sortedInsert(getChunksReceived(), n);
        Application.Storage.setValue(KEY_CHUNKS, updated);
    }

    function markComplete() as Void {
        Application.Storage.setValue(KEY_STATE, STATE_COMPLETE);
    }

    // Wipe all install-state keys back to "none".
    function reset() as Void {
        Application.Storage.deleteValue(KEY_STATE);
        Application.Storage.deleteValue(KEY_VERSION);
        Application.Storage.deleteValue(KEY_CHUNKS);
    }
}
