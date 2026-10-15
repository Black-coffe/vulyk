// The watcher's pure parts: skip decision, hive check, labels, prompt build, reply parse, seen-list update,
// band labels and the «В defects» hand-off text. No `$` here: register.tsx reads and writes, this decides.

export type Lang = 'ru' | 'uk' | 'en'

/** A transcript row as `$.session.messages()` answers it, the fields the watcher reads. */
export type Row = {
  role: 'user' | 'assistant'
  text: string
  toolUses?: readonly unknown[]
  toolResults?: readonly unknown[]
}

export type Card = { id: string; text: string }

/** `lang` is the reply's own code (ISO 639-1, lower case), chosen by the model; `en` when the reply gave none. */
export type Note = { note: string; tag: string; cls: string; explain: string; lang: string }

export const MAX_NOTES = 3
export const MAX_SEEN = 200
/** The forks a session may spend; past it, no fork and no note (the owner's spend decision). */
export const MAX_FORKS = 30
export const CARD_BUDGET = 16 * 1024

const isPrompt = (row: Row): boolean =>
  row.role === 'user' && (row.toolResults ?? []).length === 0 && row.text.trim() !== ''

/** Whether the turn just finished (rows after the person's last prompt) made a tool call. */
export const turnHadToolCall = (rows: readonly Row[]): boolean => {
  let start = rows.length - 1
  while (start >= 0 && !isPrompt(rows[start]!)) start -= 1
  return rows.slice(start + 1).some(row => row.role === 'assistant' && (row.toolUses ?? []).length > 0)
}

/** Why no fork runs this turn, or null when it should. */
export const skipReason = (s: {
  hadToolCall: boolean
  noteOnScreen: boolean
  shown: number
  forks: number
}): 'no-tool-call' | 'note-on-screen' | 'cap' | 'fork-cap' | null => {
  if (!s.hadToolCall) return 'no-tool-call'
  if (s.noteOnScreen) return 'note-on-screen'
  if (s.shown >= MAX_NOTES) return 'cap'
  if (s.forks >= MAX_FORKS) return 'fork-cap'
  return null
}

/** Where each fork's spend is appended, relative to the project root. */
export const SPEND_FILE = 'memory/stats/watcher.jsonl'

/** What `$.model.fork` answers: the text when answered, the reason when not, the usage either way. */
export type ForkResult = { isAnswered: boolean; text?: string; reason?: string; usage?: Record<string, unknown> }

const count = (x: unknown): number => (typeof x === 'number' && Number.isFinite(x) ? x : 0)

/** One fork's spend row: ts, session, the usage's four counts, and answered or the reason it was not. */
export const spendRow = (ts: string, session: string, r: ForkResult): string => {
  const u = r.usage ?? {}
  return JSON.stringify({
    ts,
    session,
    input_tokens: count(u.input_tokens),
    output_tokens: count(u.output_tokens),
    cache_read_input_tokens: count(u.cache_read_input_tokens),
    cache_creation_input_tokens: count(u.cache_creation_input_tokens),
    ...(r.isAnswered ? { answered: true } : { answered: false, reason: r.reason ?? 'unknown' }),
  })
}

/** The ledger's text with one row appended; a last line without its newline gets one first. */
export const appendRow = (existing: string, row: string): string =>
  `${existing}${existing === '' || existing.endsWith('\n') ? '' : '\n'}${row}\n`

/** The band and hand-off strings for a reply's `lang:` code: ru and uk have their own, any other language gets en. */
export const labelLang = (code: string): Lang => (code === 'ru' || code === 'uk' ? code : 'en')

/** A VULYK hive has `CLAUDE.vulyk.md` or `scripts/cycle.sh` at its root; anywhere else the watcher stays silent. */
export const isHive = (root: { vulyk: boolean; cycle: boolean }): boolean => root.vulyk || root.cycle

export const LABELS: Record<Lang, { title: string; toDefects: string; close: string }> = {
  ru: { title: 'Наблюдатель', toDefects: 'В defects', close: 'Закрыть' },
  uk: { title: 'Спостерігач', toDefects: 'В defects', close: 'Закрити' },
  en: { title: 'Watcher', toDefects: 'To defects', close: 'Close' },
}

