# Research: Cache Tax, Savvy Progress, Reflect (2026-11-05)

Method: shallow clones (read only, nothing run) in `C:/Users/Andrei/AppData/Local/Temp/claude/mods-research/`; `gh api` for repo meta; raw `.md` of official docs via curl (not WebFetch summaries). Repo code = T1 for what a mod does.
Official sources: [CC-PC] https://code.claude.com/docs/en/prompt-caching.md (fetched 2026-11-05) · [PRICE] https://platform.claude.com/docs/en/about-claude/pricing.md (fetched 2026-11-05) · [VULYK] docs/specs/cache-economy/research-official.md (2026-09-30), docs/pulse.md, .claude/hooks/defect-intake.sh.

## Repo meta (gh api, 2026-11-05)
| | stars | license | created | last push | version |
|---|---|---|---|---|---|
| karanb192/cache-tax | 348 | MIT | 2026-09-18 | 2026-11-05 | plugin.json 2.4.0 |
| JohnnyVizz/claude-kit (plugins/savvy-progress) | 351 (whole kit) | MIT | 2026-10-04 | 2026-10-12 | 1.2.1 |
| BayramAnnakov/claude-reflect | 1919 | MIT | 2026-01-03 | 2026-10-03 | 3.3.1 (mod subpackage `reflect-mod`) |

All three are mods on the new in-process mod API (`$.model.fork`, `$.ui.ask`, `on('prompt.submit')`; Claude Code 2.1.286/2.1.287+). Reflect also ships an older Python hook plugin.

## 1. Cache Tax (karanb192/cache-tax, `hooks/register.ts`, one file ~51 KB + 153 KB tests)

**Surfaces:** mod hooks `prompt.submit` (guard), `turn.step`/`turn.complete` (usage), `session.start/end/compact`, `command.run` for `/keepwarm` and `/cache-tax`, `ui.render AbovePrompt` (status row with cube, refresh 60 s), `$.ui.ask` dialog, `$.clock.after`, `$.store`. Terminal and Desktop Code tab; image only in Ghostty/kitty.

**How it knows "cold":** a local clock only, no server check. `const TTL_MS = 60 * 60 * 1000` and `isCold = s.lastRequestAt > 0 && !s.compacted && now - s.lastRequestAt >= TTL_MS`. `lastRequestAt` is stamped at main requests. README: "estimates, not a live server cache check". Assumes 1 h only; on 5-min billing (API key, usage credits) the user must set `promptCacheTtl: "1h"`, otherwise the mod says warm after the cache is gone. Native alternative exists: statusline `prompt_cache` object (`warm`, `expires_at`, `recache_tokens_if_cold`) and `/usage` "Prompt cache (main)", CC >= 2.1.251 ([CC-PC]; VULYK research Q2).

**Guard:** only when context >= `BIG_TOKENS = 50000` and cold. `$.ui.ask` "Send anyway / Don't send"; dismissed or `-p` run: drops the message once, resend goes through (acked key in `$.store`). Modes `warn` / `refuse` / `refuse <usd floor>`. Unattended prompts (task-notification, scheduled, peer) are never dropped, only priced in a log line. If the hook throws the message goes through.

**Price:** `coldUsd = s.ctx * price[1] / 1e6`; `ctx` = engine's live window figure (last response input + cache read + cache write + output); `price[1]` = 1 h cache WRITE rate from a hard-coded `PRICES` table (`['fable-5-1', 0.25, 20, 50]`, `['sonnet-5-5', 0.1, 4, 10]`, `['opus-5-5', 0.2, 8, 20]` ...: read/write/output). I compared every row to [PRICE]: all match (Fable 5.1, Opus 5.5, Opus 5, Sonnet 5.5, Sonnet 5, Sonnet 4.x, Haiku 5.5 incl. >100k tier, Haiku 4.5, Haiku 3.5, Opus 4/4.1 $15/$75 via regex). Read multipliers 0.025x (Fable 5.1) and 0.05x (Opus/Sonnet 5.5) agree with VULYK's research. Dollars are API list price, "not extra subscription charges"; README: "how a cache read weighs against the 5-hour and weekly limits is not documented anywhere I could find". So "costing limit" is translated to dollars, not plan-limit percent. The count is a self-admitted upper bound (ctx includes last output): example 330,316 tokens / $6.61 estimated vs 314k / $6.28 actual write.

