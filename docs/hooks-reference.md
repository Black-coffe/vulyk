# Hooks reference

Wired in `.claude/settings.json`; scripts in `.claude/hooks/`. All scripts fail open (`exit 0` on any missing dependency) - VULYK never blocks your session because `jq` is absent.

| Script | Event | Behavior |
|---|---|---|
| `session-start-brief.sh` | SessionStart | Prints one `[VULYK]` line into context: newest map slice + its date, learnings awaiting GC, post-merge staleness flag, "start at memory/memory.md". Cheap situational awareness on every session. |
| `top-model-brief.sh` | SessionStart | Prints one `[VULYK] gate model: ...` line: the gate alias `scripts/top-model.sh` resolved (`fable` on Max and premium seats, `opus` on Pro, standard seats and API), the plan it was read from, the Tier 4 second-reviewer pairing, and whether the Queen's own session is pinned to `opus` in `.claude/settings.local.json` (ADR-012). Reads only; the pin is `scripts/top-model.sh --apply`, a decision. Silent without the resolver. Disable with `VULYK_TOP_MODEL_BRIEF=0`. |
| `anomaly-scan.sh` | SessionEnd | Runs `scripts/telemetry.sh scan` once per session: the anomaly detectors write local rows to `memory/stats/anomalies.jsonl` ([telemetry.md](telemetry.md)). Silent and fail-open. Since 0.18.0 it is no longer wired on `Stop`; an upgrade unwires that. |
| `skill-usage-counter.sh` | PostToolUse, matcher `Skill` | Increments `{count, last_used}` per skill in `memory/stats/skills.json` (requires `jq`; silently no-ops without it). Fuel for `skill-gardener`. |
| `vulyk-update-check.sh` | SessionStart | Reads the installed version from `.claude/vulyk-version` and the newest `v*` tag from the origin's GitHub API, at most once per `VULYK_UPDATE_INTERVAL_HOURS` (default 24; answer cached in `.claude/.vulyk-update-cache`, which is gitignored). Prints one `[VULYK]` line **only** when the origin is genuinely ahead, and that line instructs the model to ask you before doing anything. Silent with no stamp (the source repo itself), with no `curl`, on a network failure, on a rate limit, and whenever you are running ahead of the tags. Disable with `VULYK_UPDATE_CHECK=0`; point at a fork with `VULYK_REPO=owner/name` or a `.claude/vulyk-origin` file. |
| `context-guard.sh` | PreCompact | Snapshots `memory/memory.md` + all spec `status:` lines to `memory/snapshots/<timestamp>/` so compaction never destroys orchestration state. Librarian prunes snapshots >14 days. |
| `handoff.sh` → `handoff.py` | Stop · UserPromptSubmit · PreCompact · SessionEnd · SessionStart | Context-budget guard + session handoff. Warns as context grows, auto-dumps session state to `.claude/handoff/` on `/clear`, exit and before compaction, and restores the freshest handoff into the session that follows a `/clear` or a compaction. Details below. |

The learnings hook (`session-end-learnings.sh`) was removed in 0.18.0 (ADR-013 D7): it wrote empty
stubs. An upgrade deletes it and its `SessionEnd` wiring unless you edited the script.

## Session handoff (`handoff.py`)

Claude Code hooks receive **no token counter** — but every hook gets `transcript_path`, and each assistant entry in that JSONL carries `message.usage`. The true context size is `input + cache_read + cache_creation + output` of the last **non-sidechain** assistant entry (sidechain = subagent; counting those skews the number). That measurement drives everything:

- **Escalating warnings** (Stop → banner to the user; UserPromptSubmit → context injected to the model) at **55% / 70% / 82% of the context window** by default. Each level fires **once per session** — a noisy hook is worse than no hook.
- **Cache warmth.** From level 2 the warning also carries how long the prompt cache has left. The same transcript entry that yields the token count carries its `timestamp`, so the age of the last turn is free to compute — and it decides the *price* of acting on the warning: compacting or checkpointing re-reads the conversation, which is a cache hit inside the TTL and a full-price re-prefill after it. The banner therefore says "warm for ~55 more min", "expires in ~5 min", or "expired anyway — no reason to delay". Default TTL is 60 min (subscription plans); set `cache_ttl_minutes: 5` in the config if you run on an API key without `ENABLE_PROMPT_CACHING_1H=1`. Transcripts without a parseable timestamp simply drop the clause. See [token-economy.md](token-economy.md).
- **Auto-dump** of a mechanical handoff (`git` state, last TodoWrite, touched files, recent prompts, last reply) on SessionEnd (`/clear`, exit) and PreCompact. Sessions under 25k tokens are not worth dumping and are skipped (PreCompact always dumps). The dump passes through `scripts/redact.sh` before it is written — handoffs are gitignored but re-injected into future sessions and routinely shared.
- **`/vulyk-handoff`** writes the same skeleton on demand, then the model enriches its `## Summary` section — decisions, dead ends, next step. See the command reference.
- **Restore** on SessionStart: after `/clear` or compaction only, cut to 4 000 characters (`restore_max_chars`). A plain startup or a `fork` starts on its own topic, and a `resume` still carries its own context, so none of them restores (changed in 0.18.0: a plain startup used to restore any handoff younger than 12 h, whatever it was about).

**The window is detected, never assumed.** A percentage needs a denominator, and the hook payload does not carry one: `context_window_size` exists only in statusLine input, and the transcript records the model without its `[1m]` suffix. So `handoff.py` asks, strictest source first — a `context_limit` pin in the config; Claude Code's own `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_CODE_DISABLE_1M_CONTEXT`; the statusLine JSON [claude-statusbar](https://pypi.org/project/claude-statusbar/) caches on disk (its per-session copy, then the global one, and only when this session rendered it — every Claude Code window overwrites that file); the window this session was already seen to have; and finally the measurement itself, since a session past 200k tokens proves the window is the large one. Failing all of that it assumes the stock 200k.

Where the statusbar could answer but this tick could not tell (another window rendered last), the hook **says nothing** instead of dividing by a guess: a wrong denominator is what makes a guard untrustworthy. Machines without the statusbar keep the plain 200k behaviour.

Storage is project-local and gitignored: documents in `.claude/handoff/`, pointer in `.claude/handoff/index.json`, per-session anti-spam state in `.claude/handoff/state/` (self-pruned after 7 days, and where the detected window is remembered). Override defaults (`thresholds_pct`, absolute `thresholds`, `context_limit` to pin the window, `cache_ttl_minutes`, `restore_max_chars`, `enabled`) in `.claude/handoff.config.json`.

Requires Python 3 on PATH (`python3`, `python` or `py`); the `handoff.sh` wrapper fails open without it, per the VULYK contract. Diagnose with `bash .claude/hooks/handoff.sh status`.

Plus one **git** hook sample (not a Claude Code hook): `scripts/git-hooks/post-merge` touches `memory/map/.stale` after merges; `/vulyk-status` and the session brief surface it. Install per the comment in the file.

Customizing: hooks receive JSON on stdin (see Anthropic's hooks docs for the schema per event); keep scripts fast and fail-open, and prefer writing signals to `memory/` over doing heavy work inline.
