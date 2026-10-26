"""VULYK symbol map: the repo paths linked to a file that lie outside a story's scope (stdlib only).

Usage: bash scripts/symbol-map.sh [--story <story.md>] [--scope <path>]... <file>...

For each input prints a block `## <path>` with the sections tests, importers, imported, guard tests,
path mentions (an empty one omitted). Every line is `exact` (a Python `ast` import or a bash
`source`/`.` resolved to the file) or `textual` (the stem as a whole word, the path as a substring).
The scope set (inputs, every --scope, the `## Files` lines of --story, globs by fnmatch) never appears.
Python and bash get importers/imported; any other file gets tests, guard tests and path mentions only.
The whole stdout stays at or under 1536 bytes, cut with one final `... N more` line.
Exit: 0 done, 1 an input is missing (every input is still reported), 2 usage or not inside a git repo.
The script reports; it blocks nothing.
"""
import ast
import fnmatch
import os
import posixpath
import re
import subprocess
import sys

CAP_BYTES = 1536
SECTION_CAP = 5
MAX_FILE = 1024 * 1024
GUARD_MARKERS = ('os.walk', 'rglob', 'glob(', 'git ls-files', 'listdir', 'iterdir')
SHELL_EXT = ('.sh', '.bash')
USAGE = 'usage: bash scripts/symbol-map.sh [--story <story.md>] [--scope <path>]... <file>...'


def native(p):
    if os.name == 'nt' and re.match(r'^/[A-Za-z]/', p):
        return p[1] + ':' + p[2:]
    return p


def usage(code):
    out = sys.stdout if code == 0 else sys.stderr
    if code == 0:
        out.write(__doc__.split('\n', 1)[1].lstrip('\n'))
    else:
        out.write(USAGE + '\n')
    sys.exit(code)


def parse_args(argv):
    story, scope, files = None, [], []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('-h', '--help'):
            usage(0)
        elif a in ('--story', '--scope'):
            if i + 1 >= len(argv) or not argv[i + 1]:
                usage(2)
            if a == '--story':
                story = argv[i + 1]
            else:
                scope.append(argv[i + 1])
            i += 2
            continue
        elif a.startswith('-'):
            usage(2)
        else:
            files.append(a)
        i += 1
    if not files and not story:
        usage(2)
    return story, scope, files


def story_files(path):
    try:
        with open(native(path), encoding='utf-8') as f:
            lines = f.read().splitlines()
    except (OSError, UnicodeDecodeError):
        print('symbol-map: cannot read story %s' % path, file=sys.stderr)
        sys.exit(2)
    out, inside = [], False
    for line in lines:
        if line.startswith('## '):
            inside = line.strip() == '## Files'
            continue
        if inside and line.startswith('- '):
            item = line[2:].strip().split()[0].strip('`') if line[2:].strip() else ''
            if item:
                out.append(item)
    return out


def git_root(start):
    d = start if os.path.isdir(start) else os.getcwd()
    try:
        r = subprocess.run(['git', '-C', d, 'rev-parse', '--show-toplevel'],
                           capture_output=True, text=True)
    except OSError:
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    return os.path.realpath(native(r.stdout.strip()))


def tracked(root):
    r = subprocess.run(['git', '-C', root, 'ls-files', '-z'], capture_output=True)
    return sorted(p for p in r.stdout.decode('utf-8', 'replace').split('\0') if p)


def rel_to_root(root, arg):
    """A cwd-relative or absolute argument as a repo-relative posix path (root-relative fallback)."""
    a = native(arg)
    cand = os.path.realpath(os.path.abspath(a))
    if not os.path.exists(cand) and not os.path.isabs(a):
        alt = os.path.realpath(os.path.join(root, a))
        if os.path.exists(alt):
            cand = alt
    try:
        rel = os.path.relpath(cand, root)
    except ValueError:
        return a.replace('\\', '/')
    return rel.replace('\\', '/')


