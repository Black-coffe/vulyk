# Research: Claude Code updates 2026-10-23..2026-11-02, context and limits

Study record for `weekly-budget`. Installed CLI: 2.1.316. Fetched 2026-11-02.
Status: complete 2026-11-02.

## 1. Versions in the window (npm `time` map + CHANGELOG.md)

npm dist-tags on 2026-11-02: `latest` = `next` = 2.1.316, `stable` = 2.1.309.
2.1.313 was never published to npm and has no CHANGELOG section.

| Version | npm publish (UTC) |
|---|---|
| 2.1.310 | 2026-10-23T21:20:46Z |
| 2.1.311 | 2026-10-26T19:47:57Z |
| 2.1.312 | 2026-10-27T18:36:10Z |
| 2.1.314 | 2026-10-30T00:12:56Z |
| 2.1.315 | 2026-10-30T21:05:24Z (npm only; no CHANGELOG section) |
| 2.1.316 | 2026-10-31T00:42:05Z |

Nothing published 2026-10-31T00:42Z..2026-11-02.

### Context / compaction
- 2.1.310: compaction after "Prompt is too long" kept too much dense text (base64/SVG) -> fixed.
- 2.1.310: lower memory use of `-p`/SDK sessions during compaction on huge transcripts.
- 2.1.311: "Fixed standard-context sessions stopping with "Usage credits required for 1M context" when a request ran over 200K tokens; Claude Code now compacts the conversation and continues".
- 2.1.311: stale MEMORY.md / CLAUDE.md after auto-compact fixed (re-read after compaction).
- 2.1.311: "when the model's reply has no summary in it, Claude Code now usually asks for the summary once more before it replaces the conversation".
- 2.1.311: `DISABLE_COMPACT` in settings / mod env can only turn compaction off; teammates no longer compact when it is set; rewind no longer offers "Summarize from here" then.
- 2.1.311: `[1m]` suffix dropped from names where it has no effect (still accepted).
- 2.1.311: `/teleport` warns when a compacted cloud session loads from its last compaction.
- 2.1.312: "Changed a subagent's `autoCompactWindow` to lower the window set by `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, where it had no effect before; it still never raises that window".
- 2.1.314: "Added idle compaction to VS Code and Claude Desktop's Code tab: a 200K+ token conversation left idle is summarized, and the summary is used on your next message if the prompt cache has expired".
- 2.1.314: "Changed idle compaction to also run for subscribers with telemetry turned off, and on Bedrock, Vertex, Foundry and LLM gateways once the one-hour prompt cache is on".
- 2.1.314: PreCompact hook output now cut at 10,000 characters (huge output made compaction fail/repeat).
- 2.1.314: Bedrock many-image sessions: older images removed and compacted instead of "400 Input is too long".
- 2.1.314: dotted model IDs behind gateways (`claude-opus-4.8`) no longer get the wrong context window.
- 2.1.316: "Fixed `/model <id>` not warning when the model isn't recognized by this version and auto-compact will assume a 200K context window".

### Limits / usage / rate limits
- 2.1.311: "Fixed `/usage` never showing large prompt-cache misses under "What's contributing to your limits usage?"".
- 2.1.311: Pro/Max told to ask admin -> now pointed to billing settings.
- 2.1.312: "Changed usage limit messages to call the 5-hour window the "5-hour limit" instead of the "session limit"" (VS Code: resets shown as clock time).
- 2.1.314: "Continue automatically at usage limit" no longer continues more than three times without a prompt when a task restarts itself.
- 2.1.314: sessions untitled after first prompt failed on a usage limit fixed.
- 2.1.316: Claude apps gateway pooled group budgets (`pooled_budget`, spend limits admin API) - enterprise gateway, not subscriptions.

