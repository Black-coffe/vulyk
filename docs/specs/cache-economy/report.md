# Cache economy: what caching can still save VULYK

Study work, 2026-09-30. Brief: `brief.md`. The owner's scope: save tokens **through caching only**,
without cutting agents, prompts or model rungs.

Evidence on disk:
- `research-official.md`: the mechanics. Covers the API docs, Claude Code docs as raw `.md`, the CHANGELOG and about 150 `anthropics/claude-code` issues.
- `research-github.md`: 50 GitHub queries plus 10 short follow-ups, about 30 repos, and community opinion.
- Local measurement: transcripts in `~/.claude/projects/E--Projects-vulyk`, 2026-09-20..30, 67 sessions, 4,043 API calls, 238 subagent transcripts. The scripts are reproduced in the appendix.

## Verdict

VULYK already has the base right. It routes models through agent frontmatter instead of `/model`, uses `omitClaudeMd`, keeps the constitution lean and runs checkpoints while the cache is warm. Three findings are new:

1. **Per-agent cache TTL exists, and the workers need it.** The key is `experimental: {cacheTtl: 1h}` in agent frontmatter (Claude Code ≥ 2.1.248; installed: 2.1.285). `worker-code` loses its whole cached prefix while `close-story` runs a suite longer than 5 minutes. That happened 23 times in 10 days, about **40% of worker-code's cost** ($5.54 of $13.89 at API prices). A **blanket** 1-hour TTL for all subagents is a net loss, both on our data and in issue #74318.
2. **Our price model is wrong for the models we run.** A cache read costs 0.1× input on Sonnet 5.5, but **0.05× on Opus 5.5 and 0.025× on Fable 5.1**. `docs/token-economy.md` and `scripts/token-report.py` apply 0.1× to every model, so they overstate reads and understate the relative weight of writes. That weight is exactly where caching can still act.
3. **Same-type subagents share only `tools + agent body`.** CLAUDE.md, the environment block, listings and the date sit *after* the unique dispatch prompt (issue #98513, which matches our numbers). So an agent's first call reads about 5k tokens and writes about 12k. Whatever should be shared across spawns must live in the agent body.

Most remaining cache-addressable spend is not in the VULYK machinery. It is in the Queen idling more than 1 hour and in ad-hoc Opus `general-purpose` agents. See "Where the money goes".

## How the cache works (short version)

Full detail with sources is in `research-official.md`.

| Layer | What it is | Who controls it |
|---|---|---|
| API prompt cache | Exact-prefix KV reuse. Order: tools → system → messages. Up to 4 breakpoints, 20-block lookback. 5 min (write 1.25×) or 1 h (write 2×) TTL. A read refreshes the TTL, and the TTL is counted from the **start** of the request. | The harness places breakpoints. We choose the TTL and keep the prefix stable. |
| Claude Code TTL buckets | Main conversation: 1 h on a subscription within plan usage, otherwise 5 min. **Everything else** (subagents, Workflow agents, forks, compaction): 5 min on every plan. | `promptCacheTtl` and `subagentPromptCacheTtl` (≥ 2.1.242), per-agent `experimental.cacheTtl` (≥ 2.1.248), env vars. Precedence: `FORCE_PROMPT_CACHING_5M` > bucket env > bucket setting > **frontmatter** > `ENABLE_PROMPT_CACHING_1H` > default. |
| Sibling sharing | Same model, effort, agent type, tools, output schema and cwd produce the same `tools + system` prefix. Workflow fan-outs stagger siblings by up to 5 s so later ones read the first one's cache. | `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` (default 5000). A cache entry exists only after the first response *begins*. |
| Forks | Inherit the parent's prompt, tools and history, so the first request reads the parent's cache. | `subagent_type: "fork"`. Runs the main session's model. |
| Local harness caches | Read dedup ("File unchanged"), a 15-minute WebFetch cache, the MCP discovery cache, the plugin cache. | Mostly automatic. They save context, not API cache. |
| Semantic / response caches | GPTCache, ModelCache, LiteLLM and similar. Not an Anthropic feature. | Need an API key and a base-URL proxy. |

## Where the money goes (local, API-price equivalent)

These are 10 days of this repo's transcripts priced at the platform page's $/MTok, with model-correct read prices. The owner is on a subscription, so read these as **relative** weights, not a bill.

| Component | $ | Share | Cache-addressable? |
|---|---|---|---|
| Cache reads | 144.94 | 39.6% | No. This is the price of context size. Caching is already the cheap path. |
| Writes: continuing a warm prefix | 75.44 | 20.6% | Only through the TTL choice (1 h costs 1.6× a 5-minute write). |
| Output | 93.41 | 25.5% | No. |
| **Writes: first call of an agent** | 23.32 | 6.4% | **Partly**, through sibling sharing. |
| **Writes: re-writing a lost prefix** | 28.48 | 7.8% | **Yes.** The TTL expired or the prefix broke. |

Lost prefix and first writes by source ($, top rows):

| Source | Lost | First | Note |
|---|---|---|---|
| Queen (`MAIN:opus`) | 14.72 | 7.15 | 7 rebuilds after 72–813 min idle. Already at 1 h TTL. |
| `general-purpose:opus` | 7.18 | 3.68 | Ad-hoc research and board agents with long web turns. A built-in type, so no frontmatter to set. |
| `worker-code:opus` | 5.54 | 0.97 | 23 lost-prefix events after 5–60 min gaps (a suite running inside `close-story`). |
| `cycle-clerk:sonnet` | 0.54 | 1.87 | 65 dispatches. The 13 losses are cheap (small context), so 1 h would *add* cost. |
| `lead-review:opus` | 0.32 | 0.55 | Rarely loses its prefix. |

A what-if per type, with every subagent write at 2× instead of 1.25× and the lost-prefix re-writes removed:

| Type | Now (weighted) | At 1 h | Delta |
|---|---|---|---|
| `worker-code` | 2.18M | 1.28M | **−0.91M** |
| `cycle-clerk` | 1.36M | 1.75M | +0.38M |
| `lead-review` | 1.08M | 1.59M | +0.52M |
| `general-purpose` | 9.66M | 12.57M | +2.92M |
| All subagents, global 1 h | 17.6M | 22.4M | **+4.8M: a loss** |

Caveat: over these 10 days this repo mostly did study and framework work, not large Tier 3 builds. A host like katan, with long suites and more workers, will show a larger worker share.

## Beliefs in our docs that need correcting

| Where | Today | Correct |
|---|---|---|
| `docs/token-economy.md:24` | "A cache hit costs about 0.1×" | 0.1× on Sonnet 5.5; 0.05× on Opus 5.5; 0.025× on Fable 5.1 |
| `docs/token-economy.md:36`, `docs/model-cascade.md:106` | `/effort` keeps the cache on Opus 5.5 and Fable 5.1 | Also Sonnet 5.5. Not on Bedrock/Vertex/gateways or with `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` |
| `docs/token-economy.md:37` | Toggling fast mode re-prefills | Only the **first** fast-mode turn of a conversation misses. Later toggles keep the cache. |
| `docs/token-economy.md:40` | `subagentPromptCacheTtl` raises it | Global. It overrides per-agent frontmatter. The per-agent key is `experimental.cacheTtl`. |
| `docs/token-economy.md:88` | Each subagent writes a fresh cache of its bundle | Only the first of a (type, model, effort, tools, cwd) group within 5 min writes `tools + body`. The CLAUDE.md, environment and date blocks are written on every spawn. |
| `scripts/token-report.py:17,51` | weighted = … + 0.1 × read | Needs a model-aware read multiplier, and ideally a "lost prefix" column. |

## Options, recommended first

1. **Recommended: a per-agent 1 h TTL on the workers, plus a measurement that proves it.**
   - Add `experimental: {cacheTtl: 1h}` to `worker-code` and `worker-test`. Leave clerks, drones, reviewers and seats at 5 min.
   - Make sure that `install.sh` never sets `subagentPromptCacheTtl`, `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL` or `FORCE_PROMPT_CACHING_5M`, and that `/vulyk-status` flags any of them. Each one silently overrides the frontmatter.
   - Why first: it is the only lever where our own data shows a large, targeted loss (40% of worker-code spend). It costs two frontmatter lines, and it is reversible.
   - Rejected: the global setting. Our data shows +4.8M and #74318 shows +8.6%.
   - Open point to settle in the story: whether **Workflow** agents honour a named agent's `cacheTtl`. The docs say nothing either way. Check `ephemeral_1h_input_tokens` in a worker transcript after one Tier 3 run.
2. **Make `token-report.py` cache-true.** Add model-aware read prices (0.05 / 0.025 / 0.1) and three new columns: first-call writes, continuing writes and lost-prefix writes, per agent type and per TTL bucket. `/vulyk-status` and `/vulyk-evolve` then show "cache lost" as its own line. Why: without it, no cache lever is measurable, and the current weights misrank them. It is cache-only by construction: it measures, it does not cut.
3. **Correct `docs/token-economy.md` and `docs/model-cascade.md`** with the table above. Cheap, and it prevents wrong decisions.
4. **Prefix layout for sharing, as an experiment first.** Keep every dispatch of a type byte-identical up to the task text: put the stamp, slug, story path and round last. Dispatch same-type workers in one Workflow wave from the same cwd, and leave the 5 s stagger on. Moving CLAUDE.md content that workers need into the agent body (with `omitClaudeMd: true`) would turn about 12k of per-spawn writes into shared reads. This is second-rank for two reasons. The first-call pool is only 6.4%, and VULYK's own agents hold a small share of it. A host's CLAUDE.md is also project-specific, so it cannot be baked into a shipped agent body without a bootstrap step.
5. **Queen idle over 1 hour.** Already covered by the "checkpoint while warm" rule and by the cache countdown in `handoff.py`. The 7 rebuilds cost $14.72, but most were overnight or multi-hour gaps where `/clear` plus a handoff is the right answer anyway. Rejected: keepalive pings (`ScheduleWakeup`/`/loop` every 55 min). The keepalive plugins' own authors say they hurt on Pro/Max. On a subscription, whether the quota charges a cache read like other tokens is ❓ unconfirmed.

Rejected outright:
- **Semantic and response caches** (GPTCache, ModelCache, semcache, LiteLLM caching): they need an API key and a proxy, and a near-duplicate hit returns the wrong answer for code.
- **Request-rewriting proxies** (`cnighswonger/claude-code-cache-fix`, CtxGuard): they sit in the auth path and patch internals that change every release.
- **Forks as reviewers**: they run the Queen's model and context, which breaks "the family that builds never judges" and the blind court.
- **Pinning an old Claude Code version** for its cache behaviour: the evidence is stale.

Worth a one-off A/B, not a story (the evidence is weak):
- `includeGitInstructions: false`. It is global and also removes the commit/PR guidance, and where the git status sits in the prompt is ⚠️ contested.
- `totalTokensReminder: "off"`. It appears only in issues, not in the settings reference: ❓.

## Candidate stories (for a future `/vulyk-plan`)

- **S1 (Tier 1):** `experimental.cacheTtl: 1h` on `worker-code` and `worker-test`, a `/vulyk-status` warning when a global subagent TTL override is set, and one verification run that reads `ephemeral_1h_input_tokens` from a Workflow worker transcript.
- **S2 (Tier 2):** `token-report.py` gets model-aware read prices and first/continue/lost write columns per agent type and TTL. The `/vulyk-status` and `/vulyk-evolve` lines follow, with a test in `tests/maintenance.test.sh`.
- **S3 (Tier 0-1):** doc corrections in `docs/token-economy.md` and `docs/model-cascade.md`.
- **S4 (Tier 2, after S2 exists):** a prefix-layout experiment for dispatch briefs and same-type fan-outs, measured before and after on one host spec.

## Sources (key claims)

| # | Claim | Status | Sources (fetched 2026-09-30) |
|---|---|---|---|
| 1 | Per-agent `experimental.cacheTtl` (`5m`/`1h`), Claude Code ≥ 2.1.248 | ✅ | code.claude.com/docs/en/sub-agents (frontmatter table) · CHANGELOG.md line "Added `experimental.cacheTtl`…" |
| 2 | Global subagent setting/env overrides frontmatter | ✅ | code.claude.com/docs/en/prompt-caching ("choose the TTL yourself", precedence list) · CHANGELOG ("used when no subagent TTL setting is configured") |
| 3 | Cache read 0.05× on Opus 5.5, 0.025× on Fable 5.1, 0.1× otherwise | ✅ | platform.claude.com/docs/en/build-with-claude/prompt-caching (pricing table and footnotes) · `docs/adr/015-…md` (Opus 5.5 $4 in / $0.20 read, recorded from the pricing page earlier) |
| 4 | Subagents and Workflow agents: 5 min on every plan | ✅ | code.claude.com/docs/en/prompt-caching · local transcripts: 100% of subagent writes in the 5 min bucket (14.1M tokens, 0 at 1 h) |
| 5 | Workflow fan-outs stagger same-prefix siblings, default 5000 ms | ✅ | CHANGELOG ("stagger same-prefix sibling agents…") · code.claude.com/docs/en/workflows (via `research-official.md`) |
| 6 | A blanket 1 h TTL for subagents is a net loss | ✅ | local what-if (+4.8M weighted) · github.com/anthropics/claude-code/issues/74318 (+8.6%, ~1,800 subagents; user measurement) |
| 7 | CLAUDE.md, environment block and date sit after the dispatch prompt, so they are not shared | ⚠️ one wire capture + our numbers | issue #98513 (user capture, 2.1.284) · local first-call read ~5k / write ~12k. Not stated in the docs. |
| 8 | Keepalive pings hurt on a subscription | ❓ | only the plugin author's README (yujiachen-y/claude-code-cache-keepalive) |
| 9 | `totalTokensReminder: "off"` stops conversation re-writes | ❓ | only issues #90018, #96101, #96163. Absent from settings-reference.md and the CHANGELOG. |

Limits:
- Dollar figures are API-price equivalents for a subscription account, from one repo over 10 days.
- The lost-prefix rule is a heuristic: the read falls below half of the previous context after a gap of 5 min or more.
- Behaviour of Workflow agents with a per-agent TTL is not yet observed.

## Appendix: how the local numbers were made

The scripts are in the session scratchpad (not committed): `cache_anatomy.py`, `cache_whatif.py`, `cache_dollars.py`.

- **Input:** every `*.jsonl` under the project's transcript directory, including `subagents/` and `subagents/workflows/`, from 2026-09-20 on.
- **Dedup:** usage records are deduplicated per `message.id`.
- **Agent type:** read from `agent-*.meta.json`.
- **Prices:** $/MTok from the platform prompt-caching page.

S2 would make this a permanent part of `token-report.py`.
