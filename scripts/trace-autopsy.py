"""VULYK trace autopsy: the repo lines of a stack trace in a brief, with the last commits per line (stdlib only).

Usage: bash scripts/trace-autopsy.sh <brief.md>

Reads only the brief's `> ` lines (the verbatim request). Frames: Python `File "p", line N`, Node `at f (p:L:C)` /
`at p:L:C`, bash `p: line N:`, plain `p.ext:N`; the first form that matches a line wins. A frame resolves when a
tracked file's whole path is the tail of the frame path (`/app/src/a.py`, `C:\\build\\src\\a.py` -> `src/a.py`),
or one tracked file alone shares its last two parts or more (`/app/app/a.py` -> `src/app/a.py`); a basename-only
match is `ambiguous`, a frame with no tracked name is `outside the repo`. Built files (`dist/`) are not mapped back.
Innermost frame first (a Python `most recent call last` trace is reversed). Writes `autopsy.md` beside the brief,
at most 15 lines: HEAD, up to 3 frames with the code line at HEAD and `git log -n 3 -L <n>,<n>:<path>` under
«last touched», the marks, then `... N more repo frames`. No repo frame: one stdout line, no file.
Trace text is data: git runs from an argv list, gets only `git ls-files` paths and digit-only line numbers,
and a git failure becomes a mark. Exit: 0 done, 2 usage or not inside a git repo.
"""
import os
import re
import subprocess
import sys

MAX_LINES = 15
MAX_FRAMES = 3
MAX_LINE_NO = 9999999
CODE_WIDTH = 100
USAGE = 'usage: bash scripts/trace-autopsy.sh <brief.md>'

FRAME_FORMS = (
    re.compile(r'File "([^"]+)", line (\d+)'),
    re.compile(r'\bat\s+(?:[^()]*\()?(\S+?):(\d+):\d+\)?\s*$'),
    re.compile(r'^\s*(\S+): line (\d+):'),
)
PLAIN = re.compile(r'((?:[A-Za-z]:)?[\w./\\-]*\.\w+):(\d+)')


def native(p):
    if os.name == 'nt' and re.match(r'^/[A-Za-z]/', p):
        return p[1] + ':' + p[2:]
    return p


def git(root, *args):
    r = subprocess.run(['git', '-C', root] + list(args), capture_output=True)
    return r.returncode, r.stdout.decode('utf-8', 'replace')


def quoted_lines(brief):
    with open(brief, encoding='utf-8', errors='replace') as f:
        return [re.sub(r'^>\s?', '', l.rstrip('\r\n')) for l in f if l.startswith('>')]


def frames_of(lines):
    found = []
    for line in lines:
        for form in FRAME_FORMS:
            m = form.search(line)
            if m:
                found.append((m.group(1), m.group(2)))
                break
        else:
            found.extend(m.groups() for m in PLAIN.finditer(line))
    if any('most recent call last' in l for l in lines):
        found.reverse()
    return found


def resolve(raw, by_name):
    """-> (tracked path or None, basename candidates)."""
    p = re.sub(r'^file://', '', raw.replace('\\', '/'))
    parts = [c for c in re.sub(r'^[A-Za-z]:/', '/', p).split('/') if c not in ('', '.', '..')]
    if not parts:
        return None, []
    cands = by_name.get(parts[-1], [])
    full = [t for t in cands if parts[-len(t.split('/')):] == t.split('/')]
    if len(full) == 1:
        return full[0], []
    if full:
        return None, full
    # A build that drops a folder (`/app/app/core.py` for `src/app/core.py`): a unique tail of two parts or more.
    tail = {t: common_tail(parts, t.split('/')) for t in cands}
    best = max(tail.values(), default=0)
    top = [t for t in cands if tail[t] == best]
    if best >= 2 and len(top) == 1:
        return top[0], []
    return None, cands


def common_tail(a, b):
    k = 0
    while k < min(len(a), len(b)) and a[-1 - k] == b[-1 - k]:
        k += 1
    return k