### Models
- 2.1.311: `ultrathink` runs the turn at xhigh effort "on Opus 5.5, Sonnet 5.5, Haiku 5.5 and Fable 5.1 through Anthropic's API". (No Fable 5.5 named anywhere in the window.)
- 2.1.314: effort capped by org admin -> Claude Code lowers effort and retries.
- 2.1.314: flagged requests retry on another model when only an older Opus is allowed.
- 2.1.316: "Deprecated fast mode for Opus 4.8 as of October 30, 2026; it will be removed on November 30, 2026 ... Migrate to Opus 5.5 to keep the speedup".
- 2.1.316: Vertex/Bedrock aliases fall back to an older model when the newest is not available.

### Agents / subagents / Workflow
- 2.1.311: subagents can use MCP servers that finish connecting late; `SubagentStop` hooks fired ~2x/min per running subagent -> once at finish; isolated worktree no longer removed under a running background subagent.
- 2.1.312: prompt and agent hooks capped at 24 concurrent per session (+12 overdue).
- 2.1.314: parent session no longer keeps each subagent's tool results until turn end (memory).
- 2.1.316: "Added `CLAUDE_CODE_SUBAGENT_EFFORT` to set the effort level subagents run at when nothing else names one, instead of inheriting the session's".
- 2.1.316: subagents that inherited a parent subagent's model no longer move to the main model when woken.

### Hooks / statusline
- 2.1.310: Windows PreToolUse/PermissionRequest hooks let calls through when Git Bash missing -> fixed.
- 2.1.311: status line links stay plain text in background sessions -> fixed.
- 2.1.314: Bash hooks now run on Monitor's shell commands; hook `if` `Monitor(tail *)` matches like `Bash(tail *)`.
- 2.1.316: PowerShell hooks not blocking on exit code 2 when command starts with a type cast/`param`/`using` -> fixed.

### Other (selected)
- 2.1.310: Monitor tool on Bedrock/Vertex/Foundry.
- 2.1.314: `permissions.blockWritesOutsideWorkingDirectories`.
- 2.1.316: `CLAUDE_CODE_DISABLE_ULTRATHINK`; Grep/Glob never returning on Windows when the search process is killed at timeout -> fixed.

## 2. Context window: is it unlimited? (docs, read 2026-11-02)

Short answer: no. A session is bounded by the model window and kept alive by compaction. The 1M window is
the model's ceiling; Claude Code summarizes before it.

- Window size. Fable 5.1/5, Sonnet 5+, Haiku 5.5, Opus 4.7+ "run with the 1M window by default, with no
  `[1m]` suffix needed" (model-config#extended-context). Opus 4.6 / Sonnet 4.6 need `[1m]`.
- Auto-compact threshold. "Models running with a native 1M window compact before the window fills, at about
  967K tokens by default. These include the Fable models, Sonnet 5 and later, Haiku 5.5, and Opus 4.7 and
  later" (model-config#default-auto-compact-thresholds). Otherwise "compacts when the conversation reaches the
  model's context limit"; cloud sessions "as the conversation approaches"; `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`
  -> 200K boundary.
- Tunable: `/autocompact 500k` (per model, saved to `modelSettings`, since v2.1.288), `autoCompactWindow`,
  `--autocompact`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (100K..1M, wins over all), subagent `autoCompactWindow`
  (2.1.312: can only lower). `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` can only lower.
- Not a dead end: "Claude Code compacts automatically as you approach the limit, so a full context window
  doesn't end your session ... Compaction works the same way at the larger limit" (context-window).
