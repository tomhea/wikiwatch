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

    # 7. Whitespace cleanup: collapse intra-line runs, trim each line, collapse
    #    blank-line runs to a single blank line.
    $s = $s -replace '[ \t]+', ' '
    $lines = $s -split "`n"
    $trimmed = New-Object System.Collections.ArrayList
    foreach ($ln in $lines) { [void]$trimmed.Add($ln.Trim()) }
    $s = ($trimmed -join "`n")
    $s = [regex]::Replace($s, "(`n){3,}", "`n`n")
    $s = $s.Trim()

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
