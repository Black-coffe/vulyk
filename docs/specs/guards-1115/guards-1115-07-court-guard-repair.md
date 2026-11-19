---
story: guards-1115-07
status: done
returned: DONE
worker: worker-code
model: opus
wave: 5
blocked_by: [guards-1115-06]
red: required
red_reason: ::error::court guard r2:
red_verified_at: 2026-11-16T12:56:44Z 5c3c7f2be8d14df895e7cabd62f8d81a8ca96fb6b5c6723d96a4e7dfa8f8cef3
---

# Repair round 2: court-guard

## Goal
Make the asks and findings council round 2 left RED pass for this hook, and change nothing else.

## Requirements
> 5. The blind council seat's court cannot be left through the named form classes: git reads by an allowlist wherever git stands as a command; paths resolved (dot-dot, a link or junction, one made in the same call, letter case), a path glued to its option, held in a variable set in the same call, inside a quoted substitution, or a file URL; no system-path escape. Any other form is named open in the header (private S7, S8, S9).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Findings
ASK 5: RED - blind seat cannot leave its court through the named classes - run: court-guard.sh as council-opus standing in this court, 59 calls (a5b), and 135 on a /tmp court (a5) saw: plain sibling-round paths, cd, links made in the call, system-path dot-dot and the main session's temp folder denied; passing: a non-allowlisted git verb after a keyword, `!`, a redirect, timeout, nice, xargs, eval, a -c string, a variable or inside a substitution; a dot-dot path that starts inside the court; a path glued to its option (3 of 4 tools); a path held in a variable set in the same call; a path inside a quoted substitution; a file URL; a backslash path
ASK 6: RED - header-named forms closed, headers exact and worded for a cooperative agent - run: git-guard.sh with 27 forced-tag, forced-push and iex forms; grep -i "adversar|cooperative" over .claude/hooks saw: all 4 forced-tag, 13 push and 5 iex forms denied, a plain tag passes (closed as answered); but zero matches for the cooperative-agent sentence in any hook header, and the open lists omit the forms asks 1, 4 and 5 measured open
ASK 7: RED - a test per closed gap with a neighbour, no legitimate flow denied - run: the three test parts above; court-guard.sh on a seat's own flows saw: parts green (730 checks 0 failed; 279 ok; runstate 15 ok), but court-guard denies a seat writing its report by a relative path into the reports folder (the absolute spelling passes) and a Read of a file in its own court spelled in another letter case, and the classes named in asks 1, 3, 4, 5 have no test because they are not closed
8. .claude/hooks/court-guard.sh:442 [ask 5] the git allowlist of the seat must hold wherever git stands as the command of a simple command, not only as its first word: after `!`, `then`, `do` or `else`, a leading redirect, an option of `time` / `command` / `exec` / `env`, `eval`, a quoted command substitution or a variable command word, :452 never calls `check_git` and a verb off the list reads history (round 1 line 8, unchanged).
9. .claude/hooks/court-guard.sh:308 [ask 5] the court path rule must judge the path forms the narrowed ask now names: a path held in a variable set in the same call or inside a quoted substitution (:316), a file URL (:313), a dot-dot behind a glob prefix (:325), and must close or name open in the header a redirect glued to a word (:308) and a `cd` that does not take effect (:434); each still reads outside the court (round 1 line 11, now named by ask 5; my rerun of the round 1 court cases gave the same 233 results).
11. .claude/hooks/git-guard.sh:79 [ask 6] the open list of each header must name every form the hook lets through and say that the guards stop accidents and shortcuts of a cooperative agent, not an adversary: the forms of lines 2-9 stand in none of the three lists (git-guard.sh:79-94, owner-guard.sh:70-88, court-guard.sh:34-41), and `grep -n -i -e cooperative -e adversar .claude/hooks/git-guard.sh .claude/hooks/owner-guard.sh .claude/hooks/court-guard.sh` prints nothing.

