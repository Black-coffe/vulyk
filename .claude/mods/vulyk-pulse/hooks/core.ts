// The pulse's pure parts: weights, formats, frames, phase, dots, the row, the closing line and the task rules.
// No `$` here: register.tsx reads and listens, this decides.

export type Motion = 'on' | 'slow' | 'off'

/** One API response's usage as `turn.step` reports it (`TurnUsage`, d.ts). */
export type Usage = {
  input_tokens: number
  output_tokens: number
  cache_read_input_tokens: number
  cache_creation_input_tokens: number
  model?: string
}

/** A piece of the row; the kind says how register.tsx colours it (the glyph in theme `claude`, the rest dim or plain). */
export type Seg = { t: string; kind: 'glyph' | 'sep' | 'text' | 'live' | 'dim' | 'done' }

export type Agent = { type: string; live: boolean }
export type Task = { start: number; last: number; open: boolean; idle?: number }

export type View = {
  phase: string
  wave: number
  round: number
  live: number
  finished: number
  elapsedMs: number
  tokens: number
  now: number
  motion: Motion
}

/** Task close: the main loop idle and no agent live, both for this long. */
export const SETTLE_MS = 60_000
export const MAX_DOTS = 10
export const NARROW_BELOW = 60

// --- weights -------------------------------------------------------------------------------------------------

// Pinned to scripts/token-report.py: lines 18-19 (the formula and the read rates) and line 57 (READ_RATE).
// weighted = input + 1.25 x every cache write + r x read + output; r = 0.05 Opus 5.5, 0.025 Fable/Mythos 5.1, else 0.1.
// ModelUsage does not split 5m from 1h writes, so every write counts 1.25 here.
const READ_RATE: readonly (readonly [string, number])[] = [
  ['opus-5-5', 0.05],
  ['fable-5-1', 0.025],
  ['mythos-5-1', 0.025],
]

export const weigh = (u: Usage): number => {
  const model = typeof u.model === 'string' ? u.model : ''
  const rate = READ_RATE.find(([key]) => model.includes(key))?.[1] ?? 0.1
  return u.input_tokens + 1.25 * u.cache_creation_input_tokens + rate * u.cache_read_input_tokens + u.output_tokens
}

// --- formats -------------------------------------------------------------------------------------------------

const scale = (n: number, div: number, unit: string): string => {
  const v = n / div
  return (v < 100 ? v.toFixed(1) : String(Math.round(v))) + unit
}

/** `812`, `48.2k`, `1.8M`, padded on the left to 5 cells. */
export const fmtTokens = (n: number): string => {
  const x = Math.max(0, n)
  let s: string
  if (x < 1000) s = String(Math.round(x))
  else if (x < 1e6) {
    s = scale(x, 1e3, 'k')
    if (s.startsWith('1000')) s = scale(x, 1e6, 'M')
  } else s = scale(x, 1e6, 'M')
  return s.padStart(5)
}

