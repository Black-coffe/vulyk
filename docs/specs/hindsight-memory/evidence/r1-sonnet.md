# Board R1 - Sonnet 5.5 - Hindsight -> VULYK

Study work, no repo file changed. Sources read 2026-09-29 (repo HEAD, pushed 2026-09-29).
Hindsight repo = github.com/vectorize-io/hindsight ("H:" below).

## 1. Fact check of the post

| Claim | Confirmed? | Source |
|---|---|---|
| Hindsight >42k stars | Yes: 42,689 | `gh api repos/vectorize-io/hindsight` (2026-09-29) |
| Mem0 66k stars, since 2023 | Yes: 66,320; created 2023-06-20 | `gh api repos/mem0ai/mem0` |
| MemPalace 59k, came out "this spring" | Yes: 59,363; created 2026-04-05 | `gh api repos/MemPalace/mempalace`; its README |
| MemPalace stores verbatim, finds the piece, no call to a neural net | Mostly: "verbatim, local-first, 96.6% R@5 raw on LongMemEval - zero API calls". Retrieval is embedding search (ChromaDB), so "no LLM call", not "no neural net" | github.com/MemPalace/mempalace README |
| Plugin does: before each message recall + inject, after reply extract and store | Yes: hooks.json has UserPromptSubmit -> recall.py, Stop (async) -> retain.py, SessionStart, SessionEnd | H:hindsight-integrations/claude-code/hooks/hooks.json, scripts/recall.py, retain.py |
| Four zones: world facts / agent experience / observations / mental models | Yes in substance. Paper: four networks (world, experience, entity summaries, beliefs). In code fact_type is only `world`/`assistant`(experience); observations and mental models are separate layers | arxiv.org/abs/2512.12818; H:hindsight-api-slim/.../retain/fact_extraction.py:272 |
| Observation carries evidence with exact quotes + confirmation counter, refined not overwritten | Yes, with a caveat: the counter `proof_count` = number of distinct source facts merged (not "times the user confirmed"); evidence = source memories; pre-update snapshot kept in `observation_history` | H:.../consolidation/consolidator.py (docstring, `_apply_update_action`, `_append_observation_history`); docs/developer/observations.mdx |
| Mental model set once by a question, rewritten as it learns | Yes. Now marketed as "Knowledge Pages" (a mental model with defaults) | H:hindsight-docs/docs/developer/mental-models.mdx, knowledge-pages.mdx |
| Own UI | Yes: hindsight-control-plane | H:hindsight-control-plane/ (tree) |
| Four retrieval ways: meaning, exact words, entity links, time | Yes: semantic, BM25/keyword, graph, temporal; RRF fusion + cross-encoder rerank + recency/temporal/proof boosts | H:docs/developer/retrieval.md |
| Install: uv, `/plugin marketplace add vectorize-io/hindsight`, `/plugin install hindsight-memory` | Yes (marketplace "hindsight", plugin `hindsight-memory`, v0.7.5). **Omitted by the post: this plugin is DEPRECATED** - every session start prints "DEPRECATED, replaced by the Coding Agents plugin" | H:.claude-plugin/marketplace.json; claude-code/scripts/lib/upgrade_notice.py |
| `HINDSIGHT_LLM_PROVIDER=claude-code` runs on Pro/Max, personal use only | Yes: README says "personal/local use only"; env name in config.py. Server-side name is `HINDSIGHT_API_LLM_PROVIDER` (plugin maps it) | H:claude-code/README.md:19-21; H:hindsight-docs/docs/developer/models.mdx:530-545 ("local, personal development use only"); scripts/lib/config.py |
| Port 9077, `/health` | Yes: `apiPort` default 9077, README troubleshooting curl | H:claude-code/scripts/lib/config.py:45; README.md:325 |
| `HINDSIGHT_DYNAMIC_BANK_ID=true` for a bank per repo; default one bank for all | Yes: `dynamicBankId` False, `bankId` "claude_code"; granularity agent+project | H:config.py:51-54; README.md:206-212 |
| `uvx hindsight-embed control start` opens UI | Not confirmed in the plugin/coding-agents README (not found by grep); plausible, not verified | - |
| "Agent really changes behaviour after your corrections" (the post's main sales point) | **Not confirmed.** Nothing in the repo measures it. Corrections are only a word inside the extraction prompt ("world = preferences, rules, corrections, constraints"); no correction-detection, no "did the mistake repeat" metric. Benchmarks (LongMemEval 91.4%, LoCoMo 89.6%) test question answering over old chats, self-reported by authors (Virginia Tech / WaPo co-authors reproduced) | H:fact_extraction.py:272,1085; arxiv 2512.12818 abstract; H:README.md:44-50 |

## 2. How Hindsight actually works (from source)

1. **Deployment.** A Python server (FastAPI + PostgreSQL/pgvector, embedder + cross-encoder reranker, LLM for extraction). The Claude Code plugin starts a local daemon `hindsight-embed` (port 9077) via `uvx`; hooks are thin Python clients (`claude-code/scripts/*.py`). Alternatives: Docker, Helm, cloud.
2. **Hooks (old plugin, `claude-code/hooks/hooks.json`).** SessionStart (5 s), UserPromptSubmit -> `recall.py` (45 s), Stop -> `retain.py` (async, 15 s), SessionEnd (10 s). All fail open, exit 0.
3. **Recall injection (`recall.py`).** Query = the prompt (optionally last N turns, capped 800 chars). Calls `recall` with `max_tokens=1024`, `budget=mid`, `types=["observation"]` (default: only consolidated beliefs, so one belief is not shown 5 times). Result wrapped in `<hindsight_memories>` + preamble + current time and returned as `hookSpecificOutput.additionalContext`. Every prompt, so ~1k tokens each turn when anything matches. Optional `recallMinScores` floors; last injection saved to state for PostCompact re-injection.
4. **Retain (`retain.py`).** After each reply (every 10 turns by default, `retainMode=full-session`, sends only the not-yet-sent suffix as a new chunk-document), POSTs the transcript with tags/metadata. Roles user+assistant, tool calls off by default. The server, not the hook, does the LLM work.
5. **Fact extraction (`engine/retain/fact_extraction.py`).** An LLM turns text into structured facts: what/when/where/who/why, entities, temporal fields, `fact_type` = `world` (about user/world, "including preferences, rules, corrections, constraints") or `assistant` (what the agent did). Extraction modes concise/verbose/verbatim/chunks. Per-bank "mission" biases what is kept.
6. **Consolidation (`engine/consolidation/consolidator.py`, `prompts.py`).** Background job after retain. For each batch of new facts it recalls related existing observations and asks an LLM for JSON `{creates, updates, deletes}`; **every entry needs a `reason`** (audited to catch duplicate creates). Rules in the prompt: prefer UPDATE over CREATE; one observation = one facet; match by entity not topic; state change -> update concisely; cascade; preserve history (delete only when superseded); **no arithmetic or deductions**; one update per observation id.
7. **Provenance.** Observation row = text, embedding, `source_memory_ids`, `proof_count = len(distinct source ids)`, temporal span (earliest start / latest mention). Before each update the old text is snapshotted into `observation_history` (capped). `source_fact_ids` must be UUIDs copied from the input - the model cannot invent a source.
8. **Second-pass dedup.** After create/update, the new text is embedded and compared to nearest observations (cosine >= 0.97 default); a focused 1-by-1 LLM check decides merge or keep (respects a number/negation/entity difference).
9. **Contradictions** are not overwritten: "Alice works at Meta (previously thought Google)"; the user's React->Vue switch keeps the journey. Raw facts always stay.
10. **Mental models / Knowledge Pages (`docs/developer/mental-models.mdx`, `knowledge-pages.mdx`).** A stored question; its answer is synthesised from observations, refreshed only when something *in its scope* changed (cron or after consolidation), updated **incrementally** (only the implied changes applied, the rest physically untouched, because an LLM told to "preserve" text still drifts), keeps previous versions and the fact/observation ids it stood on. Pages never read other pages (no feedback loop). Projected to disk as real markdown with `hindsight fs mount`.
11. **Retrieval (`retrieval.md`).** Four arms in parallel (semantic, BM25/tsvector, graph over entities/causal links, temporal spreading) -> RRF (k=60) -> top 300 -> cross-encoder -> multiplicative boosts: recency +-10%, temporal +-10%, `proof_norm = clamp(0.5 + ln(proof_count)/10)` up to +5% -> pack by token budget (skips a long item, keeps packing).
12. **Successor plugin (`hindsight-integrations/coding-agents`).** Claude Code plugin is deprecated in its favour. Differences: 3 hooks + MCP tools + a companion skill; **injects once, on the session's first prompt** (`autoInject: reflect|pages|recall|none`); five seeded knowledge pages per repo (Component map, Core concepts, Conventions, Key decisions and rationale, Initiatives), each pinned to a `knowledge:*` tier tag; auto-seed from last 300 commits (`gitIngest: message|full`); `optInOnly` (inert outside listed repos); budget caps (`surveyBudgetUsd` 2). Its docs argue: search "is a tool an agent *chooses* to call... retrieval it didn't ask for tends to derail it" (knowledge-pages.mdx).
13. **Memory Defense** (`docs/developer/memory-defense`): 45 regexes redact secrets/PII from retained text before storage; off by default.
14. **Cost/moving parts.** Postgres, embedding model, reranker, LLM calls on every retain and every consolidation batch, cron page refreshes (each page = one LLM synthesis per refresh), Rust toolchain needed on macOS (litellm dependency). Claude-code provider bills against the owner's Claude subscription.
15. **Benchmarks.** Paper 2512.12818: LongMemEval 91.4%, LoCoMo 89.6% - long-conversation QA. No experiment on "repeats fewer mistakes after correction".

## 3. VULYK today vs. Hindsight

**Different problems.** Hindsight = a server that turns *every conversation* into recallable facts and beliefs about a user/project (LLM on every retain, ranking on every recall). VULYK = *prescriptive* memory: owner rejections become forbids with a check, delivered by hooks at the moment of action. The post sells the first as a cure for the second's problem; nothing in Hindsight's repo measures that cure.

| Hindsight mechanism | VULYK counterpart | Who is stronger |
|---|---|---|
| Recall injected before each prompt (`recall.py`) | `defects-inject.sh` (PreToolUse, once per session+agent, 4000-char budget, never-lines only), `defect-intake.sh` (UserPromptSubmit, human text only), `session-start-brief.sh` | VULYK on cost and precision (path/command match, once). Hindsight's own successor moved to first-prompt injection + agent-pulled search and says unasked retrieval "tends to derail" |
| Observation = deduped belief + evidence quotes + `proof_count` | A defect card = one class, verbatim owner quotes (`## Owner quotes`), quote-line count = the counter; debt rule at >=2 (`docs/defects/README.md`, `scripts/defects-check.sh`) | VULYK: quotes are the owner's exact words, not LLM-extracted facts; the count drives a *failing gate*, Hindsight's only nudges rank by +5% |
| Refine, don't overwrite; history snapshot (`observation_history`) | Cards are git files; a repeat is a new quote line, never an edit; `## Revoked` with owner's words; git holds history | VULYK (authority = owner, history = git blame) |
| Consolidation with `reason` per op, ids validated | `librarian` GC pass + `Delete:` list (ADR-017), `CONSOLIDATED.md` cap 40 | Hindsight has the stricter output contract, but VULYK's writer is one agent, one file, in git, human-reviewed |
| Mental model / Knowledge Page = self-rewriting standing answer | `CLAUDE.md` (owner-signed only, byte cap test), `memory/map`, `docs/wiki`, ADRs, learnings promoted by `/vulyk-evolve` changesets the owner merges | VULYK by design: a self-rewriting always-loaded doc is the thing Law/ADR-013/016 forbid |
| Five seeded pages (component, concepts, conventions, decisions, initiatives) | map / wiki / rules / ADR / specs | Overlap almost 1:1. VULYK's ADR harvest (3-part test, "no recorded reason = report a gap, do not write") is stricter than an LLM-written "why" page |
| Staleness-aware reads, scoped refresh | "Hint, not truth", `last-verified`, `.stale` flag, per-module map refresh | Overlap |
| Session capture (Stop hook -> transcript -> server) | litopys: raw journal without a model, Sonnet distills on demand, golden questions + baseline (grill 09-21 D1..D15) | VULYK/litopys on cost cap (<=5%), privacy (git-ignored by default), no server |
| 4-arm retrieval + RRF + cross-encoder + boosts | grep + navigation, vectors only if golden-question metric says so (grill 09-21 D5, D15) | Hindsight is richer; VULYK has no evidence yet that it needs it (2 chronicle records exist) |
| Memory Defense: 45 regexes redact before store | `scripts/redact.sh` (hosts' briefs, handoff, litopys via its C16 lookup) | **Hindsight has more patterns** - measured below, P2 |
| Opt-in only / per-repo bank / worktree resolve | hooks exit silently without `docs/defects/`; litopys root = `CLAUDE_PROJECT_DIR`, which Claude Code documents as staying at the session's project root even inside worktrees (code.claude.com/docs/en/hooks) | Overlap; the worktree worry is a non-issue (checked) |
| Benchmarks | golden questions (`docs/chronicle/golden-questions.md`), council numbers with n | Neither measures "did the mistake repeat" |

**What Hindsight has that VULYK lacks** (each becomes a proposal only if it survives the concept test):
1. Every memory op carries a `reason` and may cite only ids that exist (validated) - a hallucinated source cannot be stored.
2. A recurrence view: `proof_count` and history make "how often did this come back" a query. VULYK's index has a "last quote" column but no "came back after the fix" number.
3. Broader secret-pattern set (45 labels).
4. Out-of-band capture that does not depend on the live session's judgement (VULYK's intake hook only *reminds*; grill D4 promised "litopys picks up the rest", which is not built - checked: litopys agents/skills/bin have no correction handling).

**A defect found in VULYK's own delivery while comparing** (new evidence, not from Hindsight): the only host with a real library, `D:/YouTube_AI` (VULYK 0.21.1), has 22 cards; **all 22 use `area:` and none has `paths:`** (`contract.md:22`: `area:` "ignored by VULYK logic"). `defects-inject.sh` matches only `paths:`. So its 9 `text` cards (32 owner quotes, one class alone has 13) are never delivered, and `defects-check.sh` says nothing about it. Recall coverage is the whole product of a memory system; VULYK does not measure it.

## 4. Proposals

Order = priority. No proposal grows CLAUDE.md, adds a service, or adds a model call to a hook.

### P1. Delivery audit: a `text` card that no hook can ever deliver is a defect (Tier 1)
- **Borrowed:** the idea that memory is only as good as what reaches the agent. Hindsight tracks what it injected (`last_recall.json`: `result_count`, `saved_at`); VULYK has no such accounting.
- **Evidence (new, on disk):** YouTube_AI: 9 of 9 `text` cards have no `paths:` (all 22 cards use the legacy `area:`, which VULYK ignores), so `defects-inject.sh` can never fire for them: 32 owner quotes undelivered, `shoot-step-guesswork` alone 13. Two of them (`private-in-frame`, `review-take-uncut`) also have no `check:`. `defects-check.sh` printed only "RED: 1 new debt" for something else.
- **Where (VULYK owns):** `scripts/defects-check.sh` (audit + gate): a `text` card whose `paths:` is empty or absent is "undeliverable", red when new (same git-blame rule as debt), an "old" line otherwise. One sentence in `docs/defects/README.md`. `tests/defects.test.sh` fixtures: original = `area:`-only card; neighbours = `paths: []`, blank `paths:`; a cmd-only card must stay green. The installer/upgrade diff may propose a `paths:` for a legacy `area:` (never auto-applied).
- **Concept fit:** Law 6 (a check that only warns is not a check; a repeated class with no delivery and no check is debt), ADR-014 D2/D3/D6 (text cards are pushed before the action: a card that cannot be pushed breaks D6). Adds nothing to per-turn context.
- **Cost/risk:** about 20 lines of python in an existing script, 0 tokens. Risk: a pre-existing library goes red once on upgrade, hence "new only, old reported"; deliberately read-only cards must be `revoked` or get `paths:`.
- **Measured by:** run on YouTube_AI: 9 undeliverable now, 0 after the host adds `paths:`. Later: share of `text` cards injected at least once (the inject state file under `.claude/state/defects/` already records it).

### P2. Widen `scripts/redact.sh` with Hindsight's secret-pattern list (Tier 1)
- **Borrowed:** data, not mechanism: the 45 labels of Memory Defense (`hindsight-docs/docs/developer/memory-defense/index.md`).
- **Evidence (measured now, `printf 'x <token> y' | bash scripts/redact.sh`):** 5 of 15 sample shapes masked (AKIA, AIza, `sk-ant-`, `ghp_`, `postgres://user:pass@`). 10 pass through: GitLab `glpat-`, npm `npm_`, PyPI `pypi-`, HuggingFace `hf_`, Groq `gsk_`, SendGrid `SG.x.y`, Stripe `sk_live_`, Slack webhook URL, **Telegram bot token** (`123456789:AAA...`, the owner's own stack), credit-card digits.
- **Where (VULYK owns):** `scripts/redact.sh`. `handoff.py` keeps its minimal built-in subset (by its own comment). litopys reads the host's `scripts/redact.sh` first (its C16 lookup, `bin/litopys:73-88`), so committed chronicle records get the fix for free. Tests: one fixture per pattern plus neighbour negatives that must NOT be masked (a git sha, a 30-char base64 word, `sk-learn` style prose).
- **Concept fit:** constitution "Secrets: briefs and the handoff dump pipe through redact.sh, a seatbelt". Bash + sed only, no dependency.
- **Cost/risk:** about 12 `-e` lines; the script already self-tests the sed dialect. Risk: over-masking hurts brief readability, so prefix-anchored patterns with length floors only, no entropy rule. Skip PII (SSN, cards) unless the owner wants it: locale-bound and false-positive prone.
- **Measured by:** the 15 samples go from 5/15 to 15/15 (cards excluded if skipped); re-redacting a sample of real briefs/handoffs shows 0 new false masks.

### P3. litopys decisions carry a verbatim evidence quote, validated against the raw journal (Tier 1, litopys repo)
- **Borrowed:** the observation data shape "claim + exact quote + source ids that must exist" (`consolidator.py`: `source_fact_ids` must be UUIDs copied from the input, every op has an audited `reason`; observations.mdx: "grounded, with exact quotes").
- **Where (litopys owns; VULYK is a consumer):** `agents/distiller.md` body template: a `## Decisions` line may end with `-- «owner's exact words»` (<=160 chars). `bin/litopys distill record` rejects the record (per journal, as it already does on a filter failure) if a quoted span is not a substring of the journal it came from. Deterministic, $0. `/litopys:recall` can then answer "what did the owner decide about X" with proof.
- **Why it fits:** VULYK's currency for owner intent is the verbatim quote (Law 6, ADR-014, evolve's "owner-signed evidence"). Today a chronicle decision is a model paraphrase of unknown fidelity (the two records on disk carry no quote). Grill 09-21 D1 (raw first, model judges at boundaries) and D5 (grep first) are unchanged; grep now hits the owner's real words.
- **Cost/risk:** about +40 tokens per decision in distill output, inside the <=5% cap (already measured in the jsonl). The journal stores prompts verbatim but assistant text only as the last message per Stop, so quotes are owner prompts: say so in the template. The distiller must omit a quote it cannot find; the validator enforces it.
- **Measured by:** golden questions gain "answer carries a verifiable quote"; validator reject rate over the first 20 distills (above 30% means the template is wrong).

### P4. Filed-rate audit of owner remarks: replay the intake lexicon over closed journals, $0 (Tier 2)
- **Borrowed:** the principle behind Hindsight's out-of-band `retain`: capture must not depend on the live session's judgement. Only the cheap deterministic half.
- **Status:** grill 2026-09-27 D4 already decided "regex + session judgement, litopys picks up the rest", and its assumption ledger lists "regex catches most owner remarks" as unchecked. The litopys half is not built (grep of litopys agents/skills/bin/hooks: no correction handling). So this builds a decided item and takes its first measurement; it is not a new idea.
- **Where (VULYK owns; reads `.litopys/raw/*.md` or `.claude/handoff/` prompts when present):** `scripts/defects-check.sh --intake-audit` or a `/vulyk-evolve` harvest read. Run the same lexicon as `defect-intake.sh` (reuse its strip function, do not fork it) over human prompts of the last N closed journals and list remarks that appear in no card's quote lines (whitespace-normalised substring). Output: `fired 14, filed 9, unfiled 5` plus the lines. Never blocks, never edits a card (the Queen files the quote next session).
- **Concept fit:** ADR-014 D5 (intake reads only the human), no model call, private journals stay local.
- **Cost/risk:** about 60 lines; needs litopys (else falls back to handoff prompts, weaker). Lexicon false positives inflate "unfiled": it is a rate with n beside it, never a gate (RRSI report §4: counters of 0-2 are noise). If n stays under 10 after a month, delete it (self-evolution "Sunset").
- **Measured by:** filed-rate over 4 weeks on YouTube_AI and VULYK; the decision it feeds is whether an LLM backstop is ever needed (today: no evidence it is).

### P5. Recurrence report: quotes that arrived after a card reached `block` (Tier 1, report first)
- **Borrowed:** what Hindsight's counter makes possible and its docs never do: "how often did it come back". Their `proof_count` is a rank nudge (+5% max); here the same number is a repair signal.
- **Where (VULYK):** `scripts/defects-check.sh` audit output only. Per class: quotes total / after the effective-block commit, using the git-blame time the script already computes for debt (`blame()`). A block card with a quote newer than its block commit means the check missed a neighbour form: name it, and the Queen adds the fixture (ADR-014 D2). Promote to red only at the first real escape (Law 2: no rule for a case never seen).
- **Evidence, honest:** 0 escapes observed (the gate is two days old on YouTube_AI). One adjacent case: `owner-does-prep` got its 5th quote on 2026-09-29 while `text` and became `block` the same day, the debt rule working as designed. The RRSI report deferred "prune by fired-and-caught" (no catch log, zero cards); this differs (no pruning, no catch log) but shares the small-n caveat.
- **Cost/risk:** about 25 lines, 0 tokens. Keep it out of `/vulyk-evolve` until n exists.
- **Measured by:** it prints per host; the first non-zero "after block" is the trigger to make it red.

## 5. Rejected (must not be taken)

| What | Why not |
|---|---|
| **Install Hindsight** (daemon, Docker, cloud) | A server plus Postgres/pgvector, embedder, reranker and an LLM on every retain and consolidation: breaks "bash + markdown + hooks, no server, no DB" (Law 2). Its LLM calls run outside VULYK's model floor and telemetry (`llmModel` is free config). The `claude-code` provider uses the owner's personal subscription, "local, personal development use only" (README + models.mdx): a framework shipped to 16 hosts cannot depend on it. The Claude Code plugin in the post is **deprecated** by its authors (`upgrade_notice.py`). Rust toolchain needed on macOS. |
| **Per-prompt auto-recall into context** (`recall.py`, 1024 tokens default) | An `additionalContext` injection stays in the transcript and is re-sent every later turn; owner rule: injection <= ~1%, once per session (grill 09-27 D15). Hindsight's own successor stopped doing it per prompt and argues unasked retrieval derails agents. |
| **Self-rewriting mental model, "CLAUDE.md that behaves on its own"** | Base prompts must not grow and owner authority is the point (Law 6, ADR-013 D7, ADR-016 byte cap). Hindsight's docs admit an LLM told to "preserve" text still drifts. |
| **Auto-merging contradictions into narrative** ("was X, now Y") | Fine for facts about a person, wrong for prescriptions. A VULYK rule ends only by the owner's words in `## Revoked` (D13). |
| **Confirmation counters, lesson trees with escalation** | Already rejected (grill 09-27 D6/D8/D9, ADR-014 "Rejected"): quote lines are the counter and debt is the one mechanism. P5 reuses it and adds no tree. |
| **LLM extraction of every conversation as correction detector** | Cost on every turn; Hindsight's extractor has no correction type (one word in the `world` description) and no repeat metric; literature P0.43/R0.58 (ADR-014). Regex + session judgement + P4 stays. |
| **Vector store, graph, cross-encoder (4-arm retrieval)** | Grill 09-21 D5/D15: grep first, vectors only if golden questions fail against baseline. Two chronicle records exist, nothing to fail yet. If it ever does, the recipe worth reading is RRF k=60 over keyword+dense with +-10% recency/proof boosts, not a server. Their benchmarks (LongMemEval 91.4%, LoCoMo 89.6%) are self-reported conversation QA and do not test "stops repeating a mistake". |
| **Knowledge pages seeded from git history by an LLM** | A second source of truth beside map/wiki/ADR, with invented "why" (VULYK's ADR harvest refuses an unrecorded reason). litopys backfill (grill 09-21 D8) is the planned, source-labelled version. |
| **Second-pass embedding dedup of cards** | Looks like a gap, is not yet: 22 cards in the only library, at most one shared key phrase (`не дышит`, speech-cut vs breath-cut, by eye), no split-quote case seen. Revisit at the first observed split. |
| **`reason` on every op + delete-by-cited-id for `librarian`** | Sound rule, no incident: the first real `/vulyk-gc` run (2026-09-29) worked. Adopt at the first wrongly deleted learning. |
| **Worktree-resolving project key** (`resolveWorktrees`) | Checked, not needed: `CLAUDE_PROJECT_DIR` stays at the project root inside worktrees (Claude Code hooks docs) and litopys uses it first. |

## 6. Top-3

1. **P1** delivery audit: 9 of 9 text cards in the only real host cannot be delivered today; cheapest fix, real evidence, pure Law 6.
2. **P2** `redact.sh` from Hindsight's pattern list: 10 of 15 common token shapes (incl. Telegram bot tokens) pass unmasked today; also protects litopys records.
3. **P3** evidence quotes validated against the raw journal in litopys decisions: the one Hindsight data shape that improves VULYK's currency (verbatim owner words) with no server. P4 and P5 wait for data.

## Not verified
`uvx hindsight-embed control start` (not found in the READMEs); independent reproduction of the benchmarks (README claims Virginia Tech / Washington Post reproduction, not checked); the `claude -p --max-budget-usd` flag (only quoted from Hindsight's README); whether YouTube_AI has another delivery route for its `area:` cards (its hooks dir shows none). I ran `defects-check.sh` read-only against D:/YouTube_AI (it executes that host's `check:` commands); no file in E:/Projects/vulyk was changed.
