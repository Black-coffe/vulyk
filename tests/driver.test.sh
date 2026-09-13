#!/usr/bin/env bash
# Executes .claude/workflows/vulyk-cycle.js for real, against stubbed agent/parallel/
# pipeline/phase/log and a scripted cycle-clerk - the check `node --check` cannot do,
# since the driver is bare top-level statements meant to run as an async function body,
# not a module (round-3 review major 1).
#
#   Usage: bash tests/driver.test.sh            # from the VULYK repo root
#
# No node on PATH -> prints "skipped: node not found" and exits 0 (this suite proves
# nothing about the driver without a runtime to execute it in).
set -u

if ! command -v node >/dev/null 2>&1; then
  echo "skipped: node not found"
  exit 0
fi

SRC="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
expect() { # expect <label> <needle> <haystack>   (no pipe - a pipe into a function
  # runs the function in a subshell in bash, and this "fail=1" needs to reach the caller's shell)
  local label="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then echo "  ok    $label"
  else echo "::error::$label - expected '$needle' in:"; printf '%s\n' "$haystack" | sed 's/^/        /'; fail=1; fi
}

export VULYK_DRIVER_PATH="$SRC/.claude/workflows/vulyk-cycle.js"

out="$(node <<'NODE_EOF'
'use strict';
const fs = require('fs');
const driverPath = process.env.VULYK_DRIVER_PATH || '.claude/workflows/vulyk-cycle.js';
const src = fs.readFileSync(driverPath, 'utf8');

// --- compile step: strip `export ` at line start, compile the rest as the body of an
// async function taking (args, agent, parallel, pipeline, phase, log) - this is the
// Workflow runtime's own shape for a bare top-level-statement/top-level-return file.
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
function compile(body) {
  const stripped = body.replace(/^export /gm, '');
  return new AsyncFunction('args', 'agent', 'parallel', 'pipeline', 'phase', 'log', stripped);
}

let driverFn;
try {
  driverFn = compile(src);
  console.log('ok compile driver');
} catch (e) {
  console.log('FAIL compile driver: ' + e);
}

// garbage: `export ` still stripped, but the remainder is not valid JS - the inverse
// check that `node --check` cannot perform on an ES-module-shaped file.
try {
  compile('export const meta = {a:1}\nthis is not javascript at all (((');
  console.log('FAIL garbage rejected: no throw');
} catch (e) {
  if (e instanceof SyntaxError) console.log('ok garbage rejected');
  else console.log('FAIL garbage rejected: wrong error type ' + e);
}

// --- foldReviews harness, ported verbatim from
// docs/specs/autonomous-cycle/autonomous-cycle-26-driver-fails-closed.md:54
{
  const s = src;
  const m = s.match(/^function foldReviews\([\s\S]*?^\}/m);
  if (!m) throw new Error('no foldReviews');
  const fold = new Function(m[0] + ';return foldReviews;')();
  const first = (r) => String(r).split('\n')[0];
  const ok = (c, w) => { if (!c) { console.error('FAIL ' + w); process.exit(1); } };
  ok(first(fold('VERDICT: PASS\nA', 'VERDICT: BLOCK\nB')) === 'VERDICT: BLOCK', 'either BLOCK');
  ok(first(fold('VERDICT: PASS\nA', 'VERDICT: PASS\nB')) === 'VERDICT: PASS', 'both PASS');
  for (const [a, b, w] of [
    [null, null, 'null,null'],
    [null, 'VERDICT: PASS\nB', 'null,PASS'],
    ['VERDICT: PASS\nA', null, 'PASS,null'],
    ['', 'VERDICT: PASS\nB', 'empty,PASS'],
    ['prose\nVERDICT: PASS', 'VERDICT: PASS\nB', 'prose first'],
  ]) {
    ok(!/^VERDICT:/.test(first(fold(a, b))), w);
  }
  ok(fold(null, 'VERDICT: PASS\nB').includes('VERDICT: PASS\nB'), 'survivor kept');
  console.log('fold ok');
}

