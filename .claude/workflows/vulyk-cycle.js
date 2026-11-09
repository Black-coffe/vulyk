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
// There is no deadline in here: deadlines live in the verbs (`close-story`'s verification timeout)
// and in each agent's own Bash timeouts. The script reads no clock: the runtime refuses one at launch
// (it breaks resume). The checkpoint (C10) takes its time from outside: past `checkpoint_min` between
// `args.launched_at` and the `now` the last verb answer carried (both epoch seconds), the next wave,
// gate step or seat dispatch is not started and the run returns `checkpoint`, so the Queen's turn
// comes back before her 1 h cache lapses. Either one missing: no checkpoint, the run goes on.

const TERMINAL = ['green', 'escalated', 'paused', 'shipped']
// advance runs these itself - one reaching the driver means advance stopped short of a boundary
const ADVANCE_VERBS = ['branch', 'open-round', 'judge', 'repair']
const SEAT_AGENT = { haiku: 'council-haiku', opus: 'council-opus', review: 'lead-review', review2: 'lead-review' }
const BLIND = ['haiku', 'opus']
const MAX_ITERATIONS = 40

// Why a dispatch came back dead: a rejected agent() (carried as { threw }) or an empty return,
// the shape a turn-cap death takes. Null for any non-empty text - the driver never reads it.
// The cap is named by file, not by number: agent frontmatter is its one source, and a hive that
// raises a maxTurns there needs no second edit here (the runtime cannot read the file).
const reasonFor = (who, agentType, r) => {
  if (r && typeof r === 'object' && 'threw' in r) return `${who} threw: ${r.threw}`
  if (typeof r === 'string' && r.trim() !== '') return null
  return `${who} returned empty - turn cap suspected (${agentType}, maxTurns in .claude/agents/${agentType}.md)`
}
const caught = (p) => p.catch((e) => ({ threw: e && e.message ? e.message : String(e) }))
// The Fable-limit refusal. A caught error (caught() swallowed it) matches either form anywhere; a
// returned string only when it names the limit AND is not a report: it is short (the real refusal,
// '"<description>" failed: Agent terminated early due to an API error: You've reached your Fable
// limit. ...', runs about 250 characters; REFUSAL_MAX = 600) and no line opens with a report header
// (VERDICT, COUNCIL, STATUS), so a report that quotes the refusal (a judge reviewing this very
// feature) is a report. Nothing else matches: an Opus or Sonnet limit, usage_limit_reached or any
// other API error behaves as before.
const REFUSAL = /You['\u2019]ve reached your Fable limit|model_requires_usage_credits/
const REFUSAL_MAX = 600
const REPORT_HEADER = /^\s*(VERDICT|COUNCIL|STATUS)\b/m
const refused = (r) => {
  if (r && typeof r === 'object' && 'threw' in r) return typeof r.threw === 'string' && REFUSAL.test(r.threw)
  return typeof r === 'string' && r.trim().length <= REFUSAL_MAX && REFUSAL.test(r) && !REPORT_HEADER.test(r)
}

const A = args ?? {}
const spec = A.spec
const stamp = A.stamp // workers get it for close-story; blind seats never see it
const TOP = A.top_model || 'opus'
const SECOND = A.second_model
// the model profile's families (/vulyk-build passes them only off sonnet-builds); absent, the frontmatter decides
const WORKER = A.worker_model || undefined
const REVIEW = A.review_model || undefined
const SEAT = A.seat_model || undefined
// a missed story's retry: the first of [TOP, opus] that is not a family judging this round (REVIEW when passed, else
// opus at Tier 1-3; TOP at Tier 4, beside REVIEW when passed); none left -> opus, and the result says retry_same_family
let retrySameFamily = false
const retryModel = (tier) => {
  const judges = tier === 4 ? [TOP, REVIEW].filter(Boolean) : [REVIEW || 'opus']
  const pick = [TOP, 'opus'].find((m) => !judges.includes(m))
  if (pick) return pick
  retrySameFamily = true
  return 'opus'
}
const same = () => (retrySameFamily ? { retry_same_family: true } : {})
// a Fable-refused dispatch runs once more on this family (the owner's ADR-015 exception); no model passed means the frontmatter's opus
const FALLBACK_MODEL = 'opus'
const fallbacks = [] // {agent, where, from, to}, carried in the return value for /vulyk-build to record
// ab-run-fixes C10: minutes from launch after which the driver stops at the next boundary (default 50)
const CHECKPOINT_MIN = Number.isFinite(Number(A.checkpoint_min)) && A.checkpoint_min !== null && A.checkpoint_min !== '' ? Number(A.checkpoint_min) : 50
// epoch seconds from a number or a numeric string; NaN for anything else (null and '' are not 0)
const epoch = (v) => ((typeof v === 'number' || (typeof v === 'string' && v.trim() !== '')) && Number.isFinite(Number(v)) ? Number(v) : NaN)
const LAUNCHED = epoch(A.launched_at) // the Queen passes it at launch
let verbNow = NaN // epoch seconds of the last verb answer that carried `now`
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
class Checkpoint extends Error {
  constructor(next, elapsed) { super('checkpoint'); this.next = next; this.elapsed = elapsed }
}
// A boundary: only after this run has done some work (a dispatch or a gate step), never at launch.
let worked = false
const boundary = (st) => {
  if (!worked || !Number.isFinite(LAUNCHED) || !Number.isFinite(verbNow)) return
  const elapsed = Math.floor((verbNow - LAUNCHED) / 60)
  if (elapsed >= CHECKPOINT_MIN) throw new Checkpoint(st.next, elapsed)
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
  // `now` sits at the top level of an emit() line, and only inside `status` on advance and suite
  const now = Number.isFinite(epoch(parsed.now)) ? epoch(parsed.now)
    : epoch(parsed.status !== null && typeof parsed.status === 'object' ? parsed.status.now : undefined)
  if (Number.isFinite(now)) verbNow = now
  return parsed
}

// Cleared only by an explicit claim refusal. A release the run did not need is harmless -
// cycle.sh refuses to release a stamp it does not hold - while a skipped one strands the lock.
let claimed = true
const refusedClaim = (r) => r.ok === false && (r.verb === 'claim' || r.failed === 'claim')

// One `advance`; its ok:false line comes back for the caller to stop on. A line that is not
// JSON, or an ok line without a status, costs one read-only `status --json` - the verb may
// already have acted - and a second unreadable line ends the run with that raw line.
// Not after `--claim`, unless the line said ok:true (advance stops on a refused claim): status
// does not name the DRIVER holder, so it cannot prove the claim, and a run on another driver's
// claim would dispatch beside it. A short re-claim by the same stamp proves it instead (ask 17): claim is
// idempotent for the stamp that holds the spec, so ok:true proves the claim and status is read; a
// refusal stops before any dispatch; an unreadable re-claim stops unproven. Both stops still release
// (a stamp the run does not hold is refused); a relaunch claims afresh.
const advance = async (flags) => {
  const cmd = `advance ${spec} --stamp ${stamp}${flags}`
  let res = null
  let bad = null
  try { res = await ask(cmd) } catch (e) { if (!(e instanceof BadLine)) throw e; bad = e.line }
  if (res !== null && refusedClaim(res)) claimed = false
  if (res !== null && res.exit === 3) throw new Paused()
  if (res !== null && (res.ok === false || isStatus(res.status))) return res
  if (flags.includes('--claim') && !(res !== null && res.ok === true)) {
    const line = bad === null ? JSON.stringify(res) : bad
    let re = null
    try { re = await ask(`claim ${spec} ${stamp}`) } catch (e) { if (!(e instanceof BadLine)) throw e }
    if (re !== null && re.exit === 3) throw new Paused()
    if (re !== null && re.ok === false) {
      return { ok: false, verb: 'claim', failed: 'claim', exit: re.exit, next: re.next, steps: [],
        error: `re-claim after an unreadable "${cmd}" refused: ${re.error}` }
    }
    if (re === null || re.ok !== true) {
      return { ok: false, verb: 'advance', failed: 'claim', exit: 2, next: 'error', steps: [],
        error: `unreadable result from "${cmd}": the claim is unproven, launch again; clerk line: ${line}` }
    }
    // proven; the re-claim by the holder carries no leftover list, so this run dispatches without leftover notes
  }
  log(`cycle-clerk: unreadable result from "${cmd}", reading status instead`)
  const st = await ask(`status ${spec} --json`)
  if (st.exit === 3) throw new Paused()
  if (st.ok === false) return st
  if (!isStatus(st)) throw new BadLine(JSON.stringify(st))
  return { ok: true, verb: 'advance', exit: 0, next: st.next, steps: [], rejected: [], status: st, recovered: 'status' }
}

// Every worker and seat dispatch: on a Fable refusal with a model other than FALLBACK_MODEL passed,
// the same prompt and agent once more on FALLBACK_MODEL. Not an attempt - the refused call wrote no
// report - and never a third call: a second refusal goes down the dead-dispatch path as before.
// Inside a Workflow the refusal comes back as null (live probe 2026-10-27), so an empty return asks
// one cheap ping on the same model: an empty or refused ping is the limit, an answer keeps the empty
// result for the turn-cap path. One ping per dispatch, none on the redispatch.
const empty = (r) => r === null || r === undefined || (typeof r === 'string' && r.trim() === '')
const dispatch = async (prompt, opts, where) => {
  const r = await caught(agent(prompt, opts))
  if (!opts.model || opts.model === FALLBACK_MODEL) return r
  if (!refused(r)) {
    if (!empty(r)) return r
    const ping = await caught(agent('Reply with the single word OK.', { label: `ping:${where}`, model: opts.model }))
    if (!empty(ping) && !refused(ping)) return r
  }
  fallbacks.push({ agent: opts.agentType, where, from: opts.model, to: FALLBACK_MODEL })
  log(`fallback: ${opts.agentType} ${where} ${opts.model} -> ${FALLBACK_MODEL} (Fable limit)`)
  return caught(agent(prompt, { ...opts, model: FALLBACK_MODEL }))
}

const misses = new Map() // story file -> misses this run
let leftover = new Set() // story files claim found leftover edits in (ab-run-fixes C9)
const LEFTOVER_NOTE = ' Note: a previous attempt left uncommitted edits in your ## Files: read `git diff` first, finish the story and close it.'
const dispatched = new Map() // `${round}:${seat}` -> dispatches this run
let rejected = [] // the last advance's `rejected`, for the one re-ask

const build = async (st) => {
  phase('Build')
  const stories = st.wave_stories || []
  const returns = await parallel(stories.map((story) => () => {
    const retry = (misses.get(story.file) || 0) >= 1
    const prompt = `Your story: ${story.file}. Stamp: ${stamp}. Implement it per your protocol; your last step is \`bash scripts/cycle.sh close-story ${story.file} --commit --stamp ${stamp}\`.`
      + (leftover.has(story.file) ? LEFTOVER_NOTE : retry ? ' Note: a previous attempt may have left uncommitted edits in your files; `git diff` them first.' : '')
    return dispatch(prompt, { agentType: story.worker, model: retry ? retryModel(st.tier) : (story.model || WORKER), phase: 'Build', label: story.story }, story.story)
  }))
  worked = true
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

// The round's integration gate: `cycle.sh suite` runs one step per call into council/round-N/suite.log
// and says done:true when the log is finished; a finished log answers with a no-op. Every call goes
// through the clerk (no shell here); ok:false stops the run like any refused verb. A clerk line that
// cannot be read is asked again within the same 32 calls: safe, since each call resumes the log at
// its next step and a finished log is a no-op, so a step the lost line ran is never run twice.
const SUITE_CALLS = 32
const gate = async (st) => {
  const cmd = `suite ${spec} --commit --stamp ${stamp}`
  let bad = null
  for (let k = 0; k < SUITE_CALLS; k++) {
    boundary(st)
    let r
    try { r = await ask(cmd) } catch (e) {
      if (!(e instanceof BadLine)) throw e
      bad = e.line
      log(`cycle-clerk: unreadable result from "${cmd}", asking suite again`)
      continue
    } finally { worked = true }
    if (r.exit === 3) throw new Paused()
    if (r.ok === false) fail(st, { verb: r.verb || 'suite', failed: r.failed, exit: r.exit, next: r.next, error: r.error })
    if (r.done === true) return
  }
  fail(st, { verb: 'suite', error: `suite not done after ${SUITE_CALLS} calls` + (bad === null ? '' : `; last unreadable clerk line: ${bad}`) })
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
  await gate(st)
  boundary(st)
  const jobs = []
  for (const seat of seats) {
    // keyed by head too: a round that went stale is re-stamped in place (same N, new head) and its
    // discarded reports must not count against the fresh round's two dispatches
    const key = `${st.round}:${st.head}:${seat}`
    const n = (dispatched.get(key) || 0) + 1
    dispatched.set(key, n)
    const k = (st.seat_attempt && st.seat_attempt[seat]) || 1
    const note = n > 1 ? `\nYour previous report was rejected: ${rejectionFor(seat)}` : ''
    // exactly the seats `next` names, never doubled by tier: Tier 4's review runs on TOP, and review2 -
    // the second reviewer `next` names on a risk path or after a BLOCK - is one lead-review on SECOND
    if (seat === 'review2') {
      jobs.push({ who: 'reviewer (second)', agentType: 'lead-review', model: SECOND, name: 'review2', prompt: reviewPrompt(st) + note + reportNote(st, 'review2', k) })
    } else if (seat === 'review') {
      jobs.push({ who: 'reviewer', agentType: 'lead-review', model: st.tier === 4 ? TOP : REVIEW, name: 'review', prompt: reviewPrompt(st) + note + reportNote(st, 'review', k) })
    } else {
      jobs.push({ who: `seat ${seat}`, agentType: SEAT_AGENT[seat], model: SEAT, name: seat, prompt: seatPrompt(seat, st) + note + reportNote(st, seat, k) })
    }
  }
  const returns = await parallel(jobs.map((j) => () =>
    dispatch(j.prompt, { agentType: j.agentType, model: j.model, phase: 'Council', label: j.who }, `round-${st.round}/${j.name}`)))
  jobs.forEach((j, i) => {
    const why = reasonFor(j.who, j.agentType, returns[i])
    if (why !== null) log(why)
  })
  return advance(' --ingest')
}

let st = {}
try {
  let res = await advance(' --claim')
  if (Array.isArray(res.leftover)) leftover = new Set(res.leftover)
  for (let i = 0; ; i++) {
    if (res.ok === false) {
      fail(st, { verb: res.verb, failed: res.failed, exit: res.exit, next: res.next, error: res.error, steps: res.steps })
    }
    st = res.status
    rejected = Array.isArray(res.rejected) ? res.rejected : []
    const ran = Array.isArray(res.steps) && res.steps.length ? ` · ran ${res.steps.join(', ')}` : ''
    log(`${st.slug} · ${st.stage} · next: ${st.next}${ran}`)
    if (TERMINAL.includes(st.next)) return { ...st, fallbacks, ...same() }
    if (i >= MAX_ITERATIONS) fail(st, { verb: 'driver', error: `iteration cap ${MAX_ITERATIONS} reached at next: ${st.next}` })
    // before any worker or seat is dispatched: Tier 4's review and review2 need two different models
    if (st.tier === 4 && (!SECOND || SECOND === TOP)) {
      fail(st, { verb: 'launch', error: 'second_model missing or equal to top_model on a Tier 4 spec' })
    }
    // 0.19 C: a hand step (blocked_by manual:<id>) - stop before any dispatch; the Queen does it
    if (st.next.startsWith('manual:')) {
      const ids = st.next.slice('manual:'.length).split(',').filter(Boolean)
      const cmds = ids.map((id) => `bash scripts/cycle.sh manual-done ${spec} ${id}`).join('; ')
      fail(st, { verb: 'manual', manual: ids, error: `waiting on manual step ${ids.map((id) => `'${id}'`).join(', ')} - do it, then: ${cmds}, and launch again` })
    }
    if (st.next.startsWith('build:') || st.next.startsWith('dispatch:')) boundary(st)
    if (st.next.startsWith('build:')) res = await build(st)
    else if (st.next.startsWith('dispatch:')) res = await council(st)
    else if (ADVANCE_VERBS.includes(st.next)) fail(st, { verb: st.next, error: `advance left ${st.next} to the driver` })
    else return { ...st, fallbacks, ...same() } // an unrecognised `next` - report it rather than guess at an action
  }
} catch (e) {
  if (e instanceof Stop) return { ...e.result, fallbacks, ...same() }
  if (e instanceof Paused) return { next: 'paused', fallbacks, ...same() }
  // /vulyk-build journals it and relaunches with a fresh stamp; `finally` releases the claim
  if (e instanceof Checkpoint) return { status: 'checkpoint', next: e.next, elapsed_min: e.elapsed, fallbacks, ...same() }
  // the raw line stays a string; a fallback before it is in the console log only
  if (e instanceof BadLine) return e.line
  throw e
} finally {
  if (claimed) await ask(`release ${spec} ${stamp}`).catch(() => {})
}
