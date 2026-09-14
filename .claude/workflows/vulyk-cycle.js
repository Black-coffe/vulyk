export const meta = {
  name: 'vulyk-cycle',
  description: 'build → council → repair, ceiling 3',
  phases: [
    { title: 'Build' },
    { title: 'Round' },
    { title: 'Judge' },
    { title: 'Repair' },
  ],
}

// This driver holds no verdict or staleness logic and never parses prose except the first
// line of a review report (VERDICT: PASS|BLOCK, folded at Tier 4) - it loops on
// scripts/cycle.sh's `status --json` and acts on every verb's exit code too (ADR-001 D2):
// ok:false ends the run with the failure in the returned object, except a record-seat
// MALFORMED (re-ask that seat once) and a second failed close-story for the same file (also
// ends the run, naming the file instead of an exit code). Everything else it knows about the
// state comes from `status --json`; a decision that needs more than `next`, `wave_stories`,
// `court`, `round`, `round_dir`, `spec`, `branch`, `head` or `tier` means the status contract
// is missing a key, not something to work around here.

const TERMINAL = ['green', 'escalated', 'paused', 'shipped']
const SEAT_AGENT = { haiku: 'council-haiku', sonnet: 'council-sonnet', opus: 'council-opus', review: 'lead-review' }

const A = args ?? {} // a missing args object reaches this guard instead of throwing on args.spec
const spec = A.spec
const TOP = A.top_model
const SECOND = A.second_model
const stamp = A.stamp // a per-run random value the seat is never told - only used to build the record-seat delimiter (R11/R31); never compared, parsed or shown to a seat
if (typeof stamp !== 'string' || stamp.length < 12) {
  return { stop: { verb: 'launch', error: 'args.stamp missing: launch with the 16-hex random stamp of /vulyk-build step 1' } }
}
log(`vulyk-cycle: ${spec} · stamp ${stamp}`)

class BadLine extends Error {
  constructor(line) { super('cycle-clerk returned a non-JSON last line'); this.line = line }
}

// A verb's own ok:false ends the run; Stop carries the full return value so the outer catch
// needs nothing from the loop's scope.
class Stop extends Error {
  constructor(result) { super('driver stop'); this.result = result }
}
// exit:3 (PAUSE) is a terminal on its own, from any verb - no stop shape, just next:'paused'.
class Paused extends Error {
  constructor(next) { super('paused'); this.next = next }
}
const fail = (st, stop) => { throw new Stop({ ...st, stop }) }
const asStop = (res) => ({ verb: res.verb, exit: res.exit, error: res.error })

// The Workflow runtime has no shell of its own - cycle-clerk is the only way to reach one.
// A non-JSON last line from any verb ends the whole run; the Queen reads the raw line at wake.
const clerk = (cmd) => agent(
  `Run exactly: bash scripts/cycle.sh ${cmd}\nReturn the last stdout line verbatim.`,
  { agentType: 'cycle-clerk', effort: 'low' },
).then((out) => {
  const line = String(out).trim().split('\n').pop()
  let parsed
  try { parsed = JSON.parse(line) } catch { throw new BadLine(line) }
  if (parsed.exit === 3) throw new Paused(parsed.next)
  return parsed
})

// A blind seat gets slug/round/court only (R9) - round_dir would let it name the very
// taint pattern C5 forbids it to repeat. lead-review is never blind, so it gets the full
// review packet instead: round_dir, the spec (its stories and plan), the branch to diff, ADR-001.
const seatPrompt = (seat, st) =>
  `Council round ${st.round} for ${st.slug}, seat ${seat}. Work only inside COURT: ${st.court}. Read COURT/brief.md's ## Asks and COURT/CLAUDE.md's ## Profile, then judge per your seat contract.`
const reviewPrompt = (st) =>
  `Adversarial review for ${st.slug}, round ${st.round}. Round dir: ${st.round_dir}. Spec: ${st.spec} - review its stories and plan. Diff the branch ${st.branch} at ${st.head} against its base. See docs/adr/001-cycle-state-contract.md. You do not enter the court.`

