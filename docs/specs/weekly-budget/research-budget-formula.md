# Research: weekly-budget formula and data sources

> **Corrections (Queen, 2026-11-02, after this file was written):**
> 1. "Fable % is not exposed officially" is superseded. Headless `claude -p "/usage"` returns `weekly_scoped` with `scope.model.display_name: Fable` at $0. See recon.md, probe section.
> 2. C5 ("account 1 re-anchor") is most likely a mix of two accounts' data: account 2 read 64%/Wednesday on 10-29 and 65%/Wednesday on the owner's Usage page on 11-02, while account 1 reads 32%/Thursday. Treat it as a per-account isolation requirement, not as evidence of re-anchoring.


**Date:** 2026-11-02 · **Spec:** weekly-budget · **Status:** complete (A, B, C). Owner-specific paths were generalised before commit; A1/B5c/C5 keep usage readings
as anonymous examples (account 1 / account 2).

Scope: what a framework can read about the account's usage limits, how existing tools compute burn rate and
projections, candidate pace formulas with worked numbers, pitfalls. Local evidence is read-only; no tokens or
secrets were read or printed. Account identifiers below are shortened shapes only.

## A. Data sources

### A1. Local evidence on this machine (read 2026-11-02)

**`~/.claude/limits_state.json`** (written by the owner's statusline shim, see A2). Current content shape:

```json
{"seven_day": {"used_percentage": 31, "resets_at": 1793865600}, "updated_at": 1793610489.39}
```

- No `five_hour` key: account 1 is a verified Ultra account (matches the brief). `used_percentage` is an integer.
- `resets_at` is epoch seconds; `updated_at` is the shim's own `time.time()` (local clock), rewritten on every
  statusline render that carries `rate_limits` (observed: two rewrites ~5 s apart while this research ran).
- One file per `CLAUDE_CONFIG_DIR`, so it is already per account. It holds the latest value only, no history.

**A personal statusline shim** (about 50 lines, outside VULYK): reads statusline stdin, takes `data["rate_limits"]`, if
`five_hour` or `seven_day` is present writes it + `updated_at` atomically (`mkstemp` + `os.replace`) to
`<CLAUDE_CONFIG_DIR or ~/.claude>/limits_state.json`; when stdin has no `rate_limits` (fresh session before its first
reply) it injects the saved windows whose `resets_at` is still in the future; then pipes stdin unchanged to the real
statusline command (`cs`). Fails silent. This is exactly the pattern a framework needs, but it lives in the owner's
personal setup, not in VULYK.

**`~/.cache/claude-statusbar/last_stdin.json`** (cs, last stdin of the last render on the machine, any account). Full
statusline stdin shape observed (CC 2.1.316): `session_id, transcript_path, cwd, prompt_id, effort.level,
session_name, model{id,display_name}, workspace{...}, version, cost{total_cost_usd, total_duration_ms, ...},
context_window{total_input_tokens, total_output_tokens, context_window_size, current_usage{...}, used_percentage,
remaining_percentage}, exceeds_200k_tokens, prompt_cache{...}, fast_mode, thinking.enabled,
rate_limits{five_hour{used_percentage:int, resets_at:int}, seven_day{used_percentage:int, resets_at:int}}`.
That snapshot (account 2, 10:44 local) still carried `five_hour`, so the two owner accounts are in different states:
account 2 is not (yet) on the no-5h regime. **No model-specific or Fable bucket** (`seven_day_opus`,
`seven_day_fable`, ...) and no `spend_limit` key appeared in any local stdin snapshot; keys ever seen: `five_hour`,
`seven_day`.

**`~/.cache/claude-statusbar/rate_latest.<acct12>-<org8>.json`** (cs shared "latest reading" store, per account+org;
legacy unsuffixed and account-only variants also present). Shape:

```json
{"sessions": {"<session-id>": {"sig": [u5, r5, u7, r7], "changed_at": ts, "model": "claude-opus-5-5",
                               "advanced_at": {"seven_day": ts}}},
 "five_hour": {"<resets_at>": {"used": 42.0, "observed_at": ts}},
 "seven_day": {"<resets_at>": {"used": 31.0, "observed_at": ts, "value_at": ts}},
 "regime": {"changed_at": ts, "reason": "model-switch", "model": "claude-opus-4-8"}}
```

One reading per window per `resets_at` (overwrite-on-newer), plus the previous window's last value (here: previous
7d window ended at 64 %, current at 31 %). It is **not** a time series. `sessions` keeps each session's last
signature, so several sessions' last readings exist, but only the last one each.

