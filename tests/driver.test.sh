#!/usr/bin/env bash
# Executes .claude/workflows/vulyk-cycle.js for real, against stubbed agent/parallel/phase/log
# and a scripted cycle-clerk that answers each expected command with a JSON line - the check
# `node --check` cannot do, since the driver is bare top-level statements meant to run as an
# async function body, not a module.
#
#   Usage: bash tests/driver.test.sh            # from the VULYK repo root
#
# No node on PATH -> prints "skipped: node not found" and exits 0 (this suite proves nothing
# about the driver without a runtime to execute it in).
set -u

if ! command -v node >/dev/null 2>&1; then
  echo "skipped: node not found"
  exit 0
fi

SRC="$(cd "$(dirname "$0")/.." && pwd)"
export VULYK_DRIVER_PATH="$SRC/.claude/workflows/vulyk-cycle.js"

node <<'NODE_EOF'
'use strict';
const fs = require('fs');
const src = fs.readFileSync(process.env.VULYK_DRIVER_PATH, 'utf8');

let passed = 0;
let failed = 0;
const check = (cond, label, detail) => {
  if (cond) { passed++; console.log('  ok    ' + label); }
  else { failed++; console.log('::error::' + label + (detail === undefined ? '' : ' - got ' + JSON.stringify(detail))); }
};

// --- compile: strip `export ` at line start and compile the rest as the body of an async
// function taking the Workflow hooks - the runtime's own shape for a top-level-return file.
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const compile = (body) => new AsyncFunction('args', 'agent', 'parallel', 'phase', 'log', body.replace(/^export /gm, ''));
let driverFn = null;
try { driverFn = compile(src); check(true, 'compile: the driver compiles as an async body'); }
catch (e) { check(false, 'compile: the driver compiles as an async body', String(e)); }
try { compile('export const meta = {a:1}\nthis is not javascript ((('); check(false, 'compile: garbage is rejected'); }
catch (e) { check(e instanceof SyntaxError, 'compile: garbage is rejected', String(e)); }
if (!driverFn) { console.log('FAIL: nothing to run'); process.exit(1); }

// --- static checks
{
  const m = src.match(/^export const meta = (\{[\s\S]*?^\})/m);
  let literal = false;
  // a pure literal evaluates with no free identifier in scope
  try { literal = !!m && typeof new Function('"use strict"; return (' + m[1] + ')')() === 'object'; } catch { literal = false; }
  check(literal, 'static: meta is a pure literal');
  check(!src.includes('queen-planner'), 'static: no queen-planner anywhere in the driver');
  check(!/\bfoldReviews\b/.test(src), 'static: no JS review fold - advance --ingest folds');
  const advances = src.match(/`advance \$\{spec\}[^`]*`/g) || [];
  check(advances.length > 0 && advances.every((t) => t.includes('--stamp ${stamp}')), 'static: every advance template carries --stamp', advances);
  check(/close-story \$\{story\.file\} --commit --stamp \$\{stamp\}/.test(src), 'static: the worker prompt names close-story --commit --stamp');
  const verbs = ['claim', 'record-seat', 'judge', 'open-round', 'branch', 'close-story'].filter((v) => new RegExp('`' + v + ' ').test(src));
  check(verbs.length === 0, 'static: the driver sends no per-verb clerk command but advance/status/release', verbs);
  const shout = src.match(/\b(MUST|NEVER|ALWAYS|CRITICAL|IMPORTANT)\b/g);
  check(!shout, 'static: no all-caps shouting', shout);
  // agent frontmatter is the one source of maxTurns and model: the driver keeps no per-agent
  // table of either and passes no turn cap, so a hive raising a seat's cap edits one file
  const agentsDir = require('path').join(require('path').dirname(process.env.VULYK_DRIVER_PATH), '..', 'agents');
  const mirrored = fs.readdirSync(agentsDir).filter((f) => f.endsWith('.md')).map((f) => f.slice(0, -3))
    .filter((a) => new RegExp(`['"]${a}['"]\\s*:\\s*['"\\d]`).test(src));
  check(mirrored.length === 0 && !/maxTurns\s*[:=]/.test(src), 'static: no per-agent cap or model table, no maxTurns option', mirrored);
  const d = src.match(/description:\s*'([^']*)'/);
  check(!!d && !/ceiling\s*\(?3\b/.test(d[1]), 'static: the description states no flat ceiling 3', d && d[1]);
}

// --- harness
const S = '0123456789abcdef';
const SPEC = 'docs/specs/demo';
const ADV = `advance ${SPEC} --stamp ${S}`;
const CLAIM = `${ADV} --claim`;
const INGEST = `${ADV} --ingest`;
const STATUS = `status ${SPEC} --json`;
const RELEASE = `release ${SPEC} ${S}`;
const ARGS = { spec: SPEC, top_model: 'fable', second_model: 'opus', stamp: S };
const releaseOk = { ok: true, verb: 'release', exit: 0, next: 'released' };
const COURT = '/abs/.vulyk/court/demo';

