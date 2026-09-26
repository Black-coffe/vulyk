#!/usr/bin/env bash
# The token-report contract (ADR-013 D8), driven through a synthetic transcript tree - no model
# calls, no network, nothing under the real ~/.claude/projects read.
#
#   Usage: bash tests/token-report.test.sh            # from the VULYK repo root
#
# Fixture: tests/fixtures/token-report/ - three main sessions (one response split over three
# lines, a malformed line, a <synthetic> message, a session that names no spec, one older than
# --since), a worker whose prompt names its spec, a team agent that names none, a workflow clerk
# whose run record carries args.spec (and a journal.jsonl that must not be read), and a council
# ledger with a repeated round. Every expected number below is worked out by hand in the comments.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$SRC/tests/fixtures/token-report"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
LEDGER="$T/checks"; FAILS="$T/fails"; : > "$LEDGER"; : > "$FAILS"
ok()  { printf 'x\n' >> "$LEDGER"; echo "  ok    $1"; }
bad() { printf 'x\n' >> "$LEDGER"; printf 'x\n' >> "$FAILS"; echo "::error::$1"; }

expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then ok "$label"
  else bad "$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}
expect_absent() { # expect_absent <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    bad "$label - did not expect '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'
  else ok "$label"; fi
}
expect_eq() { # expect_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 - expected '$2', got '$3'"; fi
}

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then echo "::error::no python on PATH"; exit 1; fi
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# jget <json-file> <python expression over d (the report) and S (specs by slug)>
# eval() only ever sees the literal expressions written in this file, never data.
jget() {
  "$PY" -c 'import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8")); S={s["spec"]:s for s in d["specs"]}
print(eval(sys.argv[2]))' "$(native "$1")" "$2"
}

# --- the fixture projects-root: <root>/<encoded project path>/ ----------------------------------
# The project path carries '_' and '.' on purpose: every non-alphanumeric becomes '-'.
PROJ="$T/my_proj.v2"
mkdir -p "$PROJ/memory/stats"
cp "$FIX/council.jsonl" "$PROJ/memory/stats/council.jsonl"
PROJ_N="$(native "$PROJ")"
ENC="$(printf '%s' "$PROJ_N" | sed 's/[^A-Za-z0-9]/-/g')"
ROOT="$T/projects"
mkdir -p "$ROOT/$ENC"
cp -R "$FIX/transcripts/." "$ROOT/$ENC/"
# Session 2 was last written on 2026-09-10: --since must skip it without opening it.
touch -t 202609101200 "$ROOT/$ENC/aaaaaaaa-0000-4000-8000-000000000002.jsonl"
ROOT_N="$(native "$ROOT")"
TR="$SRC/scripts/token-report.py"
run() { "$PY" "$TR" "$@" --projects-root "$ROOT_N"; }

