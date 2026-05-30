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

Test-Case "extractor::strips_nikud" {
    # Nikud / cantillation (combining vowel points) are removed; the base
    # consonants survive. שָׁלֹום -> שלום. The maqaf (U+05BE, a connector) is
    # NOT nikud and must be kept.
    $word = "ש" + [char]0x05B8 + [char]0x05C1 + "ל" + [char]0x05B9 + "ו" + "ם"
    $html = "<div id=`"mw-content-text`"><p>$word ובן" + [char]0x05BE + "גוריון</p></div>"
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # no combining marks left, base letters intact, maqaf kept
    (-not ($md.Contains([char]0x05B8))) -and (-not ($md.Contains([char]0x05B9))) `
        -and (-not ($md.Contains([char]0x05C1))) -and ($md -match 'שלום') `
        -and ($md.Contains([char]0x05BE))
}

# ---------------------------------------------------------------------------
# extractor.test — block spacing + tables (M8.2 corpus formatting)
# ---------------------------------------------------------------------------

Test-Case "extractor::bullets_single_newline_between" {
    $html = '<div id="mw-content-text"><ul><li>א</li><li>ב</li><li>ג</li></ul></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    $lines = $md -split "`n"
    $i = [array]::IndexOf($lines, '- א')
    # consecutive bullets are adjacent lines (no blank line between).
    ($i -ge 0) -and ($lines[$i+1] -eq '- ב') -and ($lines[$i+2] -eq '- ג')
}

Test-Case "extractor::header_single_newline_after" {
    $html = '<div id="mw-content-text"><h2>כותרת</h2><p>גוף הטקסט</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    $lines = $md -split "`n"
    $i = [array]::IndexOf($lines, '## כותרת')
    # body line directly follows the header (no blank line between).
    ($i -ge 0) -and ($lines[$i+1] -eq 'גוף הטקסט')
}

Test-Case "extractor::initial_h1_keeps_blank_line" {
    # The very first '# <title>' is exempt — it keeps its blank line.
    $html = '<div id="mw-content-text"><p>גוף</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'ראשי'
    $lines = $md -split "`n"
    ($lines[0] -eq '# ראשי') -and ($lines[1] -eq '')
}

Test-Case "extractor::table_emits_tavla_header_and_rows" {
    $html = '<div id="mw-content-text"><table class="wikitable"><tr><th>כותרת1</th><th>כותרת2</th></tr><tr><td>א</td><td>ב</td></tr></table></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # smallest header size (h4); cells (incl. header row) separated by " | ".
    ($md -match '(?m)^#### טבלה:') -and ($md -match '(?m)^כותרת1 \| כותרת2\s*$') -and ($md -match '(?m)^א \| ב\s*$')
}

Test-Case "extractor::table_colspan_repeats_value" {
    $html = '<div id="mw-content-text"><table class="wikitable"><tr><td colspan="2">מוזג</td></tr><tr><td>א</td><td>ב</td></tr></table></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # merged (colspan=2) cell value written for BOTH columns, " | " separated.
    ($md -match '(?m)^מוזג \| מוזג\s*$')
}

Test-Case "extractor::table_rowspan_repeats_down" {
    $html = '<div id="mw-content-text"><table class="wikitable"><tr><td rowspan="2">מ</td><td>א</td></tr><tr><td>ב</td></tr></table></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    # rowspan=2 value carried into the second row's first column.
    ($md -match '(?m)^מ \| א\s*$') -and ($md -match '(?m)^מ \| ב\s*$')
}

Test-Case "extractor::removes_external_links_section" {
    $html = '<div id="mw-content-text"><h2>תוכן</h2><p>גוף אמיתי</p><h2>קישורים חיצוניים</h2><ul><li>אתר רשמי</li></ul></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md -match 'גוף אמיתי') -and (-not ($md -match 'קישורים חיצוניים')) -and (-not ($md -match 'אתר רשמי'))
}

Test-Case "extractor::removes_footnotes_section" {
    $html = '<div id="mw-content-text"><p>גוף</p><h2>הערות שוליים</h2><p>הערה כלשהי</p></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    ($md -match 'גוף') -and (-not ($md -match 'הערות שוליים')) -and (-not ($md -match 'הערה כלשהי'))
}

Test-Case "extractor::bullets_no_blank_before_first" {
    $html = '<div id="mw-content-text"><p>פסקה ראשונה</p><ul><li>פריט</li></ul></div>'
    $md = Convert-WikiHtmlToMarkdown -Html $html -Title 'בדיקה'
    $lines = $md -split "`n"
    $i = [array]::IndexOf($lines, '- פריט')
    # the first bullet sits directly under the preceding paragraph (no blank line).
    ($i -ge 1) -and ($lines[$i-1] -eq 'פסקה ראשונה')
}

# ---------------------------------------------------------------------------
# pack-index.test — M9 index-part packing
# ---------------------------------------------------------------------------

Test-Case "pack-index::splits_into_parts_under_cap" {
    $dir = [System.IO.Path]::Combine($env:TEMP, "pki_test_$(Get-Random)")
    New-Item -ItemType Directory -Path $dir | Out-Null
    # Write a packed.tsv with 400 articles (expect ~3 parts at 10KB cap, ~133/part)
    $sw = [System.IO.StreamWriter]::new("$dir\packed.tsv", $false, [System.Text.UTF8Encoding]::new($false))
    $sw.WriteLine("id`ttitle`tpopularity")
    for ($i=0; $i -lt 400; $i++) { $sw.WriteLine("$i`tכותרת-$i`t$([Math]::Max(1,100-$i))") }
    $sw.Close()
    & "$PSScriptRoot\pack-index.ps1" -InDir $dir -OutDir "$dir\index" *>&1 | Out-Null
    $parts = @(Get-ChildItem "$dir\index" -Filter *.json -ErrorAction SilentlyContinue)
    $meta = Get-Content "$dir\index-meta.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    ($parts.Count -gt 1) -and ($meta -ne $null) -and ($meta.indexCount -eq $parts.Count) `
        -and ($meta.indexUriPattern -eq "/index/{n}.json")
}

Test-Case "pack-index::all_parts_under_12kb" {
    $dir = [System.IO.Path]::Combine($env:TEMP, "pki_cap_$(Get-Random)")
    New-Item -ItemType Directory -Path $dir | Out-Null
    $sw = [System.IO.StreamWriter]::new("$dir\packed.tsv", $false, [System.Text.UTF8Encoding]::new($false))
    $sw.WriteLine("id`ttitle`tpopularity")
    for ($i=0; $i -lt 300; $i++) {
        $title = "ישראל מדינה עם היסטוריה ארוכה ועשירה אשר כוללת " + $i
        $sw.WriteLine("$i`t$title`t$([Math]::Max(1,100-$i))")
    }
    $sw.Close()
    & "$PSScriptRoot\pack-index.ps1" -InDir $dir -OutDir "$dir\index" *>&1 | Out-Null
    $over = @(Get-ChildItem "$dir\index" -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 12288 }).Count
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    $over -eq 0
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