const status = (o) => ({
  spec: SPEC, slug: 'demo', stage: '03', tier: 3, branch: 'vulyk/demo', head: 'h1',
  wave_stories: [], round: 0, court: null, round_dir: null, since: null, seat_attempt: {}, seats: [], red: [],
  ...o,
});
const adv = (st, extra) => ({ ok: true, verb: 'advance', exit: 0, next: st.next, steps: [], rejected: [], status: st, ...extra });
const story = (n, o) => ({ file: `${SPEC}/demo-0${n}-x.md`, story: `demo-0${n}`, worker: 'worker-code', model: 'opus', repeat: 1, ...o });
const build = (stories, o) => status({ next: 'build:1', wave_stories: stories, ...o });
const round = (seats, o) => status({
  next: 'dispatch:' + seats, stage: '04', round: 1, court: COURT, round_dir: `${SPEC}/council/round-1`,
  seats: seats.split(','), seat_attempt: Object.fromEntries(seats.split(',').map((s) => [s, 1])), ...o,
});
const green = (o) => status({ next: 'green', stage: '05', ...o });

const everyAgentType = new Set();

// script.clerk: an array of [expected command, answer] pairs, or a function (cmd, n) -> answer.
// A command that differs from the expected one is recorded as a mismatch.
async function run(args, script) {
  const clerk = script.clerk || [];
  const agents = (script.agents || []).slice();
  const clerkCmds = [];
  const mismatches = [];
  const dispatches = [];
  const logs = [];
  const phases = [];
  const agent = (prompt, opts) => {
    if (opts && opts.agentType === 'cycle-clerk') {
      const m = prompt.match(/^Run exactly: bash scripts\/cycle\.sh (.*)\nReturn the last stdout line verbatim\.$/);
      const cmd = m ? m[1] : '<malformed clerk prompt> ' + prompt;
      const n = clerkCmds.length;
      clerkCmds.push(cmd);
      let answer;
      if (typeof clerk === 'function') answer = clerk(cmd, n);
      else {
        const entry = clerk[n];
        if (entry === undefined) return Promise.reject(new Error('clerk script exhausted at: ' + cmd));
        if (entry[0] !== cmd) mismatches.push({ n, want: entry[0], got: cmd });
        answer = entry[1];
      }
      return Promise.resolve(typeof answer === 'string' ? answer : JSON.stringify(answer));
    }
    everyAgentType.add(opts && opts.agentType);
    dispatches.push({ agentType: opts && opts.agentType, model: opts && opts.model, phase: opts && opts.phase, prompt });
    let entry = agents.shift();
    if (typeof entry === 'function') entry = entry(prompt, opts);
    if (entry && typeof entry === 'object' && 'throw' in entry) return Promise.reject(new Error(entry.throw));
    return Promise.resolve(entry === undefined ? 'a report' : entry);
  };
  const parallel = (thunks) => Promise.all(thunks.map((t) => {
    try { return Promise.resolve(t()).catch(() => null); } catch { return Promise.resolve(null); }
  }));
  const result = await driverFn(args, agent, parallel, (p) => phases.push(p), (l) => logs.push(l));
  return { result, clerkCmds, mismatches, dispatches, logs, phases };
}
const seq = (r) => r.clerkCmds.join(' | ');
const blindPromptsClean = (r) => r.dispatches
  .filter((d) => d.agentType === 'council-opus' || d.agentType === 'council-haiku')
  .every((d) => !d.prompt.includes(SPEC) && !d.prompt.includes('council/round-') && !d.prompt.includes(S));

