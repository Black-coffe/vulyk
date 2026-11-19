"""VULYK symbol map: the repo paths linked to a file that lie outside a story's scope (stdlib only).

Usage: bash scripts/symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...
       bash scripts/symbol-map.sh --fill-tests <spec-dir>

For each input prints a block `## <path>` with the sections tests, importers, imported, guard tests,
path mentions (an empty one omitted). Every line is `exact` (a Python `ast` import, a bash
`source`/`.`, a bash-run `.py`, or a script run by `bash`/`sh`/`exec` - a literal path or a variable set to
one - resolved to the file; a .py's runners include who runs its bash wrapper, via named) or `textual` (the
stem as a whole word, the path as a substring). A story's sections are read outside fenced blocks only. Path mentions rank code, docs/adr, other docs, then the root CHANGELOG/CLAUDE/README.
The scope set (inputs, every --scope, the `## Files` lines of --story, globs by fnmatch) never appears,
nor does a path with a `fixtures` segment after a `tests`/`test` segment.
Python and bash get importers/imported; any other file gets tests, guard tests and path mentions only.
--exact: each section keeps its `exact` lines and folds the rest into `  textual  <N> not shown`.
A missing input's block comes first. The whole stdout stays at or under 1536 bytes, cut with one
final `... N more` line.
Exit: 0 done, 1 an input is missing (every input is still reported), 2 usage or not inside a git repo.
The script reports; it blocks nothing.
--fill-tests: each `status: todo` story of the spec that is not a repair story gets, appended to its
`## Files`, every test an `exact` hit links to one of its files (never a `textual` one), and, appended to its
`## Verification`, the first non-`round-only` `## Commands` cell with no placeholder that names a listed test
no line names yet; a cell with a placeholder prints `symbol-map: <story>: pick a row for <test> (<cell>)`.
Its listing is uncapped. Exit 0 every listed test has a row, 1 a pick line, 2 usage or not inside a git repo.
"""
# Speed on a bash input (post-037-tails, profiled with cProfile; warm OS file cache, one Windows box,
# median of 3 `time` runs). Before: `bash scripts/symbol-map.sh scripts/lib.sh` 1.55 s, a .py 0.34 s;
# direct `python scripts/symbol-map.py`: scripts/lib.sh 0.264 s, scripts/symbol-map.py 0.271 s.
# Fix: edges are parsed per kind on first need (a bash input parses no Python), comment lines skip
# the source regex. After, direct: scripts/lib.sh 0.170 s, scripts/symbol-map.py 0.233 s; through the
# wrapper: scripts/lib.sh 0.245 s, scripts/symbol-map.py 0.311 s. A cold first run (5.3 s) is file I/O.
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
USAGE = 'usage: bash scripts/symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...'


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
    story, scope, files, exact = None, [], [], False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('-h', '--help'):
            usage(0)
        elif a == '--exact':
            exact = True
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
    return story, scope, files, exact


def fence_mask(lines):
    """True for each line that is a fence line or inside a fence: the FENCE_AWK rule of cycle.sh, wave-check.sh,
    scope-check.sh and trace-check.sh (narrow-repair-1115-06). 3+ ` or ~ (any indent) open a fence, a ` one with
    no ` in its info string; only the same character, at least as long, with nothing after it, closes it."""
    out, fc, fn = [], '', 0
    for ln in lines:
        t = ln.lstrip(' \t')
        c, hit = t[:1], False
        if c in ('`', '~'):
            n = len(t) - len(t.lstrip(c))
            r = t[n:]
            if n >= 3:
                if fn:
                    if c == fc and n >= fn and not r.strip(' \t\r'):
                        fn, hit = 0, True
                elif not (c == '`' and '`' in r):
                    fc, fn, hit = c, n, True
        out.append(hit or fn > 0)
    return out


