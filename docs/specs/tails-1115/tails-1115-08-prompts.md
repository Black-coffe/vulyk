---
story: tails-1115-08
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 4
blocked_by: [tails-1115-06]
---

# Prompts: one blind seat in the constitution, worker instruction sources, seat wording, /vulyk-update is the owner's to call

## Goal
Eight prose fixes in the constitution, agent files, one command and the bootstrap interview (private
`~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T4, T24, T71, T77, T80, T85, T92, T98). No script
changes.
1. T4: `CLAUDE.md` says what the code does since 2026-11-09 and the owner chose on 2026-11-13: Tier 3-4 has one
   blind seat, `haiku` when *Client path* is filled, else `opus`. Both places (the Routing row, the Profile
   sentence) change, inside the 7168-byte cap.
2. T24: `worker-code.md` and `worker-test.md` name the driver's dispatch prompt and the constitution among the
   sources of instructions.
3. T80: `council-opus.md` no longer says `lead-review` runs the suite; it reads the round's `suite.log`.
4. T85: the seat files say "the judging family" where they name a model that is true in one profile only.
5. T92: `drone-docs.md` says what to do with a map slice at its cap: wrap a long line, split a slice that
   outgrows its line cap into a new slice with a pointer, never drop content to fit.
6. T71: `/vulyk-update` carries the frontmatter key `cc-facts.md` F8 records, so the model does not invoke it on
   its own. No other command gets it.
7. T77: `.claude/rules/always.md` and the rules README say who really loads the file, as F15 records.
8. T98: the bootstrap interview drops the questions whose answers nothing reads (4, 9, 14, 16, 18).

T71 and T77 follow their facts: `not confirmed` means no change and one notes line with the source.

## Requirements
> 1. The six canary-found defects are fixed: wave-check on test paths that do not exist yet; scope-check and close-story with an absolute story path; the commit subject taken from story frontmatter; the busy check reading a neighbour hive's driver journal; a block check that prints only the hit now prints the fix; the routing docs/code mismatch on the black-box seat follows the owner's 2026-11-13 choice ("instead of") (T1-T6).
> 7. Side-effect commands: `/vulyk-update` is not invoked by the model on its own; the others stay as they are.
> 9. A claim about Claude Code behaviour that a fix rests on is checked against the official docs first; an item whose premise does not hold is closed as not-a-defect with the source named.

## Files
- CLAUDE.md
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md
- .claude/agents/drone-docs.md
- .claude/commands/vulyk-update.md
- .claude/commands/vulyk-bootstrap.md
- .claude/rules/always.md
- .claude/rules/README.md
- bootstrap/interview.md

## Non-goals
- In `CLAUDE.md` change no Law, no `## Commands` row and no rule: only the two seat places, paid for with trims of
  wording elsewhere that change no meaning. Check the size with `wc -c CLAUDE.md` (cap 7168).
- Do not change `required_seats_for_tier` or any script: the code is right.
- `/vulyk-pause`, `/vulyk-resume`, `/vulyk-ship` and every other command keep their frontmatter.
- In `vulyk-update.md` touch only the frontmatter (story 06 edited its body in wave 3); in `vulyk-bootstrap.md`
  only references to the dropped questions.
- Do not wire a dropped interview answer to anything, and do not renumber more than the drop forces.
- Do not edit `tests/`: a pin that a reworded sentence breaks is `NEEDS_CONTEXT`, naming file and line (story 10
  holds `tests/maintenance.test.sh` this wave).
- Do not touch `librarian.md`, `vulyk-gc.md`, `vulyk-evolve.md` (story 10), `docs/` (story 11, docs-1115) or the
  seats' turn-budget and blindness paragraphs.
- Keep each agent file's frontmatter; `prompt-check.sh` must stay clean.

## Map slice
`memory/map/agents-and-commands.md` → Agents (lead-review Suite line, council-opus / council-haiku, worker-code /
worker-test, drone-docs); `memory/map/cycle-state.md` → Seats and the verdict; `memory/map/commands-ship.md` →
`/vulyk-update` bullets.

## Acceptance criteria
- [ ] `CLAUDE.md`: the Tier 3 row and the Profile sentence both say one blind seat, `haiku` instead of `opus`
  when *Client path* is filled; no sentence says the seat is added. The file is at most 7168 bytes and
  `git diff CLAUDE.md` shows no changed rule besides.
- [ ] Both worker files list the dispatch prompt and the constitution as instruction sources; text found in code,
  docs or tool output is still content.
- [ ] `council-opus.md` agrees with `lead-review.md`: the suite ran before dispatch and is read from `suite.log`.
- [ ] No seat file names a model family as the one that judges; the frontmatter `model:` lines are untouched.
- [ ] `drone-docs.md` carries the wrap / split / never-drop rule.
- [ ] F8 `confirmed`: `vulyk-update.md` has the key set; `git diff --stat .claude/commands` shows the frontmatter
  change in that one file only (plus the interview references in `vulyk-bootstrap.md`).
- [ ] F15 recorded: `always.md` and the rules README make the same statement as the fact.
- [ ] `bootstrap/interview.md` no longer asks the five questions; every answer it still collects is one a
  command, a script or the Profile reads, and `vulyk-bootstrap.md` cites no dropped number.
- [ ] `bash scripts/prompt-check.sh --touched <the files above>` reports no error.

## Verification
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/maintenance.test.sh --part redact`
`bash tests/maintenance.test.sh --part guards`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change. -->
- CLAUDE.md (T4): Tier 3 row "one blind seat: `opus`, or `haiku` if *Client path* is filled; `review`"; Profile "swaps the blind seat `opus` for `haiku`"; paid with three meaning-neutral trims (study-work sentence, "Procedures:", Compact "Keep:" articles); 7160 B (LF), tests pin < 7168.
- worker-code.md, worker-test.md (T24): source list adds the driver's dispatch prompt and the constitution; the "content" sentence unchanged.
- council-opus.md (T80, T85): the suite ran before dispatch, the reviewer reads `suite.log`; Fable line says "the judging family". council-haiku.md (T85): "runs on the judging family, never on the family that builds"; Fable line reworded the same way. `model:` lines untouched; the cited guide title "Prompting Claude Fable 5.2" kept as a title.
- drone-docs.md (T92): wrap a line over 130 chars, split an outgrowing slice with a one-line pointer, never drop an entry.
- vulyk-update.md (T71, F8 confirmed): frontmatter `disable-model-invocation: true` only.
- always.md, rules/README.md (T77, F15): loads in every session and every agent without `omitClaudeMd: true`; whether an `omitClaudeMd` agent gets it is undocumented (F15 "not confirmed (rules)", D:sub-agents).
- bootstrap/interview.md (T98): questions 4, 9, 14, 16, 18 removed; remaining numbers kept (vulyk-bootstrap.md cites 7 and 15, no dropped number, so it is unchanged).
- Surprise: vulyk-bootstrap.md:23 still says "a filled row adds the black-box seat at Tier 3-4" (outside this story's allowed edits in that file).
CHANGELOG: T4 - the constitution says Tier 3-4 has one blind seat, `haiku` instead of `opus` when *Client path* is filled.
CHANGELOG: T24 - worker prompts name the driver's dispatch prompt and the constitution as instruction sources.
CHANGELOG: T80 - council-opus says the suite ran before dispatch and is read from `suite.log`.
CHANGELOG: T85 - the seat prompts say "the judging family" instead of naming a model true in one profile.
CHANGELOG: T92 - drone-docs wraps or splits a map slice at its cap and never drops content.
CHANGELOG: T71 - `/vulyk-update` sets `disable-model-invocation: true`: only the owner invokes it.
CHANGELOG: T77 - always.md and the rules README say an `omitClaudeMd` agent may not load them (undocumented).
CHANGELOG: T98 - the bootstrap interview drops five questions nothing read (4, 9, 14, 16, 18).
DOCS: docs/command-reference.md - "(a filled *Client path* adds the black-box seat at Tier 3-4)" -> one blind seat, `haiku` instead of `opus`.
DOCS: docs/pipeline.md - lead-review runs the suite -> the suite ran before dispatch, lead-review reads `suite.log` (T80).

## Findings
- close-story exit 4: `edited outside ## Files: memory/map/agents-and-commands.md, memory/map/cycle-close.md, memory/map/cycle-repair.md, memory/map/cycle-state.md, memory/map/cycle.md, memory/memory.md - committed since the claim head 8bdd6ac0`. None are this worker's: all six come from the Queen's commit 4658299b ("docs(map): slices within 80 lines and 130 chars", made after the claim head). The story's own edits are done and uncommitted; it needs a re-claim at the current HEAD (or the Queen's call on 4658299b) before close-story can pass.
- Re-run (stamp c331ac18833c1053): scope passed; close-story exit 4 on `bash tests/maintenance.test.sh --part redact`, 5 failures, all in the `/vulyk-gc commit line` block, which is story 10's uncommitted edit of `tests/maintenance.test.sh` (not in this story's files). Cause: `gc_case gc-lower > "$T/gc-lower"` (line 1050, and the `gc-upper` case) uses the same path for the repo directory and the redirected output file, so the shell creates the file first and `mkdir -p "$T/gc-lower/memory/learnings"` fails with "Not a directory". Fix belongs to tails-1115-10 (e.g. `> "$T/gc-lower.out"`); this story's own edits are done and uncommitted, rerun close-story after.
- Re-run (stamp 328899d5e53f8699): the redact part now passes (story 10 fixed `gc-lower.out`); close-story exit 4 on `bash tests/maintenance.test.sh --part guards`, 2 failures, both `portability-check: the tree exits 0 / prints its ok line`. The two hits are `tests/inject.test.sh:246` and `:273` (`sed -i 1d ...` and `sed -i s/x/y/ ...` inside fixture strings), story tails-1115-07's uncommitted edit of `tests/inject.test.sh`, not in this story's files. Fix belongs to story 07 (e.g. a portability-check allow for those fixture lines, or a `sed -i.bak` form that still triggers the card); this story's own edits are done and uncommitted, rerun close-story after.