def main():
    argv = sys.argv[1:]
    if argv in (['-h'], ['--help']):
        sys.stdout.write(__doc__.split('\n', 1)[1].lstrip('\n'))
        sys.exit(0)
    if len(argv) != 1 or argv[0].startswith('-'):
        sys.stderr.write(USAGE + '\n')
        sys.exit(2)
    brief = os.path.abspath(native(argv[0]))
    if not os.path.isfile(brief):
        sys.stderr.write('trace-autopsy: no such brief: %s\n' % argv[0])
        sys.exit(2)
    rc, top = git(os.path.dirname(brief), 'rev-parse', '--show-toplevel')
    if rc != 0:
        sys.stderr.write('trace-autopsy: %s is not inside a git repo\n' % argv[0])
        sys.exit(2)
    root = top.strip()
    _, listing = git(root, 'ls-files', '-z')
    by_name = {}
    for t in filter(None, listing.split('\0')):
        by_name.setdefault(t.rsplit('/', 1)[-1], []).append(t)

    raw = frames_of(quoted_lines(brief))
    resolved, outside, ambiguous, past_end, seen = [], [], [], [], set()
    for path, num in raw:
        n = int(num)
        hit, cands = resolve(path, by_name)
        if hit is None:
            (ambiguous if cands else outside).append((path, n, cands))
        elif not 1 <= n <= MAX_LINE_NO:
            past_end.append('%s:%d (no such line)' % (hit, n))
        elif (hit, n) not in seen:
            seen.add((hit, n))
            resolved.append((hit, n))
    if not resolved:
        hint = ''
        if ambiguous:
            p, n, c = ambiguous[0]
            hint = '; ambiguous: %d (first %s:%d -> %s)' % (len(ambiguous), p, n, ', '.join(c[:2]))
        print('trace-autopsy: no repo frame (%d frames seen%s)' % (len(raw), hint))
        sys.exit(0)

    _, head = git(root, 'log', '-1', '--date=short', '--format=%h %ad')
    blocks = []
    for path, n in resolved:
        rc, text = git(root, 'show', 'HEAD:' + path)
        lines = text.splitlines()
        if rc != 0 or n > len(lines):
            past_end.append('%s:%d (%s)' % (path, n, 'not at HEAD' if rc else 'file has %d lines' % len(lines)))
            continue
        code = lines[n - 1].strip()
        block = ['%s:%d  %s' % (path, n, code[:CODE_WIDTH])]
        rc, log = git(root, 'log', '-n', '3', '-s', '--date=short', '--format=%h %ad %an - %s',
                      '-L%d,%d:%s' % (n, n, path), 'HEAD')
        block += ['  last touched: ' + c for c in log.splitlines() if c.strip()][:3] if rc == 0 else \
            ['  git log -L failed: exit %d' % rc]
        blocks.append(block)

    marks = []
    if outside:
        p, n, _ = outside[0]
        marks.append('outside the repo: %d (first %s:%d)' % (len(outside), p, n))
    if ambiguous:
        p, n, c = ambiguous[0]
        marks.append('ambiguous: %d (first %s:%d -> %s)' % (len(ambiguous), p, n, ', '.join(c[:2])))
    if past_end:
        marks.append('past end: ' + '; '.join(past_end[:2]))
    header = ['# Trace autopsy - HEAD %s: the last commits that touched each line, a lead, not a verdict'
              % head.strip()]
    shown = blocks[:MAX_FRAMES]
    while len(shown) > 1 and len(header) + sum(map(len, shown)) + len(marks) + 1 > MAX_LINES:
        shown.pop()
    out = header + [l for b in shown for l in b] + marks
    if len(blocks) > len(shown):
        out.append('... %d more repo frames' % (len(blocks) - len(shown)))
    text = '\n'.join(out) + '\n'
    with open(os.path.join(os.path.dirname(brief), 'autopsy.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    sys.stdout.write(text)


if __name__ == '__main__':
    main()