Queen answers (2026-11-16, before the build; the owner chose «Ремонт классами + сузить вопросы (Рекомендую)» after
round 1 and «Теперь в ремонт классами (Рекомендую)» after round 2):
- Round 2 judged the round-1 code unchanged (no repair had run). This story is that repair, for both rounds' findings.
- Fix by class, not by spelling: resolve a path once (letter case, dot-dot, trailing dot or space, links) and judge
  the resolved form; under a DRIVER give a subagent a read list of git verbs and refuse the rest; find git and
  `cycle.sh` in every command position the asks name, through the shared segment walker of each hook; what the hook
  cannot resolve (a variable or substitution in the program word or in a target next to a guarded path) is refused
  for a subagent. Keep each hook's existing helpers; no new framework.
- Exact forms of every finding: private `~/.vulyk/audits/known-defects-2026-11-15/guards-review-r1.md` (items N1-N8,
  R1, OD1-OD3) and the round reports. Tests, comments, labels and commit text name the class in general words; a
  form left open is named in the header only in general words (brief `## Privacy`).
- Each header (git-guard, owner-guard, court-guard) gets one sentence: the guards stop accidents and shortcuts of a
  cooperative agent, not an adversary; then its exact open list.
- Over-denies are tests of allowed calls: a subagent `python3 -c "print(6 * 7)"`, interpreter or heredoc text with a
  lone `*`, `**` or `$name`, `sed -i '$d' <file>`, `echo x > "$OUT"`, `xargs sed -i`, `bash "$CLAUDE_PROJECT_DIR/scripts/x.sh"`,
  a seat writing its report by a relative path into its reports folder, a seat Read of a file in its own court in
  another letter case: each passes.
- Finding 1 (tests/full-suite.sh, parts at 212-213 s): not a code fault. Re-timed on an idle machine: cycle:red 172 s,
  telemetry:install-xp2 167 s, telemetry:edits 175 s (cut line 210 s); the round-2 run shared the machine with the
  seats. Do not touch tests/full-suite.sh or those parts.
- Finding 12 (plan.md `## Descoped`): the Queen wrote it (paperwork). Do not edit plan.md.
- `tests/maintenance.test.sh` runs near its cap (about 268 s): put new cases in tests/defects.test.sh where it fits.

- Worker (2026-11-16): stopped during reading, before any test or code edit. No hook, test or card was touched; no
  red receipt was stamped. The story covers three hooks of about 2900 lines, twelve findings and seven asks in one
  dispatch. A re-dispatch should split it, one hook per story (git-guard, owner-guard, court-guard).
