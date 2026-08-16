# VULYK ← AUTOPILOT: Integration Plan (Draft 1)

*Aug 2026. Targets Claude Code 2.1.232, native primitives only, subscription-safe.*

## 1. Design thesis

The merged framework keeps VULYK's identity whole — hive castes, Tier 0–4 routing, model cascade by agent frontmatter, the 7-layer memory plane, human approval as an unconditional spine — and absorbs from AUTOPILOT exactly one thing: **the discipline that a human's request survives, verbatim and traceable, all the way to a running result.** That arrives as four cheap mechanisms, not a second pipeline: a verbatim `brief.md` anchoring everything downstream; requirement quotes inside stories plus a deterministic forward/backward trace script; boundaries decided at plan time and handed to concurrent workers; and an independent checker that never sees the plan. Everything AUTOPILOT built to run unattended — modes, depth/polish dials, the manifest ledger, the dashboard, persistent reviewers, same-context repair — is refused, because VULYK's operator is at the keyboard and those mechanisms either contradict Law 1, require an experimental env flag, or add a second source of truth. The merge is measured by one test: does it add deterministic, zero-token checks (VULYK's only credibility currency) rather than ceremony?

## 2. Decisions

| Item | Verdict | Rationale |
|---|---|---|
| Wave/`blocked_by` frontmatter + `## Files` overlap check before co-dispatch | **Adopt** | Closes silent-overwrite data loss; reuses scope-check's existing awk parser. |
| One-message wave launch, one Task call per story | **Adopt** | Names the mechanism that actually produces concurrency; serial runs look identical today. |
| Bounded return contract (STATUS/FILES/TESTS/INTERFACES/CONCERNS/BLOCKERS, ≤25 lines) | **Adopt** | Returns are decoded output resident forever in the one context never refreshed. |
| `NEEDS_CONTEXT` status + 2-round repair ceiling, repairs stated as conditions | **Adopt** | Separates plan defects from worker failures; caps unbounded retry loops. |
| One commit per story, gated on scope-check + green quiet verification | **Adopt** | Fixes scope-gate contamination (story 03 counts 01–02's files) and adds rollback points. |
| Verbatim `docs/specs/<slug>/brief.md` | **Adopt** | One line of change; every independence gate is impossible without it. |
| Queen's-hands rule, scoped from the moment a story file exists (Tier 2+) | **Adopt** | Protects the unrefreshed context; unscoped it contradicts Tier 0. |
| Briefing question discipline (look facts up; ask only irreversible/costly/vendor/business-rule; one at a time; recommend a default) | **Adopt** | VULYK has no per-task clarification step at all today. |
| `## Requirements` quotes in stories + `scripts/trace-check.sh` (forward + backward) | **Adopt** | The manifest's whole user value, deterministic and zero-token. |
| `## Contracts` in `plan.md` (owns/exposes/hides + test seams), handed to multi-story waves | **Adopt (reworked)** | Same content as `interfaces.md` without an eighth memory-plane artifact. |
| Conditional blind acceptance (`drone-acceptance`: brief + repo + run command only) | **Adopt** | Only mechanism that can contradict the framework's own account of itself. |
| Independent coverage check (brief + plan only, never stories) | **Adopt (v0.8)** | The planner cannot see what the planner did not write. |
| Irreversible/outward-facing actions always a question, stated in worker agents | **Adopt** | worker-code/worker-test hold Bash; CLAUDE.md alone doesn't reach the excuse. |
| Secrets policy + `scripts/redact.sh` piped into learnings/handoff writers | **Adopt** | No secrets rule exists anywhere today; verbatim briefs make it structural. |
| `## Plan deltas` + `## Descoped` record | **Adopt** | Today's "re-scope the story" is unrecorded requirement narrowing. |
| drone-docs sources from diff, story labelled as a plan that may be wrong | **Adopt** | Its input contract currently undercuts its own "record what IS" rule. |
| Story-count budgets + >16 ceiling grafted onto Tier rows | **Adopt** | Useful half of AUTOPILOT's scale, no new vocabulary. |
| Tier 0–4 matrix, `## Files` + scope-check.sh, `## Non-goals`, tracer story, ~1500-token budget | **Keep** | Only objective metric plus the cheapest anti-scope-creep devices in either repo. |
| Single end-of-build `lead-review`, BLOCK/PASS binary, report-everything rule | **Keep** | Cross-story findings come free from one whole-diff read; per-story Opus is the BMAD tax. |
| Model cascade via frontmatter, aliases not IDs, Tier-4 different-model second reviewer | **Keep** | AUTOPILOT has no model routing at all; this is what makes the cascade affordable. |
| Unconditional approval gate; `/vulyk-build` refuses without the marker | **Keep** | Costs thirty seconds; only guard against an evening of wrong work on a real repo. |
| Memory plane, single-consolidator writes, staleness dates, `/vulyk-evolve`, hooks | **Keep** | AUTOPILOT has no cross-run learning; importing its absence is a straight loss. |
| Modes (full/semi/interview/manual), depth and polish dials | **Drop** | `full` waives Law 1; three dials for one operator who can just say what they want. |
| `state.js` + `dashboard.html` as truth or as v0.5 must | **Drop** | No async audience; duplicates frontmatter; needs an http server to render in-pane. |
| `.autopilot/` second storage root | **Drop** | `docs/specs/<slug>/` exists, is installed, and is git-diffable by design. |
| Persistent reviewers / same-context дозапрос | **Drop** | Needs Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) — breaks the no-flags promise. |
| Full R##/A##/D##/G## ledger, 7 statuses, 5 update moments, G1 | **Drop** | Bookkeeping over bookkeeping on a pipeline that has never run once. |
| Three-axis review as separate dispatches; per-axis verdicts | **Drop** | Doubles the priciest dispatch, buys no model diversity, loses the security axis. |
| `## Zone` field; T0–T3 tier labels; Russian stage vocabulary; ~2000-token story budget | **Drop** | Second scope truth, second tier scale, second language, evidence-free constant. |
| Dropping `## Implementation notes` / `## Findings`; status out of frontmatter | **Drop** | drone-docs and the wall rule read them; frontmatter is the compact-preserved truth. |
| Marker-generated CLAUDE.md; killing SessionEnd/handoff hooks | **Drop** | Hands a subagent the constitution; deletes the context meter before the longest sessions. |
| Rationalizations (30) + Red Flags (40) tables | **Rework** | ~5 rules survive as five lines; the rest is self-audit CLAUDE.md forbids. |
| Marker discipline | **Rework** | Generalize existing `VULYK:COMMANDS` to one `VULYK:PROFILE` pair, nothing more. |
| Dashboard/instruments | **Rework** | Optional `state.json` *derived* from frontmatter, v0.9.x, never a second authority. |
| `.claude/workflows/` example + Workflows-API roadmap line | **Drop** | No such product exists Aug 2026; the shipped example is the worse half of the overclaim. |

