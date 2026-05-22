import Toybox.Lang;

// M0 placeholder module. Exists so the M0 smoke test has something to call
// and so the source/models/ directory is committed with a real .mc file in it.
// Will be deleted once a real model module replaces it in M3.
module Tdd {
    function alwaysReturns42() as Number {
        return 42;
    }
}