class Repo:
    def __init__(self, root, files):
        self.root = root
        self.files = files
        self.fileset = set(files)
        self._text = {}
        self.modules = {}  # dotted name -> path
        for p in files:
            if p.endswith('.py'):
                m = p[:-3].replace('/', '.')
                if m.endswith('.__init__'):
                    m = m[:-9]
                self.modules[m] = p
        self.basenames = {}
        for p in files:
            self.basenames.setdefault(posixpath.basename(p), []).append(p)
        self._edges = None

    def text(self, p):
        if p not in self._text:
            t = None
            full = os.path.join(self.root, p)
            try:
                if os.path.getsize(full) <= MAX_FILE:
                    with open(full, 'rb') as f:
                        t = f.read().decode('utf-8')
            except (OSError, UnicodeDecodeError):
                t = None
            self._text[p] = t
        return self._text[p]

    def is_shell(self, p):
        if p.endswith(SHELL_EXT):
            return True
        if '.' in posixpath.basename(p):
            return False
        t = self.text(p)
        if not t:
            return False
        first = t.split('\n', 1)[0]
        return first.startswith('#!') and re.search(r'\b(ba)?sh\b', first) is not None

    # --- python -------------------------------------------------------------------------------
    def resolve_module(self, name, importer):
        if not name:
            return None
        d = posixpath.dirname(importer)
        local = (d.replace('/', '.') + '.' + name) if d else name
        if local in self.modules:
            return self.modules[local]
        if name in self.modules:
            return self.modules[name]
        hits = [p for m, p in self.modules.items() if m.endswith('.' + name)]
        return hits[0] if len(hits) == 1 else None

    def py_edges(self, p):
        """The set of tracked files p imports, or None when p does not parse."""
        t = self.text(p)
        if t is None:
            return set()
        try:
            tree = ast.parse(t)
        except (SyntaxError, ValueError):
            return None
        out = set()
        pkg = posixpath.dirname(p)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    r = self.resolve_module(a.name, p)
                    if r:
                        out.add(r)
            elif isinstance(node, ast.ImportFrom):
                if node.level:
                    base = pkg
                    for _ in range(node.level - 1):
                        base = posixpath.dirname(base)
                    prefix = base.replace('/', '.')
                    mod = '.'.join(x for x in (prefix, node.module or '') if x)
                    resolve = lambda n: self.modules.get(n)
                else:
                    mod = node.module or ''
                    resolve = lambda n: self.resolve_module(n, p)
                hit_module = False
                for a in node.names:
                    sub = resolve((mod + '.' + a.name) if mod else a.name)
                    if sub:
                        out.add(sub)
                    else:
                        hit_module = True
                if hit_module and mod:
                    r = resolve(mod)
                    if r:
                        out.add(r)
        out.discard(p)
        return out

    # --- bash ---------------------------------------------------------------------------------
    SOURCE_RE = re.compile(r'(?:^|[;&|(]\s*|\bthen\s+|\bdo\s+|\belse\s+)(?:source|\.)\s+(?=\S)')

    @staticmethod
    def word_at(s, i):
        """The shell word starting at s[i]: quotes and $( ) kept whole, ends at blank, ; & | or ) at depth 0."""
        quote, depth, j = None, 0, i
        while j < len(s):
            c = s[j]
            if quote:
                if c == quote:
                    quote = None
            elif c in '"\'':
                quote = c
            elif c == '(':
                depth += 1
            elif c == ')':
                if depth == 0:
                    break
                depth -= 1
            elif depth == 0 and (c.isspace() or c in ';&|'):
                break
            j += 1
        return s[i:j]

    def sh_resolve(self, raw, importer):
        s = raw.replace('"', '').replace("'", '')
        if '$' in s:
            m = re.search(r'(?:\)|\}|\$\w+)/([^$]*)$', s)
            if not m:
                return None
            s = m.group(1)
        if not s or s.startswith('/'):
            return None
        d = posixpath.dirname(importer)
        for c in (posixpath.normpath(posixpath.join(d, s)), posixpath.normpath(s)):
            if c in self.fileset:
                return c
        same = self.basenames.get(posixpath.basename(s), [])
        return same[0] if len(same) == 1 else None

    def sh_edges(self, p):
        t = self.text(p)
        out = set()
        if not t:
            return out
        for line in t.splitlines():
            code = line.split('#', 1)[0] if line.lstrip().startswith('#') else line
            for m in self.SOURCE_RE.finditer(code):
                r = self.sh_resolve(self.word_at(code, m.end()), p)
                if r:
                    out.add(r)
        out.discard(p)
        return out

    def edges(self):
        """path -> (set of imported tracked files, parsed?) for every Python and bash file."""
        if self._edges is None:
            self._edges = {}
            for p in self.files:
                if p.endswith('.py'):
                    e = self.py_edges(p)
                    self._edges[p] = (e or set(), e is not None)
                elif self.is_shell(p):
                    self._edges[p] = (self.sh_edges(p), True)
        return self._edges