**`~/.cache/claude-statusbar/rate_projection*.json`** (cs projection sample store, up to 5000 samples per window,
decimated to >= 0.5 pp or >= 60 s): **not present on this machine** (the forecast/projection feature has not written
it). So there is no local `used_percentage` time series today. `quota/<sha256>.json` holds `{ts, rate_limits}`, a
single latest reading.

**Sampling cadence.** cs comments (predict.py:51-57) say each Claude Code window sees only the `used_pct` that
Claude "last pushed into ITS stdin" on its own cadence, while the statusline re-renders ~1/s in cs daemon mode;
`used_percentage` is an integer, so it moves in 1 pp steps. Effective resolution of a 7-day series is 1 pp =
1/100 of the week's budget; at a flat-pace burn (100 %/168 h = 0.6 %/h) one step arrives every ~1.7 h.

**Transcripts `~/.claude/projects/**/*.jsonl`.** Each assistant entry carries `message.model`, `timestamp`,
`requestId`, `isSidechain`, and `message.usage{input_tokens, cache_creation_input_tokens, cache_read_input_tokens,
output_tokens, output_tokens_details.thinking_tokens, cache_creation{ephemeral_1h_input_tokens,
ephemeral_5m_input_tokens}, server_tool_use{web_search_requests, web_fetch_requests}, service_tier, speed,
iterations[], fallback_credit}`. No percent, no limit field. Tokens per model per minute are recoverable; percent is
not.

### A2. cs (claude-statusbar 3.52.3) forecast algorithm

File: `<site-packages>/claude_statusbar/predict.py` (1320 lines).

1. **Imminent chip (`forecast_chip`, predict.py:259-285; math in `project_window`, :237-256).** Whole-window
   average pace: `elapsed = window_len - (resets_at - now)`, `avg_rate = used/elapsed`,
   `projected = used + avg_rate*ttr` (= `used*window_len/elapsed`), `ttl = (100-used)/avg_rate`. Chip `~ETA` only
   when `projected >= 100` **and** `ttl <= 1 h` (`IMMINENT_ETA_S`, :44). Suppressed until 10 min (5h) / 60 min (7d)
   into the window (`MIN_ELAPSED_S`, :41). Rationale in the docstring (:4-10): a burst-rate extrapolation gave
   absurd ETAs ("~20m to the 7-day limit" off a 60 s tick) because `used_pct` is a coarse integer.
2. **End-of-window projection `->NN%` for 7d (`_project_7d_raw`, :1015-1039).**
   `future = integrate_future_buckets(now, resets_at, learned)` sums hourly expected rates over four local-time
   buckets (`bucket_for_time`, :843-852: night 00-07, weekend, weekday work 09-18, weekday non-work) with priors
   `DEFAULT_BUCKET_PRIORS` %/h night 0.02, work 0.45, non-work 0.12, weekend 0.10 (:213-218), blended toward learned
   per-bucket rates with weight `min(1, n/20)` (`expected_bucket_rate`, :888-898). Momentum: the rate over the last
   3 h (`RECENT_MOMENTUM_HORIZON_S`, :211) may only **raise** the near-horizon estimate
   (`future += max(0, recent*horizon - bucket_near)`). Plus 10 % of the whole-window-average overshoot as a sanity
   term. Result `max(used, used + future + sanity)`.
3. **5h projection (`_project_5h_raw`, :966-1005).** Weighted blend of recent rate (max of 1 h and 30 min trailing,
   weight 0.55), window average (0.30) and bucket prior (0.15). Comment (:986-992): backtested over 46 closed windows,
   taking the faster of 1 h/30 min cut heavy-window misses 26 % -> 19 %, "a mild high bias ... is the preferred
   failure direction for a quota warning".
