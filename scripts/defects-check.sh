#!/usr/bin/env bash
# VULYK defect library gate - docs/defects/<id>.md or docs/defects/<area>/<id>.md, one card per class of
# owner-rejected work (format and rules: docs/defects/README.md; parser: .claude/hooks/defects_lib.py).
#
#   Usage: bash scripts/defects-check.sh           # library audit
#          bash scripts/defects-check.sh <arg>     # the gate before showing work to the owner
#
# Audit: debt, effective status, and fixtures - every effective `block` card's `check:` is run
# once per fixture and must exit non-zero on each (a fixture that passes = the gate is blind to it).
# Gate: debt, then the `check:` of every card that DECLARES `block` with a check, fixtures or not,
# with <arg>; a non-zero exit is red.
#
# Effective status: `block` only with a non-empty `check:` and >= 2 existing `fixtures:`; a block
# with a check but fewer fixtures is reported as "block without fixtures (check runs, not earned)";
# any other block (and any status but block/text/revoked) is reported as `text` with the reason.
# Effective status decides debt and the audit, not whether the gate runs a check. `revoked`
# cards are ignored. Debt: >= 2 owner quotes, effective status not block, and at least one quote
# line committed after the commit that added the library's README.md (git blame committer time,
# not the date written in the quote). Uncommitted quote lines and a library outside git are new.
# Debt with no new quote is "old debt": reported, never red.
# The same new/old rule holds for three more findings. UNDELIVERABLE: a card shown as text with no
# `paths:` (no hook can deliver it). OVERLAP: one normalised key on two live cards (a key inside
# another card's key is only an "ambiguous key" line). ESCAPE: a block card got a quote after its
# `check:` line and no fixture or check change since. New = the card file / keys line / quote is
# newer than the library's README.md, or uncommitted. DUPLICATE: two cards with one id - always red.
# Branches: debt is owed only by a prohibitive card (a Never or How-to line); a permissive card (Allowed
# lines only) with >= 2 dated Allowed lines is an `allowed repeats` line. CONFLICT: a live permissive and
# a live card with a Never line (a How-to line prohibits nothing) with overlapping paths: and no
# `exception:` naming the latter (new/old by the newest Allowed line). EXCEPTION: an `exception:` naming no live card, or (audit) a `passes:` fixture
# the named card's check: fails on (new/old by the exception: line). INDEX: INDEX.md exists and
# `defects-index.sh --check` says stale (no INDEX.md: one `no index` line, never red).
#
# Placeholder: the first <...> token of `check:` (<arg>, or a host's own such as <sheet>.json) is
# replaced by the argument / fixture path. When the token carries an extension (<sheet>.json) and the
# argument ends with it, the whole `<sheet>.json` is replaced. A check with no token runs as written.
# Checks run from the repo root; their output goes to a log under ${TMPDIR:-/tmp}, not the tree.
#
# Exit: 0 green, 1 red (a new finding, a duplicate id, a red check, a blind fixture, a stale index), 2 usage / no library /
# no python / no parser.
# Output: one line per finding, the last line is the verdict (GREEN: N blocking checks | RED: ...).
# DEFECTS_DIR overrides docs/defects (relative to the repo root, or absolute).
set -uo pipefail

case "${1:-}" in
  -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "defects-check: usage: bash scripts/defects-check.sh [<arg>]" >&2; exit 2
fi
MODE=audit; ARG=""
if [ "$#" -eq 1 ]; then
  [ -n "$1" ] || { echo "defects-check: <arg> is empty" >&2; exit 2; }
  MODE=gate; ARG="$1"
fi

