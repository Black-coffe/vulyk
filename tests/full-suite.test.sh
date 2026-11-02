#!/usr/bin/env bash
# The full-suite runner's contract (tests/full-suite.sh), driven through VULYK_SUITES with stub
# scripts: a cap per part (a part at its cap is FAIL, exit 1, never 124), the growth check over 70% of
# the cap, PART lines, --steps / --step K, SKIP (exit 77) and VULYK_STRICT_SKIP, the --jobs cap,
# the uncapped mode, --list, the capped default --jobs, the latency suites last and the shared install
# cache. No real suite runs here except the --list of the real tree.
#
#   Usage: bash tests/full-suite.test.sh     # from anywhere, about 40 s
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
part() { # part <label> <name> <verdict> - a `PART <name> <verdict> <N>s cap <C>s` line, any N
  if printf '%s\n' "$OUT" | grep -qE -- "^PART $2 $3 [0-9]+s cap [0-9]+s"; then echo "  ok    $1"
  else echo "::error::$1 - expected 'PART $2 $3 <N>s cap <C>s' in:"; printf '%s\n' "$OUT" | sed 's/^/        /'; fail=1; fi
}
dropLogs() { local d; d="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"; [ -n "$d" ] && rm -rf "$d"; return 0; }
run() { # run <VULYK_PART_CAP> <suites> [runner args...] - sets OUT and RC
  local c="$1" s="$2"; shift 2
  OUT="$(VULYK_PART_CAP="$c" VULYK_SUITES="$s" bash "$RUN" "$@" 2>&1)"; RC=$?
}

S="$T/stubs"; mkdir -p "$S"
printf 'echo fine\n' > "$S/ok.sh"
printf 'for i in $(seq 1 30); do echo "fail-line-$i"; done\nexit 3\n' > "$S/bad.sh"
printf 'sleep 30\n' > "$S/hang.sh"
printf 'sleep 3\n' > "$S/slow.sh"
printf ': > "%s/started-$1"\n' "$T" > "$S/mark.sh"
printf 'echo "SKIP: no such tool"\nexit 77\n' > "$S/skip.sh"
# lock.sh: fails when another lock.sh holds the lock - two at once means the --jobs cap broke
printf 'mkdir "%s/lock" 2>/dev/null || { echo overlap; exit 1; }\nsleep 2\nrmdir "%s/lock"\n' "$T" "$T" > "$S/lock.sh"

echo "== all ok"
run 300 "bash $S/ok.sh
bash $S/ok.sh"
code "all ok -> exit 0" 0 "$RC"
part "a PART ok line per job" ok ok
expect "summary line" "SUITE: ok "
expect "summary counts parts" "parts=2 skip=0 fail="
reject "logs removed on exit 0" "logs: "

echo "== one failing"
run 300 "bash $S/ok.sh
bash $S/bad.sh"
code "a FAIL -> exit 1" 1 "$RC"
part "FAIL line" bad FAIL
expect "tail of the failed log" "fail-line-30"
expect "tail reaches 20 lines back" "fail-line-11"
reject "tail stops at 20 lines" "fail-line-10"
expect "summary names the failure" "SUITE: FAIL "
expect "summary lists the failed part" "fail=bad"
LOGDIR="$(printf '%s\n' "$OUT" | sed -n 's/^logs: //p')"
if [ -n "$LOGDIR" ] && [ -d "$LOGDIR" ]; then echo "  ok    logs kept and named on exit 1"; rm -rf "$LOGDIR"
else echo "::error::logs not kept/named: '$LOGDIR'"; fail=1; fi

echo "== a part at its cap is FAIL, exit 1, never 124"
before=$SECONDS
run 2 "bash $S/hang.sh
bash $S/bad.sh" --jobs 2
took=$(( SECONDS - before ))
code "a cut part -> exit 1, not 124" 1 "$RC"
expect "the CAP line names the cut part" "cut part hang"
part "CAP line for the hang" hang CAP
part "FAIL line beside it" bad FAIL
expect "summary lists both" "fail=hang,bad"
[ "$took" -lt 20 ] && echo "  ok    the hang was killed (${took}s)" || { echo "::error::runner waited ${took}s for a 30 s hang"; fail=1; }
dropLogs

echo "== a part over 70% of its cap fails the growth check"
run 4 "bash $S/slow.sh"
code "3 s of a 4 s cap -> exit 1" 1 "$RC"
expect "growth line from suite-parts-check" "suite-parts-check: cut part slow"
expect "named as grown" "grew"
dropLogs
run 10 "bash $S/slow.sh"
code "3 s of a 10 s cap is fine -> exit 0" 0 "$RC"

