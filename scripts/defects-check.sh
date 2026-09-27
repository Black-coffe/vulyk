#!/usr/bin/env bash
# VULYK defect library gate - docs/defects/<id>.md, one card per class of owner-rejected work
# (format and rules: docs/defects/README.md).
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
#
# Placeholder: the first <...> token of `check:` (<arg>, or a host's own such as <sheet>.json) is
# replaced by the argument / fixture path. When the token carries an extension (<sheet>.json) and the
# argument ends with it, the whole `<sheet>.json` is replaced. A check with no token runs as written.
# Checks run from the repo root; their output goes to a log under ${TMPDIR:-/tmp}, not the tree.
#
# Exit: 0 green, 1 red (new debt, a red check, a blind fixture), 2 usage / no library / no python.
# Output: one line per finding, the last line is the verdict (GREEN: N blocking checks | RED: ...).
# DEFECTS_DIR overrides docs/defects (relative to the repo root, or absolute).
set -uo pipefail

case "${1:-}" in
  -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "defects-check: usage: bash scripts/defects-check.sh [<arg>]" >&2; exit 2
fi
MODE=audit; ARG=""
if [ "$#" -eq 1 ]; then
  [ -n "$1" ] || { echo "defects-check: <arg> is empty" >&2; exit 2; }
  MODE=gate; ARG="$1"
fi

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
#   I <text>                      information (not red)
#   R <id> <target> <cmd> <title> a check to run: <target> is the fixture (audit) or <arg> (gate)
plan="$(PYTHONIOENCODING=utf-8 "$PY" - "$MODE" "$DIR" "$ARG" <<'PY'
import datetime, os, re, shlex, subprocess, sys

sys.stdout.reconfigure(newline='\n')  # Windows python would end every record with \r
mode, d, arg = sys.argv[1], sys.argv[2], sys.argv[3]
QUOTE_HEADS = {'## owner quotes', '## цитаты владельца'}

def git(*a):
    r = subprocess.run(['git', '-C', d] + list(a), capture_output=True)
    return r.stdout.decode('utf-8', 'replace') if r.returncode == 0 else None

in_git = (git('rev-parse', '--is-inside-work-tree') or '').strip() == 'true'
lib_time = None  # None: README not committed yet, so every committed quote predates the library
if in_git:
    stamps = (git('log', '--diff-filter=A', '--format=%ct', '--', 'README.md') or '').split()
    if stamps:
        lib_time = int(stamps[-1])

def listval(v):
    v = v.strip()
    if v.startswith('[') and v.endswith(']'):
        v = v[1:-1]
    return [x.strip().strip('"\'') for x in v.split(',') if x.strip().strip('"\'')]

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

if not in_git:
    emit('I', 'note: %s is outside git - every quote counts as new' % d)

for name in sorted(os.listdir(d)):
    if not name.endswith('.md') or name == 'README.md' or not os.path.isfile(os.path.join(d, name)):
        continue
    with open(os.path.join(d, name), encoding='utf-8', errors='replace', newline='') as fh:
        lines = [l.rstrip('\r') for l in fh.read().lstrip('﻿').split('\n')]
    fm, body_from = {}, 0
    if lines and lines[0].strip() == '---':
        for i in range(1, len(lines)):
            if lines[i].strip() == '---':
                body_from = i + 1
                break
            if lines[i][:1].isspace() or ':' not in lines[i]:
                continue
            k, _, v = lines[i].partition(':')
            # An inline ` # comment` is dropped, as the hooks' fm_scalar does (contract section 1 example).
            fm[k.strip().lower()] = re.sub(r'\s+#(\s.*)?$', '', v).strip()
    cid = fm.get('id') or name[:-3]
    title = fm.get('title', '')
    status = (fm.get('status') or 'text').lower()
    if status == 'revoked':
        continue
    check = fm.get('check', '')
    fixtures = listval(fm.get('fixtures', ''))
    existing = [f for f in fixtures if os.path.isfile(f)]

    quotes, inside = [], False
    for i in range(body_from, len(lines)):
        line = lines[i]
        if line.startswith('## '):
            inside = line.strip().lower() in QUOTE_HEADS
        elif inside and re.match(r'^- \d{4}-\d{2}-\d{2} ·', line):
            quotes.append(i + 1)

    eff, reason = 'text', ''
    if status == 'block':
        if not check:
            reason = 'block without check'
        elif len(existing) < 2:
            # 0.19.1: the gate still runs a declared check - fixtures earn the status (debt, the
            # audit), they do not switch the protection off.
            emit('I', 'block %s: block without fixtures (check runs, not earned) - %d of %d listed exist, counted as text for debt'
                 % (cid, len(existing), len(fixtures)))
        else:
            eff = 'block'
    elif status != 'text':
        reason = "status '%s' is not block|text|revoked" % status
    if reason:
        emit('I', 'text  %s: %s - counted as text' % (cid, reason))

    if eff != 'block' and len(quotes) >= 2:
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

    if mode == 'gate' and status == 'block' and check:
        emit('R', cid, arg, placeholder(check, arg), title)
    elif mode == 'audit' and eff == 'block':
        for target in existing:
            emit('R', cid, target, placeholder(check, target), title)
PY
)" || { echo "defects-check: cards could not be read in $DIR" >&2; exit 2; }

LOG="${TMPDIR:-/tmp}/vulyk-defects-$(date +%Y%m%d-%H%M%S)-$$.log"
debt=0; red=0; blind=0; runs=0
seen=" "; n=0
while IFS=$'\t' read -r kind a b c title; do
  case "$kind" in
    D) echo "$a"; debt=$((debt+1)) ;;
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

[ "$runs" -gt 0 ] && echo "log: $LOG"
if [ $((debt + red + blind)) -eq 0 ]; then
  echo "GREEN: $n blocking checks"; exit 0
fi
parts=()
[ "$debt" -gt 0 ] && parts+=("$debt new debt")
[ "$red" -gt 0 ] && parts+=("$red red checks")
[ "$blind" -gt 0 ] && parts+=("$blind blind fixtures")
( IFS=','; echo "RED: ${parts[*]}" | sed 's/,/, /g' )
exit 1
