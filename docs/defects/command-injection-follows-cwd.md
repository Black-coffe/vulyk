---
id: command-injection-follows-cwd
title: A command's injection names its script relative to the session cwd
status: block
check: bash scripts/injection-check.sh <arg>
fixtures: [docs/defects/command-injection-follows-cwd.original.fixture, docs/defects/command-injection-follows-cwd.fenced.fixture, docs/defects/command-injection-follows-cwd.bare.fixture]
keys: [No such file or directory, Shell command failed for pattern]
paths: [".claude/commands/*.md", ".claude/skills/**/SKILL.md"]
---

# A command's injection names its script relative to the session cwd
A slash command or skill runs its `!` injections in the session's shell cwd before the model sees the prompt, and
Claude Code keeps a Bash `cd` that stays inside the project. An injection such as `` !`bash scripts/state.sh` `` works
from the project root and aborts the whole command the moment the session has drifted into a subfolder.

## Owner quotes
- 2026-10-13 · /vulyk-handoff · E:/Projects/AI — «Пытаюсь сделать в проектах work handoff и получаю ошибки. Ты можешь разобраться, в чём проблема, почему так выходит и как это побороть?» (the screenshot: «Shell command failed for pattern "!`bash scripts/state.sh`": [stderr] bash: scripts/state.sh: No such file or directory»)

## Cause
`vulyk-handoff.md` named `scripts/state.sh` and `.claude/hooks/handoff.sh` relative to the cwd (v0.3.0, v0.9.1). The
model's own `cd <hive>/docs/specs/<client>/... && ...` moved the session cwd, Claude Code kept it because it stays
inside the project, and the injection then ran from that subfolder.

## Never
- Name an injection's script by a relative path: write `"${CLAUDE_PROJECT_DIR}/scripts/x.sh"` (a skill's own files:
  `"${CLAUDE_SKILL_DIR}/..."`), and give `allowed-tools` the same prefix.
- Trust `os.getcwd()` as the project root in a script an injection runs: root it at its own location or at
  `CLAUDE_PROJECT_DIR`.

## Allowed
- A plain command on PATH (`` !`git status --short` ``): it names no script.
