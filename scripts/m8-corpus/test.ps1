# M8 corpus-tooling test runner.
#
# Self-contained (no Pester dependency — the host only has Pester 3.4.0, whose
# syntax differs from modern Pester; a tiny custom runner is more robust and
# matches the project's existing scripts/test.ps1 style). Dot-sources the pure
# transforms in corpus-lib.ps1 and asserts their behaviour.
#
# Exit 0 iff every test passes, else 1 (so R1 evidence capture mirrors the
# watch-side scripts/test.ps1 contract).

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\corpus-lib.ps1"

$script:Tests = [System.Collections.ArrayList]@()
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    [void]$script:Tests.Add(@{ Name = $Name; Body = $Body })
}

# ---------------------------------------------------------------------------
# extractor.test — Convert-WikiHtmlToMarkdown
# ---------------------------------------------------------------------------

Test-Case "extractor::strips_infobox_table" {
    $html = '<div id="mw-content-text"><table class="infobox"><tr><td>INFOMETA</td></tr></table><p>גוף הטקסט כאן</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    (-not ($md -match 'INFOMETA')) -and ($md -match 'גוף הטקסט כאן')
}

Test-Case "extractor::strips_navbox_table" {
    $html = '<div id="mw-content-text"><p>פתיח</p><table class="navbox"><tr><td>NAVLINKS</td></tr></table></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    (-not ($md -match 'NAVLINKS')) -and ($md -match 'פתיח')
}

Test-Case "extractor::preserves_link_text" {
    $html = '<div id="mw-content-text"><p><a rel="mw:WikiLink" href="./תורה">תורה</a> חשובה</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md -match 'תורה חשובה') -and (-not ($md -match '<a')) -and (-not ($md -match 'href'))
}

Test-Case "extractor::converts_ul_to_dash_list" {
    $html = '<div id="mw-content-text"><ul><li>א</li><li>ב</li></ul></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md -match '(?m)^- א\s*$') -and ($md -match '(?m)^- ב\s*$')
}

Test-Case "extractor::decodes_nbsp_entity" {
    $html = '<div id="mw-content-text"><p>שלום&nbsp;לכם</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # &nbsp; -> normal space; &amp; round-trip too.
    ($md -match 'שלום לכם') -and (-not ($md -match '&nbsp;'))
}

Test-Case "extractor::emits_h1_first_line" {
    $html = '<div id="mw-content-text"><p>גוף</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'ישראל'
    $first = ($md -split "`n")[0]
    $first -eq '# ישראל'
}

Test-Case "extractor::truncates_at_paragraph_boundary" {
    # Build ~20 KB of distinct paragraphs.
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<div id="mw-content-text">')
    for ($i = 0; $i -lt 400; $i++) {
        [void]$sb.Append('<p>')
        [void]$sb.Append(('פסקה מספר ' + $i + ' ') * 6)
        [void]$sb.Append('</p>')
    }
    [void]$sb.Append('</div>')
    $md = Convert-WikiHtmlToMarkdown -Html $sb.ToString() -Title 'ארוך' -MaxBytes 14336
    $bytes = Get-Utf8ByteCount $md
    # Under cap, and the truncation marker is appended (proves it was cut on a
    # boundary rather than mid-sentence).
    ($bytes -le 14336) -and ($md -match 'המשך בערך המלא')
}

# ---------------------------------------------------------------------------
# extractor.test — unprintable-category handling (math, bidi, zero-width,
# sub/superscripts, nikud) — M8.1 corpus cleanup
# ---------------------------------------------------------------------------

Test-Case "extractor::math_collapses_to_latex_annotation" {
    # MathML presentation tree (which used to explode into one line per token)
    # is replaced by the cleaned LaTeX annotation, inline.
    $html = '<div id="mw-content-text"><p>ביטוי מהצורה <math alttext="x"><semantics><mrow><mi>a</mi><mn>0</mn><mo>+</mo><mi>a</mi><mn>1</mn></mrow><annotation encoding="application/x-tex">{\displaystyle \a_{0}+a_{1}}</annotation></semantics></math> סוף</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # Keeps the cleaned LaTeX, drops the presentation explosion + \displaystyle.
    ($md -match '\{a_\{0\}\+a_\{1\}\}') -and (-not ($md -match 'displaystyle')) -and
        # the lone 'a 0 + a 1' token soup must NOT each be on their own line
        (-not ($md -match '(?m)^0\s*$'))
}

Test-Case "extractor::math_strips_displaystyle_space_prefix" {
    $html = '<div id="mw-content-text"><p>x הוא <math><semantics><mrow><mi>x</mi></mrow><annotation encoding="application/x-tex">{\displaystyle \ x}</annotation></semantics></math></p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md -match '\{x\}') -and (-not ($md -match 'displaystyle'))
}

Test-Case "extractor::math_drops_svg_fallback" {
    # The SVG fallback <img alt="..."> after </math> must not leak its alt text.
    $html = '<div id="mw-content-text"><p><math><semantics><annotation encoding="application/x-tex">{\displaystyle \ y}</annotation></semantics></math><img src="x.svg" class="mwe-math-fallback-image-inline" alt="{\displaystyle \ y}"> end</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # exactly one {y}, not two (annotation + img alt)
    (([regex]::Matches($md, '\{y\}')).Count -eq 1)
}

