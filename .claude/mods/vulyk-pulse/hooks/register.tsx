import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import {
  closing,
  elapsedOf,
  isHive,
  joinable,
  motionOf,
  parseStatus,
  periodOf,
  phaseOf,
  row,
  settled,
  specOf,
  summarize,
  touched,
  weigh,
} from './core'
import type { Agent, Motion, Seg, Task, View } from './core'

const taskA = atom({ plugin: 'vulyk-pulse', key: 'task' } as const, null)
const tallyA = atom({ plugin: 'vulyk-pulse', key: 'tally' } as const, 0)
const agentsA = atom({ plugin: 'vulyk-pulse', key: 'agents' } as const, {} as Record<string, Agent>)
const specA = atom({ plugin: 'vulyk-pulse', key: 'spec' } as const, '')
const placeA = atom({ plugin: 'vulyk-pulse', key: 'place' } as const, { wave: 0, round: 0 })

const NO_PLACE = { wave: 0, round: 0 }
/** Frozen closing lines kept at most; past it the oldest go. */
const LINES_CAP = 200

// The `Text` constructor of the terminal's element table; the three sites share it, so it is typed loosely here.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const drawSegs = (Box: any, Text: any, segs: readonly Seg[]) => (
  <Box>
    {segs.map(s =>
      s.kind === 'glyph' ? (
        <Text color="claude">{s.t}</Text>
      ) : s.kind === 'sep' || s.kind === 'dim' || s.kind === 'done' ? (
        <Text dimColor>{s.t}</Text>
      ) : (
        <Text>{s.t}</Text>
      ),
    )}
  </Box>
)

let motion: Motion = 'on'
// Session-held (a hot reload clears them): the motion setting, the main loop's busy flag, the redraw timer, the hive
// check and the closing lines. The task, tally, agents, spec and place are `$.state`.
let mainBusy = false
let timer: { cancel: () => void } | null = null
let hive: Promise<boolean> | null = null
// Each closing line's figures ("<word>" left out), frozen at its first drawing under the line's `requestId`: a drawing
// may not write `$.state`, and the line's `durationMs` is not the turn's (a background wait counts from the launch).
const lines = new Map<string, string>()

const hiveOf = ($: EngineInterface): Promise<boolean> => {
  hive ??= (async () => {
    try {
      const root = await $.session.root()
      const has = async (path: string) => (await $.fs.read(`${root}/${path}`).catch(() => undefined)) !== undefined
      return isHive({ vulyk: await has('CLAUDE.vulyk.md'), cycle: await has('scripts/cycle.sh') })
    } catch {
      return false
    }
  })()
  return hive
}

const busyOf = async ($: EngineInterface): Promise<boolean> =>
  mainBusy || summarize(await read($, agentsA)).live > 0

const viewOf = async ($: EngineInterface): Promise<View | null> => {
  const task = await read($, taskA)
  if (task === null) return null
  const now = await $.clock.now()
  const sum = summarize(await read($, agentsA))
  const place = await read($, placeA)
  return {
    phase: phaseOf(sum.types),
    wave: place.wave,
    round: place.round,
    live: sum.live,
    finished: sum.finished,
    elapsedMs: elapsedOf(task, now, mainBusy || sum.live > 0),
    tokens: await read($, tallyA),
    now,
    motion,
  }
}

// The redraw timer runs only while a task is open; the tick also closes a task that has been quiet for the settle window.
const arm = ($: EngineInterface) => {
  if (timer !== null) return
  timer = $.clock.every(periodOf(motion), () => {
    void (async () => {
      try {
        const task = await read($, taskA)
        if (settled(task, await $.clock.now(), await busyOf($))) {
          await update($, taskA, t => (t === null ? t : { ...t, open: false }))
          timer?.cancel()
          timer = null
        }
        $.ui.invalidate('ui.render')
      } catch {
        // A gauge that fails stays silent.
      }
    })()
  })
}

// Activity at now: join the open task, or start a new one with a clean tally. The owner's message (`owner`) joins
// only while something runs.
const begin = async ($: EngineInterface, owner = false) => {
  const now = await $.clock.now()
  const task = await read($, taskA)
  const busy = await busyOf($)
  if (!joinable(task, now, busy, owner)) {
    await update($, tallyA, () => 0)
    await update($, agentsA, () => ({}))
    await update($, specA, () => '')
    await update($, placeA, () => NO_PLACE)
  }
  await update($, taskA, () => touched(task, now, busy, owner))
  arm($)
}

