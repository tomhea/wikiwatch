# CR rules

These are the eight hard requirements every PR into `main` must satisfy.
The CR-ist agent enforces them mechanically. Don't argue with it - fix the violation.

Each rule has a one-letter ID so review comments can quote it (`R1 fail: ...`).

## R1 - Tests first, evidence in PR body
The PR description MUST contain two fenced code blocks:
1. `scripts/test.ps1` output showing the new test(s) FAILing (run before implementing the change).
2. `scripts/test.ps1` output showing the same tests PASSing (run after implementing the change).
If only the passing output is shown, the rule fails - we cannot tell whether the test would have caught the regression.

## R2 - Simulator evidence for UI changes
Any change that touches `source/views/`, `source/delegates/`, `resources/`, or layout math
MUST include either:
- a simulator screenshot (PNG attached to the PR), OR
- a paste of `monkeydo` stdout that demonstrates the new behaviour (e.g. `KEY pressed: 'ש'`).

## R3 - Test coverage on touched logic
Every new or modified `.mc` file under `source/models/`, `source/state/`, `source/storage/`,
or `source/net/` MUST have at least one new `(:test)` function exercising the new branch.
Pure render code under `source/views/` is exempt (R2 covers it).

## R4 - Storage write guard
Every `Application.Storage.setValue(...)` call MUST be preceded (within the same function or
its caller) by a `System.getSystemStats().freeMemory` check that proves at least
`3 * size_of_value` bytes are free. OOM in Monkey C is uncatchable - we cannot defend
after the fact.

## R5 - Allocation guard
Any single allocation expected to exceed ~4 KB (string concatenation in a loop, JSON parsing,
Array of N>500, byte buffer) MUST be preceded by the same `freeMemory` check.
The peak for a doubling string builder is ~1.5 x N.

## R6 - Module placement
Pure logic with NO side effects, NO `Application.Storage.*`, NO `WatchUi.*`, NO
`Communications.*`, NO `System.*` clocks MUST live in `source/models/`.
Anything that touches those APIs MUST NOT live in `source/models/`.
Easy test: a module under `source/models/` should be unit-testable without a simulator runtime.

## R7 - Branch & PR naming
- Branch: `mN-feature-slug` (lowercase, kebab) for milestone branches, `sN-...` for spikes.
- PR title: exact format `M<N>: <feature>` for milestone PRs, `Spike: <topic>` for spikes.
- PR body contains a `## TDD evidence` section (R1) and a `## Simulator evidence` section (R2 if applicable).

## R8 - Zero new warnings
Build must succeed with `monkeyc -w` and introduce no new warning lines compared to the
parent commit's build. If the existing codebase has warnings, list them in `docs/known-warnings.md`
so the diff is clear; new warnings outside that list fail R8.

---

## Verdict format the CR-ist uses

When the agent reviews a PR, the final review body is one of:

```
APPROVED
All R1-R8 pass.
```

or

```
CHANGES REQUESTED
R<id> fail: <one-line reason>
R<id> fail: <one-line reason>
...
```

Inline comments quote the offending lines with `R<id>:` prefix.
