#!/usr/bin/env bash
# The whole test suite in capped parts, run in steps (plan gate-split, `## Contracts` Runner).
#
#   Usage: bash tests/full-suite.sh [--jobs N] [--list | --steps | --step K]   # from anywhere; runs from the repo root
#
# Jobs: every tests/*.test.sh as `bash tests/<x>.test.sh`; a suite that answers `--list-parts`
# (telemetry, council, cycle, ...) contributes one `--part <name>` job per part instead, so a later re-cut
# needs no edit here. VULYK_SUITES (newline-separated commands) overrides the list - tests only.
# Each job is a part with its own hard cap, VULYK_PART_CAP seconds (default and maximum 300; lower is
# allowed, for tests). There is no budget for the whole run: a part at its cap is a FAIL of that part
# ("cut part X", exit 1, never 124); a part over 70% of its cap fails too (scripts/suite-parts-check.sh,
# run on each step's PART lines). Cap by lib.sh's run_capped_as: `timeout`, else `gtimeout`, else python 3;
# with none of the three parts run uncapped, one over its cap is reported CAP by its measured time.
#
# Steps: the K-th chunk of at most --jobs jobs in --list order, started together; the wall-clock latency
# checks (inject.test.sh, intake.test.sh `--part latency`: 200 ms medians, or either suite listed whole)
# go last, each in a step alone, outside the contended window. `--steps` prints the step count S,
# `--step K` runs step K, no flag runs steps 1..S in sequence. Step membership is a pure function of
# the job list and --jobs.
#
# --jobs defaults to the core count capped at 12 (28 parallel jobs pushed the latency medians past
# their bound). VULYK_INSTALL_CACHE is exported as a directory inside the logs dir: the parts that need a
# plain fresh install copy one install.sh output built once per run (tests/telemetry.test.sh, tests/intake.test.sh).
#
# SKIP: a job that prints `SKIP: <reason>` and exits 77 is a SKIP part, counted apart; with
# VULYK_STRICT_SKIP=1 (CI) it is a FAIL.
#
# Output: one `PART <name> <ok|FAIL|SKIP|CAP> <N>s cap <C>s[ - <reason>]` line per part as it ends, the last
# 20 lines of each failed or cut part's log, the growth lines, then
#   STEP K/S: ok|FAIL <N>s                                   (--step K)
#   SUITE: ok|FAIL <N>s parts=<n> skip=<n> fail=<csv>        (no flag)
# Exit 0 all ok, 1 any FAIL, CAP, growth or strict SKIP, 2 bad usage; 124 is never returned. Logs live in a
# mktemp -d, removed on exit 0, kept and named otherwise.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
. "$ROOT/scripts/lib.sh"   # capped_by, run_capped_as (probed once here, not per job)

JOBS='' LIST=0 STEPS=0 STEPK=''
while [ $# -gt 0 ]; do
  case "$1" in
    --jobs) JOBS="${2:-}"; shift ;;
    --jobs=*) JOBS="${1#--jobs=}" ;;
    --list) LIST=1 ;;
    --steps) STEPS=1 ;;
    --step) STEPK="${2:-}"; shift ;;
    --step=*) STEPK="${1#--step=}" ;;
    *) echo "usage: bash tests/full-suite.sh [--jobs N] [--list | --steps | --step K]" >&2; exit 2 ;;
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
PART_CAP="${VULYK_PART_CAP:-300}"
case "$PART_CAP" in ''|*[!0-9]*|0) echo "full-suite: VULYK_PART_CAP must be seconds, 1-300, got '$PART_CAP'" >&2; exit 2 ;; esac
[ "$PART_CAP" -le 300 ] || { echo "full-suite: VULYK_PART_CAP is at most 300 s, got '$PART_CAP': split the part, never raise the cap" >&2; exit 2; }
[ "$STEPS" -eq 1 ] && [ -n "$STEPK" ] && { echo "full-suite: --steps and --step K are exclusive" >&2; exit 2; }
case "$STEPK" in *[!0-9]*) echo "full-suite: --step needs a positive number, got '$STEPK'" >&2; exit 2 ;; esac
[ "$STEPK" = 0 ] && { echo "full-suite: --step needs a positive number, got '0'" >&2; exit 2; }

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
# the latency checks move to the end; FIRST_LATE is the index of the first of them
is_late() { [[ "$1" =~ (^|[ /])(inject|intake)\.test\.sh( --part latency)?$ ]]; }
EARLY=() LATE=()
for c in ${CMDS[@]+"${CMDS[@]}"}; do if is_late "$c"; then LATE+=("$c"); else EARLY+=("$c"); fi; done
CMDS=(${EARLY[@]+"${EARLY[@]}"} ${LATE[@]+"${LATE[@]}"})
FIRST_LATE=${#EARLY[@]}
if [ "$LIST" -eq 1 ]; then printf '%s\n' ${CMDS[@]+"${CMDS[@]}"}; exit 0; fi
NJ=${#CMDS[@]}
[ "$NJ" -gt 0 ] || { echo "full-suite: no jobs found" >&2; exit 2; }

# --- steps: chunks of at most JOBS early jobs, then every latency job alone ----------------
declare -a STEP_FIRST STEP_N
NSTEPS=0
for ((i = 0; i < FIRST_LATE; i += JOBS)); do
  n=$(( FIRST_LATE - i )); [ "$n" -gt "$JOBS" ] && n=$JOBS
  STEP_FIRST[NSTEPS]=$i; STEP_N[NSTEPS]=$n; NSTEPS=$((NSTEPS + 1))
done
for ((i = FIRST_LATE; i < NJ; i++)); do STEP_FIRST[NSTEPS]=$i; STEP_N[NSTEPS]=1; NSTEPS=$((NSTEPS + 1)); done
if [ "$STEPS" -eq 1 ]; then echo "$NSTEPS"; exit 0; fi
if [ -n "$STEPK" ] && [ "$STEPK" -gt "$NSTEPS" ]; then
  echo "full-suite: --step $STEPK, but there are $NSTEPS steps" >&2; exit 2
fi

# --- run ---------------------------------------------------------------------------------
TIMEOUT_OK=0
capped_by && TIMEOUT_OK=1
[ "$TIMEOUT_OK" -eq 0 ] && echo "full-suite: no working timeout - parts run uncapped, over-cap ones are reported by their time" >&2
LOGS="$(mktemp -d)"
export VULYK_INSTALL_CACHE="$LOGS/install-cache"
SECONDS=0
declare -a PID
trap 'for p in "${PID[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; exit 1' INT TERM

part_name() { # part_name <index> - <suite>[:<part>] from the command, else job<index>
  local c="${CMDS[$1]}" n
  if [[ "$c" =~ ([A-Za-z0-9_-]+)(\.test)?\.sh([[:space:]]+--part[[:space:]]+([a-z0-9-]+))? ]]; then
    n="${BASH_REMATCH[1]}"; [ -n "${BASH_REMATCH[4]}" ] && n="$n:${BASH_REMATCH[4]}"
  else n="job$1"; fi
  printf '%s' "$n"
}

start_job() { # start_job <index> - runs in the background, leaves "<rc> <seconds>" in $LOGS/<i>.rc
  local i="$1"
  (
    rc=0 st=$SECONDS
    if [ "$TIMEOUT_OK" -eq 1 ]; then
      run_capped_as "$VULYK_CAP" "$PART_CAP" bash -c "${CMDS[i]}" </dev/null >"$LOGS/$i.log" 2>&1 || rc=$?
    else
      bash -c "${CMDS[i]}" </dev/null >"$LOGS/$i.log" 2>&1 || rc=$?
    fi
    echo "$rc $(( SECONDS - st ))" > "$LOGS/$i.rc.tmp" && mv "$LOGS/$i.rc.tmp" "$LOGS/$i.rc"
  ) &
  PID[i]=$!
}

NPART=0 NSKIP=0 FAILS=''
add_fail() { case ",$FAILS," in *",$1,"*) ;; *) FAILS="${FAILS:+$FAILS,}$1" ;; esac; }

