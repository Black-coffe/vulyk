---
story: audit-fixes-1113-05
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [audit-fixes-1113-01, audit-fixes-1113-02]
red: required
red_reason: a subagent session start prints nothing
red_verified_at: 2026-11-13T21:31:44Z 88fab6f564035645d09ace9985250b3936c29d4eddb0be1dd3e0148166d27637
---

# Session hooks stay silent for a subagent; the brief names a missing Python and a template copy; the counter counts VULYK's own skills

## Goal
Four changes in the hooks a session starts with.
1. Every hook `.claude/settings.json` wires on SessionStart or PreCompact exits 0 with no output and no write when
   its input is a subagent's (plan.md `## Contracts` H1). For the handoff that means: a subagent is offered no
   handoff and marks none as read. First confirm against the installed Claude Code that these two events carry
   `agent_id` for a subagent; write what you found in the notes.
2. The SessionStart brief prints one line when no Python 3 answers in the hooks' launcher order (`$VULYK_PY`,
   python3, python, py; the Windows Store stub counts as missing), naming what is limited without it.
3. The GitHub template quick start leaves `README.md` and `docs/getting-started.md`. One recovery line stays for
   people who used it: what such a copy holds that is VULYK's own, and that `install.sh` run from a VULYK clone
   gives the repo its version stamp, permissions and hook wiring. The brief recognises such a copy (VULYK's own
   spec folders, `install.sh` at the root, no `.claude/vulyk-version`, no `v*` tag) and prints one line pointing at
   that recovery text.
4. `.claude/hooks/skill-usage-counter.sh` counts only a skill whose folder is under the project's
   `.claude/skills/` and a `vulyk-*` command; other names are not written, and keys already in the file that fail
   the rule are dropped on the next write. The file stays `memory/stats/skills.json`, local and gitignored. The
   brief's clean-tree exception for it goes.

Marked red: new branches in hooks every session runs.

## Requirements
> 16. SessionStart and PreCompact hooks exit silently for a subagent (the input carries `agent_id`).
> 6. git-guard without Python: a pure-bash fallback with the same verb list (a test compares both lists) still denies the work-losing verbs in Bash and PowerShell; a real interpreter that crashes on a git command denies it; the SessionStart brief says when Python is missing.
> 18. The GitHub template quick start leaves README and getting-started, with a recovery line for people who used it. The SessionStart brief recognises such a copy (VULYK's own specs, no `.claude/vulyk-version`). The repo's template flag is switched off at the next publish, on the owner's word.
> 2. `memory/stats/skills.json` is no longer tracked (`git rm --cached`, gitignored) and public history is not rewritten. It counts only VULYK's own skills and `vulyk-*` commands and lives locally. `install.sh` does not ship it, no ship step commits it, and the clean-tree exceptions made for it are gone.

## Files
- .claude/hooks/session-start-brief.sh
- .claude/hooks/context-guard.sh
- .claude/hooks/ysk-offer.sh
- .claude/hooks/vulyk-update-check.sh
- .claude/hooks/top-model-brief.sh
- .claude/hooks/handoff.py
- .claude/hooks/handoff.sh
- .claude/hooks/skill-usage-counter.sh
- README.md
- docs/getting-started.md
- tests/maintenance.test.sh
- tests/handoff-hooks.test.py
- tests/handoff.test.sh
- .claude/hooks/defects-inject.sh

## Non-goals
- Do not switch the repository's template flag, push, or call the GitHub API: that is the owner's step at publish.
- Do not untrack `memory/stats/skills.json` or edit `.gitignore`: the Queen did both before wave 1. If the test of
  the last criterion is red because the file is still tracked, return `NEEDS_CONTEXT`.
- Do not change the Stop, UserPromptSubmit or SessionEnd hooks, the handoff thresholds or the redact fallback
  (story 02 landed it).
- Do not remove a hook, a snapshot or a brief line: dead mechanisms are a later spec. A hook `settings.json` wires
  on these two events that is not in `## Files` is `NEEDS_CONTEXT`, naming it.
- Do not rewrite other README sections; the hook and command tables are the later docs spec.
- Do not edit `tests/maintenance.test.sh` outside the brief, hook and counter blocks (story 07 owns the git-guard
  block in wave 3).

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`session-start-brief.sh`, `vulyk-update-check.sh`, `handoff.py`,
`handoff.sh`), Gotchas; `memory/map/scripts-checks.md` → Tests (`tests/maintenance.test.sh`).

## Acceptance criteria
- [ ] `tests/maintenance.test.sh` derives the SessionStart and PreCompact commands from `.claude/settings.json`
  and runs each in a scratch project with an input carrying `agent_id`: stdout is empty, the exit is 0, no file
  under the scratch project is created or changed, and the update check makes no network call (stub). The label
  contains `a subagent session start prints nothing`. The same inputs without `agent_id` behave as before.
- [ ] `tests/handoff-hooks.test.py`: a pending handoff is not delivered to a subagent's SessionStart and is still
  delivered, once, to the main session's next one; a subagent's PreCompact writes no dump.
- [ ] With no working Python on PATH (stubs that fail to launch, `VULYK_PY` unset) the brief prints exactly one
  line starting `[VULYK] no Python 3 found`; with Python present it prints none.
- [ ] In a scratch copy shaped like a template copy the brief prints one line naming a template copy and the
  recovery text; in a hive with `.claude/vulyk-version`, and in a source clone with a `v*` tag, it prints none.