4. **Rate hygiene (`_rate_from_samples`, :922-956).** Rate = (last-first)/(t_last-t_first) over the lookback; needs
   span >= 300 s (`MIN_RECENT_RATE_SPAN_S`, :208); clamped (not dropped) at `RATE_CAP_PCT_PER_H` 60 %/h for 5h,
   10 %/h for 7d (:204). A **regime boundary** (model switch, a new model joining the active fleet within 900 s,
   :326-338) clips the lookback and relaxes the span floor to 120 s.
5. **Smoothing (`smooth_projection`, :1042-1066).** EWMA on the displayed projection, tau 8 min (5h) / 2 h (7d);
   upward moves to >= 100 approach with tau <= 120 s, downward moves keep the slow tau (anti-flap hysteresis).
6. **Depletion ETA (`_depletion_eta_seconds`, :1175-1193).** `eta = ttr*(100-used)/(raw-used)`, only if
   `raw > 100`; docstring admits it overestimates time left when near-term buckets are hotter.
7. **Integrity.** Samples are compressed to monotonic-per-`resets_at` (:739-761); a reading below the same-reset max
   means the limit was re-baselined, and all samples of that reset are dropped (:790-809). `resets_at` outside
   `[now-60s, now+window+1d]` is rejected (:340-348). Stores are keyed per account+org (`_account_path`, :163-182)
   after a live incident where another login's later `resets_at` won the merge for days (:59-67).

### A3. Official Claude Code docs: statusline and hooks (opened 2026-11-02)

**Statusline stdin `rate_limits`** (code.claude.com/docs/en/statusline):
- Fields: `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage` ("from 0 to 100"),
  `rate_limits.{five_hour,seven_day}.resets_at` ("Unix epoch seconds"); `rate_limits.spend_limit.{used_percentage,
  resets_at}` behind a Claude apps gateway (v2.1.251+), with optional `used_usd, limit_usd, period`
  (`daily|weekly|monthly`, v2.1.284+, refreshed "about every five minutes").
- Presence: "appears only for claude.ai Pro, Max, and Ultra subscribers, or behind a Claude apps gateway that sets a
  spend limit for you. Even then, it appears only after the first API response in the session. Each window
  (`five_hour`, `seven_day`, `spend_limit`) may be independently absent, and Claude Code drops a window once its
  `resets_at` time passes."
- **No model-scoped bucket** (no Fable, no Opus) is documented in stdin; none was seen locally either (A1).
- Update triggers: session start/resume, each new assistant message, `/compact` end, permission-mode change, vim
  toggle, `command` change, `refreshInterval` timer (min 1 s), a rate-limit window reaching `resets_at`, a warm prompt
  cache reaching `expires_at`. "Claude Code debounces updates at 300ms ... If a new update triggers while your script
  is still running, Claude Code cancels the in-flight script." "The event-driven triggers can go quiet when the main
  session is idle, for example while a coordinator waits on background subagents."
- One `statusLine` per effective settings (a single `command` object). `subagentStatusLine` (which a plugin may ship)
  gets base hook fields + `columns` + `tasks[]`, no `rate_limits`. So a framework cannot own the statusline; it can
  only (a) ship an optional shim like the owner's (A1) that the owner chains in front of their real statusline, or
  (b) read a file such a shim writes.

**Hooks** (code.claude.com/docs/en/hooks): common input fields are `session_id, prompt_id, transcript_path, cwd,
scratchpad_dir, permission_mode, effort.level, hook_event_name` (+ `agent_id, agent_type` in subagents).
**No hook input carries `rate_limits`** (all three parts of the page read). Usage-adjacent fields that do exist:
SessionStart on resume/fork has `context_tokens`, `estimated_cache_write_usd`, `prompt_cache_likely_expired`,
`seconds_since_last_response`; PostToolUse for the Agent tool has `tool_response.totalTokens` and `usage{...}` of the
subagent's final request; `StopFailure` input has `error` (`rate_limit`, `overloaded`, `billing_error`, ...),
`error_details` (e.g. `"429 Too Many Requests"`), `last_assistant_message`; Notification types
`quota_auto_resume_fired|stale|disabled` (v2.1.234+) carry only `message/title/notification_type`, no `resets_at`.
StopFailure is the only hard "limit hit" signal a hook gets, and it is post-factum.

