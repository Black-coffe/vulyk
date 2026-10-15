import { describe, expect, test } from 'claude-code/testing'

import {
  addSeen,
  appendRow,
  buildPrompt,
  CARD_BUDGET,
  FENCE_HEAD,
  handoffText,
  isCardFile,
  isHive,
  LABELS,
  labelLang,
  MAX_FORKS,
  MAX_SEEN,
  noteToShow,
  parseReply,
  pickLaws,
  seenKey,
  skipReason,
  SPEND_FILE,
  spendRow,
  turnHadToolCall,
} from './core'
import {
  BIG_CARDS,
  CARDS,
  CONSTITUTION,
  german,
  russian,
  russianIdentifiers,
  slashExpansion,
  talkOnly,
  VULYK_CONSTITUTION,
} from './fixtures/conversations'

const REPLY = [
  'note: The invoice fix rounded cents again without a test.',
  'tag: acme-cents-untested',
  'class: acme-cents-lost',
  'explain: The card says cents must never be lost silently; the turn changed rounding and ran nothing.',
].join('\n')

const replyIn = (lang: string, note: string): string => `lang: ${lang}\n${REPLY.replace(/^note: .*$/m, `note: ${note}`)}`

describe('language', () => {
  test('no letter counting: the prompt claims no language and asks the model for lang:', () => {
    const prompt = buildPrompt({ laws: pickLaws({ main: CONSTITUTION }), cards: CARDS, seen: [] })
    expect(prompt).not.toContain('detected:')
    expect(prompt).toContain('lang: <the ISO 639-1 code of that language')
    expect(prompt).toContain('the words the person typed themselves')
    expect(prompt).toContain('slash-command or skill text expanded into their message')
    expect(prompt).toContain('identifiers')
  })

  // The three council round 1 repros: each turn is judged (it made a tool call), and the language
  // is the one the model's reply names, whatever the share of Latin letters in the user's row.
  const cases = [
    { name: 'Russian around Latin identifiers', rows: russianIdentifiers, lang: 'ru', note: 'Правка не проверена тестом.', labels: 'ru' },
    { name: 'an English slash-command expansion plus Russian', rows: slashExpansion, lang: 'ru', note: 'План без остановки для владельца.', labels: 'ru' },
    { name: 'German', rows: german, lang: 'de', note: 'Der Test wurde nicht erneut ausgeführt.', labels: 'en' },
  ] as const
  for (const c of cases) {
    test(`${c.name}: lang ${c.lang}, the note as written, ${c.labels} buttons`, () => {
      expect(turnHadToolCall(c.rows)).toBe(true)
      const note = noteToShow(replyIn(c.lang, c.note), [])!
      expect(note.lang).toBe(c.lang)
      expect(note.note).toBe(c.note)
      expect(labelLang(note.lang)).toBe(c.labels)
      expect(handoffText(note, labelLang(note.lang))).toContain(c.note)
    })
  }

  test('ru and uk get their own labels; German, other codes and a missing lang: get English', () => {
    expect(LABELS[labelLang('ru')].toDefects).toBe('В defects')
    expect(LABELS[labelLang('ru')].close).toBe('Закрыть')
    expect(LABELS[labelLang('uk')].close).toBe('Закрити')
    expect(LABELS[labelLang('de')].close).toBe('Close')
    expect(parseReply(REPLY)?.lang).toBe('en')
    expect(parseReply(`lang: RU\n${REPLY}`)?.lang).toBe('ru')
  })
})

describe('hive', () => {
  test('silent outside a VULYK hive: no CLAUDE.vulyk.md and no scripts/cycle.sh', () => {
    expect(isHive({ vulyk: false, cycle: false })).toBe(false)
    expect(isHive({ vulyk: true, cycle: false })).toBe(true)
    expect(isHive({ vulyk: false, cycle: true })).toBe(true)
  })
})