// Only prose this driver ever reads: a review report's first line (C5's PASS|BLOCK token).
// Folds two reviewer reports into one; a null/empty/prose report on either side never
// manufactures a verdict - the driver sends NO VERDICT through unchanged so record-seat
// rejects it (R28, N-C1).
function foldReviews(r1, r2) {
  const isEmpty = (r) => r === null || r === undefined || r === ''
  const firstLine = (r) => isEmpty(r) ? null : String(r).trim().split('\n')[0]
  const isVerdict = (line) => line !== null && /^VERDICT:\s*(PASS|BLOCK)\b/.test(line)
  const f1 = firstLine(r1)
  const f2 = firstLine(r2)
  if (isVerdict(f1) && isVerdict(f2)) {
    const block = /^VERDICT:\s*BLOCK\b/.test(f1) || /^VERDICT:\s*BLOCK\b/.test(f2)
    return `VERDICT: ${block ? 'BLOCK' : 'PASS'}\n${r1}\n${r2}`
  }
  const b1 = isEmpty(r1) ? '(no report)' : r1
  const b2 = isEmpty(r2) ? '(no report)' : r2
  return `NO VERDICT: top=${f1 ?? '(no report)'} · second=${f2 ?? '(no report)'}\n${b1}\n${b2}`
}

// Tier 4 folds a second reviewer on the paired model into the one `review` seat (R12); `note`
// carries the re-ask text on a record-seat MALFORMED retry, appended to every prompt it builds.
const dispatchSeat = (seat, st, note) => (seat === 'review' && st.tier === 4)
  ? parallel([
      () => agent(reviewPrompt(st) + note, { agentType: SEAT_AGENT.review, model: TOP, phase: 'Round' }),
      () => agent(reviewPrompt(st) + note, { agentType: SEAT_AGENT.review, model: SECOND, phase: 'Round' }),
    ]).then(([r1, r2]) => foldReviews(r1, r2))
  : agent((seat === 'review' ? reviewPrompt(st) : seatPrompt(seat, st)) + note, {
      agentType: SEAT_AGENT[seat],
      model: seat === 'review' ? TOP : undefined,
      phase: 'Round',
    })

const attempts = new Map() // story file -> misses this run: red close-story or empty worker report, together (R6/R29, per-run only - nothing on disk depends on it)
const lastError = new Map() // story file -> the most recent miss's own reason, carried into the two-miss stop (M2/X-M1)
const repaired = new Set() // round numbers already sent to queen-planner this run (R30, per-run only)