def is_test(p):
    parts = p.split('/')
    if 'tests' in parts[:-1] or 'test' in parts[:-1]:
        return True
    b = parts[-1]
    return (fnmatch.fnmatch(b, 'test_*') or fnmatch.fnmatch(b, '*_test.*')
            or fnmatch.fnmatch(b, '*.test.*') or fnmatch.fnmatch(b, '*.spec.*'))


def in_scope(p, scope):
    for s in scope:
        if p == s or (s.endswith('/') and p.startswith(s)):
            return True
        if any(c in s for c in '*?[') and fnmatch.fnmatch(p, s):
            return True
    return False


def stem_of(p):
    b = posixpath.basename(p)
    if b == '__init__.py':
        return posixpath.basename(posixpath.dirname(p)) or None
    s = b.split('.')[0]
    return s or None


def line(label, path):
    return '  %-7s  %s' % (label, path)


def block(repo, p, scope):
    out = ['## ' + p]
    if p not in repo.fileset and not os.path.isfile(os.path.join(repo.root, p)):
        out.append('  ! missing')
        return out, True
    edges = repo.edges()
    lang = 'py' if p.endswith('.py') else ('sh' if repo.is_shell(p) else None)
    if lang is None:
        ext = posixpath.splitext(p)[1] or posixpath.basename(p)
        out.append('  ! imports not parsed for %s: search callers yourself' % ext)
    elif lang == 'py' and p in edges and not edges[p][1]:
        out.append('  ! unparsed')
    seen = set()

    def ok(q):
        return q != p and q not in seen and not in_scope(q, scope)

    stem = stem_of(p)
    word = re.compile(r'(?<![\w])' + re.escape(stem) + r'(?![\w])') if stem else None
    sections = []

    exact_imp = {}
    if lang:
        for q, (e, _) in edges.items():
            if p in e:
                exact_imp[q] = ''
        if lang == 'py':
            for init in [q for q in exact_imp if q.endswith('__init__.py')]:
                for q, (e, _) in edges.items():
                    if init in e and q not in exact_imp and q != p:
                        exact_imp[q] = ' (via %s)' % init

    def textual_hits(cands):
        hits = []
        for q in cands:
            if not ok(q) or q in exact_imp:
                continue
            t = repo.text(q)
            if t and word and word.search(t):
                hits.append(q)
        return hits

    # tests
    rows = [line('exact', q + v) for q, v in sorted(exact_imp.items()) if is_test(q) and ok(q)]
    seen.update(q for q in exact_imp if is_test(q))
    tt = textual_hits([q for q in repo.files if is_test(q)])
    rows += capped([line('textual', q) for q in tt])
    seen.update(tt)
    sections.append(('tests', rows))

    # importers
    if lang:
        rows = [line('exact', q + v) for q, v in sorted(exact_imp.items()) if not is_test(q) and ok(q)]
        seen.update(exact_imp)
        same = [q for q in repo.files if not is_test(q) and q in edges
                and (q.endswith('.py') if lang == 'py' else not q.endswith('.py'))]
        ti = textual_hits(same)
        rows += capped([line('textual', q) for q in ti])
        seen.update(ti)
        sections.append(('importers', rows))
        imp = sorted(q for q in edges.get(p, (set(), True))[0] if ok(q))
        seen.update(imp)
        sections.append(('imported', [line('exact', q) for q in imp]))

    # guard tests
    gt = []
    for q in repo.files:
        if is_test(q) and ok(q):
            t = repo.text(q)
            if t and any(m in t for m in GUARD_MARKERS):
                gt.append(q)
    seen.update(gt)
    sections.append(('guard tests', capped([line('textual', q) for q in gt])))

    # path mentions
    pm = []
    for q in repo.files:
        if ok(q):
            t = repo.text(q)
            if t and p in t:
                pm.append(q)
    sections.append(('path mentions', capped([line('textual', q) for q in pm])))

    printed = False
    for name, rows in sections:
        if rows:
            out.append(name + ':')
            out.extend(rows)
            printed = True
    if not printed:
        out.append('  (no links outside scope)')
    return out, False