// --- run(args, script) harness: script = { clerk: [...], agents: [...] }
function run(args, script) {
  const clerkQueue = (script.clerk || []).slice();
  const agentsQueue = (script.agents || []).slice();
  const calls = [];
  const phases = [];
  const logs = [];

  const agent = (prompt, opts) => {
    if (opts && opts.agentType === 'cycle-clerk') {
      const m = prompt.match(/scripts\/cycle\.sh (\S+)/);
      const verb = m ? m[1] : null;
      calls.push({ verb, cmd: prompt });
      let entry = clerkQueue.shift();
      if (entry === undefined) throw new Error('clerk queue exhausted for: ' + prompt);
      if (typeof entry !== 'string') entry = JSON.stringify(entry);
      return Promise.resolve(entry);
    }
    calls.push({ agentType: opts && opts.agentType, model: opts && opts.model, prompt });
    const entry = agentsQueue.shift();
    return Promise.resolve(entry === undefined ? null : entry);
  };

  const parallel = (thunks) => Promise.all(thunks.map((t) => {
    try { return Promise.resolve(t()).catch(() => null); } catch { return Promise.resolve(null); }
  }));

  const pipeline = (items, ...stages) => items.reduce(
    (p, item) => p.then(async (acc) => {
      let cur = item;
      for (const stage of stages) {
        if (cur === null) break;
        try { cur = await stage(cur); } catch { cur = null; }
      }
      acc.push(cur);
      return acc;
    }),
    Promise.resolve([]),
  );

  const phase = (name) => { phases.push(name); };
  const log = (line) => { logs.push(line); };

  return driverFn(args, agent, parallel, pipeline, phase, log).then((result) => ({ result, calls, phases, logs }));
}

// --- scenario (a): args.stamp missing -> stop.verb === 'launch', no clerk call
run({}, { clerk: [], agents: [] }).then(({ result, calls }) => {
  const clerkCalls = calls.filter((c) => 'verb' in c);
  if (result && result.stop && result.stop.verb === 'launch' && clerkCalls.length === 0) {
    console.log('ok launch guard: missing stamp');
  } else {
    console.log('FAIL launch guard: missing stamp - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
  }
})
// --- scenario (b): status next:"green" -> next === 'green', zero agent dispatches
.then(() => run(
  { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
  { clerk: [{ next: 'green' }], agents: [] },
).then(({ result, calls }) => {
  const dispatches = calls.filter((c) => !('verb' in c));
  if (result && result.next === 'green' && dispatches.length === 0) {
    console.log('ok status green: terminal, no dispatch');
  } else {
    console.log('FAIL status green: terminal, no dispatch - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
  }
}))
// --- scenario (c): build:1 with one wave story -> worker dispatched as worker-test,
// close-story called once with that file, then status green ends the run
.then(() => {
  const file = 'docs/specs/demo/demo-01-first.md';
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    {
      clerk: [
        { next: 'build:1', wave_stories: [{ file, story: 'demo-01', worker: 'worker-test' }] },
        { ok: true },
        { next: 'green' },
      ],
      agents: ['a worker report'],
    },
  ).then(({ result, calls }) => {
    const workerCalls = calls.filter((c) => c.agentType === 'worker-test');
    const closeStoryCalls = calls.filter((c) => c.verb === 'close-story' && c.cmd && c.cmd.includes(file));
    if (
      result && result.next === 'green'
      && workerCalls.length === 1
      && closeStoryCalls.length === 1
    ) {
      console.log('ok build wave: worker dispatched, close-story called once');
    } else {
      console.log('FAIL build wave: worker dispatched, close-story called once - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
    }
  });
})
.catch((e) => { console.log('FAIL harness threw: ' + (e && e.stack || e)); process.exitCode = 1; });
NODE_EOF
)"

echo "$out"

expect "compile: strips export, compiles async body"    "ok compile driver"                                     "$out"
expect "compile: garbage without export is rejected"     "ok garbage rejected"                                   "$out"
expect "fold: foldReviews harness from story 26"         "fold ok"                                               "$out"
expect "run: launch guard on missing args.stamp"         "ok launch guard: missing stamp"                        "$out"
expect "run: status green is terminal, no dispatch"      "ok status green: terminal, no dispatch"                "$out"
expect "run: build wave dispatches worker, closes story" "ok build wave: worker dispatched, close-story called once" "$out"

exit $fail