### A4. Plan facts since 2026-10-30 (opened 2026-11-02)

- claude.com/pricing: Ultra "No 5-hour limit ‡ ... ‡ No 5-hour limit for verified accounts", "10x Pro usage every
  week"; table: Max 5x per 5 h and 5x per week; Fable "50% of weekly limits" on Max and Ultra, "Usage credits" on Pro.
- support.claude.com "What is the Ultra plan?": "Ultra plans have a weekly usage limit that applies across all
  models, and a separate weekly limit for Fable." Verified check: "If you don't see a Current session bar, your
  account is verified." Also: a "limit reset" can reset weekly usage back to full (pitfall C: `used` can drop).
- support.claude.com "Claude Fable models on your plan" (2026-10-30): Max/Ultra "can use up to 50% of your weekly
  usage limits on Fable models ... They draw from your plan's regular weekly usage limits and use them faster than
  other Claude models." FAQ: "No. You can use up to 50% of your weekly limit on Fable models, but your use of other
  models draws from the same usage limits and you can never use more than your weekly limit."
- support.claude.com "How do usage and length limits work?": "Weekly limits reset at a fixed time each week that is
  assigned to your account."
- Secondary: notebookcheck.net, framesignal.com (2026-11-01), datastudios.org (2026-10-30) agree: renamed on
  2026-10-30, verified Ultra has weekly limits only, weekly limits unchanged.

**Consequence for the formula.** Fable is a *sub-cap inside* the all-model weekly pool: Fable usage moves both
`seven_day` (all models) and the Fable bucket. Fable cap in all-model units = 50 % of the week. The Fable bucket's
own percent is **not** in statusline stdin; only the undocumented endpoint (A5) returns it.

### A5. OAuth usage endpoint `GET https://api.anthropic.com/api/oauth/usage` (undocumented)

- Used by Claude Code's own `/usage` per third-party docs; requires the interactive-login OAuth bearer token from
  `~/.claude/.credentials.json` (macOS keychain) and header `anthropic-beta: oauth-2025-04-20`.
- Response (third-party reverse engineering, consistent across sources): `five_hour`, `seven_day`, `seven_day_opus`,
  `seven_day_sonnet`, `seven_day_oauth_apps` as `{utilization: float 0-100, resets_at: ISO-8601}` or `null`;
  `extra_usage{is_enabled, monthly_limit, used_credits, utilization, currency}`; newer `limits[]` array of
  `{kind: session|weekly_all|weekly_scoped, percent: int, resets_at: ISO, scope.model.display_name: "Fable",
  severity}`. linesmith notes per-model weekly usage "now arrives" in `limits[]` and `seven_day_*` are "null in
  practice"; codenamed keys (`omelette_*`, `iguana_*`, `spend`, ...) appear without notice.
- cs uses exactly this, **opt-in**, in `scoped_usage.py:59-100`: reads `~/.claude/.credentials.json`
  (`claudeAiOauth`) or the macOS keychain, polls at most every 300 s, keeps the last good value for 600 s, parses
  only `kind == "weekly_scoped"` rows (`parse_limits`, :15-35). Not enabled on this machine (no `scoped/` cache dir).
