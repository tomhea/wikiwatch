import Toybox.Lang;
import Toybox.Test;

// M10.1 tests for the pure body-codec routing (BodyCodec.readAction / installable).
// Baked model version in these tests is 1 (matches the M10.0 model).

(:test)
function bodyCodec_plainUsesStored(logger as Logger) as Boolean {
    var a = BodyCodec.readAction("plain", 0, 1);
    logger.debug("readAction(plain) = " + a);
    return a == :plain;
}

(:test)
function bodyCodec_nullCodecIsPlain(logger as Logger) as Boolean {
    // pre-M10.1 stored manifest has no codec -> behave exactly as today.
    var a = BodyCodec.readAction(null, 0, 1);
    logger.debug("readAction(null) = " + a);
    return a == :plain;
}

(:test)
function bodyCodec_decompressWhenVersionMatches(logger as Logger) as Boolean {
    var a = BodyCodec.readAction("bpe-huff-1", 1, 1);
    logger.debug("readAction(bpe-huff-1, mv=1, baked=1) = " + a);
    return a == :decompress;
}

(:test)
function bodyCodec_unavailableOnVersionMismatch(logger as Logger) as Boolean {
    // compressed corpus trained with a model this binary doesn't carry.
    var a = BodyCodec.readAction("bpe-huff-1", 2, 1);
    logger.debug("readAction(bpe-huff-1, mv=2, baked=1) = " + a);
    return a == :unavailable;
}

(:test)
function bodyCodec_unavailableOnNullVersion(logger as Logger) as Boolean {
    var a = BodyCodec.readAction("bpe-huff-1", null, 1);
    logger.debug("readAction(bpe-huff-1, mv=null) = " + a);
    return a == :unavailable;
}

(:test)
function bodyCodec_unavailableOnUnknownCodec(logger as Logger) as Boolean {
    var a = BodyCodec.readAction("lzss-9", 1, 1);
    logger.debug("readAction(lzss-9) = " + a);
    return a == :unavailable;
}

(:test)
function bodyCodec_installableAllowsPlain(logger as Logger) as Boolean {
    return BodyCodec.installable("plain", 0, 1) == true;
}

(:test)
function bodyCodec_installableAllowsMatchingCompressed(logger as Logger) as Boolean {
    return BodyCodec.installable("bpe-huff-1", 1, 1) == true;
}

(:test)
function bodyCodec_installableRejectsMismatch(logger as Logger) as Boolean {
    // the "ship binary before flipping corpus" safety net.
    return BodyCodec.installable("bpe-huff-1", 2, 1) == false;
}
