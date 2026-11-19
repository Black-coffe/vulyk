---
story: tails-1115-05
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [tails-1115-01, tails-1115-03]
red: required
red_reason: a test path the story itself creates counts as covered
red_verified_at: 2026-11-17T11:34:43Z 532181a49d295daa1d20aea0c172b731f08738869f30cf1291f6f85a6f79f1c5
---

# Check scripts: wave-check and new test paths, the busy check and a neighbour hive, portability hits print the fix, --show order, agent tools

## Goal
Six tails in the report and gate scripts (private `~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T1,
T5, T6, T90, T16, T65).
1. T1: `wave-check.sh` counts a `## Verification` token as a path when it exists or matches a `## Files` entry of
   the story, so a test the story creates no longer raises `verify-gap`.
2. T5: `hives-behind.sh --busy` no longer reads a neighbour hive's fresh transcript as this hive's: a transcript
   with no `cwd` in a sibling folder takes the `cwd` of its session's top transcript; if that is unreadable too,
   the answer stays busy.
3. T6: every `portability-check.sh` hit line ends with the fix for its rule (the helper or spelling to use).
4. T90: `portability-check.sh` gains a rule for version sort by `sort -V`; `vulyk-evolve.md` uses
   `scripts/version-order.sh` instead.
5. T16: `human-check.sh --show` prints code paths first and spec paperwork after, inside the same 300-line cap.
6. T65: `prompt-check.py` refuses an agent whose `tools:` lists the subagent-spawning tool, as `cc-facts.md` F4
   names it (`not confirmed`: no change, one notes line with the source).

Marked red: new branches in gates that decide what a story or a hive upgrade may do.

## Requirements
> 1. The six canary-found defects are fixed: wave-check on test paths that do not exist yet; scope-check and close-story with an absolute story path; the commit subject taken from story frontmatter; the busy check reading a neighbour hive's driver journal; a block check that prints only the hit now prints the fix; the routing docs/code mismatch on the black-box seat follows the owner's 2026-11-13 choice ("instead of") (T1-T6).
> 5. The hook, telemetry, token-report, prompt-check and model-floor tails in tails.md are fixed; a fallback never runs a model below the floor (pause instead).
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
- scripts/wave-check.sh
- scripts/hives-behind.sh
- scripts/portability-check.sh
- scripts/human-check.sh
- scripts/prompt-check.py
- .claude/commands/vulyk-evolve.md
- docs/defects/shell-needs-gnu-or-bash4.*
- docs/defects/INDEX.md
- tests/maintenance.test.sh
- tests/cycle.test.sh

## Non-goals
- In `human-check.sh` touch only the `--show` output: recording and `--commit` are guarded by guards-1115.
- In `vulyk-evolve.md` change only the version-sort line: story 10 edits the rest in wave 4.
- `--busy` never turns a doubt into `idle`: an unreadable `cwd` stays busy, and a hive's own transcripts and
  `DRIVER` files count as today.
- Do not print a card's lines from `close-story` or `defects-check.sh`: T6 is built for the check that printed a
  bare hit (plan.md `## Assumptions`).
- Edit `tests/cycle.test.sh` only in part `gates`; edit `tests/maintenance.test.sh` only in the hives-behind,
  portability and prompt-check blocks plus one new `--show` block.
- A `sort -V` hit the new rule finds outside `## Files` is `NEEDS_CONTEXT`, naming the sites.
- Fixtures use synthetic hive names (`Acme`, `Acme_two`); no real hive name or transcript slug.
- Run `bash scripts/defects-index.sh` after a card edit; never edit `INDEX.md` by hand.

## Map slice
`memory/map/scripts-checks.md` → Entry points (`wave-check.sh`, `portability-check.sh`, `prompt-check.sh`), Tests;
`memory/map/scripts-hives.md` (whole, 23 lines); `memory/map/scripts.md` → Entry points (`human-check.sh --show`).

## Acceptance criteria
- [ ] Part `gates`: a story whose `## Verification` runs an existing runner on a test file that is in `## Files`
  and not yet on disk gets no `verify-gap`. The label contains `a test path the story itself creates counts as
  covered`. Neighbours: a `## Files` glob that matches the token; a token that neither exists nor is in
  `## Files` still raises `verify-gap`.
- [ ] `--busy` on hive `Acme` with a fresh `cwd`-less Workflow journal under the transcript folder of `Acme_two`,
  whose top transcript names `Acme_two` as `cwd`: `idle`. Neighbours: the top transcript names `Acme` or a
  folder below it: busy; no top transcript, or one with no readable `cwd`: busy.
- [ ] Each rule of `portability-check.sh` has a fix text; a fixture hit for `sed -i` names `sed_inplace`, one for
  bare `timeout` names `run_capped`. A test fails for a rule with no fix text.
- [ ] The tree scan is clean with the new `sort -V` rule on; the card has a fixture pair for it and
  `bash scripts/defects-check.sh` is green.
- [ ] `--show` on a branch that changed 400 lines of spec paperwork and 20 lines of code prints the code diff
  whole, then paperwork up to the cap. Neighbour: only paperwork changed prints as today.
- [ ] F4 `confirmed`: an agent fixture whose `tools:` holds the spawning tool (either recorded name) is an error;
  every shipped agent passes.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/cycle.test.sh --part gates`
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/maintenance.test.sh --part redact`
`bash tests/maintenance.test.sh --part guards`
`bash scripts/defects-check.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change. -->
- `scripts/wave-check.sh`: a verification token not on disk counts as a path when a `## Files` entry names or a glob there matches it (shared `overlap`).
- `scripts/hives-behind.sh` `sub_session`: a fresh cwd-less transcript at `<dir>/<sid>/...` reads the cwd of `<dir>/<sid>.jsonl`; a top-level one, or none readable, stays busy.
- `scripts/portability-check.sh`: `FIX` table, every hit line ends ` - fix: <fix>`; `--rules` prints `<rule>: <fix>` from the rule tables; new WORDS rule `sort-V` (command position only, so test labels quoting "sort -V" are no hits).
- `.claude/commands/vulyk-evolve.md`: the litopys cache order is `version_newest` in a loop (newest first, same fallback order as `sort -rV`); tree scan clean, no other `sort -V` site.
- Card `shell-needs-gnu-or-bash4`: a Never line and fixtures `sort-v` (original) + `sort-v-neighbour`; INDEX.md by `defects-index.sh`.
- `scripts/human-check.sh --show`: diff of `:(top)` minus `docs/specs/` first, then `docs/specs/`, one `head -n 300`; the cut count is the whole diff, as before.
- `scripts/prompt-check.py`: rule `tools` errors on `Agent` / `Task` in `tools:` (also `Agent(x)`, `[..]` list), F4 confirmed in cc-facts.md.
- Cases failing on HEAD: gates `a test path the story itself creates counts as covered`, `... a ## Files glob matches ...`; guards `a neighbour hive's cwd-less journal ... is idle` (+ its exit 0), `--rules` (5), the sed-i / timeout / each-hit fix lines, both sort-V CASES and both card fixtures; redact the 4 spawn forms (8) and `--show` `+code 20` / code-before-paperwork. Neighbours that pass on HEAD too: the verify-gap for wnew-03, the four busy forms, the sort-V ok lines, `nospawn`, the cap and paperwork-only `--show`.
- CHANGELOG: wave-check no longer reports verify-gap for a test the story creates (a `## Files` entry names it).
- CHANGELOG: hives-behind --busy reads a cwd-less Workflow journal's cwd from its session's top transcript, so a neighbour hive's build no longer reads as busy.
- CHANGELOG: portability-check prints the fix at the end of every hit line and lists rules with --rules.
- CHANGELOG: portability-check rule sort-V; /vulyk-evolve orders litopys copies with scripts/version-order.sh.
- CHANGELOG: human-check --show prints code first and spec paperwork after, inside the 300-line cap.
- CHANGELOG: prompt-check refuses an agent whose tools list Agent or Task.
- DOCS: memory/map/scripts-checks.md - the portability-check hit format gains ` - fix: <fix>`, `--rules`, rule sort-V; prompt-check rule `tools`.
- DOCS: memory/map/scripts-hives.md - a cwd-less transcript takes its session's top transcript cwd before it counts as busy.
- DOCS: memory/map/scripts.md - `human-check.sh --show` prints code first, docs/specs/ after, one 300-line cap.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part gates
- exit: 1
- tests: 532181a49d295daa1d20aea0c172b731f08738869f30cf1291f6f85a6f79f1c5 (tests/cycle.test.sh, tests/maintenance.test.sh)
- impl: 051ef53d6e5adf33ee7dd05c276eae8b7f4ea9750119b5368a040aceb94d4cd9
- stamped: 2026-11-17T11:34:43Z

```
::error::a test path the story itself creates counts as covered - got a verify-gap:   ! verify-gap: wnew-01's verification names paths that do not intersect its '## Files' - check the command can fail for THIS story (an ignore file or a wrong directory makes green vacuous)
ab-run-fixes-09: every verb's last JSON line carries now, the epoch seconds the driver checkpoint reads
  ok    an ok and a refused verb both carry an integer now within 5 s of the shell clock
G3 (mass-audit-fixes-08): scope-check drops a sibling's declared paths only for a not-done sibling of the same wave
  ok    a wave-1 edit of a file only a wave-2 todo story declares is out of scope
  ok    a same-wave sibling's file is still dropped: changed 2, out of scope 1
G4: a git mv of an out-of-scope file into a declared directory still counts the path it left
  ok    a rename into a declared dir reports out of scope 1
G8 (mass-audit-fixes-08): wave-check reports red-seals-impl when a red story seals its one implementation
  ok    a red story whose verification calls its one implementation script: red-seals-impl
  ok    a suite-only verification is no red-seals-impl
```
