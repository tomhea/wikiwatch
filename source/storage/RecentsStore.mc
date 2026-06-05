import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

// M10.4 persistence for the recently-read list (the pure list logic is Recents,
// models/). Stored under one Application.Storage key as two parallel String arrays
// { "ids" => [...], "titles" => [...] } (most-recent first) — primitive arrays
// avoid any Symbol-key serialization issue, and the whole value is tiny (<= CAP
// short id/title pairs). Impure (Application.Storage + System) so it lives under
// storage/, not models/.
module RecentsStore {
    const CAP = 12;          // keep the last 12 opened articles
    const _KEY = "recents";

    // The recently-read list as Array<{ :id, :title }>, most-recent first. Empty
    // before anything has been opened (or after a corpus wipe).
    function load() as Array {
        var raw = Application.Storage.getValue(_KEY);
        if (raw == null) { return []; }
        var d = raw as Dictionary;
        var ids = d["ids"] as Array?;
        var titles = d["titles"] as Array?;
        if (ids == null || titles == null) { return []; }
        var out = [];
        var n = (ids.size() < titles.size()) ? ids.size() : titles.size();
        for (var i = 0; i < n; i++) {
            out.add({ :id => ids[i] as String, :title => titles[i] as String });
        }
        return out;
    }

    // Record that (id, title) was just opened: move it to the front, dedup, cap.
    function record(id as String, title as String) as Void {
        _save(Recents.add(load(), id, title, CAP));
    }

    // Drop the list (called on a corpus wipe/reinstall — ids may no longer map).
    function clear() as Void {
        Application.Storage.deleteValue(_KEY);
    }

    function _save(list as Array) as Void {
        var ids = [];
        var titles = [];
        var est = 0;
        for (var i = 0; i < list.size(); i++) {
            var e = list[i] as Dictionary;
            var id = e[:id] as String;
            var title = e[:title] as String;
            ids.add(id);
            titles.add(title);
            est += (id.length() + title.length()) * 4 + 16;
        }
        // R4: guard the setValue with >= 3x the value's byte estimate free.
        if (System.getSystemStats().freeMemory < 3 * est) { return; }
        Application.Storage.setValue(_KEY, { "ids" => ids, "titles" => titles });
    }
}