def story_files(path):
    try:
        with open(native(path), encoding='utf-8') as f:
            lines = f.read().splitlines()
    except (OSError, UnicodeDecodeError):
        print('symbol-map: cannot read story %s' % path, file=sys.stderr)
        sys.exit(2)
    out, inside = [], False
    for line, fenced in zip(lines, fence_mask(lines)):
        if fenced:
            continue
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
        self._detail = {}  # shell file -> [(line, files it sources or runs)]
        self._sourced_only = {}  # shell file -> files it sources and never runs

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

    RUNNER = re.compile(r'^(?:python3?|exec|\$\{?\w+\}?)$')
    SH_RUNNER = re.compile(r'^(?:bash|sh|exec)$')
    ASSIGN = re.compile(r'^\s*(?:export\s+|local\s+|readonly\s+)?([A-Za-z_]\w*)=(\S+)\s*$')
    VAR = re.compile(r'^\$\{?([A-Za-z_]\w*)\}?$')

    def sh_words(self, code):
        """(word, previous word) for each shell word of a line, quotes kept."""
        i, prev = 0, ''
        while i < len(code):
            if code[i].isspace() or code[i] in ';&|()':
                i += 1
                continue
            w = self.word_at(code, i)
            if not w:
                i += 1
                continue
            yield w, prev
            prev = w
            i += len(w)

    @staticmethod
    def subst_bodies(code):
        """(tails-1115-12) The body of each $( ) and backtick command substitution of a line that is not inside
        single quotes, nested ones too: a command run there (`out="$(bash scripts/x.sh)"`) is a direct call."""
        out, i, sq, dq = [], 0, False, False
        while i < len(code):
            c = code[i]
            if sq:
                if c == "'":
                    sq = False
            elif c == '\\':
                i += 1
            elif c == "'" and not dq:
                sq = True
            elif c == '"':
                dq = not dq
            elif c == '`':
                j = code.find('`', i + 1)
                if j < 0:
                    break
                out.append(code[i + 1:j])
                out.extend(Repo.subst_bodies(code[i + 1:j]))
                i = j
            elif code.startswith('$(', i):
                j, depth, q = i + 2, 1, None
                while j < len(code):
                    d = code[j]
                    if q:
                        if d == q:
                            q = None
                    elif d in '"\'':
                        q = d
                    elif d == '(':
                        depth += 1
                    elif d == ')':
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                out.append(code[i + 2:j])
                out.extend(Repo.subst_bodies(code[i + 2:j]))
                i = j
            i += 1
        return out

    def segments(self, line):
        """The line itself, then each command substitution body in it."""
        return [line] + (self.subst_bodies(line) if '$(' in line or '`' in line else [])

    FUNC_RE = re.compile(r'^(\s*)(?:function\s+)?([A-Za-z_][\w:-]*)\s*\(\)\s*\{')

    def sh_reach(self, via, p):
        """(tails-1115-12) (runs p at the top level?, the functions of via that run p, or call one that does):
        a file that only sources via calls p only through one of these."""
        top, owner, body, cur, indent = False, [], {}, None, ''
        detail = self._detail.get(via, [])
        for ln, targets in detail:
            if cur is None:
                m = self.FUNC_RE.match(ln)
                if m:
                    name = m.group(2)
                    body.setdefault(name, [])
                    if not re.search(r'[;\s]\}(?:\s|;|$)', ln[m.end():]):
                        cur, indent = name, m.group(1)
                    body[name].append((ln, targets))
                    continue
                if p in targets:
                    top = True
            else:
                body[cur].append((ln, targets))
                if re.match(re.escape(indent) + r'\}', ln):
                    cur = None
        reach = {f for f, lns in body.items() if any(p in tg for _, tg in lns)}
        grew = True
        while grew:
            grew = False
            for f, lns in body.items():
                if f not in reach and any(self.call_words(ln) & reach for ln, _ in lns):
                    reach.add(f)
                    grew = True
        return top, reach

    def call_words(self, code):
        """The unquoted shell words of a line and of its command substitutions."""
        return {w for seg in self.segments(code) for w, _ in self.sh_words(seg) if '"' not in w and "'" not in w}

    def calls_any(self, q, names):
        t = self.text(q)
        if not t or not names:
            return False
        return any(self.call_words(ln) & names for ln in t.splitlines() if not ln.lstrip().startswith('#'))

    def sh_edges(self, p):
        t = self.text(p)
        out = set()
        if not t:
            return out
        lines = [ln for ln in t.splitlines() if not ln.lstrip().startswith('#')]
        detail, sourced, ran = [], set(), set()
        # narrow-repair-1115-06: a variable set once to a script path (`SM="$SRC/scripts/symbol-map.sh"`) stands
        # for that path when a runner runs it (`bash "$SM"`, `"$PY" "$EL"`)
        paths = {}
        for line in lines:
            m = self.ASSIGN.match(line)
            if m and m.group(2).replace('"', '').replace("'", '').endswith(SHELL_EXT + ('.py',)):
                paths[m.group(1)] = m.group(2)

        def expand(w):
            v = self.VAR.match(w.replace('"', '').replace("'", ''))
            return paths.get(v.group(1), w) if v else w
        for line in lines:
            targets = set()
            if 'source' in line or '.' in line:
                for m in self.SOURCE_RE.finditer(line):
                    r = self.sh_resolve(self.word_at(line, m.end()), p)
                    if r:
                        sourced.add(r)
                        targets.add(r)
            if '.py' in line or '.sh' in line or '.bash' in line or (paths and '$' in line):
                # a bash-run python file: "$(dirname "$0")/x.py", "$DIR/x.py", or a literal path after a runner;
                # (narrow-repair-1115-06) a bash-run script: `bash <path>.sh`, `sh <path>`, `exec <path>`, as the
                # suites run a script they copied (`cp "$SRC"/scripts/x.sh scripts/` then `bash scripts/x.sh`);
                # (tails-1115-12) the same inside a command substitution: `out="$(bash scripts/x.sh)"`, backticks
                for seg in self.segments(line):
                    for w, prev in self.sh_words(seg):
                        w = expand(w)
                        s = w.replace('"', '').replace("'", '')
                        pv = prev.replace('"', '').replace("'", '')
                        if s.endswith('.py'):
                            if '$' not in s and not self.RUNNER.match(pv):
                                continue
                        elif not (s.endswith(SHELL_EXT) and self.SH_RUNNER.match(pv)):
                            continue
                        r = self.sh_resolve(w, p)
                        if r:
                            ran.add(r)
                            targets.add(r)
            detail.append((line, targets))
            out |= targets
        self._detail[p] = detail
        self._sourced_only[p] = sourced - ran
        out.discard(p)
        return out

    def edges(self, kinds=('py', 'sh')):
        """path -> (set of imported tracked files, parsed?) for every Python ('py') and bash ('sh') file
        of the kinds asked; each kind is parsed once per run, on first need."""
        if self._edges is None:
            self._edges, self._kinds = {}, set()
        for k in kinds:
            if k in self._kinds:
                continue
            self._kinds.add(k)
            for p in self.files:
                if k == 'py' and p.endswith('.py'):
                    e = self.py_edges(p)
                    self._edges[p] = (e or set(), e is not None)
                elif k == 'sh' and not p.endswith('.py') and self.is_shell(p):
                    self._edges[p] = (self.sh_edges(p), True)
        return self._edges


