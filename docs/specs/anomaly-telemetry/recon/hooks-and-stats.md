# Scout report: hooks & stats writers (anomaly-telemetry spec)

Scout: drone-scout `scout-hooks`, 2026-09-14. Persisted by the Queen (the scout has no Write tool).

## Purpose
Every hook wired in `.claude/settings.json:4-54`, the context-measurement function a new hook should reuse, the redaction pipeline, every `memory/stats/*.jsonl` writer and its readers, and how install.sh classifies new framework files.

## 1. Hook wiring (`.claude/settings.json:4-54`)
- **SessionStart**: `session-start-brief.sh:1-18` (counts learnings, map staleness; echoes one line, writes nothing) · `top-model-brief.sh:1-47` (resolves top model via `scripts/top-model.sh`; `VULYK_TOP_MODEL_BRIEF=0` disables) · `vulyk-update-check.sh:1-90` (reads `.claude/vulyk-version`, GitHub tags API rate-limited via `.claude/.vulyk-update-cache`; env `VULYK_UPDATE_CHECK`, `VULYK_UPDATE_INTERVAL_HOURS`, `VULYK_REPO`, `GITHUB_TOKEN`) · `handoff.sh sessionstart`.
- **SessionEnd**: `session-end-learnings.sh:1-41` (stdin `.transcript_path`; writes `memory/learnings/<TS>.md`; with `VULYK_AUTOLEARN=1` distils via `claude -p --model sonnet`, piped through `redact()`) · `handoff.sh sessionend`.
- **UserPromptSubmit**: `handoff.sh prompt`. **Stop**: `handoff.sh stop`.
- **PostToolUse** (matcher `Skill`): `skill-usage-counter.sh:1-19` - stdin `.tool_input.skill_name`; requires `memory/stats/skills.json`; jq increment + atomic mv.
- **PreCompact**: `context-guard.sh:1-14` (snapshots `memory/memory.md` + spec status lines into `memory/snapshots/<TS>/`) · `handoff.sh precompact` (forced dump).
- All hooks: fail-open bash, `set -uo pipefail`, early `exit 0` on missing prerequisites.

## 2. Context-size measurement to reuse: `.claude/hooks/handoff.py:388-414` `context_tokens(transcript_path)`
Reads the transcript tail (`iter_tail_lines` :310-330, `parse_entries` :333-343), walks newest-first, skips `isSidechain: true`, returns the newest main-thread `assistant` entry with `message.usage`: `total = input_tokens + cache_read_input_tokens + cache_creation_input_tokens + output_tokens` = **current context size**, not cumulative spend. Returns `(tokens, model, utc_ts)`. `transcript_path` comes from the hook payload (`handoff.py:625`); fallback `newest_transcript_for_cwd(cwd)` (:417-428) finds the newest `*.jsonl` under `~/.claude/projects/<slugify(cwd)>/`. Window detection for percentages: `detect_window()`/`resolve_window()` (:245-293).

## 3. `session-end-learnings.sh` + `scripts/redact.sh`
- Stub file by default; with `VULYK_AUTOLEARN=1` 1-6 bullets, or nothing on `NOTHING_NOTEWORTHY`. `redact()` (:12-14) = `bash scripts/redact.sh` else `cat`.
- `redact.sh:1-59`: deterministic sed/awk, exits 0, degrades to `cat`. Masks to `[VULYK:REDACTED]`: AWS keys, GitHub tokens, Slack, OpenAI `sk-`, Google `AIza`, JWTs, `Bearer`, `user:pass@` URLs, PEM blocks, and `key=value` pairs whose key matches password/secret/api key/access key/auth token/client secret/private key (value >= 6 chars).
- **Does NOT mask**: file paths, repo names, usernames, emails, IPs.
- `handoff.py:577-618` `_REDACT_FALLBACK` mirrors the pattern list; extend both together (:575-576).

