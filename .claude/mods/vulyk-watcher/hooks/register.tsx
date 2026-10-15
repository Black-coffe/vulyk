import type { Register } from 'claude-code'

import {
  addSeen,
  buildPrompt,
  detectLang,
  handoffText,
  isCardFile,
  LABELS,
  noteToShow,
  pickLaws,
  seenKey,
  skipReason,
  turnHadToolCall,
} from './core'
import type { Card, Lang, Note, Row } from './core'

type Shown = Note & { lang: Lang }

export const register: Register = on => {
  // Session-held: `$.state` would need a types contract in plugin.json (-01's file). A hot reload clears both.
  let onScreen: Shown | null = null
  let shownCount = 0

  // Once per turn, after the turn is settled; a subagent's turn is not judged.
  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId !== undefined) return done

    try {
      const rows = await $.session.messages()
      if (!Array.isArray(rows)) return done
      const turn = rows as readonly Row[]
      const skip = skipReason({
        hadToolCall: turnHadToolCall(turn),
        noteOnScreen: onScreen !== null,
        shown: shownCount,
      })
      if (skip !== null) return done

      const root = await $.session.root()
      const text = (path: string) => $.fs.read(`${root}/${path}`).catch(() => undefined)
      const laws = pickLaws({ vulyk: await text('CLAUDE.vulyk.md'), main: await text('CLAUDE.md') })
      const entries = await $.fs.list(`${root}/docs/defects`).catch(() => [])
      const cards: Card[] = []
      for (const entry of entries) {
        if (entry.kind !== 'file' || !isCardFile(entry.name)) continue
        const body = await text(`docs/defects/${entry.name}`)
        if (typeof body === 'string') cards.push({ id: entry.name.replace(/\.md$/i, ''), text: body })
      }

      const key = seenKey(root)
      const stored = await $.store.get(key)
      const seen = Array.isArray(stored) ? stored.filter((tag): tag is string => typeof tag === 'string') : []
      const lang = detectLang(turn)

      const reply = await $.model.fork({ prompt: buildPrompt({ laws, cards, seen, lang }) })
      if (!reply.isAnswered) return done
      const note = noteToShow(reply.text, seen)
      if (note === null) return done

      await $.store.set(key, addSeen(seen, note.tag))
      shownCount += 1
      onScreen = { ...note, lang }
      $.ui.invalidate('ui.render')
    } catch {
      // A watcher that fails stays silent.
    }
    return done
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const shown = onScreen
    if (e.props.hasSurvey || shown === null) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const labels = LABELS[shown.lang]
    const dismiss = () => {
      onScreen = null
      $.ui.invalidate('ui.render')
    }
    const toDefects = async () => {
      await $.prompt.fill({ text: handoffText(shown, shown.lang), mode: 'replace' })
      dismiss()
    }

    return (
      <Box flexDirection="column">
        <Text>
          {labels.title}: {shown.note}
        </Text>
        {shown.explain !== '' && <Text dimColor>{shown.explain}</Text>}
        <Box>
          <Button key="to-defects" variant="primary" label={labels.toDefects} onPress={toDefects} />
          <Text> </Text>
          <Button key="close" role="dismiss" label={labels.close} onPress={dismiss} />
        </Box>
      </Box>
    )
  })
}