// Wave and round from `cycle.sh status --json` while a spec is known; a failure leaves them blank.
const refresh = async ($: EngineInterface) => {
  const spec = await read($, specA)
  if (spec === '') return
  try {
    const out = await $.process.run(['bash', 'scripts/cycle.sh', 'status', spec, '--json'])
    await update($, placeA, () => (out.exitCode === 0 ? parseStatus(out.stdout) : NO_PLACE))
  } catch {
    await update($, placeA, () => NO_PLACE)
  }
}

export const register: Register = (on, options) => {
  motion = motionOf(options.motion)

  on('session.start', async ($, e, next) => {
    try {
      if (await hiveOf($)) {
        const task: Task | null = await read($, taskA)
        if (task !== null && task.open) arm($)
      }
    } catch {
      // A gauge that fails stays silent.
    }
    return next(e)
  })

  // The owner's message (typed at the composer or sent through the bridge) opens a new task unless something still
  // runs; anything else (a task notification, a schedule, a peer, an `isMeta` prompt) joins like any activity.
  on('prompt.submit', async ($, e, next) => {
    try {
      const own = e.origin.kind === 'composer' || e.origin.kind === 'bridge'
      if (own && e.isMeta !== true && (await hiveOf($))) await begin($, true)
    } catch {
      // A gauge that fails stays silent.
    }
    return next(e)
  })

  // A main `turn.start` (the owner's turn, or a task notification) joins the task, or opens one past the settle window.
  on('turn.start', async ($, e, next) => {
    try {
      if (e.agentId === undefined && (await hiveOf($))) {
        await begin($)
        mainBusy = true
      }
    } catch {
      // A gauge that fails stays silent.
    }
    return next(e)
  })

  on('agent.spawn', async ($, e, next) => {
    const spawned = await next(e)
    try {
      if (await hiveOf($)) {
        await begin($)
        if (typeof spawned.agentId === 'string') {
          const id = spawned.agentId
          await update($, agentsA, a => ({ ...a, [id]: { type: e.subagentType, live: true } }))
        }
        await refresh($)
      }
    } catch {
      // A gauge that fails stays silent.
    }
    return spawned
  })

  on('tool.call', async ($, e, next) => {
    try {
      if (e.tool === 'Workflow' && (await hiveOf($))) {
        const spec = specOf(e.args)
        if (spec !== null) {
          await update($, specA, () => spec)
          await refresh($)
        }
      }
    } catch {
      // A gauge that fails stays silent.
    }
    return next(e)
  })

  // Every loop's response, the Queen's and every agent's: the weighted tokens of the task.
  on('turn.step', async function* ($, e, next) {
    const r = yield* next(e)
    try {
      if (r.usage !== null && (await hiveOf($))) {
        const weight = weigh(r.usage)
        await update($, tallyA, n => n + weight)
      }
    } catch {
      // A gauge that fails stays silent.
    }
    return r
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    try {
      if (await hiveOf($)) {
        const id = e.agentId
        if (id === undefined) mainBusy = false
        else await update($, agentsA, a => (a[id] === undefined ? a : { ...a, [id]: { ...a[id], live: false } }))
        const now = await $.clock.now()
        await update($, taskA, t => (t === null ? t : { ...t, last: now }))
      }
    } catch {
      // A gauge that fails stays silent.
    }
    return done
  })

  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    if (e.props.message !== null || e.surface !== 'terminal' || !(await hiveOf($))) return next(e)
    const view = await viewOf($)
    if (view === null) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    return drawSegs(Box, Text, row(e.viewport?.columns ?? 80, view))
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.isWorking || e.props.hasSurvey || e.surface !== 'terminal' || !(await hiveOf($))) return next(e)
    const view = await viewOf($)
    if (view === null || view.live === 0) return next(e)
    // `next(e)` resolves to `{ type: 'engine', ref }` when no other hook drew the band: core's own drawing.
    const drawn = await next(e)
    if (drawn.type !== 'engine') return drawn
    const { Box, Text } = $.ui.resolve(e)
    return drawSegs(Box, Text, row(e.props.bodyColumns, view))
  })

  // Each closing line draws the task's figures as they stood at its first drawing, then keeps them, so a later turn
  // or task never repaints it. With no task view the line stays the engine's own and nothing is kept.
  on('ui.render', { component: 'TurnDuration' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !(await hiveOf($))) return next(e)
    let tail = lines.get(e.requestId)
    if (tail === undefined) {
      const view = await viewOf($)
      if (view === null) return next(e)
      tail = closing('', view)
      lines.set(e.requestId, tail)
      if (lines.size > LINES_CAP) lines.delete(lines.keys().next().value as string)
    }
    const { Text } = $.ui.resolve(e)
    return <Text dimColor>{`${e.props.word}${tail}`}</Text>
  })
}