def is_test(p):
    parts = p.split('/')
    if 'tests' in parts[:-1] or 'test' in parts[:-1]:
        return True
    b = parts[-1]
    return (fnmatch.fnmatch(b, 'test_*') or fnmatch.fnmatch(b, '*_test.*')
            or fnmatch.fnmatch(b, '*.test.*') or fnmatch.fnmatch(b, '*.spec.*'))


def is_fixture(p):
    """A path with a `fixtures` segment after a `tests`/`test` segment: never listed."""
    seen_tests = False
    for part in p.split('/')[:-1]:
        if part in ('tests', 'test'):
            seen_tests = True
        elif part == 'fixtures' and seen_tests:
            return True
    return False


ROOT_DOCS = ('CHANGELOG.md', 'CLAUDE.md', 'README.md')


def mention_rank(p):
    """0 code/config/tests, 1 docs/adr, 2 other docs, 3 the root CHANGELOG/CLAUDE/README."""
    if p in ROOT_DOCS:
        return 3
    if not p.lower().endswith(('.md', '.rst', '.txt')):
        return 0
    return 1 if p.startswith('docs/adr/') else 2


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


def exact_importers(repo, edges, p, lang):
    """path -> '' or ' (via <__init__>)' for every file that imports, sources or runs p (an `exact` hit)."""
    exact_imp = {}
    if lang:
        for q, (e, _) in edges.items():
            if p in e:
                exact_imp[q] = ''
        if lang == 'py':
            # a re-exporting __init__, and (narrow-repair-1115-06) a bash wrapper that runs p: who imports or
            # runs the wrapper imports p, via the wrapper
            vias = [q for q in exact_imp if q.endswith('__init__.py') or not (q.endswith('.py') or is_test(q))]
            for via in vias:
                reach = None
                for q, (e, _) in edges.items():
                    if via in e and q not in exact_imp and q != p:
                        # (tails-1115-12) sourcing a wrapper is a call of p only when the wrapper runs p at its
                        # top level or q calls a function of it that runs p
                        if via in repo._sourced_only.get(q, ()):
                            if reach is None:
                                reach = repo.sh_reach(via, p)
                            if not reach[0] and not repo.calls_any(q, reach[1]):
                                continue
                        exact_imp[q] = ' (via %s)' % via
    return exact_imp