SELF="$(cd "$(dirname "$0")" && pwd)"
# The card parser is shared with the hooks: .claude/hooks/defects_lib.py next to this script's repo.
LIB="$(cd "$(dirname "$0")/../.claude/hooks" 2>/dev/null && pwd)"
[ -f "$LIB/defects_lib.py" ] || { echo "defects-check: card parser missing: $(dirname "$0")/../.claude/hooks/defects_lib.py" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2
DIR="${DEFECTS_DIR:-docs/defects}"
[ -d "$DIR" ] || { echo "defects-check: no defect library at $DIR" >&2; exit 2; }

PY=""
for p in python3 python; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done
[ -n "$PY" ] || { echo "defects-check: python 3 not found on PATH (python3 or python) - cannot parse cards" >&2; exit 2; }

# One record per line, tab-separated:
#   D <text>                      new debt (red)
#   U / O / E <text>              new undeliverable card / key overlap / escape after block (red)
#   C / N <text>                  new allowed/never conflict / broken exception (red)
#   X <text>                      two cards with one id (always red)
#   I <text>                      information (not red)
#   R <id> <target> <cmd> <title> a check to run: <target> is the fixture (audit) or <arg> (gate)
#   P <ref> <fixture> <cmd> <new|old never-ref>  a passes: fixture the never card's check must exit 0 on
plan="$(PYTHONIOENCODING=utf-8 "$PY" - "$MODE" "$DIR" "$ARG" "$LIB" <<'PY'
import collections, datetime, os, re, shlex, subprocess, sys

sys.stdout.reconfigure(newline='\n')  # Windows python would end every record with \r
mode, d, arg = sys.argv[1], sys.argv[2], sys.argv[3]
hooks = sys.argv[4]
if os.name == 'nt' and re.match(r'^/[A-Za-z]/', hooks):  # a Git Bash path the shell did not convert
    hooks = hooks[1] + ':' + hooks[2:]
sys.path.insert(0, hooks)
import defects_lib

def git(*a):
    r = subprocess.run(['git', '-C', d] + list(a), capture_output=True)
    return r.stdout.decode('utf-8', 'replace') if r.returncode == 0 else None

in_git = (git('rev-parse', '--is-inside-work-tree') or '').strip() == 'true'
lib_time = None  # None: README not committed yet, so every committed quote predates the library
if in_git:
    stamps = (git('log', '--diff-filter=A', '--format=%ct', '--', 'README.md') or '').split()
    if stamps:
        lib_time = int(stamps[-1])

def blame(name):
    """line number (from 1) -> (sha, committer-time); None when the file has no history."""
    out = git('blame', '--line-porcelain', '--', name) if in_git else None
    if out is None:
        return None
    res, sha, t, n = {}, None, None, 0
    for line in out.split('\n'):
        if line.startswith('\t'):
            n += 1
            res[n] = (sha, t)
        elif re.match(r'^[0-9a-f]{40} \d+ \d+', line):
            sha, t = line.split(' ', 1)[0], None
        elif line.startswith('committer-time '):
            t = int(line.split(' ', 1)[1])
    return res

def placeholder(cmd, target):
    m = re.search(r'(<[^<>\s]+>)(\.[A-Za-z0-9]+)?', cmd)
    if not m:
        return cmd
    tok, ext = m.group(1), m.group(2) or ''
    q = shlex.quote(target)
    if ext and target.endswith(ext):
        cmd = cmd.replace(tok + ext, q)
        base = target[:-len(ext)]
        return cmd.replace(tok, shlex.quote(base) if base else q)
    return cmd.replace(tok, q)

def emit(*f):
    print('\t'.join(str(x).replace('\t', ' ').replace('\n', ' ') for x in f))

_blames = {}
def blame_of(name):
    if name not in _blames:
        _blames[name] = blame(name)
    return _blames[name]

def when(name, n):
    """(time, label) of line n: time is inf when the line is uncommitted or the library is outside git."""
    sha, t = (blame_of(name) or {}).get(n, (None, None))
    if not in_git:
        return float('inf'), 'outside git'
    if sha is None or set(sha) == {'0'} or t is None:
        return float('inf'), 'uncommitted'
    return t, '%s %s' % (sha[:7], datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%d %H:%M'))

def is_new(t):
    # The debt rule: newer than the commit that added README.md, or uncommitted (inf).
    return t == float('inf') or (lib_time is not None and t > lib_time)

def touched(path):
    """Newest time a repo-root path changed: inf when it is dirty or untracked, None when unknown."""
    r = subprocess.run(['git', 'status', '--porcelain', '--', path], capture_output=True)
    if r.returncode == 0 and r.stdout.strip():
        return float('inf')
    r = subprocess.run(['git', 'log', '-1', '--format=%ct', '--', path], capture_output=True)
    s = r.stdout.decode('utf-8', 'replace').strip() if r.returncode == 0 else ''
    return int(s) if s else None

def norm_key(k):
    return re.sub(r'\s+', ' ', k.strip().lower())

if not in_git:
    emit('I', 'note: %s is outside git - every quote counts as new' % d)

live_keys = []  # (card id, {normalised key}, time of its keys: line)

cards = defects_lib.load_cards(d)
# Ids are unique across the library (revoked cards included): a card in a folder must not shadow another.
by_id = collections.defaultdict(list)
for c in cards:
    by_id[c.id].append(c.ref)
for cid in sorted(by_id):
    if len(by_id[cid]) > 1:
        emit('X', 'DUPLICATE  %s: %s share one id - rename all but one' % (cid, ', '.join(by_id[cid])))

for c in cards:
    # name: the card's path relative to the library, for git; cid: the ref every finding prints.
    name, cid, fml = c.path, c.ref, c.fm_lines
    title = defects_lib.fm_scalar(c.fm.get('title', ''))
    status, check, fixtures, quotes = c.status, c.check, c.fixtures, c.lines['quotes']
    if status == 'revoked':
        continue
    existing = [f for f in fixtures if os.path.isfile(f)]

    eff, reason = defects_lib.effective_status(c)
    if reason == 'block without fixtures':
        # 0.19.1: the gate still runs a declared check - fixtures earn the status (debt, the
        # audit), they do not switch the protection off.
        emit('I', 'block %s: block without fixtures (check runs, not earned) - %d of %d listed exist, counted as text for debt'
             % (cid, len(existing), len(fixtures)))
    elif reason:
        emit('I', 'text  %s: %s - counted as text' % (cid, reason))

    permissive = bool(c.allowed) and not c.never and not c.howto
    if permissive:
        reps = len([x for x in c.allowed_dates if x])
        if reps >= 2:
            emit('I', 'allowed repeats %d %s' % (reps - 1, cid))
    if not permissive and eff != 'block' and len(quotes) >= 2:
        bl = blame(name)
        newest = None
        for n in quotes:
            sha, t = (bl or {}).get(n, (None, None))
            if not in_git:
                key, label = float('inf'), 'outside git'
            elif bl is None or sha is None or set(sha) == {'0'} or t is None:
                key, label = float('inf'), 'uncommitted'
            elif lib_time is not None and t > lib_time:
                key = t
                label = '%s %s' % (sha[:7], datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%d %H:%M'))
            else:
                continue
            if newest is None or key > newest[0]:
                newest = (key, label)
        if newest:
            emit('D', 'DEBT  %s: %d quotes, not block, new quote %s - add a failing check: and 2 fixtures' % (cid, len(quotes), newest[1]))
        else:
            emit('I', 'old debt  %s: %d quotes, not block, none newer than the library' % (cid, len(quotes)))

    # Undeliverable: defects-inject.sh shows a card as text unless it declares block with a check, and
    # only when a target matches its paths:. With no paths: its Never lines can never reach an agent.
    if not (status == 'block' and check) and not c.paths:
        added = (git('log', '--diff-filter=A', '--format=%ct', '--', name) or '').split() if in_git else []
        t = int(added[-1]) if added else float('inf')
        hint = ' (area: is a label, not a glob)' if defects_lib.fm_scalar(c.fm.get('area', '')) else ''
        if is_new(t):
            emit('U', 'UNDELIVERABLE  %s: text card with no paths: - no hook can show its Never lines; add path globs, cmd:<regex> or tool:<regex>%s' % (cid, hint))
        else:
            emit('I', 'old undeliverable  %s: text card with no paths:, older than the library%s' % (cid, hint))

    # Escape: an owner quote committed after the block check: line, and no fixture or check change since.
    if eff == 'block' and in_git and 'check' in fml:
        ct = when(name, fml['check'])[0]
        newest = None
        for n in quotes:
            qt, label = when(name, n)
            if qt > ct and (newest is None or qt > newest[0]):
                newest = (qt, label)
        if newest:
            fx = [x for x in (touched(f) for f in existing) if x is not None]
            if not fx or max(fx) < newest[0]:
                if is_new(newest[0]):
                    emit('E', 'ESCAPE  %s: quote %s came after the block check, no fixture or check change since - add the new form as a fixture and make the check fail on it' % (cid, newest[1]))
                else:
                    emit('I', 'old escape  %s: quote %s after the block check, older than the library' % (cid, newest[1]))

    keys = {norm_key(k) for k in c.keys if norm_key(k)}
    if keys:
        live_keys.append((cid, keys, when(name, fml['keys'])[0] if 'keys' in fml else float('inf')))

    if mode == 'gate' and status == 'block' and check:
        emit('R', cid, arg, placeholder(check, arg), title)
    elif mode == 'audit' and eff == 'block':
        for target in existing:
            emit('R', cid, target, placeholder(check, target), title)

# Allowed against Never: a permissive card overrides a prohibitive one only through `exception: <ref>`.
live = {c.ref: c for c in cards if c.status != 'revoked'}

def scopes_overlap(a, b):
    """Identical entries, or one glob matching the other entry as a path; cmd:/tool: compare as strings."""
    for x in a:
        for y in b:
            if x == y:
                return True
            kx, vx = defects_lib.parse_scope(x)
            ky, vy = defects_lib.parse_scope(y)
            if kx == ky == 'glob' and (defects_lib.scope_matches(x, None, vy, None) or defects_lib.scope_matches(y, None, vx, None)):
                return True
    return False

for p in live.values():
    if not (p.allowed and not p.never and not p.howto):
        continue
    t = max([when(p.path, n)[0] for n in p.lines['allowed']] or [float('inf')])
    for n in live.values():
        if not n.never or p.exception == n.ref or not scopes_overlap(p.paths, n.paths):
            continue
        if is_new(t):
            emit('C', 'CONFLICT %s %s: allowed and never share a scope, no exception: links them - the never wins; add exception: %s to %s or narrow its paths:' % (p.ref, n.ref, n.ref, p.ref))
        else:
            emit('I', 'old conflict %s %s: allowed and never share a scope, no exception: links them' % (p.ref, n.ref))

for p in live.values():
    if not p.exception:
        continue
    t, label = when(p.path, p.fm_lines['exception']) if 'exception' in p.fm_lines else (float('inf'), 'uncommitted')
    new = is_new(t)
    target = live.get(p.exception)
    if target is None:
        if new:
            emit('N', 'EXCEPTION %s: exception: %s names no live card - fix the ref' % (p.ref, p.exception))
        else:
            emit('I', 'old exception %s: exception: %s names no live card' % (p.ref, p.exception))
        continue
    if not target.check:
        if p.passes:
            emit('I', 'passes unused  %s: %s has no check:' % (p.ref, target.ref))
        continue
    if not p.passes:
        # ADR-021 D9: an exception to a checked never needs the fixture that check passes.
        if new:
            emit('N', 'EXCEPTION %s: exception: %s has a check: and %s lists no passes: fixture - add one the check exits 0 on' % (p.ref, target.ref, p.ref))
        else:
            emit('I', 'old exception %s: exception: %s has a check:, no passes: fixture' % (p.ref, target.ref))
        continue
    if mode == 'audit':
        for f in p.passes:
            emit('P', p.ref, f, placeholder(target.check, f), '%s %s' % ('new' if new else 'old', target.ref))

# Overlap: one key on two live cards sends one owner remark to two classes, and splits its quotes.
for i in range(len(live_keys)):
    a, ka, ta = live_keys[i]
    for b, kb, tb in live_keys[i + 1:]:
        same = sorted(ka & kb)
        if same:
            shown = ', '.join('"%s"' % k for k in same)
            if is_new(max(ta, tb)):
                emit('O', 'OVERLAP  %s, %s: share key %s - sharpen one key or merge the cards' % (a, b, shown))
            else:
                emit('I', 'old overlap  %s, %s: share key %s' % (a, b, shown))
        for x, y, kx, ky in ((a, b, ka, kb), (b, a, kb, ka)):
            for k in sorted(kx - ky):
                for m in sorted(ky - kx):
                    if k in m:
                        emit('I', 'ambiguous key  %s "%s" is inside %s "%s"' % (x, k, y, m))
PY
)" || { echo "defects-check: cards could not be read in $DIR" >&2; exit 2; }

LOG="${TMPDIR:-/tmp}/vulyk-defects-$(date +%Y%m%d-%H%M%S)-$$.log"
debt=0; red=0; blind=0; runs=0; undel=0; overlap=0; escape=0; dup=0; conflict=0; exc=0; stale=0
seen=" "; n=0
while IFS=$'\t' read -r kind a b c title; do
  case "$kind" in
    D) echo "$a"; debt=$((debt+1)) ;;
    U) echo "$a"; undel=$((undel+1)) ;;
    O) echo "$a"; overlap=$((overlap+1)) ;;
    E) echo "$a"; escape=$((escape+1)) ;;
    X) echo "$a"; dup=$((dup+1)) ;;
    C) echo "$a"; conflict=$((conflict+1)) ;;
    N) echo "$a"; exc=$((exc+1)) ;;
    P)
      runs=$((runs+1)); age="${title%% *}"; nref="${title#* }"
      out="$(bash -c "$c" 2>&1 < /dev/null)"; rc=$?
      { echo "== $a passes [$b]: $c (exit $rc)"; printf '%s
' "$out"; } >> "$LOG"
      if [ "$rc" -eq 0 ]; then
        echo "ok    $a: passes: $b passes the check of $nref"
      elif [ "$age" = new ]; then
        echo "EXCEPTION $a: passes: $b fails the check of $nref (exit $rc) - the never check fires on the allowed form; narrow the check or fix the fixture ($c)"
        exc=$((exc+1))
      else
        echo "old exception $a: passes: $b fails the check of $nref (exit $rc)"
      fi ;;
    I) echo "$a" ;;
    R)
      id="$a"; target="$b"; cmd="$c"; runs=$((runs+1))
      case "$seen" in *" $id "*) ;; *) seen="$seen$id "; n=$((n+1)) ;; esac
      out="$(bash -c "$cmd" 2>&1 < /dev/null)"; rc=$?
      { echo "== $id [$target]: $cmd (exit $rc)"; printf '%s\n' "$out"; } >> "$LOG"
      if [ "$MODE" = audit ]; then
        if [ "$rc" -eq 0 ]; then
          echo "BLIND $id: fixture $target passes the check - the gate cannot see it ($cmd)"; blind=$((blind+1))
        else
          echo "ok    $id: fixture $target fails the check (exit $rc)"
        fi
      elif [ "$rc" -ne 0 ]; then
        echo "RED   $id - $title: $cmd (exit $rc)"; red=$((red+1))
        [ -n "$out" ] && printf '%s\n' "$out" | tail -n 8 | awk '{ print "      " substr($0, 1, 200) }'
      else
        echo "ok    $id"
      fi ;;
  esac