echo "== a cap above 300 is refused"
run 301 "bash $S/ok.sh"
code "VULYK_PART_CAP=301 -> exit 2" 2 "$RC"
run abc "bash $S/ok.sh"
code "a non-number cap -> exit 2" 2 "$RC"

echo "== --jobs 1 runs one at a time, --jobs 2 does not"
run 300 "bash $S/lock.sh
bash $S/lock.sh" --jobs 1
code "--jobs 1: no overlap -> exit 0" 0 "$RC"
expect "--jobs 1 is a step per part" "parts=2"
run 300 "bash $S/lock.sh
bash $S/lock.sh" --jobs 2
code "--jobs 2: the lock catches the overlap -> exit 1" 1 "$RC"
expect "overlap reported" "overlap"
dropLogs

echo "== --steps and --step K"
J5="bash $S/mark.sh a
bash $S/mark.sh b
bash $S/mark.sh c
bash $S/mark.sh d
bash $S/mark.sh e"
run 300 "$J5" --jobs 2 --steps
code "--steps -> exit 0" 0 "$RC"
[ "$OUT" = "3" ] && echo "  ok    5 jobs, jobs 2 -> 3 steps" || { echo "::error::--steps printed: $OUT"; fail=1; }
run 300 "$J5" --jobs 2 --step 2
code "--step 2 -> exit 0" 0 "$RC"
expect "the step's last line" "STEP 2/3: ok "
[ -e "$T/started-c" ] && [ -e "$T/started-d" ] && echo "  ok    step 2 ran its two parts" || { echo "::error::step 2 did not run c and d"; fail=1; }
[ -e "$T/started-a" ] || [ -e "$T/started-b" ] || [ -e "$T/started-e" ] && { echo "::error::step 2 ran another step's part"; fail=1; } || echo "  ok    step 2 ran nothing else"
run 300 "$J5" --jobs 2 --step 4
code "--step beyond the last -> exit 2" 2 "$RC"
run 300 "bash $S/ok.sh
bash $S/bad.sh" --jobs 2 --step 1
code "a failing step -> exit 1" 1 "$RC"
expect "STEP line says FAIL" "STEP 1/1: FAIL "
dropLogs

echo "== SKIP: exit 77 with a SKIP: line"
run 300 "bash $S/skip.sh
bash $S/ok.sh"
code "a skip is not a failure -> exit 0" 0 "$RC"
part "SKIP PART line" skip SKIP
expect "the reason is kept" "no such tool"
expect "skips counted apart" "parts=2 skip=1 fail="
OUT="$(VULYK_STRICT_SKIP=1 VULYK_PART_CAP=300 VULYK_SUITES="bash $S/skip.sh
bash $S/ok.sh" bash "$RUN" 2>&1)"; RC=$?
code "strict SKIP -> exit 1" 1 "$RC"
part "strict SKIP is a FAIL part" skip FAIL
expect "strict summary lists it" "fail=skip"
dropLogs
printf 'exit 77\n' > "$S/mute77.sh"
run 300 "bash $S/mute77.sh"
code "77 without a SKIP: line is a FAIL" 1 "$RC"
dropLogs

echo "== dead timeout and gtimeout stubs, Python present: the cap still holds"
mkdir -p "$T/deadbin"
# Each stub logs its call: the runner probes the cap once, not again inside every job.
for b in timeout gtimeout; do printf '#!/bin/sh\necho %s >> "%s/probes"\nexit 1\n' "$b" "$T" > "$T/deadbin/$b"; chmod +x "$T/deadbin/$b"; done
OUT="$(PATH="$T/deadbin:$PATH" VULYK_PART_CAP=1 VULYK_SUITES="bash $S/hang.sh
bash $S/mark.sh done" bash "$RUN" --jobs 2 2>&1)"; RC=$?
code "over-cap job with dead stubs -> exit 1" 1 "$RC"
printf '%s\n' "$OUT" | grep -qE "^PART hang CAP [0-9]s cap 1s" && echo "  ok    the hanging job is cut at the cap" \
  || { echo "::error::hanging job not capped"; printf '%s\n' "$OUT"; fail=1; }
[ "$(grep -c . "$T/probes" 2>/dev/null)" = 2 ] && echo "  ok    the cap is probed once per run" \
  || { echo "::error::dead stubs probed more than once per run: $(tr '\n' ' ' < "$T/probes" 2>/dev/null)"; fail=1; }
rm -f "$T/probes"
part "a job inside the cap is ok" mark ok
reject "no uncapped warning while python caps" "no working timeout"
dropLogs

