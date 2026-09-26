#!/usr/bin/env bash
# End to end: the real Workflow driver (.claude/workflows/vulyk-cycle.js) against the real
# scripts/cycle.sh in a throwaway git repo. The clerk stub runs the command it is handed; the
# worker, seat and reviewer stubs write what a real agent would (the file, the report, the
# close-story call). driver.test.sh proves the driver against a scripted clerk and the cycle
# suites prove cycle.sh on its own - this is the seam between them (ADR-013 D2, D6).
#
#   Usage: bash tests/e2e.test.sh            # from the VULYK repo root
#
# Two runs: a Tier 3 spec that goes green in one round, and one whose first review BLOCKs on
# an anchored ask - the mechanical repair story, its worker, and a second round that carries
# the green intent seat forward and reviews only the repair diff.
set -u

if ! command -v node >/dev/null 2>&1; then
  echo "skipped: node not found"
  exit 0
fi

SRC="$(cd "$(dirname "$0")/.." && pwd)"
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

make_fixture() { # make_fixture <dir>
  local d="$1"
  mkdir -p "$d" && cd "$d" || exit 1
  git init -q -b main . && git config user.name t && git config user.email t@t
  cp -r "$SRC/scripts" scripts
  cat > CLAUDE.md <<'EOF'
# VULYK Constitution

## Profile

<!-- VULYK:PROFILE:START -->
| Field | Value |
|---|---|
| Client path | `none: library only` |
<!-- VULYK:PROFILE:END -->

## Commands

<!-- VULYK:COMMANDS:START -->
| Purpose | Command |
|---|---|
| App check | `bash check.sh` |
<!-- VULYK:COMMANDS:END -->
EOF
  printf '#!/usr/bin/env bash\ngrep -q fixed app.txt\n' > check.sh
  printf 'broken\n' > app.txt
  printf '.vulyk/\ndocs/specs/*/DRIVER\ndocs/specs/*/PAUSE\n' > .gitignore   # what install.sh writes
  mkdir -p docs/specs/demo memory/stats
  cat > docs/specs/demo/brief.md <<'EOF'
# Brief - demo

## Request (verbatim)

> app.txt says fixed

## Asks

1. app.txt says fixed
EOF
  cat > docs/specs/demo/plan.md <<'EOF'
# Plan - demo

**Tier:** 3 · **Spec slug:** `demo` · **Brief:** [brief.md](brief.md)

**Approved:** owner, 2026-09-26
**Branch:** <written by the build>
**Council:** <written by judge>
**Shipped:** <written by ship-check>
EOF
  cat > docs/specs/demo/demo-01-app.md <<'EOF'
---
story: demo-01
status: todo
returned:
worker: worker-code
model: opus
wave: 1
blocked_by: []
---

# Make app.txt say fixed

## Goal
app.txt says fixed.

## Requirements
> app.txt says fixed

## Files
- app.txt

## Verification
`bash check.sh`
EOF
  git add -A && git commit -q -m init
}

run_driver() { # run_driver <fixture> <scenario>
  FIXTURE="$(winpath "$1")" SCENARIO="$2" DRIVER="$(winpath "$SRC/.claude/workflows/vulyk-cycle.js")" node <<'NODE_EOF'
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const FIX = process.env.FIXTURE;
const SCEN = process.env.SCENARIO;
const src = fs.readFileSync(process.env.DRIVER, 'utf8');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const driverFn = new AsyncFunction('args', 'agent', 'parallel', 'phase', 'log', src.replace(/^export /gm, ''));

const sh = (cmd) => spawnSync('bash', ['-c', cmd], { cwd: FIX, encoding: 'utf8' });
const write = (rel, text) => { const p = path.join(FIX, rel); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, text); };
const reportPath = (prompt) => (prompt.match(/\.vulyk\/reports\/\S+?\.md/) || [])[0];
const S = '0123456789abcdef';
const trace = { clerk: [], agents: [] };
let reviews = 0;

