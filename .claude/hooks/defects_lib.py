"""VULYK defect library parser - the one reader of docs/defects/ (format: docs/defects/README.md).

Cards are `<lib>/<id>.md` (area `general`, ref `<id>`) or `<lib>/<area>/<id>.md` (ref `<area>/<id>`),
one folder level. `fixtures/` is never a card folder; `README.md` and `INDEX.md` (any case) are never cards.

Importers: `sys.path.insert(0, <dir of this file>)`, then `import defects_lib`.
`python3 defects_lib.py <lib-dir>` prints one JSON object per card (for tests).
"""
import json, os, re, sys

NOT_CARDS = {'readme.md', 'index.md'}
QUOTE_HEADS = {'## owner quotes', '## цитаты владельца', '## цитати власника'}
SECTIONS = (  # branch -> heading aliases (en, ru, uk); first heading of a branch wins
    ('never', r'Never|Нельзя|Не можна'),
    ('allowed', r'Allowed|Можно|Можна'),
    ('howto', r'How-to|Как надо|Як треба'),
    ('revoked', r'Revoked|Отозвано|Відкликано'),
)
SECTION_RX = [(k, re.compile(r'^##[ \t]+(?:' + a + r')(?![\w-])', re.I)) for k, a in SECTIONS]
WILD = set('*?[]{}().|+^$\\')


def fixpath(p):
    # A Git Bash path (/e/Projects/x) handed to a native Windows python.
    if os.name == 'nt':
        m = re.match(r'^/([A-Za-z])(/.*)?$', p)
        if m:
            p = m.group(1) + ':' + (m.group(2) or '/')
    return p


def fm_scalar(v):
    v = re.sub(r'\s+#(\s.*)?$', '', v or '').strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in '"\'':
        v = v[1:-1]
    return v


def fm_list(v):
    # `[a, b, "c, d", 'e']` -> list; a bare scalar -> one item. In double quotes \\ and \" unescape.
    v = (v or '').strip()
    if not v.startswith('['):
        v = fm_scalar(v)
        return [v] if v else []
    items, i, n, cur = [], 1, len(v), ''
    while i < n:
        c = v[i]
        if c in '"\'' and not cur.strip():
            q, i, s = c, i + 1, ''
            while i < n and v[i] != q:
                if q == '"' and v[i] == '\\' and i + 1 < n and v[i + 1] in '\\"':
                    s += v[i + 1]
                    i += 2
                    continue
                s += v[i]
                i += 1
            items.append(s)
            i += 1
            while i < n and v[i] not in ',]':
                i += 1
            if i >= n or v[i] == ']':
                break
            i += 1
            cur = ''
            continue
        if c in ',]':
            items.append(cur.strip())
            cur = ''
            if c == ']':
                break
        else:
            cur += c
        i += 1
    items.append(cur.strip())
    return [x for x in items if x]


def card_files(d):
    """(area, path relative to d with `/`) of every card, sorted by path."""
    out = []
    for name in os.listdir(d):
        full = os.path.join(d, name)
        if os.path.isfile(full):
            if name.endswith('.md') and name.lower() not in NOT_CARDS:
                out.append(('general', name))
        elif os.path.isdir(full) and name != 'fixtures' and not name.startswith('.'):
            for sub in os.listdir(full):
                if sub.endswith('.md') and sub.lower() not in NOT_CARDS and os.path.isfile(os.path.join(full, sub)):
                    out.append((name, name + '/' + sub))
    return sorted(out, key=lambda x: x[1])


def parse_card(d, area, path):
    with open(os.path.join(d, path), encoding='utf-8', errors='replace', newline='') as fh:
        # Split on \n only: line numbers must match git blame's.
        lines = [l.rstrip('\r') for l in fh.read().lstrip('﻿').split('\n')]
    fm, fm_lines, body_from = {}, {}, 0
    if lines and lines[0].strip() == '---':
        end = next((i for i in range(1, len(lines)) if lines[i].strip() == '---'), None)
        if end is not None:
            body_from = end + 1
            for i in range(1, end):
                line = lines[i]
                if not line.strip() or line[:1].isspace() or line.startswith('#') or ':' not in line:
                    continue
                k, _, v = line.partition(':')
                fm[k.strip().lower()] = v.strip()
                fm_lines[k.strip().lower()] = i + 1
    sec = {k: [] for k, _ in SECTIONS}
    sec_lines = {k: [] for k, _ in SECTIONS}
    quotes, quote_lines = [], []
    seen, cur, in_quotes = set(), None, False
    for i in range(body_from, len(lines)):
        line = lines[i]
        if re.match(r'^##[ \t]', line):
            in_quotes = line.startswith('## ') and line.strip().lower() in QUOTE_HEADS
            cur = None
            for k, rx in SECTION_RX:
                if rx.match(line):
                    if k not in seen:
                        seen.add(k)
                        cur = k
                    break
            continue
        if in_quotes and re.match(r'^- \d{4}-\d{2}-\d{2} ·', line):
            quotes.append(line[2:].strip())
            quote_lines.append(i + 1)
        if cur:
            b = re.match(r'^[-*][ \t]+(.*\S)', line)
            if b:
                sec[cur].append(b.group(1))
                sec_lines[cur].append(i + 1)
            elif sec[cur] and line[:1].isspace() and line.strip():
                sec[cur][-1] += ' ' + line.strip()
    cid = os.path.basename(path)[:-3]
    exc = fm_scalar(fm.get('exception', ''))
    if exc.endswith('.md'):
        exc = exc[:-3]
    paths = fm_list(fm.get('paths', ''))
    c = {
        'ref': cid if area == 'general' else area + '/' + cid,
        'id': cid, 'area': area, 'path': path, 'fm': fm,
        'status': (fm_scalar(fm.get('status', '')) or 'text').lower(),
        'check': fm_scalar(fm.get('check', '')),
        'fixtures': fm_list(fm.get('fixtures', '')),
        'keys': fm_list(fm.get('keys', '')),
        'paths': paths,
        'passes': fm_list(fm.get('passes', '')),
        'exception': exc or None,
        'quotes': quotes,
        'never': sec['never'], 'allowed': sec['allowed'], 'howto': sec['howto'], 'revoked': sec['revoked'],
        'scopes': [list(parse_scope(e)) for e in paths],
        'allowed_dates': [allowed_date(x) for x in sec['allowed']],
        'fm_lines': fm_lines,
        'lines': dict(sec_lines, quotes=quote_lines),
    }
    return Card(c)


