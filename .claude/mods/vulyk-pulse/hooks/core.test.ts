import { describe, expect, mock, test } from 'claude-code/testing'

import {
  closing,
  dots,
  elapsedOf,
  fmtElapsed,
  fmtTokens,
  frameAt,
  isHive,
  joinable,
  parseStatus,
  periodOf,
  phaseOf,
  plain,
  row,
  settled,
  SETTLE_MS,
  specOf,
  summarize,
  touched,
  weigh,
} from './core'
import type { Motion, View } from './core'

// weights-pin: [{"model":"claude-opus-5-5","in":1000,"cw":2000,"cr":40000,"out":500,"want":6000},{"model":"claude-sonnet-5-5","in":2000,"cw":4000,"cr":100000,"out":800,"want":17800},{"model":"claude-fable-5-1","in":500,"cw":1000,"cr":80000,"out":300,"want":4050}]
// tests/mods.test.sh reads the line above and computes each `want` through scripts/token-report.py's own functions.
const PIN = [
  { model: 'claude-opus-5-5', in: 1000, cw: 2000, cr: 40000, out: 500, want: 6000 },
  { model: 'claude-sonnet-5-5', in: 2000, cw: 4000, cr: 100000, out: 800, want: 17800 },
  { model: 'claude-fable-5-1', in: 500, cw: 1000, cr: 80000, out: 300, want: 4050 },
]

const view = (over: Partial<View> = {}): View => ({
  phase: 'build',
  wave: 2,
  round: 0,
  live: 3,
  finished: 1,
  elapsedMs: 724_000,
  tokens: 1_800_000,
  now: 500,
  motion: 'on',
  ...over,
})

describe('weights', () => {
  test('weigh() gives the figure token-report.py gives for an Opus, a Sonnet and a Fable row', () => {
    for (const p of PIN) {
      const got = weigh({
        model: p.model,
        input_tokens: p.in,
        cache_creation_input_tokens: p.cw,
        cache_read_input_tokens: p.cr,
        output_tokens: p.out,
      })
      expect(Math.abs(got - p.want) < 1e-6).toBe(true)
    }
  })
})

describe('formats', () => {
  test('tokens', () => {
    expect(fmtTokens(812)).toBe('  812')
    expect(fmtTokens(48_200)).toBe('48.2k')
    expect(fmtTokens(1_800_000)).toBe(' 1.8M')
    expect(fmtTokens(482_000)).toBe(' 482k')
    expect(fmtTokens(999_990)).toBe(' 1.0M')
  })
  test('elapsed', () => {
    expect(fmtElapsed(7_000)).toBe('0m 07s')
    expect(fmtElapsed(724_000)).toBe('12m 04s')
    expect(fmtElapsed(4_324_000)).toBe('1h 12m 04s')
    expect(fmtElapsed(724_000, true)).toBe('12m')
    expect(fmtElapsed(4_324_000, true)).toBe('1h12m')
  })
})

describe('frameAt', () => {
  const sequence = ['·', '✢', '✳', '✶', '✻', '✽', '✻', '✶', '✳', '✢']
  test('ping-pong at 125 ms', () => {
    expect(sequence.map((_, i) => frameAt(i * 125, 'on'))).toEqual(sequence)
    expect(frameAt(10 * 125, 'on')).toBe('·')
  })
  test('ping-pong at 500 ms under slow', () => {
    expect(sequence.map((_, i) => frameAt(i * 500, 'slow'))).toEqual(sequence)
    expect(frameAt(125, 'slow')).toBe('·')
  })
  test('a static glyph under off', () => {
    for (const now of [0, 125, 500, 9999]) expect(frameAt(now, 'off')).toBe('✻')
  })
  test('redraw periods', () => {
    expect((['on', 'slow', 'off'] as Motion[]).map(periodOf)).toEqual([125, 500, 1000])
  })
})

