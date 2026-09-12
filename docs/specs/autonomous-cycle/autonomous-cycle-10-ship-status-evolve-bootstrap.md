---
story: autonomous-cycle-10
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [autonomous-cycle-02]
---

# `/vulyk-ship`, `/vulyk-status`, `/vulyk-evolve`, `/vulyk-bootstrap`: ledgers, mode, numbers, pin

## Goal
`/vulyk-ship` ships on a GREEN council row, merges locally, prints the publish command and does not wait; `/vulyk-status` shows the driver mode, the council numbers and what is merged but not pushed; `/vulyk-evolve` prints the three weekly numbers; `/vulyk-bootstrap` pins the session and stops talking about `drone-acceptance`.

## Requirements
> Мерж сам, публикация — нет. Система сама мержит vulyk/<slug> в default-ветку, обновляет CHANGELOG/версию/карту, печатает команду publish в лог и НЕ ждёт. Наружу (push тега, npm publish, деплой на прод) — только человек, когда захочет.

> Новый memory/stats/council.jsonl: раунды до зелёного, эскалации, и «сбежавший дефект» — баг-brief, который трассируется к спеке, принятой советом. /vulyk-evolve раз в неделю печатает три числа.

> install.sh/bootstrap сами делают --apply, SessionStart-бриф ругается, если сессия идёт не на топ-модели.

> UNASKED/minor — в леджер следующего круга, не блокируют.

## Files
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-status.md
- .claude/commands/vulyk-evolve.md
- .claude/commands/vulyk-bootstrap.md

## Non-goals
- Do not push, tag, publish or deploy from any step; do not add a "press it for me" option.
- Do not change `ship-check.sh` (story 02 did) or `release-check.sh`.
- Do not add the Browser MCP interview question here - that is `bootstrap/interview.md` (story 11); `vulyk-bootstrap.md` only references the Profile row by name.
- Do not rewrite `/vulyk-evolve`'s harvest or changeset mechanics; add the three numbers as one read-only step.
- Do not compute the council numbers with a model: one `awk`/`grep` over `memory/stats/council.jsonl`, printed as-is.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C4 (row keys), C7, C12 (`/vulyk-status` lines) and `## Assumptions` (escaped-defect header, release paperwork) · `docs/grill/2026-09-12-autonomous-cycle-council.md` Decision 2, 14 and Act 2 rows 2 (local merge, "N merged locally, not pushed"), Anti-scope row (fallback is the most expensive path - status says so), "— леджер следующего круга" (`## Next circle`) · `docs/specs/autonomous-cycle/recon/scout-commands.md` §Answer 1 rows `vulyk-ship.md` (step 1 gate, step 3 human-press stop), `vulyk-bootstrap.md:10`, and §Answer 7 (where a `council.jsonl` reader plugs into `vulyk-status.md` step 4/5 and `vulyk-evolve.md` step 1).

## Acceptance criteria
- [ ] `vulyk-ship.md`: step 1 `ship-check.sh` unchanged as the gate (it now reads the council row); the release-paperwork commit skips version/CHANGELOG when they already carry the version; merge into the default branch locally as the *Release / deploy* row prescribes; `ship-check.sh --record`; the publish command (push, tag, npm publish, deploy - whatever the row names) is printed under "to publish, run:" and the command ends - no waiting step; the `## Next circle` step also collects the seats' `UNASKED:` lines and any `minor` findings from the newest round's seat files; the `## Needs a human` section, if present, is carried into the next brief draft.
- [ ] `vulyk-status.md`: a `driver:` line (Workflow tool present -> `workflow`; else `fallback` with the CLI version and the sentence that the fallback runs the loop in the pinned top-model session, the most expensive path); a `council:` line from `council.jsonl` per C12 (specs judged, median rounds to the first GREEN, escalations, escaped defects); `merged locally, not pushed: <n>` from `git log origin/<default>..<default> --oneline | wc -l` (or "no remote"); per-spec stage now shows `04-council:<verdict>` and `paused` from `state.sh`; a missing `council.jsonl` prints `council: no rounds yet`.
- [ ] `vulyk-evolve.md`: a read-only step printing the same three numbers for the last 7 days plus the comparison the grill names (escaped defects vs. `human.jsonl` rejections for the same span) and the "return the human" signal sentence; nothing self-applies.
- [ ] `vulyk-bootstrap.md`: runs `bash scripts/top-model.sh --apply` after the Profile is written and says why (the Queen session must run on the resolved top model); the `drone-acceptance` caveat at `:10` now names the council and the *Browser MCP* Profile row.
- [ ] No command text mentions `human-check.sh` as a required step; `/vulyk-ship` mentions it once as the override.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `vulyk-ship.md`: since publish is never waited for, `--record` now runs right after the local merge with a generic note ("merged to <default>, publish pending") instead of the owner's after-the-fact "where it was published" - that provenance detail is a casualty of not waiting, not an oversight.
- `vulyk-ship.md` step 2: "skip the bump" is keyed on `VERSION`/`CHANGELOG.md` already showing the target version verbatim (the case story 13 creates for this very spec), not on any new script - purely a command-prose instruction.
- `vulyk-status.md`/`vulyk-evolve.md`: the council numbers (specs/median/escalations) are one `awk` pass each, escaped defects are a `grep` over `docs/specs/*/brief.md` `**Escaped from:**` headers cross-checked against `council.jsonl` for a GREEN row - all four inline blocks tested against a synthetic `council.jsonl`/`human.jsonl`/brief fixture in scratch before being written into the files (median, escalation count, 7-day date filter via `date -u -d '-7 days'`, and the escaped-defect cross-check all matched hand-computed expected values).
- `vulyk-status.md` step 1 driver line: "Workflow in your own tool list" is the check (per plan.md Assumptions), with the CLI-version fallback message reusing the same `claude --version` / `sort -V` / `2.1.154` idiom `top-model-brief.sh` already uses, for consistency rather than inventing a second detector.
- `vulyk-bootstrap.md`: also reworded two stale "blind acceptance gate" mentions near the caveat to "blind council" (drone-acceptance.md is already deleted on this branch, per story 05) - small in-file consistency fix, not a scope change.
- Working tree had `core.autocrlf=true`; `vulyk-bootstrap.md` picked up CRLF via Edit and was stripped back to LF with `sed -i 's/\r$//'` before finishing - the other three files (written fresh via Write) were already LF-only.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
