# M8 corpus-generation pure transforms.
#
# These functions carry the testable logic of the offline corpus pipeline:
#   - Convert-WikiHtmlToMarkdown : MediaWiki article HTML -> clean Markdown body
#   - Split-IntoChunks           : ordered article list -> fixed-size chunks
#   - Get-PopularityScore        : pageview count -> 0..100 (log-normalised)
#   - Resolve-ManifestVersion    : bump the manifest version iff the corpus changed
#   - Get-Utf8ByteCount          : UTF-8 byte length (the watch's per-key cap unit)
#   - Get-CorpusTotalBytes       : sum of per-chunk byte sizes (manifest totalBytes)
#
# Dot-sourced by the orchestration scripts (enumerate/select/extract/pack/
# gen-manifest) AND by test.ps1. No zimdump / filesystem side effects live
# here — those are in the orchestration scripts, so this file is unit-testable
# in isolation (the PowerShell analogue of R6 module placement).

Set-StrictMode -Version Latest

function Get-Utf8ByteCount {
    param([string]$Text)
    if ($null -eq $Text) { return 0 }
    return [System.Text.Encoding]::UTF8.GetByteCount($Text)
}

# Cache filename for an article id. Short ids are used verbatim; very long
# URL-encoded ids (long Hebrew titles blow past the Windows path limit) are
# truncated + suffixed with a STABLE content hash. Stable = deterministic
# across processes (SHA-1, not String.GetHashCode which is randomised per run),
# so extract.ps1 and pack-chunks.ps1 — separate processes — agree on the name.
function Get-CacheFileName {
    param([string]$Id)
    if ($Id.Length -le 180) { return $Id }
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Id)
        $hex = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    } finally { $sha.Dispose() }
    return ($Id.Substring(0, 120)) + "_" + $hex.Substring(0, 16)
}

# Remove every <table>...</table> block whose opening tag carries one of the
# given CSS classes, handling NESTED tables (real Wikipedia infoboxes nest) by
# depth-counting rather than a non-greedy regex (which would stop at the first
# inner </table>).
function Remove-BalancedTables {
    param([string]$Html, [string]$ClassPattern)
    $open = [regex]'(?is)<table\b[^>]*>'
    $tag  = [regex]'(?is)<(/?)table\b[^>]*>'
    while ($true) {
        # Find the next opening <table> whose class matches.
        $m = $open.Match($Html)
        $start = -1
        while ($m.Success) {
            if ($m.Value -match $ClassPattern) { $start = $m.Index; break }
            $m = $m.NextMatch()
        }
        if ($start -lt 0) { break }
        # Walk forward depth-counting to the matching </table>.
        $depth = 0
        $end = -1
        $t = $tag.Match($Html, $start)
        while ($t.Success) {
            if ($t.Groups[1].Value -eq '/') {
                $depth--
                if ($depth -le 0) { $end = $t.Index + $t.Length; break }
            } else {
                $depth++
            }
            $t = $t.NextMatch()
        }
        if ($end -lt 0) {
            # Unbalanced — drop from the opening tag to end of string.
            $Html = $Html.Substring(0, $start)
            break
        }
        $Html = $Html.Substring(0, $start) + $Html.Substring($end)
    }
    return $Html
}

