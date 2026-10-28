<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: 90fa65f · pack: b83a52b31a38 · attempt: 1 · recorded: 2026-10-28T20:31:38Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: FAIL 465s

## Critical
None.
## Major
1. .claude/hooks/handoff.sh:13 [regression] the Python probe must not add a second interpreter start to every `handoff.sh measure` call: `scripts/telemetry.sh:241` goes through the hook and the scan's python-start bound (one start per unmeasured file, `tests/telemetry.test.sh:648-660` shim) now counts double - repro: `bash tests/telemetry.test.sh --part scan` on the head gives `164 checks, 6 failed` (`the first scan starts python for the transcript and both subagents - expected [3], got [6]`, `a second scan starts no python for an already-recorded subagent - expected [1], got [2]`, `... --final scan ... expected [1], got [2]`); on the base 7f7c86e (`git show 7f7c86e:.claude/hooks/handoff.sh`, line 10 execs after `command -v` alone) the same part gives `164 checks, 0 failed`; `bash tests/full-suite.sh` is red on `bash tests/telemetry.test.sh --part scan` for the same six checks.
## Minor
- docs/specs/self-learning/plan.md:226 the `**Shipped:**` line sits directly under list item 3 with no blank line, so markdown folds it into the item; the stage scripts still read it.
- tests/telemetry.test.sh `--part install` failed in my full-suite run only because my concurrent `scripts/state.sh` comparison left `.claude/state.json.tmp*` in the tree (`the cached install equals a real install (diff -r)`); rerun alone on the head it is `31 checks, 0 failed` - not a finding on the diff.
- Delivered and checked: asks 1, 3, 4, 5 (prompt-check `ok (33 files)`, `state.sh` old-vs-new over the repo changes only `architecture-passport` to `study`, upgrade-keeps-host-edits `06-shipped` todo 0, both receipts show the missing behaviour, not a staged break); ask 6 is an at-ship task, not in this diff; `scripts/defects-check.sh` GREEN.
