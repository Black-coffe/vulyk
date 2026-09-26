export const meta = {
  name: 'vulyk-cycle',
  description: 'build → council → repair, round ceiling by tier (1 / 2 / 3 for Tier 1 / 2 / 3-4, the same again per reopen)',
  phases: [
    { title: 'Build' },
    { title: 'Council' },
  ],
}

// This driver dispatches agents and decides nothing else: no verdict, ceiling, staleness,
// branch, round or repair. `scripts/cycle.sh advance` runs every mechanical verb up to the next
// agent boundary and hands back the state (ADR-013 D2, D6). The runtime has no shell, so each
// boundary costs one cycle-clerk call - `advance --claim` at the start, `advance` after a wave,
// `advance --ingest` after a council dispatch - and `release` closes the run. Every state the
// loop acts on is the `status` object the last `advance` carried; `status` itself is asked only
// to recover a clerk line that cannot be read, never re-running a verb that may have acted.
// What the driver remembers is per run and bounds re-dispatch only: misses per story file (two
// end the run) and dispatches per seat per round (a third ends the run).
// There is no deadline in here because the runtime has no clock; deadlines live in the verbs
// (`close-story`'s verification timeout) and in each agent's own Bash timeouts.

const TERMINAL = ['green', 'escalated', 'paused', 'shipped']
// advance runs these itself - one reaching the driver means advance stopped short of a boundary
const ADVANCE_VERBS = ['branch', 'open-round', 'judge', 'repair']
const SEAT_AGENT = { haiku: 'council-haiku', opus: 'council-opus', review: 'lead-review' }
const BLIND = ['haiku', 'opus']
// mirrors maxTurns in .claude/agents/*.md - update both together
const CAPS = { 'worker-code': 90, 'worker-test': 90, 'council-haiku': 60, 'council-opus': 60, 'lead-review': 60 }
const MAX_ITERATIONS = 40

// Why a dispatch came back dead: a rejected agent() (carried as { threw }) or an empty return,
// the shape a turn-cap death takes. Null for any non-empty text - the driver never reads it.
const reasonFor = (who, agentType, r) => {
  if (r && typeof r === 'object' && 'threw' in r) return `${who} threw: ${r.threw}`
  if (typeof r === 'string' && r.trim() !== '') return null
  return `${who} returned empty - turn cap suspected (${agentType}, maxTurns ${CAPS[agentType] ?? 'unknown'} in .claude/agents/${agentType}.md)`
}
const caught = (p) => p.catch((e) => ({ threw: e && e.message ? e.message : String(e) }))

const A = args ?? {}
const spec = A.spec
const stamp = A.stamp // workers get it for close-story; blind seats never see it
const TOP = A.top_model || 'opus'
const SECOND = A.second_model
if (typeof stamp !== 'string' || stamp.length < 12) {
  return { stop: { verb: 'launch', error: 'args.stamp missing: launch with the 16-hex random stamp of /vulyk-build step 1' } }
}
if (typeof spec !== 'string' || spec === '') {
  return { stop: { verb: 'launch', error: 'args.spec missing: launch with the spec dir' } }
}
log(`vulyk-cycle: ${spec} · stamp ${stamp}`)

class BadLine extends Error {
  constructor(line) { super('cycle-clerk returned a line that is not a JSON object'); this.line = line }
}
class Stop extends Error {
  constructor(result) { super('driver stop'); this.result = result }
}
class Paused extends Error {
  constructor() { super('paused') }
}
const fail = (state, stop) => { throw new Stop({ ...state, stop }) }

// A status object, not a verb's error envelope (which carries `ok`).
const isStatus = (o) => o !== null && typeof o === 'object' && typeof o.next === 'string' && !('ok' in o)

const ask = async (cmd) => {
  const out = await agent(
    `Run exactly: bash scripts/cycle.sh ${cmd}\nReturn the last stdout line verbatim.`,
    { agentType: 'cycle-clerk', effort: 'low' },
  ).catch(() => null)
  const line = (out === null || out === undefined ? '' : String(out)).trim().split('\n').pop()
  let parsed = null
  try { parsed = JSON.parse(line) } catch { /* not JSON */ }
  if (parsed === null || typeof parsed !== 'object') throw new BadLine(line)
  return parsed
}