# Flatten one data table's inner HTML into "#### טבלה:" + one line per row,
# cells space-joined. Merged cells are written for EVERY grid position they
# cover: colspan repeats the value across columns, rowspan carries it down into
# the following rows' matching column (standard HTML table-grid reconstruction).
function Convert-OneTable {
    param([string]$Inner)
    $rows = [regex]::Matches($Inner, '(?is)<tr\b[^>]*>(.*?)</tr>')
    $carry = @{}   # absolute column index -> @{ text=...; left=... }
    $out = New-Object System.Collections.ArrayList
    foreach ($rm in $rows) {
        $cells = [regex]::Matches($rm.Groups[1].Value, '(?is)<t[dh]\b([^>]*)>(.*?)</t[dh]>')
        $cols = New-Object System.Collections.ArrayList
        $col = 0
        $ci = 0
        while ($true) {
            $carryAhead = @($carry.Keys | Where-Object { $_ -ge $col -and $carry[$_].left -gt 0 }).Count -gt 0
            if (-not ($ci -lt $cells.Count -or $carryAhead)) { break }
            if ($carry.ContainsKey($col) -and $carry[$col].left -gt 0) {
                [void]$cols.Add($carry[$col].text)
                $carry[$col].left--
                if ($carry[$col].left -le 0) { [void]$carry.Remove($col) }
                $col++
            } elseif ($ci -lt $cells.Count) {
                $attrs = $cells[$ci].Groups[1].Value
                $text = [regex]::Replace($cells[$ci].Groups[2].Value, '(?s)<[^>]+>', ' ')
                $text = ($text -replace '\s+', ' ').Trim()
                $ci++
                $cs = 1; $rs = 1
                $m1 = [regex]::Match($attrs, '(?i)colspan="?(\d+)'); if ($m1.Success) { $cs = [int]$m1.Groups[1].Value }
                $m2 = [regex]::Match($attrs, '(?i)rowspan="?(\d+)'); if ($m2.Success) { $rs = [int]$m2.Groups[1].Value }
                if ($cs -lt 1) { $cs = 1 }; if ($rs -lt 1) { $rs = 1 }
                for ($k = 0; $k -lt $cs; $k++) {
                    [void]$cols.Add($text)
                    if ($rs -gt 1) { $carry[$col] = @{ text = $text; left = ($rs - 1) } }
                    $col++
                }
            } else { break }
        }
        if ($cols.Count -gt 0) { [void]$out.Add(($cols -join ' ')) }
    }
    if ($out.Count -eq 0) { return ' ' }
    # h4 ("smallest header size") label + rows; padded with blank lines so it
    # detaches from surrounding prose.
    return "`n`n#### טבלה:`n" + ($out -join "`n") + "`n`n"
}

# Process every remaining <table> (infobox/navbox already removed): flatten the
# real DATA tables (Wikipedia marks them class="wikitable") to "#### טבלה:" +
# rows, and DROP everything else — class-less styled hatnote/notice boxes,
# DiagramTable, etc. — which are layout noise, not content. Depth-counts
# <table>/</table> so a top-level table is handled as a whole.
function Convert-Tables {
    param([string]$Html)
    $open = [regex]'(?is)<table\b[^>]*>'
    $tag  = [regex]'(?is)<(/?)table\b[^>]*>'
    $from = 0
    while ($true) {
        $m = $open.Match($Html, $from)
        if (-not $m.Success) { break }
        $start = $m.Index
        $depth = 0; $end = -1; $innerStart = $m.Index + $m.Length; $innerEnd = -1
        $t = $tag.Match($Html, $start)
        while ($t.Success) {
            if ($t.Groups[1].Value -eq '/') {
                $depth--
                if ($depth -le 0) { $end = $t.Index + $t.Length; $innerEnd = $t.Index; break }
            } else { $depth++ }
            $t = $t.NextMatch()
        }
        if ($end -lt 0) { break }   # unbalanced — leave as-is to avoid a loop
        if ($m.Value -match '(?i)\bwikitable\b') {
            $inner = $Html.Substring($innerStart, $innerEnd - $innerStart)
            $flat = Convert-OneTable -Inner $inner
        } else {
            $flat = ' '   # notice / layout / diagram table — drop
        }
        $Html = $Html.Substring(0, $start) + $flat + $Html.Substring($end)
        $from = $start + $flat.Length
    }
    return $Html
}

# Replace each <math>...</math> with its cleaned LaTeX annotation, inline.
# MediaWiki Parsoid renders math as a MathML presentation tree (<mi>/<mn>/<mo>
# — which a naive tag-strip explodes into one line per token) PLUS a
# <annotation encoding="application/x-tex"> with the source LaTeX (also mirrored
# in the alttext attribute + an SVG <img alt>). We keep the LaTeX, drop the
# tree. The \displaystyle directive (and its escaped space) is stripped; the
# braces are kept. Runs BEFORE the generic tag-strip so the tree never leaks.
function Convert-MathElements {
    param([string]$Html)
    return [regex]::Replace($Html, '(?is)<math\b([^>]*)>(.*?)</math>', {
        param($m)
        $attrs = $m.Groups[1].Value
        $inner = $m.Groups[2].Value
        $latex = $null
        $am = [regex]::Match($inner, '(?is)<annotation\b[^>]*encoding="application/x-tex"[^>]*>(.*?)</annotation>')
        if ($am.Success) {
            $latex = $am.Groups[1].Value
        } else {
            $aa = [regex]::Match($attrs, '(?is)alttext="([^"]*)"')
            if ($aa.Success) { $latex = $aa.Groups[1].Value }
        }
        if ($null -eq $latex) { return ' ' }
        # Drop the \displaystyle directive + a following escaped-space/backslash.
        $latex = [regex]::Replace($latex, '\\displaystyle\s*\\?\s*', '')
        # Pad with spaces so it doesn't fuse with adjacent prose.
        return ' ' + $latex.Trim() + ' '
    })
}

