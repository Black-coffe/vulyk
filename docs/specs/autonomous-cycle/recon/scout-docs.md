# Scout report: VULYK docs — human-gate removal / agent-council rewrite

## Purpose
Locate every doc location describing the human gate (stage 05), plan-approval stop (stage 02) and publish step (stage 06); the Queen's build-loop role; CHANGELOG/version-sync conventions; ADR/wiki listing; bootstrap interview Profile-row pattern; token-economy gate-cost claims.

## Entry points
- `E:\Projects\vulyk\CLAUDE.md` — constitution: cycle table, Five Laws, routing matrix, `## Profile` block (unfilled placeholders)
- `E:\Projects\vulyk\docs\cycle.md` — the six-stage loop, single source of stage definitions
- `E:\Projects\vulyk\docs\pipeline.md` — "the gates": what each of 9 checks can/can't see, staleness table
- `E:\Projects\vulyk\docs\architecture.md` — data-flow diagram through all 6 stages
- `E:\Projects\vulyk\docs\command-reference.md` — per-command prose for `/vulyk-plan|build|review|ship`
- `E:\Projects\vulyk\memory\learnings\2026-09-12-human-gates-rework.md` — **owner's own feedback note**, dated today, already states the desired direction
- `E:\Projects\vulyk\docs\grill\2026-09-12-autonomous-cycle-council.md` — **full design doc for the replacement**, already synthesized, adversarially reviewed, with a Decision log and amendments table

## Key types / contracts
- Cycle stages 01–06 (spec/plan/code/tests/human/ship), each closed by a confirmation artifact on disk (`docs/cycle.md:21-28`).
- `templates/plan.md`: marker lines `**Approved:**`, `**Branch:**`, `**Checked:**`, `**Shipped:**` (lines 59-62).
- `templates/adr.md`: `ADR-NNN`, `Status: proposed | accepted | superseded by ADR-NNN`.

## Dependencies
Tool note: in this session `Glob` and any `Grep` call with a **directory** `path` silently returned "No files found" for this repo (confirmed cwd is `E:\Projects\vulyk`, and `Read`/file-targeted `Grep` work correctly). I could not enumerate `docs/adr/`, `docs/wiki/`, or any directory listing — every file below was located by following explicit references in other files, never by listing. Treat "no ADR files found" as "not discoverable with available tools," not "confirmed absent."

## Gotchas
- `CITATION.cff` version (`0.9.5`) is **stale** against `VERSION` (`0.11.0`) — no sync script exists; nobody re-verifies it on release.
- `memory/memory.md` shows "no modules mapped yet" / "Wiki domains: none yet" despite the repo being on v0.11.0 — either the map/wiki were reset, or this repo doesn't dogfood its own `/vulyk-map`.
- The replacement design (council) is **already fully drafted** in the grill doc — this may not be known to whoever dispatched the recon.

## Answer

**1. Every place describing stage 05 / human-check.sh / "owner looks" / drone-acceptance / blind acceptance** (edit list):
- `CLAUDE.md`: cycle table row `05 | **Human**` (`| **Checked:**` col); "Working with a frontier model" section is untouched but Five Laws / routing matrix reference stage via the cycle table only.
- `docs/cycle.md:11,26-27` (diagram "05 Human (mandatory)"), `:30-42` ("Why 05 is red" — full rationale section, entirely about to be superseded), `:49-56` (invalidation table rows for stage 05/human check).
- `docs/pipeline.md:24` (`human-check.sh` gate row), `:55` (staleness row "Any commit after the owner looked").
- `docs/architecture.md:44-47` ("the owner looks (stage 05 - mandatory..."), caste table `drone-acceptance` row (:17), flow line `:40-46`.
- `docs/command-reference.md:15` (`/vulyk-review` full paragraph: check card, `human-check.sh`, PASS→stage05).
- `docs/getting-started.md:49` (working-loop block: "PASS hands YOU a check card...").
- `docs/model-cascade.md` — no direct human-gate mention (out of scope for this file).
- `README.md:151` (build-discipline bullet "**the cycle closes with a person...**"), `:164` (`/vulyk-ship` command row), roadmap `:269` (v0.11.0 entry — largest single description).
- `CHANGELOG.md` `## [0.11.0]` (lines 5-58) — the entire "Added" section is this feature's origin; will need a paired entry when reverted/replaced.
- `docs/architecture.md:52` ("librarian harvests ADRs" — post-human, tied to stage 06 not 05).
- **`memory/learnings/2026-09-12-human-gates-rework.md`** — owner's feedback already recorded, in Russian: v0.11.0 made the human a mandatory gate on 4 stages; a week later the owner asked to remove it because the models no longer need re-checking — that function should move to a blind agent council judging the brief, not a human. Says explicitly: never re-add "owner looks" as a mandatory stage for any tier; only irreversible-outward actions (publish/deploy) stay human by default, and even those aren't waited on.
- **`docs/grill/2026-09-12-autonomous-cycle-council.md`** — the actual spec for the replacement (13 decisions + Act 2 adversarial amendments). Verdict: stage 05 → **Council** (mandatory, agentic, 3 seats: `council-haiku` black-box/Client-path, `council-sonnet` suite+each-ask, `council-opus` intent/edge-cases), human becomes an optional override at any stage via a `PAUSE` semaphore file; `**Checked:**` → `**Council:**` written by a new `council-log.sh`; `human-check.sh` stays as an override path only. Ceiling: 3 rounds, escalate to human on no-consensus or ≥50% RED asks. This doc already names every file that needs editing (§"Производные решения" and the Act-2 table) — recommend reading it directly rather than re-deriving the plan.

