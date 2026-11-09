#!/usr/bin/env bash
# UserPromptSubmit hook: hears the owner in every channel and tells the session to file his words in
# docs/defects/ (contract: docs/specs/rules-tree/plan.md `## Contracts`, Capture; cards are read by
# .claude/hooks/defects_lib.py). One line per finding:
#   - the explicit phrase «внеси в запрет / правило / разрешение» (RU/UK/EN), typed ->
#     write the never / how-to / allowed card now, verbatim; found only in a paste, quote or fence -> ask first;
#   - typed text that looks like a correction (a timecode by a media cue or a correction word, a correction
#     word, a card's `keys:` at a word start) ->
#     file the quote now and report one line with «отмени»;
#   - a correction word or card key only inside <pasted_content> -> ask the owner whether these are
#     his words first. A paste that starts with $VULYK_DICTATION_TAG (when set) counts as typed.
#   - the same in a quote inside typed text («…», “…”, „…“, "…" on one line, `>` lines): someone else's words
#     until the owner says so, so the ask, unless a correction word or key also stands outside the quote.
# A side-agent note ("Here is a note offered by a side agent", to the end of its paragraph or tag, then its
# quoted `>` lines) is cut before every pass: it is model text, never the owner's. <task-notification>, <system-reminder>
# and <cross-session-message> blocks are cut too; ``` / ~~~ fences are cut from the correction passes.
#
# `defect-intake.sh answer` (PostToolUse, matcher AskUserQuestion): an answer part equal to an option
# label prints `[VULYK] decision: «<label>» on «<question>»` (a decision, never a quote); the free text
# left over runs through the phrase and the typed-correction passes.
#
# Never blocks: no python, no docs/defects/, bad JSON or any error -> silent exit 0.
# The Python half lives below the `exit 0`, inside a no-op heredoc; bash never runs it, python reads
# it back out of this file (one interpreter start, stdin passes straight through).
# stdin is read once so a non-working interpreter falls through to the next one: a preset $VULYK_PY
# (as scripts/lib.sh trusts it), then python3, python, py. Only exit 0 means the Python half ran (it
# always ends in sys.exit(0)); its output is held until then, so the Windows Store `python3` alias
# (9009), a Python 2 that cannot read this file (1) or a broken install prints nothing.
# `--lexicon` prints the correction lexicon as portable ERE lines instead (for `litopys corrections
# --lexicon`, read by /vulyk-evolve) and reads no stdin: one word list, two consumers.
if [ "${1:-}" = "--lexicon" ]; then IN=""; else IN="$(cat)"; fi
for PY in ${VULYK_PY:+"$VULYK_PY"} python3 python py; do
  command -v "$PY" >/dev/null 2>&1 || continue
  # the trailing `.` keeps the output's last newline (the --lexicon list) through $(...)
  OUT="$(printf '%s' "$IN" | "$PY" -S -c 'import sys;sys.argv=sys.argv[1:];p=sys.argv[0];s=open(p,encoding="utf-8").read();exec(compile(s.split("\n#<py>\n",1)[1].split("\nPYTHON\n",1)[0],p,"exec"))' \
    "${BASH_SOURCE[0]}" "$@" 2>/dev/null && printf .)" || continue
  printf '%s' "${OUT%.}"
  exit 0
done
exit 0

: <<'PYTHON'
#<py>
import json, os, re, sys

HARNESS = [
    r'<task-notification\b[^>]*>.*?(?:</task-notification\s*>|\Z)',
    r'<system-reminder\b[^>]*>.*?(?:</system-reminder\s*>|\Z)',
    r'<cross-session-message\b[^>]*/>',
    r'<cross-session-message\b[^>]*>.*?(?:</cross-session-message\b[^>]*>|\Z)',
]
FENCES = [r'```.*?(?:```|\Z)', r'~~~.*?(?:~~~|\Z)']
# A quote inside typed text (uncommitted-work-guard-03): «…», “…”, „…“, "…" on one line, and `>` lines. The
# words in it are someone else's until the owner says so: they go to the paste pass, never the typed one.
QUOTES = re.compile(r'«[^«»]*»|“[^“”]*”|„[^„“”]*[“”]|"[^"\n]*"|^[ \t]*>[^\n]*', re.M)
PASTE = re.compile(r'<pasted_content\b[^>]*?(?:/>|>(.*?)(?:</pasted_content\b[^>]*>|\Z))', re.S | re.I)
# A side-agent note: from its preamble (at a line start or right after a tag) to a blank line or a closing tag,
# then the blank and `>` lines that follow it (the relayed note's quoted body, evolve 2026-10-19).
SIDE_NOTE = re.compile(r'(?:^|(?<=>))[ \t]*here is a note offered by a side agent\b.*?(?=\n[ \t]*\n|</|\Z)'
                       r'(?:\n[ \t]*(?:>[^\n]*)?(?=\n|\Z))*',
                       re.S | re.I | re.M)