echo "--- full report, --json"
run "$PROJ_N" --json > "$T/all.json"; RC=$?
expect_eq "exits 0 over a malformed line and a journal file" "0" "$RC"
expect_eq "specs reported, weighted desc" "['beta', 'gamma', 'alpha', '(none)', 'old-spec']" "$(jget "$T/all.json" '[s["spec"] for s in d["specs"]]')"
# alpha = msg_A1 (10+1000w5m+200 out, the max over its three lines) + msg_D1 (400w5m+600r+40) in the
# main sessions, msg_W1 (3+500w-nosplit+1000r+40) + msg_W2 (2+3000r+60) in the worker.
expect_eq "dedup: msg_A1 counted once at its max output (alpha main raw 1210+1040)" "2250" "$(jget "$T/all.json" 'S["alpha"]["main"]["raw"]')"
expect_eq "alpha raw" "6855" "$(jget "$T/all.json" 'S["alpha"]["raw"]')"
expect_eq "alpha weighted (1460+600+768+362)" "3190" "$(jget "$T/all.json" 'S["alpha"]["weighted"]')"
expect_eq "alpha api calls (A1 once, D1, W1, W2)" "4" "$(jget "$T/all.json" 'S["alpha"]["api_calls"]')"
expect_eq "alpha sessions" "2" "$(jget "$T/all.json" 'S["alpha"]["sessions"]')"
expect_eq "alpha dispatches: the worker named alpha in its prompt" "{'worker-code': 1}" "$(jget "$T/all.json" 'S["alpha"]["dispatches"]')"
expect_eq "alpha council rounds: unique (spec, round), repeated round 1 once" "2" "$(jget "$T/all.json" 'S["alpha"]["rounds"]')"
expect_eq "alpha active minutes: 09:00:00-09:05:00 + 30 s on 09-12" "5.5" "$(jget "$T/all.json" 'S["alpha"]["active_min"]')"
expect_eq "alpha dates" "2026-09-12..2026-09-21" "$(jget "$T/all.json" 'S["alpha"]["first"]+".."+S["alpha"]["last"]')"
# beta = msg_A2 (5+10000r+50, named by a Bash command) + msg_A3 (2000w1h+20000r+300) + the team
# agent msg_G1 (1+100w5m+10), which names no spec and started while the session held beta.
expect_eq "beta raw" "32466" "$(jget "$T/all.json" 'S["beta"]["raw"]')"
expect_eq "beta weighted: a 1h write counts 2x (1055+6300+136)" "7491" "$(jget "$T/all.json" 'S["beta"]["weighted"]')"
expect_eq "beta dispatches: customAgentType wins over a team agentType" "{'drone-scout': 1}" "$(jget "$T/all.json" 'S["beta"]["dispatches"]')"
expect_eq "beta active minutes: gaps over 15 min not counted" "1.3" "$(jget "$T/all.json" 'S["beta"]["active_min"]')"
expect_eq "beta cache-read share" "0.924" "$(jget "$T/all.json" 'S["beta"]["cache_read_share"]')"
# gamma = msg_A4 (1+5000r+20, named by the Workflow args) + the clerk msg_C1 (2+3000w5m+30), whose
# prompt names alpha but whose run record says gamma. msg_SYN (<synthetic>) is not a call.
expect_eq "gamma raw: <synthetic> excluded, clerk deduped" "8053" "$(jget "$T/all.json" 'S["gamma"]["raw"]')"
expect_eq "gamma weighted" "4303" "$(jget "$T/all.json" 'S["gamma"]["weighted"]')"
expect_eq "gamma: the workflow agent follows the run's args.spec" "{'cycle-clerk': 1}" "$(jget "$T/all.json" 'S["gamma"]["dispatches"]')"
expect_eq "gamma: main/subagent split" "5021/3032" "$(jget "$T/all.json" 'str(S["gamma"]["main"]["raw"])+"/"+str(S["gamma"]["subagents"]["raw"])')"
expect_eq "gamma rounds from a docs/specs/ spec field" "1" "$(jget "$T/all.json" 'S["gamma"]["rounds"]')"
expect_eq "a session that names no spec is (none)" "110" "$(jget "$T/all.json" 'S["(none)"]["raw"]')"
expect_eq "a ledger-only spec reports its rounds at zero tokens" "1/0" "$(jget "$T/all.json" 'str(S["old-spec"]["rounds"])+"/"+str(S["old-spec"]["raw"])')"
expect_eq "total raw" "47484" "$(jget "$T/all.json" 'd["total"]["raw"]')"
expect_eq "total weighted" "15094" "$(jget "$T/all.json" 'd["total"]["weighted"]')"
expect_eq "total dispatches: agent-*.jsonl only, the journal is not one" "3" "$(jget "$T/all.json" 'd["total"]["dispatch_count"]')"
expect_eq "total rounds" "4" "$(jget "$T/all.json" 'd["total"]["rounds"]')"
expect_eq "total sessions" "3" "$(jget "$T/all.json" 'd["total"]["sessions"]')"
expect_eq "total active minutes: one merged timeline" "8.6" "$(jget "$T/all.json" 'd["total"]["active_min"]')"
expect_eq "a write without the 5m/1h split is counted and flagged" "1" "$(jget "$T/all.json" 'd["total"]["writes_without_split"]')"
expect_eq "top-level keys" "['project', 'since', 'specs', 'total']" "$(jget "$T/all.json" '[k for k in ("project","since","specs","total") if k in d]')"
expect_absent "the Workflow's totalTokens is never reported" "987654" < "$T/all.json"

