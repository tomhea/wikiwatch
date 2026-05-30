import Toybox.Lang;
import Toybox.Test;

// M9.4: pin the free-memory HUD formatting (the size-sweep instrument).

(:test)
function memHud_kbFloorsToKilobytes(logger as Logger) as Boolean {
    logger.debug("412874->" + MemHud.kb(412874) + " 1023->" + MemHud.kb(1023));
    return MemHud.kb(412874) == 403 && MemHud.kb(1023) == 0 && MemHud.kb(2048) == 2;
}

(:test)
function memHud_lineFormat(logger as Logger) as Boolean {
    logger.debug("line=" + MemHud.line(412874));
    return MemHud.line(412874).equals("free 403k");
}

(:test)
function memHud_taggedFormat(logger as Logger) as Boolean {
    logger.debug("tagged=" + MemHud.tagged("idx", 412874));
    return MemHud.tagged("idx", 412874).equals("idx free 403k");
}
