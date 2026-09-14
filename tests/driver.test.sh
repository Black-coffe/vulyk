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
    // a dead subagent: an { throw: '<message>' } queue entry rejects instead of resolving,
    // so the driver's own per-thunk catch (not parallel's) is what the scenario proves.
    if (entry && typeof entry === 'object' && 'throw' in entry) return Promise.reject(new Error(entry.throw));
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
// --- scenario (d): two red close-story misses on the same file -> stop carries the
// verification line's own error, not a generic message
.then(() => {
  const file = 'docs/specs/demo/demo-02-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-02', worker: 'worker-test' }] };
  const redLine = { ok: false, verb: 'close-story', exit: 4, error: 'red: verification failed' };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, redLine, wave, redLine], agents: ['report 1', 'report 2'] },
  ).then(({ result }) => {
    if (result && result.stop && result.stop.verb === 'build' && result.stop.file === file && result.stop.error === 'red: verification failed') {
      console.log('ok two-miss stop: red+red carries the verification error');
    } else {
      console.log('FAIL two-miss stop: red+red carries the verification error - got ' + JSON.stringify(result));
    }
  });
})
// --- scenario (e): empty report then a red close-story -> the second (verification) error wins
.then(() => {
  const file = 'docs/specs/demo/demo-03-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-03', worker: 'worker-test' }] };
  const redLine = { ok: false, verb: 'close-story', exit: 4, error: 'red: verification failed' };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, wave, redLine], agents: [null, 'report 2'] },
  ).then(({ result }) => {
    if (result && result.stop && result.stop.verb === 'build' && result.stop.error === 'red: verification failed') {
      console.log('ok two-miss stop: empty+red carries the verification error');
    } else {
      console.log('FAIL two-miss stop: empty+red carries the verification error - got ' + JSON.stringify(result));
    }
  });
})
// --- scenario (f): a red close-story then an empty report -> "worker returned no report" wins
.then(() => {
  const file = 'docs/specs/demo/demo-04-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-04', worker: 'worker-test' }] };
  const redLine = { ok: false, verb: 'close-story', exit: 4, error: 'red: verification failed' };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, redLine, wave], agents: ['report 1', null] },
  ).then(({ result }) => {
    if (result && result.stop && result.stop.verb === 'build' && result.stop.error === 'worker returned no report') {
      console.log('ok two-miss stop: red+empty ends "worker returned no report"');
    } else {
      console.log('FAIL two-miss stop: red+empty ends "worker returned no report" - got ' + JSON.stringify(result));
    }
  });
})
// --- scenario (g): a whitespace-only report is a miss - close-story is never called for it
.then(() => {
  const file = 'docs/specs/demo/demo-05-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-05', worker: 'worker-test' }] };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, wave], agents: ['   ', '   '] },
  ).then(({ result, calls }) => {
    const closeStoryCalls = calls.filter((c) => c.verb === 'close-story');
    if (result && result.stop && result.stop.error === 'worker returned no report' && closeStoryCalls.length === 0) {
      console.log('ok whitespace report: a miss, close-story never called');
    } else {
      console.log('FAIL whitespace report: a miss, close-story never called - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
    }
  });
})
// --- scenario (h): args undefined -> launch stop, zero clerk calls, no TypeError
.then(() => run(undefined, { clerk: [], agents: [] }).then(({ result, calls }) => {
  const clerkCalls = calls.filter((c) => 'verb' in c);
  if (result && result.stop && result.stop.verb === 'launch' && clerkCalls.length === 0) {
    console.log('ok launch guard: args undefined');
  } else {
    console.log('FAIL launch guard: args undefined - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
  }
}))
// --- scenario (i): Tier 4 with no second_model refuses at launch, before any worker dispatch
.then(() => run(
  { spec: 'demo', top_model: 'opus', stamp: '0123456789abcdef' },
  { clerk: [{ next: 'build:1', tier: 4, wave_stories: [{ file: 'docs/specs/demo/demo-06-x.md', story: 'demo-06', worker: 'worker-test' }] }], agents: ['report'] },
).then(({ result, calls }) => {
  const dispatches = calls.filter((c) => !('verb' in c));
  if (result && result.stop && result.stop.verb === 'launch' && /second_model/.test(result.stop.error) && dispatches.length === 0) {
    console.log('ok tier4 guard: second_model missing');
  } else {
    console.log('FAIL tier4 guard: second_model missing - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
  }
}))
// --- scenario (j): Tier 4 with second_model equal to top_model also refuses
.then(() => run(
  { spec: 'demo', top_model: 'opus', second_model: 'opus', stamp: '0123456789abcdef' },
  { clerk: [{ next: 'build:1', tier: 4, wave_stories: [] }], agents: [] },
).then(({ result }) => {
  if (result && result.stop && result.stop.verb === 'launch' && /second_model/.test(result.stop.error)) {
    console.log('ok tier4 guard: second_model equal to top_model');
  } else {
    console.log('FAIL tier4 guard: second_model equal to top_model - got ' + JSON.stringify(result));
  }
}))
// --- scenario (k): a Tier 3 run with no second_model proceeds (the guard is Tier-4-only)
.then(() => {
  const file = 'docs/specs/demo/demo-07-x.md';
  return run(
    { spec: 'demo', top_model: 'opus', stamp: '0123456789abcdef' },
    {
      clerk: [
        { next: 'build:1', tier: 3, wave_stories: [{ file, story: 'demo-07', worker: 'worker-test' }] },
        { ok: true },
        { next: 'green' },
      ],
      agents: ['a worker report'],
    },
  ).then(({ result }) => {
    if (result && result.next === 'green') {
      console.log('ok tier3: no second_model needed, run proceeds');
    } else {
      console.log('FAIL tier3: no second_model needed, run proceeds - got ' + JSON.stringify(result));
    }
  });
})
// --- scenario (l): any clerk line with exit:3 ends the run paused, no stop shape
.then(() => run(
  { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
  {
    clerk: [
      { next: 'dispatch:sonnet', tier: 2, round: 1, round_dir: 'docs/specs/demo/council/round-1' },
      { ok: false, exit: 3, next: 'paused', error: 'paused: owner requested a pause' },
    ],
    agents: ['a seat report'],
  },
).then(({ result }) => {
  if (result && result.next === 'paused' && !result.stop) {
    console.log('ok record-seat exit 3: ends the run paused, no stop');
  } else {
    console.log('FAIL record-seat exit 3: ends the run paused, no stop - got ' + JSON.stringify(result));
  }
}))
// --- scenario (m): next:"briefed" -> the driver refuses, never runs briefed --commit itself
.then(() => run(
  { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
  { clerk: [{ next: 'briefed' }], agents: [] },
).then(({ result, calls }) => {
  const briefedCommit = calls.some((c) => c.cmd && c.cmd.includes('briefed --commit'));
  if (result && result.stop && result.stop.verb === 'briefed' && !briefedCommit) {
    console.log('ok briefed refusal: stop, never runs briefed --commit');
  } else {
    console.log('FAIL briefed refusal: stop, never runs briefed --commit - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
  }
}))
// --- scenario (n): an ok:true exit:6 line (escalated) is followed by a status poll
.then(() => run(
  { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
  {
    clerk: [
      { next: 'open-round' },
      { ok: true, verb: 'open-round', exit: 6, next: 'escalated' },
      { next: 'escalated' },
    ],
    agents: [],
  },
).then(({ result }) => {
  if (result && result.next === 'escalated' && !result.stop) {
    console.log('ok exit 6: ok:true is followed by a status poll, ends escalated');
  } else {
    console.log('FAIL exit 6: ok:true is followed by a status poll, ends escalated - got ' + JSON.stringify(result));
  }
}))
// --- scenario (o): a thrown worker agent() is caught by its own build thunk, logged, and
// counted as the same miss a null report would be - the dead subagent's reason survives
// in the run journal even though the two-miss stop still says "worker returned no report"
.then(() => {
  const file = 'docs/specs/demo/demo-08-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-08', worker: 'worker-test' }] };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, wave], agents: [{ throw: 'subagent died' }, { throw: 'subagent died again' }] },
  ).then(({ result, logs }) => {
    const threw = logs.some((l) => l.startsWith('worker threw:'));
    if (result && result.stop && result.stop.error === 'worker returned no report' && threw) {
      console.log('ok worker threw: caught by the build thunk, logged, counted as a miss');
    } else {
      console.log('FAIL worker threw: caught by the build thunk, logged, counted as a miss - got ' + JSON.stringify(result) + ' logs=' + JSON.stringify(logs));
    }
  });
})
// --- scenario (p): the second dispatch of the same story carries the uncommitted-diff
// sentence; the first dispatch does not
.then(() => {
  const file = 'docs/specs/demo/demo-09-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-09', worker: 'worker-test', model: 'sonnet' }] };
  const redLine = { ok: false, verb: 'close-story', exit: 4, error: 'red: verification failed' };
  const sentence = 'a previous attempt may have left uncommitted edits in your files; `git diff` them first';
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, redLine, wave, { ok: true }, { next: 'green' }], agents: ['report 1', 'report 2'] },
  ).then(({ result, calls }) => {
    const workerCalls = calls.filter((c) => c.agentType === 'worker-test');
    if (
      result && result.next === 'green'
      && workerCalls.length === 2
      && !workerCalls[0].prompt.includes(sentence)
      && workerCalls[1].prompt.includes(sentence)
      && workerCalls[0].model === 'sonnet'
      && workerCalls[1].model === 'opus'
    ) {
      console.log('ok retry prompt: only the second dispatch mentions uncommitted edits');
    } else {
      console.log('FAIL retry prompt: only the second dispatch mentions uncommitted edits - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
    }
  });
})
// --- scenario (q): ADR-006 - a worker report opening STATUS: DONE, but close-story's
// first answer is exit 4 "returned WALL" (the worker forgot the `returned:` key or wrote
// the wrong one) - the driver still runs close-story a second time on retry and, once it
// answers ok:true, the run continues with no stop. This is the proof the driver never
// read "STATUS: DONE" to decide the story was done - only close-story's own exit code.
.then(() => {
  const file = 'docs/specs/demo/demo-10-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-10', worker: 'worker-test' }] };
  const returnedWall = { ok: false, verb: 'close-story', exit: 4, error: 'returned WALL' };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, returnedWall, wave, { ok: true }, { next: 'green' }], agents: ['STATUS: DONE\nreport 1', 'STATUS: DONE\nreport 2'] },
  ).then(({ result, calls }) => {
    const closeStoryCalls = calls.filter((c) => c.verb === 'close-story' && c.cmd && c.cmd.includes(file));
    if (result && result.next === 'green' && !result.stop && closeStoryCalls.length === 2) {
      console.log('ok ADR-006 returned WALL then ok: close-story called twice, no stop, run continues');
    } else {
      console.log('FAIL ADR-006 returned WALL then ok: close-story called twice, no stop, run continues - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
    }
  });
})
// --- scenario (r): same worker report (STATUS: DONE), but close-story answers exit 4
// "returned WALL" on both attempts - the second miss stops the run, close-story was
// still called exactly twice, and the stop names this story's file.
.then(() => {
  const file = 'docs/specs/demo/demo-11-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-11', worker: 'worker-test' }] };
  const returnedWall = { ok: false, verb: 'close-story', exit: 4, error: 'returned WALL' };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, returnedWall, wave, returnedWall], agents: ['STATUS: DONE\nreport 1', 'STATUS: DONE\nreport 2'] },
  ).then(({ result, calls }) => {
    const closeStoryCalls = calls.filter((c) => c.verb === 'close-story' && c.cmd && c.cmd.includes(file));
    if (result && result.stop && result.stop.verb === 'build' && result.stop.file === file && closeStoryCalls.length === 2) {
      console.log('ok ADR-006 returned WALL twice: stops on build, close-story called exactly twice');
    } else {
      console.log('FAIL ADR-006 returned WALL twice: stops on build, close-story called exactly twice - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
    }
  });
})
// --- scenario (s): a worker report opening STATUS: WALL, but close-story answers ok:true
// (the worker set `returned: DONE` regardless of its own STATUS line) - the story closes.
// This documents, not endorses, that the verb's own field is the gate, not the driver's
// reading of the report.
.then(() => {
  const file = 'docs/specs/demo/demo-12-x.md';
  const wave = { next: 'build:1', wave_stories: [{ file, story: 'demo-12', worker: 'worker-test' }] };
  return run(
    { spec: 'demo', top_model: 'opus', second_model: 'sonnet', stamp: '0123456789abcdef' },
    { clerk: [wave, { ok: true }, { next: 'green' }], agents: ['STATUS: WALL\nreport'] },
  ).then(({ result, calls }) => {
    const closeStoryCalls = calls.filter((c) => c.verb === 'close-story' && c.cmd && c.cmd.includes(file));
    if (result && result.next === 'green' && !result.stop && closeStoryCalls.length === 1) {
      console.log('ok ADR-006 STATUS: WALL but close-story ok: the story closes on the verb alone');
    } else {
      console.log('FAIL ADR-006 STATUS: WALL but close-story ok: the story closes on the verb alone - got ' + JSON.stringify(result) + ' calls=' + JSON.stringify(calls));
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
expect "run: two-miss stop names the red verification (M2/X-M1)" "ok two-miss stop: red+red carries the verification error" "$out"
expect "run: two-miss stop, empty then red"                      "ok two-miss stop: empty+red carries the verification error" "$out"
expect "run: two-miss stop, red then empty"                      "ok two-miss stop: red+empty ends \"worker returned no report\"" "$out"
expect "run: whitespace-only report is a miss"                   "ok whitespace report: a miss, close-story never called" "$out"
expect "run: launch guard on args undefined"                     "ok launch guard: args undefined" "$out"
expect "run: Tier 4 without second_model refuses at launch"      "ok tier4 guard: second_model missing" "$out"
expect "run: Tier 4 with second_model == top_model refuses"      "ok tier4 guard: second_model equal to top_model" "$out"
expect "run: Tier 3 with no second_model proceeds"               "ok tier3: no second_model needed, run proceeds" "$out"
expect "run: record-seat exit 3 ends the run paused"              "ok record-seat exit 3: ends the run paused, no stop" "$out"
expect "run: next:briefed refuses instead of stamping"           "ok briefed refusal: stop, never runs briefed --commit" "$out"
expect "run: exit 6 ok:true is followed by a status poll"        "ok exit 6: ok:true is followed by a status poll, ends escalated" "$out"
expect "run: a thrown worker agent() is caught and logged"       "ok worker threw: caught by the build thunk, logged, counted as a miss" "$out"
expect "run: the retry prompt names the uncommitted-diff note, retry on opus (ADR-007)" "ok retry prompt: only the second dispatch mentions uncommitted edits" "$out"
expect "run: ADR-006 returned WALL then ok - close-story x2, no stop" "ok ADR-006 returned WALL then ok: close-story called twice, no stop, run continues" "$out"
expect "run: ADR-006 returned WALL twice - stops, close-story x2"    "ok ADR-006 returned WALL twice: stops on build, close-story called exactly twice" "$out"
expect "run: ADR-006 STATUS: WALL but close-story ok - story closes" "ok ADR-006 STATUS: WALL but close-story ok: the story closes on the verb alone" "$out"

exit $fail
