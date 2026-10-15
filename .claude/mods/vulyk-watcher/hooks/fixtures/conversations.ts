// Synthetic conversations and cards (Acme stand-ins), never a real transcript.
import type { Card, Row } from '../core'

const tool = (name: string) => ({ name, input: {} })
const result = (text: string) => ({ tool_use_id: 't1', text, isError: false })

const LONG_CODE = [
  'export function invoice(total: number) {',
  '  // Acme billing: compute the tax, round the cents, return the payable amount',
  '  const tax = Math.round(total * 0.2 * 100) / 100',
  '  return { total, tax, payable: total + tax }',
  '}',
].join('\n')

export const russian: Row[] = [
  { role: 'user', text: 'Почини, пожалуйста, расчёт налога в счёте Acme: округление съедает копейки.' },
  { role: 'assistant', text: 'Смотрю файл.', toolUses: [tool('Read')] },
  { role: 'user', text: '', toolResults: [result(LONG_CODE)] },
  { role: 'assistant', text: 'Исправил округление.', toolUses: [tool('Edit')] },
  { role: 'user', text: '', toolResults: [result('The file was updated.')] },
  { role: 'assistant', text: 'Готово: налог теперь считается в центах.' },
]

/** A Russian person whose turns are buried in English tool output and code. */
export const russianOverCode: Row[] = [
  { role: 'user', text: 'Запусти тесты Acme и скажи, что упало.' },
  {
    role: 'assistant',
    text: 'Running the whole suite now. The billing module has the most coverage, so I will start with it.',
    toolUses: [tool('Bash')],
  },
  {
    role: 'user',
    text: '',
    toolResults: [result(`FAIL billing.test.ts\n  Expected payable 120.00, received 119.99\n${LONG_CODE}\n${LONG_CODE}`)],
  },
  { role: 'user', text: 'Вот лог:\n```\nTypeError: cannot read properties of undefined (reading total) at invoice\n```' },
  {
    role: 'assistant',
    text: 'The failure is a rounding error in invoice(); the stack trace points at the tax line. Fixing it.',
    toolUses: [tool('Edit')],
  },
  { role: 'user', text: '', toolResults: [result(LONG_CODE)] },
]

export const ukrainian: Row[] = [
  { role: 'user', text: 'Виправ, будь ласка, звіт Acme: дати їдуть на один день.' },
  { role: 'assistant', text: 'Дивлюся.', toolUses: [tool('Grep')] },
  { role: 'user', text: '', toolResults: [result('report.ts:12 new Date(day)')] },
  { role: 'assistant', text: 'Це часовий пояс, виправив.' },
]

export const english: Row[] = [
  { role: 'user', text: 'Rename the Acme exporter to acme-export and update the imports.' },
  { role: 'assistant', text: 'Renaming.', toolUses: [tool('Bash')] },
  { role: 'user', text: '', toolResults: [result('renamed')] },
  { role: 'assistant', text: 'Done.' },
]

/** The last turn only talked: an earlier turn's tool call does not count. */
export const talkOnly: Row[] = [
  ...english,
  { role: 'user', text: 'What does the exporter do?' },
  { role: 'assistant', text: 'It writes Acme orders to CSV.' },
]

export const CONSTITUTION = [
  '# Acme Constitution',
  '',
  '## Laws',
  '',
  '1. Make routine calls yourself.',
  '2. No out-of-scope edits.',
  '',
  '## Routing',
  '',
  'Tiers live here.',
].join('\n')

export const VULYK_CONSTITUTION = CONSTITUTION.replace('# Acme Constitution', '# Acme VULYK Constitution').replace(
  '2. No out-of-scope edits.',
  '2. No out-of-scope edits.\n3. Tests first.',
)

const card = (id: string, status: string, filler = '') =>
  [
    '---',
    `id: ${id}`,
    `title: ${id} title`,
    `status: ${status}`,
    '---',
    '',
    `# ${id} heading`,
    `What ${id} is, as the owner sees it.${filler}`,
    '',
    '## Owner quotes',
    `- 2026-10-01 · Acme — «${id} again»`,
    '',
    '## Never',
    `- Never do the ${id} thing.`,
    '',
    '## Allowed',
    `- The ${id} neighbour.`,
  ].join('\n')

export const CARDS: Card[] = [
  { id: 'acme-cents-lost', text: card('acme-cents-lost', 'block') },
  { id: 'acme-old-rule', text: card('acme-old-rule', 'revoked') },
]

const BULK = ' Lorem ipsum Acme filler.'.repeat(500)

export const BIG_CARDS: Card[] = [
  { id: 'acme-big-one', text: card('acme-big-one', 'block', BULK) },
  { id: 'acme-big-two', text: card('acme-big-two', 'warn', BULK) },
]
