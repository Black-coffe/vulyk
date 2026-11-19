---
story: guards-1115-06
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason: ::error::owner guard r2:
red_verified_at: 2026-11-16T12:10:30Z e2e3b0cc67efe6ef1fa54ade956b99b9b0ebfd8f7eacae9475ee9a399d39dd17
---

# Repair round 2: owner-guard

## Goal
Make the asks and findings council round 2 left RED pass for this hook, and change nothing else.

## Requirements
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Findings
ASK 6: RED - header-named forms closed, headers exact and worded for a cooperative agent - run: git-guard.sh with 27 forced-tag, forced-push and iex forms; grep -i "adversar|cooperative" over .claude/hooks saw: all 4 forced-tag, 13 push and 5 iex forms denied, a plain tag passes (closed as answered); but zero matches for the cooperative-agent sentence in any hook header, and the open lists omit the forms asks 1, 4 and 5 measured open
ASK 7: RED - a test per closed gap with a neighbour, no legitimate flow denied - run: the three test parts above; court-guard.sh on a seat's own flows saw: parts green (730 checks 0 failed; 279 ok; runstate 15 ok), but court-guard denies a seat writing its report by a relative path into the reports folder (the absolute spelling passes) and a Read of a file in its own court spelled in another letter case, and the classes named in asks 1, 3, 4, 5 have no test because they are not closed
4. .claude/hooks/owner-guard.sh:805 [ask 2] the owner-only script with a verdict, a shell write of a plan.md and a `git add` covering the acceptance record must be refused whatever stands in front of the program word: a keyword carrying an option, a wrapper outside WRAPPERS (:609), a program word held in a variable, a `find -exec` and a file writer outside the lists at :882-887 still pass for a subagent (round 1 line 4, unchanged).
5. .claude/hooks/owner-guard.sh:163 [ask 2] an Edit, Write or MultiEdit by a subagent of a plan.md record line or of the acceptance record must be judged by the resolved path, as `run_state` (:1207) does for the run state: another letter case, a trailing dot or space, or a link still passes :555 and :568 (round 1 line 5, unchanged).
10. .claude/hooks/owner-guard.sh:665 [ask 7] an ordinary subagent call that names no guarded thing must pass: `names_plan` (:665-673, used at :899 and :1199) still refuses interpreter inline code or a heredoc holding a lone `*`, `**` or `$name`, :900-902 a redirect, tee, touch, cp or in-place sed whose target is a bare variable or a wide glob, and git-guard.sh:906-911 any Bash command word holding an unresolved variable - `--check` on the base copies exits 0 for each, on the head 1 (round 1 line 9, unchanged), and no class of lines 1-9 has its failing test yet.
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

- Worker (2026-11-16, close-story exit 4): `defect card shell-needs-gnu-or-bash4 fails on tests/defects.test.sh`.
  portability-check flags 14 `sed-i` hits in the new test lines (tests/defects.test.sh:940-954 and :1002-1007):
  hook input text, never run, but written without the file's `# portability: hook input text, never run` marker
  (the older cases put such text in a variable carrying that comment, e.g. SEDI). The fix is test-only: move each
  `sed -i` case into a marked variable or add the marker. The test is sealed by the red receipt and the
  implementation is already green, so the edit needs a re-stamp the protocol does not allow here. Decision
  needed: allow the test-only marker edit with a re-stamp from base (revert impl, re-stamp, re-apply), or accept
  it otherwise. Implementation state: the owner-guard harness of tests/defects.test.sh is green (229 ok, 0 failed).
- Queen (2026-11-16): yes, re-stamp from base. Move only the 14 flagged `sed -i` cases into marked variables, as the
  SEDI_* cases do, with `# portable: hook input text, never run`; change nothing else in the test, then return
  NEEDS_CONTEXT "re-stamp". The Queen runs `stamp-red --baseline` (it stamps against HEAD's implementation and puts
  your working copy back), then you close. Add one test for the `find docs/specs -name '*.md' -exec sed -i` neighbour
  you fixed in code, in the same edit.
