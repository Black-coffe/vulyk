#!/usr/bin/env bash
# UserPromptSubmit hook: hears the owner in every channel and tells the session to file his words in
# docs/defects/ (contract: docs/specs/rules-tree/plan.md `## Contracts`, Capture; cards are read by
# .claude/hooks/defects_lib.py). One line per finding:
#   - the explicit phrase «внеси в запрет / правило / разрешение» (RU/UK/EN), typed or pasted ->
#     write the never / how-to / allowed card now, verbatim;
#   - typed text that looks like a correction (a timecode, a correction word, a card's `keys:`) ->
#     file the quote now and report one line with «отмени»;
#   - a correction word or card key only inside <pasted_content> -> ask the owner whether these are
#     his words first. A paste that starts with $VULYK_DICTATION_TAG (when set) counts as typed.
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
# stdin is read once so a non-working interpreter (the Windows Store `python3` alias exits 9009
# without running anything) falls through to the next one; 0 or 1 means python itself ran.
# `--lexicon` prints the correction lexicon as portable ERE lines instead (for `litopys corrections
# --lexicon`, read by /vulyk-evolve) and reads no stdin: one word list, two consumers.
if [ "${1:-}" = "--lexicon" ]; then IN=""; else IN="$(cat)"; fi
for PY in python3 python; do
  command -v "$PY" >/dev/null 2>&1 || continue
  printf '%s' "$IN" | "$PY" -S -c 'import sys;sys.argv=sys.argv[1:];p=sys.argv[0];s=open(p,encoding="utf-8").read();exec(compile(s.split("\n#<py>\n",1)[1].split("\nPYTHON\n",1)[0],p,"exec"))' \
    "${BASH_SOURCE[0]}" "$@" 2>/dev/null
  case $? in 0|1) exit 0 ;; esac
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
PASTE = re.compile(r'<pasted_content\b[^>]*?(?:/>|>(.*?)(?:</pasted_content\b[^>]*>|\Z))', re.S | re.I)
# A side-agent note: from its preamble (at a line start or right after a tag) to a blank line or a closing tag,
# then the blank and `>` lines that follow it (the relayed note's quoted body, evolve 2026-10-19).
SIDE_NOTE = re.compile(r'(?:^|(?<=>))[ \t]*here is a note offered by a side agent\b.*?(?=\n[ \t]*\n|</|\Z)'
                       r'(?:\n[ \t]*(?:>[^\n]*)?(?=\n|\Z))*',
                       re.S | re.I | re.M)
# Stems match at a word start ("переделай" also takes "переделайте"); whole phrases need both edges.
STEMS = ['опять', 'снова', 'я же говорил', 'я же казав', 'знову', 'переделай', 'переделать', 'обрезал']
WORDS = ['не так', 'again', 'i said', 'i told you', 'why did you', 'not what i asked']
LEXICON = re.compile(r'(?<!\w)(?:' + '|'.join(map(re.escape, STEMS)) + r')'
                     r'|(?<!\w)(?:' + '|'.join(map(re.escape, WORDS)) + r')(?!\w)')
TIMECODE = re.compile(r'\b\d{1,2}:\d{2}\b')
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
    tc = TIMECODE.search(text) if timecode else None
    if tc:
        why.append('timecode ' + tc.group(0))
    lx = LEXICON.search(low)
    if lx:
        why.append('word "' + lx.group(0) + '"')
    for c in cards:
        if c.status == 'revoked':
            continue
        if any(k.strip().lower() and k.strip().lower() in low for k in c.keys):
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
    branches = phrase_branches(text)                     # pastes and fences included
    if branches:
        return phrase_lines(branches)
    tag = os.environ.get('VULYK_DICTATION_TAG', '')
    pastes = []

    def paste(m):
        inner = (m.group(1) or '').lstrip()
        if tag and inner.startswith(tag):
            return ' ' + inner[len(tag):] + ' '
        pastes.append(inner)
        return ' '
    typed = strip(PASTE.sub(paste, text), FENCES)
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
            if label in rest:
                rest = rest.replace(label, ' ')
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
