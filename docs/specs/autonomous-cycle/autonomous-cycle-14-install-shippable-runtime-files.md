---
story: autonomous-cycle-14
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [autonomous-cycle-07]
---

# The installer never ships a file its own `.gitignore` ignores

## Goal
`install.sh` stops copying the maintainer's runtime artifacts into target hives. `shippable()` refuses every path VULYK's own `.gitignore` ignores — the pinned-model file above all — and the `install-smoke` CI job proves that a fresh install and an `--upgrade` leave none of them in the target.

## Requirements
> `shippable()` in `install.sh` has no exclusion for gitignored runtime files, so `copy_tree ".claude"` copies the maintainer's `.claude/settings.local.json` (the pinned model) and other runtime artifacts into every install/upgrade target.

> the installer must never ship a file that its own `.gitignore` ignores — `.claude/settings.local.json`, `.claude/handoff/`, `.claude/state.json`, `.claude/.vulyk-update-cache`, `.claude/settings.json.vulyk-bak`, `memory/snapshots/*`, `memory/map/.stale`, `__pycache__` — and the install-smoke CI job proves it.

## Files
- install.sh
- .github/workflows/ci.yml

## Non-goals
- Do not change what `--upgrade` overwrites (`OWNED`) or the marker-block blanking; this story is only about what is never copied.
- Do not read `.gitignore` at runtime to derive the list — a target hive's `.gitignore` is not VULYK's; keep an explicit list in `shippable()` next to the existing `docs/specs/*` and `memory/learnings/*` exclusions, with a comment naming `.gitignore` as the source of truth to keep in sync.
- Do not touch `ensure_gitignore()`'s wanted list (story 07 already extended it) or `wire_permissions()`.
- Do not run `install.sh` against this repository or any real directory — smoke-test only in a `mktemp -d` target, and delete it and any log you wrote.

## Map slice
`docs/specs/autonomous-cycle/recon/scout-install.md` §Key types (`shippable()` at `install.sh:40-48`, `copy_tree` walks `find "$rel" -type f` — so ignored files are copied), §Answer 5 (the full `.gitignore` list) · `docs/specs/autonomous-cycle/autonomous-cycle-07-install-and-session-brief.md` `## Implementation notes` (where the defect was found) · `.github/workflows/ci.yml` job `install-smoke` (lines ~107-153 before story 01's additions).

## Acceptance criteria
- [ ] `shippable()` returns non-zero for every path matching: `.claude/settings.local.json`, `.claude/settings.json.vulyk-bak`, `.claude/state.json`, `.claude/.vulyk-update-cache`, `.claude/vulyk-version`, `.claude/handoff/*`, `memory/snapshots/*` (the `.gitkeep` stays shippable), `memory/map/.stale`, `*/__pycache__/*`, `*.pyc`, `CLAUDE.local.md` — and still returns zero for everything it shipped before.
- [ ] A fresh install into an empty `mktemp -d` target from a source tree that contains a dummy `.claude/settings.local.json`, `.claude/handoff/x.md`, `.claude/state.json` and `memory/snapshots/2026/x.md` leaves none of those four in the target; `--upgrade` into the same target leaves none either; `.claude/vulyk-version` in the target is the one `install.sh` stamps, not a copy.
- [ ] The `install-smoke` CI job plants those dummy files in the checkout before its runs and asserts their absence in the target with `test ! -e`; the job still passes its existing dry-run / real-run / idempotency assertions.
- [ ] `bash -n install.sh` passes; the `--check` dry run prints `would skip (runtime)` or similar for a planted file so a maintainer can see the exclusion working.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `install.sh` `shippable()`: added the 10 acceptance-listed paths as case arms returning a new code `2` (vs. `1` for vulyk's own dev content like `docs/specs/*`), so `copy_tree` can tell "gitignored runtime artifact" apart from "vulyk's own dev content" for the `--check` message. `.gitkeep` exception for `memory/snapshots/*` mirrors the existing `memory/learnings/*`/README.md pattern (moot in practice since `find ... ! -name '.gitkeep'` already filters it, but needed for a direct `shippable()` call to return 0).
- `copy_tree`: `shippable "$f" || continue` became `shippable "$f" && sc=0 || sc=$?; [ "$sc" -ne 0 ] && { [ "$sc" -eq 2 ] && [ check ] && echo "would skip (runtime) $f"; continue; }` - captured via `&&`/`||` (not a bare `;`) so a nonzero `shippable` return can't trip `set -e`.
- **Found while smoke-testing**: `top-model.sh --apply` (story 07) legitimately creates the target's OWN `.claude/settings.local.json` after the copy loop regardless of `shippable()` - so "leaves none of those four in the target" cannot mean the path is absent for that one file. Planted it with a sentinel value (`__vulyk_smoke_leak_marker__`) instead of a plausible model name, and asserted the sentinel is absent rather than the path - this is what both my local smoke test and the new CI step do. The other three (`.claude/handoff/x.md`, `.claude/state.json`, `memory/snapshots/2026/x.md`) have no such second writer and are asserted absent by path.
- `.github/workflows/ci.yml` `install-smoke`: added one "plant dummy runtime artifacts" step (right after checkout, so it's in place for every later step) and one new step asserting `--upgrade` into the same target ships none either; extended the existing "real install" step with the same four assertions plus a `.claude/vulyk-version` content check (must equal `VERSION`, not the planted `BOGUS-VERSION`); extended the `--check` step with a `would skip (runtime) .claude/settings.local.json` grep.
- Smoke-tested by hand in `mktemp -d` (never against this repo or a real directory, per the story's non-goal): copied the repo into a temp dir, planted the four/five dummies there, ran `--check`, a fresh install, and `--upgrade` into the same target, verified all four negative assertions plus the vulyk-version and settings.local.json sentinel checks, then re-ran the pre-existing idempotency and foreign-CLAUDE.md steps to confirm no regression. All temp dirs deleted afterward, no log file written anywhere.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
