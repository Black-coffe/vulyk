#!/usr/bin/env bash
# The full-suite runner's contract (tests/full-suite.sh), driven through VULYK_SUITES with stub
# scripts: ok / FAIL / TIMEOUT lines, the summary, exit 0/1/124, the --jobs cap, the budget,
# the uncapped modes, --list, the capped default --jobs, the latency suites last and the shared
# install cache. No real suite runs here except the --list of the real tree.
#
#   Usage: bash tests/full-suite.test.sh     # from anywhere, about 30 s
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
line() { # line <label> <verdict> <command> - a `<verdict> <N>s <command>` line, any N (seconds round)
  if printf '%s\n' "$OUT" | sed -E 's/^(ok|FAIL|TIMEOUT) [0-9]+s /\1 Ns /' | grep -qxF -- "$2 Ns $3"; then echo "  ok    $1"
  else echo "::error::$1 - expected '$2 <N>s $3' in:"; printf '%s\n' "$OUT" | sed 's/^/        /'; fail=1; fi
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
line "an ok line per job" ok "bash $S/ok.sh"
expect "summary line" "full suite: 2 ok, 0 failed, 0 timed out, wall "
expect "summary names budget and jobs" "s, budget 540s, jobs "
reject "logs removed on exit 0" "logs: "

echo "== one failing"
run 540 "bash $S/ok.sh
bash $S/bad.sh"
code "a FAIL -> exit 1" 1 "$RC"
line "FAIL line" FAIL "bash $S/bad.sh"
expect "tail of the failed log" "fail-line-30"
expect "tail reaches 20 lines back" "fail-line-11"
reject "tail stops at 20 lines" "fail-line-10"
expect "summary counts the failure" "full suite: 1 ok, 1 failed, 0 timed out"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"
if [ -n "$LOGDIR" ] && [ -d "$LOGDIR" ]; then echo "  ok    logs kept and named on exit 1"; rm -rf "$LOGDIR"
else echo "::error::logs not kept/named: '$LOGDIR'"; fail=1; fi

echo "== the budget: a hang beside a FAIL"
before=$SECONDS
run 2 "bash $S/hang.sh
bash $S/bad.sh" --jobs 2
took=$(( SECONDS - before ))
code "TIMEOUT outranks FAIL -> exit 124" 124 "$RC"
expect "TIMEOUT line for the hang" "s bash $S/hang.sh"
printf '%s\n' "$OUT" | grep -q "^TIMEOUT [0-9]*s bash $S/hang.sh\$" && echo "  ok    hang marked TIMEOUT" \
  || { echo "::error::hang not marked TIMEOUT"; printf '%s\n' "$OUT"; fail=1; }
line "FAIL line beside it" FAIL "bash $S/bad.sh"
expect "summary still printed" "full suite: 0 ok, 1 failed, 1 timed out"
[ "$took" -lt 20 ] && echo "  ok    the hang was killed (${took}s)" || { echo "::error::runner waited ${took}s for a 30 s hang"; fail=1; }
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== the budget: a job still queued at the budget never starts"
run 2 "bash $S/hang.sh
bash $S/mark.sh late" --jobs 1
code "queued job -> exit 124" 124 "$RC"
expect "unstarted job marked TIMEOUT" "TIMEOUT 0s bash $S/mark.sh late"
[ -e "$T/started-late" ] && { echo "::error::a job started past the budget"; fail=1; } || echo "  ok    no job starts past the budget"
expect "summary counts both" "full suite: 0 ok, 0 failed, 2 timed out"
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

echo "== dead timeout and gtimeout stubs, Python present: the budget still caps"
mkdir -p "$T/deadbin"
for b in timeout gtimeout; do printf '#!/bin/sh\nexit 1\n' > "$T/deadbin/$b"; chmod +x "$T/deadbin/$b"; done
OUT="$(PATH="$T/deadbin:$PATH" VULYK_SUITE_TIMEOUT=1 VULYK_SUITES="bash $S/slow.sh
bash $S/mark.sh done" bash "$RUN" --jobs 2 2>&1)"; RC=$?
code "over-budget job with dead stubs -> exit 124" 124 "$RC"
printf '%s\n' "$OUT" | grep -q "^TIMEOUT [0-2]s bash $S/slow.sh\$" && echo "  ok    the slow job is killed at the budget" \
  || { echo "::error::slow job not capped at the budget"; printf '%s\n' "$OUT"; fail=1; }
line "a job inside the budget is ok" ok "bash $S/mark.sh done"
reject "no uncapped warning while python caps" "no working timeout"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== dead stubs and no Python on PATH: the run is uncapped and says so"
# Python is hidden by dead python3/python/py stubs first on PATH (exit 127, as a missing command):
# vulyk_python runs each and rejects it. The rest of PATH stays: on Linux and macOS python sits in
# /usr/bin beside every tool the runner needs, so dropping its directory would strip them too.
mkdir -p "$T/nopy"
for b in python3 python py; do printf '#!/bin/sh\nexit 127\n' > "$T/nopy/$b"; chmod +x "$T/nopy/$b"; done
NOPY="$T/nopy:$PATH"
(PATH="$T/deadbin:$NOPY"; VULYK_PY=; . "$SRC/scripts/lib.sh"; ! vulyk_python) \
  && echo "  ok    the test PATH runs no python" || { echo "::error::the test PATH still runs a python"; fail=1; }
OUT="$(PATH="$T/deadbin:$NOPY" VULYK_PY= VULYK_SUITE_TIMEOUT=1 VULYK_SUITES="bash $S/slow.sh
bash $S/mark.sh done" "$BASH" "$RUN" --jobs 2 2>&1)"; RC=$?
code "uncapped run over the budget -> exit 124 by measured time" 124 "$RC"
expect "warns that it runs uncapped" "no working timeout"
printf '%s\n' "$OUT" | grep -q "^TIMEOUT [3-9]s bash $S/slow.sh\$" && echo "  ok    the slow job ran to the end, reported by its time" \
  || { echo "::error::slow job not TIMEOUT by measured time"; printf '%s\n' "$OUT"; fail=1; }
line "a job inside the budget is ok" ok "bash $S/mark.sh done"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== only latency suites: the parallel list is empty, the run still works"
mkdir -p "$T/only"; printf 'echo fine\n' > "$T/only/inject.test.sh"
run 540 "bash $T/only/inject.test.sh"
code "a latency-only list -> exit 0" 0 "$RC"
line "the latency suite ran" ok "bash $T/only/inject.test.sh"

echo "== --list"
run 540 "bash $S/mark.sh listed" --list
code "--list -> exit 0" 0 "$RC"
[ "$OUT" = "bash $S/mark.sh listed" ] && echo "  ok    --list prints the commands" || { echo "::error::--list printed: $OUT"; fail=1; }
[ -e "$T/started-listed" ] && { echo "::error::--list ran a job"; fail=1; } || echo "  ok    --list runs nothing"
OUT="$(env -u VULYK_SUITES bash "$RUN" --list 2>&1)"
expect "real list: a plain suite" "bash tests/driver.test.sh"
expect "real list: cycle by part" "bash tests/cycle.test.sh --part ship"
expect "real list: telemetry by part" "bash tests/telemetry.test.sh --part telemetry"
expect "real list: council by part" "bash tests/council.test.sh --part verbs"
[ "$(printf '%s\n' "$OUT" | tail -n 2)" = "bash tests/inject.test.sh --part latency
bash tests/intake.test.sh --part latency" ] && echo "  ok    real list: only the latency parts run last" \
  || { echo "::error::real list tail: $(printf '%s\n' "$OUT" | tail -n 2)"; fail=1; }
expect "real list: inject functional among the parallel jobs" "bash tests/inject.test.sh --part functional"
expect "real list: intake functional among the parallel jobs" "bash tests/intake.test.sh --part functional"
printf '%s\n' "$OUT" | grep -qxE 'bash tests/(telemetry|council|cycle|inject|intake)\.test\.sh' \
  && { echo "::error::a split suite is also listed whole"; fail=1; } || echo "  ok    split suites are not listed whole"

echo "== the default --jobs is the core count capped at 12"
mkdir -p "$T/nproc28"; printf '#!/bin/sh\necho 28\n' > "$T/nproc28/nproc"; chmod +x "$T/nproc28/nproc"
OUT="$(PATH="$T/nproc28:$PATH" VULYK_SUITE_TIMEOUT=540 VULYK_SUITES="bash $S/ok.sh" bash "$RUN" 2>&1)"; RC=$?
code "28 cores -> exit 0" 0 "$RC"
expect "28 cores run 12 jobs" "jobs 12"
mkdir -p "$T/nproc3"; printf '#!/bin/sh\necho 3\n' > "$T/nproc3/nproc"; chmod +x "$T/nproc3/nproc"
OUT="$(PATH="$T/nproc3:$PATH" VULYK_SUITE_TIMEOUT=540 VULYK_SUITES="bash $S/ok.sh" bash "$RUN" 2>&1)"
expect "3 cores run 3 jobs" "jobs 3"

echo "== the latency suites run last, alone, one at a time"
L="$T/late"; mkdir -p "$L"
printf 'sleep 2; : > "%s/early-done"\n' "$T" > "$L/early.sh"
for n in inject intake; do
  printf '[ -e "%s/early-done" ] || { echo "%s started beside another job"; exit 1; }\nmkdir "%s/late-lock" 2>/dev/null || { echo "%s overlap"; exit 1; }\nsleep 1\nrmdir "%s/late-lock"\n' \
    "$T" "$n" "$T" "$n" "$T" > "$L/$n.test.sh"
done
LATE_SUITES="bash $L/inject.test.sh
bash $L/intake.test.sh
bash $L/early.sh"
run 540 "$LATE_SUITES" --list
[ "$OUT" = "bash $L/early.sh
bash $L/inject.test.sh
bash $L/intake.test.sh" ] && echo "  ok    --list puts the latency suites last" || { echo "::error::--list order: $OUT"; fail=1; }
run 540 "$LATE_SUITES" --jobs 4
code "latency suites after the rest, no overlap -> exit 0" 0 "$RC"
line "inject ok" ok "bash $L/inject.test.sh"
line "intake ok" ok "bash $L/intake.test.sh"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$LOGDIR" ] && rm -rf "$LOGDIR"

echo "== jobs share one install cache inside the logs dir"
printf 'case "$VULYK_INSTALL_CACHE" in */install-cache) ;; *) echo "cache: [$VULYK_INSTALL_CACHE]"; exit 1 ;; esac\n' > "$S/cache.sh"
run 540 "bash $S/cache.sh"
code "VULYK_INSTALL_CACHE is exported to every job -> exit 0" 0 "$RC"

echo "== bad usage"
run 540 "bash $S/ok.sh" --jobs 0
code "--jobs 0 -> exit 2" 2 "$RC"

[ "$fail" -eq 0 ] && echo "full-suite.test.sh: all ok" || echo "full-suite.test.sh: FAILED"
exit "$fail"