def block(repo, p, scope, exact=False):
    out = ['## ' + p]
    if p not in repo.fileset and not os.path.isfile(os.path.join(repo.root, p)):
        out.append('  ! missing')
        return out, True
    lang = 'py' if p.endswith('.py') else ('sh' if repo.is_shell(p) else None)
    edges = repo.edges({'py': ('py', 'sh'), 'sh': ('sh',), None: ()}[lang])
    if lang is None:
        ext = posixpath.splitext(p)[1] or posixpath.basename(p)
        out.append('  ! imports not parsed for %s: search callers yourself' % ext)
    elif lang == 'py' and p in edges and not edges[p][1]:
        out.append('  ! unparsed')
    seen = set()

    def ok(q):
        return q != p and q not in seen and not is_fixture(q) and not in_scope(q, scope)

    stem = stem_of(p)
    word = re.compile(r'(?<![\w])' + re.escape(stem) + r'(?![\w])') if stem else None
    sections = []

    exact_imp = exact_importers(repo, edges, p, lang)

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
    seen.update(tt)
    sections.append(('tests', rows, tt))

    # importers
    if lang:
        rows = [line('exact', q + v) for q, v in sorted(exact_imp.items()) if not is_test(q) and ok(q)]
        seen.update(exact_imp)
        same = [q for q in repo.files if not is_test(q) and q in edges
                and (q.endswith('.py') if lang == 'py' else not q.endswith('.py'))]
        ti = textual_hits(same)
        seen.update(ti)
        sections.append(('importers', rows, ti))
        imp = sorted(q for q in edges.get(p, (set(), True))[0] if ok(q))
        seen.update(imp)
        sections.append(('imported', [line('exact', q) for q in imp], []))

    # guard tests
    gt = []
    for q in repo.files:
        if is_test(q) and ok(q):
            t = repo.text(q)
            if t and any(m in t for m in GUARD_MARKERS):
                gt.append(q)
    seen.update(gt)
    sections.append(('guard tests', [], gt))

    # path mentions
    pm = []
    for q in repo.files:
        if ok(q):
            t = repo.text(q)
            if t and p in t:
                pm.append(q)
    pm.sort(key=lambda q: (mention_rank(q), q))
    sections.append(('path mentions', [], pm))

    printed = False
    for name, rows, textual in sections:
        if textual:
            if exact:
                rows = rows + [line('textual', '%d not shown' % len(textual))]
            else:
                rows = rows + capped([line('textual', q) for q in textual])
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