const agent = async (prompt, opts) => {
  const type = opts && opts.agentType;
  if (type === 'cycle-clerk') {
    const cmd = (prompt.match(/^Run exactly: bash scripts\/cycle\.sh (.*)$/m) || [])[1];
    trace.clerk.push(cmd.split(' ').slice(0, 1).concat(cmd.includes('--ingest') ? ['--ingest'] : [], cmd.includes('--claim') ? ['--claim'] : []).join(' '));
    const r = sh('bash scripts/cycle.sh ' + cmd);
    return r.stdout;
  }
  trace.agents.push({ type, prompt });
  if (type === 'worker-code') {
    const file = prompt.match(/Your story: (\S+?)\. /)[1];
    fs.writeFileSync(path.join(FIX, 'app.txt'), file.includes('repair') ? 'fixed, really\n' : (SCEN === 'red' ? 'fixed\n' : 'fixed\n'));
    const story = path.join(FIX, file);
    fs.writeFileSync(story, fs.readFileSync(story, 'utf8').replace(/^returned:.*$/m, 'returned: DONE'));
    const r = sh(`bash scripts/cycle.sh close-story ${file} --commit --stamp ${S}`);
    return r.status === 0 ? 'DONE' : 'close-story failed: ' + r.stdout.split('\n').filter(Boolean).pop();
  }
  if (type === 'council-opus') {
    const text = ['COUNCIL: demo round 1 seat opus', 'MODEL: opus', 'COURT: the court', 'VERDICT: GREEN',
      'ASSUMED CONFIG: single file', 'RAN: grep', 'PATH: app.txt', 'UNASKED: none', 'BREACH: none',
      'ASK 1: GREEN - app.txt says fixed - run: grep fixed app.txt - saw: fixed'].join('\n') + '\n';
    write(reportPath(prompt), text);
    return text;
  }
  if (type === 'lead-review') {
    reviews++;
    const block = SCEN === 'red' && reviews === 1;
    const text = block
      ? 'VERDICT: BLOCK\nMODEL: opus\n\n## Critical\n- [ask 1] app.txt must say it is really fixed - run: grep really app.txt - saw: nothing\n'
      : 'VERDICT: PASS\nMODEL: opus\n\n## Minor\n- none\n';
    write(reportPath(prompt), text);
    return text;
  }
  return 'unexpected agent ' + type;
};
const parallel = (thunks) => Promise.all(thunks.map((t) => Promise.resolve().then(t).catch(() => null)));

(async () => {
  const result = await driverFn({ spec: 'docs/specs/demo', stamp: S, top_model: 'fable', second_model: 'opus' }, agent, parallel, () => {}, () => {});
  console.log(JSON.stringify({ result, trace }));
})().catch((e) => { console.log(JSON.stringify({ crash: String(e && e.stack || e) })); });
NODE_EOF
}