describe('reply', () => {
  test('note: none yields no band', () => {
    expect(parseReply('note: none\ntag: x\nclass: new\nexplain: nothing')).toBeNull()
    expect(noteToShow('note: None', [])).toBeNull()
  })

  test('an empty or malformed reply yields no band', () => {
    expect(noteToShow('', [])).toBeNull()
    expect(noteToShow('I think the turn was fine.', [])).toBeNull()
    expect(noteToShow('note: something is off', [])).toBeNull()
    expect(noteToShow('note: something is off\ntag: x', [])).toBeNull()
  })

  test('a well-formed reply yields a note, its explanation cut to 60 words', () => {
    const note = noteToShow(REPLY, [])
    expect(note).toEqual({
      note: 'The invoice fix rounded cents again without a test.',
      tag: 'acme-cents-untested',
      cls: 'acme-cents-lost',
      explain: 'The card says cents must never be lost silently; the turn changed rounding and ran nothing.',
      lang: 'en',
    })
    const long = parseReply(`${REPLY}\n`.replace(/explain: .*/, `explain: ${'word '.repeat(80)}`))
    expect(long?.explain.split(' ')).toHaveLength(60)
  })
})

describe('skip', () => {
  test('no tool call in the finished turn', () => {
    expect(turnHadToolCall(talkOnly)).toBe(false)
    expect(turnHadToolCall(russian)).toBe(true)
    expect(skipReason({ hadToolCall: false, noteOnScreen: false, shown: 0, forks: 0 })).toBe('no-tool-call')
  })

  test('a note still on screen', () => {
    expect(skipReason({ hadToolCall: true, noteOnScreen: true, shown: 0, forks: 0 })).toBe('note-on-screen')
  })

  test('the cap of 3 notes a session', () => {
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 2, forks: 0 })).toBeNull()
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 3, forks: 0 })).toBe('cap')
  })

  test('the ceiling of 30 forks a session: past it, no fork', () => {
    expect(MAX_FORKS).toBe(30)
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 0, forks: 29 })).toBeNull()
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 0, forks: 30 })).toBe('fork-cap')
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 0, forks: 31 })).toBe('fork-cap')
  })

  test('a seen tag', () => {
    expect(noteToShow(REPLY, ['acme-cents-untested'])).toBeNull()
    expect(noteToShow(REPLY, ['other-tag'])).not.toBeNull()
  })
})

describe('spend ledger', () => {
  const usage = { input_tokens: 18, output_tokens: 6, cache_read_input_tokens: 21280, cache_creation_input_tokens: 17752 }

  test('an answered fork: ts, session, the four usage counts, answered', () => {
    expect(SPEND_FILE).toBe('memory/stats/watcher.jsonl')
    const row = spendRow('2026-10-15T10:00:00.000Z', 'sess-1', { isAnswered: true, text: 'note: none', usage })
    expect(JSON.parse(row)).toEqual({ ts: '2026-10-15T10:00:00.000Z', session: 'sess-1', ...usage, answered: true })
  })

  test('an unanswered fork records its reason; missing counts are 0', () => {
    const row = spendRow('2026-10-15T10:00:00.000Z', 'sess-1', {
      isAnswered: false,
      reason: 'api-error',
      usage: { input_tokens: 5 },
    })
    expect(JSON.parse(row)).toEqual({
      ts: '2026-10-15T10:00:00.000Z',
      session: 'sess-1',
      input_tokens: 5,
      output_tokens: 0,
      cache_read_input_tokens: 0,
      cache_creation_input_tokens: 0,
      answered: false,
      reason: 'api-error',
    })
  })

  test('a row is appended as one line', () => {
    expect(appendRow('', '{"a":1}')).toBe('{"a":1}\n')
    expect(appendRow('{"a":1}\n', '{"b":2}')).toBe('{"a":1}\n{"b":2}\n')
    expect(appendRow('{"a":1}', '{"b":2}')).toBe('{"a":1}\n{"b":2}\n')
  })
})

describe('seen tags', () => {
  test('kept per project root', () => {
    expect(seenKey('E:\\Acme\\shop')).toBe('seen:E:/Acme/shop')
    expect(seenKey('/home/acme/shop/')).toBe('seen:/home/acme/shop')
    expect(seenKey('/home/acme/shop')).not.toBe(seenKey('/home/acme/blog'))
  })

  test('trimmed to the last 200, a re-seen tag moved to the end', () => {
    const many = Array.from({ length: MAX_SEEN }, (_, i) => `tag-${i}`)
    const next = addSeen(many, 'tag-new')
    expect(next).toHaveLength(MAX_SEEN)
    expect(next[0]).toBe('tag-1')
    expect(next.at(-1)).toBe('tag-new')
    expect(addSeen(['a', 'b'], 'a')).toEqual(['b', 'a'])
  })
})