echo "--- --since"
run "$PROJ_N" --json --since 2026-09-15 > "$T/since.json"
expect_eq "since is echoed" "2026-09-15" "$(jget "$T/since.json" 'd["since"]')"
expect_eq "since drops the 09-12 edit from alpha" "5815/2590/1" "$(jget "$T/since.json" '"%d/%d/%d" % (S["alpha"]["raw"], S["alpha"]["weighted"], S["alpha"]["sessions"])')"
expect_eq "since drops (none) and the old ledger row" "['beta', 'gamma', 'alpha']" "$(jget "$T/since.json" '[s["spec"] for s in d["specs"]]')"
expect_eq "since total raw/weighted/rounds" "46334/14384/3" "$(jget "$T/since.json" '"%d/%d/%d" % (d["total"]["raw"], d["total"]["weighted"], d["total"]["rounds"])')"
expect_eq "a session last written before --since is not opened" "2" "$(jget "$T/since.json" 'd["scanned"]["sessions"]')"
run "$PROJ_N" --since 2026-9-x > /dev/null 2>&1; RC=$?
expect_eq "a malformed --since is refused" "2" "$RC"

echo "--- --spec"
run "$PROJ_N" --json --spec gamma > "$T/spec.json"
expect_eq "--spec reports that spec only" "['gamma']" "$(jget "$T/spec.json" '[s["spec"] for s in d["specs"]]')"
expect_eq "--spec total is that spec" "8053" "$(jget "$T/spec.json" 'd["total"]["raw"]')"
run "$PROJ_N" --json --spec docs/specs/alpha --since 2026-09-15 > "$T/spec2.json"
expect_eq "--spec takes a docs/specs path and combines with --since" "alpha:5815" "$(jget "$T/spec2.json" '",".join("%s:%d" % (s["spec"], s["raw"]) for s in d["specs"])')"

echo "--- human output"
run "$PROJ_N" > "$T/human.txt"; RC=$?
expect_eq "table exits 0" "0" "$RC"
expect "header row" "spec" < "$T/human.txt"
expect "numbers in k" "32k" < "$T/human.txt"
expect "a TOTAL row" "TOTAL" < "$T/human.txt"
expect "note, line 1" "weighted ≈ cost at API cache prices" < "$T/human.txt"
expect "note, line 2" "The Workflow's printed totalTokens is not spend" < "$T/human.txt"
expect "the no-split fallback is said" "counted as 5m" < "$T/human.txt"
expect_eq "sorted by weighted desc" "beta gamma alpha (none) old-spec" "$(sed -n '3,7p' "$T/human.txt" | awk '{print $1}' | tr '\n' ' ' | sed 's/ $//')"

echo "--- locating the transcripts"
run "$PROJ_N/" --json > "$T/slash.json"
expect_eq "a trailing slash finds the same directory" "47484" "$(jget "$T/slash.json" 'd["total"]["raw"]')"
if command -v cygpath >/dev/null 2>&1; then
  run "$(cygpath -w "$PROJ")" --json > "$T/bs.json"
  expect_eq "a backslash path finds the same directory" "47484" "$(jget "$T/bs.json" 'd["total"]["raw"]')"
fi
run "$T/nowhere" --json > "$T/none.out" 2>&1; RC=$?
expect_eq "a project with no transcripts exits 1" "1" "$RC"
expect "and says where it looked" "no transcripts for" < "$T/none.out"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "token-report.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