/** The `## Laws` section of a constitution, heading included; '' when it has none. */
export const lawsOf = (constitution: string): string => {
  const lines = constitution.split(/\r?\n/)
  const at = lines.findIndex(line => /^##\s+Laws\s*$/.test(line))
  if (at < 0) return ''
  const end = lines.findIndex((line, i) => i > at && /^##\s/.test(line))
  return lines.slice(at, end < 0 ? lines.length : end).join('\n').trim()
}

/** The Laws the fork reads: `CLAUDE.vulyk.md` when it exists, else `CLAUDE.md` (lib.sh `constitution_file`). */
export const pickLaws = (files: { vulyk?: string; main?: string }): string => lawsOf(files.vulyk ?? files.main ?? '')

/** A card whose `status:` line says `revoked`: the one field read. */
export const isRevoked = (text: string): boolean => /^status:\s*revoked\s*$/m.test(text)

/** A card cut to its title and its `## Never` lines. */
export const cutCard = (text: string): string => {
  const lines = text.split(/\r?\n/)
  const title = lines.find(line => /^#\s/.test(line)) ?? ''
  const at = lines.findIndex(line => /^##\s+Never\s*$/.test(line))
  if (at < 0) return title
  const end = lines.findIndex((line, i) => i > at && /^##\s/.test(line))
  const never = lines.slice(at, end < 0 ? lines.length : end).join('\n').trim()
  return `${title}\n${never}`
}

/** The card files the watcher reads: `*.md` under docs/defects, README.md excluded. */
export const isCardFile = (name: string): boolean => /\.md$/i.test(name) && name.toLowerCase() !== 'readme.md'

/** The cards' text for the prompt: live cards whole, or each cut to title + `## Never` past the budget. */
export const cardsText = (cards: readonly Card[]): string => {
  const live = cards.filter(card => !isRevoked(card.text))
  const whole = live.map(card => `### card: ${card.id}\n${card.text.trim()}`).join('\n\n')
  if (whole.length <= CARD_BUDGET) return whole
  return live.map(card => `### card: ${card.id}\n${cutCard(card.text)}`).join('\n\n')
}

export const buildPrompt = (p: { laws: string; cards: readonly Card[]; seen: readonly string[] }): string => {
  const cards = cardsText(p.cards)
  return [
    'You are a quiet watcher over this session. Judge ONLY the turn that just finished, the last exchange above.',
    'Flag it only if that turn likely broke one of the Laws below, or repeats the class of one of the defect cards below,',
    'and the main agent did not raise it itself, and it would cost the owner (wrong work, lost data, a repeat they corrected before).',
    'Skip anything already discussed in the conversation and anything matching a seen tag. When in doubt, answer none.',
    'Most turns deserve none.',
    '',
    '== Laws ==',
    p.laws || '(no Laws section found)',
    '',
    '== Defect cards ==',
    cards || '(this project has no defect cards)',
    '',
    '== Seen tags (never flag these again) ==',
    p.seen.length > 0 ? p.seen.join(', ') : '(none)',
    '',
    'Write note and explain in the language the user writes their own messages in, any language.',
    'Judge that language from the words the person typed themselves; ignore code, file names, identifiers, commands,',
    'tool output, and any slash-command or skill text expanded into their message.',
    'Reply with exactly these five lines and nothing else:',
    'lang: <the ISO 639-1 code of that language, e.g. ru, uk, en, de>',
    'note: <one line, or none>',
    'tag: <a short kebab-case tag naming this finding>',
    'class: <a card id, law <n>, or new>',
    'explain: <why, 60 words at most>',
  ].join('\n')
}

/** The fork's reply as a note, or null: `note: none`, an empty or a malformed reply all give null. */
export const parseReply = (text: string): Note | null => {
  const field = (name: string): string => {
    const m = text.match(new RegExp(`^\\s*${name}\\s*:[ \\t]*(.*)$`, 'mi'))
    return (m?.[1] ?? '').trim()
  }
  const note = field('note')
  if (note === '' || /^none\.?$/i.test(note)) return null
  const tag = field('tag').toLowerCase()
  const cls = field('class')
  if (tag === '' || cls === '') return null
  const explain = field('explain').split(/\s+/).filter(Boolean).slice(0, 60).join(' ')
  const lang = field('lang').toLowerCase().match(/^[a-z]{2,3}\b/)?.[0] ?? 'en'
  return { note, tag, cls, explain, lang }
}

/** The note a fork's reply puts on the band, or null: nothing to say, malformed, or a tag already seen. */
export const noteToShow = (reply: string, seen: readonly string[]): Note | null => {
  const note = parseReply(reply)
  return note === null || seen.includes(note.tag) ? null : note
}

/** The seen list after showing `tag`: moved to the end, the last 200 kept. */
export const addSeen = (seen: readonly string[], tag: string): string[] =>
  [...seen.filter(one => one !== tag), tag].slice(-MAX_SEEN)

/** The `$.store` key of one project's seen tags. */
export const seenKey = (root: string): string => `seen:${root.replace(/\\/g, '/').replace(/\/+$/, '')}`

const REQUEST: Record<Lang, string> = {
  ru: 'Это заметка наблюдателя, а не мои слова: покажи её мне и спроси, дефект ли это; под цитаты владельца идут только мои собственные слова.',
  uk: 'Це нотатка спостерігача, а не мої слова: покажи її мені й запитай, чи це дефект; під цитати власника йдуть лише мої власні слова.',
  en: 'This is a watcher note, not my words: show it to me and ask whether it is a defect; only my own words go under owner quotes.',
}

export const FENCE_HEAD: Record<Lang, string> = {
  ru: 'заметка наблюдателя - не цитата владельца',
  uk: 'нотатка спостерігача - не цитата власника',
  en: 'watcher note - not an owner quote',
}

// A backtick inside the block could close the fence early and leak the note's words past it.
const inFence = (s: string): string => s.replace(/`/g, "'").replace(/~~~/g, '~ ~ ~')

/** The «В defects» text: one request line, then the note inside a fenced block. */
export const handoffText = (n: Note, lang: Lang): string =>
  [
    REQUEST[lang],
    '',
    '```',
    FENCE_HEAD[lang],
    inFence(n.note),
    inFence(n.explain),
    `class: ${inFence(n.cls)}`,
    '```',
    '',
  ].join('\n')
