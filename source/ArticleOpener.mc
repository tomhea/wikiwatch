import Toybox.Lang;
import Toybox.WatchUi;

// M10.1: routes an article-open from a stored body to the right view, per the
// persisted manifest codec. Plain corpus → push the reader directly (verbatim,
// exactly as before M10). Compressed corpus → push DecodeView (decode across
// ticks → reader), UNLESS the article's laid-out lines are already cached, in
// which case the reader re-opens instantly with no decode. An undecodable
// compressed corpus (modelVersion mismatch) opens nothing (never garbage).
//
// Impure (WatchUi) so it lives in source/, not models/. The routing decision
// itself is the pure BodyCodec.readAction.
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
        var dv = new DecodeView(blob, id);
        WatchUi.pushView(dv, new DecodeDelegate(), WatchUi.SLIDE_LEFT);
    }

    function _pushReader(body as String, id as String) as Void {
        var reader = new wikiwatchView(body, id);
        WatchUi.pushView(reader, new wikiwatchDelegate(reader), WatchUi.SLIDE_LEFT);
    }
}