describe('phase', () => {
  test('priority and fallbacks', () => {
    expect(phaseOf(['cycle-clerk', 'worker-code', 'lead-review'])).toBe('build')
    expect(phaseOf(['lead-review', 'lead-architect'])).toBe('council')
    expect(phaseOf(['council-opus'])).toBe('council')
    expect(phaseOf(['lead-architect', 'drone-scout'])).toBe('design')
    expect(phaseOf(['drone-scout', 'librarian'])).toBe('plan')
    expect(phaseOf(['drone-docs', 'cycle-clerk'])).toBe('docs')
    expect(phaseOf(['cycle-clerk'])).toBe('clerk')
    expect(phaseOf(['workflow-subagent'])).toBe('agents')
    expect(phaseOf([])).toBe('thinking')
  })
  test('summarize counts live and finished', () => {
    const s = summarize({ a: { type: 'worker-code', live: true }, b: { type: 'cycle-clerk', live: false } })
    expect(s).toEqual({ types: ['worker-code'], live: 1, finished: 1 })
  })
})

describe('dots', () => {
  const kinds = (now: number, motion: Motion) => dots(3, 0, now, motion).map(s => s.kind)
  test('one live dot is dim per 500 ms step, walking left to right', () => {
    expect(kinds(0, 'on')).toEqual(['dim', 'live', 'live'])
    expect(kinds(500, 'on')).toEqual(['live', 'dim', 'live'])
    expect(kinds(1000, 'on')).toEqual(['live', 'live', 'dim'])
    expect(kinds(1500, 'on')).toEqual(['live', 'live', 'live'])
  })
  test('none dim under off', () => {
    for (const now of [0, 500, 1000]) expect(kinds(now, 'off')).toEqual(['live', 'live', 'live'])
  })
  test('more than 10: finished dropped first, then a count', () => {
    expect(plain(dots(4, 9, 0, 'off'))).toBe('●●●●······')
    expect(plain(dots(10, 5, 0, 'off'))).toBe('●●●●●●●●●●')
    expect(plain(dots(12, 3, 0, 'off'))).toBe('●×12')
  })
})

describe('row', () => {
  test('the mockup row', () => {
    expect(plain(row(100, view()))).toBe('✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok')
  })
  test('council shows the round', () => {
    expect(plain(row(100, view({ phase: 'council', wave: 2, round: 2 })))).toBe(
      '✻ VULYK · council · round 2 · ●●●· · 12m 04s · ≈1.8M tok',
    )
  })
  test('the narrow form at width 50', () => {
    expect(plain(row(50, view()))).toBe('✻ build ●●●· · 12m · 1.8M')
  })
  test('no spec gives no wave word', () => {
    expect(plain(row(100, view({ wave: 0 })))).toBe('✻ VULYK · build · ●●●· · 12m 04s · ≈1.8M tok')
  })
  test('more than 10 dots', () => {
    expect(plain(row(100, view({ live: 12, finished: 3 })))).toBe('✻ VULYK · build · wave 2 · ●×12 · 12m 04s · ≈1.8M tok')
  })
  test('thinking with no agents', () => {
    const v = view({ phase: 'thinking', wave: 0, live: 0, finished: 0, elapsedMs: 7_000, tokens: 812 })
    expect(plain(row(100, v))).toBe('✻ VULYK · thinking · 0m 07s · ≈812 tok')
  })
  test('fixed width: two rows that differ only in a digit have equal length', () => {
    const a = plain(row(100, view({ elapsedMs: 724_000 })))
    const b = plain(row(100, view({ elapsedMs: 725_000 })))
    expect(a === b).toBe(false)
    expect(a.length).toBe(b.length)
  })
  test('the closing line with and without agents', () => {
    expect(closing('Baked', view())).toBe('Baked for 12m 04s · 4 agents · ≈1.8M tok')
    expect(closing('Baked', view({ live: 0, finished: 1 }))).toBe('Baked for 12m 04s · 1 agent · ≈1.8M tok')
    expect(closing('Baked', view({ live: 0, finished: 0, elapsedMs: 7_000, tokens: 812 }))).toBe('Baked for 0m 07s · ≈812 tok')
  })
})

