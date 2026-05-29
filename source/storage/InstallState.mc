import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

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

    // R4: every setValue is preceded by a freeMemory check proving >= 3x the
    // value size is free. These values are small, but R4 is unconditional —
    // OOM in Monkey C is uncatchable, so we never write without the guard.
    // Returns false (write skipped) if memory is too low; callers treat a
    // skipped bitmap write as "chunk not marked" (safe — it re-downloads on
    // resume, idempotent).
    function _guardedSet(key as String, value as Application.PropertyValueType, estBytes as Number) as Boolean {
        if (System.getSystemStats().freeMemory < estBytes * 3) {
            System.println("M8 InstallState: setValue skipped (low memory) key=" + key);
            return false;
        }
        Application.Storage.setValue(key, value);
        return true;
    }

    // Begin (or restart) an install for the given version: state=in_progress,
    // version recorded, received-set cleared. NOT called on resume.
    function begin(version as Number) as Void {
        _guardedSet(KEY_STATE, STATE_IN_PROGRESS, 16);
        _guardedSet(KEY_VERSION, version, 8);
        _guardedSet(KEY_CHUNKS, [] as Array<Number>, 16);
    }

    // Record one chunk as durably written (sorted-insert, idempotent). The
    // sorted-insert math lives in the pure InstallPlan module.
    function markChunkReceived(n as Number) as Void {
        var updated = InstallPlan.sortedInsert(getChunksReceived(), n);
        // Each chunk index is a Number (~4-8 B) + small Array overhead.
        _guardedSet(KEY_CHUNKS, updated, updated.size() * 8 + 32);
    }

    function markComplete() as Void {
        _guardedSet(KEY_STATE, STATE_COMPLETE, 16);
    }

    // Wipe all install-state keys back to "none".
    function reset() as Void {
        Application.Storage.deleteValue(KEY_STATE);
        Application.Storage.deleteValue(KEY_VERSION);
        Application.Storage.deleteValue(KEY_CHUNKS);
    }
}