def capped(rows):
    if len(rows) <= SECTION_CAP:
        return rows
    return rows[:SECTION_CAP] + ['    ... %d more' % (len(rows) - SECTION_CAP)]


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    story, scope_args, files = parse_args(sys.argv[1:])
    listed = story_files(story) if story else []
    if files:
        start = os.path.dirname(os.path.abspath(native(files[0])))
    else:
        start = os.path.dirname(os.path.abspath(native(story)))
    root = git_root(start)
    if not root:
        print('symbol-map: not inside a git repository: %s' % start, file=sys.stderr)
        sys.exit(2)
    inputs = [rel_to_root(root, f) for f in files]
    if not files:
        inputs = [x for x in listed if not any(c in x for c in '*?[') and not x.endswith('/')]
        if not inputs:
            print('symbol-map: no file in the story ## Files to map', file=sys.stderr)
            sys.exit(2)
    scope = set(inputs) | {rel_to_root(root, s) for s in scope_args} | set(listed)
    if story:
        scope.add(rel_to_root(root, story))
    repo = Repo(root, tracked(root))

    lines, blocks_of, missing = [], [], False
    for i, p in enumerate(inputs):
        b, miss = block(repo, p, scope)
        missing = missing or miss
        if i:
            lines.append('')
            blocks_of.append(i)
        lines.extend(b)
        blocks_of.extend([i] * len(b))

    total = sum(len(x.encode('utf-8')) + 1 for x in lines)
    if total > CAP_BYTES:
        kept, size = 0, 0
        while kept < len(lines):
            need = len(lines[kept].encode('utf-8')) + 1
            dropped = len([x for x in lines[kept + 1:] if x])
            hidden = len(set(blocks_of[kept + 1:]) - set(blocks_of[:kept + 1]))
            tail = '... %d more' % dropped + (' (%d inputs not shown)' % hidden if hidden else '')
            if size + need + len(tail.encode('utf-8')) + 1 > CAP_BYTES:
                break
            size += need
            kept += 1
        dropped = len([x for x in lines[kept:] if x])
        hidden = len(set(blocks_of[kept:]) - set(blocks_of[:kept]))
        lines = lines[:kept]
        while lines and not lines[-1]:
            lines.pop()
        lines.append('... %d more' % dropped + (' (%d inputs not shown)' % hidden if hidden else ''))
    sys.stdout.write('\n'.join(lines) + '\n')
    sys.exit(1 if missing else 0)


if __name__ == '__main__':
    main()
