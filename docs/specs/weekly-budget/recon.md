# Recon: weekly-budget (2026-11-02)

Condensed from two `drone-scout` reports (scout-fable and scout-surfaces). The scouts have no Write tool, so this file was written by the Queen.

## Model choice and Fable (scout-fable)

### Where the model is chosen
- `scripts/top-model.sh:147-171` resolves the gate model. The order is: env `VULYK_TOP_MODEL`, then the constitution's `TOP_MODEL`, then the profile, then the plan from `~/.claude.json` (lines 91-122), then `opus`. `second_reviewer()` is at 188-195, `--floor` at 236-323.
- `scripts/model-profile.sh:66-96` (`role_of`) maps each role to a model family. The profile is stored in `~/.claude/vulyk-model-profile` and takes one of `opus-builds`, `sonnet-builds` (the default) or `economy`.
- `scripts/lib.sh:316-317` holds the `model_floor`: fable 5.1, opus/sonnet/haiku 5.5. This floor is version-pinned and must be updated for Fable 5.5.
- `.claude/workflows/vulyk-cycle.js`:
  - Model arguments are at 57-64.
  - `RETRY` is at 64, and `FALLBACK_MODEL='opus'` at 66.
  - The refusal detector is at 46-52.
  - `dispatch()` (the fallback) is at 132-143.
  - A story's own `model:` overrides `WORKER`.
- `.claude/commands/vulyk-build.md:33-62` dispatches and resolves models; fallback records are at 100-113.
- `.claude/commands/vulyk-plan.md:59-74` dispatches the Tier 4 planner and architect on `top_model` and holds the Fable fallback.

### Agent frontmatter

| Agent | Model | Effort |
|---|---|---|
| lead-review | opus | high |
| queen-planner | opus | high |
| lead-architect | opus | high |
| worker-code | sonnet | medium |
| council-opus | opus | medium |
| cycle-clerk | haiku | low |

### How spend is measured today
- `scripts/token-report.py` counts weighted tokens from transcripts after the fact. `READ_RATE` at line 55 is keyed to `fable-5-1`, which is version-pinned.
- `scripts/telemetry.sh` has `fable_limit_fallback` and `model_below_floor` in its ENUM.
- Nothing tracks spend live, and nothing knows about limits.

### fable-fallback (0.39.0)
- It is reactive: it acts only after Fable refuses. It matches only the Fable refusal, not `usage_limit_reached` (the 5h limit) and not Opus/Sonnet limits.

### fable-budget report (2026-10-27)
- Account 1: Fable was 40% of weighted spend and the weekly bar reached 80%. Account 2: Fable 17%, weekly bar 41%.
- Judges took most of the Fable spend: hive judge scripts at xhigh cost $259, and VULYK judges cost $260 (lead-review $144, council-opus $57, queen-planner $44).
- Shipped: the opus fallback, a gate-scope hint and `cacheTtl 1h`.
- Left to the owner: lowering effort from xhigh to high.

### Doc contradiction
`docs/model-cascade.md` says the half-of-week Fable cap "is never reached by design". The fable-budget study contradicts this.

## Surfaces (scout-surfaces)

### Hooks
- `.claude/settings.json:3-69` wires the hooks for SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, Stop, PostToolUse and PreCompact. There is no `statusLine` entry.
- `.claude/hooks/handoff.py` is the only hook that warns by percentage (thresholds 55/70/82, line 62).
  - `mode_stop` (783-805) shows a `systemMessage` banner to the user, once per level.
  - `mode_prompt` (808-835) adds `additionalContext` at level 2 and above, once per level.
- `handoff.py:197-239` reads the claude-statusbar cache `sessions/<id>/last_stdin.json`, i.e. the raw statusline JSON. It uses only `context_window_size`. This is prior art for reading statusline data through a personal tool.
- `.claude/hooks/top-model-brief.sh:80` writes a one-line `[VULYK] gate model` into context. It has an off switch, `VULYK_TOP_MODEL_BRIEF=0`. It is the template for a budget line.

### Commands and the cycle
- `/vulyk-status` step 9, "Budget posture" (`vulyk-status.md:53-55`), shows only `top-model.sh --explain`. It computes no pace.
- `scripts/cycle.sh`:
  - `pause_guard` (169-175) makes every mutating verb exit 3 when `<spec>/PAUSE` exists. `pause`/`resume` are at about 2907-2941.
  - A budget gate could write `PAUSE`.
  - There is no pre-dispatch budget check.

### Install and the pulse mod
- `install.sh:60`: `OWNED` paths are overwritten on upgrade.
- `install.sh:707-905` wires hooks into `settings.json` additively, keeping a `.vulyk-bak`. There is no statusLine handling.
- The pulse mod (`vulyk-pulse@vulyk`, user scope, terminal only) shows wave, time and ≈tokens from live per-response usage. It has no weekly figure and costs no model call.

### Cost per turn
- SessionStart output and `additionalContext` are added once and then read from cache on every turn.
- A `systemMessage` is free for the model.
- A budget warning needs once-per-level state, as `handoff.py` has.

## Probe: headless /usage as the data source (Queen, 2026-11-02, Claude Code 2.1.316, Windows)

- How to call it: `MSYS_NO_PATHCONV=1 claude -p "/usage" --output-format stream-json --verbose`. In Git Bash, without `MSYS_NO_PATHCONV=1` the argument is rewritten to `C:/Program Files/Git/usage`. It is then sent to the model as a prompt, which cost $0.19 in the first probe.
- Result: `total_cost_usd: 0`. It is a local command (`local_command_run: {command: usage}`) and makes no model call. It took about 14.6 s.
- The `usage_report.rate_limits.limits[]` rows contain:
  - `{kind: weekly_all, group: weekly, percent: 32, resets_at: 2026-11-05T08:00Z, severity: normal, is_active: true}`;
  - `{kind: weekly_scoped, percent: 15, scope.model.display_name: Fable, is_active: false}`.
  - Docs also name `kind: session`, which is the 5h window where it exists. Plus `extra_usage`.
- The text also gives a "What's contributing" breakdown for the last 24 h and 7 d: top subagents, skills and MCP shares, plus tips. Last 7 d: worker-code 13%, general-purpose 12%, lead-review 4%, council-opus 2%.
- Any `claude -p` call that reaches the API also emits `rate_limit_event`, with `unifiedWindows.seven_day.utilization` (0.31) and `resetsAt`.
- What this means for the design:
  - An official data source exists that works for every owner, needs no statusline and no auth code in VULYK, and respects the account (Claude Code's own config dir).
  - It is the only source that gives the separate Fable share.
  - It is too slow to call on every hook, so it needs caching and a sampling interval.
  - The SDK docs mark it "experimental".