done <<< "$plan"

# The generated index (scripts/defects-index.sh): red when it exists and differs from the cards.
if [ -f "$DIR/INDEX.md" ]; then
  if [ -f "$SELF/defects-index.sh" ]; then
    iout="$(DEFECTS_DIR="$DIR" bash "$SELF/defects-index.sh" --check 2>&1)"; irc=$?
  else
    iout="scripts/defects-index.sh missing - cannot check $DIR/INDEX.md"; irc=2
  fi
  if [ "$irc" -ne 0 ]; then echo "INDEX  $iout"; stale=1; fi
else
  echo "no index  $DIR/INDEX.md - generate it: bash scripts/defects-index.sh"
fi

[ "$runs" -gt 0 ] && echo "log: $LOG"
if [ $((debt + red + blind + undel + overlap + escape + dup + conflict + exc + stale)) -eq 0 ]; then
  echo "GREEN: $n blocking checks"; exit 0
fi
parts=()
[ "$debt" -gt 0 ] && parts+=("$debt new debt")
[ "$red" -gt 0 ] && parts+=("$red red checks")
[ "$blind" -gt 0 ] && parts+=("$blind blind fixtures")
[ "$undel" -gt 0 ] && parts+=("$undel undeliverable")
[ "$overlap" -gt 0 ] && parts+=("$overlap overlaps")
[ "$escape" -gt 0 ] && parts+=("$escape escapes")
[ "$dup" -gt 0 ] && parts+=("$dup duplicate ids")
[ "$conflict" -gt 0 ] && parts+=("$conflict conflicts")
[ "$exc" -gt 0 ] && parts+=("$exc exceptions")
[ "$stale" -gt 0 ] && parts+=("index stale")
( IFS=','; echo "RED: ${parts[*]}" | sed 's/,/, /g' )
exit 1