- Risks: undocumented, can change without notice; aggressive 429s reported (anthropics/claude-code#31637: "even at
  very low intervals", no `Retry-After`; closed "not planned" by a stale bot, no staff reply); setup-token
  credentials get 403 (scope `user:profile` missing); reading/refreshing the shared credentials file can collide with
  Claude Code's own refresh. **Constraint for VULYK:** CONTRIBUTING rejects anything touching auth, so the endpoint
  is out of bounds for the framework. It is the only source of the Fable percent today, so VULYK must either estimate
  the Fable share (B4) or read a file an owner-installed tool (cs scoped cache) already writes.

### A6. Tokens -> weekly percent: not published, calibratable

- The ratio is not published. claude.com/pricing: "How fast you reach a limit depends on the model you use, how long
  your chats are, and how large your files are" (no figures); the Fable article: Fable models "use them faster than
  other Claude models" (no factor). cc-usage (tillo13) README: the endpoint "reports rounded percentages of
  undisclosed limits".
- Empirical calibration is practised: cc-usage keeps "a locally-calibrated `%-per-Mtoken` ratio" to extrapolate
  between endpoint snapshots and has `--validate` ("Compares the Anthropic-reported Δ quota % against your
  locally-measured token burn over the same interval").
- Mandatory hygiene from the same README: one assistant JSONL line per content block, each repeating `usage`; dedupe
  by `(message.id, requestId)` keeping the last line, or sums overcount ~2x (measured 2.1-2.6x there; ccusage keys
  dedupe the same way).
- Proposed calibration for VULYK (derived, not from a source): `k_m = ΔU / Σ c_m(tokens)` over intervals where only
  model family `m` ran, with `c_m` = API-equivalent cost (tokens by type × list price) so input, output, cache write
  and cache read fold into one number; refit as a least-squares `ΔU ≈ Σ_m k_m·c_m` over many intervals. Limits:
  1 pp quantization means an interval must span >= 5 steps for ~±10 % error; usage on claude.ai web/mobile/Cowork
  and on other machines draws the same pool but never reaches local JSONL, so k is biased high when those run.
  Good enough to apportion *who* spent (Fable vs Opus vs Sonnet, per story), not to replace the official percent.

## B. Formulas

### B1. Survey of existing tools

| Tool | Data | Pace / projection rule | Thresholds |
|---|---|---|---|
| cs 3.52.3 (local, A2) | stdin `rate_limits`; opt-in endpoint | chip: whole-window average `projected = U·W/elapsed`; 7d `->NN%`: hourly bucket priors (work 0.45, non-work 0.12, weekend 0.10, night 0.02 %/h) learned toward actuals + 3 h momentum that may only raise; 5h: 0.55·recent(max of 1 h, 30 min) + 0.30·window avg + 0.15·bucket | ETA chip only if `projected >= 100` and ETA <= 1 h; no chip before 60 min (7d); EWMA display tau 2 h (7d), fast up / slow down |
| ccusage `blocks` | local JSONL tokens | 5 h blocks from first message; burn = tokens/min in active block; projected = current rate continued | vs `--token-limit` (explicit or `max` of past blocks): < 70 % green, 70-90 % yellow, >= 90 % red |
| Claude-Code-Usage-Monitor v4 | statusline capture, JSONL, opt-in endpoint | burn over "all sessions in the last hour"; custom plan = P90 of last 192 h sessions; "Seven-day percentages render only from official statusline data" | README names "reset-aware pace", no formula published |
| Matthew-IDKA/claude-code-statusline | stdin | pace = U / elapsed-share | < 0.85 behind, 0.85-1.15 on pace, > 1.15 ahead |
| achromichat/usage-quota-bar | endpoint | `δ = remaining - (time_left/window·100)` | ±5 pp tolerance; 7d shown if burning fast, surplus to waste, or <= 25 % left |
| asjadaugust/claude-usage-statusline | endpoint (`limits[]`, shows Fable) | gap = U - elapsed % | sign only |
| thevibeworks/claude-code-statusline | stdin + endpoint | pace = used ÷ elapsed (`0.7✕`, hidden first 15 min); 7d forecast = per-weekday EWMA profile + last 24 h burn; < 14 days history -> window average | colour only |
| tillo13/cc-usage | endpoint every 15 min + SQLite of JSONL | target landing (default 99 %): `daily budget = (target - U)/days_left`; "safe %/h"; rate per *active* hour; "constraint picker" = the window that bites first | COOL / ON PACE / HOT / VERY HOT |
| mmdemirbas/claude-quota | endpoint | projected share at reset (`↗145 %`) | dim to 79 %, yellow to 100 %, red beyond |

Common ground: everyone compares U with elapsed share; the careful ones (cs, thevibeworks, cc-usage) add a
time-of-week weighting and a short recent-burn term, and choose a high bias for warnings.

### B2. Notation

`W` window length (168 h; 5 h for `five_hour`) · `T = resets_at - now` (h) · `e = W - T` elapsed (assumes the window
started at `resets_at - W`, see C) · `f = e/W` · `U` used % · `R = 100 - U` · `d = T/24` days left ·
`w(h)` hour weight (1 = flat) · `S_past = Σ w over elapsed hours`, `S_left = Σ w over remaining hours`.

### B3. Candidate formulas

**F1. Calendar glide (stateless, zero history).**
`E = 100·f` (expected used by now) · pace ratio `P = U/E` · gap `δ = U - E` (pp) ·
average burn `a = U/e` %/h · landing at that pace `L = U/f` · exhaustion in `R/a` hours ·
daily allowance `D = R/d` · hourly allowance `H = R/T`. Optional target landing `τ` (e.g. 95, a reserve):
`D_τ = (τ - U)/d`.

**F2. Work-hours glide (stateless, needs a weight profile).** Same as F1 with weighted time:
`E_w = 100·S_past/(S_past + S_left)`, `P_w = U/E_w`, allowance for the current hour `H_now = R·w(now)/S_left`,
for today `D_today = R·Σ_today_left w / S_left`. Weights: cs priors normalised (work 1.0, weekday evening 0.27,
weekend day 0.22, night 0.04) or owner-set; learned weights per cs `expected_bucket_rate` (blend to actuals, full
weight at 20 samples). Fixes F1's two flaws: nights count as spendable, and early-week P swings.

**F3. Burn-rate projection (stateful: a per-account sample log).** Recent rate over a lookback `Lb`
(3 h for 7d, max(1 h, 30 min) for 5h, as cs): `r = (U_now - U_{now-Lb})/span`, span >= 20 min (7d) and >= 1 pp moved,
clamped to a plausibility cap (cs: 10 %/h for 7d, 60 %/h for 5h). Forward rate `r_f = max(r, a_w)` while active
(high bias, cs rationale), bucket-weighted `a_w` when idle. ETA to 100 % `= R / r_f` (active hours, map to calendar
with `w`). Projected landing `L3 = U + r·min(Lb, T) + a_w·Σ_rest w` (cs `_project_7d_raw` shape). Display smoothing:
EWMA `x ← x + α(x_raw - x)`, `α = 1 - exp(-Δt/τ)`, τ = 2 h down, <= 2 min up.

Recommendation: F2 sets the **allowance** (daily/hourly budget), F3 drives the **warning text** ("at this rate the
week ends in …"), F1 is the fallback when there is no profile or history. Evaluate every window present
(`five_hour`, `seven_day`, Fable estimate) and act on the one that bites first (cc-usage constraint picker).

### B4. States and hysteresis (proposal)

| State | Enter | Leave | Meaning for VULYK |
|---|---|---|---|
| BOOST | `T < 72 h` and `L_w < 70` (would waste > 30 pp) | `L_w >= 80` | allowance `D` above neutral; Fable/opus seats allowed |
| OK | otherwise | | neutral |
| WARN | `P_w > 1.20` or F3 ETA < `T` | `P_w < 1.10` and ETA >= `T + 12 h` | say it once per hour/session, with numbers |
| THROTTLE | F3 ETA < `T - 24 h`, or `R < 10` with `T > 24 h`, or Fable bucket est > 90 % | ETA >= `T` | downgrade routing, fewer parallel workers, ask before a Tier 3-4 build |

No P-based state before `E_w >= 5 pp` or `e >= 6 h` (integer percent makes early P meaningless); use `δ` instead.
Thresholds 1.15/1.20 sit where Matthew-IDKA (1.15) and usage-quota-bar (±5 pp) put theirs.

### B5. Worked numbers (owner's examples)

Neutral flat allowance = 100/7 = **14.3 %/day**.

**(a) 6 days left, 20 % used.** `f = 1/7`, `E = 14.3`, `P = 1.40`, `δ = +5.7 pp`. Average burn 20 %/day:
landing 140 %, dry in 80/20 = **4 days** (2 days before reset). Allowance `D = 80/6 = 13.3 %/day` (0.93× neutral),
`H = 0.56 %/h` wall-clock, 1.33 %/h per active hour at 10 active h/day; with a 95 % target 12.5 %/day.
F2 changes the verdict. With cs priors normalised (weekday = 9 h×1.0 + 8 h×0.267 + 7 h×0.044 = 11.44; weekend
day = 17 h×0.222 + 7 h×0.044 = 4.09; week = 65.40): if day 1 was a weekday, `E_w = 11.44/65.40 = 17.5` and
`P_w = 1.14` (OK, just under WARN); if day 1 was a Saturday, `E_w = 4.09/65.40 = 6.3` and `P_w = 3.2` (hard WARN).
F3 gives the owner's "through 2 days / today" phrasing: recent burn 2 %/active h -> 80/2 = 40 active h ≈ 4 workdays;
recent burn 8 %/active h (a Fable-heavy afternoon) -> 10 active h -> **runs out today**.

**(b) 2 days left, 50 % used.** `f = 5/7`, `E = 71.4`, `P = 0.70`, `δ = -21.4 pp`. Average burn 10 %/day lands at
70 %: 30 pp expire unused. Allowance `D = 50/2 = 25 %/day` (**1.75× neutral**), `H = 1.04 %/h` wall-clock,
2.5 %/active h; with a 95 % target 22.5 %/day. State BOOST.

**(c) Live, account 1, 2026-11-02 09:08 UTC** (L1): U = 31, resets Thu 2026-11-05 08:00 UTC, `T = 70.9 h`,
`f = 0.578`, `E = 57.8`, `P = 0.54`, `D = 69/2.95 = 23.4 %/day` (1.64× neutral) -> BOOST, *if* the window really
started at `resets_at - 7 d` (see C, re-anchoring).

**(d) Fable share.** Fable cap = 50 pp of the week (A4). Fable bucket `F` (% of its own cap) ↔ week pp `= 0.5·F`.
Fable availability `= min(0.5·(100 - F), R)` pp; Fable daily allowance `D_F = min(100 - F, 2R)/d` in Fable-bucket %.
Example: 4 days left, `F = 60`, `U = 45`: `E_F = 42.9`, `P_F = 1.40` (WARN on Fable alone while all-model
`P = 1.05` is fine); `D_F = 40/4 = 10 %` of the Fable cap per day = **5 pp** of today's all-model 13.75 pp; the rest
goes to non-Fable models. Variant 2 days left, `U = 50`, `F = 30`: `D_F = min(70, 100)/2 = 35 %`/day of the Fable
cap = 17.5 pp/day -> BOOST for Fable. Without the endpoint, `F̂ = 2·Σ_since_reset k_fable·c_fable` (A6), a derived
estimate to be labelled as such.

## C. Pitfalls

1. **Integer percent.** `used_percentage` arrives as an integer locally (docs say only "0 to 100"; rounding rule
   unknown). At a flat pace one step is ~1.7 h; any rate needs a span floor and >= 1 step, and early-week P must be
   suppressed (B4).
2. **Refresh cadence.** Statusline runs on events (each assistant message etc.), 300 ms debounce, goes quiet when
   the main session idles; `refreshInterval` (>= 1 s) only re-renders, it does not fetch fresher limits. Hooks never
   see `rate_limits`. A hook reading a shim-written file must check staleness (`now - updated_at`) and say "unknown"
   rather than act on an old value; the value only moves when *some* session on the account gets a reply.
3. **No owned statusline.** One `statusLine` per user; VULYK can ship an opt-in shim (chain: shim -> owner's
   command, as such a shim does) or read an existing file; it must work with neither (no budget, no blocking).
4. **Two accounts on one machine.** Limits are per account; key all state by `CLAUDE_CONFIG_DIR` (the owner's shim
   already writes per config dir). cs had a live incident where another login's later `resets_at` won a shared merge
   "for days" (predict.py:59-67) and now keys by account+org.
5. **`resets_at` moves.** Observed locally (L3): account 1's window was `resets_at` Wed 2026-11-04 08:00 UTC at 64 %
   (reading 2026-10-29), now `resets_at` Thu 2026-11-05 08:00 UTC at 31 %: the reset moved +24 h mid-window and usage
   dropped (cause not confirmed: the 2026-10-30 plan change or a "limit reset", W4). Rules: a new `resets_at` = a new
   window, drop that window's samples; `U` falling within the same `resets_at` = re-baseline, drop samples (cs
   :790-809); reject `resets_at` outside `[now - 60 s, now + W + 1 d]` (cs :340-348). And `elapsed = W - T` is an
   assumption: after a re-anchor the true start is unknown, so P can be wrong for that week; prefer forward-looking
   numbers (`D = R/d`, ETA) which need no start.
6. **Missing windows.** `rate_limits` absent before the first reply, for API-key users, and per window after its
   `resets_at` passes. Verified Ultra: no `five_hour`; Pro/Max (and unverified Ultra): both. The formula runs per
   window present; `five_hour` caps the hourly allowance: `H = min(H_7d, R_5h/T_5h)`.
7. **Clock skew.** `resets_at` is server epoch, `now` is the local clock, `updated_at` is the shim's local clock.
   Minutes of skew are harmless for a 7-day window; for 5h clamp `T` to `[0, W]` and treat `T < 0` as "window
   dropped" (CC itself drops it).
8. **Shared pool, many consumers.** All sessions, subagents, workers, both machines and claude.ai web/mobile/Cowork
   draw one pool; one session's stdin can lag another's (cs predict.py:51-57). Merge readings per `resets_at` by max
   `U` and newest time; a per-session token count is never the account's percent. Parallel workers step the burn rate
   (cs "regime boundary"): clip the rate lookback at a fleet change.
9. **Fable percent is invisible** to stdin and hooks (A3); only the undocumented endpoint has it (A5, out of bounds
   for VULYK). Use the estimate (B5 d) and say it is one.
10. **StopFailure `rate_limit`** is the only hard signal in hooks and arrives after the wall is hit; useful as a
    calibration point (U = 100 at that moment for the binding window) and to stop the Workflow driver cleanly.

| # | Source | What it settles | Opened |
|---|---|---|---|
| L1 | `~/.claude/limits_state.json` | shim output shape, Ultra has no `five_hour` | 2026-11-02 |
| L2 | a personal statusline shim | shim mechanics | 2026-11-02 |
| L3 | `~/.cache/claude-statusbar/{last_stdin,rate_latest.*,quota/*}.json` | full stdin shape, no model buckets, no series | 2026-11-02 |
| L4 | `claude_statusbar/predict.py` (cs 3.52.3) | forecast algorithm, file:line above | 2026-11-02 |
| W1 | code.claude.com/docs/en/statusline | stdin `rate_limits` schema, presence, triggers, 300 ms debounce | 2026-11-02 |
| W2 | code.claude.com/docs/en/hooks | no `rate_limits` in hooks; StopFailure, quota notifications | 2026-11-02 |
| W3 | claude.com/pricing | Ultra no 5h (verified), 10x weekly, Fable 50 % | 2026-11-02 |
| W4 | support.claude.com/en/articles/17728952-what-is-the-ultra-plan | separate Fable weekly limit, verified check, limit resets | 2026-11-02 |
| W5 | support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan | Fable up to 50 % inside the weekly pool | 2026-11-02 |
| W6 | support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work | fixed weekly reset time per account | 2026-11-02 |
| W7 | notebookcheck.net; framesignal.com (2026-11-01); datastudios.org (2026-10-30) | secondary confirmation of the 2026-10-30 change | 2026-11-02 |
| W8 | github.com/FullFran/claudeops-tui docs/oauth-usage-endpoint.md; docs.rs linesmith-core usage.rs | OAuth endpoint shape, `limits[]` weekly_scoped | 2026-11-02 |
| W9 | github.com/anthropics/claude-code/issues/31637 | endpoint 429s, closed not planned | 2026-11-02 |
| W10 | ccusage.com/guide/blocks-reports | blocks, burn rate, projection, colour thresholds | 2026-11-02 |
| W11 | github.com/Maciek-roboblog/Claude-Code-Usage-Monitor (README v4) | P90 over 192 h, last-hour burn, official-only 7d % | 2026-11-02 |
| W12 | github.com/tillo13/cc-usage (README) | target-landing daily budget, %-per-Mtoken calibration, dedupe by (message.id, requestId) | 2026-11-02 |
| W13 | github.com/Matthew-IDKA/claude-code-statusline; achromichat/usage-quota-bar; asjadaugust/claude-usage-statusline; thevibeworks/claude-code-statusline; mmdemirbas/claude-quota (README extracts via Exa) | pace thresholds and forms in B1 | 2026-11-02 |
| L5 | `~/.claude/projects/<project>/*.jsonl` | transcript usage fields | 2026-11-02 |