# Stems match at a word start ("переделай" also takes "переделайте"); whole phrases need both edges.
# «снова» and "again" are not here: a report says "ran it again" with no complaint in it (P10-08).
STEMS = ['опять', 'я же говорил', 'я же казав', 'знову', 'переделай', 'переделать', 'обрезал']
WORDS = ['не так', 'i said', 'i told you', 'why did you', 'not what i asked']
LEXICON = re.compile(r'(?<!\w)(?:' + '|'.join(map(re.escape, STEMS)) + r')'
                     r'|(?<!\w)(?:' + '|'.join(map(re.escape, WORDS)) + r')(?!\w)')
# A media timecode (m:ss, mm:ss, h:mm:ss). Not a clock (after a date; before am/pm/UTC/GMT/Z or an offset),
# a line:col (`x.sh:12:34`) or an offset itself (after `:`, `+`, `-` or a word character): those fired on
# every report (P10-08).
TIMECODE = re.compile(r'(?<![\w:+-])(?<!\d{4}-\d{2}-\d{2}T)(?<!\d{4}-\d{2}-\d{2} )'
                      r'\d{1,2}:[0-5]\d(?::[0-5]\d)?(?:[.,]\d+)?'
                      r'(?![\w:]|\s*(?:[ap]\.?m\b|utc\b|gmt\b|[+-]\d{2}:?\d{2}\b))', re.I)
# A bare clock time («at 14:32 the build ran») is no correction: a timecode counts only with a media cue or a
# correction word within NEAR characters of it (mass-audit-fixes-03).
MEDIA = re.compile(r'(?<!\w)(?:video|видео|відео|ролик|кадр|frame|сек|second|voice|голос|audio|аудио|аудіо'
                   r'|звук|scene|сцен|clip|клип|кліп|track|трек|subtitle|субтитр|timecode|таймкод|sec(?!\w))', re.I)
NEAR = 48
# The explicit phrase (RU, UK, EN); the last group names the branch. RU/UK allow up to three words
# between the verb and the preposition («внеси это / вот это в запрет»).
PHRASES = [
    re.compile(r'(?<!\w)(?:внеси|запиши|добавь)(?:\s+[^\s:]+){0,3}?\s+в\s+(запрет|правило|разрешение)', re.I),
    re.compile(r'(?<!\w)(?:внеси|запиши|додай)(?:\s+[^\s:]+){0,3}?\s+(?:в|до)\s+(заборон\S*|правил\S*|дозв[іо]л\S*)', re.I),
    re.compile(r'(?<!\w)(?:add|file|put)\s+(?:this\s+)?(?:to|as|in|under)\s+(?:a\s+|the\s+)?(never|rule|allowed)', re.I),
]
LIMIT = 600


def ere(s):
    return re.sub(r'([.^$*+?()\[\]{}|\\])', r'\\\1', s)


def print_lexicon():
    # grep -E has no lookbehind: a non-word character or a line edge stands in for (?<!\w) / (?!\w).
    edge_l, edge_r = '(^|[^[:alnum:]_])', '([^[:alnum:]_]|$)'
    out = [edge_l + ere(s) for s in STEMS] + [edge_l + ere(w) + edge_r for w in WORDS]
    sys.stdout.buffer.write(('\n'.join(out) + '\n').encode('utf-8'))


def branch_of(word):
    w = word.lower()
    if w.startswith(('запрет', 'заборон', 'never')):
        return 'never'
    if w.startswith(('разреш', 'дозв', 'allowed')):
        return 'allowed'
    return 'how-to'


def phrase_branches(text):
    found = []
    for rx in PHRASES:
        for m in rx.finditer(text):
            found.append((m.start(), branch_of(m.group(1))))
    out = []
    for _, b in sorted(found):
        if b not in out:
            out.append(b)
    return out


def strip(text, pats):
    for pat in pats:
        text = re.sub(pat, ' ', text, flags=re.S | re.I)
    return text


def triggers(text, cards, timecode=True):
    low = text.lower()
    why, refs = [], []
    tc = None
    for m in (TIMECODE.finditer(text) if timecode else ()):
        near = text[max(0, m.start() - NEAR):m.end() + NEAR]
        if MEDIA.search(near) or LEXICON.search(near.lower()):
            tc = m
            break
    if tc:
        why.append('timecode ' + tc.group(0))
    lx = LEXICON.search(low)
    if lx:
        why.append('word "' + lx.group(0) + '"')
    for c in cards:
        if c.status == 'revoked':
            continue
        # A key matches at a word start, as a stem does: "cut" takes "cutting", never "execute" (P10-08).
        if any(k.strip() and re.search(r'(?<!\w)' + re.escape(k.strip().lower()), low) for k in c.keys):
            refs.append(c.ref)
    if refs:
        why.append('card keys')
    return why, refs


def clip(s, n):
    s = ' '.join(s.split())
    return s if len(s) <= n else s[:n - 1] + '…'


def phrase_lines(branches, words=''):
    tail = ' — owner\'s words: «' + clip(words, 200) + '»' if words else ''
    return ['[VULYK] owner asks to file a ' + b + ' card: write it now, verbatim, in'
            ' docs/defects/<area>/<id>.md (choose area and scope), then report one line: filed → <ref>' + tail
            for b in branches]