# Sub/superscript digits (and a few operators) -> ASCII so they're printable on
# the watch (e.g. H₂O -> H2O, x² -> x2).
function Convert-SubSuperscripts {
    param([string]$Text)
    $map = @{
        # subscripts 2080-2089
        ([char]0x2080)='0';([char]0x2081)='1';([char]0x2082)='2';([char]0x2083)='3';([char]0x2084)='4'
        ([char]0x2085)='5';([char]0x2086)='6';([char]0x2087)='7';([char]0x2088)='8';([char]0x2089)='9'
        ([char]0x208A)='+';([char]0x208B)='-';([char]0x208C)='=';([char]0x208D)='(';([char]0x208E)=')'
        # superscripts
        ([char]0x2070)='0';([char]0x00B9)='1';([char]0x00B2)='2';([char]0x00B3)='3';([char]0x2074)='4'
        ([char]0x2075)='5';([char]0x2076)='6';([char]0x2077)='7';([char]0x2078)='8';([char]0x2079)='9'
        ([char]0x207A)='+';([char]0x207B)='-';([char]0x207C)='=';([char]0x207D)='(';([char]0x207E)=')'
    }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        if ($map.ContainsKey($ch)) { [void]$sb.Append($map[$ch]) } else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

# Strip invisible control marks that the watch doesn't need and that perturb
# word-wrap / search: bidi marks (RLM/LRM/embeds/isolates) + zero-width chars.
# Nikud (U+0591-05C7) is deliberately NOT in this set — it's preserved.
function Remove-InvisibleControls {
    param([string]$Text)
    # 200B-200F (ZWSP/ZWNJ/ZWJ + RLM/LRM), 202A-202E (embeds/overrides),
    # 2066-2069 (isolates), FEFF (BOM). Pattern built from explicit codepoints
    # so this source file stays ASCII-only. Nikud (0591-05C7) is NOT included.
    $r = [char]0x200B + '-' + [char]0x200F +
         [char]0x202A + '-' + [char]0x202E +
         [char]0x2066 + '-' + [char]0x2069 +
         [char]0xFEFF
    $pattern = '[' + $r + ']'
    return [regex]::Replace($Text, $pattern, '')
}

# Strip Hebrew nikud + cantillation (the combining vowel/te'amim marks), leaving
# the base consonants — Hebrew Wikipedia prose is normally read unpointed, and
# the marks bloat the text + don't all render on the watch. Combining marks
# only (Unicode category Mn in the Hebrew block): 0591-05BD, 05BF, 05C1, 05C2,
# 05C4, 05C5, 05C7. Punctuation/connectors are KEPT: 05BE maqaf (־), 05C0 paseq,
# 05C3 sof pasuq, 05C6 nun hafukha, and geresh/gershayim (05F3/05F4).
function Remove-Nikud {
    param([string]$Text)
    $r = [char]0x0591 + '-' + [char]0x05BD +
         [char]0x05BF + [char]0x05C1 + [char]0x05C2 +
         [char]0x05C4 + [char]0x05C5 + [char]0x05C7
    return [regex]::Replace($Text, '[' + $r + ']', '')
}

function Convert-HtmlEntities {
    param([string]$Text)
    $s = $Text
    $s = $s -replace '&nbsp;', ' '
    $s = $s -replace '&#160;', ' '
    $s = $s -replace '&lt;', '<'
    $s = $s -replace '&gt;', '>'
    $s = $s -replace '&quot;', '"'
    $s = $s -replace '&#0?39;', "'"
    $s = $s -replace '&apos;', "'"
    $s = $s -replace '&mdash;', '—'
    $s = $s -replace '&ndash;', '–'
    # Numeric decimal entities -> char.
    $s = [regex]::Replace($s, '&#(\d+);', { param($mm) [char][int]$mm.Groups[1].Value })
    # &amp; LAST so we don't double-decode (e.g. &amp;lt; -> &lt;).
    $s = $s -replace '&amp;', '&'
    return $s
}

# Convert one MediaWiki article's raw HTML into a clean Markdown body capped at
# $MaxBytes UTF-8 bytes, truncating on a paragraph boundary.
function Convert-WikiHtmlToMarkdown {
    param(
        [string]$Html,
        [string]$Title,
        [int]$MaxBytes = 14336
    )
    $s = $Html

    # 1. Narrow to the real content div if present.
    $cm = [regex]::Match($s, '(?is)<div\b[^>]*\bid="mw-content-text"[^>]*>(.*)</div>')
    if ($cm.Success) { $s = $cm.Groups[1].Value }

    # 2. Drop non-content elements wholesale (with their contents).
    $s = [regex]::Replace($s, '(?is)<head\b.*?</head>', '')
    $s = [regex]::Replace($s, '(?is)<script\b.*?</script>', '')
    $s = [regex]::Replace($s, '(?is)<style\b.*?</style>', '')
    $s = [regex]::Replace($s, '(?is)<link\b[^>]*>', '')
    # Footnote markers like [1], [2].
    $s = [regex]::Replace($s, '(?is)<sup\b[^>]*class="[^"]*\breference\b[^"]*"[^>]*>.*?</sup>', '')

    # 3. Drop infobox + navbox tables (nested-aware).
    $s = Remove-BalancedTables -Html $s -ClassPattern 'class="[^"]*\b(infobox|navbox)\b[^"]*"'

    # 3b. Collapse <math> elements to their LaTeX annotation BEFORE the generic
    #     tag-strip (else the MathML <mi>/<mn>/<mo> tree explodes into one line
    #     per token — the polynomial-article 1056-line blowup). The SVG <img>
    #     fallback that follows each <math> is left for the tag-strip to remove.
    $s = Convert-MathElements -Html $s

    # 3c. Flatten remaining (data) tables to "#### טבלה:" + rows, BEFORE the
    #     generic tag-strip (which would otherwise jumble <tr>/<td> together).
    $s = Convert-Tables -Html $s

    # 4. Structural conversions BEFORE stripping the remaining tags.
    $s = [regex]::Replace($s, '(?is)<li\b[^>]*>(.*?)</li>', "`n- `$1`n")
    $s = [regex]::Replace($s, '(?is)</?(ul|ol)\b[^>]*>', "`n")
    $s = [regex]::Replace($s, '(?is)<br\b[^>]*/?>', "`n")
    $s = [regex]::Replace($s, '(?is)<h2\b[^>]*>(.*?)</h2>', "`n`n## `$1`n`n")
    $s = [regex]::Replace($s, '(?is)<h3\b[^>]*>(.*?)</h3>', "`n`n### `$1`n`n")
    $s = [regex]::Replace($s, '(?is)<h4\b[^>]*>(.*?)</h4>', "`n`n#### `$1`n`n")
    $s = [regex]::Replace($s, '(?is)<p\b[^>]*>(.*?)</p>', "`n`n`$1`n`n")

    # 5. Strip every remaining tag, keeping inner text. Quote-aware so a '>'
    #    inside an attribute value doesn't end the tag early — MediaWiki
    #    Parsoid stuffs JSON (with '>' and quotes) into data-mw="{...}", which a
    #    naive <[^>]+> would mangle, spilling the JSON into the body text.
    $s = [regex]::Replace($s, '(?s)<(?:"[^"]*"|''[^'']*''|[^''">])*>', '')

    # 6. Decode entities.
    $s = Convert-HtmlEntities $s

    # 6b. Drop Parsoid audio-button artefacts (Phonos ⓘ / Ⓘ glyphs) that have
    #     no value on the watch.
    $s = $s -replace '[ⓘⒾ]', ''

    # 6c. Strip invisible bidi/zero-width controls (the watch does its own RTL),
    #     normalise sub/superscript digits to ASCII, and strip Hebrew nikud /
    #     cantillation (keep the base consonants + maqaf).
    $s = Remove-InvisibleControls $s
    $s = Convert-SubSuperscripts $s
    $s = Remove-Nikud $s

    # 7. Whitespace cleanup: collapse intra-line runs, trim each line, collapse
    #    blank-line runs to a single blank line.
    $s = $s -replace '[ \t]+', ' '
    $lines = $s -split "`n"
    $trimmed = New-Object System.Collections.ArrayList
    foreach ($ln in $lines) { [void]$trimmed.Add($ln.Trim()) }
    $s = ($trimmed -join "`n")
    $s = [regex]::Replace($s, "(`n){3,}", "`n`n")
    $s = $s.Trim()

    # 7b. Tighten block spacing (the reader gives every blank line vertical gap):
    #     - consecutive bullets get a single newline, not a blank line between;
    #     - sub-headers (## / ### / ####) sit directly above their first body
    #       line (single newline after), not separated by a blank line. The
    #       initial "# <title>" is added in step 8 and keeps its blank line.
    $s = [regex]::Replace($s, "(?m)^(- .+)`n`n(?=- )", "`$1`n")
    $s = [regex]::Replace($s, "(?m)^(#{2,4} .+)`n`n", "`$1`n")

    # 8. Prepend the H1 title.
    $body = "# $Title`n`n$s"

    # 9. Truncate on a paragraph boundary if over the byte cap.
    $marker = "`n`n(המשך בערך המלא)"
    $markerBytes = Get-Utf8ByteCount $marker
    if ((Get-Utf8ByteCount $body) -le $MaxBytes) {
        return $body
    }
    $budget = $MaxBytes - $markerBytes
    $paras = $body -split "`n`n"
    $acc = New-Object System.Text.StringBuilder
    foreach ($p in $paras) {
        $candidate = if ($acc.Length -eq 0) { $p } else { $acc.ToString() + "`n`n" + $p }
        if ((Get-Utf8ByteCount $candidate) -gt $budget) { break }
        if ($acc.Length -gt 0) { [void]$acc.Append("`n`n") }
        [void]$acc.Append($p)
    }
    return $acc.ToString() + $marker
}

# Split an ordered array into chunks of at most $ChunkSize items each, order
# preserved. Returns an array of arrays.
function Split-IntoChunks {
    param(
        [object[]]$Items,
        [int]$ChunkSize
    )
    $out = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Items.Count; $i += $ChunkSize) {
        $end = [Math]::Min($i + $ChunkSize, $Items.Count) - 1
        # @(...) keeps a 1-element slice an array, not a scalar.
        [void]$out.Add(@($Items[$i..$end]))
    }
    # Leading comma stops PowerShell from unrolling the outer array on return.
    return ,$out.ToArray()
}