- [ ] `README.md` and `docs/getting-started.md` no longer offer the template as a way to start, and each carries
  the recovery line; `maintenance.test.sh` pins both.
- [ ] The counter, fed a Skill event for a project skill, for a `vulyk-*` command and for a skill of neither
  kind: the first two are counted, the third is not written, and a foreign key already in the file is gone after
  the write. The output stays LF, valid JSON.
- [ ] `git ls-files memory/stats/skills.json` prints nothing and `git check-ignore -q memory/stats/skills.json`
  exits 0 in this repo; the brief no longer special-cases the file.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/handoff.test.sh`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (16, 6, 18, 2). -->
- agent_id check (installed Claude Code 2.1.323, read from the binary's bundled JS): the shared hook-input builder sets `agent_id: s?.agentId`; SessionStart passes `{agentId}` into it and PreCompact passes `agentId: r.agentId`, so both events carry `agent_id` for a subagent. Nothing built yet; tree left untouched apart from this file.
- The Findings question above was answered by the plan delta (05: `defects-inject.sh` joined `## Files`); built on that.
- H1 bash hooks (`session-start-brief.sh`, `top-model-brief.sh`, `vulyk-update-check.sh`, `ysk-offer.sh`, `context-guard.sh`): one guard at the top reads stdin (skipped on a terminal, `read -t 1` on a pipe so a shell call never hangs) and exits 0 on a non-empty string `agent_id`.
- H1 `defects-inject.sh`: `reset` with an `agent_id` exits in bash before python starts (python would also write `__pycache__` beside the hook); the PreToolUse path is untouched.
- H1 `handoff.py`: `sessionstart`/`precompact` with an `agent_id` emit nothing right after the payload read, before config or state; `handoff.sh` needed no change (stdin passes through).
- Brief, ask 6: probes `$VULYK_PY`, python3, python, py by running `-c` with a version check (one Python start per session start; a resolving Store alias fails it); one line when none answers.
- Brief, ask 18: template copy = no `.claude/vulyk-version`, `install.sh` at root, `docs/specs/auto-maintenance` or `docs/specs/gate-split`, no `v*` tag; the line points at "Started from the GitHub template" in README.md / docs/getting-started.md. A tagless shallow clone of VULYK would also match.
- Brief, ask 2: the clean-tree exception for `memory/stats/skills.json` is gone from the maintenance line.
- Counter: counts a name with a folder under `.claude/skills/` or a `vulyk-*` name with `.claude/commands/<name>.md`; names with path characters are refused; keys failing the rule are dropped on each write; creates `{}` when `memory/stats/` exists but the file does not (the file is no longer shipped or tracked, so it would otherwise never count).
- README: Option A (template) removed, Option B renamed "Add to a project, new or existing", recovery paragraph added; getting-started: same.
- Tests: `maintenance.test.sh` new H1 block (commands read from `.claude/settings.json`, scratch project with copied hooks/scripts, curl stub, tree checksum before/after, main-session contrast) plus brief/README/counter checks; `handoff-hooks.test.py` H1 cases (no handoff offered or marked to a subagent, delivered once to the main session after, no PreCompact dump).
CHANGELOG: SessionStart and PreCompact hooks exit silently for a subagent: no handoff offered or marked read, no dump, no snapshot, no update-check call, no inject reset (ask 16).
CHANGELOG: The SessionStart brief says in one line when no Python 3 answers in the hooks' launcher order (ask 6).
CHANGELOG: The GitHub template quick start is gone from README and getting-started, a recovery paragraph replaces it, and the brief names a template copy (ask 18).
CHANGELOG: The skill counter counts only project skills and vulyk-* commands and drops foreign keys; the brief no longer exempts skills.json from the clean tree (ask 2).

## Findings
- NEEDS_CONTEXT (Non-goals: "A hook `settings.json` wires on these two events that is not in `## Files` is
  `NEEDS_CONTEXT`, naming it"): `.claude/settings.json` wires `.claude/hooks/defects-inject.sh reset` on
  SessionStart, and that file is not in `## Files`. Its `reset` branch writes for any caller: on `source`
  compact/clear it deletes `.claude/state/defects/inject-<session>.txt` (the file is per session_id, which a
  subagent shares with the main session), on `startup` it prunes week-old `inject-*` files. H1 needs it to exit
  before that when `agent_id` is non-empty. Question: add `.claude/hooks/defects-inject.sh` to this story's
  `## Files` (a one-line `agent_id` exit in the `reset` branch), or rule that it stays out of H1 here?

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 88fab6f564035645d09ace9985250b3936c29d4eddb0be1dd3e0148166d27637 (tests/handoff.test.sh, tests/maintenance.test.sh)
- impl: 1efd4ec98c1741a342530e3ce9b51a7b8fdad1b96147be53f3f49d412a0961d9
- stamped: 2026-11-13T21:31:44Z

```
::error::H1 SessionStart session-start-brief.sh (startup) with agent_id: a subagent session start prints nothing - exit 0, stdout:
::error::H1 SessionStart session-start-brief.sh (clear) with agent_id: a subagent session start prints nothing - exit 0, stdout:
::error::H1 SessionStart top-model-brief.sh (startup) with agent_id: a subagent session start prints nothing - exit 0, stdout:
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 741 checks, 23 failed
```