- Worker (2026-11-16): re-stamp. The 14 flagged `sed -i` cases now sit in `SEDI_*` variables marked
  `# portable: hook input text, never run`; one deny case added for `find docs/specs -name '*.md' -exec sed -i`.
  Nothing else in the test changed. portability-check on tests/defects.test.sh: ok; tests/defects.test.sh: all
  checks passed. Needs the Queen's `stamp-red --baseline`, then close.
- Worker (2026-11-16, close after the re-stamp): close-story exit 4 `edited outside ## Files:
  docs/specs/guards-1115/guards-1115-01-git-guard.md, docs/specs/guards-1115/guards-1115-02-owner-guard.md,
  docs/specs/guards-1115/guards-1115-03-cycle-run-state.md - committed since the claim head 701fee89`. None are this
  worker's edits: they are the Queen's `revised guards-1115-0N` commits. Needs a fresh claim head or the Queen's ruling,
  then close-story again; the red receipt (12:10:30Z) and the implementation are in place.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- .claude/hooks/owner-guard.sh
- tests/defects.test.sh
- docs/defects/owner-words-by-builder.md

## Implementation notes
- .claude/hooks/owner-guard.sh: `resolved()` (shared with `run_state`) judges an Edit/Write/MultiEdit of a plan.md or the record by its resolved path; a human.jsonl edit is judged on the file after it.
- Same file: `judge_seg` scans every word that may be a program word (wrappers too, keyword options skipped), unless the first program reads its words as data (DATA_PROGS); `judge_prog`/`judge_named` replace the single program-word branch; a held command with a space is re-read; an unreadable program word is judged as each guarded program.
- Same file: `written()` replaces `plan_write` (editors, ln, output options, extractors into a spec folder, a spec folder filled from a glob); `hits()`/`target_why()` decide a target (last part any case, trailing dot/space, link, disk glob, or a glob spelling the name); an unreadable target counts only when `near()` finds a guarded word in the command.
- Same file: `names_plan` counts a glob only when it spells the name (`spells`), so a lone `*`, `**`, `$name` pass; `find -exec {}` takes find's names; `env -S` read as a command; `(( ))` no heredoc; git aliases followed through chains; a shell write of human.jsonl refused for a subagent (RECORD_WRITE).
- Header and card: one cooperative-agent sentence; the open list gains one item (subagent writes the hook cannot tie to the file); the card ## Check equals the header list.
- tests/defects.test.sh: the 14 hook-input `sed -i` strings moved into marked `SEDI_*` variables (portability-check), plus the `find docs/specs -name '*.md' -exec sed -i` deny case.
- Surprise: the hook under edit is the live hook guarding this worker; an intermediate edit broke every Edit call, so the code was built in a scratch copy and copied in once green.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: e2e3b0cc67efe6ef1fa54ade956b99b9b0ebfd8f7eacae9475ee9a399d39dd17 (tests/defects.test.sh)
- impl: 06378716f0e455541f0bc95390541b469c910c92e35696008deebdb6c707cae9
- stamped: 2026-11-16T12:10:30Z

```
::error::owner guard r2: a guarded script behind any word before it is denied - subagent: command -p bash scripts/human-ch*.sh docs/specs/acme-demo ACCEPTED ok
::error::owner guard r2: a guarded script behind any word before it is denied - subagent: time -p bash scripts/human-ch*.sh docs/specs/acme-demo ACCEPTED ok
::error::owner guard r2: a guarded script behind any word before it is denied - subagent: exec -a x bash scripts/human-ch*.sh docs/specs/acme-demo ACCEPTED ok
  ok    owner guard: with no Python an unrelated subagent call passes
  ok    owner guard: the header ends with the open list and the card's ## Check list equals it
  ok    owner guard: the open list names the main session's text prefilter
  ok    owner guard: the open list names the tools the hook is not wired on
  ok    owner guard: the open list names a spelling form (glob, variable, changed directory) only for the main session or no Python
  ok    owner guard: the header is clean for portability-check
--- this tree's library: green, one info line per .scrub-revs commit (audit-fixes-1113-12)
  ok    defects-check on this tree is green, no ESCAPE (story 04's masked quote of command-injection-follows-cwd)
  ok    the audit of this tree prints one info line per listed commit
defects.test.sh: FAILED
```
