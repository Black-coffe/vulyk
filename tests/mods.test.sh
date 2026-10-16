#!/usr/bin/env bash
# Mod checks: claude plugin validate (the pulse mod and the root marketplace), claude plugin test once a *.test.ts exists,
# its plugin.json version pinned to VERSION, and the pulse weights pinned to scripts/token-report.py.
cd "$(dirname "$0")/.." || exit 2
MODS=".claude/mods/vulyk-pulse"
if ! command -v claude >/dev/null 2>&1; then
  echo "mods.test.sh: claude is not on PATH, the mods cannot be checked" >&2
  exit 2
fi
for MOD in $MODS; do
  claude plugin validate "$MOD" || exit 1
done
claude plugin validate . >/dev/null || { claude plugin validate .; exit 1; }   # the root marketplace
for MOD in $MODS; do
  if [ -n "$(find "$MOD" -name '*.test.ts' -print -quit)" ]; then
    claude plugin test "$MOD" || exit 1
  fi
done

# Version pin: the plugin.json version equals VERSION.
WANT=$(tr -d '[:space:]' < VERSION)
for MOD in $MODS; do
  GOT=$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$MOD/.claude-plugin/plugin.json" | head -n1)
  if [ "$GOT" != "$WANT" ]; then
    echo "mods.test.sh: $MOD/.claude-plugin/plugin.json version '$GOT' is not VERSION '$WANT'" >&2
    exit 1
  fi
done

# Weights pin: the fixture line in the pulse's core.test.ts gives the same figure through scripts/token-report.py's own
# functions as the `want` it carries (core.test.ts checks weigh() against the same `want`).
PY=$(command -v python3 || command -v python)
[ -n "$PY" ] || { echo "mods.test.sh: no python, the weights pin cannot be checked" >&2; exit 2; }
"$PY" -I - <<'PYEOF' || exit 1
import importlib.util, json, re, sys
spec = importlib.util.spec_from_file_location('token_report', 'scripts/token-report.py')
tr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tr)
src = open('.claude/mods/vulyk-pulse/hooks/core.test.ts', encoding='utf-8').read()
m = re.search(r'^// weights-pin: (\[.*\])$', src, re.M)
if not m:
    sys.exit('mods.test.sh: no weights-pin line in the pulse core.test.ts')
rows = json.loads(m.group(1))
if len({r['model'].split('-')[1] for r in rows}) < 3:
    sys.exit('mods.test.sh: the weights pin needs an Opus, a Sonnet and a Fable row')
for r in rows:
    u = {'input_tokens': r['in'], 'cache_creation_input_tokens': r['cw'],
         'cache_read_input_tokens': r['cr'], 'output_tokens': r['out']}
    got = tr.weighted(tr.usage_of(u, r['model']))
    if abs(got - r['want']) > 1e-6:
        sys.exit('mods.test.sh: weights pin: %s weighs %s in token-report.py, the pin says %s' % (r['model'], got, r['want']))
PYEOF
echo "pulse mod: ok"