// Cleared only by an explicit claim refusal. A release the run did not need is harmless -
// cycle.sh refuses to release a stamp it does not hold - while a skipped one strands the lock.
let claimed = true
const refusedClaim = (r) => r.ok === false && (r.verb === 'claim' || r.failed === 'claim')

// One `advance`; its ok:false line comes back for the caller to stop on. A line that is not
// JSON, or an ok line without a status, costs one read-only `status --json` - the verb may
// already have acted - and a second unreadable line ends the run with that raw line.
const advance = async (flags) => {
  const cmd = `advance ${spec} --stamp ${stamp}${flags}`
  let res = null
  try { res = await ask(cmd) } catch (e) { if (!(e instanceof BadLine)) throw e }
  if (res !== null && refusedClaim(res)) claimed = false
  if (res !== null && res.exit === 3) throw new Paused()
  if (res !== null && (res.ok === false || isStatus(res.status))) return res
  log(`cycle-clerk: unreadable result from "${cmd}", reading status instead`)
  const st = await ask(`status ${spec} --json`)
  if (st.exit === 3) throw new Paused()
  if (st.ok === false) return st
  if (!isStatus(st)) throw new BadLine(JSON.stringify(st))
  return { ok: true, verb: 'advance', exit: 0, next: st.next, steps: [], rejected: [], status: st, recovered: 'status' }
}

const misses = new Map() // story file -> misses this run
const dispatched = new Map() // `${round}:${seat}` -> dispatches this run
let rejected = [] // the last advance's `rejected`, for the one re-ask

const build = async (st) => {
  phase('Build')
  const stories = st.wave_stories || []
  const returns = await parallel(stories.map((story) => () => {
    const retry = (misses.get(story.file) || 0) >= 1
    const prompt = `Your story: ${story.file}. Stamp: ${stamp}. Implement it per your protocol; your last step is \`bash scripts/cycle.sh close-story ${story.file} --commit --stamp ${stamp}\`.`
      + (retry ? ' Note: a previous attempt may have left uncommitted edits in your files; `git diff` them first.' : '')
    return caught(agent(prompt, { agentType: story.worker, model: retry ? TOP : story.model, phase: 'Build', label: story.story }))
  }))
  const res = await advance('')
  if (res.ok === false) return res
  // a dispatched story still listed is still todo: close-story never closed it
  const left = new Set((res.status.wave_stories || []).map((s) => s.file))
  stories.forEach((story, i) => {
    if (!left.has(story.file)) return
    const why = reasonFor('worker', story.worker, returns[i]) ?? `worker returned, but ${story.file} is still todo - close-story did not close it`
    const n = (misses.get(story.file) || 0) + 1
    misses.set(story.file, n)
    log(`miss ${n} on ${story.file}: ${why}`)
    if (n >= 2) fail(res.status, { verb: 'build', file: story.file, error: why })
  })
  return res
}

// A blind seat gets slug, round and COURT only: no spec dir, no round dir (the taint rule), no stamp.
const seatPrompt = (seat, st) =>
  `Council round ${st.round} for ${st.slug}, seat ${seat}. Work only inside COURT: ${st.court}. Judge COURT/brief.md's ## Asks per your seat contract.`
// Round 1 reviews the branch; a later round reviews only what changed since the last one.
const reviewPrompt = (st) => {
  const scope = st.since
    ? `review only ${st.since}..${st.head} and whether it fixes the findings in ${st.spec}/council/round-${st.round - 1}/`
    : 'review the whole branch against its base'
  return `Review for ${st.slug}, round ${st.round}. Spec: ${st.spec}. Branch ${st.branch} at ${st.head}: ${scope}.`
}
// `advance --ingest` records these files; a missing one is recorded empty and spends the attempt.
const reportNote = (st, name, k) =>
  ` As your last action, write your full report verbatim to .vulyk/reports/${st.slug}/round-${st.round}/${name}.attempt-${k}.md (mkdir -p its directory); your chat reply is the same text.`
const rejectionFor = (seat) => {
  const r = rejected.filter((x) => x && x.seat === seat).pop()
  return r && r.error ? r.error : 'no reason reached the driver - write the report again, exactly in your contract\'s format.'
}

