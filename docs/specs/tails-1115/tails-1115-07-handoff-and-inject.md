---
story: tails-1115-07
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 4
blocked_by: [tails-1115-03, tails-1115-06]
red: required
red_reason: a read-only command gets no card
red_verified_at: 2026-11-17T15:36:10Z 483aa6a2875d10820bb5d9d0fae3f4ced668ed4f050f505569a9ab5d9edefc28
---

# Hooks: the handoff measures the real window, defect cards skip read-only commands

## Goal
Five hook tails and one fence gap (private `~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T20, T69, T74, T75, T78).
1. T78: `defects-inject.sh` delivers no card for a Bash or PowerShell command that only reads (plan.md
   `## Contracts` J1); `git` commands keep delivering, because `lead-review` gets its cards from one `git diff`.
2. T20: in `handoff.py` a measured window outranks one borrowed by model name when the session has already passed
   the stock window and the borrowed value is not above stock.
3. T69: with no status-line report the window comes from a family table, the compaction-window variable is
   honoured, and the offer levels reset when the window changes - each as `cc-facts.md` F7 records.
4. T74: the handoff reads the session's task list from the tool F10 names, beside the old one.
5. T75: on PreCompact the handoff emits through the field F11 records, so its note does not land in the
   compaction summary.
6. Ask 12 (narrow-repair-1115 round 2, the one story-section reader still reading inside a fence): `story_files` in
   `defects-inject.sh` skips fenced lines with the fence rule of `FENCE_AWK` in `scripts/cycle.sh` and `fence_mask`
   in `scripts/symbol-map.py` (3+ ` or ~ opens; only the same character, as long or longer, with nothing after it,
   closes).
T69, T74 and T75 follow their facts: a part that is `not confirmed` gets no code change and one notes line with
the source. Marked red: a parser that decides whether a rule reaches an agent.

## Requirements
> 5. The hook, telemetry, token-report, prompt-check and model-floor tails in tails.md are fixed; a fallback never runs a model below the floor (pause instead).
> 9. A claim about Claude Code behaviour that a fix rests on is checked against the official docs first; an item whose premise does not hold is closed as not-a-defect with the source named.
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.
> 12. The defect-card hook reads a story's `## Files` outside fenced code blocks only, with the same fence rule as the other story-section readers.

## Files
- .claude/hooks/handoff.py
- .claude/hooks/defects-inject.sh
- scripts/handoff-window-check.py
- tests/handoff-hooks.test.py
- tests/handoff.test.sh
- tests/inject.test.sh
- tests/handoff-window.test.py
- docs/defects/handoff-offered-too-early.md
- tests/telemetry.test.sh
- CLAUDE.md

## Non-goals
- Do not touch `_REDACT_FALLBACK` (story 03 landed it) or the thresholds (70/80/90 % of the real window).
- Do not touch `.claude/settings.json`, any matcher, or `context-guard.sh`: story 06 retires that hook this wave.
- Tool names in `defects-inject.sh` stay: a name an older Claude Code still sends costs nothing.
- When the hook cannot tell whether a command only reads, it delivers the cards as today. Read, Edit, Write and
  the other tools are not changed.
- `handoff-window-check.py` is the check of card `handoff-offered-too-early`: change it only if the window rule
  it replays changes, and keep both card fixtures failing.
- Never offer a handoff before 70 % of the real window, and keep `context_limit` in the hive's config as the pin
  that wins.
- Do not edit the latency cases of `tests/inject.test.sh`.

## Map slice
`memory/map/scripts-hooks.md` → Purpose, Entry points (`handoff.py`, `handoff.sh`), Gotchas;
`docs/wiki/rules-tree.md` (delivery); `memory/map/agents-and-commands.md` → lead-review (the one `git diff`).

## Acceptance criteria
- [ ] `tests/inject.test.sh`: a PreToolUse input for `grep -n x scripts/lib.sh` on a path a card covers prints no
  card. The label contains `a read-only command gets no card`. Neighbours: the same for a PowerShell read; a
  command that reads and then writes (a pipe into a writer, a redirect, `sed -i`) gets the cards; `git diff
  <range> -- <path>` gets them; an unreadable command gets them.
- [ ] A session whose own measure is past 98 % of the stock window, with a borrowed window equal to stock, is
  judged against the measured window: no offer at that point on a large-window model. Neighbour: a borrowed
  window above stock still wins; a session below stock behaves as today.
- [ ] F7 `confirmed`, per part: no status-line copy and no report for the model gives the family's window from
  the table; the compaction-window variable changes the window and is no longer ignored; after the window
  changes, a level already offered on the old window can be offered again on the new one.
- [ ] F10 `confirmed`: a transcript that lists tasks only through the newer tool yields the same handoff task
  lines as one using the old tool.
- [ ] F11 `confirmed`: the PreCompact output of `handoff.py` carries its note in the recorded field and nothing
  on plain stdout.
- [ ] Card `handoff-offered-too-early` stays green in `bash scripts/defects-check.sh`, with both its fixtures
  still failing the check.
- [ ] `tests/inject.test.sh`: a story file whose `## Red receipt` fence holds a `## Files` heading and a path, above
  the real `## Files`, yields only the real section's paths when Read. The label contains `a fenced section adds
  no path`. Neighbours: a 4-backtick fence holding a 3-backtick one; a `~~~` fence; a story with no fence reads as
  today.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh`
`bash tests/inject.test.sh`
`bash tests/handoff.test.sh`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`
`bash scripts/defects-check.sh`
`bash tests/telemetry.test.sh --part scan`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change
(docs/hooks-reference.md rows for the handoff and the inject hook). -->
- `.claude/hooks/handoff.py`: `family_window` + `_FAMILY_1M` (F7: Fable, Sonnet 5+, Opus 4.7+, Haiku 5.5+ are 1M; anything else unparsed keeps stock), placed after the borrowed `model` window and before `measured`; `window_count` parses `400k`/`1M`/ints for `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (no range clamp: F7 gives 100k-1M, behaviour outside it is not documented); `track_window` resets both levels when the window changes, saved at once so Stop and prompt both see it; T20 guard in `resolve_window`.
- T74: `harvest` reads TaskCreate/TaskUpdate (F10) beside TodoWrite; ids from `toolUseResult.task.id` (BIN schema `task:{id,subject}`), else creation order (assumption: ids count up from 1, not confirmed by a source); `deleted` drops a task; header is now `## Tasks (last task list)`.
- T75: no code change. F11: plain stdout becomes summary instructions; PreCompact already prints one JSON object (`systemMessage`, discarded by Claude Code). The case is a regression guard and passes on HEAD.
- `.claude/hooks/defects-inject.sh`: `read_only` (J1) with shlex: every command word on `READ_ONLY`, redirects only to a null sink or an fd, no `sed -i`; `` ` ``, `$(`, `<(`, `>(`, `<<`, a newline, a subshell or unbalanced quotes deliver the cards. `fence_mask` (Ask 12) mirrors `scripts/symbol-map.py`.
- Tests: `tests/handoff-hooks.test.py` default model and H1M row moved to `claude-sonnet-4-6`; new T20/T69/T74/T75 sections. `tests/handoff-window.test.py`: the 200k case uses `claude-sonnet-4-6`, plus a `claude-opus-5` neighbour that stays silent. `tests/inject.test.sh` J1 + fence cases, P10-15/ps2 rewritten to write commands; `tests/telemetry.test.sh` case 11 model + Fable neighbour (written before receipt in an earlier round).
- Card `handoff-offered-too-early`: Allowed line narrowed to the table (Queen + owner); `handoff-window-check.py` unchanged, card green in `defects-check.sh`, both fixtures still fail.
- `CLAUDE.md`: `Defect hooks` row split, new `| Inject |` row; the line under the heading reads as the owner set it; 7167 bytes without CR.
- Fail on HEAD (red receipt run + local run before the implementation): T20 past-stock case; T69 five table models, `400k`, both level-reset checks; T74 both Task-tool cases; handoff-window `claude-opus-5` neighbour; inject J1 read-only cases (grep, PowerShell, pipe/list) and three fence cases; telemetry Fable neighbour. Passing on HEAD (neighbours/guards): T20 neighbours, T69 200k models, `1M`, plain count, DISABLE_1M, T75.
- Surprise: a Bash heredoc on this box mangled backslashes in a Python edit script (tab/CR bytes written into the hook); fixed with Edit.
- Next circle: `harvest` reads only the transcript tail (`dump_tail_bytes`, 12 MB): a task list created earlier than that is lost.
- CHANGELOG: The handoff hook knows the 1M model families with no statusLine copy, honours `CLAUDE_CODE_AUTO_COMPACT_WINDOW=400k`/`1M`, re-offers a level after the window changes, and trusts a session past 196k over a borrowed 200k window.
- CHANGELOG: The handoff dump lists the task list from TaskCreate/TaskUpdate as well as TodoWrite.
- CHANGELOG: The defect-card hook skips Bash and PowerShell commands that only read (search, print, list, count, compare); `git` and anything it cannot read still get cards.
- CHANGELOG: The defect-card hook reads a story's `## Files` outside fenced code blocks only.
- DOCS: docs/hooks-reference.md - the handoff row must say the window comes from a pin, the env knobs (with `k`/`M` suffixes), the statusLine copy, a same-model copy, the family table (Fable, Sonnet 5+, Opus 4.7+, Haiku 5.5+ = 1M), then the measured proof, else 200k; levels reset when the window changes.
- DOCS: docs/hooks-reference.md - the auto-dump line must say "last task list (TodoWrite or TaskCreate/TaskUpdate)" instead of "last TodoWrite".
- DOCS: docs/hooks-reference.md - the defect-inject row must say a read-only Bash/PowerShell command gets no card, and a story's `## Files` inside a fence is not read.
- DOCS: docs/command-reference.md - the /vulyk-handoff entry says "last TodoWrite": "last task list".

## Findings
- NEEDS_CONTEXT (builder, 2026-11-17, before any edit or red receipt): the T69 family table needs a file outside
  `## Files`. `tests/handoff-window.test.py` (run by CI, `.github/workflows/ci.yml` job `handoff-window`) has the
  case `no statusbar at all -> legacy 200k behaviour preserved`: model `claude-opus-5`, 150k tokens, no statusbar,
  expects a nag `(75% of 200k)`. F7 says Opus 4.7 and later is 1M by default, so with the table that session reads
  150k of 1M and stays silent: the case turns red. Question: add `tests/handoff-window.test.py` to `## Files` (that
  case then becomes a model the table does not know, e.g. `claude-sonnet-4-6`, plus a `claude-opus-5` neighbour that
  stays silent), or drop the table part? The same change also narrows card `handoff-offered-too-early` ✓ "The stock
  200k guess when nothing on the machine knows the model's window" (the table now knows the families F7 names);
  the card file is not mine either.
- Second point for the same answer (no file needed): T75 premise does not hold for `handoff.py`. Its PreCompact mode
  already prints one JSON object `{"systemMessage": ..., "suppressOutput": true}` and nothing else; D:hooks
  (#exit-code-0) counts that as JSON output, not plain text, and only plain-text stdout becomes summary
  instructions (#precompact-output); `systemMessage` is discarded on PreCompact (#precompact). So T75 needs no code
  change in the handoff, and its acceptance case passes on HEAD, against "Every new case fails on HEAD". I would
  write the case as a regression guard and note it as passing on HEAD, unless told otherwise.
- Queen (2026-11-17): T69: keep the family table; `tests/handoff-window.test.py` joins `## Files` for that case only
  (a model the table does not know keeps the 200k behaviour, plus a `claude-opus-5` neighbour that stays silent), and
  card `handoff-offered-too-early` joins to narrow its Allowed line to "nothing on the machine and no family in the
  table knows the model's window". T75: F11 confirms the stdout rule, and the handoff already sends nothing to the
  summary: no code change; write the case as a regression guard and note it as passing on HEAD (the story's own
  rule for a premise the facts do not bear out).
- NEEDS_CONTEXT (builder, 2026-11-17, round 2, before any edit or red receipt): the T69 family table also reaches
  `tests/telemetry.test.sh`, outside `## Files`. `handoff.py measure` resolves the window as the hook does, and
  `scripts/telemetry.sh` `detect_context` takes its `window`. Case 11 (`--- scan: context_high`) feeds a
  `claude-fable-5-1` main transcript at ~150k with an empty HOME and expects `scan records one context_high row above
  the absolute threshold` and `context_high maps claude-fable-5-1 to fable`: today the window is the stock 200k
  (threshold 140k); with the table Fable reads 1M (threshold 700k), no row, both checks red. Question: (a) add
  `tests/telemetry.test.sh` to `## Files` for that case only (its fixture model becomes one the table does not know,
  e.g. `claude-sonnet-4-6`, the alias check following it; plus a Fable neighbour with no row), or (b) keep the table
  out of `measure` (telemetry keeps judging a Fable/Opus 4.7+ session with no statusLine copy against 200k: the
  status quo, and the same false `context_high` the card's telemetry neighbour exists for). I would take (a).
  The `claude-opus-5` default model of `tests/handoff-hooks.test.py` `write_transcript` (P10-01, P10-07, H1M at 150k
  against 200k) has the same shape but is inside `## Files`: I would move it to `claude-sonnet-4-6`.
- Owner, 2026-11-17, asked: «Таблица + правка карточки (Рекомендую)». The card's Allowed line also says that a new
  family is added to the table (an unknown model keeps the stock 200k guess).
- Queen (2026-11-17): (a), it keeps the owner's table decision whole: `tests/telemetry.test.sh` joins `## Files` for
  case 11 of part `scan` only (a fixture model the table does not know keeps the row, the alias check follows, a
  Fable neighbour expects no row); `--part scan` joins `## Verification`. Story 06 edits the same file this wave, so
  this story moves to wave 4, after 06. The inject.test.sh read-only rewrites and the handoff-hooks default model
  are inside `## Files`: go ahead. The 12 MB task-list window: name it in the notes for the next circle.
- WALL (builder, 2026-11-17, round 3, sealed tests written, no implementation edit, no receipt): `stamp-red` refused
  three times with `not red: timed out after 300s`, each time on the first `## Verification` line
  (`defects.test.sh && intake.test.sh && inject.test.sh`). Run one by one outside the gate: defects 136 s, intake
  102 s, inject 85 s = 323 s, over the 300 s per-line clamp before any of this story's code exists (the new inject
  cases add about ten hook calls). Wave-mates' suites ran beside it. Hypothesis: the row is too long for one gate
  line on this machine under wave load (card test-gate-one-long-limit). Ask: split that line (this story changes
  only `inject.test.sh` of the three; `bash tests/inject.test.sh` alone, or one line per suite), then re-dispatch:
  the sealed edits to `tests/inject.test.sh` (J1 + fence cases, the P10-15 / ps2 read-only rewrites) and
  `tests/telemetry.test.sh` (case 11) are in the tree, uncommitted, and are red on HEAD as intended.
- Queen (2026-11-17): the `Defect hooks` line ran past 300 s while four wave-mates ran their suites beside it (the
  same line closed under 300 s in guards-1115). The move to wave 5 is undone (a claim refuses this story's leftover test edits outside its wave); instead the Queen ran
  stamp-red for this story on an idle machine. The line stays. If it is
  still over 300 s alone, return NEEDS_CONTEXT with the time and the Queen splits it through a `## Commands` row.
- Queen (2026-11-17, later): measured on an idle machine, stamp-red on the `Defect hooks` line still took 306 s, so it
  is split. Wait for story 08 (it owns CLAUDE.md this wave) to close: until then do not run stamp-red or close-story,
  return NEEDS_CONTEXT at once. The Queen then adds CLAUDE.md to this story for the row split.
- NEEDS_CONTEXT (builder, 2026-11-17, round 4, no edit, no stamp-red or close-story run): story 08 is still `status: todo`
  (returned NEEDS_CONTEXT) and this story names neither CLAUDE.md in `## Files` nor a split `Defect hooks` line in
  `## Verification`; per the Queen's last finding, waiting for 08 to close and the row split.
- NEEDS_CONTEXT (builder, 2026-11-17, round 5, no edit, no stamp-red or close-story run): unchanged since round 4: story 08
  still `status: todo`, CLAUDE.md `Defect hooks` row not split, CLAUDE.md not in `## Files`. Waiting as the Queen ordered.
- Queen (2026-11-17, deadlock): stories 08 and 10 cannot close while this story's uncommitted `tests/inject.test.sh`
  fails the tree-wide portability check (two `sed -i` fixture strings, at about lines 246 and 273). Now, before
  anything else: change those two strings to `sed -i.bak` (still a write, still meets its card), nothing else, run
  `bash scripts/portability-check.sh tests/inject.test.sh`, and return NEEDS_CONTEXT. No stamp-red yet.
- NEEDS_CONTEXT (builder, 2026-11-17, round 6, deadlock step only, no stamp-red or close-story run): `tests/inject.test.sh`
  lines 246 and 273 now run `sed -i.bak`. Line 273's `expect` label also read a bare `sed -i` and kept the check red, so
  it now reads `J1 neighbour: sed -i.bak gets the card` (label text only). `bash scripts/portability-check.sh
  tests/inject.test.sh`: ok, exit 0. Waiting for story 08 to close and the `Defect hooks` row split.
- NEEDS_CONTEXT (builder, 2026-11-17, round 7, no edit, no stamp-red or close-story run): unchanged since round 6: story 08
  still `status: todo` (returned NEEDS_CONTEXT), CLAUDE.md `Defect hooks` row not split, CLAUDE.md not in `## Files`. Waiting as the Queen ordered.
- Queen (2026-11-17): story 08 is closed. `CLAUDE.md` joins `## Files` for one change: split the `Defect hooks` row
  into `| Defect hooks |` with cell `bash tests/defects.test.sh && bash tests/intake.test.sh` and a new
  `| Inject hook |` row with cell `bash tests/inject.test.sh`. CLAUDE.md stays under 7168 bytes with CR removed
  (it is at 7160): pay for the extra bytes by shortening another VULYK-only Commands row or the line under the
  table, never a Law, the Profile, or a label tests key on (`Anomaly telemetry contract tests`, `(round-only)`).
  Do that first, check the cap, and return NEEDS_CONTEXT; the Queen then switches `## Verification` to the two
  lines and you stamp-red and build.
- NEEDS_CONTEXT (builder, 2026-11-17, round 8, CLAUDE.md split only, no stamp-red or close-story run): `Defect hooks`
  cell is now `bash tests/defects.test.sh && bash tests/intake.test.sh`, new row `| Inject hook | bash tests/inject.test.sh |`.
  Paid by the line under the heading: `Quiet variants: output resent per turn. ``## Verification`` uses one, not round-only.`
  (was `Quiet variants only: ... names one, never ``round-only``.`). CLAUDE.md is 7167 bytes with CR removed (cap 7168);
  no Law, Profile or keyed label touched. Waiting for `## Verification` to switch to the two lines.
- Owner, 2026-11-17, on this story's CLAUDE.md diff: «Вернуть only (Рекомендую)». The line under the Commands
  table reads exactly: Quiet variants only: output resent per turn. `## Verification` uses one, not round-only.
  and the new row's label is `Inject` (not `Inject hook`); nothing else in CLAUDE.md changes. `## Verification`
  now runs the two rows. Next: stamp-red, then build.

## Red receipt
- command: bash tests/inject.test.sh
- exit: 1
- tests: 483aa6a2875d10820bb5d9d0fae3f4ced668ed4f050f505569a9ab5d9edefc28 (tests/handoff.test.sh, tests/inject.test.sh, tests/telemetry.test.sh)
- impl: 590fe94c515b12da974f293724b7764c97cc14a68ce10479f92b4909734cf25f
- stamped: 2026-11-17T15:36:10Z

```
::error::J1: a read-only command gets no card (grep -n x scripts/lib.sh) - expected no output and exit 0, got:
::error::J1: a read-only command gets no card (a PowerShell read: Get-Content | Select-String) - expected no output and exit 0, got:
::error::J1: a read-only command gets no card (a pipe, a list, a /dev/null redirect, a compare) - expected no output and exit 0, got:
  ok    court guard r2: a Read of the seat's own court in another letter case passes (drive form)
  ok    court guard r2: a Read of the main tree in another letter case is denied
--- latency
  median defects-inject.sh (Bash): 147 ms over 30 calls (fixture library; target <= 200 ms)
  ok    median latency, Bash, <= 200 ms
  median defects-inject.sh (Edit): 147 ms over 30 calls (fixture library; target <= 200 ms)
  ok    median latency, Edit, <= 200 ms
  median defects-inject.sh (Read, not a story): 70 ms over 30 calls (fixture library; target <= 100 ms)
  ok    median latency, non-story Read, <= 100 ms
inject.test.sh: 393 checks, 9 failed
```