- Split (2026-11-16, after the first worker's NEEDS_CONTEXT): one story per hook, each with its own test file and
  card: 05 git-guard (tests/maintenance.test.sh, card work-discarded-by-git-verb), 06 owner-guard (tests/defects.test.sh,
  card owner-words-by-builder), 07 court-guard (tests/inject.test.sh, wave 5). A finding on another hook is that
  story's; ASK 6 and ASK 7 lines are shared: each story fixes its own hook's part.
- This is defensive work on this repository's own guard hooks: read the exact forms from the private file, write
  tests that the hook refuses them, and do not copy a working form of a still-open class anywhere.
- Findings 2 and 3 ("pass both hooks") are git-guard's (story 05): plan A1 gives shell writes of the run state and
  `cycle.sh` verbs to git-guard, Edit/Write to owner-guard; one hook refusing a call is enough.
- Worker (2026-11-16): stopped during reading, before any test or code edit; no red receipt stamped. The acceptance
  criterion asks for the class card under docs/defects/ in the same commit as the fix, but `## Files` names no card
  (05 named work-discarded-by-git-verb.md, 06 owner-words-by-builder.md; no card mentions court-guard), so close-story
  would refuse any card edit as outside `## Files`. Question: which card does this story update - likely
  `docs/defects/safeguard-bypassable-or-late.md` - and please add it to `## Files` (or drop the criterion).
- Queen (2026-11-16): no card edit in this story. The class is card `safeguard-bypassable-or-late` (Never: "call a
  guard protection without naming how it is walked around"); it holds no owner quote to add and no check: (none can
  be generic). Its rule is met by court-guard's header open list, by class. The card criterion is replaced by that.
- Worker (2026-11-16, third dispatch): the red test is written in tests/inject.test.sh (block "guards-1115-07",
  labels `court guard r2:`; run by hand: 284 checks, 51 failed, every failure on a new r2 case) and `red_reason`
  is set, but `stamp-red` refused with exit 3: `paused: Andrei · story 05's over-deny fix let a defaulted variable
  naming git through (probe: refused before, passes now); add story 08 before round 3 · 2026-11-16T12:45:08Z`.
  No court-guard.sh edit was made (no receipt). Resume: lift the pause, then re-dispatch; the next worker runs
  stamp-red first and builds on the test as written. Root causes already found while reading: a cwd in the Git
  Bash spelling is joined unconverted (relative paths resolve to the wrong drive: the report and letter-case
  over-denies), and /tmp is mapped only in lower case.

## Implementation notes
- tests/inject.test.sh: the r2 block written by the third dispatch, unchanged; red receipt stamped first.
- .claude/hooks/court-guard.sh: the Bash half now walks a tokenized command (words, separators, redirects, subshells) instead of flat segments; redirects split off any word and judged on every command, `2>` descriptors dropped.
- Command position: `head()` skips assignments, keywords and wrappers (WRAP table, with their value options); eval and `sh -c` strings and every `$( )`, backtick and `<( )` body are walked again; a program word with `$`, a brace or a wildcard is denied; git under xargs is denied.
- Paths: `full()`/`native()` convert the Git Bash cwd (root cause of the report and letter-case over-denies) and /tmp in any case; a `..` step anywhere makes a word path-shaped; glued short-option values, `--opt=` values, file URLs and `for` lists are judged; a variable set earlier in the call is expanded.
- cd: followed only where it surely takes effect; otherwise every candidate folder is kept and each judged; more than one folder or a CDPATH is denied.
- drop_heredocs takes the whole delimiter word and skips `<<` in a comment or `(( ))`; comments are cut quote-aware (shlex commenters off), so a mid-word `#` no longer hides the rest of a line.
- Header: the cooperative-agent sentence and the exact open list in general words (card safeguard-bypassable-or-late, no card edit).
- Surprise: the Bash tool collapses `\\` inside heredocs; the backslash literals were fixed with Edit.

## Acceptance criteria
- [ ] court-guard's header names every form it leaves open, by class (card safeguard-bypassable-or-late, Never line 1); no card edit.

## Files
- .claude/hooks/court-guard.sh
- tests/inject.test.sh

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: 5c3c7f2be8d14df895e7cabd62f8d81a8ca96fb6b5c6723d96a4e7dfa8f8cef3 (tests/inject.test.sh)
- impl: ce2fa7c66360f0481572665487847cdf072f5ecd292a7776846a32b5e947625d
- stamped: 2026-11-16T12:56:44Z

```
::error::court guard r2: deny from round-1: ! git show HEAD~1:docs/specs/acme/plan.md - expected 'deny', got 'allow'
::error::court guard r2: deny from round-1: if true; then git log -p; fi - expected 'deny', got 'allow'
::error::court guard r2: deny from round-1: for i in 1; do git log -p; done - expected 'deny', got 'allow'
  ok    court guard r2: a Read of the seat's own court in another letter case passes (drive form)
  ok    court guard r2: a Read of the main tree in another letter case is denied
--- latency
  median defects-inject.sh (Bash): 162 ms over 30 calls (fixture library; target <= 200 ms)
  ok    median latency, Bash, <= 200 ms
  median defects-inject.sh (Edit): 159 ms over 30 calls (fixture library; target <= 200 ms)
  ok    median latency, Edit, <= 200 ms
  median defects-inject.sh (Read, not a story): 83 ms over 30 calls (fixture library; target <= 100 ms)
  ok    median latency, non-story Read, <= 100 ms
inject.test.sh: 287 checks, 51 failed
```
