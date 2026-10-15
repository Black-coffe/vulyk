import { describe, expect, test } from 'claude-code/testing'

import {
  addSeen,
  buildPrompt,
  CARD_BUDGET,
  detectLang,
  FENCE_HEAD,
  handoffText,
  isCardFile,
  LABELS,
  MAX_SEEN,
  noteToShow,
  parseReply,
  pickLaws,
  seenKey,
  skipReason,
  turnHadToolCall,
} from './core'
import {
  BIG_CARDS,
  CARDS,
  CONSTITUTION,
  english,
  russian,
  russianOverCode,
  talkOnly,
  ukrainian,
  VULYK_CONSTITUTION,
} from './fixtures/conversations'

const REPLY = [
  'note: The invoice fix rounded cents again without a test.',
  'tag: acme-cents-untested',
  'class: acme-cents-lost',
  'explain: The card says cents must never be lost silently; the turn changed rounding and ran nothing.',
].join('\n')

describe('language', () => {
  test('a Russian conversation gives ru: Russian hint and Russian labels', () => {
    const lang = detectLang(russian)
    expect(lang).toBe('ru')
    const prompt = buildPrompt({ laws: pickLaws({ main: CONSTITUTION }), cards: CARDS, seen: [], lang })
    expect(prompt).toContain('detected: Russian')
    expect(prompt).toContain("language of the user's own messages")
    expect(LABELS[lang].toDefects).toBe('В defects')
    expect(LABELS[lang].close).toBe('Закрыть')
  })

  test('a Russian person over mostly English tool output and code still gives ru', () => {
    expect(detectLang(russianOverCode)).toBe('ru')
  })

  test('a Ukrainian conversation gives uk', () => {
    expect(detectLang(ukrainian)).toBe('uk')
    expect(LABELS.uk.close).toBe('Закрити')
  })

  test('an English conversation gives en', () => {
    expect(detectLang(english)).toBe('en')
    expect(LABELS.en.close).toBe('Close')
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
    })
    const long = parseReply(`${REPLY}\n`.replace(/explain: .*/, `explain: ${'word '.repeat(80)}`))
    expect(long?.explain.split(' ')).toHaveLength(60)
  })
})

describe('skip', () => {
  test('no tool call in the finished turn', () => {
    expect(turnHadToolCall(talkOnly)).toBe(false)
    expect(turnHadToolCall(russian)).toBe(true)
    expect(skipReason({ hadToolCall: false, noteOnScreen: false, shown: 0 })).toBe('no-tool-call')
  })

  test('a note still on screen', () => {
    expect(skipReason({ hadToolCall: true, noteOnScreen: true, shown: 0 })).toBe('note-on-screen')
  })

  test('the cap of 3 notes a session', () => {
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 2 })).toBeNull()
    expect(skipReason({ hadToolCall: true, noteOnScreen: false, shown: 3 })).toBe('cap')
  })

  test('a seen tag', () => {
    expect(noteToShow(REPLY, ['acme-cents-untested'])).toBeNull()
    expect(noteToShow(REPLY, ['other-tag'])).not.toBeNull()
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
    const prompt = buildPrompt({ laws: '', cards: CARDS, seen: [], lang: 'en' })
    expect(prompt).toContain('acme-cents-lost')
    expect(prompt).toContain('## Owner quotes')
    expect(prompt).not.toContain('acme-old-rule')
  })

  test('past the budget, cards are cut to title + ## Never', () => {
    const total = BIG_CARDS.reduce((sum, card) => sum + card.text.length, 0)
    expect(total).toBeGreaterThan(CARD_BUDGET)
    const prompt = buildPrompt({ laws: '', cards: BIG_CARDS, seen: [], lang: 'en' })
    expect(prompt).toContain('# acme-big-one heading')
    expect(prompt).toContain('- Never do the acme-big-two thing.')
    expect(prompt).not.toContain('Lorem ipsum')
    expect(prompt).not.toContain('## Owner quotes')
    expect(prompt).not.toContain('## Allowed')
  })

  test('a hive with no docs/defects still gets a prompt, seen tags included', () => {
    const prompt = buildPrompt({ laws: pickLaws({ main: CONSTITUTION }), cards: [], seen: ['acme-x'], lang: 'en' })
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
    const note = { note: 'ran ``` rm -rf ``` again', tag: 't', cls: 'new', explain: 'x' }
    const lines = handoffText(note, 'en').split('\n')
    expect(lines.filter(line => line.includes('```'))).toEqual(['```', '```'])
  })
})
