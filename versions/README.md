# versions

Frozen artifacts from each merged milestone. One `.prg` per `M<N>` plus the git tag
`v0.M<N>` that points at the merge commit on `main`.

| File | Tag | What works |
| --- | --- | --- |
| (M0 lands here once merged) | `v0.M0` | toolchain + TDD pipeline + CR-ist workflow |

Restoring an old version:

```powershell
git checkout v0.M<N>
& scripts\build.ps1
```

Or sideload directly: copy `versions/wikiwatch-M<N>.prg` to `GARMIN\APPS\` on a Venu 2.
