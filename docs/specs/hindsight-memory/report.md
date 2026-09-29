# Hindsight → VULYK: editorial board report

Study work, 2026-09-29. Source: a Telegram post about vectorize-io/hindsight (`evidence/post.md`).
The board had three members, each working independently in their own context: Opus 5.5, Sonnet 5.5 and Fable 5.1.
Round 1: each studied the post, Hindsight's source and VULYK (`evidence/r1-*.md`). Round 2: each member cross-checked the others' claims on disk and voted on a merged list (`evidence/r2-*.md`).

## Verdict on Hindsight itself

The post gets the numbers and settings right. All of these were confirmed through `gh api` and the repo source:
- stars: 42 689 for Hindsight, 66 320 for Mem0, 59 363 for MemPalace;
- port 9077;
- `HINDSIGHT_DYNAMIC_BANK_ID`;
- `claude-code` is "personal/local use only".

The post misses these points:
- The plugin it recommends, `hindsight-memory`, is **deprecated by its own authors** (`scripts/lib/upgrade_notice.py`).
- Retain runs every 10th turn plus a forced retain at SessionEnd, not after every reply.
- The "exact quotes" belong to a different object: reflect-time observations, not consolidated ones.
- The headline claim, "the agent changes behaviour after your corrections", has **no mechanism and no measurement**. The lesson carrier is prose injected into the prompt (≤1024 tokens per prompt). The benchmarks (LongMemEval, LoCoMo) test recall of a conversation, not whether a mistake repeats.

Unanimous: **do not install Hindsight**. The board also unanimously rejected:
- a daemon with Postgres/pgvector;
- per-prompt recall;
- a CLAUDE.md that rewrites itself;
- vectors or graph retrieval;
- an LLM correction classifier;
- counters used as an escalation ladder;
- one shared bank across projects.

## Votes

| ID | Proposal | Opus | Sonnet | Fable | Result |
|---|---|---|---|---|---|
| C1 | litopys journal: harness text (`task-notification`, `system-reminder`, cross-session, pasted) goes to `## notice · <kind>`, not `## user`. 61 of 110 "owner" blocks in VULYK's journals are subagent reports | FOR | FOR* | FOR* | **Accepted 3:0** |
| C2 | litopys distill: a «quote» in `## Decisions` or `## Corrections` must be a whitespace-normalised substring of the journal's human `## user` text. `distill record` refuses otherwise; a quote that is not found is omitted, never paraphrased | FOR* | FOR* | FOR* | **Accepted 3:0** |
| C3 | Measure unfiled owner corrections: a $0 replay of the intake lexicon now; the distiller's corrections once C2 exists; sunset if n<10 in a month | merged | b | a-merged | **Accepted 3:0 in substance.** No SessionStart line (3:0); consumer `/vulyk-evolve` (2:1). Open: where the reader lives |
| C4 | Two live defect cards share a key | exact → red, containment → info | info only | red for new, by blame | **Accepted 2:1.** New overlapping keys (by git blame) → red; existing overlaps and containment → info |
| C5 | A `text` card no hook can deliver (no `paths:`) is a defect. YouTube_AI: 9 of 9 text cards (~20 owner quotes) are never injected | FOR* | FOR | FOR* | **Accepted 3:0** |
| C6 | `scripts/redact.sh` + `handoff.py`: prefix-anchored patterns (Telegram bot, npm, PyPI, GitLab, HF, Groq, SendGrid, Stripe live, Slack webhook). Today 10 of 15 shapes pass through | FOR* | FOR | FOR* | **Accepted 3:0** |
| C7 | Quote count and sorting on the injected card | DEFER | FOR* (count only) | DEFER | Deferred 2:1, until the first budget overflow |
| C8 | `stale` line for text cards with no quote in 90 d | DEFER | DEFER | DEFER | Deferred 3:0, until 2026-12-27 |
| C9 | `/vulyk-gc` refuses to commit a `CONSOLIDATED.md` that lost >50% of its entries or bytes | FOR* | DEFER | FOR* | **Accepted 2:1** |
| C10 | Rendered defect index | DEFER (author withdrew) | AGAINST | DEFER | Rejected |
| C11 | Escape: a `block` card gets a quote after its block commit, with no fixture or check commit since → red | FOR* | DEFER | FOR* | **Accepted 2:1.** Sonnet's "0 escapes" did not hold: Fable found 2 on 2026-09-27 |
| C12 | Hindsight consolidation rules as a design note for litopys phase 3 | DEFER | DEFER | FOR | Deferred 2:1, until phase 3 opens |
| C13 | Isolate `claude -p` in litopys bench | AGAINST | DEFER | DEFER (author) | Dropped |

FOR* = FOR with an amendment. The amendments are written into the "Accepted package" below.

## Accepted package

**VULYK** (`scripts/defects-check.sh`, `tests/defects.test.sh`, `docs/defects/README.md`, `scripts/redact.sh`,
`.claude/hooks/handoff.py`, `.claude/commands/vulyk-gc.md`, `.claude/commands/vulyk-evolve.md`):
- **C5.** An undeliverable `text` card: new → red, old → reported, by the same blame rule as debt. The message says `area:` is a label, not a glob; the host writes `paths:`/`cmd:` itself, with no auto-migration. Fixtures: `area:`-only, `paths: []`, a blank `paths:`, and a `cmd:`-only card that stays green.
- **C4.** A new overlapping key → red; existing overlaps and containment → info. Fixture: the `не дышит` pair.
- **C11.** `ESCAPE <id>` is red from day one. It turns green after a commit to `fixtures:` or `check:` that is newer than the quote. Fixtures: the `speech-cut` and `frame-timecode-stale` states of 2026-09-27.
- **C6.** Patterns with length floors, and no PII or entropy rules. Negatives: a git sha, a base64 word, `sk-learn`, an ISO timestamp. `handoff.py` gets the same list.
- **C9.** A shell condition in the commit step, not a sentence the model is asked to honour. The report always prints `entries a→b, bytes a→b`.
- **C3 (VULYK side).** `/vulyk-evolve` shows `corrections: fired / filed / unfiled` with n.
- Every new red (C4, C5, C11) needs the new/old split by blame, because `lead-review` runs the audit. Without it, the next upgrade turns a host red in review over pre-existing cards. New checks count quotes only under the quotes heading, with the script's existing parser.

**litopys** (a separate repo): C1 → C2 → the C3 reader. Owner of the C3 reader: `bin/litopys corrections [--lexicon]` (Fable, the one-CLI contract of grill 09-21 D13) or VULYK reading `.litopys/raw` directly (Sonnet). The Queen recommends litopys.

## What all three missed (from round 2)

- **The 0.19 contract renamed `area:` to `paths:` without a migration.** The shipped injector cannot deliver the pilot library it was generalised from. C5 treats the symptom. The lesson: a rename in a contract needs an upgrade line.
- **YouTube_AI still runs `claude -p` in SessionEnd** (`project-learnings.sh`). This is the anomaly ADR-014 names. It is host-side, but it should be fixed.
- **The post's real question has had no metric:** "does a filed correction stop repeating". C11 + C3 give the first number: repeats after filing, per class, with n.
