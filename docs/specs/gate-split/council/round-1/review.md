<!-- seat: review · model: claude-opus-5-5 · round: 1 · head: 48b20ba · pack: e86c1131360a · attempt: 1 · recorded: 2026-11-02T22:08:23Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: FAIL 734s - part full-suite failed, part maintenance failed
MODEL: claude-opus-5-5

## Critical
1. tests/full-suite.test.sh:171-177 [regression] suite full-suite, check "a job inside the cap is ok": the runner test must not depend on a trivial job ending inside a 1 s window, because under VULYK_PART_CAP=1 on the uncapped path tests/full-suite.sh:154 reads `secs -ge PART_CAP` on whole-second SECONDS, so under the round's contention `mark` measured 1s and came out `PART mark CAP 1s cap 1s` (round log line 34, part log /tmp/tmp.oBaKnOGzuT/29.log); it passes alone, so the round gate is red at random - repro: `bash tests/full-suite.test.sh` inside a loaded step (alone: green).
2. scripts/cycle.sh:3473 [regression] suite maintenance, check "portability-check: the tree exits 0" (2 failed): scripts/cycle.sh must pass the card shell-needs-gnu-or-bash4 gate, but the comment added inside cmd_repair's multi-line `findings="$(` puts an unpaired apostrophe ("round's") inside a $( ), which bash 3.2 reads as an open quote, and the gate now reports 8 case-in-subst hits at cycle.sh:3583-3779; base is clean - repro: `bash scripts/portability-check.sh scripts/cycle.sh` (8 hits) vs `git show b054df7:scripts/cycle.sh > /tmp/c.sh && bash scripts/portability-check.sh /tmp/c.sh` (ok).

## Major
1. scripts/cycle.sh:1619 [ask 9] the round gate must run every `Full suite ... (round-only)` row of a hive's `## Commands` as its own capped part, but full_suite_row exits at the first matching row and cmd_suite (scripts/cycle.sh:3042, 3058) sets S=1, so a hive that splits its row as install.sh:1517-1518 and .claude/commands/vulyk-update.md step 6 tell it to never runs its second and later rows and still records SUITE: ok - repro: a constitution with rows `| Full suite unit (round-only) | \`bash a.sh\` |` and `| Full suite e2e (round-only) | \`bash b.sh\` |` -> full_suite_row prints only `bash a.sh`.
2. scripts/cycle.sh:1613-1617 [regression] the `## Commands` row parser that cmd_suite executes must take exactly the second cell and refuse an empty one: `c = substr(line, i + 1)` keeps every later cell, so `| Full suite (round-only) |  | echo PWNED |` yields the command `| echo PWNED` where base refused the empty cell (`c ~ /^\|/` -> next, `git show b054df7:scripts/cycle.sh` full_suite_row_round_only: not found, SUITE: none), and `| Full suite (round-only) | \`bash t.sh\` | echo PWNED |` yields `bash t.sh | echo PWNED`, which cmd_suite runs through `bash -c` (scripts/cycle.sh:3060-3087) - repro: source full_suite_row from both revisions and feed those two three-column rows.

## Minor
- scripts/cycle.sh:2048 verify_files_hash hashes a `## Files` entry that is a directory or a glob as the literal `missing <path>`, so edits under it do not invalidate a `verify_resume` mark and a resumed close-story skips lines that ran on older code.
- The log's `head=57270fb` is the ROUND head; the dispatched head 627d5f1 is the open-round paperwork commit on top of it, so the log was taken as this head's.
- Plan delta 1 tail stands: CLAUDE.md's `Cycle` row (`bash tests/cycle.test.sh`, 307-309 s alone) is itself over the 300 s per-line cap any story naming it now hits.
