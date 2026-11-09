---
story: mass-audit-fixes-10
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 3
blocked_by: [mass-audit-fixes-08]
red: required
red_reason: invalidates the mark
red_verified_at: 2026-11-09T14:31:12Z fa48b8bf6fce95008fa9e65b30bcb5f2421b29e5aaafa19cdab9fd748d15a336
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
- scripts/cycle.sh `verify_files_hash`: expands dir/glob entries via `git ls-files -co --exclude-standard` (red_sets' rule), sorted; the hash order changed, so a mark written by the old code restarts at line 1 once.
- scripts/cycle.sh close-story: `cs_add` checks every `git add`; on failure it unstages what it staged, puts `status:` back and exits 2 `git add failed: <path>`. An entry git lists nothing for (never created, ignored) is skipped, as before.
- scripts/cycle.sh `stamp-red --baseline`: `red_baseline_swap`/`red_baseline_restore` (EXIT trap, plus INT/TERM/HUP turned into exits); HEAD content comes from `git show HEAD:<p>` (raw blob, no eol smudge). It does not remove empty directories it creates.
- scripts/cycle.sh suite: the `LOAD: start` sample runs in the foreground before t0 with a 5 s cap; stepcap = min(VULYK_STEP_CAP, 590) - SECONDS, floor 1. The sxhung test now uses cap 6 and accepts the cut value.
- scripts/cycle.sh `fm_unquote` (variable, no subshell) is used by `fm_line_value` (so fm_field and fm_status_wave) and per entry in `blockers_of`; `status --json` also escapes spec, slug (needed for valid JSON), next and round_dir. `fm_field` lives in cycle.sh, not lib.sh.
- scripts/lib.sh: `CITATION.cff` added to is_paperwork_path. ci.yml: macOS step runs load_sample and asserts `^cpu [0-9]+% top: `.
- Tests: the red part also got a stamp-red resume-mark case (G5 runs through the same hash), which carries the red_reason text; the P9-06 hardening case now expects the unquoted values.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part red && bash tests/cycle.test.sh --part close
- exit: 1
- tests: fa48b8bf6fce95008fa9e65b30bcb5f2421b29e5aaafa19cdab9fd748d15a336 (tests/council.test.sh, tests/cycle.test.sh)
- impl: 1be35f226b17eb37db403697571719d7b292725ad4a45fb7b8d3f52f34cbe11d
- stamped: 2026-11-09T14:31:12Z

```
::error::stamp-red: an edit under a ## Files directory invalidates the mark - exit=0 receipt=## Red receipt
  ok    red-14 stamped
  ok    the receipt seals tests/red14.sh, not the implementation or the lint config
  ok    an edit to the verification-named lint config does not break the seal: closed
  ok    red-15 stamped
  ok    the repo script the line runs is sealed beside its test argument
  ok    a checker weakened after the stamp: exit 4
  ok    no test-shaped path: the seal falls back to every verification path under ## Files
red-receipt: close-story on a marked story that was never stamped
  ok    the unstamped story: exit 4, nothing committed
  ok    the refusal names stamp-red and the story
```