Test-Case "extractor::strips_bidi_marks" {
    $html = "<div id=`"mw-content-text`"><p>$([char]0x200F)שלום$([char]0x200E) עולם</p></div>"
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    (-not ($md.Contains([char]0x200F))) -and (-not ($md.Contains([char]0x200E))) -and ($md -match 'שלום עולם')
}

Test-Case "extractor::strips_zero_width" {
    $html = "<div id=`"mw-content-text`"><p>אב$([char]0x200B)גד$([char]0xFEFF)הו</p></div>"
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    (-not ($md.Contains([char]0x200B))) -and (-not ($md.Contains([char]0xFEFF)))
}

Test-Case "extractor::converts_subscript_superscript_digits" {
    # H₂O -> H2O ; x² -> x2
    $html = "<div id=`"mw-content-text`"><p>H$([char]0x2082)O ו-x$([char]0x00B2)</p></div>"
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md -match 'H2O') -and ($md -match 'x2')
}

Test-Case "extractor::preserves_nikud" {
    # Nikud (vowel points) must survive untouched.
    $nikud = "ש" + [char]0x05B8 + "ל" + [char]0x05B9 + "ם"   # שָלֹם-ish
    $html = "<div id=`"mw-content-text`"><p>$nikud</p></div>"
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md.Contains([char]0x05B8)) -and ($md.Contains([char]0x05B9))
}

# ---------------------------------------------------------------------------
# pack.test — Split-IntoChunks
# ---------------------------------------------------------------------------

Test-Case "pack::groups_articles_into_chunks" {
    $items = 1..200
    $chunks = Split-IntoChunks -Items $items -ChunkSize 80
    ($chunks.Count -eq 3) -and
        ($chunks[0].Count -eq 80) -and ($chunks[1].Count -eq 80) -and ($chunks[2].Count -eq 40)
}

Test-Case "pack::chunk_index_matches_manifest" {
    # Flattening the chunks must reproduce the original order, so the global
    # index of item i lands in chunk floor(i/size) — the invariant the manifest
    # relies on.
    $items = 1..123
    $size = 40
    $chunks = Split-IntoChunks -Items $items -ChunkSize $size
    $flat = @()
    foreach ($c in $chunks) { $flat += $c }
    $orderOk = ($flat.Count -eq 123) -and ($flat[0] -eq 1) -and ($flat[122] -eq 123)
    # item at global index 95 -> chunk 2 (95 / 40 = 2)
    $idxOk = ($chunks[2] -contains $items[95])
    $orderOk -and $idxOk
}

# ---------------------------------------------------------------------------
# manifest.test — Get-CorpusTotalBytes / Get-PopularityScore / Resolve-ManifestVersion
# ---------------------------------------------------------------------------

Test-Case "manifest::sums_total_bytes_correctly" {
    $total = Get-CorpusTotalBytes -ChunkByteSizes @(81920, 81920, 40960)
    $total -eq 204800
}

Test-Case "manifest::popularity_in_0_100" {
    $max = 1000000L
    $vals = @(0L, 1L, 50L, 1000L, 50000L, 1000000L)
    $allInRange = $true
    foreach ($v in $vals) {
        $p = Get-PopularityScore -Views $v -MaxViews $max
        if ($p -lt 0 -or $p -gt 100) { $allInRange = $false }
    }
    # endpoints: max views -> 100; zero views -> >=0
    $allInRange -and ((Get-PopularityScore -Views $max -MaxViews $max) -eq 100)
}

Test-Case "manifest::version_bumps_on_change" {
    $bumped = Resolve-ManifestVersion -PrevVersion 4 -PrevHash 'aaa' -NewHash 'bbb'
    $kept   = Resolve-ManifestVersion -PrevVersion 4 -PrevHash 'aaa' -NewHash 'aaa'
    ($bumped -eq 5) -and ($kept -eq 4)
}

# ---------------------------------------------------------------------------
# runner
# ---------------------------------------------------------------------------

$pass = 0
$fail = 0
$results = @()
foreach ($t in $script:Tests) {
    $name = $t.Name
    $ok = $false
    $err = $null
    try {
        $ok = [bool](& $t.Body)
    } catch {
        $ok = $false
        $err = $_.Exception.Message
    }
    if ($ok) {
        $pass++
        $results += "PASS  $name"
    } else {
        $fail++
        $results += "FAIL  $name" + ($(if ($err) { "  ($err)" } else { "" }))
    }
}

Write-Host "------------------------------------------------------------"
$results | ForEach-Object { Write-Host $_ }
Write-Host "------------------------------------------------------------"
Write-Host "Ran $($script:Tests.Count) corpus-tooling tests: passed=$pass failed=$fail"
if ($fail -gt 0) {
    Write-Host "TOOLING TESTS FAILED"
    exit 1
}
Write-Host "TOOLING TESTS OK"
exit 0