describe('task', () => {
  const task = { start: 1_000, last: 100_000, open: true }
  test('a spawn 30 s after the last agent ends joins the task', () => {
    expect(joinable(task, 130_000, false)).toBe(true)
    expect(touched(task, 130_000, false)).toEqual({ start: 1_000, last: 130_000, open: true, idle: 30_000 })
  })
  test('a spawn at 61 s opens a new one', () => {
    expect(joinable(task, 100_000 + SETTLE_MS + 1_000, false)).toBe(false)
    expect(touched(task, 161_000, false)).toEqual({ start: 161_000, last: 161_000, open: true, idle: 0 })
  })
  test('a main turn while agents are live joins', () => {
    expect(touched(task, 900_000, true)).toEqual({ start: 1_000, last: 900_000, open: true, idle: 0 })
  })
  test("the owner's message 30 s after the last agent ends opens a new task, while anything runs joins", () => {
    const old = { start: 0, last: 600_000, open: true }
    expect(joinable(old, 630_000, false, true)).toBe(false)
    expect(touched(old, 630_000, false, true)).toEqual({ start: 630_000, last: 630_000, open: true, idle: 0 })
    expect(elapsedOf(touched(old, 630_000, false, true), 635_000, false)).toBe(0)
    expect(touched(old, 630_000, true, true)).toEqual({ start: 0, last: 630_000, open: true, idle: 0 })
  })
  test('a main turn joining after a 40 s quiet gap does not count the gap', () => {
    const ended = { start: 0, last: 300_000, open: true }
    const joined = touched(ended, 340_000, false)
    const done = touched(joined, 342_000, true)
    expect(joined.idle).toBe(40_000)
    expect(elapsedOf(done, 342_000, false)).toBe(302_000)
    expect(elapsedOf({ ...done, idle: undefined }, 342_000, false)).toBe(342_000)
  })
  test('no task opens one', () => {
    expect(touched(null, 5_000, false)).toEqual({ start: 5_000, last: 5_000, open: true, idle: 0 })
  })
  test('closes after 60 s of quiet, never while busy', () => {
    expect(settled(task, 100_000 + SETTLE_MS - 1, false)).toBe(false)
    expect(settled(task, 100_000 + SETTLE_MS, false)).toBe(true)
    expect(settled(task, 900_000, true)).toBe(false)
    expect(settled({ ...task, open: false }, 900_000, false)).toBe(false)
  })
  test('elapsed runs to now while busy, to the last activity once idle', () => {
    expect(elapsedOf(task, 500_000, true)).toBe(499_000)
    expect(elapsedOf(task, 500_000, false)).toBe(99_000)
  })
})

describe('hive, spec, status', () => {
  test('hive', () => {
    expect(isHive({ vulyk: true, cycle: false })).toBe(true)
    expect(isHive({ vulyk: false, cycle: true })).toBe(true)
    expect(isHive({ vulyk: false, cycle: false })).toBe(false)
  })
  test('spec of a Workflow call', () => {
    expect(specOf({ spec: 'docs/specs/acme-invoices', wave: 1 })).toBe('docs/specs/acme-invoices')
    expect(specOf({ spec: '' })).toBe(null)
    expect(specOf(undefined)).toBe(null)
    expect(specOf('x')).toBe(null)
  })
  test('status json', () => {
    expect(parseStatus('{"stage":"build","wave":2,"round":0}')).toEqual({ wave: 2, round: 0 })
    expect(parseStatus('{"wave":1,"round":3}')).toEqual({ wave: 1, round: 3 })
    expect(parseStatus('not json')).toEqual({ wave: 0, round: 0 })
  })
})

describe('pass-through outside a hive', () => {
  // The test environment has no fs, so neither CLAUDE.vulyk.md nor scripts/cycle.sh exists: every site draws no pulse row.
  // (`$.state` is not reachable from the test's `$`, so the gate cannot be isolated from the empty task here.)
  test('Spinner, AbovePrompt and TurnDuration keep the engine drawing', async ($, on) => {
    // What stands for the engine beneath the plugin: core's own drawing, which `next(e)` hands up.
    on('ui.render', () => ({ type: 'engine', ref: 0 }))
    const sites = [
      { component: 'Spinner', props: { word: 'Sauteing', message: null, suffix: '…', mode: 'thinking' } },
      {
        component: 'AbovePrompt',
        props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { bodyRows: 5 }, view: { kind: 'main' } },
      },
      { component: 'TurnDuration', props: { word: 'Baked', durationMs: 3000 } },
    ] as const
    for (const site of sites) {
      const ui = await $.ui.mount({ plugin: 'vulyk-pulse', surface: 'terminal', ...site } as never)
      expect(await ui.find({ type: 'Text', text: /VULYK|≈/ })).toBeUndefined()
    }
  })
})