# --- --fill-tests <spec-dir> (narrow-repair-1115 T1) ---------------------------------------------
PLACEHOLDER = re.compile(r'<[^<> ]+>')
FILL_USAGE = 'usage: bash scripts/symbol-map.sh --fill-tests <spec-dir>'


def is_glob(x):
    return any(c in x for c in '*?[') or x.endswith('/')


def commands_cells(path):
    """(purpose, command) for each command a `## Commands` row offers, as lib.sh command_cells reads it:
    the second cell of each table row, `\\|` unescaped, every backticked span of it."""
    try:
        with open(path, encoding='utf-8') as f:
            text = f.read()
    except (OSError, UnicodeDecodeError):
        return []
    out, inside = [], False
    for ln in text.splitlines():
        if re.match(r'^## Commands\s*$', ln):
            inside = True
            continue
        if re.match(r'^##\s', ln):
            if inside:
                break
            continue
        if not inside or not ln.startswith('|'):
            continue
        cells = ln.replace('\\|', '\x01').split('|')
        purpose = cells[1].replace('\x01', '|').strip()
        c = cells[2].replace('\x01', '|').strip() if len(cells) >= 3 else ''
        out.extend((purpose, span.strip()) for span in re.findall(r'`([^`]*)`', c))
    return out


def names(path, text):
    """Does text name path as a whole path (not inside a longer one)?"""
    return re.search(r'(?<![\w./-])' + re.escape(path) + r'(?![\w./-])', text) is not None


def section(bare, heading, mask):
    """(heading index, index of the next `## ` line or the end), or None; a fenced line (mask) is never read."""
    for i, ln in enumerate(bare):
        if not mask[i] and ln.strip() == heading:
            j = i + 1
            while j < len(bare) and (mask[j] or not bare[j].startswith('## ')):
                j += 1
            return i, j
    return None


def insert_after(lines, at, new, eol):
    """Insert new lines after lines[at]; a last line with no line end gets one first."""
    if not new:
        return
    if not lines[at].endswith(('\n', '\r')):
        lines[at] += eol
    lines[at + 1:at + 1] = [x + eol for x in new]


