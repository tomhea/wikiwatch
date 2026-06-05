import Toybox.Lang;

// M10.4 pure recently-read list logic. A recents list is an Array of
// { :id => String, :title => String } dicts, MOST-RECENT FIRST — the same shape
// the keyboard suggestion rows and ResultsView already render, so opening a
// recent reuses the existing tap-to-open path.
//
// Pure — only imports Toybox.Lang. Persistence is RecentsStore (storage/).
module Recents {
    // Return a NEW list with (id, title) moved to the front: the entry is inserted
    // at position 0, any previous entry with the same id is dropped (dedup — so
    // re-opening an article just re-orders it), and the result is capped at `cap`
    // (the oldest tail entries fall off).
    function add(list as Array, id as String, title as String, cap as Number) as Array {
        var out = [ { :id => id, :title => title } ];
        for (var i = 0; i < list.size() && out.size() < cap; i++) {
            var e = list[i] as Dictionary;
            if (!(e[:id] as String).equals(id)) {
                out.add(e);
            }
        }
        return out;
    }
}