const council = async (st) => {
  phase('Council')
  const seats = st.next.slice('dispatch:'.length).split(',').filter(Boolean)
  for (const seat of seats) {
    if (!SEAT_AGENT[seat]) fail(st, { verb: 'dispatch', seat, error: `no agent for seat ${seat}` })
    if (BLIND.includes(seat) && !st.court) fail(st, { verb: 'dispatch', seat, error: `seat ${seat} is blind but status.court is null` })
    if ((dispatched.get(`${st.round}:${st.head}:${seat}`) || 0) >= 2) {
      fail(st, { verb: 'dispatch', seat, round: st.round, error: `seat ${seat} still missing after two dispatches in round ${st.round}` })
    }
  }
  const jobs = []
  for (const seat of seats) {
    // keyed by head too: a round that went stale is re-stamped in place (same N, new head) and its
    // discarded reports must not count against the fresh round's two dispatches
    const key = `${st.round}:${st.head}:${seat}`
    const n = (dispatched.get(key) || 0) + 1
    dispatched.set(key, n)
    const k = (st.seat_attempt && st.seat_attempt[seat]) || 1
    const note = n > 1 ? `\nYour previous report was rejected: ${rejectionFor(seat)}` : ''
    if (seat === 'review' && st.tier === 4) {
      // two reviewers on different models; advance --ingest folds their files into one review
      jobs.push({ who: 'reviewer (top)', agentType: 'lead-review', model: TOP, prompt: reviewPrompt(st) + note + reportNote(st, 'review-top', k) })
      jobs.push({ who: 'reviewer (second)', agentType: 'lead-review', model: SECOND, prompt: reviewPrompt(st) + note + reportNote(st, 'review-second', k) })
    } else if (seat === 'review') {
      jobs.push({ who: 'reviewer', agentType: 'lead-review', model: undefined, prompt: reviewPrompt(st) + note + reportNote(st, 'review', k) })
    } else {
      jobs.push({ who: `seat ${seat}`, agentType: SEAT_AGENT[seat], model: undefined, prompt: seatPrompt(seat, st) + note + reportNote(st, seat, k) })
    }
  }
  const returns = await parallel(jobs.map((j) => () =>
    caught(agent(j.prompt, { agentType: j.agentType, model: j.model, phase: 'Council', label: j.who }))))
  jobs.forEach((j, i) => {
    const why = reasonFor(j.who, j.agentType, returns[i])
    if (why !== null) log(why)
  })
  return advance(' --ingest')
}

let st = {}
try {
  let res = await advance(' --claim')
  for (let i = 0; ; i++) {
    if (res.ok === false) {
      fail(st, { verb: res.verb, failed: res.failed, exit: res.exit, next: res.next, error: res.error, steps: res.steps })
    }
    st = res.status
    rejected = Array.isArray(res.rejected) ? res.rejected : []
    const ran = Array.isArray(res.steps) && res.steps.length ? ` · ran ${res.steps.join(', ')}` : ''
    log(`${st.slug} · ${st.stage} · next: ${st.next}${ran}`)
    if (TERMINAL.includes(st.next)) return st
    if (i >= MAX_ITERATIONS) fail(st, { verb: 'driver', error: `iteration cap ${MAX_ITERATIONS} reached at next: ${st.next}` })
    // before any worker or seat is dispatched: Tier 4's two reviewers need two different models
    if (st.tier === 4 && (!SECOND || SECOND === TOP)) {
      fail(st, { verb: 'launch', error: 'second_model missing or equal to top_model on a Tier 4 spec' })
    }
    if (st.next.startsWith('build:')) res = await build(st)
    else if (st.next.startsWith('dispatch:')) res = await council(st)
    else if (ADVANCE_VERBS.includes(st.next)) fail(st, { verb: st.next, error: `advance left ${st.next} to the driver` })
    else return st // an unrecognised `next` - report it rather than guess at an action
  }
} catch (e) {
  if (e instanceof Stop) return e.result
  if (e instanceof Paused) return { next: 'paused' }
  if (e instanceof BadLine) return e.line
  throw e
} finally {
  if (claimed) await ask(`release ${spec} ${stamp}`).catch(() => {})
}
