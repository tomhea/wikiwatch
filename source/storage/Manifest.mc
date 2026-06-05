import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// M4 wrapper around Application.Storage for the article manifest.
// In-memory schema (Symbol-keyed; matches the Monkey C idiom used across
// the rest of the codebase):
//   { :version => 1,
//     :articles => [ { :id, :title, :popularity }, ... ] }
//
// Storage boundary: Application.Storage cannot serialize Symbol keys
// (UnexpectedTypeException). save() converts Symbol -> String keys before
// setValue; load() converts back. Callers (Fixtures, FixtureInstaller,
// future M5 search) never see the String-keyed form.
//
// save() is R4-gated: returns false when freeMemory is below 3x the
// estimated serialized size. R5: same guard mitigates the uncatchable OOM.
//
// Lives in source/storage/ (not source/models/) because it imports
// Application + System.
module Manifest {
    const KEY = "manifest";

    function load() as Dictionary {
        var v = Application.Storage.getValue(KEY) as Dictionary?;
        if (v == null) {
            return { :version => 1, :articles => [], :bodyCodec => "plain", :modelVersion => 0 };
        }
        return _fromStorageDict(v);
    }

    function save(m as Dictionary) as Boolean {
        var est = _estimateSize(m);
        if (System.getSystemStats().freeMemory < est * 3) {
            return false;
        }
        Application.Storage.setValue(KEY, _toStorageDict(m));
        return true;
    }

    function isEmpty() as Boolean {
        var m = load();
        var arts = m[:articles] as Array?;
        return arts == null || arts.size() == 0;
    }

    function articleIds() as Array<String> {
        var arts = load()[:articles] as Array?;
        var ids = [];
        if (arts == null) { return ids; }
        for (var i = 0; i < arts.size(); i++) {
            ids.add((arts[i] as Dictionary)[:id] as String);
        }
        return ids;
    }

    // M7: deletes all "article:<id>" keys from Storage so a fresh download
    // starts from a clean slate. Preserves the "manifest" key — the caller
    // can wipe in any order relative to Manifest.save. Returns the number
    // of article keys deleted (handy for diagnostics).
    //
    // Uses the current manifest's article list to know which keys to
    // delete. If the manifest is empty/missing, no-op (returns 0).
    function wipeArticles() as Number {
        var ids = articleIds();
        for (var i = 0; i < ids.size(); i++) {
            Application.Storage.deleteValue("article:" + (ids[i] as String));
        }
        return ids.size();
    }

    function titleOf(id as String) as String? {
        var arts = load()[:articles] as Array?;
        if (arts == null) { return null; }
        for (var i = 0; i < arts.size(); i++) {
            var a = arts[i] as Dictionary;
            if ((a[:id] as String).equals(id)) {
                return a[:title] as String;
            }
        }
        return null;
    }

    // Conservative size estimate for the freeMemory guard. 100 byte header
    // + 100 bytes per article (id ~ 16, title ~ 40, popularity ~ 4, dict
    // overhead). Real overhead is smaller, but the *3 multiplier needs a
    // generous baseline to keep R4 honest.
    function _estimateSize(m as Dictionary) as Number {
        var arts = m[:articles] as Array?;
        var n = arts == null ? 0 : arts.size();
        return 100 + n * 100;
    }

    // Convert in-memory Symbol-keyed dict to String-keyed dict for Storage.
    function _toStorageDict(m as Dictionary) as Dictionary {
        var arts = m[:articles] as Array?;
        var storageArts = [];
        if (arts != null) {
            for (var i = 0; i < arts.size(); i++) {
                var a = arts[i] as Dictionary;
                storageArts.add({
                    "id" => a[:id],
                    "title" => a[:title],
                    "popularity" => a[:popularity]
                });
            }
        }
        // M10.1: persist the body codec + model version so the read path knows,
        // offline, whether stored bodies are plain text or BPE+Huffman blobs.
        var bodyCodec = m[:bodyCodec];
        if (bodyCodec == null) { bodyCodec = "plain"; }
        var modelVersion = m[:modelVersion];
        if (modelVersion == null) { modelVersion = 0; }
        return {
            "version" => m[:version],
            "articles" => storageArts,
            "bodyCodec" => bodyCodec,
            "modelVersion" => modelVersion
        };
    }

    // Convert String-keyed dict from Storage back to Symbol-keyed.
    function _fromStorageDict(v as Dictionary) as Dictionary {
        var arts = v["articles"] as Array?;
        var memArts = [];
        if (arts != null) {
            for (var i = 0; i < arts.size(); i++) {
                var a = arts[i] as Dictionary;
                memArts.add({
                    :id         => a["id"],
                    :title      => a["title"],
                    :popularity => a["popularity"]
                });
            }
        }
        // M10.1: default for manifests stored before M10.1 (no codec keys) → plain.
        var bodyCodec = v["bodyCodec"];
        if (bodyCodec == null) { bodyCodec = "plain"; }
        var modelVersion = v["modelVersion"];
        if (modelVersion == null) { modelVersion = 0; }
        return {
            :version      => v["version"],
            :articles     => memArts,
            :bodyCodec    => bodyCodec,
            :modelVersion => modelVersion
        };
    }
}
