import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// M10.1/M10.2: routes an article-open from a stored body to the right view, per
// the persisted manifest codec. Plain corpus → push the reader directly
// (verbatim, exactly as before M10). Compressed corpus → push the STREAMING
// reader (wikiwatchView.startStreaming) which decodes+lays out across ticks,
// showing text after the first ~2 screens decode. On the FIRST compressed open of
// a session the model isn't parsed yet, so we route via DecodeView (the parse
// gate) which hands off to the streaming reader once parsed. If the article's
// laid-out lines are already cached the reader re-opens instantly (no decode). An
// undecodable compressed corpus (modelVersion mismatch) opens nothing.
//
// Impure (WatchUi/System) so it lives in source/, not models/. The routing
// decision itself is the pure BodyCodec.readAction.
module ArticleOpener {
    function open(stored as String, id as String) as Void {
        var man = Manifest.load();
        var codec = man[:bodyCodec] as String?;
        // Plain corpus / pre-M10.1: never touches the model.
        if (codec == null || codec.equals(BodyCodec.PLAIN)) {
            _pushReader(stored, id);
            return;
        }
        var action = BodyCodec.readAction(codec, man[:modelVersion] as Number?, CompModel.bakedVersion());
        if (action != :decompress) {
            return;   // :unavailable — compressed corpus this binary can't decode
        }
        // Already laid out (re-open) → reader adopts the cached layout, no decode.
        if (ArticleLayoutCache.get(id) != null) {
            _pushReader("", id);
            return;
        }
        var blob = Decompressor.b64ToBytes(stored);
        var model = CompModel.cachedModel();
        if (model != null) {
            // Model already parsed this session → stream directly, no parse gate.
            // R5: guard the decode output buffer alloc (grows to the full body).
            if (System.getSystemStats().freeMemory < CompModel.MIN_FREE_DECODE) {
                return;   // open nothing rather than risk an uncatchable OOM
            }
            var reader = new wikiwatchView("", id);
            reader.startStreaming(blob, model as Dictionary);
            WatchUi.pushView(reader, new wikiwatchDelegate(reader), WatchUi.SLIDE_LEFT);
            return;
        }
        // First compressed open of the session → parse gate, then it streams.
        var dv = new DecodeView(blob, id);
        WatchUi.pushView(dv, new DecodeDelegate(), WatchUi.SLIDE_LEFT);
    }

    function _pushReader(body as String, id as String) as Void {
        var reader = new wikiwatchView(body, id);
        WatchUi.pushView(reader, new wikiwatchDelegate(reader), WatchUi.SLIDE_LEFT);
    }
}