echo "== dead stubs and no Python on PATH: the run is uncapped and says so"
mkdir -p "$T/nopy"
for b in python3 python py; do printf '#!/bin/sh\nexit 127\n' > "$T/nopy/$b"; chmod +x "$T/nopy/$b"; done
NOPY="$T/nopy:$PATH"
(PATH="$T/deadbin:$NOPY"; VULYK_PY=; . "$SRC/scripts/lib.sh"; ! vulyk_python) \
  && echo "  ok    the test PATH runs no python" || { echo "::error::the test PATH still runs a python"; fail=1; }
rm -f "$T/started-done"
OUT="$(PATH="$T/deadbin:$NOPY" VULYK_PY= VULYK_PART_CAP=1 VULYK_SUITES="bash $S/slow.sh
bash $S/mark.sh done" "$BASH" "$RUN" --jobs 2 2>&1)"; RC=$?
code "uncapped run over the cap -> exit 1 by measured time" 1 "$RC"
expect "warns that it runs uncapped" "no working timeout"
printf '%s\n' "$OUT" | grep -qE "^PART slow CAP [3-9]s cap 1s" && echo "  ok    the slow job ran to the end, reported CAP by its time" \
  || { echo "::error::slow job not CAP by measured time"; printf '%s\n' "$OUT"; fail=1; }
# Uncapped, a part is judged by whole-second SECONDS against a 1 s cap, so a trivial job on a loaded
# box can measure 1s and read CAP (gate-split-08 finding 1): this check asks only that it ran and was
# reported, never that it ended inside the 1 s window.
[ -e "$T/started-done" ] && printf '%s\n' "$OUT" | grep -qE '^PART mark (ok|CAP) [0-9]+s cap 1s' \
  && echo "  ok    the second job ran and got its PART line" \
  || { echo "::error::uncapped run: the mark job did not run or has no PART line"; printf '%s\n' "$OUT"; fail=1; }
dropLogs

echo "== only latency suites: the parallel list is empty, the run still works"
mkdir -p "$T/only"; printf 'echo fine\n' > "$T/only/inject.test.sh"
run 300 "bash $T/only/inject.test.sh"
code "a latency-only list -> exit 0" 0 "$RC"
part "the latency suite ran" inject ok

echo "== --list"
run 300 "bash $S/mark.sh listed" --list
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
OUT="$(PATH="$T/nproc28:$PATH" VULYK_SUITES="bash $S/ok.sh" bash "$RUN" --steps 2>&1)"; RC=$?
code "28 cores -> exit 0" 0 "$RC"
J14="$(for n in 1 2 3 4 5 6 7 8 9 10 11 12 13; do echo "bash $S/mark.sh x$n"; done)"
OUT="$(PATH="$T/nproc28:$PATH" VULYK_SUITES="$J14" bash "$RUN" --steps 2>&1)"
[ "$OUT" = "2" ] && echo "  ok    28 cores: 13 jobs fall in 2 steps of at most 12" || { echo "::error::28 cores --steps: $OUT"; fail=1; }
mkdir -p "$T/nproc3"; printf '#!/bin/sh\necho 3\n' > "$T/nproc3/nproc"; chmod +x "$T/nproc3/nproc"
OUT="$(PATH="$T/nproc3:$PATH" VULYK_SUITES="$J14" bash "$RUN" --steps 2>&1)"
[ "$OUT" = "5" ] && echo "  ok    3 cores: 13 jobs fall in 5 steps of at most 3" || { echo "::error::3 cores --steps: $OUT"; fail=1; }

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
run 300 "$LATE_SUITES" --list
[ "$OUT" = "bash $L/early.sh
bash $L/inject.test.sh
bash $L/intake.test.sh" ] && echo "  ok    --list puts the latency suites last" || { echo "::error::--list order: $OUT"; fail=1; }
run 300 "$LATE_SUITES" --jobs 4 --steps
[ "$OUT" = "3" ] && echo "  ok    one early step, then one step per latency job" || { echo "::error::latency --steps: $OUT"; fail=1; }
run 300 "$LATE_SUITES" --jobs 4
code "latency suites after the rest, no overlap -> exit 0" 0 "$RC"
part "inject ok" inject ok
part "intake ok" intake ok
dropLogs

echo "== jobs share one install cache inside the logs dir"
printf 'case "$VULYK_INSTALL_CACHE" in */install-cache) ;; *) echo "cache: [$VULYK_INSTALL_CACHE]"; exit 1 ;; esac\n' > "$S/cache.sh"
run 300 "bash $S/cache.sh"
code "VULYK_INSTALL_CACHE is exported to every job -> exit 0" 0 "$RC"

echo "== bad usage"
run 300 "bash $S/ok.sh" --jobs 0
code "--jobs 0 -> exit 2" 2 "$RC"

[ "$fail" -eq 0 ] && echo "full-suite.test.sh: all ok" || echo "full-suite.test.sh: FAILED"
exit "$fail"
