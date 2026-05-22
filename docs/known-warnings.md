# Known build warnings

Baseline warnings present on `main` as of M0. R8 (zero new warnings) compares
new PRs against this list; if a PR introduces a warning not listed here, R8 fails.

## Active warnings

1. **No supported languages in manifest.**
   `manifest.xml: No supported languages are defined. Language-specific resources will be ignored unless language support is added to the manifest file.`
   - Will be resolved when we add Hebrew support in M2.

2. **Launcher icon size mismatch (24x24 vs 70x70 for venu2).**
   `venu2: The launcher icon (24x24) isn't compatible with the specified launcher icon size of the device 'venu2' (70x70). The image will be scaled to the target size.`
   - Will be resolved when we ship a proper 70x70 launcher icon (M9 polish).