run_step() { # run_step <k> (0-based) - starts the step's parts together, prints their PART lines and tails
  local k="$1" first last i rc secs name verdict why reason tails=() pl="$LOGS/parts.$1" chk line
  first=${STEP_FIRST[k]}; last=$(( first + STEP_N[k] - 1 ))
  : > "$pl"
  for ((i = first; i <= last; i++)); do start_job "$i"; done
  for ((i = first; i <= last; i++)); do
    wait "${PID[i]}" 2>/dev/null
    read -r rc secs < "$LOGS/$i.rc"
    name="$(part_name "$i")"; why=''; NPART=$((NPART + 1))
    if [ "$rc" -eq 77 ] && grep -q '^SKIP:' "$LOGS/$i.log"; then
      reason="$(grep -m1 '^SKIP:' "$LOGS/$i.log" | sed 's/^SKIP:[[:space:]]*//')"
      if [ "${VULYK_STRICT_SKIP:-0}" = 1 ]; then
        verdict=FAIL; why="SKIP under VULYK_STRICT_SKIP=1: $reason"; add_fail "$name"
      else verdict=SKIP; why="$reason"; NSKIP=$((NSKIP + 1)); fi
    elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || { [ "$TIMEOUT_OK" -eq 0 ] && [ "$secs" -ge "$PART_CAP" ]; }; then
      verdict=CAP; why="cut part $name"; add_fail "$name"
    elif [ "$rc" -eq 0 ]; then verdict=ok
    else verdict=FAIL; add_fail "$name"; fi
    if [ "$verdict" = FAIL ] || [ "$verdict" = CAP ]; then tails+=("$i"); fi
    echo "PART $name $verdict ${secs}s cap ${PART_CAP}s${why:+ - $why}" | tee -a "$pl"
  done
  for i in ${tails[@]+"${tails[@]}"}; do
    echo "--- last 20 lines: ${CMDS[i]}"
    tail -n 20 "$LOGS/$i.log"
  done
  if ! chk="$(bash "$ROOT/scripts/suite-parts-check.sh" "$pl")"; then
    printf '%s\n' "$chk"
    while IFS= read -r line; do
      name="${line#suite-parts-check: cut part }"; add_fail "${name%%: *}"
    done <<< "$chk"
  fi
}

if [ -n "$STEPK" ]; then FROM=$((STEPK - 1)) TO=$((STEPK - 1)); else FROM=0 TO=$((NSTEPS - 1)); fi
for ((k = FROM; k <= TO; k++)); do run_step "$k"; done

verdict=ok rc=0
[ -n "$FAILS" ] && { verdict=FAIL; rc=1; }
if [ -n "$STEPK" ]; then echo "STEP $STEPK/$NSTEPS: $verdict ${SECONDS}s"
else echo "SUITE: $verdict ${SECONDS}s parts=$NPART skip=$NSKIP fail=$FAILS"; fi
if [ "$rc" -eq 0 ]; then rm -rf "$LOGS"; else echo "logs: $LOGS"; fi
exit "$rc"
