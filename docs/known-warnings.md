# Known build warnings

Baseline warnings present on `main` as of M0. R8 (zero new warnings) compares
new PRs against this list; if a PR introduces a warning not listed here, R8 fails.

## Active warnings

1. **No supported languages in manifest.**
   `manifest.xml: No supported languages are defined. Language-specific resources will be ignored unless language support is added to the manifest file.`
   - Will be resolved when we add Hebrew support in M2.

## Resolved

- ~~**Launcher icon size mismatch (24x24 vs 70x70 for venu2).**~~ Resolved in
  M9.2 (`v0.M9.2`): shipped a proper 70x70 launcher icon
  (`resources/drawables/wikiwatch.png`), replacing the 24x24 `launcher_icon.svg`.
  Build now emits only the single language warning above.