**2. Stage 02 approval stop and stage 06 publish:**
- Approval: `CLAUDE.md` cycle table row 02; `docs/cycle.md:24`; `docs/architecture.md:34`; `docs/command-reference.md:9` (`/vulyk-plan` "...stops for human approval..."); `templates/plan.md:59` (`**Approved:**` marker). Grill doc decision #1/amendment: approval becomes a `**Briefed:** via grill` log line, folded into the new single mini-grill stop inside `/vulyk-plan`.
- Publish: `CLAUDE.md` cycle table row 06; `docs/cycle.md:28`; `docs/architecture.md:48-51`; `docs/command-reference.md:17-18` (`/vulyk-ship` full paragraph — "publish step printed for the human to press — no agent deploys"); README `:164`, `:269`. Grill doc amendment (Act 2, row "2"): merge stays local/automatic; only push/PR/tag/deploy stays human-pressed.

**3. Queen's build-loop role / token-economy argument for it:**
- `CLAUDE.md` "Token economy" section (Queen never reads source; bookend rule) and Five Laws #5.
- `docs/architecture.md:6-8,13` (caste table, "Queen ... owns plan & integration; consumes reports, never source"), flow lines `:23-55`.
- `docs/token-economy.md:51-70` ("Why the cascade is cache-safe and `/model` is not" — the core argument: a subagent's prefill never touches the Queen's cached prefix, which is what the Workflow-script proposal in the grill doc (decision #11) explicitly must preserve — "Fable делает минимум").
- `docs/command-reference.md:11-15` (`/vulyk-build`, `/vulyk-review` — describes Queen dispatching waves, running gates).
- Grill doc decision #11 is the exact rewrite target: "build → gates → council → repair loop moves to a Workflow script with session fallback," Queen wakes only twice (final report / escalation).

**4. CHANGELOG.md format:** Heading `## [X.Y.Z] - YYYY-MM-DD`; optional one-line prose summary under the heading; subsections `### Added` / `### Changed` / `### Fixed` / `### Removed` / `### Notes` / occasionally `### Upgrading`, each a bulleted list, bold lead phrase then explanation, often citing file paths and PR/contributor credit inline (e.g. `Found by [@chizhseo](...) in [PR #1](...)`), never raw commit hashes as the primary reference (one exception: `docs/grill/2026-09-12-autonomous-cycle-council.md` cites commit `2a35d15`). No `Co-Authored-By` lines appear in CHANGELOG. Version sync: **no script found.** `VERSION` = single line (`0.11.0`), `CITATION.cff` `version:` field (`0.9.5`) is stale/unsynced — confirms no release-check enforces this. `scripts/release-check.sh` (per README/CHANGELOG v0.9.2 entry) only counts the 1.0.0 spec-maturity bar (brief+scope+acceptance-fingerprint-match), not version-string sync.

**5. docs/adr/:** Could not list — no README found at `docs/adr/README.md`, no ADR filenames surfaced anywhere in the files read (README, CHANGELOG, all docs/*.md). Convention exists only via `templates/adr.md`: title `# ADR-NNN: <title>`, `Status: proposed | accepted | superseded by ADR-NNN`, `Date`, `Spec:` pointer, sections Context/Options/Decision/Consequences/Invariants created/Revisit when. Governance: no ADR is auto-`accepted` — status is always `proposed` on harvest (`librarian`, stage 06 only, per CHANGELOG v0.9.0); acceptance is human-only. None of the docs I read state an ADR governs the cycle or human gates specifically — the grill doc is pre-ADR (status "синтез готов, реализация не начата").

**6. bootstrap/interview.md Profile rows:** Batch 2, Q9 → *Client path* ("How does a person reach the running thing? ... its quiet command goes in the Profile's Client path row; 'none: library only' is an answer"); Q10 → *Release / deploy* ("How does a version get published, and who presses the button? ... goes in the Release / deploy row; `/vulyk-ship` prints it and never presses it"). A new `Browser MCP` row would follow the same pattern: one interview question in Batch 2 (after Q9, since it's Client-path-adjacent), phrased as a closed choice with a stated default and a one-line reason it goes in the Profile, quoted back in `## Project profile` per the "After the interview" rule (`bootstrap/interview.md:26-28`). The grill doc already proposes this exact row: decision #8, "новая необязательная строка Профиля `Browser MCP: chrome-devtools / claude-in-chrome / none`."

**7. docs/token-economy.md gate-cost numbers:** This file contains **no per-gate dispatch-count or per-spec cost figures** — it's about token pricing mechanics (cache/model/effort multipliers), not gate economics. The only place with a gate-cost claim relevant to the council redesign is the grill doc itself (Act 2 amendment, Anti-scope row): "+3 диспатча (1 Opus-класса) с холодным кешем" per round, and fallback mode runs the loop in the pinned top-model session as "the most expensive path" — this is a **proposed** cost for the new design, not an existing measured claim. `docs/model-cascade.md:97-106` has the only existing per-caste model/dispatch table (`lead-review` + `drone-acceptance` dispatched together, "one message," `drone-acceptance` sonnet, no explicit dispatch count per spec beyond "one run per review + Tier-4 second reviewer").