// The DRIVER semaphore (ADR-004/K3): claim once, right after the launch guards, before any
// other clerk call; release on every exit path including a stop, a BadLine or a Paused - the
// `finally` below is the one release point, so a held-by refusal never reaches it (claimed
// stays false) and every other exit does.
let claimed = false
try {
  const claimRes = await clerk(`claim ${spec} ${stamp}`)
  if (!claimRes.ok) return { stop: asStop(claimRes) }
  claimed = true
  for (;;) {
    const st = await clerk(`status ${spec} --json`)
    log(`${st.slug} · ${st.stage} · next: ${st.next}`)
    if (TERMINAL.includes(st.next)) return st

    // second_model missing or equal to top_model on a Tier 4 spec refuses at launch, before
    // any non-clerk agent() is dispatched (X-M4) - checked every poll since tier is unknown
    // before the first status.
    if (st.tier === 4 && (!SECOND || SECOND === TOP)) {
      fail(st, { verb: 'launch', error: 'second_model missing or equal to top_model on a Tier 4 spec' })
    }

    if (st.next === 'briefed') {
      // r2m15: the driver refuses instead of stamping - it never runs briefed --commit itself.
      fail(st, { verb: 'briefed', error: 'spec not briefed: run /vulyk-plan' })
    } else if (st.next === 'branch') {
      const res = await clerk(`${st.next} ${spec} --commit`)
      if (!res.ok) fail(st, asStop(res))
    } else if (st.next.startsWith('build:')) {
      phase('Build')
      const stories = st.wave_stories
      // status --json now carries "worker" and "repeat" per story (autonomous-cycle-15) -
      // route agentType from the object; the driver still never opens a story file itself.
      // A story on its second dispatch (one miss already counted) gets one extra sentence:
      // a previous attempt may have left an uncommitted diff behind.
      const reports = await parallel(stories.map((story) => () => {
        const retry = (attempts.get(story.file) || 0) >= 1
        const prompt = `Your story: ${story.file}. Read it fully, including the map slice it names, and implement it per your protocol.`
          + (retry ? ' Note: a previous attempt may have left uncommitted edits in your files; `git diff` them first.' : '')
        return agent(prompt, { agentType: story.worker, phase: 'Build' })
          .catch((e) => { log(`worker threw: ${e && e.message ? e.message : e}`); return null })
      }))
      for (let i = 0; i < stories.length; i++) {
        const file = stories[i].file
        const report = reports[i]
        // an empty/null/whitespace-only worker report is a miss on the same bound a red
        // close-story is (R29) - close-story never runs on one, and either failure trips
        // the same count; lastError carries the failing verb's own reason into the stop.
        if (typeof report === 'string' && report.trim() !== '') {
          // close-story derives `repeat: N` itself from the story's own ## Verification block
          // (cycle.sh's cmd_close_story) and takes no --repeat flag, so it is not passed here.
          const res = await clerk(`close-story ${file} --commit --stamp ${stamp}`)
          if (res.ok) continue
          if (res.exit !== 4) fail(st, asStop(res))
          lastError.set(file, res.error)
        } else {
          lastError.set(file, 'worker returned no report')
        }
        const n = (attempts.get(file) || 0) + 1
        attempts.set(file, n)
        if (n >= 2) fail(st, { verb: 'build', file, error: lastError.get(file) })
        // first miss for this file: continue - it stays open, the next status poll re-routes it
      }
    } else if (st.next === 'open-round') {
      phase('Round')
      const res = await clerk(`open-round ${spec} --commit --stamp ${stamp}`)
      // exit 6 at the bound: cycle.sh already recorded the escalation (R5) - this driver's job is only to stop
      if (!res.ok) fail(st, asStop(res))
    } else if (st.next.startsWith('dispatch:')) {
      phase('Round')
      const seats = st.next.slice(9).split(',')
      const delim = (seat, attempt) => `VULYK_${stamp}_${seat}_${attempt}`
      const recordSeat = (seat, report, attempt) => {
        const d = delim(seat, attempt)
        const body = report ?? '' // a null report (dead agent(), a throwing parallel thunk) is an empty body, never the string "null"
        return clerk(`record-seat ${spec} ${st.round} ${seat} --stamp ${stamp} <<'${d}'\n${body}\n${d}`)
      }
      const reports = await parallel(seats.map((seat) => () => dispatchSeat(seat, st, '')))
      let dispatchStop = null
      for (let i = 0; i < seats.length; i++) {
        const seat = seats[i]
        // a seat's report is always recorded, empty or not (R6); clerk() runs in plain loop
        // code, not inside a pipeline stage, so a BadLine reaches the one catch (R32).
        const res = await recordSeat(seat, reports[i], 1)
        if (res.ok) continue
        if (res.exit !== 4) { dispatchStop = dispatchStop || asStop(res); continue }
        const retry = await dispatchSeat(seat, st, `\nYour previous report was rejected: ${res.error}`)
        await recordSeat(seat, retry, 2) // re-asked once (R6) - continue whatever this second result is
      }
      if (dispatchStop) fail(st, dispatchStop)
    } else if (st.next === 'judge') {
      phase('Judge')
      const res = await clerk(`judge ${spec} --commit --stamp ${stamp}`)
      if (!res.ok) fail(st, asStop(res))
    } else if (st.next === 'repair') {
      phase('Repair')
      // one queen-planner dispatch per round number per run (R30) - a repeat visit means
      // the last dispatch landed no story, nothing changed, so re-asking would loop forever.
      if (repaired.has(st.round)) fail(st, { verb: 'repair', round: st.round, error: `repair landed nothing for round ${st.round}` })
      repaired.add(st.round)
      const reason = st.red.length > 0
        ? `left the asks numbered [${st.red.join(', ')}] unresolved - the seat reports are under ${st.round_dir}`
        : `has no ask numbered - the review seat's BLOCK (or an owner REJECTED) is why the round failed; see ${st.round_dir}/review.md`
      const ask = st.red.length > 0
        ? 'one wave, each addressing exactly one of those asks'
        : 'one wave, one story per critical and per major finding whose fix is local'
      await agent(
        `Round ${st.round} for ${st.slug} (review: ${st.review}) ${reason}. Cut fix stories under docs/specs/${st.slug}/ following templates/story.md's frontmatter and naming convention, ${ask}, then update plan.md's story index.`,
        { agentType: 'queen-planner', model: TOP, phase: 'Repair' },
      )
    } else {
      return st // an unrecognised `next` - report it rather than guess at an action
    }
  }
} catch (e) {
  if (e instanceof BadLine) return e.line
  if (e instanceof Paused) return { next: e.next }
  if (e instanceof Stop) return e.result
  throw e
} finally {
  // A release after pause is harmless (DRIVER already absent, exit 0) - not the mechanism,
  // just a no-op on that path; every other path is where this call matters (K3, Non-goals).
  if (claimed) await clerk(`release ${spec} ${stamp}`).catch(() => {})
}