fail=0
expect() { # expect <label> <condition-exit-code>
  if [ "$2" -eq 0 ]; then echo "  ok    $1"; else echo "::error::$1"; fail=1; fi
}
jqr() { printf '%s' "$OUT" | jq -r "$1" 2>/dev/null; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- run 1: green in one round ---------------------------------------------------------------
( make_fixture "$TMP/green" >/dev/null )
OUT="$(run_driver "$TMP/green" green)"
[ -n "${E2E_DEBUG:-}" ] && printf '%s\n' "$OUT" | jq -c '{result, clerk: .trace.clerk, agents: [.trace.agents[].type], crash}'
[ -n "$(jqr '.crash // empty')" ] && { echo "::error::green: driver crashed: $(jqr .crash)"; fail=1; }
expect "green: the run ends green" "$([ "$(jqr '.result.next')" = green ]; echo $?)"
expect "green: four clerk calls - claim, advance, ingest, release" \
  "$([ "$(jqr '.trace.clerk | join(",")')" = "advance --claim,advance,advance --ingest,release" ]; echo $?)"
expect "green: one worker, one intent seat, one reviewer, nothing else" \
  "$([ "$(jqr '[.trace.agents[].type] | sort | join(",")')" = "council-opus,lead-review,worker-code" ]; echo $?)"
cd "$TMP/green" || exit 1
expect "green: the story is done and committed on the spec branch" \
  "$(git log --format=%s vulyk/demo 2>/dev/null | grep -q '^story(demo-01)'; echo $?)"
expect "green: a GREEN ledger row for round 1" "$(grep -q '"round":1,"verdict":"GREEN"' memory/stats/council.jsonl; echo $?)"
expect "green: no court worktree is left behind" "$([ -z "$(git worktree list | sed 1d)" ]; echo $?)"
expect "green: the DRIVER lock is released" "$([ ! -f docs/specs/demo/DRIVER ]; echo $?)"
[ -n "${E2E_DEBUG:-}" ] && git status --porcelain
expect "green: the tree is clean" "$([ -z "$(git status --porcelain)" ]; echo $?)"
cd "$SRC" || exit 1

# --- run 2: an anchored BLOCK, a mechanical repair, a second round on the repair diff ----------
( make_fixture "$TMP/red" >/dev/null )
OUT="$(run_driver "$TMP/red" red)"
[ -n "${E2E_DEBUG:-}" ] && printf '%s\n' "$OUT" | jq -c '{result, clerk: .trace.clerk, agents: [.trace.agents[].type], crash}'
[ -n "$(jqr '.crash // empty')" ] && { echo "::error::red: driver crashed: $(jqr .crash)"; fail=1; }
expect "red: the run ends green after one repair" "$([ "$(jqr '.result.next')" = green ]; echo $?)"
expect "red: two workers - the story and its repair" \
  "$([ "$(jqr '[.trace.agents[] | select(.type=="worker-code")] | length')" = 2 ]; echo $?)"
expect "red: the intent seat runs once - round 2 carries it forward" \
  "$([ "$(jqr '[.trace.agents[] | select(.type=="council-opus")] | length')" = 1 ]; echo $?)"
expect "red: the reviewer runs twice" \
  "$([ "$(jqr '[.trace.agents[] | select(.type=="lead-review")] | length')" = 2 ]; echo $?)"
expect "red: the second review is scoped to the repair diff and the previous round" \
  "$(jqr '[.trace.agents[] | select(.type=="lead-review")][1].prompt' | grep -q 'review only .*council/round-1/'; echo $?)"
expect "red: no queen-planner" "$([ "$(jqr '[.trace.agents[] | select(.type=="queen-planner")] | length')" = 0 ]; echo $?)"
cd "$TMP/red" || exit 1
expect "red: a repair story was written for round 1 and closed" \
  "$(grep -q '^status: done' docs/specs/demo/demo-02-repair-round-1.md 2>/dev/null; echo $?)"
expect "red: the repair story carries the anchored finding" \
  "$(grep -q '\[ask 1\] app.txt must say it is really fixed' docs/specs/demo/demo-02-repair-round-1.md 2>/dev/null; echo $?)"
expect "red: round 1 RED, round 2 GREEN in the ledger" \
  "$(grep -q '"round":1,"verdict":"RED"' memory/stats/council.jsonl && grep -q '"round":2,"verdict":"GREEN"' memory/stats/council.jsonl; echo $?)"
expect "red: round 2's intent seat is marked carried" "$(head -1 docs/specs/demo/council/round-2/opus.md | grep -q 'carried: round 1'; echo $?)"
expect "red: the DRIVER lock is released" "$([ ! -f docs/specs/demo/DRIVER ]; echo $?)"
cd "$SRC" || exit 1

if [ "$fail" -eq 0 ]; then echo "e2e.test.sh: all checks passed"; else echo "e2e.test.sh: FAILED"; fi
exit "$fail"
