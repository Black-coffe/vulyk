#!/usr/bin/env bash
# SessionStart hook: inject a one-line hive brief into context (stdout becomes context).
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEM="$ROOT/memory"
[ -d "$MEM" ] || exit 0

newest_map=$(ls -t "$MEM/map"/*.md 2>/dev/null | head -1)
map_age="no map yet - run /vulyk-bootstrap or /vulyk-map"
if [ -n "${newest_map:-}" ]; then
  map_age="newest map slice: $(basename "$newest_map"), modified $(date -r "$newest_map" +%Y-%m-%d 2>/dev/null || stat -c %y "$newest_map" 2>/dev/null | cut -d' ' -f1)"
fi
echo "[VULYK] $map_age | start at memory/memory.md"

# Maintenance that runs itself (spec auto-maintenance): computed from files and git on every start,
# printed only when something is due, so a quiet hive pays nothing. The Queen runs what is due after
# the owner's task; nobody has to know /vulyk-gc, /vulyk-evolve or /vulyk-map exist.
iso_ago() { date -u -d "-$1 days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; }
first_ts() { awk 'match($0, /"ts":"[^"]*"/) { print substr($0, RSTART+6, RLENGTH-7) }' "$@" 2>/dev/null; }
items=""; skills=""
due() { items="${items:+$items · }$1"; skills="${skills:+$skills, }$2"; }

# gc: stubs left by the pre-0.18 SessionEnd hook, or a raw buffer past /vulyk-status's threshold.
if [ -d "$MEM/learnings" ]; then
  stubs=$(grep -l "Stub captured by VULYK" "$MEM/learnings"/*.md 2>/dev/null | wc -l | tr -d ' ')
  raw=$(find "$MEM/learnings" -maxdepth 1 -name '*.md' ! -name README.md ! -name CONSOLIDATED.md 2>/dev/null | wc -l | tr -d ' ')
  real=$((raw - stubs))
  if [ "$stubs" -gt 0 ] || [ "$real" -ge 10 ]; then due "gc ($stubs stub, $real raw learnings)" vulyk-gc; fi
fi

# evolve: never run, or 7+ days since the last run - and only when a council round was recorded since.
# A changeset still on its branch is waiting for the owner, not due.
def=$(git -C "$ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); def="${def#origin/}"
if [ -z "$def" ]; then
  for b in main master; do git -C "$ROOT" show-ref --verify --quiet "refs/heads/$b" 2>/dev/null && { def="$b"; break; }; done
fi
pending=""
if [ -n "$def" ]; then
  for b in $(git -C "$ROOT" for-each-ref --format='%(refname:short)' 'refs/heads/vulyk/evolve-*' 2>/dev/null); do
    git -C "$ROOT" merge-base --is-ancestor "$b" "$def" 2>/dev/null || pending="${pending:+$pending, }$b"
  done
fi
last_run=""
[ -f "$MEM/stats/evolve.jsonl" ] && last_run=$(grep '"kind":"run"' "$MEM/stats/evolve.jsonl" | first_ts | sort | tail -1)
since=0
[ -f "$MEM/stats/council.jsonl" ] && since=$(first_ts "$MEM/stats/council.jsonl" | awk -v t="$last_run" '$0 > t' | wc -l | tr -d ' ')
if [ -z "$pending" ] && [ "$since" -gt 0 ]; then
  if [ -z "$last_run" ]; then
    due "evolve (never run; $since council rounds on record)" vulyk-evolve
  elif [[ "$last_run" < "$(iso_ago 7)" ]]; then
    over=""
    [[ "$last_run" < "$(iso_ago 28)" ]] && over=" - overdue: ask the owner once whether to retire it (docs/self-evolution.md, Sunset)"
    due "evolve (last run ${last_run%%T*}; $since council rounds since$over)" vulyk-evolve
  fi
fi

# map: the post-merge git hook's flag.
[ -f "$MEM/map/.stale" ] && due "map (flagged stale after a merge: refresh the modules changed since, then delete memory/map/.stale)" vulyk-map

if [ -n "$items" ]; then
  echo "[VULYK] maintenance due: $items. After the owner's current task, on ${def:-the default branch} with a clean tree (memory/stats/skills.json aside: the Skill counter rewrites it), run each through the Skill tool ($skills) without asking, then tell the owner in one line what changed; otherwise leave it for a later session."
fi
[ -n "$pending" ] && echo "[VULYK] evolve changeset $pending waits for the owner's review (merge = accept, delete the branch = reject): tell the owner once."

# litopys, the session chronicle plugin (0.19, plan 1.7): offered once. Installed = an
# `enabledPlugins` key starting `litopys@` in either settings file; declined = a Profile row
# `| Chronicle | none ... |` in the constitution. Either one silences the line for good.
if ! grep -qsE '"litopys@[^"]*"[[:space:]]*:' "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json" &&
   ! grep -qsE '^\|[[:space:]]*Chronicle[[:space:]]*\|[[:space:]]*`?none' "$ROOT/CLAUDE.md"; then
  echo "[VULYK] litopys (session chronicle plugin) is not installed here. Ask the owner once: install (\`claude plugin marketplace add Black-coffe/litopys --scope project\` then \`claude plugin install litopys@litopys --scope project\`) or decline (then add Profile row \`| Chronicle | none (declined <date>) |\`)."
fi
exit 0
