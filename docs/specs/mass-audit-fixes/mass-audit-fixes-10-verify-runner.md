---
story: mass-audit-fixes-10
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 3
blocked_by: [mass-audit-fixes-08]
red: required
red_reason: invalidates the mark
---

# The verification runner: honest resume marks, refused staging failures, the baseline re-stamp, a load sample before the step

## Goal
`scripts/cycle.sh`: `verify_files_hash` expands a directory or glob `## Files` entry the way `red_sets` does
(`git ls-files -co --exclude-standard -- <entry>`) and hashes the files, so an edit under it invalidates a
`verify_resume` mark (G5); each `git add` in `close-story` is checked and a failure refuses with exit 2,
nothing written (G6); `stamp-red <story> --baseline` (ADR-032 D5) copies the story's implementation set aside,
writes each file to its `HEAD` content (a file new since HEAD is removed), stamps, and restores the copies in a
trap on every exit, with no `git stash`; the suite step takes its `LOAD: start` sample in the foreground before
`t0`, sample cap 5 s, and the stepped call cap is cut by the seconds already spent so no call passes 600 s
(X-08); `blockers_of` and `lib.sh` `fm_field` strip one layer of matching YAML quotes together, and
`status --json` escapes `spec`, `round_dir` and `next` (ask 3). `lib.sh` `is_paperwork_path` admits
`CITATION.cff` (I9, bumped in story 13). `.github/workflows/ci.yml`'s macOS job runs `load_sample` for real and
asserts a `cpu <N>%` line (X-07). Asks 3, 8, 9, 11 (G5, G6, I5 code half). Marked red: runner branches.

## Requirements
> 3. P9-06 extended: a quoted front-matter value is unquoted in `fm_field` and `blockers_of` together, and `status --json` escapes `spec`, `round_dir` and `next` too.
> 8. X-07: the macOS branch of `load_sample` runs for real on macOS (CI), not only against a stub.
> 9. X-08: the suite's `LOAD: start` sample is taken before the step starts and does not overlap it.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- tests/cycle.test.sh
- tests/council.test.sh
- .github/workflows/ci.yml

## Non-goals
- Do not change `load_sample` itself (X-07 merged it); only run it on CI.
- Do not touch `briefed`, `branch`, the block-card call, scope-check or wave-check (story 08, landed), nor
  `approved_rev` / D2 (story 05, landed).
- Do not let workers run `--baseline`: `worker-code.md` keeps NEEDS_CONTEXT (story 13 writes the prose; this
  story writes the verb).
- Do not bump `CITATION.cff` (story 13); only the whitelist line.
- Do not edit the two test suites outside the `red`, `close` (cycle) and `suite`, `hardening` (council) parts.

## Map slice
`memory/map/cycle.md` → Verbs (close-story Verify runner, Red receipt, `suite` LOAD lines), Repair;
`memory/map/scripts.md` → Entry points (`lib.sh` red helpers, `load_sample`, `capped_by`), Key contracts, Gotchas.

## Acceptance criteria
- [ ] `--part close`: Files `- src/`, two lines, a pause after line 1, an edit under `src/`, a rerun: line 1
  runs again on the new code and a failing change is not committed (label contains `invalidates the mark`); the
  mark still resumes when nothing under the entry changed.
- [ ] `--part close`: a `git` shim failing one `add` makes `close-story` exit 2 with nothing committed and
  `status:` untouched.
- [ ] `--part red`: a sealed test edited after green, implementation dirty: `stamp-red --baseline` writes the
  receipt against HEAD's implementation and restores the working copy byte for byte, also when the stamp exits
  4; a file new since HEAD is back afterwards; no stash entry exists.
- [ ] `--part suite`: with a stub sampler that records a timestamp, the `LOAD: start` sample completes before
  the step command starts; the stepped call cap is reduced by the sample's seconds; the FAIL-only write rule
  is unchanged.
- [ ] `--part hardening`: a story with `blocked_by: ["x-01"]` and `worker: "worker-code"` resolves like the
  unquoted form; `status --json` with a spec path and a story file name holding `"` and `\` is valid JSON.
- [ ] CI: the macOS job prints a `cpu <N>% top:` line from `load_sample` and fails if it does not.

## Verification
`bash tests/cycle.test.sh --part red && bash tests/cycle.test.sh --part close`
`bash tests/council.test.sh --part suite && bash tests/council.test.sh --part hardening`

## Implementation notes

## Findings