**/keepwarm:** timer inside the CC process via `$.clock.after` (no polling). After `PING_AFTER_MS = 50 * 60 * 1000` idle it calls `$.model.fork({ prompt: 'Reply with the single word: warm' })`, a tool-less fork over the session transcript (a fork inherits parent system+tools+history, [CC-PC]). One ping per 50 min; window default 6 h (`/keepwarm 90m`, `always`; Auto keepwarm, on by default, arms 3 h after any paid cold write). After each ping it reads usage and stops if `cache_read == 0` or `cache_creation >= 0.1 * cache_read`. Retries 1/2/4 min on 429/5xx. Ping cost = `read*r + creation*w + input*w/2 + output*out`, output uncapped ("a model at high effort may think before it says warm").
- Cheaper? The mod computes break-even `floor(write/read)` pings = one cold write (Fable 5.1: 20/0.25 = 80 pings, ~66 h at 50 min). A 6 h window = ~7 pings (~$0.35 on 200k Fable context) vs $4.01 cold write, at list prices. It loses if the user never returns inside the window, and auto-arm spends tokens unasked.
- Bucket tension: [CC-PC] puts forks in "Everything else" (5 min on subscription). README admits this and cites one transcript run (Fable 5.1, subscription, 2026-09-19: ping at min 50 read 157k; message at min 62 read 156,886 from cache; CC's countdown reset to 58 min). "One run, one configuration". The mechanism is most plausibly that a cache read refreshes the entry ([PRICE]: "cache hits and refreshes"), but only empirically shown for the fork.
- Hard dependency: 1 h main TTL. On 5-min paths a 50-min timer protects nothing (README says so).

**Model call / disk:** model calls only for pings (token cost); guard, status, cold detection cost 0. Disk: `$.store` keys (`deadline`, `every`, `guard`, `always`, `acked`) per session id; no project files. MIT, threat model in README, very active (push on the day of research).

**Weaknesses:** (1) clock-only coldness: prefix invalidation (model switch, tool-set change, CC upgrade, [CC-PC]) makes a send expensive while the mod shows warm; a warm ping "proves the cache was warm then". (2) 5-min billing users get a wrong clock unless they set the TTL. (3) token count is an upper bound. (4) USD list price; subscription-limit effect unknown (mod says so). (5) Auto-arm 3 h default. (6) Guard only at >= 50k ctx. (7) Overlaps native `prompt_cache` statusline fields. (8) No source that a fork ping weighs the same on plan limits as a cache read.

### Claims vs facts (Cache Tax)
| Claim | Grade | Sources |
|---|---|---|
| Subscription keeps the conversation in cache ~1 h | ✅ main conversation within plan usage; 5 min on API key/credits; subagents/forks 5 min | [CC-PC] "Which TTL each request gets" · 2026-11-05 · https://code.claude.com/docs/en/prompt-caching.md ; register.ts `TTL_MS` |
| A message after that re-reads the whole dialog, costing limit | ⚠️ re-write at write rate confirmed; "costing limit" not documented (mod itself says so) | [CC-PC] cache lifetime · 2026-11-05; [PRICE] 1 h write 2x · https://platform.claude.com/docs/en/about-claude/pricing.md · 2026-11-05; cache-tax README "Cost and the plan-limit question" |
| Mod catches that moment and shows the price so you decide | ✅ `prompt.submit` guard + `$.ui.ask`; ctx >= 50k; price = ctx x 1 h write rate, upper bound, clock estimate | register.ts; README |
| /keepwarm keeps cache warm while away | ✅ mechanism (50-min fork ping); proof = one author run; fork bucket is 5 min per docs | register.ts `ping`; README Limits; [CC-PC] |
| and costs much less | ⚠️ at list prices yes (Fable 5.1: 80 pings = 1 cold write); plan-limit cost unverified; loses if you do not return or on 5-min billing | register.ts `ping`, break-even; [PRICE] |

## 2. Savvy Progress (JohnnyVizz/claude-kit/plugins/savvy-progress, `hooks/register.tsx` 60 KB)

**Surfaces:** `ui.render AbovePrompt` (progress bar + crew button), a side `Pane` (`/agents-info` toggle/open; auto-opens on `savvy-*` worker spawn, or any subagent with `autoOpen: any`), `$.tool.register` of two tools `progress` and `step`, hooks `agent.spawn`, `turn.step`, `turn.complete`, `tool.call`, `$.clock.every(1000)` for running timers. Languages en/ru/he. Terminal mod.

**Where progress comes from:**
1. Plan-level bar ("accepted tasks of planned"): the orchestrator model must call `mcp__savvy-progress__progress` (title/total/done/phase/tasks). Built for the author's `/savvy-flow` skill; main session only. Safety net: spawning a `subagent_type` starting `savvy-` bumps a running counter.
2. Per-agent "how far": the worker must call `step({done,total,note})`, self-reported by the model; `agent.spawn` appends `STEP_BRIEF` to `savvy-*` prompts lacking it. Agents that do not report show only context fill (`contextTokens` = last request input + cache read + cache write + output, vs `windowOf(model)`: 1M, 200k for Haiku 4/claude-3). So "how far it got" is real progress only for compliant `savvy-*` workers; for other subagents it is context fill.

**Cost:** from `turn.step` usage per `agentId`: `costUsd += costOf(model, usage, true)` with hard-coded `PRICES` (`[/(fable|mythos)-5-1/, [10, 50, 0.25, 20]]`, `[/sonnet-5-5/, [2, 10, 0.1, 4]]` ...: input/output/read/write); cache writes always at the 1 h rate (README: 5-min writes overestimated). Rows match [PRICE] for current models. Gaps: `/opus/` catch-all is $5/$25, so retired Opus 4/4.1 ($15/$75) are underpriced 3x; unknown model falls to `[4, 20, 0.2, 8]`. README: "rough estimate ... not a bill"; on subscription dollars are a yardstick.

**Model call / disk:** no model call of its own, but the `step`/`progress` tools sit in every agent's tool list (`isDeferred: false`) and each `savvy-*` worker gets an extra brief line, so a few tool calls and schema tokens per worker. State kept in plugin `atom`s; no project files. MIT, v1.2.1, repo 9 days old at last push, solo author; star count is for the whole kit (also contains `session-band`: cache countdown band with a notify-before-expiry, not read here).

### Claims vs facts (Savvy Progress)
| Claim | Grade | Sources |
|---|---|---|
| Progress bar | ✅ but fed by the model calling `progress` (made for /savvy-flow); otherwise only a spawn counter | plugin README; register.tsx `tool.call` handlers |
| Panel showing each subagent | ✅ `agent.spawn` + `turn.step`; any subagent only with `autoOpen: any` or `/agents-info` | register.tsx |
| How far it got | ⚠️ self-reported `step` for savvy-* workers; else context fill | register.tsx `STEP_TOOL`, `agent.spawn` |
| Roughly what it costs | ✅ as an estimate; table matches [PRICE] for current models; 1 h write assumed; old Opus underpriced | register.tsx `PRICES`; [PRICE] · 2026-11-05 |

## 3. Reflect (BayramAnnakov/claude-reflect): two packages

### 3a. reflect-mod (`mod/hooks/register.tsx`, "early access"), the one the post describes
- **Trigger:** `prompt.submit` with cheap pre-filter: human origin (`composer`/`bridge`), not a slash command, not a TRIVIAL ack (en/ru regex), <= 500 chars (`MAX_PROMPT`), no secret-shaped text. Queued, then `$.clock.after(0, drain)`.
- **Detection is a model call, not regex:** `$.model.complete({ model, system: SYSTEM, prompt: checkPrompt(text, await lastReply($), root), maxTokens: 300, timeoutMs: 30000 })` with `model = 'haiku'`, per eligible prompt. Answer `{is_rule, rule, scope, confidence}`; kept only if confidence >= 0.7, one line <= 200 chars, no secret. SYSTEM text separates reusable rules from one-off redirects ("wrong file", "try again", "stop"). Any language. Token cost: one small Haiku request per short non-trivial prompt (README: counts toward usage like any request); the mod does not meter it.
- **UI:** band above the prompt with "Save to ./CLAUDE.md" / "Save to ~/.claude/CLAUDE.md", "Global instead" / "This repo instead", Edit (puts `remember: <rule>` in the prompt box), Skip. So several buttons, not one. `remember: <rule>` skips the model.
- **Write:** `withRule()` appends a bullet inside a marked block (`<!-- claude-reflect: learned rules ... -->` / `## Learned rules` / `<!-- end claude-reflect -->`) in CLAUDE.md (project or global), re-reading the file just before the write; broken markers = refuse. The rule also goes into the current session's system prompt. Not memory, not a skill. Rule text is the model's one-line English paraphrase (<= 25 words), not the user's words.
- **Dedupe/review:** queue rows merged by ordered word-pair Jaccard `SAME = 0.6` with a count; a bullet already in the file with similarity >= 0.8 is not added; the human click is the review step. Queue in plugin `$.store` (max 300; prompt text not stored). Known race: two sessions saving to one CLAUDE.md can lose a bullet (README).
- **Limits:** Claude Code 2.1.286+ mods; README warns an older running session can switch mods off in `~/.claude.json`. Classifier sees only the prompt (<= 500 chars) and last 1200 chars of the assistant reply; a wrong verdict is possible both ways.

### 3b. Python plugin (hooks.json: UserPromptSubmit, PreCompact, PostToolUse(Bash), SessionStart; python3 required)
- `capture_learning.py` -> `detect_patterns` with 63 regexes (`^no[,.!:;-]+\s*\S`, `^don't`, `^stop|^never`, `that's (wrong|incorrect)`, `use .{1,30} not`, `remember:`, positive "perfect!", CJK set), queue per project, zero tokens at capture. `/reflect` later runs `claude -p --model sonnet` (semantic_detector.py), human review via AskUserQuestion, and writes to CLAUDE.md, `.claude/rules/*.md`, CLAUDE.local.md, AGENTS.md, command/skill files, referenced docs, or auto memory for low confidence; `--dedupe`, `--organize`, decay days. Author's own measurement (BACKLOG #1/#2): ~16 of 102 queued items on one machine were reusable rules; "Regex cannot separate a rule from a moment".

### Claims vs facts (Reflect)
| Claim | Grade | Sources |
|---|---|---|
| You write "no, not like that" and it notices | ✅ mod: Haiku classifier, any language; Python: regex `^no...` | mod/hooks/register.tsx `SYSTEM`; scripts/lib/reflect_utils.py `CORRECTION_PATTERNS` |
| One button saves it as a permanent rule | ⚠️ band with Save + scope switch + Edit + Skip; saves to marked block in CLAUDE.md; costs one Haiku call per eligible prompt | mod/README.md; register.tsx `withRule` |
| Claude follows it later | ✅ CLAUDE.md is loaded per session and rule is also injected into the current session; nothing checks obedience | register.tsx; [VULYK] CLAUDE.md loaded once per session |

## Agreement/disagreement with VULYK facts (no recommendations)
- Cache Tax: TTL buckets and 0.025x/0.05x read multipliers agree with [VULYK] Q1/Q2 and [PRICE]. Tension: docs put forks in the 5-min bucket; the mod relies on one run showing a 50-min fork ping keeps the 1 h main entry. `docs/pulse.md` says pulse never calls the model and weights every cache write 1.25 (cannot tell 5 min from 1 h); Cache Tax and Savvy Progress price all writes at the 1 h rate (2x), Savvy admits overestimate on 5-min writes.
- Savvy Progress vs pulse: both read per-agent usage on `turn.step` and draw a band; pulse needs no model cooperation and shows weighted tokens, Savvy shows dollars and needs the model to call `progress`/`step` for progress; pulse's phase/wave comes from `cycle.sh status --json`.
- Reflect vs `defect-intake.sh`: both are prompt-submit capture. VULYK's is a regex lexicon, no model call, cuts model-written text and files the owner's words verbatim to `docs/defects/` cards; Reflect mod uses a Haiku call and writes a model paraphrase to CLAUDE.md after a click.

## Unverified / not done
- Plan-limit weight of a cache read or a fork ping: no official doc found (the mod's README says the same): ❓.
- No mod was run; behaviour is from source. The author's recorded numbers in Cache Tax are not independently reproduced.
- Savvy Progress CI/test state and `session-band` not inspected beyond file list/README.