describe('closing line inside a hive', () => {
  // What stands for the engine beneath the plugin: a hive root holding CLAUDE.vulyk.md, a mocked clock, core's own drawing.
  const hiveBeneath = (on: any, now: number) => {
    on('session.root', () => ({ value: '/hive' }))
    on('fs.read', (_$: unknown, e: { path: string }) =>
      e.path.endsWith('CLAUDE.vulyk.md') ? { value: '' } : { deny: 'no such file' },
    )
    on('prompt.submit', (_$: unknown, e: { text: string; origin: unknown }) => ({ text: e.text, origin: e.origin }))
    on('turn.start', (_$: unknown, e: { turnId: string }) => ({ turnId: e.turnId }))
    on('turn.complete', () => ({ text: '' }))
    on('ui.render', () => ({ type: 'engine', ref: 0 }))
    return mock.clock(on, { now })
  }
  const turn = async ($: any, clock: any, id: string, ms: number) => {
    await $.turn.start({ text: 'go', turnId: id })
    await clock.advance(ms)
    await $.turn.complete({ answer: '', durationMs: ms, isAborted: false, turnId: id, reason: 'answer' })
  }
  const line = async ($: any, requestId: string) => {
    const ui = await $.ui.mount({
      plugin: 'vulyk-pulse',
      surface: 'terminal',
      component: 'TurnDuration',
      requestId,
      props: { word: 'Baked', durationMs: 2500 },
    } as never)
    const text = (await ui.find({ type: 'Text', text: /Baked for/ }))?.text
    await ui.unmount()
    return text
  }

  test('a turn draws the pulse closing line, and a later task does not repaint it', async ($, on) => {
    const clock = hiveBeneath(on, 1_000_000)
    await $.prompt.submit({ text: 'task A', wait: false, origin: { kind: 'composer' } } as never)
    await turn($, clock, 'a', 2_500)
    expect(await line($, 'line-a')).toBe('Baked for 0m 02s · ≈0 tok')
    await clock.advance(120_000)
    await $.prompt.submit({ text: 'task B', wait: false, origin: { kind: 'composer' } } as never)
    await turn($, clock, 'b', 7_000)
    expect(await line($, 'line-b')).toBe('Baked for 0m 07s · ≈0 tok')
    expect(await line($, 'line-a')).toBe('Baked for 0m 02s · ≈0 tok')
  })

  test("a task notification joins the owner's task, its closing line carries the task total", async ($, on) => {
    const clock = hiveBeneath(on, 5_000_000)
    await $.prompt.submit({ text: 'build it', wait: false, origin: { kind: 'composer' } } as never)
    await turn($, clock, 'launch', 2_000)
    await clock.advance(30_000)
    await $.prompt.submit({ text: '<task-notification>', wait: false, origin: { kind: 'task-notification' } } as never)
    await turn($, clock, 'notice', 3_000)
    expect(await line($, 'line-notice')).toBe('Baked for 0m 05s · ≈0 tok')
  })

  test('off the terminal, AbovePrompt and TurnDuration keep the engine drawing while the terminal draws the pulse', async ($, on) => {
    const clock = hiveBeneath(on, 9_000_000)
    on('agent.spawn', () => ({ model: 'sonnet', agentId: 'a1' }))
    await $.prompt.submit({ text: 'go', wait: false, origin: { kind: 'composer' } } as never)
    await turn($, clock, 'x', 2_500)
    await $.agent.spawn({ subagentType: 'worker-code', prompt: 'p', description: 'd' } as never)
    const above = {
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { bodyRows: 5 }, view: { kind: 'main' } },
    }
    const closingSite = { component: 'TurnDuration', requestId: 'surf', props: { word: 'Baked', durationMs: 2500 } }
    const drawn = async (surface: string, site: object) => {
      const ui = await $.ui.mount({ plugin: 'vulyk-pulse', surface, ...site } as never)
      const found = await ui.find({ type: 'Text', text: /VULYK|Baked for/ })
      await ui.unmount()
      return found !== undefined
    }
    expect(await drawn('terminal', above)).toBe(true)
    expect(await drawn('terminal', closingSite)).toBe(true)
    expect(await drawn('desktop', above)).toBe(false)
    expect(await drawn('desktop', { ...closingSite, requestId: 'surf2' })).toBe(false)
  })
})