class Card:
    """A card: the fields of parse_card() as attributes; vars(card) is the dict."""
    def __init__(self, fields):
        self.__dict__.update(fields)


def load_cards(lib_dir):
    """Every card of the library, revoked included, sorted by path. Unreadable files are skipped."""
    cards = []
    for area, path in card_files(lib_dir):
        try:
            cards.append(parse_card(lib_dir, area, path))
        except OSError:
            continue
    return cards


def effective_status(card):
    """(status, reason) by today's rule: `revoked`; `block` needs a check: and >= 2 fixtures that exist
    (relative to the cwd = repo root); anything else is `text`, the reason says why when it is not plain text.
    Reasons: 'block without check', 'block without fixtures', "status '<s>' is not block|text|revoked"."""
    st = card.status
    if st == 'revoked':
        return 'revoked', ''
    if st == 'block':
        if not card.check:
            return 'text', 'block without check'
        if len([f for f in card.fixtures if os.path.isfile(f)]) < 2:
            return 'text', 'block without fixtures'
        return 'block', ''
    if st != 'text':
        return 'text', "status '%s' is not block|text|revoked" % st
    return 'text', ''


def parse_scope(entry):
    """`cmd:<regex>` -> ('cmd', regex); `tool:<regex>` -> ('tool', regex); anything else -> ('glob', entry)."""
    for kind in ('cmd', 'tool'):
        if entry.startswith(kind + ':'):
            return kind, entry[len(kind) + 1:]
    return 'glob', entry


def glob_rx(g):
    # fnmatch semantics (`*` crosses `/`), plus `**/` = any number of directories, zero included.
    out, i, n = '', 0, len(g)
    while i < n:
        if g.startswith('**/', i):
            out, i = out + '(?:.*/)?', i + 3
        elif g[i] == '*':
            while i < n and g[i] == '*':
                i += 1
            out += '.*'
        elif g[i] == '?':
            out, i = out + '.', i + 1
        elif g[i] == '[':
            j = g.find(']', i + 2)
            if j < 0:
                out, i = out + '\\[', i + 1
            else:
                body = g[i + 1:j]
                if body.startswith('!'):
                    body = '^' + body[1:]
                out, i = out + '[' + body.replace('\\', '\\\\') + ']', j + 1
        else:
            out, i = out + re.escape(g[i]), i + 1
    return re.compile(out + r'\Z', re.I if os.name == 'nt' else 0)


def scope_matches(entry, tool_name, file_path, command):
    """One `paths:` entry against an action. `file_path` is a repo-relative path or a list of them; a glob
    without `/` also matches the basename. `tool:` is a full match on tool_name, `cmd:` a search in command."""
    kind, val = parse_scope(entry)
    try:
        if kind == 'tool':
            return bool(tool_name) and re.fullmatch(val, tool_name) is not None
        if kind == 'cmd':
            return bool(command) and re.search(val, command) is not None
    except re.error:
        return False
    paths = [file_path] if isinstance(file_path, str) else list(file_path or [])
    rx = glob_rx(val)
    return any(p and (rx.match(p) or ('/' not in val and rx.match(p.rsplit('/', 1)[-1]))) for p in paths)


def specificity(entry):
    """Characters of the entry's value that are not wildcard or regex syntax: higher = narrower scope."""
    return sum(1 for ch in parse_scope(entry)[1] if ch not in WILD)


def allowed_date(line):
    """`YYYY-MM-DD · «words»` (bullet optional) -> 'YYYY-MM-DD'; an undated line -> None."""
    m = re.match(r'^\s*(?:[-*][ \t]+)?(\d{4}-\d{2}-\d{2})\s*·', line or '')
    return m.group(1) if m else None


if __name__ == '__main__':
    if len(sys.argv) != 2 or not os.path.isdir(fixpath(sys.argv[1])):
        sys.stderr.write('usage: python3 defects_lib.py <lib-dir>\n')
        sys.exit(2)
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    for c in load_cards(fixpath(sys.argv[1])):
        print(json.dumps(vars(c), ensure_ascii=False))