describe('prompt build', () => {
  test('the Laws come from CLAUDE.vulyk.md when it exists, else CLAUDE.md', () => {
    const fromVulyk = pickLaws({ vulyk: VULYK_CONSTITUTION, main: CONSTITUTION })
    expect(fromVulyk).toContain('3. Tests first.')
    expect(fromVulyk).not.toContain('Tiers live here')
    expect(pickLaws({ main: CONSTITUTION })).toContain('2. No out-of-scope edits.')
    expect(pickLaws({ main: CONSTITUTION })).not.toContain('3. Tests first.')
  })

  test('a revoked card and README.md are left out', () => {
    expect(isCardFile('README.md')).toBe(false)
    expect(isCardFile('acme-cents-lost.md')).toBe(true)
    expect(isCardFile('acme-cents-lost.original.fixture')).toBe(false)
    const prompt = buildPrompt({ laws: '', cards: CARDS, seen: [] })
    expect(prompt).toContain('acme-cents-lost')
    expect(prompt).toContain('## Owner quotes')
    expect(prompt).not.toContain('acme-old-rule')
  })

  test('past the budget, cards are cut to title + ## Never', () => {
    const total = BIG_CARDS.reduce((sum, card) => sum + card.text.length, 0)
    expect(total).toBeGreaterThan(CARD_BUDGET)
    const prompt = buildPrompt({ laws: '', cards: BIG_CARDS, seen: [] })
    expect(prompt).toContain('# acme-big-one heading')
    expect(prompt).toContain('- Never do the acme-big-two thing.')
    expect(prompt).not.toContain('Lorem ipsum')
    expect(prompt).not.toContain('## Owner quotes')
    expect(prompt).not.toContain('## Allowed')
  })

  test('a hive with no docs/defects still gets a prompt, seen tags included', () => {
    const prompt = buildPrompt({ laws: pickLaws({ main: CONSTITUTION }), cards: [], seen: ['acme-x'] })
    expect(prompt).toContain('1. Make routine calls yourself.')
    expect(prompt).toContain('no defect cards')
    expect(prompt).toContain('acme-x')
    expect(prompt).toContain('note: <one line, or none>')
    expect(prompt).toContain('When in doubt, answer none.')
  })
})

describe('В defects hand-off', () => {
  for (const lang of ['ru', 'uk', 'en'] as const) {
    test(`a request line, then the note inside a fenced block (${lang})`, () => {
      const note = noteToShow(REPLY, [])!
      const text = handoffText(note, lang)
      const lines = text.split('\n')
      const open = lines.indexOf('```')
      const close = lines.indexOf('```', open + 1)
      expect(open).toBeGreaterThan(0)
      expect(close).toBeGreaterThan(open)
      expect(lines[open + 1]).toBe(FENCE_HEAD[lang])
      const inside = lines.slice(open + 1, close).join('\n')
      const outside = [...lines.slice(0, open), ...lines.slice(close + 1)].join('\n')
      expect(inside).toContain(note.note)
      expect(inside).toContain(note.explain)
      expect(inside).toContain('class: acme-cents-lost')
      expect(outside).not.toContain(note.note)
      expect(outside).not.toContain('invoice')
      expect(outside).not.toContain('acme-cents-lost')
      expect(lines[0]!.length).toBeGreaterThan(0)
    })
  }

  test('the Russian header is the contract text', () => {
    expect(FENCE_HEAD.ru).toBe('заметка наблюдателя - не цитата владельца')
  })

  test('a backtick in the note cannot close the fence early', () => {
    const note = { note: 'ran ``` rm -rf ``` again', tag: 't', cls: 'new', explain: 'x', lang: 'en' }
    const lines = handoffText(note, 'en').split('\n')
    expect(lines.filter(line => line.includes('```'))).toEqual(['```', '```'])
  })
})