(async () => {
  // --- launch guards: no clerk call at all
  for (const [label, args] of [['args undefined', undefined], ['stamp missing', { spec: SPEC }], ['spec missing', { stamp: S }]]) {
    const r = await run(args, { clerk: [] });
    check(r.result && r.result.stop && r.result.stop.verb === 'launch' && r.clerkCmds.length === 0, `launch guard: ${label}`, r.result);
  }

  // --- happy Tier 3: claim -> build -> advance -> dispatch opus+review -> ingest -> green -> release
  {
    const a = story(1, { worker: 'worker-code', model: 'opus' });
    const b = story(2, { worker: 'worker-test', model: '' }); // no model: line in the story
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, adv(build([a, b]), { steps: ['branch'] })],
        [ADV, adv(round('opus,review'), { steps: ['open-round'] })],
        [INGEST, adv(green(), { steps: ['judge'] })],
        [RELEASE, releaseOk],
      ],
      agents: ['worker a', 'worker b', 'opus report', 'review report'],
    });
    const [wa, wb, opus, review] = r.dispatches;
    check(r.mismatches.length === 0 && r.clerkCmds.length === 4, 'tier 3: exact clerk sequence claim, advance, advance --ingest, release', { seq: seq(r), mm: r.mismatches });
    check(r.result && r.result.next === 'green' && !r.result.stop, 'tier 3: ends green with the carried status', r.result);
    check(r.dispatches.length === 4, 'tier 3: two workers and two seats, nothing else', r.dispatches.map((d) => d.agentType));
    check(wa.agentType === 'worker-code' && wa.model === 'opus' && wb.agentType === 'worker-test' && wb.model === undefined,
      'tier 3: workers take agentType and model from the story; no model means none passed, so the frontmatter applies', [wa, wb]);
    check(wa.prompt.includes(a.file) && wa.prompt.includes(`Stamp: ${S}`)
      && wa.prompt.includes(`bash scripts/cycle.sh close-story ${a.file} --commit --stamp ${S}`)
      && !wa.prompt.includes('git diff'), 'tier 3: worker prompt names the story, the stamp and close-story as the last step', wa.prompt);
    check(opus.agentType === 'council-opus' && opus.model === undefined && opus.prompt.includes(`COURT: ${COURT}`)
      && opus.prompt.includes('.vulyk/reports/demo/round-1/opus.attempt-1.md'), 'tier 3: opus seat gets COURT and its attempt-1 report path', opus);
    check(review.agentType === 'lead-review' && review.model === undefined, 'tier 3: lead-review runs on its frontmatter model', review);
    check(review.prompt.includes(`Spec: ${SPEC}`) && review.prompt.includes('Branch vulyk/demo at h1')
      && review.prompt.includes('review the whole branch against its base') && !review.prompt.includes('..')
      && !review.prompt.includes('council/round-') && !/adr\/001/i.test(review.prompt)
      && review.prompt.includes('.vulyk/reports/demo/round-1/review.attempt-1.md'),
      'tier 3: round-1 reviewer prompt: spec, branch, head, whole branch, no ADR-001, report path', review.prompt);
    check(blindPromptsClean(r), 'tier 3: blind seat prompt carries no spec dir, round dir or stamp', opus.prompt);
    check(r.phases.join(',') === 'Build,Council', 'tier 3: phases Build then Council', r.phases);
    check(r.clerkCmds.every((c) => !c.startsWith('status')), 'tier 3: no separate status poll', seq(r));
  }

  // --- Tier 1/2: review only, one reviewer on its frontmatter model
  for (const tier of [1, 2]) {
    const a = story(1);
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, adv(build([a], { tier }))],
        [ADV, adv(round('review', { tier, court: null }))],
        [INGEST, adv(green({ tier }))],
        [RELEASE, releaseOk],
      ],
    });
    const types = r.dispatches.map((d) => d.agentType).join(',');
    const rev = r.dispatches[1];
    check(r.mismatches.length === 0 && r.result.next === 'green' && types === 'worker-code,lead-review'
      && rev.model === undefined && rev.prompt.includes('review.attempt-1.md'),
      `tier ${tier}: review only, no court needed, reviewer on frontmatter model`, { types, seq: seq(r), result: r.result });
  }

  // --- story retry: second dispatch on TOP with the git-diff sentence, second miss stops naming the file
  {
    const a = story(1, { worker: 'worker-test', model: 'opus' });
    const sentence = 'a previous attempt may have left uncommitted edits in your files; `git diff` them first';
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, adv(build([a]))],
        [ADV, adv(build([a]))],
        [ADV, adv(build([a]))],
        [RELEASE, releaseOk],
      ],
      agents: ['report 1', 'report 2'],
    });
    const [w1, w2] = r.dispatches;
    check(r.dispatches.length === 2 && w1.model === 'opus' && w2.model === 'fable', 'retry: the second attempt runs on TOP', r.dispatches.map((d) => d.model));
    check(!w1.prompt.includes(sentence) && w2.prompt.includes(sentence), 'retry: only the second prompt carries the git-diff sentence', [w1.prompt, w2.prompt]);
    check(r.result.stop && r.result.stop.verb === 'build' && r.result.stop.file === a.file
      && /still todo/.test(r.result.stop.error), 'retry: the second miss stops the run naming the file', r.result);
    check(r.mismatches.length === 0 && r.clerkCmds[r.clerkCmds.length - 1] === RELEASE, 'retry: the stop still releases', seq(r));
  }
  // retry that lands: the run walks on; TOP falls back to opus when top_model is absent
  {
    const a = story(1, { model: 'sonnet' });
    const r = await run({ spec: SPEC, stamp: S }, {
      clerk: [[CLAIM, adv(build([a]))], [ADV, adv(build([a]))], [ADV, adv(green())], [RELEASE, releaseOk]],
    });
    check(r.result.next === 'green' && r.dispatches[1].model === 'opus', 'retry: a landed retry walks on, TOP falls back to opus', { result: r.result, m: r.dispatches.map((d) => d.model) });
  }
  // dead workers: the reasonFor classification is the stop's error; a dead worker whose story closed is no miss
  {
    const a = story(1, { worker: 'worker-code' });
    const r = await run(ARGS, {
      clerk: [[CLAIM, adv(build([a]))], [ADV, adv(build([a]))], [ADV, adv(build([a]))], [RELEASE, releaseOk]],
      agents: [{ throw: 'died' }, '   '],
    });
    check(r.result.stop && r.result.stop.error === 'worker returned empty - turn cap suspected (worker-code, maxTurns in .claude/agents/worker-code.md)'
      && r.logs.includes(`miss 1 on ${a.file}: worker threw: died`), 'dead worker: threw then empty - the second reason stops the run', { result: r.result, logs: r.logs });
    const b = story(2);
    const r2 = await run(ARGS, {
      clerk: [[CLAIM, adv(build([a, b]))], [ADV, adv(build([b]))], [ADV, adv(green())], [RELEASE, releaseOk]],
      agents: [null, 'b report', 'b again'],
    });
    const second = r2.dispatches.slice(2).map((d) => d.prompt.includes(b.file));
    check(r2.result.next === 'green' && r2.dispatches.length === 3 && second.length === 1 && second[0],
      'dead worker: a closed story is no miss, only the still-todo story is re-dispatched', { result: r2.result, n: r2.dispatches.length });
  }

  // --- seat rejection: one re-dispatch carrying advance's rejection text, a third dispatch stops
  {
    const rej = { seat: 'opus', attempt: 1, error: 'MALFORMED: ASK 2 GREEN with no run:/saw: evidence' };
    const again = round('opus', { seat_attempt: { opus: 2 } });
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, adv(round('opus,review'))],
        [INGEST, adv(again, { steps: [], rejected: [rej] })],
        [INGEST, adv(again, { rejected: [{ ...rej, attempt: 2 }] })],
        [RELEASE, releaseOk],
      ],
    });
    const opus = r.dispatches.filter((d) => d.agentType === 'council-opus');
    const reviews = r.dispatches.filter((d) => d.agentType === 'lead-review');
    check(opus.length === 2 && reviews.length === 1, 'rejection: only the rejected seat is re-dispatched', r.dispatches.map((d) => d.agentType));
    check(!opus[0].prompt.includes('rejected') && opus[1].prompt.includes('\nYour previous report was rejected: ' + rej.error),
      'rejection: the re-dispatch carries the rejection text from advance', opus.map((d) => d.prompt));
    check(opus[0].prompt.includes('opus.attempt-1.md') && opus[1].prompt.includes('opus.attempt-2.md'),
      'rejection: the report path follows status.seat_attempt', opus.map((d) => d.prompt));
    check(r.result.stop && r.result.stop.verb === 'dispatch' && r.result.stop.seat === 'opus' && r.result.stop.round === 1,
      'rejection: a seat needing a third dispatch in one round stops the run', r.result);
    check(r.mismatches.length === 0 && r.clerkCmds.length === 4, 'rejection: claim, ingest, ingest, release', seq(r));
    check(blindPromptsClean(r), 'rejection: the re-asked blind seat still gets no spec dir or stamp');
  }
  // seat_attempt from disk sets k even on this run's first dispatch, with no rejection note
  {
    const r = await run(ARGS, {
      clerk: [[CLAIM, adv(round('review', { seat_attempt: { review: 2 } }))], [INGEST, adv(green())], [RELEASE, releaseOk]],
    });
    const p = r.dispatches[0].prompt;
    check(p.includes('.vulyk/reports/demo/round-1/review.attempt-2.md') && !p.includes('rejected'),
      'seat_attempt: k comes from status, a first dispatch in this run carries no rejection note', p);
  }

  // --- round > 1: the reviewer judges since..head and the previous round's findings
  {
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, adv(round('haiku,review', { round: 2, since: 'abc123', head: 'def456', round_dir: `${SPEC}/council/round-2` }))],
        [INGEST, adv(green())],
        [RELEASE, releaseOk],
      ],
    });
    const rev = r.dispatches.find((d) => d.agentType === 'lead-review');
    const haiku = r.dispatches.find((d) => d.agentType === 'council-haiku');
    check(rev.prompt.includes('review only abc123..def456') && rev.prompt.includes(`${SPEC}/council/round-1/`)
      && !rev.prompt.includes('whole branch') && rev.prompt.includes('round-2/review.attempt-1.md'),
      'round 2: reviewer prompt names since..head and the round-1 findings dir', rev.prompt);
    check(haiku && haiku.prompt.includes('round-2/haiku.attempt-1.md') && blindPromptsClean(r), 'round 2: haiku stays blind', haiku && haiku.prompt);
  }

  // --- Tier 4: two reviewers, review-top on TOP and review-second on SECOND, one ingest
  {
    const r = await run(ARGS, {
      clerk: [[CLAIM, adv(round('opus,review', { tier: 4 }))], [INGEST, adv(green({ tier: 4 }))], [RELEASE, releaseOk]],
    });
    const revs = r.dispatches.filter((d) => d.agentType === 'lead-review');
    check(revs.length === 2 && revs[0].model === 'fable' && revs[0].prompt.includes('round-1/review-top.attempt-1.md')
      && revs[1].model === 'opus' && revs[1].prompt.includes('round-1/review-second.attempt-1.md'),
      'tier 4: two reviewers, review-top on TOP and review-second on SECOND', revs.map((d) => [d.model, d.prompt]));
    check(r.mismatches.length === 0 && r.clerkCmds.length === 3 && r.result.next === 'green', 'tier 4: one ingest folds both', seq(r));
  }
  for (const [label, args] of [['second_model missing', { spec: SPEC, top_model: 'fable', stamp: S }], ['second_model equal to top_model', { ...ARGS, second_model: 'fable' }]]) {
    const r = await run(args, { clerk: [[CLAIM, adv(build([story(1)], { tier: 4 }))], [RELEASE, releaseOk]] });
    check(r.result.stop && r.result.stop.verb === 'launch' && /second_model/.test(r.result.stop.error)
      && r.dispatches.length === 0 && r.clerkCmds[1] === RELEASE, `tier 4 guard: ${label} refuses before any dispatch, releases`, { result: r.result, seq: seq(r) });
  }

  // --- profile models: worker_model / review_model / seat_model fill only what the story or tier leaves open
  {
    const P = { ...ARGS, worker_model: 'opus', review_model: 'fable', seat_model: 'fable' };
    const a = story(1, { model: '' });
    const b = story(2, { model: 'haiku' });
    const r = await run(P, {
      clerk: [
        [CLAIM, adv(build([a, b]))],
        [ADV, adv(round('haiku,opus,review'))],
        [INGEST, adv(green())],
        [RELEASE, releaseOk],
      ],
    });
    const by = (t) => r.dispatches.filter((d) => d.agentType === t);
    const [wa, wb] = r.dispatches;
    check(r.mismatches.length === 0 && wa.model === 'opus' && wb.model === 'haiku',
      'profile: worker_model runs a story with no model, a story model: haiku stays haiku', [wa.model, wb.model]);
    check(by('lead-review').length === 1 && by('lead-review')[0].model === 'fable', 'profile: review_model runs the Tier 1-3 reviewer', by('lead-review'));
    check(by('council-opus')[0].model === 'fable' && by('council-haiku')[0].model === 'fable', 'profile: seat_model runs both blind seats',
      [by('council-opus')[0].model, by('council-haiku')[0].model]);
    const c = story(3, { model: 'haiku' });
    const r2 = await run(P, {
      clerk: [[CLAIM, adv(build([c]))], [ADV, adv(build([c]))], [ADV, adv(green())], [RELEASE, releaseOk]],
    });
    check(r2.dispatches.length === 2 && r2.dispatches[0].model === 'haiku' && r2.dispatches[1].model === 'opus',
      'profile: a retry climbs to opus when TOP is also the review model (Fable never judges its own code)', r2.dispatches.map((d) => d.model));
    const r2b = await run({ ...P, review_model: 'opus' }, {
      clerk: [[CLAIM, adv(build([c]))], [ADV, adv(build([c]))], [ADV, adv(green())], [RELEASE, releaseOk]],
    });
    check(r2b.dispatches.length === 2 && r2b.dispatches[1].model === 'fable',
      'profile: a retry runs on TOP when TOP is not the review model', r2b.dispatches.map((d) => d.model));
    const r3 = await run({ ...P, top_model: 'fable', second_model: 'sonnet' }, {
      clerk: [[CLAIM, adv(round('review', { tier: 4, court: null }))], [INGEST, adv(green({ tier: 4 }))], [RELEASE, releaseOk]],
    });
    const revs = r3.dispatches.filter((d) => d.agentType === 'lead-review');
    check(revs.length === 2 && revs[0].model === 'fable' && revs[1].model === 'sonnet', 'profile: the Tier 4 pair stays TOP/SECOND, review_model is not used',
      revs.map((d) => d.model));
    const r4 = await run({ ...ARGS, review_model: 'haiku' }, {
      clerk: [[CLAIM, adv(round('review', { tier: 4, court: null }))], [INGEST, adv(green({ tier: 4 }))], [RELEASE, releaseOk]],
    });
    check(r4.dispatches.map((d) => d.model).join(',') === 'fable,opus', 'profile: review_model leaves the Tier 4 pair on the launch pair', r4.dispatches.map((d) => d.model));
  }

  // --- unreadable clerk lines: one read-only status, then on from that status
  {
    const a = story(1);
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, '{"ok":true,"verb":"adv'],
        [STATUS, build([a])],
        [ADV, adv(round('opus'))],
        [INGEST, 'Done. The command printed a JSON line.'],
        [STATUS, round('opus', { seat_attempt: { opus: 2 } })],
        [INGEST, adv(green())],
        [RELEASE, releaseOk],
      ],
    });
    const opus = r.dispatches.filter((d) => d.agentType === 'council-opus');
    check(r.mismatches.length === 0 && r.result.next === 'green', 'bad line: recovered through status, the run walks on', { seq: seq(r), mm: r.mismatches, result: r.result });
    check(r.logs.some((l) => l.includes('reading status instead') && l.includes('--claim')), 'bad line: the recovery is logged', r.logs);
    check(opus.length === 2 && opus[1].prompt.includes("Your previous report was rejected: no reason reached the driver")
      && opus[1].prompt.includes('opus.attempt-2.md'), 'bad line: a recovered ingest re-asks with the generic line', opus.map((d) => d.prompt));
  }
  {
    const r = await run(ARGS, { clerk: [[CLAIM, 'garbled'], [STATUS, 'garbled too'], [RELEASE, releaseOk]] });
    check(r.result === 'garbled too' && r.mismatches.length === 0 && r.clerkCmds.length === 3,
      'bad line twice: the run ends with the raw second line, still releases', { result: r.result, seq: seq(r) });
  }
  {
    const r = await run(ARGS, { clerk: [[CLAIM, { ok: true, verb: 'advance', exit: 0, next: 'green' }], [STATUS, green()], [RELEASE, releaseOk]] });
    check(r.result.next === 'green' && r.mismatches.length === 0, 'bad line: an ok line with no status object reads status once', seq(r));
  }
  {
    const r = await run(ARGS, { clerk: [[CLAIM, 'x'], [STATUS, { ok: false, verb: 'status', exit: 1, next: 'error', error: 'usage' }], [RELEASE, releaseOk]] });
    check(r.result.stop && r.result.stop.verb === 'status' && r.result.stop.error === 'usage', 'bad line: a status error envelope stops the run', r.result);
  }

  // --- paused
  {
    const r = await run(ARGS, {
      clerk: [
        [CLAIM, adv(build([story(1)]))],
        [ADV, { ok: false, verb: 'advance', exit: 3, next: 'paused', error: 'paused: owner', failed: 'open-round', steps: [] }],
        [RELEASE, releaseOk],
      ],
    });
    check(r.result && r.result.next === 'paused' && !r.result.stop && r.clerkCmds[2] === RELEASE, 'paused: exit 3 ends the run paused and releases', { result: r.result, seq: seq(r) });
    const r2 = await run(ARGS, { clerk: [[CLAIM, { ok: false, verb: 'claim', exit: 3, next: 'paused', error: 'paused: owner' }]] });
    check(r2.result.next === 'paused' && r2.clerkCmds.length === 1, 'paused: a paused claim took nothing, so nothing is released', seq(r2));
    const r3 = await run(ARGS, { clerk: [[CLAIM, adv(status({ next: 'paused' }))], [RELEASE, releaseOk]] });
    check(r3.result.next === 'paused' && r3.dispatches.length === 0, 'paused: a status next of paused is terminal', r3.result);
  }

  // --- ok:false: stop with advance's failure, after release
  {
    const fail = { ok: false, verb: 'advance', exit: 2, next: 'open-round', error: 'working tree not clean', failed: 'open-round', steps: ['judge'], rejected: [] };
    const r = await run(ARGS, { clerk: [[CLAIM, adv(build([story(1)]))], [ADV, fail], [RELEASE, releaseOk]] });
    const s = r.result.stop || {};
    check(s.failed === 'open-round' && s.exit === 2 && s.error === 'working tree not clean' && JSON.stringify(s.steps) === '["judge"]',
      'ok:false: the stop carries failed, exit, error and steps', r.result);
    check(r.clerkCmds[r.clerkCmds.length - 1] === RELEASE && r.mismatches.length === 0, 'ok:false: release still runs', seq(r));
    const r2 = await run(ARGS, { clerk: [[CLAIM, { ok: false, verb: 'claim', exit: 2, next: 'error', error: 'held by aaaaaaaaaaaaaaaa' }]] });
    check(r2.result.stop && r2.result.stop.verb === 'claim' && /held by/.test(r2.result.stop.error) && r2.clerkCmds.length === 1,
      'claim refused: stop verb claim, no release, one clerk call', { result: r2.result, seq: seq(r2) });
  }

  // --- next values the driver does not act on
  {
    const r = await run(ARGS, { clerk: [[CLAIM, adv(status({ next: 'repair', round: 1 }))], [RELEASE, releaseOk]] });
    check(r.result.stop && r.result.stop.verb === 'repair' && r.dispatches.length === 0, 'repair reaching the driver stops it, nothing dispatched', r.result);
    for (const next of ['escalated', 'shipped', 'green']) {
      const t = await run(ARGS, { clerk: [[CLAIM, adv(status({ next }))], [RELEASE, releaseOk]] });
      check(t.result.next === next && !t.result.stop && t.dispatches.length === 0 && t.clerkCmds[1] === RELEASE, `terminal ${next}: returns the status, releases`, t.result);
    }
    const u = await run(ARGS, { clerk: [[CLAIM, adv(status({ next: 'briefed' }))], [RELEASE, releaseOk]] });
    check(u.result.next === 'briefed' && !u.result.stop && u.dispatches.length === 0, 'unknown next: returned as is, no guess', u.result);
    const v = await run(ARGS, { clerk: [[CLAIM, adv(round('sonnet'))], [RELEASE, releaseOk]] });
    check(v.result.stop && v.result.stop.verb === 'dispatch' && v.dispatches.length === 0, 'unknown seat: stops instead of dispatching an agent that does not exist', v.result);
    // 0.19 C: a hand step stops the run cleanly - no worker, a stop naming the ids and the command, a release
    const m = await run(ARGS, { clerk: [[CLAIM, adv(status({ next: 'manual:music,art', manual: ['music', 'art'] }))], [RELEASE, releaseOk]] });
    check(m.result.stop && m.result.stop.verb === 'manual' && m.dispatches.length === 0 && m.clerkCmds[1] === RELEASE
      && JSON.stringify(m.result.stop.manual) === '["music","art"]'
      && m.result.stop.error.includes(`bash scripts/cycle.sh manual-done ${SPEC} music`) && m.result.stop.error.includes(`manual-done ${SPEC} art`),
      'manual: stops before any dispatch, names each step and its manual-done command, releases', { result: m.result, seq: seq(m) });
  }

  // --- iteration cap: a fresh story every wave never trips the miss bound, so only the cap ends
  // it (past 100 calls the clerk garbles, so a driver without the cap ends instead of looping)
  {
    const r = await run(ARGS, {
      clerk: (cmd, n) => cmd === RELEASE ? releaseOk
        : n > 100 ? 'garbled'
        : adv(build([story(1, { file: `${SPEC}/demo-${n}.md` })])),
    });
    check(r.result.stop && r.result.stop.verb === 'driver' && /iteration cap 40/.test(r.result.stop.error)
      && r.dispatches.length === 40 && r.clerkCmds[r.clerkCmds.length - 1] === RELEASE,
      'iteration cap: 40 iterations, then a stop and a release', { stop: r.result.stop, n: r.dispatches.length });
  }

  // --- Fable-limit fallback: a refused dispatch runs once more on opus, same prompt and agent; never a third call
  {
    const REFUSED = "Agent terminated early due to an API error: You've reached your Fable limit. Switch to another model, or manage usage credits.";
    const reviewRun = (args, agents) => run(args, {
      clerk: [[CLAIM, adv(round('review', { tier: 1, court: null }))], [INGEST, adv(green())], [RELEASE, releaseOk]], agents,
    });
    const F = { ...ARGS, review_model: 'fable' };
    const r = await reviewRun(F, [REFUSED, 'review report']);
    const [d1, d2] = r.dispatches;
    check(r.dispatches.length === 2 && d1.model === 'fable' && d2.model === 'opus' && d2.agentType === 'lead-review' && d2.prompt === d1.prompt,
      'fallback: a Fable-refused reviewer runs once more on opus with the same prompt and agent', r.dispatches.map((d) => [d.agentType, d.model]));
    check(r.mismatches.length === 0 && r.result.next === 'green' && Array.isArray(r.result.fallbacks) && r.result.fallbacks.length === 1
      && JSON.stringify(r.result.fallbacks[0]) === JSON.stringify({ agent: 'lead-review', where: 'round-1/review', from: 'fable', to: 'opus' }),
      'fallback: the round goes on and the return value carries the one fallback', r.result);
    check(r.logs.includes('fallback: lead-review round-1/review fable -> opus (Fable limit)'), 'fallback: one console line', r.logs);
    const twice = await reviewRun(F, [REFUSED, REFUSED, 'never asked']);
    check(twice.dispatches.length === 2 && twice.result.next === 'green' && twice.result.fallbacks.length === 1 && twice.mismatches.length === 0,
      'fallback: a refusal on the redispatch makes no third call, the ingest records the seat as before', { n: twice.dispatches.length, result: twice.result });
    const thrown = await reviewRun(F, [{ throw: 'API Error: {"type":"error","error":{"type":"model_requires_usage_credits"}}' }, 'review report']);
    check(thrown.dispatches.length === 2 && thrown.dispatches[1].model === 'opus' && thrown.result.fallbacks.length === 1,
      'fallback: model_requires_usage_credits in a caught error is the same refusal', thrown.dispatches.map((d) => d.model));
    for (const [label, args] of [['opus passed', { ...ARGS, review_model: 'opus' }], ['no model passed', ARGS]]) {
      const n = await reviewRun(args, [REFUSED, 'never asked']);
      check(n.dispatches.length === 1 && n.result.fallbacks.length === 0, `fallback: ${label} is not redispatched`, n.dispatches.map((d) => d.model));
    }
    // the round-1 live case: a full report that quotes the refusal mid-text is a report, not a refusal
    const quoting = await reviewRun(F, ["COUNCIL REPORT\nVERDICT: GREEN\nASK 1: PASS - the driver redispatches on `model_requires_usage_credits` and on \"You've reached your Fable limit\"; see vulyk-cycle.js:41", 'never asked']);
    check(quoting.dispatches.length === 1 && quoting.result.fallbacks.length === 0,
      'fallback: a report quoting the refusal text mid-text is not redispatched', { m: quoting.dispatches.map((d) => d.model), f: quoting.result.fallbacks });
    const curly = await reviewRun(F, ['  Agent terminated early due to an API error: You’ve reached your Fable limit. Switch to another model.\n', 'review report']);
    check(curly.dispatches.length === 2 && curly.dispatches[1].model === 'opus' && curly.result.fallbacks.length === 1,
      'fallback: the real refusal with a U+2019 apostrophe is redispatched', curly.dispatches.map((d) => d.model));
    // the round-2 live case: the runtime puts the dispatch description before the early-stop line
    const prefixed = await reviewRun(F, ['"Council review round 2" failed: ' + REFUSED + ' Run /usage-credits to continue.', 'review report']);
    check(prefixed.dispatches.length === 2 && prefixed.dispatches[1].model === 'opus' && prefixed.result.fallbacks.length === 1,
      'fallback: the real refusal with a description prefix is redispatched', { m: prefixed.dispatches.map((d) => d.model), f: prefixed.result.fallbacks });
    // the 2026-10-27 live probe: inside a Workflow the refusal is agent() -> null; one ping on the same model decides
    const nul = await reviewRun(F, [null, null, 'review report']);
    const [n1, np, n2] = nul.dispatches;
    check(nul.dispatches.length === 3 && n1.model === 'fable' && np.model === 'fable' && np.agentType === undefined
      && np.prompt === 'Reply with the single word OK.' && n2.model === 'opus' && n2.agentType === 'lead-review' && n2.prompt === n1.prompt
      && nul.result.next === 'green' && nul.mismatches.length === 0
      && JSON.stringify(nul.result.fallbacks) === JSON.stringify([{ agent: 'lead-review', where: 'round-1/review', from: 'fable', to: 'opus' }]),
      'fallback: a null fable return with a null ping is redispatched once on opus, the round goes on',
      { m: nul.dispatches.map((d) => [d.agentType, d.model]), f: nul.result.fallbacks, next: nul.result.next });
    const pong = await reviewRun(F, [null, 'OK', 'never asked']);
    check(pong.dispatches.length === 2 && pong.dispatches[1].model === 'fable' && pong.result.fallbacks.length === 0
      && pong.result.next === 'green' && pong.mismatches.length === 0,
      'fallback: a null fable return with an answering ping is not redispatched, the empty return goes on as before',
      { m: pong.dispatches.map((d) => d.model), f: pong.result.fallbacks });
    const wn = await run(ARGS, { clerk: [[CLAIM, adv(build([story(1, { model: 'fable' })]))], [ADV, adv(build([story(1, { model: 'fable' })]))], [ADV, adv(build([story(1, { model: 'fable' })]))], [RELEASE, releaseOk]],
      agents: [null, 'OK', '   ', 'OK'] });
    check(wn.result.stop && wn.result.stop.error === 'worker returned empty - turn cap suspected (worker-code, maxTurns in .claude/agents/worker-code.md)'
      && wn.result.fallbacks.length === 0 && wn.dispatches.map((d) => d.model).join(',') === 'fable,fable,fable,fable',
      'fallback: an answering ping leaves the turn-cap stop as before', { stop: wn.result.stop, m: wn.dispatches.map((d) => d.model) });
    for (const [label, args] of [['opus passed', { ...ARGS, review_model: 'opus' }], ['no model passed', ARGS]]) {
      const n = await reviewRun(args, [null, 'never asked']);
      check(n.dispatches.length === 1 && n.result.fallbacks.length === 0, `fallback: a null return with ${label} makes no ping`, n.dispatches.map((d) => d.model));
    }
    const nn = await reviewRun(F, [null, null, null, 'never asked']);
    check(nn.dispatches.length === 3 && nn.result.fallbacks.length === 1, 'fallback: a null redispatch makes no second ping', nn.dispatches.map((d) => d.model));
    const sw = story(1, { model: 'fable' });
    const done = await run(ARGS, { clerk: [[CLAIM, adv(build([sw]))], [ADV, adv(green())], [RELEASE, releaseOk]],
      agents: ['STATUS: DONE\nFILES: .claude/workflows/vulyk-cycle.js\nCONCERNS: refused() now matches model_requires_usage_credits in a short string', 'never asked'] });
    check(done.dispatches.length === 1 && done.result.fallbacks.length === 0,
      'fallback: a short STATUS: DONE return naming model_requires_usage_credits is not redispatched', { m: done.dispatches.map((d) => d.model), f: done.result.fallbacks });
    const other = await reviewRun(F, [{ throw: 'usage_limit_reached: five-hour limit' }, 'never asked']);
    check(other.dispatches.length === 1 && other.result.fallbacks.length === 0, 'fallback: another limit is not redispatched', other.dispatches.map((d) => d.model));
    // workers and the retry on top_model go through the same helper
    const a = story(1, { model: 'fable' });
    const w = await run(ARGS, { clerk: [[CLAIM, adv(build([a]))], [ADV, adv(green())], [RELEASE, releaseOk]], agents: [REFUSED, 'worker report'] });
    check(w.dispatches.map((d) => d.model).join(',') === 'fable,opus'
      && JSON.stringify(w.result.fallbacks) === JSON.stringify([{ agent: 'worker-code', where: 'demo-01', from: 'fable', to: 'opus' }]),
      'fallback: a refused worker is redispatched, where is the story id', { m: w.dispatches.map((d) => d.model), f: w.result.fallbacks });
    const b = story(1, { model: 'sonnet' });
    const rt = await run(ARGS, {
      clerk: [[CLAIM, adv(build([b]))], [ADV, adv(build([b]))], [ADV, adv(green())], [RELEASE, releaseOk]], agents: ['missed', REFUSED, 'retry report'],
    });
    check(rt.dispatches.map((d) => d.model).join(',') === 'sonnet,fable,opus' && rt.result.next === 'green' && rt.result.fallbacks.length === 1,
      'fallback: the retry on top_model is redispatched on opus when Fable refuses', rt.dispatches.map((d) => d.model));
    // a stop carries the list too; a run with no refusal carries an empty one
    const st = await run(ARGS, { clerk: [[CLAIM, adv(round('sonnet'))], [RELEASE, releaseOk]] });
    const ok = await run(ARGS, { clerk: [[CLAIM, adv(build([story(1)]))], [ADV, adv(green())], [RELEASE, releaseOk]] });
    check(st.result.stop && Array.isArray(st.result.fallbacks) && st.result.fallbacks.length === 0
      && Array.isArray(ok.result.fallbacks) && ok.result.fallbacks.length === 0, 'fallback: no refusal returns fallbacks: [] on a stop and on green', [st.result, ok.result]);
  }

  check(!everyAgentType.has('queen-planner'), 'no queen-planner dispatch in any scenario', [...everyAgentType]);
  console.log(`${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.log('FAIL harness threw: ' + (e && e.stack || e)); process.exit(1); });
NODE_EOF
