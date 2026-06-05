import Toybox.Lang;

// M10.1 - pure routing for the article-body codec (the manifest's `bodyCodec`).
// Decides, from the corpus codec + the served `modelVersion` vs the model baked
// into THIS .prg, how a stored body must be turned into displayable text.
//
// Pure (only Lang) so it lives in models/ and is fully unit-testable; the impure
// glue (read the persisted manifest, call the decoder) is `CompModel.decodeBody`.
//
// Backward compatibility is the whole point: the plain v15 corpus (and any
// manifest stored before M10.1) has codec "plain" → bodies are used verbatim,
// exactly as today. A compressed corpus only decodes when its modelVersion
// matches the baked model — a mismatch is reported :unavailable (never rendered
// as base64 garbage).
module BodyCodec {
    const PLAIN      = "plain";
    const BPE_HUFF_1 = "bpe-huff-1";

    // Read-time decision for a stored body:
    //   :plain       -> use the stored String as-is (plain corpus / pre-M10.1)
    //   :decompress  -> BPE+Huffman-decode the stored base64 blob
    //   :unavailable -> can't safely render (compressed but model mismatch, or an
    //                   unknown codec) -> caller must NOT open the article
    function readAction(codec as String?, manifestModelVersion as Number?, bakedVersion as Number) as Symbol {
        if (codec == null || codec.equals(PLAIN)) {
            return :plain;
        }
        if (codec.equals(BPE_HUFF_1)) {
            if (manifestModelVersion != null && manifestModelVersion == bakedVersion) {
                return :decompress;
            }
            return :unavailable;   // compressed corpus this binary can't decode
        }
        return :unavailable;       // unknown future codec
    }

    // Install-time guard: may this binary install/keep a corpus with this codec?
    // True for plain corpora and for compressed corpora whose modelVersion matches
    // the baked model; false for a compressed corpus this binary can't decode
    // (so we don't download bodies we could never render) — the user must update
    // the app. Ship the binary BEFORE flipping the server corpus so this never
    // fires in the field.
    function installable(codec as String?, modelVersion as Number?, bakedVersion as Number) as Boolean {
        return readAction(codec, modelVersion, bakedVersion) != :unavailable;
    }
}