def fill_story(repo, path, cells):
    """Fill one todo, non-repair story in place; returns (pick lines, report lines)."""
    with open(path, 'rb') as f:
        text = f.read().decode('utf-8')
    lines = text.splitlines(True)
    eol = '\r\n' if '\r\n' in text else '\n'
    bare = [ln.rstrip('\r\n') for ln in lines]
    marks = [i for i, b in enumerate(bare) if b.strip() == '---']
    if not marks or marks[0] != 0 or len(marks) < 2:
        return [], []
    front = {}
    for b in bare[1:marks[1]]:
        if ':' in b:
            k, v = b.split(':', 1)
            front.setdefault(k.strip(), v.strip())
    sid = front.get('story', '')
    title = next((b for b in bare[marks[1] + 1:] if b.startswith('# ')), '')
    if not sid or front.get('status') != 'todo' or re.match(r'^# Repair round \d+', title):
        return [], []
    mask = fence_mask(bare)
    fs = section(bare, '## Files', mask)
    if not fs:
        return [], []
    listed, last_item = [], fs[0]
    for i in range(fs[0] + 1, fs[1]):
        if not mask[i] and bare[i].startswith('- '):
            last_item = i
            item = bare[i][2:].strip().split()[0].strip('`') if bare[i][2:].strip() else ''
            if item:
                listed.append(item)
    scope = set(listed) | {rel_to_root(repo.root, path)}
    added = []
    for p in listed:
        if is_glob(p) or is_test(p) or not os.path.isfile(os.path.join(repo.root, p)):
            continue
        lang = 'py' if p.endswith('.py') else ('sh' if repo.is_shell(p) else None)
        edges = repo.edges({'py': ('py', 'sh'), 'sh': ('sh',), None: ()}[lang])
        for q in sorted(exact_importers(repo, edges, p, lang)):
            if is_test(q) and not is_fixture(q) and not in_scope(q, scope) and q not in added:
                added.append(q)
    insert_after(lines, last_item, ['- ' + q for q in added], eol)
    report = ['symbol-map: %s: + %s' % (sid, q) for q in added]
    bare = [ln.rstrip('\r\n') for ln in lines]
    mask = fence_mask(bare)
    vs = section(bare, '## Verification', mask)
    vtext = '\n'.join(bare[i] for i in range(vs[0] + 1, vs[1]) if not mask[i]) if vs else ''
    picks, rows = [], []
    for t in [x for x in listed + added if not is_glob(x) and is_test(x) and not is_fixture(x)]:
        if names(t, vtext) or any(names(t, r) for r in rows):
            continue
        if not vs:
            picks.append('symbol-map: %s: no ## Verification section for %s' % (sid, t))
            continue
        cand = [c for purpose, c in cells if 'round-only' not in purpose and names(t, c)]
        free = [c for c in cand if not PLACEHOLDER.search(c)]
        if free:
            rows.append(free[0])
        elif cand:
            picks.extend('symbol-map: %s: pick a row for %s (%s)' % (sid, t, c) for c in cand)
        else:
            picks.append('symbol-map: %s: pick a row for %s (no ## Commands cell names it)' % (sid, t))
    if rows:
        at = max([i for i in range(vs[0] + 1, vs[1]) if bare[i].strip() and not mask[i]] or [vs[0]])
        insert_after(lines, at, ['`%s`' % r for r in rows], eol)
        report += ['symbol-map: %s: + row %s' % (sid, r) for r in rows]
    if added or rows:
        with open(path, 'wb') as f:
            f.write(''.join(lines).encode('utf-8'))
    return picks, report


def fill_tests(argv):
    """--fill-tests <spec-dir>: exit 0 every listed test has a row, 1 a pick line, 2 usage / not a repo."""
    if len(argv) != 2 or argv[0] != '--fill-tests' or not argv[1] or argv[1].startswith('-'):
        print(FILL_USAGE, file=sys.stderr)
        sys.exit(2)
    spec = os.path.abspath(native(argv[1]))
    if not os.path.isdir(spec):
        print('symbol-map: not a spec directory: %s' % argv[1], file=sys.stderr)
        sys.exit(2)
    root = git_root(spec)
    if not root:
        print('symbol-map: not inside a git repository: %s' % spec, file=sys.stderr)
        sys.exit(2)
    con = os.path.join(root, 'CLAUDE.vulyk.md')
    cells = commands_cells(con if os.path.isfile(con) else os.path.join(root, 'CLAUDE.md'))
    repo = Repo(root, tracked(root))
    picks = []
    for name in sorted(os.listdir(spec)):
        path = os.path.join(spec, name)
        if name.endswith('.md') and os.path.isfile(path):
            p, r = fill_story(repo, path, cells)
            for x in r + p:
                print(x)
            picks += p
    sys.exit(1 if picks else 0)


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    if '--fill-tests' in sys.argv[1:]:
        fill_tests(sys.argv[1:])
    story, scope_args, files, exact = parse_args(sys.argv[1:])
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

    blocks = [block(repo, p, scope, exact) for p in inputs]
    missing = any(miss for _, miss in blocks)
    # a missing input's block first, so the byte cap can never cut it; the rest keep input order
    blocks = [b for b, miss in blocks if miss] + [b for b, miss in blocks if not miss]
    lines, blocks_of = [], []
    for i, b in enumerate(blocks):
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
