#!/usr/bin/env bash
# The full-suite runner's contract (tests/full-suite.sh), driven through VULYK_SUITES with stub
# scripts: ok / FAIL / TIMEOUT lines, the summary, exit 0/1/124, the --jobs cap, the budget,
# the uncapped modes and --list. No real suite runs here except the --list of the real tree.
#
#   Usage: bash tests/full-suite.test.sh     # from anywhere, well under 30 s
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$SRC/tests/full-suite.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
expect() { # expect <label> <needle>   (judges $OUT)
  if printf '%s' "$OUT" | grep -qF -- "$2"; then echo "  ok    $1"
  else echo "::error::$1 - expected '$2' in:"; printf '%s\n' "$OUT" | sed 's/^/        /'; fail=1; fi
}
reject() { # reject <label> <needle>   (judges $OUT)
  if printf '%s' "$OUT" | grep -qF -- "$2"; then
    echo "::error::$1 - did not expect '$2' in:"; printf '%s\n' "$OUT" | sed 's/^/        /'; fail=1
  else echo "  ok    $1"; fi
}
code() { # code <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "  ok    $1"; else echo "::error::$1 - exit $3, want $2"; fail=1; fi
}
run() { # run <VULYK_SUITE_TIMEOUT> <suites> [runner args...] - sets OUT and RC
  local b="$1" s="$2"; shift 2
  OUT="$(VULYK_SUITE_TIMEOUT="$b" VULYK_SUITES="$s" bash "$RUN" "$@" 2>&1)"; RC=$?
}

S="$T/stubs"; mkdir -p "$S"
printf 'echo fine\n' > "$S/ok.sh"
printf 'for i in $(seq 1 30); do echo "fail-line-$i"; done\nexit 3\n' > "$S/bad.sh"
printf 'sleep 30\n' > "$S/hang.sh"
printf 'sleep 3\n' > "$S/slow.sh"
printf ': > "%s/started-$1"\n' "$T" > "$S/mark.sh"
# lock.sh: fails when another lock.sh holds the lock - two at once means the --jobs cap broke
printf 'mkdir "%s/lock" 2>/dev/null || { echo overlap; exit 1; }\nsleep 2\nrmdir "%s/lock"\n' "$T" "$T" > "$S/lock.sh"

echo "== all ok"
run 540 "bash $S/ok.sh
bash $S/ok.sh"
code "all ok -> exit 0" 0 "$RC"
expect "an ok line per job" "ok 0s bash $S/ok.sh"
expect "summary line" "full suite: 2 ok, 0 failed, 0 timed out, wall "
expect "summary names budget and jobs" "s, budget 540s, jobs "
reject "logs removed on exit 0" "logs: "

echo "== one failing"
run 540 "bash $S/ok.sh
bash $S/bad.sh"
code "a FAIL -> exit 1" 1 "$RC"
expect "FAIL line" "FAIL 0s bash $S/bad.sh"
expect "tail of the failed log" "fail-line-30"
expect "tail reaches 20 lines back" "fail-line-11"
reject "tail stops at 20 lines" "fail-line-10"
expect "summary counts the failure" "full suite: 1 ok, 1 failed, 0 timed out"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"
if [ -n "$LOGDIR" ] && [ -d "$LOGDIR" ]; then echo "  ok    logs kept and named on exit 1"; rm -rf "$LOGDIR"
else echo "::error::logs not kept/named: '$LOGDIR'"; fail=1; fi

echo "== the budget: a hang beside a FAIL, an unstarted job"
before=$SECONDS
run 2 "bash $S/hang.sh
bash $S/bad.sh
bash $S/mark.sh late" --jobs 2
took=$(( SECONDS - before ))
code "TIMEOUT outranks FAIL -> exit 124" 124 "$RC"
expect "TIMEOUT line for the hang" "s bash $S/hang.sh"
printf '%s\n' "$OUT" | grep -q "^TIMEOUT [0-9]*s bash $S/hang.sh\$" && echo "  ok    hang marked TIMEOUT" \
  || { echo "::error::hang not marked TIMEOUT"; printf '%s\n' "$OUT"; fail=1; }
expect "FAIL line beside it" "FAIL 0s bash $S/bad.sh"
expect "unstarted job marked TIMEOUT" "TIMEOUT 0s bash $S/mark.sh late"
[ -e "$T/started-late" ] && { echo "::error::a job started past the budget"; fail=1; } || echo "  ok    no job starts past the budget"
expect "summary still printed" "full suite: 0 ok, 1 failed, 2 timed out"
[ "$took" -lt 20 ] && echo "  ok    the hang was killed (${took}s)" || { echo "::error::runner waited ${took}s for a 30 s hang"; fail=1; }
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== --jobs 1 runs one at a time, --jobs 2 does not"
run 540 "bash $S/lock.sh
bash $S/lock.sh" --jobs 1
code "--jobs 1: no overlap -> exit 0" 0 "$RC"
expect "--jobs 1 in the summary" "jobs 1"
run 540 "bash $S/lock.sh
bash $S/lock.sh" --jobs 2
code "--jobs 2: the lock catches the overlap -> exit 1" 1 "$RC"
expect "overlap reported" "overlap"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== VULYK_SUITE_TIMEOUT=0 runs uncapped"
run 0 "bash $S/slow.sh"
code "a 3 s job under budget 0 -> exit 0" 0 "$RC"
expect "ok line" "ok "
expect "budget 0 in the summary" "budget 0s"

echo "== no working timeout binary"
mkdir -p "$T/fakebin"; printf '#!/bin/sh\nexit 1\n' > "$T/fakebin/timeout"; chmod +x "$T/fakebin/timeout"
OUT="$(PATH="$T/fakebin:$PATH" VULYK_SUITE_TIMEOUT=1 VULYK_SUITES="bash $S/slow.sh
bash $S/mark.sh done" bash "$RUN" --jobs 2 2>&1)"; RC=$?
code "over-budget job -> exit 124" 124 "$RC"
printf '%s\n' "$OUT" | grep -q "^TIMEOUT [3-9]s bash $S/slow.sh\$" && echo "  ok    reported TIMEOUT by its measured time, ran to the end" \
  || { echo "::error::slow job not TIMEOUT by measured time"; printf '%s\n' "$OUT"; fail=1; }
expect "a job inside the budget is ok" "ok 0s bash $S/mark.sh done"
expect "says it runs uncapped" "no working timeout"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== --list"
run 540 "bash $S/mark.sh listed" --list
code "--list -> exit 0" 0 "$RC"
[ "$OUT" = "bash $S/mark.sh listed" ] && echo "  ok    --list prints the commands" || { echo "::error::--list printed: $OUT"; fail=1; }
[ -e "$T/started-listed" ] && { echo "::error::--list ran a job"; fail=1; } || echo "  ok    --list runs nothing"
OUT="$(env -u VULYK_SUITES bash "$RUN" --list 2>&1)"
expect "real list: a plain suite" "bash tests/cycle.test.sh"
expect "real list: telemetry by part" "bash tests/telemetry.test.sh --part telemetry"
expect "real list: council by part" "bash tests/council.test.sh --part verbs"
printf '%s\n' "$OUT" | grep -qxE 'bash tests/(telemetry|council)\.test\.sh' \
  && { echo "::error::a split suite is also listed whole"; fail=1; } || echo "  ok    split suites are not listed whole"

echo "== bad usage"
run 540 "bash $S/ok.sh" --jobs 0
code "--jobs 0 -> exit 2" 2 "$RC"

[ "$fail" -eq 0 ] && echo "full-suite.test.sh: all ok" || echo "full-suite.test.sh: FAILED"
exit "$fail"
