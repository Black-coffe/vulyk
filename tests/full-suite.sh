#!/usr/bin/env bash
# The whole test suite at once, under one budget (plan fast-verification, `## Contracts` Runner).
#
#   Usage: bash tests/full-suite.sh [--jobs N] [--list]     # from anywhere; runs from the repo root
#
# Jobs: every tests/*.test.sh as `bash tests/<x>.test.sh`; a suite that answers `--list-parts`
# (telemetry, council, cycle) contributes one `--part <name>` job per part instead, so a later re-cut
# needs no edit here. VULYK_SUITES (newline-separated commands) overrides the list - tests only.
# The wall-clock latency suites (inject.test.sh, intake.test.sh: 200 ms medians) go last and start
# only once every other job has ended, one at a time, outside the contended window.
#
# --jobs defaults to the core count capped at 12: at 28 parallel jobs the box's load pushed the
# latency medians past their bound and cut 16 of 31 jobs at the budget (round 1, 2026-10-26); with
# a council suite beside it, 8 jobs hit the budget at 540 s and 12 ended green at 421 s.
# VULYK_INSTALL_CACHE is exported as a directory inside the logs dir: the parts that need a plain
# fresh install copy one install.sh output built once per run (tests/telemetry.test.sh).
#
# VULYK_SUITE_TIMEOUT: the whole run's budget in seconds, default 540, 0 = uncapped. At the
# budget running jobs are killed (`timeout`, set to what is left of the budget) and they and
# every unstarted job are marked TIMEOUT. Without a working `timeout` binary (probe `timeout 5
# true`: System32's timeout.exe fails it) jobs run uncapped, no new job starts after the
# budget, and a job that ends past it is still reported TIMEOUT by its measured time.
#
# Output: one `ok|FAIL|TIMEOUT <seconds>s <command>` line per job as it ends, the last 20 lines
# of each failed or killed job's log, then
#   full suite: <ok> ok, <fail> failed, <timeout> timed out, wall <W>s, budget <B>s, jobs <N>
# Exit 0 all ok, 1 any FAIL, 124 any TIMEOUT (outranks FAIL), 2 bad usage. Logs live in a
# mktemp -d, removed on exit 0, kept and named otherwise.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

JOBS='' LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --jobs) JOBS="${2:-}"; shift ;;
    --jobs=*) JOBS="${1#--jobs=}" ;;
    --list) LIST=1 ;;
    *) echo "usage: bash tests/full-suite.sh [--jobs N] [--list]" >&2; exit 2 ;;
  esac
  shift
done
if [ -z "$JOBS" ]; then
  JOBS="$(nproc 2>/dev/null)"
  case "$JOBS" in ''|*[!0-9]*|0) JOBS=4 ;; esac
  [ "$JOBS" -gt 12 ] && JOBS=12
else
  case "$JOBS" in *[!0-9]*|0) echo "full-suite: --jobs needs a positive number, got '$JOBS'" >&2; exit 2 ;; esac
fi
BUDGET="${VULYK_SUITE_TIMEOUT:-540}"
case "$BUDGET" in ''|*[!0-9]*) echo "full-suite: VULYK_SUITE_TIMEOUT must be seconds, got '$BUDGET'" >&2; exit 2 ;; esac

# --- the job list ------------------------------------------------------------------------
CMDS=()
if [ -n "${VULYK_SUITES:-}" ]; then
  while IFS= read -r c; do [ -n "$c" ] && CMDS+=("$c"); done <<< "$VULYK_SUITES"