/** `0m 07s`, `12m 04s`, `1h 12m 04s`; narrow: `12m`, `1h12m`. */
export const fmtElapsed = (ms: number, narrow = false): string => {
  const total = Math.max(0, Math.floor(ms / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  const two = (n: number) => String(n).padStart(2, '0')
  if (narrow) return h > 0 ? `${h}h${two(m)}m` : `${m}m`
  return h > 0 ? `${h}h ${two(m)}m ${two(s)}s` : `${m}m ${two(s)}s`
}

// --- motion --------------------------------------------------------------------------------------------------

export const motionOf = (v: unknown): Motion => (v === 'slow' || v === 'off' ? v : 'on')

/** The redraw period: 125 ms, 500 ms, or a calm second so the numbers stay live. */
export const periodOf = (motion: Motion): number => (motion === 'on' ? 125 : motion === 'slow' ? 500 : 1000)

const GLYPHS = ['·', '✢', '✳', '✶', '✻', '✽']
const PING_PONG = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]

/** The spinner glyph at `now`: the engine's own six, ping-pong; a static ✻ under `off`. */
export const frameAt = (now: number, motion: Motion): string => {
  if (motion === 'off') return '✻'
  const step = motion === 'slow' ? 500 : 125
  return GLYPHS[PING_PONG[Math.floor(now / step) % PING_PONG.length]!]!
}

// --- phase ---------------------------------------------------------------------------------------------------

const PHASES: readonly (readonly [string, (type: string) => boolean])[] = [
  ['build', t => t === 'worker-code' || t === 'worker-test'],
  ['council', t => t === 'lead-review' || t.startsWith('council')],
  ['design', t => t === 'lead-architect'],
  ['plan', t => t === 'queen-planner' || t === 'drone-scout' || t === 'drone-coverage'],
  ['docs', t => t === 'drone-docs' || t === 'librarian'],
  ['clerk', t => t === 'cycle-clerk'],
]

/** The phase word of the live agent types: the first of build, council, design, plan, docs, clerk that any matches. */
export const phaseOf = (liveTypes: readonly string[]): string => {
  if (liveTypes.length === 0) return 'thinking'
  return PHASES.find(([, is]) => liveTypes.some(is))?.[0] ?? 'agents'
}

/** Live types, live count and finished count of the task's agents. */
export const summarize = (agents: Readonly<Record<string, Agent>>): { types: string[]; live: number; finished: number } => {
  const all = Object.values(agents)
  const types = all.filter(a => a.live).map(a => a.type)
  return { types, live: types.length, finished: all.length - types.length }
}

// --- dots ----------------------------------------------------------------------------------------------------

/** One dot per agent, live first (`●`), then finished (`·`); at most 10 cells, finished dropped first; past 10 live,
 * `●×N`. The live dots breathe: every 500 ms one is `dim`, walking left to right with one step of rest, so a lone
 * dot blinks. `off` dims none. */
export const dots = (live: number, finished: number, now: number, motion: Motion): Seg[] => {
  if (live > MAX_DOTS) return [{ t: `●×${live}`, kind: 'live' }]
  const out: Seg[] = []
  const walk = motion === 'off' || live === 0 ? -1 : Math.floor(now / 500) % (live + 1)
  for (let i = 0; i < live; i += 1) out.push({ t: '●', kind: i === walk ? 'dim' : 'live' })
  for (let i = 0; i < Math.min(finished, MAX_DOTS - live); i += 1) out.push({ t: '·', kind: 'done' })
  return out
}

// --- the row -------------------------------------------------------------------------------------------------

const SEP: Seg = { t: ' · ', kind: 'sep' }
const SPACE: Seg = { t: ' ', kind: 'text' }

const join = (groups: Seg[][]): Seg[] => groups.filter(g => g.length > 0).flatMap((g, i) => (i === 0 ? g : [SEP, ...g]))

const text = (t: string): Seg[] => [{ t, kind: 'text' }]

/** The row as segments: full form `✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok`, or below 60 columns
 * `✻ build ●●●· · 12m · 1.8M`. Wave shows in `build`, round in `council`, only when known. The token figure is
 * trimmed of its padding so the row reads as the mockup does. */
export const row = (width: number, v: View): Seg[] => {
  const glyph: Seg = { t: frameAt(v.now, v.motion), kind: 'glyph' }
  const cells = dots(v.live, v.finished, v.now, v.motion)
  const tok = fmtTokens(v.tokens).trimStart()
  if (width < NARROW_BELOW) {
    const head: Seg[] = [glyph, SPACE, ...text(v.phase), ...(cells.length > 0 ? [SPACE, ...cells] : [])]
    return [...head, SEP, ...text(fmtElapsed(v.elapsedMs, true)), SEP, ...text(tok)]
  }
  const place = v.phase === 'build' && v.wave > 0 ? `wave ${v.wave}` : v.phase === 'council' && v.round > 0 ? `round ${v.round}` : ''
  return [
    glyph,
    SPACE,
    ...join([
      text('VULYK'),
      text(v.phase),
      place === '' ? [] : text(place),
      cells,
      text(fmtElapsed(v.elapsedMs)),
      text(`≈${tok} tok`),
    ]),
  ]
}

export const plain = (segs: readonly Seg[]): string => segs.map(s => s.t).join('')

/** The `Baked for ...` line: `<word> for <task elapsed> · N agents · ≈X tok`; the agents part is dropped at 0. */
export const closing = (word: string, v: View): string => {
  const n = v.live + v.finished
  const agents = n === 0 ? '' : ` · ${n} agent${n === 1 ? '' : 's'}`
  return `${word} for ${fmtElapsed(v.elapsedMs)}${agents} · ≈${fmtTokens(v.tokens).trimStart()} tok`
}

// --- the task ------------------------------------------------------------------------------------------------

/** Whether activity at `now` joins the task: something is running, or the last activity was within the settle window.
 * The owner's message (`owner`) joins only while something is running: sent with all quiet, it starts a new task. */
export const joinable = (t: Task | null, now: number, busy: boolean, owner = false): boolean =>
  t !== null && (busy || (!owner && now - t.last <= SETTLE_MS))

/** The task after activity at `now`: the open one extended, or a new one when it cannot be joined. */
export const touched = (t: Task | null, now: number, busy: boolean, owner = false): Task =>
  t !== null && joinable(t, now, busy, owner)
    ? { start: t.start, last: now, open: true, idle: (t.idle ?? 0) + (busy ? 0 : now - t.last) }
    : { start: now, last: now, open: true, idle: 0 }

/** Whether the open task has been quiet (main idle, no agent live) for the whole settle window. */
export const settled = (t: Task | null, now: number, busy: boolean): boolean =>
  t !== null && t.open && !busy && now - t.last >= SETTLE_MS

/** How long the task has run: to now while anything runs, else to its last activity, less the quiet gaps it joined across. */
export const elapsedOf = (t: Task, now: number, busy: boolean): number => Math.max(0, (busy ? now : t.last) - t.start - (t.idle ?? 0))

// --- hive, spec, status --------------------------------------------------------------------------------------

/** A VULYK hive has `CLAUDE.vulyk.md` or `scripts/cycle.sh` at its root. */
export const isHive = (root: { vulyk: boolean; cycle: boolean }): boolean => root.vulyk || root.cycle

/** The spec path of a Workflow call's `args`, or null. */
export const specOf = (args: unknown): string | null => {
  const spec = (args as { spec?: unknown } | null | undefined)?.spec
  return typeof spec === 'string' && spec.trim() !== '' ? spec.trim() : null
}

/** `wave` and `round` of `cycle.sh status --json`; 0 when absent or the output is not that JSON. */
export const parseStatus = (stdout: string): { wave: number; round: number } => {
  try {
    const j = JSON.parse(stdout) as { wave?: unknown; round?: unknown }
    const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0)
    return { wave: num(j.wave), round: num(j.round) }
  } catch {
    return { wave: 0, round: 0 }
  }
}