- Hard stops that do exist: (a) auto-compact off -> "Context limit reached · /compact or /clear to continue"
  (errors#prompt-is-too-long); with 1M disabled + auto-compact off "sessions stop at the 200K boundary with the
  context-limit error"; (b) thrashing: "If a single file or tool output is so large that context refills
  immediately after each summary, Claude Code stops auto-compacting after a few attempts and shows an error"
  (how-claude-code-works; troubleshooting `Autocompact is thrashing`); (c) failed compaction ->
  "Prompt is too long · automatic compaction failed: <error>".
- What is kept / reinjected (context-window#what-survives-compaction): system prompt + output style stay;
  project-root CLAUDE.md, unscoped rules, auto memory, plan re-injected from disk; skill descriptions rebuilt
  (v2.1.304+); fresh git status; `paths:` rules and nested CLAUDE.md reload on demand only; up to five most
  recently modified files re-read (>5,000 tokens -> path reference only); invoked skill bodies capped 5,000
  tokens each / 25,000 total; background commands and subagents keep running; hook-added context is summarized;
  SessionStart hooks with `compact` matcher re-run. Summary inherits session thinking config since v2.1.198.
  2.1.311 fix: MEMORY.md / CLAUDE.md now re-read fresh after auto-compact.
- Idle compaction (settings-reference#idlecompaction): on by default when interactive terminal / VS Code /
  Desktop Code tab, auto-compact on, conversation on the 1h prompt-cache TTL, feature flags fetchable,
  context >= 200,000 tokens (`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`, min 100,000), and "about an hour has passed
  since the last request". Notice: `Compacted while idle, before the prompt cache expired`. Off with
  `"idleCompaction": false` or `DISABLE_AUTO_COMPACT`. Window news: VS Code / Desktop added in 2.1.314; runs also
  with telemetry off and on Bedrock/Vertex/Foundry/gateways with 1h cache (2.1.314).
- Does compaction cost usage? Yes. "To produce the summary, Claude Code sends a separate request. The request
  repeats your conversation's system prompt, tools, and the history being summarized ... While the cache is warm,
  that request reads your prefix from the cache ... After a break longer than the cache lifetime ... the
  summarization request reprocesses that history as uncached input" (prompt-caching#compacting-the-conversation).
  costs: "`/compact` reads the conversation it summarizes, so compacting a large context is itself a large
  request ... `/clear` costs nothing"; "Session recap and idle compaction can use tokens while you're idle."
  Idle compaction's logic: summarize while the cache is still warm (cheap cache reads), so the next message
  after the 1h TTL does not resend 200K+ tokens uncached.
- Reporting. `/context`: "Visualize current context usage as a colored grid ... When the conversation exceeds the
  context window, the output includes a warning" (commands). SDK row kinds `used`/`free`/`buffer` ("the
  compaction reserve")/`deferred`. Status line: `context_window.context_window_size` ("200000 by default, or
  1000000 for models with extended context"), `used_percentage` / `remaining_percentage` (input-only formula:
  input + cache_creation + cache_read, no output), `current_usage` (null after `/compact` until next call),
  `exceeds_200k_tokens` ("fixed threshold regardless of actual context window size"). Caveat: "The status line's
  `used_percentage` measures against the model's full context window, so while the variable is set, that
  percentage doesn't indicate when compaction will run"; `/context` adds an estimate for messages since the last
  response, so it can read higher than the status line.

## 3. Fable 5.5

No official source found for any "Fable 5.5" in CHANGELOG 2.1.310..2.1.316 or model-config.md (incl. its alias
version history). Docs name Fable 5.1 (alias `fable`, since v2.1.257) and Fable 5. 2.1.311 lists `ultrathink`
models as "Opus 5.5, Sonnet 5.5, Haiku 5.5 and Fable 5.1". Fable vs limits in docs: "Depending on your plan and
seat tier, Fable usage can bill to usage credits instead of drawing on your plan's included limits"
(model-config#fable-and-usage-credits); no change to that in the window's changelog.
anthropic.com/news (items Oct 2..Oct 28, 2026) has no Fable 5.5; the last model posts are "Introducing Claude
Opus 5.5" (Oct 18) and "Introducing Claude Haiku 5.5" (Oct 7). platform models overview lists Fable 5.1
(`claude-fable-5-1`) as current, Fable 5 as legacy. claude.com/blog Oct 22..28: no model launch; relevant only
"Smart reports, surveys, and pooled group budgets for Claude Enterprise" (Enterprise, matches 2.1.316 gateway item).
Web search for "Fable 5.5": no hits; only Fable 5 (June 9, 2026) secondary coverage.
Verdict: no official source found for Fable 5.5.

Fable vs weekly limits (support, all marked "Updated this week", no calendar date):
- "Claude Fable models on your plan": Max, Ultra, premium Team/legacy-Enterprise seats: Fable models "draw from
  your plan's regular weekly usage limits and use them faster than other Claude models"; "You can use up to 50% of
  your weekly usage limits on Fable models at no extra cost"; "you can never use more than your weekly limit";
  at the Fable limit: usage credits or switch model. Pro / standard seats: "Fable 5 and Fable 5.1 aren't included
  in your plan's usage limits" (usage credits from the start). History: the 50% promotion for Fable 5 "ended on
  July 19, 2026"; Fable 5.1 "was never part of it".
- "What is the Ultra plan?": "The Max 20x plan is now called the Ultra plan"; $200/month; 10x Pro weekly;
  "Ultra plans have a weekly usage limit that applies across all models, and a separate weekly limit for Fable";
  verified Ultra accounts have no five-hour limit. No rename date given.
- "What is the Max plan?": $100/month, "five times the Pro plan's usage every five hours and every week",
  five-hour limit + weekly all-models limit + "a separate weekly limit for Fable". No rename mention.
- "Use Claude Code with your Pro, Max, or Ultra plan": limits "shared across Claude and Claude Code"; "Max and
  Ultra plans also have a separate weekly limit for Fable"; new "Usage limit reached · wrapping up" allowance
  ("small and capped ... counts toward your weekly limit", rolling out gradually); points to `/status`.
- claude.com/pricing: Max and Ultra "50% of weekly limits*" for Fable; Pro "Usage credits"; Ultra "No 5-hour
  limit" (verified accounts). No rename date on the page.
Not confirmed: the exact date of the Max 5x -> Max / Max 20x -> Ultra rename (repo commit 693fd5e says
2026-10-30; no official page read here states a date), and whether the "separate Fable weekly limit" wording is
new in the window (Wayback check rate-limited). No CHANGELOG item in 2.1.310..2.1.316 changes Fable accounting.

## 4. Reading current usage from scripts (docs)

- Status line stdin JSON: `rate_limits.five_hour|seven_day.used_percentage` (0-100) and `.resets_at` (epoch s);
  "appears only for claude.ai Pro, Max, and Ultra subscribers ... only after the first API response"; windows
  may be absent; no per-model weekly field. (statusline#rate-limit-usage)
- Hooks: common input fields are session_id, prompt_id, transcript_path, cwd, scratchpad_dir, permission_mode,
  effort, hook_event_name (+agent_id/agent_type). No `rate_limits` or `context_window` in hook payloads.
  Only limit signals: `StopFailure` matcher/error `rate_limit`; Notification types `quota_auto_resume_fired`,
  `quota_auto_resume_stale`, `quota_auto_resume_disabled`. PostToolUse of a foreground Agent call carries the
  subagent's final-request `usage`. (hooks)
- `/usage` (aliases `/cost`, `/stats`): interactive; shows session cost, plan usage bars, breakdown. No
  `claude usage` CLI subcommand in cli-reference.
- Agent SDK: send `/usage` as a prompt -> assistant message carries `usage_report` (`SDKUsageReport`, SDK
  v0.3.273+, "experimental"): `rate_limits.limits[]` rows with `kind` ("such as `session`, `weekly_all`, or
  `weekly_scoped`"), `group`, `percent`, `resets_at`, `scope.model.display_name`, `severity`, `is_active`; plus
  `extra_usage`. Only when the session uses a claude.ai credential with a known plan or `user:profile` scope and
  is not on usage-based billing. `/context` -> `context_usage`; `getContextUsage()` method. `SDKRateLimitEvent`
  (`status` allowed / allowed_warning / rejected, `resetsAt`, `utilization`). (agent-sdk/typescript)
- `-p --output-format json`: `total_cost_usd` + per-model cost (client-side estimate), not plan limits. (headless)
- OTEL: `claude_code.cost.usage` (USD), `claude_code.token.usage` (by type/model/query_source), event
  `claude_code.compaction` (trigger, pre_tokens, post_tokens, precompute_reuse). No plan-limit / quota metric.
  (monitoring-usage)

## Sources

| Claim | URL | Date | Quote |
|---|---|---|---|
| Versions and publish dates | https://registry.npmjs.org/@anthropic-ai/claude-code | fetched 2026-11-02 | `"2.1.316": "2026-10-31T00:42:05.743Z"` ... `"latest": "2.1.316"` |
| Changelog items above | https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md | fetched 2026-11-02 | quoted inline per bullet |
| Survives-compaction table, "doesn't end your session" | https://code.claude.com/docs/en/context-window | fetched 2026-11-02 | "Claude Code compacts automatically as you approach the limit, so a full context window doesn't end your session" |
| 1M default models, ~967K threshold, Fable credits | https://code.claude.com/docs/en/model-config | fetched 2026-11-02 | "compact before the window fills, at about 967K tokens by default" |
| Idle compaction conditions | https://code.claude.com/docs/en/settings-reference#idlecompaction | fetched 2026-11-02 | "about an hour has passed since the last request" |
| Compaction is a separate request | https://code.claude.com/docs/en/prompt-caching#compacting-the-conversation | fetched 2026-11-02 | "To produce the summary, Claude Code sends a separate request" |
| Compaction / idle cost | https://code.claude.com/docs/en/costs | fetched 2026-11-02 | "Session recap and idle compaction can use tokens while you're idle" |
| Thrashing stop | https://code.claude.com/docs/en/how-claude-code-works ; https://code.claude.com/docs/en/troubleshooting | fetched 2026-11-02 | "stops auto-compacting after a few attempts and shows an error" |
| Context-limit error | https://code.claude.com/docs/en/errors#prompt-is-too-long | fetched 2026-11-02 | "Context limit reached · /compact or /clear to continue" |
| Status line context + rate_limits fields | https://code.claude.com/docs/en/statusline | fetched 2026-11-02 | "`rate_limits`: appears only for claude.ai Pro, Max, and Ultra subscribers" |
| Hook input fields; quota notifications | https://code.claude.com/docs/en/hooks | fetched 2026-11-02 | common input table has no rate_limits; "`quota_auto_resume_fired`" |
| /usage, /context commands | https://code.claude.com/docs/en/commands | fetched 2026-11-02 | "`/usage` Show session cost, plan usage limits, and activity stats" |
| SDK usage_report / rate_limit_event | https://code.claude.com/docs/en/agent-sdk/typescript | fetched 2026-11-02 | "The server's meter kind, such as `session`, `weekly_all`, or `weekly_scoped`" |
| OTEL metrics | https://code.claude.com/docs/en/monitoring-usage | fetched 2026-11-02 | metrics table lists cost.usage, token.usage; no quota metric |
| Current models; no Fable 5.5 | https://platform.claude.com/docs/en/about-claude/models/overview | fetched 2026-11-02 | "Use Claude Fable 5.1 for demanding reasoning and long-horizon agentic work" |
| News list, no Fable 5.5 | https://www.anthropic.com/news | fetched 2026-11-02 | "Introducing Claude Opus 5.5 ... Oct 18, 2026" |
| Blog list Oct 22..28 | https://claude.com/blog | fetched 2026-11-02 | "Smart reports, surveys, and pooled group budgets for Claude Enterprise" |
| Fable share of weekly limit | https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan | "Updated this week", fetched 2026-11-02 | "You can use up to 50% of your weekly usage limits on Fable models at no extra cost" |
| Ultra = ex-Max 20x, separate Fable weekly limit | https://support.claude.com/en/articles/17728952-what-is-the-ultra-plan | "Updated this week", fetched 2026-11-02 | "The Max 20x plan is now called the Ultra plan" |
| Max limits | https://support.claude.com/en/articles/11049741-what-is-the-max-plan | "Updated this week", fetched 2026-11-02 | "a separate weekly limit for Fable" |
| Claude Code on plans, shared limits, wrap-up | https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan | "Updated this week", fetched 2026-11-02 | "These limits are shared across Claude and Claude Code" |
| Pricing table | https://claude.com/pricing | fetched 2026-11-02 | "Fable included, up to half your weekly limit" |
