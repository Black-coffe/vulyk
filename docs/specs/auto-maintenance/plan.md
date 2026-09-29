# Maintenance runs itself: gc, evolve and map without anyone knowing the commands (plan)

**Tier:** 2 · **Spec slug:** `auto-maintenance` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-013 (D7: constitution under ~7 KB and 120 lines), ADR-014 (Law 6 checks), `docs/self-evolution.md`, `docs/specs/rrsi-self-improvement/report.md` §5 (moderator rulings)
**Depends on:** v0.20.0 (`d519f22`), study `rrsi-self-improvement` (`95b999a`)

## Goal
The self-maintenance loop that exists only on paper starts running without anyone typing its commands.
The SessionStart brief computes deterministically what is due (gc, evolve, map refresh) and, only when
something is, tells the main session to run it after the owner's task, on the default branch with a
clean tree. Evolve records every proposed change in a ledger (`memory/stats/evolve.jsonl`), infers
the owner's verdict from git, never re-proposes a rejected idea without new evidence, admits growth
of always-loaded text only against owner-signed evidence, and builds its changeset in a separate
worktree so the owner's tree is never touched. A failing test holds the constitution to ADR-013's
cap, and CLAUDE.md is trimmed to meet it. The learnings buffer is cleaned once for real.

## Assumptions
- A1. "Due" thresholds: gc when any stub learning exists or 10+ real raw learnings (the number
  `/vulyk-status` step 6 already uses); evolve when it never ran or its last run is 7+ days old, and a
  council round was recorded since; map when `memory/map/.stale` exists. Evolve "overdue" (the sunset
  hint, ask 4) only when a previous run exists and is 28+ days old - a never-run hive after an upgrade
  is due, not overdue.
- A2. Maintenance runs only on the default branch with a clean working tree, after the owner's current
  task. Otherwise it stays due for the next session. gc commits its own result there
  (`chore(memory): gc`); evolve commits its ledger rows there and its changeset on its own branch.
- A3. The owner's verdict is per changeset branch: merged into the default branch = accepted; branch
  gone and not merged = rejected; branch present and unmerged = pending (no new changeset while one is
  pending; the brief says so instead). Per-change cherry-picking is not tracked.
- A4. The ledger is written by a script (`scripts/evolve-ledger.py`), like every other
  `memory/stats/*.jsonl`, not by a librarian dispatch (report §5.1). It is append-only: proposal rows
  and verdict rows.
- A5. Growth of always-loaded text is paid only by owner-signed evidence: a verbatim owner quote in a
  defect class code cannot check, or an ADR the owner accepted (report §5.2). The test's caps are
  numbers in the test; raising one is a visible diff.
- A6. The budget test measures the working copy with CR stripped (equal to the git blob), so it runs
  before commit on Windows too.
- A7. `memory/stats/*.jsonl` are per-hive runtime: the installer stops shipping VULYK's own
  `human.jsonl`, `scope.jsonl`, `ship.jsonl` and the new `evolve.jsonl` (council and anomalies are
  already excluded). Hosts that already received them keep them; the installer never deletes.
- A8. The one real `/vulyk-gc` run is part of story 02 (its result lands on the spec branch). The one
  real `/vulyk-evolve` run (ask 4) happens after this spec is merged, with the new procedure, and its
  outcome is reported to the owner.
- A9. `wave-check.sh` reports `bash tests/maintenance.test.sh` as "not a ## Commands cell" at plan
  time: the row lands with story 01, before any story closes. The two brief lines no story quotes are
  the paste's intro and ask 7, which this plan carries as the table below.

## Stories

**Wave 1**
- `auto-maintenance-01-constitution-budget` — trim CLAUDE.md to ≤ 7 168 B / ≤ 120 lines; a failing budget test.

**Wave 2**
- `auto-maintenance-02-due-maintenance` — SessionStart brief computes what is due and instructs the Queen; gc commits its result; the real gc run.

