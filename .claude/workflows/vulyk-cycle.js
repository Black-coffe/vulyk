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

// This driver holds no verdict, ceiling or staleness logic and never parses prose - it loops
// on scripts/cycle.sh's `status --json` and performs the one action `next` names (ADR-001 D2).
// Everything it knows about the state comes from that JSON object; a decision that needs more
// than `next`, `wave_stories`, `missing`, `court`, `round`, `round_dir` or `red` means the
// status contract is missing a key, not something to work around here.

const TERMINAL = ['green', 'escalated', 'paused', 'shipped']
const SEAT_AGENT = { haiku: 'council-haiku', sonnet: 'council-sonnet', opus: 'council-opus', review: 'lead-review' }

const spec = args.spec
const TOP = args.top_model
const stamp = args.stamp // logged only - the runtime has no clock, so nothing here may use it for logic
log(`vulyk-cycle: ${spec} · stamp ${stamp}`)

class BadLine extends Error {
  constructor(line) { super('cycle-clerk returned a non-JSON last line'); this.line = line }
}

// The Workflow runtime has no shell of its own - cycle-clerk is the only way to reach one.
// A non-JSON last line from any verb ends the whole run; the Queen reads the raw line at wake.
const clerk = (cmd) => agent(
  `Run exactly: bash scripts/cycle.sh ${cmd}\nReturn the last stdout line verbatim.`,
  { agentType: 'cycle-clerk', effort: 'low' },
).then((out) => {
  const line = String(out).trim().split('\n').pop()
  try { return JSON.parse(line) } catch { throw new BadLine(line) }
})

const seatPrompt = (seat, st) => seat === 'review'
  ? `Adversarial review for ${st.slug}, council round ${st.round}. Seat reports so far are under ${st.round_dir}. Review the branch's current tree as usual - you do not enter the court.`
  : `Council round ${st.round} for ${st.slug}, seat ${seat}. Work only inside COURT: ${st.court}. Round dir: ${st.round_dir}. Read COURT/brief.md's ## Asks and COURT/CLAUDE.md's ## Profile, then judge per your seat contract.`

try {
  for (;;) {
    const st = await clerk(`status ${spec} --json`)
    log(`${st.slug} · ${st.stage} · next: ${st.next}`)
    if (TERMINAL.includes(st.next)) return st

    if (st.next === 'briefed' || st.next === 'branch') {
      await clerk(`${st.next} ${spec} --commit`)
    } else if (st.next.startsWith('build:')) {
      phase('Build')
      const files = st.wave_stories
      // status --json carries no per-story `worker:` field, so the driver cannot route
      // between worker-code and worker-test itself (Non-goals: never compute from story
      // files) - every current story in this spec uses worker-code; reported in INTERFACES.
      const reports = await parallel(files.map((f) => () => agent(
        `Your story: ${f}. Read it fully, including the map slice it names, and implement it per your protocol.`,
        { agentType: 'worker-code', phase: 'Build' },
      )))
      for (let i = 0; i < files.length; i++) {
        if (reports[i]) await clerk(`close-story ${files[i]} --commit`)
      }
    } else if (st.next === 'open-round') {
      phase('Round')
      await clerk(`open-round ${spec} --commit`)
    } else if (st.next.startsWith('dispatch:')) {
      phase('Round')
      const seats = st.next.slice(9).split(',')
      await pipeline(
        seats,
        (seat) => agent(seatPrompt(seat, st), {
          agentType: SEAT_AGENT[seat],
          model: seat === 'review' ? TOP : undefined,
          phase: 'Round',
        }),
        (report, seat) => report && clerk(`record-seat ${spec} ${st.round} ${seat} <<'EOF'\n${report}\nEOF`),
      )
    } else if (st.next === 'judge') {
      phase('Judge')
      await clerk(`judge ${spec} --commit`)
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
  throw e
}