## 3. Resolved conflicts

**Review timing.** End-of-build `lead-review` stays the only model review; per-story checks are deterministic only (scope-check + the story's quiet verification), gating the commit. AUTOPILOT's amortisation is flag-gated, so per-story review buys cost without mitigation.

**Two tier scales.** Tier 0–4 is the only thing called a tier. Import counts (T0→0–1, T1→2 at 2–4 stories, T2→3 at 4–8, T3→4 at 9–16, >16 = split), delete the labels.

**Approval by default.** Gate stays unconditional. `full` mode is not shipped; if ever, only as a named, written waiver of Law 1 with every assumption recorded and reprinted.

**Rule 5 vs Tier 0.** Two rules: (a) keyboard scope binds from the moment a story file exists; (b) at *every* tier, never finish a returned worker's story by hand. Tier 0–1 direct work stands.

**Paths in the unit of work.** `## Files` wins outright; no zone field. It is the sole input to the only un-gameable metric, and doubles as the collision key.

**Gate authority.** Policy, stated once: deterministic scripts measure and never block; model verdicts may BLOCK; the human overrides either, out loud.

**Subagent continuation.** Available natively only for named/background agents behind an experimental flag. Ship fresh-worker repair as default; record *why* the cheap path is unavailable so nobody re-derives it.

**Spec mutability.** `## Plan deltas` in plan.md, Queen-written from the worker's *return report* (never a diff), one-line notice to the human. Only the human removes a requirement, quoted.

**Ceremony floor.** brief.md and requirement quotes at Tier 2+; trace-check whenever stories exist; Tier 0–1 gets none of it — written into the routing matrix as a rule.

**Memory source.** drone-docs' primary input becomes the diff; disagreement with the story is reported, diff wins.

**Session split.** Break at planning→build with `/vulyk-handoff` + `/clear`; effort set once per session on each side.

## 4. Roadmap

**v0.5.0 — Parallel build made safe and cheap.** `templates/story.md`: `wave:`, `blocked_by:`. `scripts/wave-check.sh` (report-only, exit 0). `vulyk-plan.md`/`queen-planner.md` compute waves and split on `## Files` intersection. `vulyk-build.md`: one-message wave launch; disjoint-files precondition; per-story close sequence (scope-check → quiet suite → commit → status); step 6's full suite moved out of the main session or piped through `tail -30`; two-round repair ceiling; `## Descoped` record. `worker-code.md`/`worker-test.md`: return contract + `NEEDS_CONTEXT`. `scope-check.sh` docstring updated. `CLAUDE.md`: scoped Queen's-hands rule; `vulyk-review.md` step 4 generalized from criticals to all findings. **Battle-test:** a real 4-story Tier-3 build; confirm scope.jsonl is no longer contaminated and no two workers touch one file.

**v0.6.0 — Distribution, secrets, safety.** `install.sh` writes `.claude/vulyk-version` and gains `--upgrade` (diff framework-owned files instead of skipping). `scripts/redact.sh` wired into `session-end-learnings.sh` and `handoff.py`'s prompt extractor. `CLAUDE.md` `## Secrets`; irreversible-action rule restated in both Bash-holding agents. Re-measure `effort:` frontmatter on 2.1.232 and restate or retract; fix the Haiku/Sonnet drift in `docs/architecture.md`, `command-reference.md`, `getting-started.md`, `vulyk-map.md`. Delete `.claude/workflows/` and the roadmap line. **Battle-test:** upgrade a project installed at 0.4.2 and confirm it receives 0.5.0's edits.

**v0.7.0 — Traceability spine.** `/vulyk-plan` step 1 writes redacted `brief.md`. `templates/story.md` gains `## Requirements` (verbatim quotes, exempt from the token budget). New `templates/plan.md` carrying `## Contracts` and `## Plan deltas`. `scripts/trace-check.sh`, called before the approval stop. Briefing discipline as a new `/vulyk-plan` step; payback/neighbour tests and the merge pass in `queen-planner.md`; story-count column in the routing matrix. **Battle-test:** two Tier-3 plans; does backward trace catch an invented story?

**v0.8.0 — Independence gates.** `.claude/agents/drone-coverage.md` (sonnet, Read, maxTurns 5) receiving exactly brief + plan, dispatched before approval. `.claude/agents/drone-acceptance.md` (sonnet, Read/Grep/Glob/Bash) receiving brief + repo + run command, never `docs/specs/**`, with a loud "cannot be run here" branch. Drift comparison logged to `memory/stats/acceptance.jsonl`. `lead-review.md`: Reinvention / Silent narrowing / Invented fact, expected-value provenance, the "could the worker have known?" routing line, findings as one-sentence conditions — report-everything unchanged. **Battle-test:** does G4 ever disagree with the story statuses, and does it decline honestly on a library-only spec?

**v0.9.x — Memory hardening and optional instruments.** drone-docs sources from diff + verify-before-write checklist; `VULYK:PROFILE` markers with `install.sh` reset support; ADR harvest from `## Plan deltas` on the review PASS path via `librarian`. Optional `state.json` derived from frontmatter, read by `/vulyk-status` and named in the handoff dump. `docs/pipeline.md`; README gains the fourth failure mode and a second measured item.

**1.0.0 criteria.** (1) Ten real specs across Tiers 2–4 with clean scope.jsonl, trace-check and acceptance.jsonl series. (2) `--upgrade` proven across two minors. (3) No documented claim unverified on the current client — effort, drone models, measured-vs-not section current. (4) Zero known silent-loss paths: no concurrent file collision, no unrecorded descope, no secret path into git. (5) Every new gate has a loud cannot-run branch.

## 5. Open questions for you

1. **Does `full`/unattended mode ever ship?** This plan says no. Saying yes requires amending Law 1 in writing — a constitutional edit only you can authorize.
2. **`memory/learnings/` in git — archive or ignore?** It ships a README and real content (archive by design), but is the only committed transcript-derived path. Redaction assumes it stays committed.
3. **Version-stamp timing:** v0.6.0 as planned, or pulled into v0.5.0 so the first merge release is itself deliverable to existing installs?
4. **Optional dashboard at all?** Judges rank it lowest-value; it remains the best demo asset. Ship in v0.9.x, or never.