## 4. `memory/stats/*` writers and readers
| File | Writer | Row fields | Readers |
|---|---|---|---|
| `scope.jsonl` | `scripts/scope-check.sh:100-104` | `{ts, story, declared, changed, out_of_scope}` | none by script |
| `ship.jsonl` | `scripts/ship-check.sh:52-57` (`--record`) | `{ts, spec, version, head, pack, note}` | none |
| `human.jsonl` | `scripts/human-check.sh:126-129` | `{ts, spec, verdict, by, head, pack, note}` | `ship-check.sh:151-171`, `/vulyk-evolve` step 2 |
| `acceptance.jsonl` | `scripts/acceptance-log.sh:148-150` | `{ts, spec, verdict, stories, done, blocked, unrecognised, drift, head, pack, note}` | `ship-check.sh:219-236` |
| `council.jsonl` | `scripts/cycle.sh:867-871` (`cmd_judge`), `:662-666` (escalate), `:1736` (STALE) | `{ts, spec, round, verdict, head, pack, asks, red[], red_unevidenced[], na, review, haiku, haiku_model, sonnet, sonnet_model, opus, opus_model, attempts, escalate, note}` | `ship-check.sh:155-217`, `/vulyk-status` step 2, `/vulyk-evolve` step 2, `cycle.sh:242-252` |
| `skills.json` | `.claude/hooks/skill-usage-counter.sh:14-17` | `{<skill>: {count, last_used}}` | `/vulyk-status` step 6, `/vulyk-evolve` step 1 |

All writers: shell, append-only `printf >> file`, `mkdir -p memory/stats` first; free-text notes go through `redact.sh`. Shared helpers in `scripts/lib.sh:16-32` (`pack_fingerprint`, `paperwork_only`, `marker`) and `is_paperwork_path()` (:42-48) - **the whitelist a new `memory/stats/*.jsonl` must join** to count as paperwork for staleness/dirty-tree checks.

## 5. `install.sh` ownership and gitignore
- `OWNED` (`install.sh:34`): `.claude/agents .claude/commands .claude/hooks .claude/skills/_meta .claude/workflows bootstrap templates scripts`. `memory/` is not owned: never synced or removed on upgrade.
- `shippable()` (:49-66): `memory/snapshots/*` and `memory/map/.stale` are runtime (2); other `memory/*` ships. A new `memory/stats/anomalies.jsonl` in VULYK's own tree would ship as content unless added to the runtime cases.
- `ensure_gitignore()` (:431-456) `wanted` list has no `memory/stats/` entry; live `.gitignore:1-36` confirms. **`memory/stats/*` is committed in a hive.**
- Precedent seed: `install.sh:542` seeds `memory/stats/skills.json` with `{}` if absent. `.jsonl` files need no seed.
- A per-machine gitignored path (e.g. `.claude/telemetry.json`) needs entries in both `shippable()` and `ensure_gitignore()`; no precedent exists.

## 6. Per-subagent cost after a dispatch - confirmed on a real file
- Plain dispatches: `~/.claude/projects/<slug>/<session>/subagents/agent-a<name>-<hash>.jsonl` (+ `.meta.json`).
- Workflow-driven: `<session>/subagents/workflows/<wf_id>/agent-a<hash>.jsonl`, plus `journal.jsonl` per workflow and `<session>/workflows/<wf_id>.json`.
- First assistant entry of `agent-aarchitect-story01-d47569ce098044db.jsonl` (line 10): `"type":"assistant"`, `"isSidechain":true`, `"agentId"`, `"message":{"model":"claude-fable-5-1", "usage":{"input_tokens":2,"cache_creation_input_tokens":22233,"cache_read_input_tokens":0,"output_tokens":2}}` - the shape `context_tokens()` reads. Pointed at a subagent's own file the `isSidechain` skip must be bypassed (the entries all carry it).

## Answers
1. Reuse `handoff.py` `context_tokens()` for context size; for a subagent's spend sum `cache_creation + input` over its own file (first turn = fixed prefix cost).
2. `memory/stats/` is committed; a new `anomalies.jsonl` needs only its writer's `mkdir -p`, plus a line in `is_paperwork_path()`. A per-machine file needs `shippable()` + `ensure_gitignore()` entries.
3. Per-subagent usage is readable today from the subagent jsonl paths above, same summing logic.
