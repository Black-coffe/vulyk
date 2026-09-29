# Board R1 — Opus 5.5 — Hindsight → VULYK

_Status: complete (2026-09-29)._

Sources read on 2026-09-29: `gh api` on vectorize-io/hindsight (main, pushed 2026-09-29), files named below;
arXiv 2512.12818 abstract; `gh api` on mem0ai/mem0 and MemPalace/mempalace.

## 1. Fact check of the post

| Claim in the post | Status | Source(s) |
|---|---|---|
| Hindsight has >42k GitHub stars | **Confirmed** — 42,689 on 2026-09-29; repo created 2025-10-30, MIT | `gh api repos/vectorize-io/hindsight`; star-history chart linked from README |
| Mem0 since 2023, 66k stars | **Confirmed** — created 2023-06-20, 66,320 stars | `gh api repos/mem0ai/mem0` |
| MemPalace "came out this spring", 59k in half a year | **Confirmed** — MemPalace/mempalace created 2026-04-05, 59,363 stars | `gh search repos MemPalace` |
| MemPalace stores chats verbatim locally, retrieves without a single LLM call | **Confirmed** (vendor's own words: "Verbatim storage … zero API calls") | github.com/MemPalace/mempalace description + README |
| Plugin: before each message finds relevant memory and injects it silently | **Confirmed** — `UserPromptSubmit` → `scripts/recall.py` → `hookSpecificOutput.additionalContext`, block `<hindsight_memories>`, cap `recallMaxTokens` 1024 | `hindsight-integrations/claude-code/hooks/hooks.json`, `scripts/recall.py`, `settings.json` |
| "After the reply" it extracts facts into the base | **Partly** — `Stop` hook (`async: true`) runs `retain.py`, but by default only **every 10th turn** (`retainEveryNTurns: 10`, overlap 2); it POSTs the raw transcript, the *server* extracts facts with an LLM | `settings.json`, `scripts/retain.py` |
| Four zones: world facts / experience / observations / mental models | **Confirmed** (README "Memory types"; paper: "four logical networks"). In code the extracted types are `world` and `assistant`; observations and mental models are derived layers | README l.281-284; `engine/retain/fact_extraction.py` l.272; arXiv 2512.12818 |
| Each observation has evidence with exact quotes + a confirmation counter; refined, not overwritten | **Confirmed** — `proof_count`, `source_memory_ids`, a required `reason` on every create/update/delete, an `observation_history` table of pre-update snapshots | README l.350; `engine/consolidation/consolidator.py` header and l.2884-2940; `consolidation/prompts.py` |
| Mental model = a question asked once; Hindsight writes and rewrites the answer | **Confirmed** — plus a "delta" refresh mode that edits by section/block id ops | README l.356; `engine/mental_model_refresh.py`; `engine/reflect/delta_ops.py` |
| "Normal DB with vector search", memory won't choke after months | **Half** — PostgreSQL + pgvector (embedded `pg0` locally) confirmed; "won't choke" is marketing, not measured in the repo | README l.75, l.168, l.399 |
| Four retrieval ways: meaning, exact words, entity links, time | **Confirmed** — 4-way parallel retrieval fused by RRF (k=60), then reranker | `engine/search/retrieval.py` header; `engine/search/fusion.py` l.29 |
| `HINDSIGHT_LLM_PROVIDER=claude-code`, Pro/Max, "personal use only" | **Confirmed** — plugin README: "uses Claude Code's own model — personal/local use only" | `hindsight-integrations/claude-code/README.md` Quick Start; `engine/providers/claude_code_llm.py` docstring |
| Needs `uv`; `/plugin marketplace add vectorize-io/hindsight`, `/plugin install hindsight-memory` | **Confirmed** | plugin README Quick Start; `.claude-plugin/marketplace.json` |
| `curl http://localhost:9077/health` | **Confirmed** — `apiPort` default 9077; plugin README troubleshooting uses this exact curl | `settings.json`; plugin README |
| UI via `uvx hindsight-embed control start` | **Not fully confirmed** — "control start" appears in `hindsight-docs/docs/sdks/embed.md` (code search hit); I did not open it | `gh search code` |
| One memory for all projects by default; per repo with `HINDSIGHT_DYNAMIC_BANK_ID=true` | **Confirmed** — `bankId: "claude_code"`, `dynamicBankId: false`, granularity `["agent","project"]`; git worktrees share one bank | `settings.json`; `hindsight-docs/docs-integrations/claude-code.md` l.179-188 |
| First start can take a couple of minutes | **Plausible, not measured** — SessionStart only pre-starts the daemon in background (5 s cap); recall never starts it | `scripts/session_start.py`, `scripts/recall.py` |
| Cloud version exists | **Confirmed** — Hindsight Cloud, usage-based | README l.115 |
| "The agent really changes behaviour after your corrections" | **Not confirmed** — nothing in the repo or paper measures behaviour change after a correction. Published numbers (LongMemEval 91.4%, LoCoMo 89.61%) are *conversational QA recall* — "remembers what was said". README says Hindsight's figures were independently reproduced (Virginia Tech, Washington Post); competitors' are self-reported | arXiv 2512.12818 abstract; README l.44-50 |

Two things the post omits that matter for VULYK: (a) default recall injects up to **1024 tokens on every prompt of
5+ characters** — a per-turn tax, not a session-start cost; (b) local mode is **a long-running daemon + embedded
Postgres + an extraction LLM** — exactly the "runtime service a host must keep running" VULYK has refused so far.

## 2. How Hindsight actually works (from source)

- **Plugin = 4 hooks + 1 MCP server** (`hindsight-integrations/claude-code/hooks/hooks.json`). `SessionStart`
  (`scripts/session_start.py`, 5 s): health check; if down, background pre-start of `hindsight-embed` via `uvx`.
  `UserPromptSubmit` (`scripts/recall.py`, 45 s hook timeout, 10 s request): query = prompt (+N prior turns, cap
  800 chars) → `/recall` with `types=["observation"]`, budget `mid`, ≤1024 tokens, optional score floors → prints
  `additionalContext` wrapped in `<hindsight_memories>` with the preamble "prioritize recent when conflicting …
  ignore the rest" and the current time. `Stop` (`scripts/retain.py`, async): every N turns, reads the JSONL
  transcript, **strips its own `<hindsight_memories>` tags (feedback-loop guard)**, POSTs the chunk with
  `document_id=session_id[-cN]`, `tags=[session_id]`. `SessionEnd` (`scripts/session_end.py`): only stops a daemon
  it started — no model work there. `scripts/mcp_server.py`: `agent_knowledge_*` tools (pages, recall, ingest).
- **Retain** (`hindsight-api-slim/hindsight_api/engine/retain/fact_extraction.py`, 3.6k lines): an LLM turns text
  into facts with `what/when/where/who/why`, `fact_type ∈ {world, assistant}`, entities, `occurred_start/end`,
  `mentioned_at`. The prompt files **"user preferences, rules, corrections, constraints" as `world`** facts.
  Facts are embedded, entity-resolved and linked (`entity_processing.py`, `link_creation.py`, `causal_links.py`).
- **Consolidation** (`engine/consolidation/consolidator.py`, `consolidation/prompts.py`): background job after
  retain. Input: new facts `[uuid] text (temporal)` + existing observations pooled by recall, each with
  `proof_count` and `source_memories`. Output: JSON `{creates, updates, deletes}`; **every entry must carry a
  one-sentence `reason`** ("audited to catch duplicate creates"). Rules: prefer UPDATE over CREATE; one observation
  per facet; match by entity/facet, not topic; state changes update concisely; **never compute** (no arithmetic
  from facts); preserve history, delete only when superseded or identical; at most one update per id. SQL
  recomputes `proof_count` as the distinct count of `source_memory_ids`; before each update the old text is
  snapshotted into `observation_history` (capped). An optional **capacity note** ("OBSERVATION LIMIT REACHED —
  only UPDATE or DELETE") bounds growth per scope.
- **Mental models** (`engine/mental_model_refresh.py`, `engine/reflect/delta_ops.py`): a pinned question; refresh
  runs `reflect` and, in **delta mode**, the LLM emits typed ops addressed by section/block **id** (never index);
  unmentioned blocks are copied byte-for-byte ("prose drift is structurally impossible"); an op list that fails
  the schema → zero changes ("the structure can only get better or stay the same"). Stale = any tagged write since
  the last refresh.
- **Retractions** (`engine/reflect/retractions.py`): a model keeps `based_on` fact ids; when a cited fact is
  deleted or invalidated, the absence is turned into a value and the claim is pruned — "a retraction is the
  absence of a row, so it raises no watermark". Pure dict transform, testable without DB or LLM.
- **Recall** (`engine/search/retrieval.py`, `search/fusion.py`): 4 arms in parallel — pgvector semantic, BM25,
  graph (link expansion from seed entities), temporal (query-extracted window with spreading) — each capped per
  source, fused by reciprocal-rank fusion k=60, cross-encoder rerank, token-budget trim.
- **Runtime**: PostgreSQL+pgvector (or Oracle 23ai); locally an embedded `pg0` in a `hindsight-embed` daemon on
  :9077; extraction LLM from 25+ providers incl. `claude-code` (Agent SDK subprocess with the user's plugins
  isolated so its own Stop hook does not recurse — `engine/providers/claude_code_llm.py` l.39-52).

## 3. VULYK today vs. Hindsight

Evidence I gathered on disk for this section (read-only):
- VULYK's own litopys journals, `E:/Projects/vulyk/.litopys/raw/*.md`: 9 journals, **110 `## user` blocks, 61 of
  them are `<task-notification>` blocks** (harness/subagent reports recorded as if the owner said them); 7 of 9
  journals affected. `raw-journal.sh` writes `.user_input // .prompt` verbatim (litopys `hooks/raw-journal.sh`
  l.98); `agents/distiller.md` has no rule separating human text from harness notices.
- YouTube_AI's library (`D:/YouTube_AI/docs/defects/`, 22 cards, 113 `keys:`): **3 ambiguous key pairs** —
  `не дышит` in both `breath-cut` and `speech-cut`; `пустота` ⊂ `где пустота` (`dead-silence` /
  `overlay-on-busy-screen`); `неполно` ⊂ `неполноценно` (`shoot-step-guesswork` / `script-shallow`).
  `defect-intake.sh` matches keys by substring, so one remark names two classes.
- Same library: `shoot-step-guesswork` is a `text` card with **7 owner quotes between 09-10 and 09-25** — the
  class kept coming back while it lived as prose. Its `README.md` index is hand-kept: 21 of 22 cards listed
  (`review-take-uncut` missing), counts correct today.
- VULYK's own `docs/defects/` has **zero cards** (index table empty).

| Concern | Hindsight | VULYK / litopys today | Verdict |
|---|---|---|---|
| Capture of the owner's words | `Stop` async, every 10 turns, raw transcript → server LLM | `defect-intake.sh` (UserPromptSubmit, regex + card keys, $0, human text only); litopys `hooks/raw-journal.sh` (verbatim, no model) | overlap; litopys journal lacks Hindsight's role separation (P1) |
| Corrections as a fact type | extraction prompt files "preferences, rules, **corrections**, constraints" as `world` facts at retain time | intake regex only; grill 2026-09-27 D4 said "пропуски regex добирает дистилляция litopys" — **not built**: distiller has 4 sections, none for corrections | Hindsight has it, VULYK decided it and lacks it (P2) |
| Evidence | `source_memory_ids` → extracted facts; **paraphrased by default** (verbatim is an opt-in mode, `fact_extraction.py` l.1189) | card quote lines, **verbatim** «…», date · material · place (`docs/defects/README.md`) | VULYK stronger |
| Counter | `proof_count` = distinct sources; informational | quote count; **2+ without an earned block = debt, gate red** (ADR-014 D3) | VULYK stronger: the counter *enforces* |
| Refine, don't overwrite | UPDATE with `reason`, pre-update snapshot in capped `observation_history` | "one line per remark; a repeat is a new line, never an edit"; `## Revoked` with owner words; git keeps all | VULYK stronger (append-only + uncapped git) |
| Anti-duplication | UPDATE-over-CREATE, one observation per facet, every CREATE must name what it considered, verbatim-duplicate CREATE dropped (`consolidator.py` l.2711) | "one card per class, not per place" — words only; nothing detects a split class or a shared key | Hindsight has the discipline; VULYK needs one mechanical piece of it (P3) |
| Delivery to the model | every prompt ≥5 chars, ≤1024 tokens of observations | `defects-inject.sh` PreToolUse by `paths:`, once per session+agent, budgeted; `block` cards never injected | VULYK far cheaper and targeted; Hindsight is semantic (finds lessons with no path) |
| Enforcement | none — memory is context | `check:` + two fixtures, debt gate, `lead-review` treats a warning as a finding | **VULYK decisively stronger. The post's headline ("behaviour changes after your corrections") is exactly what Hindsight has no mechanism or benchmark for** |
| Derived standing views | mental models: a question, answer regenerated, read = DB read, delta ops by id | `docs/defects/README.md` table and `memory/memory.md` kept by hand/by agent | small gap (P4) |
| Retraction of dead grounding | `reflect/retractions.py`: "absence raises no watermark" → turned into a value | nothing for a card whose `paths:` match no file (never injected, silently) | deferred (§5) |
| Retrieval | 4 arms + RRF + rerank, pgvector | litopys recall: navigation + `git grep`, Sonnet subagent, answer with refs | Hindsight stronger at scale; no golden-question failure asks for more |
| SessionEnd | only stops its daemon, no model work | ADR-014: no model in SessionEnd (60 s) | **agree** — independent confirmation of the owner's rule |
| Scope | one global bank by default | per host, in its git | VULYK safer by default |
| Runtime | daemon + embedded Postgres + extraction LLM on every retain | bash + markdown + hooks; model only in commands/skills | VULYK's non-negotiable prior |

## 4. Proposals

Four, not seven. Each moves a Hindsight *mechanism* into files VULYK or litopys already own; none adds a service,
a per-turn line, or prose that is supposed to change behaviour on its own.

### P1 — litopys: the journal separates the owner from the harness (Hindsight: retain strips its own injected tags; extraction keeps `world` and `assistant` apart)
- **What.** Hindsight's `retain.py` strips `<hindsight_memories>` before storing, so memory never re-ingests its
  own injections, and its extractor never files the assistant's words as the user's. litopys records the raw
  prompt, so `<task-notification>`, `<system-reminder>`, `<cross-session-message>` and `<pasted_content>`
  segments land under `## user`. Take the separation: `raw-journal.sh prompt` cuts those segments out of the
  `## user` block and writes them as their own `## notice · <ts>` block (kept, not dropped: they are real
  session history). The cut list is the one `defect-intake.sh` already applies (ADR-014 D5).
- **Where / owner.** litopys: `hooks/raw-journal.sh`, `agents/distiller.md` (one line: `## notice` blocks are
  harness reports, never the owner), its hook test. Nothing in VULYK.
- **Why it does not harm.** No model, no network (litopys README promise); deterministic jq/bash; litopys owns
  capture (grill 2026-09-21 D3, D13). It removes a misattribution instead of adding memory.
- **Cost / risk / measure.** ~20 lines of bash, zero tokens. Risk: an owner message that contains a pasted log
  loses that log from `## user` — acceptable, it moves to `## notice`, nothing is lost. Measure: a check that
  fails today — a fixture journal whose `## user` holds a `<task-notification>` (original case: VULYK's own
  journals, 61 of 110 user blocks) and a neighbour form (`<pasted_content>` inside a human sentence); after the
  fix, `## user` blocks carrying those tags = 0.
- **Size.** Tier 1 in litopys.

### P2 — litopys + VULYK: owner corrections captured at the distill boundary as verbatim evidence (Hindsight: corrections are a fact type extracted at retain, each belief pointing at its source rows)
- **What.** Hindsight classifies "preferences, rules, corrections, constraints" at the retain boundary, once, in
  batch — not with a per-prompt classifier — and every derived belief points at its sources. Take the boundary
  and the provenance, reject the paraphrase: the distiller body gets a fifth section `## Corrections`, each line
  `- «<owner's exact words>» — <what it corrected>`; `bin/litopys distill record` **refuses** (exit 2, like the
  secret filter) any line whose «…» is not a verbatim substring of a `## user` block of that journal (after P1:
  human text only). A new read-only `bin/litopys corrections [--since <date>]` prints `date · session · «quote»`.
  VULYK's consumer: `session-start-brief.sh` prints one conditional line, only when some quote from
  `litopys corrections --since <the library's first commit>` occurs in no card under `docs/defects/` (plain
  `grep -F`): "N owner corrections in the chronicle are not filed in docs/defects: `bin/litopys corrections`".
  Silent when litopys is absent or nothing is unfiled.
- **Where / owner.** litopys owns extraction, the provenance check and the CLI (a format change: ADR-009's
  record shape gets a successor ADR). VULYK owns only the brief line.
- **Why it does not harm.** It is the backstop grill 2026-09-27 D4 already decided ("пропуски regex добирает
  дистилляция litopys на границе") and ADR-014 never built. No SessionEnd model call: distill runs where it
  already runs (grill 2026-09-21 D11). Not a prose lesson carrier: a correction only becomes a quote in a card,
  and from there Law 6 decides block or text. No per-prompt classifier (rejected in ADR-014). litopys stays
  usable without VULYK, VULYK without litopys.
- **Cost / risk / measure.** One extra section in a Sonnet call that already happens; the ~5% capture cap holds
  if a distill run grows by at most 10% (litopys's own `distill.jsonl` token fields). Brief line: 0 bytes on a
  quiet day, ~150 B when due. Risk: over-extraction of routine "нет, сделай иначе" makes the line nag. Measures:
  (a) precision — the owner labels 20 extracted lines; below 0.7 the section is removed (sunset, Law 2);
  (b) the intake regex's recall becomes measurable for the first time: corrections the intake hook fired on ÷
  corrections in the chronicle over the same sessions. That closes the unverified ✗ "Regex ловит большинство
  поправок владельца" in the 09-27 grill's assumption ledger.
- **Depends on** P1, otherwise a subagent report can be quoted as the owner's words.
- **Size.** Tier 2 in litopys; Tier 1 in VULYK.

### P3 — VULYK: a split class or a shared key fails the defect gate (Hindsight: one observation per facet, UPDATE over CREATE, every CREATE names what it considered)
- **What.** Hindsight spends most of its consolidation prompt on anti-duplication, because `proof_count` only
  means something when evidence converges on one node. In VULYK the count is not informational: **two quotes on
  one card is what turns prose into a mandatory gate** (ADR-014 D3). A class split over two cards, or a key that
  sends one remark to two cards, spreads repeats thin, and the debt rule never fires — Law 6 evaded silently.
  Take the mechanical half of that discipline: `scripts/defects-check.sh` (audit and `<arg>` runs) goes red when
  a normalised key (lowercase, trimmed) of one non-revoked card equals or is a substring of a key of another.
  The fix is a human-visible choice: merge the cards (quote lines move, never rewritten) or sharpen the key.
- **Where / owner.** VULYK: `scripts/defects-check.sh`, `tests/defects.test.sh`, one line in
  `docs/defects/README.md` (a key points at one class).
- **Why it does not harm.** A failing check, not a warning (Law 6); zero context bytes; no model; it tightens
  ADR-014 D3 instead of adding a mechanism beside it.
- **Cost / risk / measure.** ~25 lines of Python inside the existing card parser. Fixtures: original case — two
  cards sharing `не дышит` (YouTube_AI `breath-cut` / `speech-cut`); neighbour form — containment with a case
  difference (`Пустота` vs `где пустота`). Risk: short stems collide across genuinely different classes; in the
  only real library that is 3 pairs out of 113 keys, and each of them does make `defect-intake.sh` name two
  classes for one remark, so each hit is a real ambiguity. Measure: 0 ambiguous pairs after the first run per
  host; number of hosts where it fired.
- **Size.** Tier 1.

### P4 — VULYK: the defect index is rendered, not written (Hindsight: a mental model is a standing view regenerated from evidence; reading it needs no LLM)
- **What.** Hindsight never has anyone hand-maintain the summary of its evidence; it regenerates it. VULYK's
  `docs/defects/README.md` `## Cards` table (id, class, status, quotes, check, last quote) is kept by hand.
  `defects-check.sh --index` renders it between two markers from the cards; the audit fails when the committed
  table differs from the render.
- **Where / owner.** VULYK: `scripts/defects-check.sh`, `docs/defects/README.md` (markers), `tests/defects.test.sh`.
- **Why it does not harm.** Deterministic, zero context bytes; the README stays the owner's "look at it with
  your eyes" view — the only part of Hindsight's UI VULYK needs.
- **Cost / risk / measure.** ~40 lines. **Evidence is thin:** YouTube_AI's hand index is 21 of 22 correct two
  days in (`review-take-uncut` missing). Rejected alternative: render on demand with no committed table —
  simpler, but a model that navigates reads the file, it does not run a command. Fixtures: a card absent from
  the table; a row with a stale quote count.
- **Size.** Tier 1. Lowest priority; drop it if the owner wants the minimum.

## 5. Rejected — what must not be taken

| Idea | Why not |
|---|---|
| **Installing Hindsight** in VULYK or shipping it to hosts | A daemon on :9077 + embedded Postgres + `uv` + an extraction LLM on every retain: the runtime service VULYK has never had. It is a second long-term memory beside litopys, against grill 2026-09-21 D9 ("one place answers each question"). Its only lesson carrier is injected prose — the carrier ADR-014 retired after YouTube_AI (a text lesson from 09-17 repeated three videos running; `shoot-step-guesswork` holds 7 quotes as prose). The `claude-code` provider is "personal/local use only", so a team host cannot rely on it. Default is one global bank for all projects. If the owner wants it for a personal, non-VULYK project: `HINDSIGHT_DYNAMIC_BANK_ID=true`, and keep it away from hosts. |
| **Per-prompt auto-recall** (UserPromptSubmit, ≤1024 tokens each) | A per-turn tax; context added on a turn stays in that session's history. (calc) 60 prompts × up to 1 024 tokens ≈ up to 61k resident tokens, against the owner's ≈1% injection ceiling (≈3k in a 300k session). VULYK's delivery is conditional (`defect-intake.sh` one line on a correction signal; `defects-inject.sh` once per card per session+agent). |
| **"A CLAUDE.md that maintains itself"** (auto-rewritten mental model of the owner's preferences) | The post's headline, and exactly what VULYK forbids: always-loaded text may grow only against an owner-signed quote or accepted ADR (`/vulyk-evolve` step 4, ADR-016); whole-document rewrites by a model collapse (ACE, cited in grill 2026-09-27); "never make the text louder". |
| **LLM-paraphrased facts as lesson evidence** | Hindsight's default extraction paraphrases; VULYK's evidence is the owner's verbatim words (ADR-014 D1). P2 takes the boundary, not the paraphrase. |
| **Per-prompt LLM classifier of corrections** | Rejected in ADR-014 (P 0.43 / R 0.58 in the literature, cost per prompt). P2 classifies in batch at distill, where a model already runs. |
| **Confirmation counter as an escalation ladder / capacity limits / auto-delete of beliefs** | ADR-014 rejected the lesson tree with counters; the debt rule is the one mechanism. Cards leave only by the owner's `## Revoked`. |
| **Vector store / pgvector / 4-arm retrieval with rerank** in litopys | Grill 2026-09-21 D5/D15: navigation + grep first, vectors only when the golden-question metric asks. No new evidence: no failing golden question has been traced to lexical search. Hindsight's benchmarks measure conversational QA recall, not a project-history question set. |
| **Async Stop retain every N turns** | litopys already journals every turn with no model and no network, which is cheaper and loses nothing on a crash. |
| **Delta-ops machinery** (id-addressed ops, copy-through, invalid ops → no change) for `librarian`'s `CONSOLIDATED.md` | `memory/learnings` is being retired (ADR-014 supersedes it; 4 real learnings). Law 2. Keep the rule as a design note for litopys **if** its wiki/topic consolidator (roadmap phase 3) is ever built: a model emits ops by id, never re-emits a whole page. |
| **Retraction check: `text` card whose `paths:` match no file** (Hindsight `retractions.py`: absence raises no watermark) | Real idea, no data: VULYK has 0 cards, YouTube_AI uses `area:` not `paths:`, and the RRSI report (§4) already deferred dead-path detection. Revisit when a host with `paths:` cards renames a module. Note the framing differs from RRSI's: not "prune candidate" but "a lesson that can no longer fire". |
| **Global/personal memory bank** | ADR-014 rejected the personal tree in `~/.claude` until hosts show the need; Hindsight's global default is the contamination risk that decision avoids. |

## 6. Top-3

1. **P1** — litopys journal writes harness notices as `## notice`, not `## user` (55% of VULYK's own "user" blocks are subagent reports today); zero tokens, Tier 1, prerequisite for anything that reads the owner's words.
2. **P2** — distiller emits a `## Corrections` section of verbatim owner quotes, refused unless verbatim; VULYK's brief flags unfiled ones — builds the backstop grill 2026-09-27 D4 decided, and measures the intake regex's recall for the first time.
3. **P3** — `defects-check.sh` goes red on a key shared or contained across two cards, so a split class cannot starve the debt counter (3 real pairs in YouTube_AI's 113 keys).

_Status: complete. Nothing in E:/Projects/vulyk or D:/YouTube_AI was changed; `defects-check.sh` was run
read-only in YouTube_AI (it writes only a log under /tmp)._