else
  for f in tests/*.test.sh; do
    [ -f "$f" ] || continue
    parts=''
    grep -q -- '--list-parts)' "$f" && parts="$(bash "$f" --list-parts 2>/dev/null </dev/null)"
    if [ -n "$parts" ]; then
      while IFS= read -r p; do [ -n "$p" ] && CMDS+=("bash $f --part $p"); done <<< "$parts"
    else
      CMDS+=("bash $f")
    fi
  done
fi
# the latency suites move to the end; FIRST_LATE is the index of the first of them
is_late() { [[ "$1" =~ (^|[ /])(inject|intake)\.test\.sh( |$) ]]; }
EARLY=() LATE=()
for c in "${CMDS[@]}"; do if is_late "$c"; then LATE+=("$c"); else EARLY+=("$c"); fi; done
CMDS=("${EARLY[@]}" "${LATE[@]}")
FIRST_LATE=${#EARLY[@]}
if [ "$LIST" -eq 1 ]; then printf '%s\n' "${CMDS[@]}"; exit 0; fi
NJ=${#CMDS[@]}
[ "$NJ" -gt 0 ] || { echo "full-suite: no jobs found" >&2; exit 2; }

# --- run ---------------------------------------------------------------------------------
TIMEOUT_OK=0
command -v timeout >/dev/null 2>&1 && timeout 5 true </dev/null >/dev/null 2>&1 && TIMEOUT_OK=1
[ "$BUDGET" -gt 0 ] && [ "$TIMEOUT_OK" -eq 0 ] && echo "full-suite: no working timeout - jobs run uncapped, over-budget ones are reported by their time" >&2
LOGS="$(mktemp -d)"
export VULYK_INSTALL_CACHE="$LOGS/install-cache"
SECONDS=0
declare -a PID STATE START   # STATE: pending | running | done
for ((i = 0; i < NJ; i++)); do STATE[i]=pending; done
trap 'for p in "${PID[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; exit 124' INT TERM

start_job() { # start_job <index> - runs in the background, leaves "<rc> <end>" in $LOGS/<i>.rc
  local i="$1" left rc=0
  START[i]=$SECONDS
  (
    if [ "$BUDGET" -gt 0 ] && [ "$TIMEOUT_OK" -eq 1 ]; then
      left=$(( BUDGET - SECONDS )); [ "$left" -lt 1 ] && left=1
      timeout -k 10 "$left" bash -c "${CMDS[i]}" </dev/null >"$LOGS/$i.log" 2>&1 || rc=$?
    else
      bash -c "${CMDS[i]}" </dev/null >"$LOGS/$i.log" 2>&1 || rc=$?
    fi
    echo "$rc $SECONDS" > "$LOGS/$i.rc.tmp" && mv "$LOGS/$i.rc.tmp" "$LOGS/$i.rc"
  ) &
  PID[i]=$!
  STATE[i]=running
}

NOK=0 NFAIL=0 NTO=0 TAILS=()
report() { # report <index> <verdict> <seconds>
  echo "$2 $3s ${CMDS[$1]}"
  case "$2" in
    ok) NOK=$((NOK + 1)) ;;
    FAIL) NFAIL=$((NFAIL + 1)); TAILS+=("$1") ;;
    TIMEOUT) NTO=$((NTO + 1)); [ -f "$LOGS/$1.log" ] && TAILS+=("$1") ;;
  esac
  STATE[$1]=done
}

next=0 running=0
while :; do
  over=0; [ "$BUDGET" -gt 0 ] && [ "$SECONDS" -ge "$BUDGET" ] && over=1
  # unstarted jobs past the budget never start
  if [ "$over" -eq 1 ]; then
    while [ "$next" -lt "$NJ" ]; do report "$next" TIMEOUT 0; next=$((next + 1)); done
  fi
  # a late job starts only when nothing else runs, so the latency suites run alone, in turn
  while [ "$running" -lt "$JOBS" ] && [ "$next" -lt "$NJ" ]; do
    [ "$next" -ge "$FIRST_LATE" ] && [ "$running" -gt 0 ] && break
    start_job "$next"; next=$((next + 1)); running=$((running + 1))
  done
  for ((i = 0; i < next; i++)); do
    [ "${STATE[i]}" = running ] || continue
    if [ -f "$LOGS/$i.rc" ]; then
      wait "${PID[i]}" 2>/dev/null
      read -r rc end < "$LOGS/$i.rc"
      secs=$(( end - START[i] ))
      if [ "$BUDGET" -gt 0 ] && { [ "$end" -gt "$BUDGET" ] || { [ "$TIMEOUT_OK" -eq 1 ] && { [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; }; }; }; then
        report "$i" TIMEOUT "$secs"
      elif [ "$rc" -eq 0 ]; then report "$i" ok "$secs"
      else report "$i" FAIL "$secs"; fi
      running=$((running - 1))
    elif [ "$BUDGET" -gt 0 ] && [ "$TIMEOUT_OK" -eq 1 ] && [ "$SECONDS" -gt $(( BUDGET + 20 )) ]; then
      # backstop: timeout -k should have ended it 10 s past the budget
      kill -9 "${PID[i]}" 2>/dev/null
      report "$i" TIMEOUT $(( SECONDS - START[i] )); running=$((running - 1))
    fi
  done
  [ "$running" -eq 0 ] && [ "$next" -ge "$NJ" ] && break
  sleep 0.25
done

for i in "${TAILS[@]:-}"; do
  [ -n "$i" ] || continue
  echo "--- last 20 lines: ${CMDS[i]}"
  tail -n 20 "$LOGS/$i.log"
done
echo "full suite: $NOK ok, $NFAIL failed, $NTO timed out, wall ${SECONDS}s, budget ${BUDGET}s, jobs $JOBS"
rc=0; [ "$NFAIL" -gt 0 ] && rc=1; [ "$NTO" -gt 0 ] && rc=124
if [ "$rc" -eq 0 ]; then rm -rf "$LOGS"; else echo "logs: $LOGS"; fi
exit "$rc"
