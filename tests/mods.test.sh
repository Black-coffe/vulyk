#!/usr/bin/env bash
# Mod checks: claude plugin validate (the pulse mod and the root marketplace), claude plugin test once a *.test.ts exists,
# its plugin.json version pinned to VERSION, and the pulse weights pinned to scripts/token-report.py.
cd "$(dirname "$0")/.." || exit 2
. scripts/lib.sh   # vulyk_python; sourcing it also turns on set -u
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
vulyk_python || true
PY="$VULYK_PY"
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

# Prices by family (tails-1115-04, cc-facts F13): weigh() in core.ts itself and token-report.py give the same figure
# for the newest Fable and for a Fable version neither table names, and both read its cache at 0.025 of input.
# 500 + 1.25x1000 + 0.025x80000 + 300 = 4050.
CORE=".claude/mods/vulyk-pulse/hooks/core.ts"
PRICE_IN='[{"model":"claude-fable-5-2","input_tokens":500,"cache_creation_input_tokens":1000,"cache_read_input_tokens":80000,"output_tokens":300},{"model":"claude-fable-5-3","input_tokens":500,"cache_creation_input_tokens":1000,"cache_read_input_tokens":80000,"output_tokens":300}]'
WEIGH_JS='const {pathToFileURL} = require("url"); import(pathToFileURL(process.argv[1]).href).then(m => { for (const u of JSON.parse(process.argv[2])) console.log(m.weigh(u)) })'
if command -v node >/dev/null 2>&1; then
  PULSE="$(node --experimental-strip-types --no-warnings -e "$WEIGH_JS" "$CORE" "$PRICE_IN" | tr -d '\r' | paste -sd' ' -)"
elif command -v bun >/dev/null 2>&1; then
  PULSE="$(bun -e "$WEIGH_JS" "$CORE" "$PRICE_IN" | tr -d '\r' | paste -sd' ' -)"
else
  echo "mods.test.sh: neither node nor bun, the pulse price cannot be checked" >&2; exit 2
fi
"$PY" -I - "$PRICE_IN" "$PULSE" <<'PYEOF' || exit 1
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location('token_report', 'scripts/token-report.py')
tr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tr)
pulse = sys.argv[2].split()
for u, p in zip(json.loads(sys.argv[1]), pulse + [''] * 2):
    got = tr.weighted(tr.usage_of(u, u['model']))
    if p == '' or abs(float(p) - got) > 1e-6:
        sys.exit('mods.test.sh: prices by family: %s weighs %s in the pulse, %s in token-report.py' % (u['model'], p or 'nothing', got))
    if abs(got - 4050) > 1e-6:
        sys.exit('mods.test.sh: prices by family: %s weighs %s, not the 4050 of a cache read at 0.025 (cc-facts F13)' % (u['model'], got))
PYEOF
echo "pulse mod: ok"
