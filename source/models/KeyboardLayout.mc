import Toybox.Lang;

// Static Hebrew keyboard layout. Pure module (no Toybox.WatchUi / Storage /
// Application / Communications imports per R6). 5 rows x 6 cols = 30 cells:
// 22 Hebrew letters (alphabet order, row-major), 4 specials (space /
// backspace / delete-all / search), 4 empty cells in the tails of rows 3+4.
//
// The grid sits inside the inscribed rectangle of the round display, below
// the buffer area at the top. _gridBounds (inlined in keyAt) derives the
// rectangle from the screen size + a SafeArea chord check so the corners
// stay inside the bezel on both the 416-px simulator and the 390-px real
// watch.
module KeyboardLayout {
    const ROWS = 5;
    const COLS = 6;
    const BUFFER_H = 50;     // px reserved at top for the typing buffer
    const GRID_TOP_GAP = 15; // gap between buffer and first row
    const GRID_H = 260;      // total grid height (5 rows of 52 px each)

    // Returns the 30 key dictionaries in row-major order.
    function keys() as Array<Dictionary> {
        return [
            // Row 0: alef-vav (first 6 letters)
            { :label => "א", :type => :LETTER, :row => 0, :col => 0 },
            { :label => "ב", :type => :LETTER, :row => 0, :col => 1 },
            { :label => "ג", :type => :LETTER, :row => 0, :col => 2 },
            { :label => "ד", :type => :LETTER, :row => 0, :col => 3 },
            { :label => "ה", :type => :LETTER, :row => 0, :col => 4 },
            { :label => "ו", :type => :LETTER, :row => 0, :col => 5 },
            // Row 1: zayin-lamed (letters 7-12)
            { :label => "ז", :type => :LETTER, :row => 1, :col => 0 },
            { :label => "ח", :type => :LETTER, :row => 1, :col => 1 },
            { :label => "ט", :type => :LETTER, :row => 1, :col => 2 },
            { :label => "י", :type => :LETTER, :row => 1, :col => 3 },
            { :label => "כ", :type => :LETTER, :row => 1, :col => 4 },
            { :label => "ל", :type => :LETTER, :row => 1, :col => 5 },
            // Row 2: mem-tzadi (letters 13-18)
            { :label => "מ", :type => :LETTER, :row => 2, :col => 0 },
            { :label => "נ", :type => :LETTER, :row => 2, :col => 1 },
            { :label => "ס", :type => :LETTER, :row => 2, :col => 2 },
            { :label => "ע", :type => :LETTER, :row => 2, :col => 3 },
            { :label => "פ", :type => :LETTER, :row => 2, :col => 4 },
            { :label => "צ", :type => :LETTER, :row => 2, :col => 5 },
            // Row 3: kuf-tav (letters 19-22) + 2 empty
            { :label => "ק", :type => :LETTER, :row => 3, :col => 0 },
            { :label => "ר", :type => :LETTER, :row => 3, :col => 1 },
            { :label => "ש", :type => :LETTER, :row => 3, :col => 2 },
            { :label => "ת", :type => :LETTER, :row => 3, :col => 3 },
            { :label => "", :type => :EMPTY, :row => 3, :col => 4 },
            { :label => "", :type => :EMPTY, :row => 3, :col => 5 },
            // Row 4: 4 specials + 2 empty (ASCII labels until we probe the
            // built-in fonts for prettier glyphs; see M1 width-probe pattern)
            { :label => "space", :type => :SPACE, :row => 4, :col => 0 },
            { :label => "<-", :type => :BACKSPACE, :row => 4, :col => 1 },
            { :label => "X", :type => :DELETE_ALL, :row => 4, :col => 2 },
            { :label => ">", :type => :SEARCH, :row => 4, :col => 3 },
            { :label => "", :type => :EMPTY, :row => 4, :col => 4 },
            { :label => "", :type => :EMPTY, :row => 4, :col => 5 }
        ];
    }

    // Returns the key whose cell contains (x, y) on a screenW x screenH
    // display, or null if outside the grid (bezel / buffer area / empty cell).
    function keyAt(x as Number, y as Number, screenW as Number, screenH as Number) as Dictionary or Null {
        var gridY = BUFFER_H + GRID_TOP_GAP;
        var gridH = GRID_H;
        var r = screenH / 2;
        // Narrowest chord across the grid height determines gridW.
        var topHalf = SafeArea.safeChordHalfWidth(r, gridY - r);
        var botHalf = SafeArea.safeChordHalfWidth(r, gridY + gridH - r);
        var gridHalfW = (topHalf < botHalf) ? topHalf : botHalf;
        var gridW = 2 * gridHalfW;
        var gridX = (screenW - gridW) / 2;
        if (x < gridX || x >= gridX + gridW) { return null; }
        if (y < gridY || y >= gridY + gridH) { return null; }
        var cellW = gridW / COLS;
        var cellH = gridH / ROWS;
        if (cellW < 1) { cellW = 1; }
        if (cellH < 1) { cellH = 1; }
        var col = (x - gridX) / cellW;
        var row = (y - gridY) / cellH;
        if (col >= COLS) { col = COLS - 1; }
        if (row >= ROWS) { row = ROWS - 1; }
        var ks = keys();
        var idx = row * COLS + col;
        if (idx >= ks.size()) { return null; }
        var k = ks[idx] as Dictionary;
        if (k[:type] == :EMPTY) { return null; }
        return k;
    }
}