def typed_line(why, refs):
    return ('[VULYK] looks like a correction (' + ', '.join(why) + '): file the quote now in '
            + (', '.join(refs) if refs else 'a new card') + ' and report one line with «отмени»'
            ' (date · material · place — «words»; a class code can check gets a failing check:, Law 6)')


def phrase_ask_lines(branches):
    return ['[VULYK] a pasted or quoted text asks to file a ' + b + ' card: ask the owner in one line whether'
            ' these are their words before filing' for b in branches]


def paste_line(why):
    return ('[VULYK] a pasted text looks like a correction (' + ', '.join(why) + '): ask the owner in one'
            ' line whether these are their words before filing')


def emit(event, lines):
    if not lines:
        return
    msg = '\n'.join(lines)
    if len(msg) > LIMIT:
        msg = msg[:LIMIT - 1] + '…'
    sys.stdout.write(json.dumps({'hookSpecificOutput': {
        'hookEventName': event, 'additionalContext': msg}}))


def on_prompt(data, cards):
    prompt = data.get('prompt')
    if not isinstance(prompt, str) or not prompt.strip():
        return []
    text = strip(SIDE_NOTE.sub(' ', prompt), HARNESS)
    tag = os.environ.get('VULYK_DICTATION_TAG', '')
    pastes = []

    def paste(m):
        inner = (m.group(1) or '').lstrip()
        if tag and inner.startswith(tag):
            return ' ' + inner[len(tag):] + ' '
        pastes.append(inner)
        return ' '
    typed = strip(PASTE.sub(paste, text), FENCES)

    def quote(m):
        pastes.append(m.group(0))
        return ' '
    typed = QUOTES.sub(quote, typed)
    branches = phrase_branches(typed)                    # the owner's typed words (and a dictation paste)
    if branches:
        return phrase_lines(branches)
    branches = phrase_branches(text)                     # only in a paste, a quote or a fence: ask first
    if branches:
        return phrase_ask_lines(branches)
    why, refs = triggers(typed, cards)
    if why:
        return [typed_line(why, refs)]
    # A paste is often a log: its timecodes are not a correction, its words and card keys may be.
    why, _ = triggers(strip('\n'.join(pastes), FENCES), cards, timecode=False)
    return [paste_line(why)] if why else []


def on_answer(data, cards):
    ti, tr = data.get('tool_input'), data.get('tool_response')
    answers = tr.get('answers') if isinstance(tr, dict) else None
    if not isinstance(answers, dict) or not answers:
        return []
    qs = ti.get('questions') if isinstance(ti, dict) else None
    qs = [q for q in (qs or []) if isinstance(q, dict)]

    def labels(q):
        return [o.get('label') for o in (q.get('options') or [])
                if isinstance(o, dict) and isinstance(o.get('label'), str) and o.get('label').strip()]
    every = [l for q in qs for l in labels(q)]
    lines, free = [], []
    for question, answer in answers.items():
        if isinstance(answer, list):
            answer = ', '.join(str(a) for a in answer)
        if not isinstance(answer, str) or not answer.strip():
            continue
        q = next((q for q in qs if q.get('question') == question), None)
        rest = answer
        for label in sorted(labels(q) if q else every, key=len, reverse=True):
            # A whole comma-separated part only (the answer joins chosen labels and free text with ", "):
            # "Blue" in "not Blue" or "Reddish" is no choice the owner made (P10-09).
            part = re.compile(r'(?:^|(?<=,))[ \t]*' + re.escape(label) + r'[ \t]*(?=,|\Z)')
            if part.search(rest):
                rest = part.sub(' ', rest)
                lines.append('[VULYK] decision: «' + clip(label, 120) + '» on «' + clip(str(question), 160) + '»')
        rest = SIDE_NOTE.sub(' ', rest).strip(' \t\r\n,;"\'«»“”')
        if rest:
            free.append(rest)
    words = '\n'.join(free)
    if words:
        branches = phrase_branches(words)
        if branches:
            lines += phrase_lines(branches, words)
        else:
            why, refs = triggers(words, cards)
            if why:
                lines.append(typed_line(why, refs))
    return lines


def main():
    if sys.argv[1:2] == ['--lexicon']:
        print_lexicon()
        return
    mode = 'answer' if sys.argv[1:2] == ['answer'] else 'prompt'
    raw = sys.stdin.buffer.read().decode('utf-8', 'replace')
    data = json.loads(raw)
    if not isinstance(data, dict):
        return
    sys.path.insert(0, os.path.dirname(os.path.abspath(sys.argv[0])))
    import defects_lib
    root = defects_lib.fixpath(os.environ.get('CLAUDE_PROJECT_DIR') or data.get('cwd') or os.getcwd())
    d = os.path.join(root, 'docs', 'defects')
    if not os.path.isdir(d):
        return
    cards = defects_lib.load_cards(d)
    if mode == 'answer':
        emit('PostToolUse', on_answer(data, cards))
    else:
        emit('UserPromptSubmit', on_prompt(data, cards))


try:
    main()
except Exception:
    pass
sys.exit(0)
PYTHON
