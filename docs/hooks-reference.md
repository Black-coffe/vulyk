# Hooks reference

Wired in `.claude/settings.json`; scripts in `.claude/hooks/`. All scripts fail open (`exit 0` on any missing dependency) - VULYK never blocks your session because `jq` is absent.

| Script | Event | Behavior |
|---|---|---|
| `session-start-brief.sh` | SessionStart | Prints one `[VULYK]` line into context: newest map slice + its date, learnings awaiting GC, post-merge staleness flag, "start at memory/memory.md". Cheap situational awareness on every session. |
| `session-end-learnings.sh` | SessionEnd | Writes `memory/learnings/<timestamp>.md`. Default: an editable stub. With `VULYK_AUTOLEARN=1` + `claude` CLI available: distills the transcript tail via one headless Haiku call; writes nothing if the session was routine. |
| `skill-usage-counter.sh` | PostToolUse, matcher `Skill` | Increments `{count, last_used}` per skill in `memory/stats/skills.json` (requires `jq`; silently no-ops without it). Fuel for `skill-gardener`. |
| `context-guard.sh` | PreCompact | Snapshots `memory/memory.md` + all spec `status:` lines to `memory/snapshots/<timestamp>/` so compaction never destroys orchestration state. Librarian prunes snapshots >14 days. |

Plus one **git** hook sample (not a Claude Code hook): `scripts/git-hooks/post-merge` touches `memory/map/.stale` after merges; `/vulyk-status` and the session brief surface it. Install per the comment in the file.

Customizing: hooks receive JSON on stdin (see Anthropic's hooks docs for the schema per event); keep scripts fast and fail-open, and prefer writing signals to `memory/` over doing heavy work inline.
