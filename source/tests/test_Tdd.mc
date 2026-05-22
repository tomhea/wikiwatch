import Toybox.Lang;
import Toybox.Test;

(:test)
function tdd_returns42(logger as Logger) as Boolean {
    var v = Tdd.alwaysReturns42();
    logger.debug("Tdd.alwaysReturns42() = " + v);
    return v == 42;
}