# Map a pageview count onto a 0..100 popularity score via log scaling, so the
# long tail doesn't collapse to 0. Pure: callers pass the corpus max.
function Get-PopularityScore {
    param(
        [long]$Views,
        [long]$MaxViews
    )
    if ($MaxViews -le 0) { return 0 }
    if ($Views -le 0) { return 0 }
    # Log scaling so the long tail keeps a non-zero, distinguishable score.
    $score = [Math]::Round(100.0 * [Math]::Log(1.0 + $Views) / [Math]::Log(1.0 + $MaxViews))
    $p = [int]$score
    if ($p -lt 0) { $p = 0 }
    if ($p -gt 100) { $p = 100 }
    return $p
}

# Bump the version only when the selected-corpus fingerprint changed. Pure so
# re-running the pipeline on an unchanged corpus is idempotent.
function Resolve-ManifestVersion {
    param(
        [int]$PrevVersion,
        [string]$PrevHash,
        [string]$NewHash
    )
    if ($PrevHash -eq $NewHash) { return $PrevVersion }
    return $PrevVersion + 1
}

# Sum per-chunk byte sizes -> manifest totalBytes.
function Get-CorpusTotalBytes {
    param([int[]]$ChunkByteSizes)
    $sum = 0
    foreach ($b in $ChunkByteSizes) { $sum += $b }
    return $sum
}
