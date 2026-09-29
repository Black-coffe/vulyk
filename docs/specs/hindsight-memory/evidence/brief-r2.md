# Editorial board, round 2 — cross-grill and vote

Round 1 is done. The three reports: `SCRATCH/r1-opus.md`, `SCRATCH/r1-sonnet.md`, `SCRATCH/r1-fable.md`.
Read the other two in full (you know your own). Then grill them: every factual claim a proposal rests
on that you can check on disk or in a repo — check it (e.g. "61 of 110 user blocks are task-notifications",
"9 of 9 YouTube_AI text cards have no `paths:`", "redact.sh masks 5 of 15 shapes", "`не дышит` in two
cards", "memory/learnings is being retired", "the grill decided sorting by repeats×freshness",
"hindsight-memory plugin deprecated"). Read-only: change no file in E:/Projects/vulyk, D:/YouTube_AI or
litopys. Running `defects-check.sh` or `redact.sh` read-only is fine.

## Canonical list (the Queen merged the three reports)

| ID | Proposal | From | Owner |
|---|---|---|---|
| C1 | litopys journal writes harness text (`<task-notification>`, `<system-reminder>`, `<pasted_content>`, cross-session) as `## notice`, not `## user` | Opus P1 | litopys |
| C2 | litopys distill: owner quotes (decisions and/or a `## Corrections` section) must be a verbatim substring of the journal's `## user` text, `distill record` refuses otherwise | Opus P2 (first half) + Sonnet P3 | litopys |
| C3 | Measure unfiled owner corrections. Variant **a**: `litopys corrections` CLI + a conditional line in VULYK `session-start-brief.sh` "N corrections not filed in docs/defects" (Opus P2 second half). Variant **b**: `$0` replay of `defect-intake.sh`'s lexicon over closed journals, a filed-rate report in audit/evolve, sunset if n<10 in a month (Sonnet P4). | Opus, Sonnet | VULYK (+litopys for a) |
| C4 | Two live defect cards share a key or one key contains another. Variant **a**: `defects-check.sh` goes RED now (Opus P3). Variant **b**: an info `overlap` line in the audit, not before 2026-12-27 (Fable P2). | Opus, Fable | VULYK |
| C5 | A `text` card no hook can deliver (no `paths:`) is a defect in `defects-check.sh` (new = red, old = reported) | Sonnet P1 | VULYK |
| C6 | Widen `scripts/redact.sh` with prefix-anchored patterns from Hindsight's Memory Defense list (Telegram bot token, npm, PyPI, GitLab, HF, Groq, SendGrid, Stripe live, Slack webhook), negatives fixtures | Sonnet P2 | VULYK |
| C7 | `defects-inject.sh` shows `· N quotes, last <date>` per card and sorts cards by (count, recency) before the 4000-char cut | Fable P1 | VULYK |
| C8 | `stale <id>` info line for `text` cards with no quote in 90 d, feeding `/vulyk-evolve` prune; not before 2026-12-27 | Fable P2 (stale half) | VULYK |
| C9 | `/vulyk-gc` refuses to commit a `CONSOLIDATED.md` that lost >50% entries or bytes, shows the diff | Fable P3 | VULYK |
| C10 | `defects-check.sh --index` renders the `## Cards` table of `docs/defects/README.md`; audit fails on drift | Opus P4 | VULYK |
| C11 | Recurrence report: per block card, quotes that arrived after its block commit (audit output; red only after the first real escape) | Sonnet P5 | VULYK |
| C12 | Design note for litopys's future phase-3 consolidator: Hindsight's processing rules (update over create, one note per facet, `reason` + source refs per op) + `sources: N` / `last_seen` frontmatter | Fable P4 | litopys |
| C13 | litopys `bench` runs spawned `claude -p` with a scratch `CLAUDE_CONFIG_DIR` so host hooks do not fire in it | Fable P5 | litopys |
| R  | Rejected by all three: install Hindsight / its plugin; per-prompt auto-recall; self-rewriting CLAUDE.md or mental models; vectors/graph retrieval; LLM or per-prompt correction classifier; counters as escalation ladder; one shared bank | all | — |

## Your vote

For every C-item: **FOR** / **FOR with amendment** (write the amendment) / **AGAINST** / **DEFER** (name
the data or date that would reopen it). For C3 and C4 also pick the variant (a / b / neither / a merged
form you write). One line of reason each, citing what you checked. Vote on R too (confirm or dissent).

Grill honestly: if the other author's evidence does not hold on disk, say so with the command/path. If
your own round-1 proposal does not survive the others' reports, say so and vote against it. Do not vote
FOR out of politeness; "does it pay for itself under Law 2" is the bar.

## Output

Write `OUT` with:
1. **Checks** — table: claim | author | holds? | how you checked.
2. **Votes** — table: ID | vote | variant | amendment | reason.
3. **Anything all three missed** (max 3 lines, or "none").

Checkpoint: create the file early and append. Final reply to the caller: 8 lines max — path and the votes
in one compact line (e.g. `C1 FOR, C2 FOR*, C3 b, ...`).
