import Toybox.Lang;
import Toybox.Test;

// Geometry tests for the circular-display safe area used by every view.
// All chord math is anchored to Venu 2 (r=195, screen=390x390).

(:test)
function safeArea_chordAtCenterEqualsDiameter(logger as Logger) as Boolean {
    var v = SafeArea.safeChordWidth(195, 0);
    logger.debug("safeChordWidth(195, 0) = " + v);
    return v == 390;
}

(:test)
function safeArea_chordShrinksOffCenter(logger as Logger) as Boolean {
    // sqrt(195^2 - 100^2) = sqrt(28025) ~= 167.41 -> floor = 167; *2 = 334.
    var v = SafeArea.safeChordWidth(195, 100);
    logger.debug("safeChordWidth(195, 100) = " + v);
    return v == 334;
}

(:test)
function safeArea_chordAtRadiusIsZero(logger as Logger) as Boolean {
    var v = SafeArea.safeChordWidth(195, 195);
    logger.debug("safeChordWidth(195, 195) = " + v);
    return v == 0;
}

(:test)
function safeArea_chordPastRadiusIsZero(logger as Logger) as Boolean {
    // out-of-range guard: |dy| > r returns 0, not a sqrt-of-negative crash.
    var v = SafeArea.safeChordWidth(195, 200);
    logger.debug("safeChordWidth(195, 200) = " + v);
    return v == 0;
}

(:test)
function safeArea_chordNegativeDyMirrorsPositive(logger as Logger) as Boolean {
    // Specific expected value (not just == positive case) so a symmetric
    // stub can't accidentally pass.
    var v = SafeArea.safeChordWidth(195, -100);
    logger.debug("safeChordWidth(195, -100) = " + v);
    return v == 334;
}

(:test)
function safeArea_minSafeYForKnownWidth(logger as Logger) as Boolean {
    // First y from top where chord >= 280: at y=60, dy=-135,
    // floor(sqrt(195^2 - 135^2)) = floor(sqrt(19800)) = 140; chord = 280. PASS.
    // At y=59, chord = 278 < 280. FAIL. So minSafeY = 60.
    var v = SafeArea.minSafeY(195, 280);
    logger.debug("minSafeY(195, 280) = " + v);
    return v == 60;
}

(:test)
function safeArea_minSafeYWiderThanDiameter(logger as Logger) as Boolean {
    // textWidth > 2r is degenerate (no Y can fit it); return r (center) as
    // the best-we-can-do fallback.
    var v = SafeArea.minSafeY(195, 500);
    logger.debug("minSafeY(195, 500) = " + v);
    return v == 195;
}