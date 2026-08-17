# Hooks reference

Wired in `.claude/settings.json`; scripts in `.claude/hooks/`. All scripts fail open (`exit 0` on any missing dependency) - VULYK never blocks your session because `jq` is absent.

| Script | Event | Behavior |
|---|---|---|
| `session-start-brief.sh` | SessionStart | Prints one `[VULYK]` line into context: newest map slice + its date, learnings awaiting GC, post-merge staleness flag, "start at memory/memory.md". Cheap situational awareness on every session. |
| `session-end-learnings.sh` | SessionEnd | Writes `memory/learnings/<timestamp>.md`. Default: an editable stub. With `VULYK_AUTOLEARN=1` + `claude` CLI available: distills the transcript tail via one headless Haiku call; writes nothing if the session was routine. Distilled output is piped through `scripts/redact.sh` — learnings are committed to git. |
| `skill-usage-counter.sh` | PostToolUse, matcher `Skill` | Increments `{count, last_used}` per skill in `memory/stats/skills.json` (requires `jq`; silently no-ops without it). Fuel for `skill-gardener`. |
| `context-guard.sh` | PreCompact | Snapshots `memory/memory.md` + all spec `status:` lines to `memory/snapshots/<timestamp>/` so compaction never destroys orchestration state. Librarian prunes snapshots >14 days. |
| `handoff.sh` → `handoff.py` | Stop · UserPromptSubmit · PreCompact · SessionEnd · SessionStart | Context-budget guard + session handoff. Warns as context grows, auto-dumps session state to `.claude/handoff/` on `/clear`, exit and before compaction, and restores the freshest handoff into the next session. Details below. |

## Session handoff (`handoff.py`)

Claude Code hooks receive **no token counter** — but every hook gets `transcript_path`, and each assistant entry in that JSONL carries `message.usage`. The true context size is `input + cache_read + cache_creation + output` of the last **non-sidechain** assistant entry (sidechain = subagent; counting those skews the number). That measurement drives everything:

- **Escalating warnings** (Stop → banner to the user; UserPromptSubmit → context injected to the model) at 110k / 140k / 165k tokens by default. Each level fires **once per session** — a noisy hook is worse than no hook.
- **Cache warmth.** From level 2 the warning also carries how long the prompt cache has left. The same transcript entry that yields the token count carries its `timestamp`, so the age of the last turn is free to compute — and it decides the *price* of acting on the warning: compacting or checkpointing re-reads the conversation, which is a cache hit inside the TTL and a full-price re-prefill after it. The banner therefore says "warm for ~55 more min", "expires in ~5 min", or "expired anyway — no reason to delay". Default TTL is 60 min (subscription plans); set `cache_ttl_minutes: 5` in the config if you run on an API key without `ENABLE_PROMPT_CACHING_1H=1`. Transcripts without a parseable timestamp simply drop the clause. See [token-economy.md](token-economy.md).
- **Auto-dump** of a mechanical handoff (`git` state, last TodoWrite, touched files, recent prompts, last reply) on SessionEnd (`/clear`, exit) and PreCompact. Sessions under 25k tokens are not worth dumping and are skipped (PreCompact always dumps). The dump passes through `scripts/redact.sh` before it is written — handoffs are gitignored but re-injected into future sessions and routinely shared.
- **`/vulyk-handoff`** writes the same skeleton on demand, then the model enriches its `## Summary` section — decisions, dead ends, next step. See the command reference.
- **Restore** on SessionStart: after `/clear` or compaction — always; on plain startup — only if the handoff is younger than 12 h and not already consumed; on `resume`/`fork` — never (the context is still there).

Storage is project-local and gitignored: documents in `.claude/handoff/`, pointer in `.claude/handoff/index.json`, per-session anti-spam state in `.claude/handoff/state/` (self-pruned after 7 days). Override defaults (thresholds, `context_limit` — set `1000000` on a 1M-context model, `cache_ttl_minutes`, `enabled`) in `.claude/handoff.config.json`.

Requires Python 3 on PATH (`python3`, `python` or `py`); the `handoff.sh` wrapper fails open without it, per the VULYK contract. Diagnose with `bash .claude/hooks/handoff.sh status`.

Plus one **git** hook sample (not a Claude Code hook): `scripts/git-hooks/post-merge` touches `memory/map/.stale` after merges; `/vulyk-status` and the session brief surface it. Install per the comment in the file.

Customizing: hooks receive JSON on stdin (see Anthropic's hooks docs for the schema per event); keep scripts fast and fail-open, and prefer writing signals to `memory/` over doing heavy work inline.
