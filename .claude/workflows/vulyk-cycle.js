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

const spec = args.spec
const TOP = args.top_model
const SECOND = args.second_model
const stamp = args.stamp // opaque per-run string - only used to build the record-seat delimiter (R11); never compared, parsed or shown to a seat
log(`vulyk-cycle: ${spec} · stamp ${stamp}`)

class BadLine extends Error {
  constructor(line) { super('cycle-clerk returned a non-JSON last line'); this.line = line }
}

// A verb's own ok:false ends the run; Stop carries the full return value so the outer catch
// needs nothing from the loop's scope.
class Stop extends Error {
  constructor(result) { super('driver stop'); this.result = result }
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
  try { return JSON.parse(line) } catch { throw new BadLine(line) }
})

// A blind seat gets slug/round/court only (R9) - round_dir would let it name the very
// taint pattern C5 forbids it to repeat. lead-review is never blind, so it gets the full
// review packet instead: round_dir, the spec (its stories and plan), the branch to diff, ADR-001.
const seatPrompt = (seat, st) =>
  `Council round ${st.round} for ${st.slug}, seat ${seat}. Work only inside COURT: ${st.court}. Read COURT/brief.md's ## Asks and COURT/CLAUDE.md's ## Profile, then judge per your seat contract.`
const reviewPrompt = (st) =>
  `Adversarial review for ${st.slug}, round ${st.round}. Round dir: ${st.round_dir}. Spec: ${st.spec} - review its stories and plan. Diff the branch ${st.branch} at ${st.head} against its base. See docs/adr/001-cycle-state-contract.md. You do not enter the court.`

// Only prose this driver ever reads: a review report's first line (C5's PASS|BLOCK token).
const isBlock = (report) => {
  const first = String(report).trim().split('\n')[0]
  return /^BLOCK\b/.test(first) || /^VERDICT:\s*BLOCK\b/.test(first)
}

// Tier 4 folds a second reviewer on the paired model into the one `review` seat (R12); `note`
// carries the re-ask text on a record-seat MALFORMED retry, appended to every prompt it builds.
const dispatchSeat = (seat, st, note) => (seat === 'review' && st.tier === 4)
  ? parallel([
      () => agent(reviewPrompt(st) + note, { agentType: SEAT_AGENT.review, model: TOP, phase: 'Round' }),
      () => agent(reviewPrompt(st) + note, { agentType: SEAT_AGENT.review, model: SECOND, phase: 'Round' }),
    ]).then(([r1, r2]) => `VERDICT: ${isBlock(r1) || isBlock(r2) ? 'BLOCK' : 'PASS'}\n${r1}\n${r2}`)
  : agent((seat === 'review' ? reviewPrompt(st) : seatPrompt(seat, st)) + note, {
      agentType: SEAT_AGENT[seat],
      model: seat === 'review' ? TOP : undefined,
      phase: 'Round',
    })

const attempts = new Map() // story file -> close-story failures this run (R6, a per-run bound only - nothing on disk depends on it)

try {
  for (;;) {
    const st = await clerk(`status ${spec} --json`)
    log(`${st.slug} · ${st.stage} · next: ${st.next}`)
    if (TERMINAL.includes(st.next)) return st

    if (st.next === 'briefed' || st.next === 'branch') {
      const res = await clerk(`${st.next} ${spec} --commit`)
      if (!res.ok) fail(st, asStop(res))
    } else if (st.next.startsWith('build:')) {
      phase('Build')
      const stories = st.wave_stories
      // status --json now carries "worker" and "repeat" per story (autonomous-cycle-15) -
      // route agentType from the object; the driver still never opens a story file itself.
      const reports = await parallel(stories.map((story) => () => agent(
        `Your story: ${story.file}. Read it fully, including the map slice it names, and implement it per your protocol.`,
        { agentType: story.worker, phase: 'Build' },
      )))
      for (let i = 0; i < stories.length; i++) {
        if (!reports[i]) continue
        const file = stories[i].file
        // close-story derives `repeat: N` itself from the story's own ## Verification block
        // (cycle.sh's cmd_close_story) and takes no --repeat flag, so it is not passed here.
        const res = await clerk(`close-story ${file} --commit`)
        if (res.ok) continue
        if (res.exit !== 4) fail(st, asStop(res))
        const n = (attempts.get(file) || 0) + 1
        attempts.set(file, n)
        if (n >= 2) fail(st, { verb: 'close-story', file, error: res.error })
        // first failed verification for this file: continue - it stays open, the next status poll re-routes it
      }
    } else if (st.next === 'open-round') {
      phase('Round')
      const res = await clerk(`open-round ${spec} --commit`)
      // exit 6 at the bound: cycle.sh already recorded the escalation (R5) - this driver's job is only to stop
      if (!res.ok) fail(st, asStop(res))
    } else if (st.next.startsWith('dispatch:')) {
      phase('Round')
      const seats = st.next.slice(9).split(',')
      const delim = (seat, attempt) => `VULYK_${stamp}_${seat}_${attempt}`
      const recordSeat = (seat, report, attempt) => {
        const d = delim(seat, attempt)
        return clerk(`record-seat ${spec} ${st.round} ${seat} <<'${d}'\n${report}\n${d}`)
      }
      let dispatchStop = null
      await pipeline(
        seats,
        (seat) => dispatchSeat(seat, st, ''),
        async (report, seat) => {
          // a seat's report is always recorded, empty or not (R6)
          const res = await recordSeat(seat, report, 1)
          if (res.ok) return
          if (res.exit !== 4) { dispatchStop = dispatchStop || asStop(res); return }
          const retry = await dispatchSeat(seat, st, `\nYour previous report was rejected: ${res.error}`)
          await recordSeat(seat, retry, 2) // re-asked once (R6) - continue whatever this second result is
        },
      )
      if (dispatchStop) fail(st, dispatchStop)
    } else if (st.next === 'judge') {
      phase('Judge')
      const res = await clerk(`judge ${spec} --commit`)
      if (!res.ok) fail(st, asStop(res))
    } else if (st.next === 'repair') {
      phase('Repair')
      await agent(
        `Round ${st.round} for ${st.slug} left the asks numbered [${st.red.join(', ')}] unresolved - the seat reports are under ${st.round_dir}. Cut fix stories under docs/specs/${st.slug}/ following templates/story.md's frontmatter and naming convention, one wave, each addressing exactly one of those asks, then update plan.md's story index.`,
        { agentType: 'queen-planner', model: TOP, phase: 'Repair' },
      )
    } else {
      return st // an unrecognised `next` - report it rather than guess at an action
    }
  }
} catch (e) {
  if (e instanceof BadLine) return e.line
  if (e instanceof Stop) return e.result
  throw e
}