**Wave 3**
- `auto-maintenance-03-evolve-ledger` — `evolve-ledger.py`, ledger + admission rules + worktree in `/vulyk-evolve`, sunset rule, installer stops shipping runtime ledgers.

## Contracts
- `memory/stats/evolve.jsonl`: one JSON object per line. Proposal row `{"ts","kind":"proposal","branch","component","file","hypothesis","evidence","bytes_delta"}`; verdict row `{"ts","kind":"verdict","branch","verdict":"accepted|rejected","reason"}`; run row `{"ts","kind":"run","branch","commit","proposals"}`, one per evolve run. `ts` is UTC `YYYY-MM-DDTHH:MM:SSZ`. `component` is one of `constitution rule agent command hook skill defect memory script doc`.
- `scripts/evolve-ledger.py <root> last` prints the newest run `ts` or nothing; `pending` prints unmerged `vulyk/evolve-*` branches; the brief reads these two.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && python -m py_compile .claude/hooks/*.py && bash tests/maintenance.test.sh && bash tests/telemetry.test.sh && bash tests/solo.test.sh`

## Next circle: the other commands (ask 7)
| Command | Today | Recommendation |
|---|---|---|
| `/vulyk-plan`, `/vulyk-build`, `/vulyk-update`, `/vulyk-handoff` | the four the owner knows and types | keep |
| `/vulyk-gc`, `/vulyk-evolve`, `/vulyk-map` | manual, forgotten, never run | this spec: run themselves when due |
| `/vulyk-ship` (Рекомендую first) | a green build only *recommends* it | build's green terminal asks one yes/no and runs ship itself - the most valuable next step, because a green spec that nobody ships is lost work |
| `/vulyk-bootstrap` | install prints "run /vulyk-bootstrap" once | the same due line: a Profile still holding `<fill in` makes bootstrap due |
| `/vulyk-status` | dashboard on demand | keep manual; the due line now carries what needed attention |
| `/vulyk-review` | internal to build; manual re-review is rare | keep; drop it from owner-facing docs |
| `/vulyk-pause`, `/vulyk-resume` | hive builds only; the launch line prints how | keep |

## Descoped

*(empty)*

## Plan deltas
- **2026-09-29, story 01 - the budget premise was half wrong.** The study (report §7) and the approval question said CLAUDE.md breaks ADR-013's cap. Measured while building: the constitution a host receives (both marked blocks swapped for install.sh placeholders) is 6 266 B / 93 lines, inside the cap; only VULYK's own copy was over, because of VULYK-only Commands rows. Decision: the test caps both the repo file (the owner's choice, "Подрезать до 7 KB") and the shipped render (ADR-013's real subject), and the trim came mostly from VULYK-only rows. Also removed two version mentions from `## Models and effort` (the owner's floor rule: versions live only in `model_floor`), crossing story 01's Non-goal on Models wording. Rejected: capping only the shipped render (the owner chose the trim); cutting Laws or Routing (owner-approved text that every host loads).
- **2026-09-29, story 02 - gc could never delete.** The real gc run returned "I only have Read, Write, Edit and Glob, so I can't delete files". `librarian.md` told an agent without a shell to delete merged learnings and snapshots, so every `/vulyk-gc` would have left the buffer full. Decision: the librarian lists (`Delete:`), the main session deletes (`git rm`, `find -mtime +14`); `.claude/agents/librarian.md` joins story 02's `## Files`. Rejected: giving the librarian Bash (a memory writer that can run anything is a wider blast radius than two shell lines in the command). Also: the Contracts `run` row is added - the evolve clock needs a row per run, a run that proposes nothing included.

**Approved:** <owner, date>
**Briefed:** via grill, Andrei, 2026-09-29
**Branch:** vulyk/auto-maintenance
**Checked:** <written by scripts/human-check.sh>
**Council:** RED round 1, 2026-09-29, at 69fc46d, pack bafdd6ffd419
**Council:** GREEN round 2, 2026-09-29, at ff3f6fe, pack 6edcd818434f
**Shipped:** <written by scripts/ship-check.sh --record>
