#!/usr/bin/env bash
# VULYK cycle - the state contract for build -> council -> repair (docs/adr/001-cycle-state-contract.md).
#
#   Usage: scripts/cycle.sh <verb> <spec-dir> [...]
#          scripts/cycle.sh status docs/specs/oauth --json
#          scripts/cycle.sh judge docs/specs/oauth [--commit]
#
# Unlike the report-only gates (ship-check.sh, human-check.sh, ...), this is a machine
# contract: exit codes mean something, and the LAST stdout line of every verb, on every
# exit code, is one JSON object `{"ok":..,"verb":"..","exit":N,"next":".."[,"error":".."]}`
# so no driver ever parses prose. `status --json` prints only that object.
#
# Exit codes: 0 ok · 1 usage · 2 precondition (stderr names it) · 3 paused ·
#             4 malformed report / red council verdict · 5 stale · 6 escalate.
#
# autonomous-cycle-01 implemented `status`, `judge` and `escalate`. autonomous-cycle-03
# added `record-seat` (the D3 report contract: labels, ASK coverage, evidence, taint, the
# two-attempt re-ask), `briefed`, `branch`, `pause`/`resume` and the `PAUSE` guard on every
# mutating verb. autonomous-cycle-04 (this story) adds `close-story` (scope-check + the
# story's `## Verification` x `repeat:`, then `status: done` and a `story(<id>): <title>`
# commit), `open-round` (preconditions, the court worktree, D1's crash/idempotency rules)
# and `reopen` (ceiling + the tier's own ceiling after ESCALATE, convergent-judge); `judge` gains only the court removal - the
# verdict rule and the row schema are unchanged from story 01/03.
#
# 0.18 (docs/adr/013-light-vulyk.md): the roster is `review` at Tier 1-2 and `opus review` at
# Tier 3-4, plus `haiku` when the constitution's Client path is filled (D1); `open-round`
# freezes it as `seats=` in ROUND, with `since=` for round n>1, builds no court when no blind
# seat is required, and carries round n-1's GREEN/N/A blind seats forward (D3). `advance` runs
# claim, seat ingestion and every branch/open-round/judge/repair step in one call (D2);
# `repair` writes the mechanical repair story (D4). `status --json` keeps every pre-0.18 key in
# its old order and appends three at the very end, in this order: `since`, `seat_attempt`,
# `seats` - so no consumer that reads keys by position (or a greedy sed) sees a moved key.
set -u
shopt -s nullglob 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$HERE/lib.sh"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "cycle: CANNOT RUN - not a git repo, so there is no state to derive or record." >&2
  printf '{"ok":false,"verb":"%s","exit":2,"next":"error","error":"not a git repo"}\n' "${1:-}"
  exit 2
}
cd "$ROOT" || exit 2

VERB="${1:-}"
SPEC="${2:-}"
SPEC="${SPEC%/}"

json_escape() { # json_escape <text> -> the JSON-string-safe form of <text>: backslash and
  # quote doubled, tab/newline replaced with \t/\n (R33/N-M4) - the one helper emit() runs
  # every value through, so the last stdout line is one parsable JSON object whatever a
  # hive's `## Commands` cell or a report's own text contains. Order matters: backslash first,
  # or a later substitution's own backslash would be escaped a second time.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

emit() { # emit <true|false> <verb> <exit> <next> [error] [status-json]
  # C5: <status-json> is a whole `status --json` object, appended verbatim as the last key -
  # exit-0 mutating verbs only (see emit_status below); every other call passes nothing and
  # the line is byte-for-byte what it was.
  local ok="$1" verb="$2" ex="$3" next="$4" err="${5:-}" st="${6:-}"
  verb="$(json_escape "$verb")"
  next="$(json_escape "$next")"
  local tail=""
  [ -n "$st" ] && tail=",\"status\":$st"
  if [ -n "$err" ]; then
    err="$(json_escape "$err")"
    printf '{"ok":%s,"verb":"%s","exit":%s,"next":"%s","error":"%s"%s}\n' "$ok" "$verb" "$ex" "$next" "$err" "$tail"
  else
    printf '{"ok":%s,"verb":"%s","exit":%s,"next":"%s"%s}\n' "$ok" "$verb" "$ex" "$next" "$tail"
  fi
}

emit_status() { # emit_status <verb> <spec-dir> [next] - C5: the exit-0 line of a mutating verb,
  # with the post-verb `status --json` object carried under `status`. Called after every write
  # the verb makes, including its `--commit`, so the carried head/stale/next describe the
  # repository the caller is about to act on - one clerk call instead of two. cmd_status derives
  # everything from disk; nothing is verified or scope-checked again here. <next> stays the
  # verb's own value (byte-for-byte what a pre-C5 driver read); omit it to take status.next.
  local verb="$1" spec="$2" next="${3:-}" st rc
  st="$(cmd_status "$spec")"; rc=$?
  [ -n "$next" ] || next="$(json_field "$st" next)"
  # C5 addendum (Minor 10): a carried `status` is a status object or absent, never an error
  # envelope. If cmd_status took its usage branch (non-zero, `{"ok":false,"verb":"status",...}`
  # on stdout), emit the pre-C5 five-key line - byte-for-byte what a pre-C5 caller read.
  if [ "$rc" -ne 0 ] || [ -z "$st" ] || printf '%s' "$st" | grep -q '"ok":false'; then
    emit true "$verb" 0 "$next"
    return
  fi
  emit true "$verb" 0 "$next" "" "$st"
}

usage() {
  echo "cycle: usage: $0 <verb> <spec-dir> [...]" >&2
  emit false "${VERB:-}" 1 "error" "usage: $0 <verb> <spec-dir> [...]"
  exit 1
}

redact_note() { # redact_note <text> -> <text> piped through scripts/redact.sh (N-m7) - a
  # free-text note (escalate's CLI arg, judge's env-absence note) never reaches the ledger
  # or the plan's ## Needs a human block unmasked. redact.sh always exits 0 and degrades to
  # `cat` if its own tools are missing, so this never blocks a write.
  printf '%s' "$1" | bash "$HERE/redact.sh" 2>/dev/null
}

council_append_line() { # council_append_line <plan> <text> - C7: the **Council:** line lands
  # right after the last existing one (or replaces the template's unfilled placeholder when
  # there is none yet), never at the file's true EOF - a round can be judged after an earlier
  # ESCALATE already wrote ## Needs a human below the last Council line, and a plain `>>`
  # would land the new line under that section instead of in round order.
  local plan="$1" text="$2" tmp
  [ -f "$plan" ] || return 0
  tmp="$plan.tmp.$$"
  if grep -qE '^\*\*Council:\*\*[[:space:]]*<' "$plan" 2>/dev/null; then
    awk -v t="$text" '!done && /^\*\*Council:\*\*[[:space:]]*</ { print t; done=1; next } { print }' "$plan" > "$tmp" && mv "$tmp" "$plan"
    return 0
  fi
  if grep -qE '^\*\*Council:\*\*' "$plan" 2>/dev/null; then
    awk -v t="$text" '{ lines[NR]=$0; if ($0 ~ /^\*\*Council:\*\*/) last=NR } END { for (i=1;i<=NR;i++) { print lines[i]; if (i==last) print t } }' "$plan" > "$tmp" && mv "$tmp" "$plan"
    return 0
  fi
  printf '%s\n' "$text" >> "$plan"
}

marker() { # marker <plan.md> <Name> -> the value of the LAST matching line, empty if
  # absent/placeholder - overrides lib.sh's first-match version (LR25): `**Council:**` is the
  # one marker `council_append_line` lets accumulate one line per round, so reading it must
  # return the newest round's line, not the first one ever written; every other marker here
  # (Briefed/Approved/Branch/Shipped) is still written at most once, so the change is a no-op
  # for them.
  # Read in bash, not grep|tail|sed: status reads four markers per call (and compute_stage four
  # more), and on Windows each pipeline stage is a process - same last match, same stripping.
  local prefix="**$2:**" line v=""
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in "$prefix"*) v="${line#"$prefix"}" ;; esac
  done < "$1"
  v="${v%$'\r'}" # a CRLF plan.md: the old pipeline never returned the CR here either
  v="${v#"${v%%[![:space:]]*}"}"
  case "$v" in ''|'<'*) return 0 ;; esac
  printf '%s' "$v"
}

pause_guard() { # pause_guard <spec> <verb-label> - exits 3 before anything mutates if PAUSEd;
  # returns (does not exit) when clear. `status`, `pause`, `resume`, `release` never call this.
  local spec="$1" verb="$2"
  [ -n "$spec" ] && [ -f "$spec/PAUSE" ] || return 0
  echo "cycle: $(slug_of "$spec") - PAUSE present, $verb refuses to act." >&2
  local first_line; first_line="$(head -1 "$spec/PAUSE" 2>/dev/null)"
  emit false "$verb" 3 paused "paused: $first_line"
  exit 3
}

driver_stamp() { # driver_stamp <spec> -> the stamp= value in <spec>/DRIVER, empty if absent
  [ -f "$1/DRIVER" ] || return 0
  sed -n 's/^stamp=//p' "$1/DRIVER" | head -1
}

driver_guard() { # driver_guard <spec> <verb-label> <stamp-opt> - exits 2 before anything
  # mutates if DRIVER exists and <stamp-opt> is absent or differs from its stamp= (ADR-004/K3).
  # Called right after pause_guard on open-round, record-seat, judge, close-story; no-op when
  # no DRIVER file exists.
  local spec="$1" verb="$2" stamp="${3:-}" holder
  holder="$(driver_stamp "$spec")"
  [ -n "$holder" ] || return 0
  [ -n "$stamp" ] && [ "$stamp" = "$holder" ] && return 0
  echo "cycle: $(slug_of "$spec") - DRIVER held by $holder, $verb refuses to act." >&2
  emit false "$verb" 2 error "held by $holder"
  exit 2
}

[ -n "$VERB" ] || usage

# --- small parsers shared by status and judge ---------------------------------------------

fm_field() { # fm_field <story-file> <key> - a frontmatter "key: value" line, raw value. The
  # first line whose text before its first `:` is exactly <key>; the value runs from past that
  # colon and its spaces to the next colon, cut at a `#` comment, trimmed - byte for byte what
  # `awk -F': *' '$1 == k { ... $2 ... }'` printed before 0.18, without a process per call.
  local k="$2" line
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [ "${line%%:*}" = "$k" ] || continue
    fm_line_value "$line"
    printf '%s\n' "$FMV"
    return 0
  done < "$1"
}

fm_line_value() { # fm_line_value <line> -> FMV: the value fm_field reads off a matching line
  local v
  case "$1" in *:*) v="${1#*:}" ;; *) v="" ;; esac
  v="${v#"${v%%[! ]*}"}"
  v="${v%%:*}"
  v="${v%%#*}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  FMV="$v"
}

fm_status_wave() { # fm_status_wave <story-file> -> FM_STATUS, FM_WAVE, each by fm_field's rule
  # (the first line keyed exactly so), in one read and no subshell - status needs both of every
  # story, and asked per wave it used to spawn four processes per story per wave.
  local line k got_s=0 got_w=0
  FM_STATUS=""; FM_WAVE=""
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    k="${line%%:*}"
    case "$k" in
      status) [ "$got_s" = 1 ] && continue; fm_line_value "$line"; FM_STATUS="$FMV"; got_s=1 ;;
      wave)   [ "$got_w" = 1 ] && continue; fm_line_value "$line"; FM_WAVE="$FMV"; got_w=1 ;;
      *) continue ;;
    esac
    [ "$got_s" = 1 ] && [ "$got_w" = 1 ] && return 0
  done < "$1"
}

story_status_for_id() { # story_status_for_id <spec> <story-id>
  local spec="$1" id="$2" f
  for f in "$spec"/*.md; do
    [ -f "$f" ] || continue
    is_story_file "$f" || continue
    [ "$(fm_field "$f" story)" = "$id" ] && { fm_field "$f" status; return; }
  done
}

asks_count() { # asks_count <spec-dir> -> A, the number of `## Asks` items in brief.md (C8)
  awk '
    /^##[[:space:]]+Asks[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                    { if (inblock) exit }
    inblock && /^[0-9]+\.[[:space:]]/   { c++ }
    END { print c+0 }
  ' "$1/brief.md" 2>/dev/null
}

current_round_dir() { # current_round_dir <spec> -> the highest round-N dir, or nothing
  local spec="$1" d best=0 bestdir="" n
  for d in "$spec"/council/round-*; do
    [ -d "$d" ] || continue
    n="${d##*/round-}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    if [ "$n" -gt "$best" ]; then best="$n"; bestdir="$d"; fi
  done
  [ -n "$bestdir" ] && printf '%s' "$bestdir"
}

round_field() { # round_field <round-dir> <key> - a ROUND file's first "key=value" line, read in
  # bash (status reads several per call; each sed|head was two processes on Windows)
  local line
  [ -f "$1/ROUND" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in "$2="*) printf '%s\n' "${line#"$2="}"; return 0 ;; esac
  done < "$1/ROUND"
}

tier_of() { # tier_of <spec> -> the spec's tier 1-4, from plan.md's first "**Tier:**" line
  # (autonomous-cycle-18, C15). That line is "**Tier:** 4 \xc2\xb7 **Spec slug:** ..." on one
  # line, so this parses only the leading digit - never marker(), which would return the
  # whole rest of the line as the value. Absent or unparsable prints nothing (R21/m-1,
  # autonomous-cycle-19): there is no default tier anymore - a silent 4 used to buy the
  # largest court unasked, and this function never writes (status calls it on every read;
  # m-1 is exactly this journal write, now gone - journal.md is untouched by a status call).
  # Only the first **Tier:** line counts, as grep -m1 did; read in bash, no process.
  local line
  [ -f "$1/plan.md" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '**Tier:**'*)
        line="${line#'**Tier:**'}"; line="${line#"${line%%[! ]*}"}"
        case "$line" in [1-4]*) printf '%s\n' "${line:0:1}" ;; esac
        return 0 ;;
    esac
  done < "$1/plan.md"
}

round_tier() { # round_tier <spec> <round-dir> -> the round's frozen tier= (open-round writes
  # it at open time, C15); tier_of() as a fallback for a round opened before this story.
  local spec="$1" rd="$2" t
  t="$(round_field "$rd" tier)"
  case "$t" in [1-4]) printf '%s' "$t"; return ;; esac
  tier_of "$spec"
}

tier_ceiling() { # tier_ceiling <tier> -> the default round ceiling for a tier (convergent-judge
  # ask 1): 1 for Tier 1, 2 for Tier 2, 3 for Tier 3-4 and anything else. The one place the
  # mapping lives; a council/CEILING file still wins over it, and `reopen` adds it again.
  case "$1" in
    1) printf '1' ;;
    2) printf '2' ;;
    *) printf '3' ;;
  esac
}

required_seats_for_tier() { # required_seats_for_tier <tier> -> the space-separated seats a
  # round of this tier must have before judge will run (ADR-013 D1, superseding C15's roster):
  # one reviewer below Tier 3; the intent seat and the reviewer from Tier 3, plus the black box
  # only where a client can actually be walked. 3 and 4 (and any value outside 1-4, which
  # tier_of never produces) share one roster - Tier 4's second reviewer folds into `review`.
  # `sonnet` is in no roster any more; record-seat still accepts it so old rounds stay readable.
  case "$1" in
    1|2) printf 'review' ;;
    *)
      if client_path_filled "$(constitution_file "$ROOT")"; then printf 'haiku opus review'
      else printf 'opus review'
      fi ;;
  esac
}

round_required_seats() { # round_required_seats <spec> <round-dir> -> the round's frozen seats=
  # list (ADR-013 D3: written once by open-round, so a Profile or plan edit mid-round never
  # changes what an open round requires); a round opened before 0.18 has no seats= line and
  # falls back to the tier's roster.
  local spec="$1" rd="$2" line
  if [ -f "$rd/ROUND" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in seats=*) printf '%s' "${line#seats=}"; return ;; esac
    done < "$rd/ROUND"
  fi
  required_seats_for_tier "$(round_tier "$spec" "$rd")"
}

is_required_seat() { # is_required_seat <seat> <required-list> -> 0 iff seat is in the list
  case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

missing_required_seats() { # missing_required_seats <round-dir> <required-list> -> space-sep
  # required seats with no accepted report yet, in canonical haiku/sonnet/opus/review order.
  # A seat that exhausted both attempts (attempt-2 exists, no final <seat>.md) is ABSENT, not
  # missing (R3/C-2, autonomous-cycle-19) - it must not block `next` from ever reaching `judge`.
  local rd="$1" required="$2" seat out=""
  for seat in haiku sonnet opus review; do
    [ -f "$rd/$seat.md" ] && continue
    [ -f "$rd/$seat.attempt-2.md" ] && continue
    is_required_seat "$seat" "$required" && out="$out $seat"
  done
  printf '%s' "${out# }"
}

seat_is_carried() { # seat_is_carried <seat-file> -> 0 iff its header says it was carried forward
  local l=""
  [ -f "$1" ] || return 1
  IFS= read -r l < "$1"
  case "$l" in *'carried: round '*) return 0 ;; esac
  return 1
}

seat_attempt_count() { # seat_attempt_count <round-dir> <seat> -> every stored file for the seat
  # this round (LR19: a re-ask counts 2); a carried report is no dispatch of this round, so it
  # never counts (ADR-013 D3) - the ledger's attempts stays "how many times a seat was asked".
  local rd="$1" seat="$2" n=0
  [ -f "$rd/$seat.md" ] && ! seat_is_carried "$rd/$seat.md" && n=$((n+1))
  [ -f "$rd/$seat.attempt-1.md" ] && n=$((n+1))
  [ -f "$rd/$seat.attempt-2.md" ] && n=$((n+1))
  printf '%s' "$n"
}

seat_next_attempt() { # seat_next_attempt <round-dir> <seat> -> the attempt a missing seat's next
  # report is recorded as: 2 once attempt-1 was rejected, else 1 - the same rule record-seat
  # applies, so status's seat_attempt and advance --ingest name the file record-seat will take.
  if [ -f "$1/$2.attempt-1.md" ]; then printf '2'; else printf '1'; fi
}

dirty_outside_paperwork() { # dirty_outside_paperwork -> the `git status --porcelain` lines that
  # are not the cycle's own paperwork (is_paperwork_path), one per line; empty means clean.
  # The one predicate open-round and claim share (ADR-013 D5). -uall lists a directory with
  # nothing tracked in it (a fresh hive's memory/learnings/) file by file, instead of one
  # `?? <dir>/` line the one-level whitelist would reject (C2 addendum).
  local status_out line
  status_out="$(git status --porcelain -uall 2>/dev/null)"
  [ -n "$status_out" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    is_paperwork_path "${line:3}" || printf '%s\n' "$line"
  done <<EOF
$status_out
EOF
}

round_is_stale() { # round_is_stale <spec> <n> - the one staleness rule (autonomous-cycle-17):
  # a round is stale iff its ROUND file's recorded head differs from current HEAD AND the
  # commits between them are not paperwork_only() (lib.sh, C1) - so a round's own open-round/
  # record-seat/judge paperwork commit never stales it, only a real code move does. Every
  # cmd_record_seat/cmd_status/cmd_open_round staleness decision goes through this, instead of
  # each reimplementing (or forgetting) the paperwork exemption.
  local spec="$1" n="$2" rhead head_now
  rhead="$(round_field "$spec/council/round-$n" head)"
  [ -n "$rhead" ] || return 1
  head_now="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  [ "$rhead" != "$head_now" ] || return 1
  ! paperwork_only "$ROOT" "$rhead" "$head_now" 2>/dev/null
}

row_exists() { # row_exists <slug> <round> - "round":$2 is followed by a comma in every row
  # (the next key is always "verdict"), so the trailing comma anchors the match: without it
  # round 1 is a substring of round 10/11/19/... (LR21/r2m1).
  [ -f memory/stats/council.jsonl ] || return 1
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl | grep -qF "\"round\":$2,"
}

newest_row() { # newest_row <slug> -> the last council.jsonl line for this spec, or empty
  [ -f memory/stats/council.jsonl ] || return 0
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl | tail -1
}

red_rounds() { # red_rounds <slug> [<exclude-round>] -> how many distinct rounds of this spec
  # ended RED (convergent-judge-07, plan ## Contracts: RED rounds): a council.jsonl row with
  # verdict RED, or ESCALATE with escalate ceiling|no-progress. GREEN, STALE and ESCALATE
  # env|half rows never count - the count every ceiling gate compares against.
  [ -f memory/stats/council.jsonl ] || { echo 0; return; }
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl \
    | grep -E '"verdict":"RED"|"verdict":"ESCALATE".*"escalate":"(ceiling|no-progress)"' \
    | sed -n 's/.*"round":\([0-9][0-9]*\),.*/\1/p' | sort -u | grep -vxF "${2:-x}" | grep -c . || true
}

round_row() { # round_row <slug> <round> -> the last council.jsonl line for that round, or empty
  # (a round can carry two rows - a RED, then a ceiling ESCALATE - the newest is its outcome)
  [ -f memory/stats/council.jsonl ] || return 0
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl | grep -F "\"round\":$2," | tail -1
}

json_num_array() { # json_num_array <json-line> <key> -> "2 5" from "key":[2,5]; a missing key is empty
  printf '%s' "$1" | sed -n "s/.*\"$2\":\[\([^]]*\)\].*/\1/p" | tr ',' ' '
}

json_field() { # json_field <json-line> <key> - a flat top-level string or number value; like
  # the sed it replaced, the greedy `.*` takes the LAST "<key>": in the line. A bash regex, so
  # no process per call (status and emit_status call this on every ledger row they read).
  local re_s='.*"'"$2"'":"([^"]*)"' re_n='.*"'"$2"'":([0-9]+)'
  if [[ $1 =~ $re_s ]]; then printf '%s' "${BASH_REMATCH[1]}"
  elif [[ $1 =~ $re_n ]]; then printf '%s' "${BASH_REMATCH[1]}"
  fi
}

json_str_array() { # json_str_array "a b c" -> "a","b","c"  (no embedded spaces per element)
  local s="$1" out="" x
  for x in $s; do out="${out:+$out,}\"$x\""; done
  printf '%s' "$out"
}

sort_num_list() { # sort_num_list "5 2" -> "2 5"
  local s="$1"
  [ -n "$(printf '%s' "$s" | tr -d '[:space:]')" ] || return 0
  printf '%s\n' $s | sort -n | tr '\n' ' ' | sed 's/ *$//'
}

json_num_csv() { # json_num_csv "2 5" -> "2,5"
  local s="$1" out="" x
  for x in $s; do out="${out:+$out,}$x"; done
  printf '%s' "$out"
}

# --- status --------------------------------------------------------------------------------

cmd_status() {
  local SPEC="$1"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 status <spec-dir> [--json]" >&2
    emit false status 1 error "usage"
    exit 1
  }
  local SLUG PLAN HEAD PACK
  SLUG="$(slug_of "$SPEC")"
  PLAN="$SPEC/plan.md"
  HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  PACK="$(pack_fingerprint "$SPEC")"

  local BRIEFED_V="" APPROVED_V="" BRANCH_V="" SHIPPED_V=""
  if [ -f "$PLAN" ]; then
    BRIEFED_V="$(marker "$PLAN" Briefed)"
    APPROVED_V="$(marker "$PLAN" Approved)"
    BRANCH_V="$(marker "$PLAN" Branch)"
    SHIPPED_V="$(marker "$PLAN" Shipped)"
  fi
  local BRIEFED_B=false APPROVED_B=false SHIPPED_B=false PAUSED_B=false
  { [ -n "$BRIEFED_V" ] || [ -n "$APPROVED_V" ]; } && BRIEFED_B=true
  [ -n "$APPROVED_V" ] && APPROVED_B=true
  [ -n "$SHIPPED_V" ] && SHIPPED_B=true
  [ -f "$SPEC/PAUSE" ] && PAUSED_B=true
  local BRANCH_JSON="null"; [ -n "$BRANCH_V" ] && BRANCH_JSON="\"$BRANCH_V\""

  # --- stories: counts, and the lowest wave that is either dispatchable or closeable -------
  # One read per story (status and wave together), kept in arrays for the wave walk below -
  # the same answers the per-wave re-reads gave, without re-reading every story per wave.
  local TODO=0 PROG=0 DONE=0 BLOCKED=0 f st
  local BUILD_WAVE="" CLOSE_FILE="" WAVE_STORIES="" MAXWAVE=0 wv
  local -a S_FILE=() S_ST=() S_WV=()
  for f in "$SPEC"/*.md; do
    [ -f "$f" ] || continue
    is_story_file "$f" || continue
    fm_status_wave "$f"; st="$FM_STATUS"; wv="$FM_WAVE"; [ -n "$wv" ] || wv=1
    case "$st" in
      done) DONE=$((DONE+1)) ;;
      blocked) BLOCKED=$((BLOCKED+1)) ;;
      in-progress) PROG=$((PROG+1)) ;;
      *) TODO=$((TODO+1)) ;;
    esac
    [ "$wv" -gt "$MAXWAVE" ] 2>/dev/null && MAXWAVE="$wv"
    S_FILE+=("$f"); S_ST+=("$st"); S_WV+=("$wv")
  done
  local w i
  for w in $(seq 1 "${MAXWAVE:-0}" 2>/dev/null); do
    local ready="" any_todo=0 any_prog="" prog_files=""
    for i in "${!S_FILE[@]}"; do
      [ "${S_WV[$i]}" = "$w" ] || continue
      f="${S_FILE[$i]}"; st="${S_ST[$i]}"
      case "$st" in
        todo)
          any_todo=1
          local blockers_done=1 b bb
          bb="$(fm_field "$f" blocked_by | tr -d '[]' | tr ',' ' ')"
          for b in $bb; do
            b="$(printf '%s' "$b" | sed 's/^ *//; s/ *$//')"
            [ -n "$b" ] || continue
            [ "$(story_status_for_id "$SPEC" "$b")" = "done" ] || blockers_done=0
          done
          # LR31: an unready todo (a blocker not yet done) is never listed - it is not
          # dispatchable, and re-dispatching it would just re-fail the same blocker.
          [ "$blockers_done" -eq 1 ] && ready="$ready $f"
          ;;
        in-progress)
          [ -n "$any_prog" ] || any_prog="$f"
          prog_files="$prog_files $f"
          ;;
      esac
    done
    if [ -n "$ready" ]; then BUILD_WAVE="$w"; WAVE_STORIES="$ready$prog_files"; break; fi
    if [ "$any_todo" -eq 0 ] && [ -n "$any_prog" ]; then CLOSE_FILE="$any_prog"; break; fi
  done
  local WAVE_JSON="null"; [ -n "$BUILD_WAVE" ] && WAVE_JSON="$BUILD_WAVE"
  local WAVE_STORIES_JSON="" wsf
  for wsf in $WAVE_STORIES; do
    WAVE_STORIES_JSON="${WAVE_STORIES_JSON:+$WAVE_STORIES_JSON,}$(wave_story_json "$wsf")"
  done

  # --- the open round, if any ---------------------------------------------------------------
  local RD ROUND_N=0 CEILING=3 COURT_JSON="null" OPEN_B=false MISSING="" STALE_B=false
  local REQUIRED="" SINCE_JSON="null" SEAT_ATTEMPT_JSON=""
  RD="$(current_round_dir "$SPEC")"
  # N-m3: a round directory without its own ROUND file (a crash before open-round's last write)
  # is not an open round - it reads exactly like no round at all, so `next` falls through to
  # the final "open-round" case below instead of a stale/dispatch/judge state built on empty
  # round_field() reads.
  if [ -n "$RD" ] && [ -f "$RD/ROUND" ]; then
    ROUND_N="${RD##*/round-}"
    local RCOURT
    RCOURT="$(round_field "$RD" court)"
    CEILING="$(round_field "$RD" ceiling)"; [ -n "$CEILING" ] || CEILING="$(tier_ceiling "$(round_tier "$SPEC" "$RD")")"
    [ -n "$RCOURT" ] && COURT_JSON="\"$RCOURT\""
    if ! row_exists "$SLUG" "$ROUND_N"; then
      OPEN_B=true
      local seat
      REQUIRED="$(round_required_seats "$SPEC" "$RD")"
      MISSING="$(missing_required_seats "$RD" "$REQUIRED")"
      for seat in $MISSING; do
        SEAT_ATTEMPT_JSON="${SEAT_ATTEMPT_JSON:+$SEAT_ATTEMPT_JSON,}\"$seat\":$(seat_next_attempt "$RD" "$seat")"
      done
      # D2/D3: the reviewer of round n>1 judges since..head. A pre-0.18 round has no since=
      # line, so the previous round's own recorded head stands in for it.
      if [ "$ROUND_N" -gt 1 ]; then
        local SINCE_V; SINCE_V="$(round_field "$RD" since)"
        [ -n "$SINCE_V" ] || SINCE_V="$(round_field "$SPEC/council/round-$((ROUND_N-1))" head)"
        [ -n "$SINCE_V" ] && SINCE_JSON="\"$SINCE_V\""
      fi
      # R2: staleness is reported whether or not a seat file exists yet - a round can go stale
      # (a real commit lands) before any seat is dispatched, and `next` must still say
      # open-round, never dispatch:/judge, so record-seat's own exit-5 refusal is never the
      # first place a driver learns the round is stale.
      round_is_stale "$SPEC" "$ROUND_N" && STALE_B=true
    fi
  fi

  # --- tier (R12/C3, autonomous-cycle-19): the open round's frozen tier= while one is open,
  # else the plan's own **Tier:** line, else null - never a silent default (R21/m-1) ---------
  local TIER_JSON="null" TIER_V=""
  if [ "$OPEN_B" = true ]; then TIER_V="$(round_tier "$SPEC" "$RD")"
  else TIER_V="$(tier_of "$SPEC")"
  fi
  case "$TIER_V" in [1-4]) TIER_JSON="$TIER_V" ;; esac

  # --- newest council.jsonl row for this spec -----------------------------------------------
  local NEWEST NEWEST_VERDICT="" NEWEST_ROUND="" NEWEST_PACK="" NEWEST_HEAD="" NEWEST_REVIEW="" RED_LIST=""
  local VERDICT_JSON="null" REVIEW_JSON="null"
  NEWEST="$(newest_row "$SLUG")"
  if [ -n "$NEWEST" ]; then
    NEWEST_VERDICT="$(json_field "$NEWEST" verdict)"
    NEWEST_ROUND="$(json_field "$NEWEST" round)"
    NEWEST_PACK="$(json_field "$NEWEST" pack)"
    NEWEST_HEAD="$(json_field "$NEWEST" head)"
    NEWEST_REVIEW="$(json_field "$NEWEST" review)"
    VERDICT_JSON="\"$NEWEST_VERDICT\""
    REVIEW_JSON="\"$NEWEST_REVIEW\""  # R30/C3: newest row's review verdict verbatim (PASS|BLOCK|ABSENT|""), null with no row
    RED_LIST="$(printf '%s' "$NEWEST" | sed -n 's/.*"red":\[\([^]]*\)\].*/\1/p' | tr ',' ' ')"
  fi

  # --- round_dir (R25): the open round's directory while one is open, else the newest row's,
  # else null - it must never be null during a round (lead-review minor 18, live on this spec) -
  local ROUND_DIR_JSON="null"
  if [ "$OPEN_B" = true ]; then
    ROUND_DIR_JSON="\"$RD\""
  elif [ -n "$NEWEST_ROUND" ]; then
    ROUND_DIR_JSON="\"$SPEC/council/round-$NEWEST_ROUND\""
  fi

  # --- next: first match wins (C3) ----------------------------------------------------------
  local NEXT=""
  if [ "$SHIPPED_B" = true ]; then NEXT="shipped"
  elif [ "$PAUSED_B" = true ]; then NEXT="paused"
  elif [ "$BRIEFED_B" = false ]; then NEXT="briefed"
  elif [ -z "$BRANCH_V" ]; then NEXT="branch"
  elif [ -n "$BUILD_WAVE" ]; then NEXT="build:$BUILD_WAVE"
  elif [ -n "$CLOSE_FILE" ]; then NEXT="close-story:$CLOSE_FILE"
  elif [ "$OPEN_B" = true ]; then
    if [ "$STALE_B" = true ]; then NEXT="open-round"
    elif [ -n "$MISSING" ]; then NEXT="dispatch:$(printf '%s' "$MISSING" | tr ' ' ',')"
    else NEXT="judge"
    fi
  elif [ "$NEWEST_VERDICT" = "ESCALATE" ] && ! reopen_names_round "$SPEC" "$NEWEST_ROUND"; then
    NEXT="escalated"
  elif [ "$NEWEST_VERDICT" = "GREEN" ] && [ "$NEWEST_PACK" = "$PACK" ] && ! round_is_stale "$SPEC" "$NEWEST_ROUND"; then
    NEXT="green"
  elif [ "$NEWEST_VERDICT" = "RED" ] && ! round_is_stale "$SPEC" "$NEWEST_ROUND"; then
    NEXT="repair"
  elif [ "$NEWEST_VERDICT" = "ESCALATE" ] && [ "$(json_field "$NEWEST" escalate)" != "env" ] \
    && ! round_is_stale "$SPEC" "$NEWEST_ROUND"; then
    # ADR-013 D3: a reopened ESCALATE (the branch above let it through) is a verdict the owner
    # wants repaired - ceiling, half and no-progress rows name real RED asks. Only `env` (the
    # round itself failed) and a stale round fall through to a fresh round.
    NEXT="repair"
  else
    NEXT="open-round"
  fi

  printf '{"spec":"%s","slug":"%s","stage":"%s","next":"%s","briefed":%s,"approved":%s,"branch":%s,"head":"%s","pack":"%s","stories":{"todo":%s,"in-progress":%s,"done":%s,"blocked":%s},"wave":%s,"wave_stories":[%s],"round":%s,"ceiling":%s,"tier":%s,"open":%s,"court":%s,"missing":[%s],"stale":%s,"verdict":%s,"review":%s,"red":[%s],"round_dir":%s,"paused":%s,"shipped":%s,"since":%s,"seat_attempt":{%s},"seats":[%s]}\n' \
    "$SPEC" "$SLUG" "$(compute_stage "$SPEC" "$PLAN" "$BRIEFED_B" "$BRANCH_V" "$((TODO+PROG+DONE+BLOCKED))" "$DONE" "$NEWEST_VERDICT" "$SHIPPED_B")" \
    "$NEXT" "$BRIEFED_B" "$APPROVED_B" "$BRANCH_JSON" "$HEAD" "$PACK" \
    "$TODO" "$PROG" "$DONE" "$BLOCKED" \
    "$WAVE_JSON" "$WAVE_STORIES_JSON" \
    "$ROUND_N" "$CEILING" "$TIER_JSON" "$OPEN_B" "$COURT_JSON" "$(json_str_array "$MISSING")" "$STALE_B" \
    "$VERDICT_JSON" "$REVIEW_JSON" "$(json_num_csv "$RED_LIST")" "$ROUND_DIR_JSON" "$PAUSED_B" "$SHIPPED_B" \
    "$SINCE_JSON" "$SEAT_ATTEMPT_JSON" "$(json_str_array "$REQUIRED")"
}

compute_stage() { # compute_stage <spec> <plan> <briefed:true|false> <branch> <stories> <done>
  # <newest-verdict> <shipped:true|false> - a best-effort mirror of state.sh's ladder, extended
  # with the council stage (C9). cmd_status (its one caller) passes what it has already read -
  # the markers, the story counts, the newest row's verdict - so none of it is read twice.
  local spec="$1" plan="$2" briefed="$3" branch="$4" total="$5" done_n="$6" v="$7" shipped="$8"
  local stage="01-spec" line checked=""
  [ -f "$spec/brief.md" ] || { echo "$stage"; return; }
  if [ -f "$plan" ]; then
    stage="02-planned"
    [ "$briefed" = true ] && stage="02-approved"
    [ -n "$branch" ] && stage="03-building"
  fi
  [ "$stage" = "03-building" ] && [ "$total" -gt 0 ] && [ "$done_n" -eq "$total" ] && stage="03-built"
  [ -n "$v" ] && stage="04-council:$v"
  # the last **Checked:** line that is not the template's `<...>` placeholder
  if [ -f "$plan" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in '**Checked:** <'*) ;; '**Checked:**'*) checked="$line" ;; esac
    done < "$plan"
  fi
  case "$checked" in
    *ACCEPTED*) stage="05-checked" ;;
    *REJECTED*) stage="05-rejected" ;;
  esac
  [ "$shipped" = true ] && stage="06-shipped"
  [ -f "$spec/PAUSE" ] && stage="paused"
  echo "$stage"
}

# --- judge / escalate ------------------------------------------------------------------------
# escalate is called by judge itself whenever the computed verdict is ESCALATE; as a CLI verb
# it currently runs the identical computation (the standalone case - open-round exiting 6
# before any round is judged - is story 04's, once open-round exists).

# The report parsers below read in bash, not through printf|grep|sed: record-seat and judge call
# them per label and per ask, and on Windows each pipeline was a burst of process spawns - a
# council seat's record-seat cost 3.5 s. Each prints what its sed/grep pipeline printed.

seat_field() { # seat_field <file> <LABEL> - value after "LABEL:" and its blanks on the first matching line
  [ -f "$1" ] || return 0
  seat_field_str "$(cat "$1")" "$2"
}

seat_field_str() { # seat_field_str <text> <LABEL> - same as seat_field, over a string, not a file
  local line
  while IFS= read -r line; do
    case "$line" in "$2:"*) line="${line#"$2:"}"; printf '%s\n' "${line#"${line%%[![:space:]]*}"}"; return ;; esac
  done <<<"$1"
}

seat_header_field() { # seat_header_field <file> <key> - from the "<!-- seat: ... -->" header: the
  # text after the first "<key>: " up to the next ` · ` separator, trailing spaces dropped
  local l=""
  [ -f "$1" ] || return 0
  IFS= read -r l < "$1"
  case "$l" in *"$2: "*) ;; *) return 0 ;; esac
  l="${l#*"$2: "}"; l="${l%%$'\xc2\xb7'*}"; l="${l#"${l%%[! ]*}"}"; l="${l%"${l##*[! ]}"}"
  printf '%s\n' "$l"
}

seat_presence() { # seat_presence <round-dir> <seat> -> present | absent | missing
  local rd="$1" seat="$2"
  if [ -f "$rd/$seat.md" ]; then echo present
  elif [ -f "$rd/$seat.attempt-2.md" ]; then echo absent
  else echo missing
  fi
}

seat_ask_lines() { # seat_ask_lines <file> -> "n verdict evidenced(1/0)" per ASK line - evidenced
  # comes from ask_evidenced_of (below), the same classification record-seat uses (R8), so a
  # header's unevidenced: list and judge's red/red_unevidenced never disagree on one report.
  grep -E '^ASK [0-9]+:' "$1" 2>/dev/null | while IFS= read -r line; do
    local n v ev
    n="$(ask_num_of "$line")"
    v="$(ask_verdict_of "$line")"
    ev="$(ask_evidenced_of "$line")"
    printf '%s %s %s\n' "$n" "$v" "$ev"
  done
}

review_verdict_of_text() { # review_verdict_of_text <text> -> PASS | BLOCK | "" (D3; C5 amended
  # by story 27, R28/N-m4: only the text's own first line is read - a matching token further
  # down is not a verdict, so a prose or blank opening line is MALFORMED rather than scored by
  # whatever PASS/BLOCK the body happens to contain)
  local first
  first="$(printf '%s\n' "$1" | sed -n '1p')"
  first="$(printf '%s' "$first" | grep -E '^(PASS|BLOCK)\b|^VERDICT: (PASS|BLOCK)\b')" || return 0
  case "$first" in
    VERDICT:*) printf '%s' "$first" | sed -n 's/^VERDICT: \(PASS\|BLOCK\).*/\1/p' ;;
    PASS*) echo PASS ;;
    BLOCK*) echo BLOCK ;;
  esac
}

review_verdict_of() { # review_verdict_of <file> -> PASS | BLOCK | "" (D3). The stored file's
  # own first line is the C4 header write_seat_file wrote; the report itself starts at line 2,
  # so drop the header before reading the report's first line (C5 amended, story 27).
  review_verdict_of_text "$(sed '1d' "$1" 2>/dev/null)"
}

review_blocking_lines_text() { # review_blocking_lines_text <report> -> its list lines (`- `,
  # `* `, `N. `) between a `## Critical` or `## Major` heading (case-insensitive) and the next
  # `## ` heading (convergent-judge-05): the only lines whose anchor tag counts - a tag in prose
  # or on a minor finding never anchors a BLOCK. Plan ## Contracts: review.md finding line.
  printf '%s\n' "$1" | awk '
    /^##[[:space:]]/ { h=tolower($0); sub(/^##[[:space:]]+/, "", h); blk=(h ~ /^(critical|major)/); next }
    blk && /^[[:space:]]*([-*][[:space:]]|[0-9]+\.[[:space:]])/ { print }'
}
review_blocking_lines() { # review_blocking_lines <file> -> the same, for a stored review (its
  # C4 header line is dropped first).
  review_blocking_lines_text "$(sed '1d' "$1" 2>/dev/null)"
}

review_anchor_asks() { # review_anchor_asks <file> <A> -> sorted "n n" of every `[ask N]` tag on
  # a blocking list line (review_blocking_lines) with 1 <= N <= A (convergent-judge-02, D4;
  # scope narrowed by convergent-judge-05): an out-of-range ask is not an anchor.
  local n out=""
  for n in $(review_blocking_lines "$1" | grep -oE '\[ask [0-9]+\]' | sed 's/[^0-9]//g'); do
    n=$((10#$n))
    [ "$n" -ge 1 ] && [ "$n" -le "$2" ] || continue
    case " $out " in *" $n "*) ;; *) out="$out $n" ;; esac
  done
  sort_num_list "$out"
}
review_has_regression() { review_blocking_lines "$1" | grep -qF '[regression]'; } # <file>

council_line_exists() { grep -qE "^\*\*Council:\*\*.*round $2," "$1" 2>/dev/null; } # <plan> <round>
journal_line_exists() { [ -f "$1/journal.md" ] && grep -qF "round $2 verdict $3" "$1/journal.md"; } # <spec> <round> <verdict>

reopen_names_round() { # reopen_names_round <spec> <n> -> 0 iff council/REOPEN has a line for
  # round n (R7/M-4, autonomous-cycle-19): `[[:space:]]` after the number keeps round 1 from
  # matching a line for round 10 - n is always digits, so no regex escaping is needed.
  local spec="$1" n="$2" f
  f="$spec/council/REOPEN"
  [ -f "$f" ] || return 1
  grep -qE "^round=$n[[:space:]]" "$f"
}

# --- git helpers (R17/M-6, autonomous-cycle-21): every site below used to swallow a failing
# git call with `|| true`, so a checkout or commit that failed still let the verb report
# success and, in build_round's case, still write ROUND as if the court behind it were real.
# git_commit_or_fail() assumes the caller already staged what it wants committed; a `return 0`
# (nothing to commit) is not an error. Every mutating verb now goes through one of these two,
# never a bare `git commit ... || true`.
git_commit_or_fail() { # git_commit_or_fail <verb-label> <message> - commits what is already
  # staged; on failure, reports it (naming "git commit", R17) and terminates the process -
  # never called when there is nothing staged (callers check first, or see commit_paperwork).
  local verb="$1" msg="$2" err
  if ! err="$(git commit -q -m "$msg" 2>&1)"; then
    echo "cycle: $verb - git commit failed: $err" >&2
    emit false "$verb" 2 error "git commit failed"
    exit 2
  fi
}

commit_paperwork() { # commit_paperwork <verb-label> <message> <path...> - stages and commits
  # the given paths iff any of them changed; a clean set of paths is not an error and returns
  # 0 without committing. The common shape shared by judge/briefed/branch/open-round/reopen.
  # Story 09: memory/stats/anomalies.jsonl (the anomaly-scan Stop hook's log) rides every
  # --commit'd verb the same way, so it never needs a hand commit ADR-001 forbids.
  local verb="$1" msg="$2"; shift 2
  local -a paths=("$@")
  # `git add -A --` errors out entirely (staging nothing) if any one pathspec matches no
  # file, so a spec that never had a Stop hook fire yet must not add a path that does not
  # exist on disk - only ride the log when there is a log to ride.
  [ -e memory/stats/anomalies.jsonl ] && paths+=(memory/stats/anomalies.jsonl)
  [ -n "$(git status --porcelain -- "${paths[@]}" 2>/dev/null)" ] || return 0
  git add -A -- "${paths[@]}" >/dev/null 2>&1
  git_commit_or_fail "$verb" "$msg"
}

# --- escalate row/plan-line helpers (R5/C-3, autonomous-cycle-21) -----------------------------
# Distinct from row_exists()/council_line_exists(): those match ANY verdict for a round number,
# but a round can legitimately carry more than one row (a STALE fold, or an already-judged RED,
# followed later by an ESCALATE for the same round number - the ceiling gate and the standalone
# `escalate` verb both add one), so idempotency here is scoped to "an ESCALATE row/line already
# exists for this round", not "any row exists".
escalate_row_exists() { # escalate_row_exists <slug> <round> - trailing comma anchor, same
  # reason as row_exists (LR21/r2m1): round 1 must not match round 10/11/... .
  [ -f memory/stats/council.jsonl ] || return 1
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl | grep -F "\"round\":$2," | grep -qF '"verdict":"ESCALATE"'
}
escalate_council_line_exists() { grep -qE "^\*\*Council:\*\*.*ESCALATE round $2," "$1" 2>/dev/null; } # <plan> <round>

write_escalate_row_for_round() { # write_escalate_row_for_round <spec> <slug> <rd> <n> <reason> <note>
  # Records an ESCALATE row (council.jsonl), a plan.md **Council:** line, a `## Needs a human`
  # block (C7) and a journal line for round <n> - shared by the standalone `escalate` verb
  # (seats missing, R5/C-3) and open-round's own ceiling gates (write_ceiling_escalate below).
  # Idempotent per round (see the two helpers just above), same pattern as write_stale_row and
  # cmd_judge's own row/line/journal writes.
  local spec="$1" slug="$2" rd="$3" n="$4" reason="$5" note="$6"
  note="$(redact_note "$note")" # N-m7: free-text note never reaches the ledger/plan unmasked
  local plan="$spec/plan.md" dateonly; dateonly="$(date -u +%Y-%m-%d)"
  local rhead rpack; rhead="$(round_field "$rd" head)"; rpack="$(round_field "$rd" pack)"
  [ -n "$rhead" ] || rhead="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  [ -n "$rpack" ] || rpack="$(pack_fingerprint "$spec")"
  local a; a="$(asks_count "$spec")"

  local required seat v model
  local haiku_v="" sonnet_v="" opus_v="" review_v="" review_asks=""
  local haiku_model=unknown sonnet_model=unknown opus_model=unknown attempts=0
  # r2m5/r2m6: the ceiling gate closes over a round whose seats already carry RED asks (a RED
  # verdict at N-1, or a STALE-folded round whose seat files were filed before code moved) - the
  # ESCALATE row and the ## Needs a human block must show those same asks, not empty arrays,
  # same evidenced/unevidenced split cmd_judge uses (seat_ask_lines, ask_evidenced_of).
  local red_e="" red_u=""
  required="$(round_required_seats "$spec" "$rd")"
  for seat in haiku sonnet opus; do
    local f="$rd/$seat.md"
    if [ -f "$f" ]; then
      v="$(seat_field "$f" VERDICT)"; [ -n "$v" ] || v="RED"
      model="$(seat_header_field "$f" model)"; [ -n "$model" ] || model="unknown"
      case "$seat" in
        haiku)  haiku_v="$v";  haiku_model="$model" ;;
        sonnet) sonnet_v="$v"; sonnet_model="$model" ;;
        opus)   opus_v="$v";   opus_model="$model" ;;
      esac
      local askn askv ev
      while IFS=' ' read -r askn askv ev; do
        [ -n "$askn" ] || continue
        if [ "$askv" = "RED" ]; then
          if [ "$ev" = "1" ]; then
            case " $red_e " in *" $askn "*) ;; *) red_e="$red_e $askn" ;; esac
          else
            case " $red_u " in *" $askn "*) ;; *) red_u="$red_u $askn" ;; esac
          fi
        fi
      done <<ASKS
$(seat_ask_lines "$f")
ASKS
    elif is_required_seat "$seat" "$required"; then
      case "$seat" in haiku) haiku_v=ABSENT ;; sonnet) sonnet_v=ABSENT ;; opus) opus_v=ABSENT ;; esac
    fi
    attempts=$((attempts + $(seat_attempt_count "$rd" "$seat")))
  done
  # evidenced wins over unevidenced for the same ask number (same rule as cmd_judge)
  local cleaned="" u
  for u in $red_u; do case " $red_e " in *" $u "*) ;; *) cleaned="$cleaned $u" ;; esac; done
  red_u="$cleaned"
  red_e="$(sort_num_list "$red_e")"
  red_u="$(sort_num_list "$red_u")"
  if [ -f "$rd/review.md" ]; then
    review_v="$(review_verdict_of "$rd/review.md")"; [ -n "$review_v" ] || review_v="ABSENT"
    [ "$review_v" = "BLOCK" ] && review_asks="$(review_anchor_asks "$rd/review.md" "$a")"
  elif is_required_seat review "$required"; then
    review_v="ABSENT"
  fi
  attempts=$((attempts + $(seat_attempt_count "$rd" review)))

  if ! escalate_row_exists "$slug" "$n"; then
    mkdir -p memory/stats
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"ESCALATE","head":"%s","pack":"%s","asks":%s,"red":[%s],"red_unevidenced":[%s],"review_asks":[%s],"na":0,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":"%s","note":"%s"}\n' \
      "$(now_ts)" "$slug" "$n" "$rhead" "$rpack" "$a" \
      "$(json_num_csv "$red_e")" "$(json_num_csv "$red_u")" "$(json_num_csv "$review_asks")" \
      "$review_v" "$haiku_v" "$haiku_model" "$sonnet_v" "$sonnet_model" "$opus_v" "$opus_model" \
      "$attempts" "$reason" "$note" >> memory/stats/council.jsonl
  fi

  if [ -f "$plan" ] && ! escalate_council_line_exists "$plan" "$n"; then
    council_append_line "$plan" "$(printf '**Council:** ESCALATE round %s, %s, at %s, pack %s' "$n" "$dateonly" "$rhead" "$rpack")"
  fi

  if [ -f "$plan" ] && ! grep -qF "reason: $reason · round $n ·" "$plan" 2>/dev/null; then
    {
      grep -q '^## Needs a human' "$plan" 2>/dev/null || printf '\n## Needs a human\n'
      printf -- '- reason: %s · round %s · %s\n' "$reason" "$n" "$dateonly"
      printf -- '- note: %s\n' "$note"
      for u in $red_e $red_u; do
        printf -- '- ask %s: RED - see %s/*.md for evidence\n' "$u" "$rd"
      done
      printf -- '- seats: %s/\n' "$rd"
    } >> "$plan"
  fi

  journal_line_exists "$spec" "$n" "ESCALATE" || \
    bash "$HERE/journal.sh" "$spec" "04-council:ESCALATE" "round $n verdict ESCALATE at $rhead pack $rpack ($reason)" "escalated" >/dev/null
}

write_ceiling_escalate() { # write_ceiling_escalate <spec> <slug> <n> <rd-or-empty> - the
  # ceiling itself is the reason (R5): open-round's two ceiling gates call this instead of
  # exiting 6 silently, so the round the ceiling stopped leaves a record on disk and `status`
  # says `escalated` instead of looping (lead-review 5, C-3(a)).
  local spec="$1" slug="$2" n="$3" rd="$4"
  [ -n "$rd" ] || rd="$spec/council/round-$n"
  write_escalate_row_for_round "$spec" "$slug" "$rd" "$n" "ceiling" "open-round ceiling"
}

cmd_judge() { # cmd_judge <spec> <commit:0|1> [<verb-label>] [<stamp>]
  local SPEC="$1" DOCOMMIT="$2" VERBLABEL="${3:-judge}" STAMP="${4:-}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 $VERBLABEL <spec-dir> [--commit]" >&2
    emit false "$VERBLABEL" 1 error "usage"
    exit 1
  }
  local SLUG PLAN; SLUG="$(slug_of "$SPEC")"; PLAN="$SPEC/plan.md"

  pause_guard "$SPEC" "$VERBLABEL"
  # driver_guard only for the real `judge` verb: cmd_escalate reuses this function internally
  # with VERBLABEL=escalate, and escalate is not gated by DRIVER (non-goal).
  [ "$VERBLABEL" = "judge" ] && driver_guard "$SPEC" "$VERBLABEL" "$STAMP"

  local RD; RD="$(current_round_dir "$SPEC")"
  if [ -z "$RD" ]; then
    echo "cycle: $VERBLABEL - $SPEC has no council round to judge (run open-round first)" >&2
    emit false "$VERBLABEL" 2 error "no open round"
    exit 2
  fi
  local N="${RD##*/round-}"
  local RHEAD RPACK ROPENED RCEILING
  RHEAD="$(round_field "$RD" head)"
  RPACK="$(round_field "$RD" pack)"
  ROPENED="$(round_field "$RD" opened)"
  RCEILING="$(round_field "$RD" ceiling)"; [ -n "$RCEILING" ] || RCEILING="$(tier_ceiling "$(round_tier "$SPEC" "$RD")")"
  local REQUIRED; REQUIRED="$(round_required_seats "$SPEC" "$RD")"

  # --- presence pass: every REQUIRED seat must be present or ABSENT, in order (C15: a seat
  # this round's tier does not call for simply may never have been dispatched) --------------
  local seat pres
  for seat in haiku sonnet opus review; do
    is_required_seat "$seat" "$REQUIRED" || continue
    pres="$(seat_presence "$RD" "$seat")"
    if [ "$pres" = missing ]; then
      echo "cycle: $VERBLABEL - seat '$seat' has no report and no attempt-2 in $RD" >&2
      emit false "$VERBLABEL" 2 error "seat $seat missing"
      exit 2
    fi
  done

  # --- per-seat verdicts and evidenced/unevidenced red asks ---------------------------------
  local A; A="$(asks_count "$SPEC")"
  local haiku_v sonnet_v opus_v haiku_model sonnet_model opus_model review_v
  local red_e="" red_u=""
  for seat in haiku sonnet opus; do
    local f="$RD/$seat.md" v model
    if [ -f "$f" ]; then
      v="$(seat_field "$f" VERDICT)"; [ -n "$v" ] || v="RED"
      model="$(seat_header_field "$f" model)"; [ -n "$model" ] || model="unknown"
      local line askn askv ev
      while IFS=' ' read -r askn askv ev; do
        [ -n "$askn" ] || continue
        if [ "$askv" = "RED" ]; then
          if [ "$ev" = "1" ]; then
            case " $red_e " in *" $askn "*) ;; *) red_e="$red_e $askn" ;; esac
          else
            case " $red_u " in *" $askn "*) ;; *) red_u="$red_u $askn" ;; esac
          fi
        fi
      done <<ASKS
$(seat_ask_lines "$f")
ASKS
    elif is_required_seat "$seat" "$REQUIRED"; then
      v="ABSENT"; model="unknown"
    else
      v=""; model="unknown" # C15: not required and never recorded - optional, not ABSENT
    fi
    case "$seat" in
      haiku)  haiku_v="$v";  haiku_model="$model" ;;
      sonnet) sonnet_v="$v"; sonnet_model="$model" ;;
      opus)   opus_v="$v";   opus_model="$model" ;;
    esac
  done

  # evidenced wins over unevidenced for the same ask number
  local cleaned="" u
  for u in $red_u; do case " $red_e " in *" $u "*) ;; *) cleaned="$cleaned $u" ;; esac; done
  red_u="$cleaned"
  red_e="$(sort_num_list "$red_e")"
  red_u="$(sort_num_list "$red_u")"
  local red_e_count red_u_count
  red_e_count="$(printf '%s' "$red_e" | wc -w | tr -d ' ')"
  red_u_count="$(printf '%s' "$red_u" | wc -w | tr -d ' ')"

  local rf="$RD/review.md" review_asks="" review_note=""
  if [ -f "$rf" ]; then
    review_v="$(review_verdict_of "$rf")"
    if [ "$review_v" = "BLOCK" ]; then
      # D4 (convergent-judge-02): a BLOCK holds only on an `[ask N]` (N a real brief ask) or a
      # `[regression]` tag in the body; otherwise it is recorded PASS and its findings go to the
      # next circle (vulyk-ship step 5), not to a repair wave. The tag is read, not validated.
      review_asks="$(review_anchor_asks "$rf" "$A")"
      if [ -z "$review_asks" ] && ! review_has_regression "$rf"; then
        review_v="PASS"; review_note="review BLOCK unanchored"
      fi
    fi
    [ -n "$review_v" ] || review_v="BLOCK" # an unreadable stored report stays a block
  elif is_required_seat review "$REQUIRED"; then
    review_v="ABSENT"
  else
    review_v="" # C15: review not required at this tier and never recorded - not ABSENT
  fi

  # --- env escalation is "at least one REQUIRED seat is ABSENT" (R16/M-5), not "all three" -
  # a partial absence with nothing RED anywhere and review not BLOCK is a court/tooling defect
  # no repair story can act on, same as the all-absent case it used to be limited to.
  local absent_seats=""
  for seat in haiku sonnet opus; do
    is_required_seat "$seat" "$REQUIRED" || continue
    case "$seat" in
      haiku)  [ "$haiku_v" = ABSENT ]  && absent_seats="$absent_seats haiku" ;;
      sonnet) [ "$sonnet_v" = ABSENT ] && absent_seats="$absent_seats sonnet" ;;
      opus)   [ "$opus_v" = ABSENT ]   && absent_seats="$absent_seats opus" ;;
    esac
  done
  is_required_seat review "$REQUIRED" && [ "$review_v" = ABSENT ] && absent_seats="$absent_seats review"
  absent_seats="${absent_seats# }"

  local na_count=0 v
  for v in "$haiku_v" "$sonnet_v" "$opus_v"; do [ "$v" = "N/A" ] && na_count=$((na_count+1)); done

  # --- the owner's override: a REJECTED human check newer than this round's opening ---------
  local override_red=0
  if [ -f memory/stats/human.jsonl ]; then
    local hlast hv hts
    hlast="$(grep -F "\"spec\":\"$SLUG\"" memory/stats/human.jsonl | tail -1)"
    if [ -n "$hlast" ]; then
      hv="$(json_field "$hlast" verdict)"
      hts="$(json_field "$hlast" ts)"
      # m-4: a REJECTED check timestamped in the same second as the round's own opening still
      # outranks it - >=, not > (a round and its override can share a clock tick).
      if [ "$hv" = REJECTED ] && [ -n "$hts" ] && [ -n "$ROPENED" ] \
        && { [ "$hts" \> "$ROPENED" ] || [ "$hts" = "$ROPENED" ]; }; then
        override_red=1
      fi
    fi
  fi

  # --- no progress (convergent-judge-04): an ask RED this round (evidenced or review-anchored)
  # that round N-1's RED row also held RED. Ask numbers only; a STALE/ESCALATE/missing N-1
  # row never triggers.
  local repeated="" prow="" prev="" x
  [ "$N" -gt 1 ] && prow="$(round_row "$SLUG" "$((N-1))")"
  if [ -n "$prow" ] && [ "$(json_field "$prow" verdict)" = "RED" ]; then
    prev=" $(json_num_array "$prow" red) $(json_num_array "$prow" review_asks) "
    for x in $red_e $review_asks; do
      case "$prev" in *" $x "*) case " $repeated " in *" $x "*) ;; *) repeated="$repeated $x" ;; esac ;; esac
    done
    repeated="$(sort_num_list "$repeated")"
  fi

  # --- the verdict rule (D4), first match wins ----------------------------------------------
  local overall="" next_val="" escalate_reason=""
  local half=$(( (A+1)/2 )); [ "$half" -lt 2 ] && half=2  # R10: max(2, ceil(A/2))
  if [ "$override_red" -eq 1 ]; then
    overall="RED"; next_val="repair"
  elif [ -n "$absent_seats" ] && [ "$red_e_count" -eq 0 ] && [ "$red_u_count" -eq 0 ] && [ "$review_v" != "BLOCK" ]; then
    overall="ESCALATE"; escalate_reason="env"; next_val="escalated"
  elif [ "$red_e_count" -gt 0 ] && [ "$red_e_count" -ge "$half" ]; then
    overall="ESCALATE"; escalate_reason="half"; next_val="escalated"
  elif [ "$review_v" = "BLOCK" ] || [ "$red_e_count" -gt 0 ] || [ "$red_u_count" -gt 0 ]; then
    if [ -n "$repeated" ]; then
      overall="ESCALATE"; escalate_reason="no-progress"; next_val="escalated"
    elif [ "$(( $(red_rounds "$SLUG" "$N") + 1 ))" -ge "$RCEILING" ]; then
      overall="ESCALATE"; escalate_reason="ceiling"; next_val="escalated"
    else
      overall="RED"; next_val="repair"
    fi
  else
    local ok=1
    for v in "$haiku_v" "$sonnet_v" "$opus_v"; do case "$v" in ""|GREEN|N/A) ;; *) ok=0 ;; esac; done
    if [ "$ok" -eq 1 ] && { [ "$review_v" = "PASS" ] || [ -z "$review_v" ]; }; then
      overall="GREEN"; next_val="green"
    else
      overall="RED"; next_val="repair" # defensive default - every ABSENT/RED/BLOCK state is
      # already routed above, so this should be unreachable (R16 closed the last gap)
    fi
  fi

  # --- write: row -> plan line -> (Needs a human) -> journal, each idempotently ------------
  local head7="${RHEAD:-unknown}" dateonly; dateonly="$(date -u +%Y-%m-%d)"
  if ! row_exists "$SLUG" "$N"; then
    mkdir -p memory/stats
    local escjson="null"; [ -n "$escalate_reason" ] && escjson="\"$escalate_reason\""
    local attempts=0
    for seat in haiku sonnet opus review; do
      attempts=$((attempts + $(seat_attempt_count "$RD" "$seat")))
    done
    local noteval=""
    [ "$escalate_reason" = "env" ] && noteval="$(redact_note "$(printf '%s' "$absent_seats" | sed 's/ /, /g') ABSENT")"
    [ -n "$review_note" ] && noteval="${noteval:+$noteval; }$review_note"
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"%s","head":"%s","pack":"%s","asks":%s,"red":[%s],"red_unevidenced":[%s],"review_asks":[%s],"na":%s,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":%s,"note":"%s"}\n' \
      "$(now_ts)" "$SLUG" "$N" "$overall" "$head7" "$RPACK" "$A" \
      "$(json_num_csv "$red_e")" "$(json_num_csv "$red_u")" "$(json_num_csv "$review_asks")" "$na_count" \
      "$review_v" "$haiku_v" "$haiku_model" "$sonnet_v" "$sonnet_model" "$opus_v" "$opus_model" \
      "$attempts" "$escjson" "$noteval" >> memory/stats/council.jsonl
  fi

  if [ -f "$PLAN" ] && ! council_line_exists "$PLAN" "$N"; then
    local suffix=""; [ -n "$red_e" ] && suffix=" - red: $(json_num_csv "$red_e")"
    council_append_line "$PLAN" "$(printf '**Council:** %s round %s, %s, at %s, pack %s%s' \
      "$overall" "$N" "$dateonly" "$head7" "$RPACK" "$suffix")"
  fi

  if [ "$overall" = "ESCALATE" ] && [ -f "$PLAN" ] && ! grep -qF "reason: $escalate_reason · round $N ·" "$PLAN" 2>/dev/null; then
    {
      grep -q '^## Needs a human' "$PLAN" 2>/dev/null || printf '\n## Needs a human\n'
      printf -- '- reason: %s · round %s · %s\n' "$escalate_reason" "$N" "$dateonly"
      for u in $red_e $red_u; do
        printf -- '- ask %s: RED - see %s/*.md for evidence\n' "$u" "$RD"
      done
      for u in $review_asks; do
        case " $red_e $red_u " in *" $u "*) continue ;; esac
        printf -- '- ask %s: BLOCK by the reviewer - see %s/review.md\n' "$u" "$RD"
      done
      if [ "$escalate_reason" = "no-progress" ]; then
        printf -- '- no progress: ask %s RED in rounds %s and %s\n' "$(json_num_csv "$repeated" | sed 's/,/, /g')" "$((N-1))" "$N"
      fi
      if [ "$escalate_reason" = "env" ]; then
        local aseat att
        for aseat in $absent_seats; do
          for att in 1 2; do
            [ -f "$RD/$aseat.attempt-$att.md" ] && printf -- '- %s: %s/%s.attempt-%s.md\n' "$aseat" "$RD" "$aseat" "$att"
          done
        done
      fi
      printf -- '- seats: %s/\n' "$RD"
    } >> "$PLAN"
  fi

  if ! journal_line_exists "$SPEC" "$N" "$overall"; then
    bash "$HERE/journal.sh" "$SPEC" "04-council:$overall" "round $N verdict $overall at $head7 pack $RPACK" "$next_val" >/dev/null
  fi

  # --- remove the court (D5): the round is closed either way, GREEN/RED/ESCALATE alike; a
  # court already gone (crash, or a re-run of an idempotent judge) is not an error (autonomous-cycle-04) ---
  local court_path; court_path="$(round_field "$RD" court)"
  if [ -n "$court_path" ]; then
    remove_worktree_path "$court_path"
    git worktree prune >/dev/null 2>&1 || true
  fi

  [ "$DOCOMMIT" = "1" ] && commit_paperwork "$VERBLABEL" "vulyk($SLUG): $VERBLABEL round $N -> $overall" "$SPEC" memory/stats/council.jsonl

  echo "cycle: $SLUG - round $N judged: $overall"
  # R24/C2: 4 is record-seat MALFORMED and close-story red verification only - a RED verdict
  # is a successful judgement (ok:true) and exits 0 with next:"repair"; ESCALATE keeps 6.
  local exit_code=0
  case "$overall" in ESCALATE) exit_code=6 ;; esac
  if [ "$exit_code" -eq 0 ] && [ "$VERBLABEL" = judge ]; then
    emit_status judge "$SPEC" "$next_val"
  else
    emit true "$VERBLABEL" "$exit_code" "$next_val"
  fi
  exit "$exit_code"
}

cmd_escalate() { # cmd_escalate <spec-dir> [--commit] [--reason <ceiling|half|env|no-progress>] ["<note>"]
  # A verb of its own now (R5/C-3, autonomous-cycle-21), not an alias of judge: judge refuses
  # outright on a missing seat (its presence pass, above), so ADR D2's "the driver calls
  # escalate on exit 6, or on its own initiative" had nowhere to land. This records an
  # escalation for an open round that has seats missing - no seat precondition - and falls
  # through to judge's own computation when nothing is missing, so a driver can call it
  # uniformly wherever a round might be stuck instead of choosing between two verbs.
  local SPEC="${1:-}"; shift || true
  local DOCOMMIT=0 REASON="" NOTE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --commit) DOCOMMIT=1; shift ;;
      --reason) REASON="${2:-}"; shift 2 2>/dev/null || shift $# ;;
      *) NOTE="$1"; shift ;;
    esac
  done
  case "$REASON" in ''|ceiling|half|env|no-progress) ;; *)
    echo "cycle: usage: $0 escalate <spec-dir> [--commit] [--reason <ceiling|half|env|no-progress>] [\"<note>\"]" >&2
    emit false escalate 1 error "usage"
    exit 1
    ;;
  esac
  [ -n "$REASON" ] || REASON="env"

  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 escalate <spec-dir> [--commit] [--reason <ceiling|half|env|no-progress>] [\"<note>\"]" >&2
    emit false escalate 1 error "usage"
    exit 1
  }

  pause_guard "$SPEC" escalate

  local SLUG; SLUG="$(slug_of "$SPEC")"
  local RD; RD="$(current_round_dir "$SPEC")"
  if [ -z "$RD" ] || row_exists "$SLUG" "${RD##*/round-}"; then
    echo "cycle: escalate - $SPEC has no open council round" >&2
    emit false escalate 2 error "no open round"
    exit 2
  fi
  local N="${RD##*/round-}"

  local required missing
  required="$(round_required_seats "$SPEC" "$RD")"
  missing="$(missing_required_seats "$RD" "$required")"

  if [ -z "$missing" ]; then
    # Nothing missing: behave exactly like judge (D3) - the verb label stays "escalate" so a
    # driver's own emit-reading code sees the call it made, whatever judge itself decides.
    cmd_judge "$SPEC" "$DOCOMMIT" escalate
    exit 0 # unreachable - cmd_judge always exits itself
  fi

  [ -n "$NOTE" ] || NOTE="$(printf '%s' "$missing" | sed 's/ /, /g') missing"

  write_escalate_row_for_round "$SPEC" "$SLUG" "$RD" "$N" "$REASON" "$NOTE"

  local court_path; court_path="$(round_field "$RD" court)"
  if [ -n "$court_path" ]; then
    remove_worktree_path "$court_path"
    git worktree prune >/dev/null 2>&1 || true
  fi

  [ "$DOCOMMIT" = "1" ] && commit_paperwork escalate "vulyk($SLUG): escalate round $N ($REASON)" "$SPEC" memory/stats/council.jsonl

  echo "cycle: $SLUG - round $N escalated ($REASON): ${missing:-none missing}"
  emit true escalate 6 escalated
  exit 6
}

# --- briefed / branch -------------------------------------------------------------------------

cmd_briefed() { # cmd_briefed <spec> <commit:0|1> <mode: ""|mini-brief|assumed>
  local SPEC="$1" DOCOMMIT="$2" MODE="$3"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 briefed <spec-dir> [--commit] [--mode mini-brief|assumed]" >&2
    emit false briefed 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" briefed

  local A; A="$(asks_count "$SPEC")"
  if [ -z "$A" ] || [ "$A" -le 0 ] 2>/dev/null; then
    echo "cycle: briefed - $SPEC/brief.md has no '## Asks' section, or it is empty" >&2
    emit false briefed 2 error "## Asks missing or empty"
    exit 2
  fi

  local PLAN="$SPEC/plan.md"
  [ -f "$PLAN" ] || {
    echo "cycle: briefed - $PLAN not found" >&2
    emit false briefed 2 error "plan.md not found"
    exit 2
  }

  local SLUG; SLUG="$(slug_of "$SPEC")"
  local briefed_v approved_v
  briefed_v="$(marker "$PLAN" Briefed)"
  approved_v="$(marker "$PLAN" Approved)"
  if [ -z "$briefed_v" ] && [ -z "$approved_v" ]; then
    local variant="via grill"
    case "$MODE" in
      mini-brief) variant="via mini-brief" ;;
      assumed)    variant="via grill (assumed)" ;;
    esac
    local OWNER_V="${OWNER:-${USER:-${USERNAME:-owner}}}"
    local dateonly; dateonly="$(date -u +%Y-%m-%d)"
    local line="**Briefed:** $variant, $OWNER_V, $dateonly"
    if grep -q '^\*\*Briefed:\*\*' "$PLAN"; then
      sed -i "s#^\*\*Briefed:\*\*.*#$line#" "$PLAN"
    else
      printf '%s\n' "$line" >> "$PLAN"
    fi
    bash "$HERE/journal.sh" "$SPEC" "02-approved" "briefed $variant, $OWNER_V" "branch" >/dev/null
  fi

  [ "$DOCOMMIT" = "1" ] && commit_paperwork briefed "vulyk($SLUG): briefed" "$SPEC"

  echo "cycle: $SLUG - briefed"
  emit true briefed 0 branch
  exit 0
}

cmd_branch() { # cmd_branch <spec> <commit:0|1>
  local SPEC="$1" DOCOMMIT="$2"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 branch <spec-dir> [--commit]" >&2
    emit false branch 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" branch

  local PLAN="$SPEC/plan.md"
  [ -f "$PLAN" ] || {
    echo "cycle: branch - $PLAN not found" >&2
    emit false branch 2 error "plan.md not found"
    exit 2
  }

  local briefed_v approved_v
  briefed_v="$(marker "$PLAN" Briefed)"
  approved_v="$(marker "$PLAN" Approved)"
  if [ -z "$briefed_v" ] && [ -z "$approved_v" ]; then
    echo "cycle: branch - $SPEC has neither Briefed nor Approved; run briefed first" >&2
    emit false branch 2 error "no Briefed or Approved"
    exit 2
  fi

  local SLUG; SLUG="$(slug_of "$SPEC")"
  local BR="vulyk/$SLUG"
  local branch_v; branch_v="$(marker "$PLAN" Branch)"
  if [ -z "$branch_v" ]; then
    local co_err co_status
    if git rev-parse --verify -q "$BR" >/dev/null 2>&1; then
      co_err="$(git checkout -q "$BR" 2>&1)"; co_status=$?
    else
      co_err="$(git checkout -q -b "$BR" 2>&1)"; co_status=$?
    fi
    # R17/M-6: a checkout that failed must not be followed by a **Branch:** line claiming it
    # succeeded - the next story commit would land on whatever branch the session was actually on.
    if [ "$co_status" -ne 0 ]; then
      echo "cycle: branch - could not check out $BR: $co_err" >&2
      emit false branch 2 error "git checkout failed"
      exit 2
    fi
    local line="**Branch:** $BR"
    if grep -q '^\*\*Branch:\*\*' "$PLAN"; then
      sed -i "s#^\*\*Branch:\*\*.*#$line#" "$PLAN"
    else
      printf '%s\n' "$line" >> "$PLAN"
    fi
    bash "$HERE/journal.sh" "$SPEC" "03-building" "branch $BR created" "build:1" >/dev/null
  fi

  [ "$DOCOMMIT" = "1" ] && commit_paperwork branch "vulyk($SLUG): branch $BR" "$SPEC"

  echo "cycle: $SLUG - branch $BR"
  emit_status branch "$SPEC" "build:1"
  exit 0
}

# --- record-seat (D3 report contract: labels, ASK coverage, evidence, taint, re-ask) -----------

write_seat_file() { # write_seat_file <path> <seat> <model> <N> <head> <pack> <attempt> <extra> <body>
  # <extra> is a pre-formatted " · key: value" suffix (or "") - the only variance between a
  # plain C4 header and one carrying `unevidenced:` (council seats) or `verdict:` (review).
  local path="$1" seat="$2" model="$3" n="$4" head="$5" pack="$6" attempt="$7" extra="$8" body="$9"
  {
    printf '<!-- seat: %s \xc2\xb7 model: %s \xc2\xb7 round: %s \xc2\xb7 head: %s \xc2\xb7 pack: %s \xc2\xb7 attempt: %s \xc2\xb7 recorded: %s%s -->\n' \
      "$seat" "$model" "$n" "$head" "$pack" "$attempt" "$(now_ts)" "$extra"
    printf '%s\n' "$body"
  } > "$path"
}

reject_seat_report() { # reject_seat_report <rd> <seat> <model> <n> <head> <pack> <attempt> <report> <reason>
  # Writes the rejected attempt under its own name and exits 4 - never called for `review`
  # taint (review has no taint check, D2/D3) - always terminates the process (mirrors usage()).
  local rd="$1" seat="$2" model="$3" n="$4" head="$5" pack="$6" attempt="$7" report="$8" reason="$9"
  write_seat_file "$rd/$seat.attempt-$attempt.md" "$seat" "$model" "$n" "$head" "$pack" "$attempt" "" "$report"
  echo "cycle: record-seat - $seat round $n attempt $attempt: MALFORMED: $reason" >&2
  emit false record-seat 4 error "MALFORMED: $reason"
  exit 4
}

missing_label() { # missing_label <report> -> the first required C5 label absent, or "" - a
  # label counts only at the start of a line (the report's first line, or after a newline)
  local lab
  for lab in 'COUNCIL:' 'MODEL:' 'COURT:' 'VERDICT:' 'ASSUMED CONFIG:' 'RAN:' 'PATH:' 'UNASKED:' 'BREACH:'; do
    case "$1" in "$lab"*|*$'\n'"$lab"*) ;; *) printf '%s' "$lab"; return ;; esac
  done
  return 0
}

taint_reason() { # taint_reason <report> <slug> -> the D3 taint description, or "" when clean.
  # Path-anchored (R9): a hit needs the slug immediately before /plan.md, /journal.md or
  # /council/ - optionally under docs/specs/ - or the story *file* itself: <slug>-NN.md and
  # the repo's real <slug>-NN-<title>.md shape (C4 revised), or
  # <slug>/<slug>-NN with or without .md, optionally under docs/specs/. A bare <slug>-NN with
  # neither the .md suffix nor the <slug>/ directory prefix is a synthesized id (a CLI --story
  # value, say), not a leak (C4/A6). The bare words plan.md/journal.md/council/, a command file
  # like vulyk-plan.md, and another spec's paths are never taint; literal, case-sensitive, no
  # prose heuristics.
  local report="$1" slug="$2" esc
  esc="$(printf '%s' "$slug" | sed 's/[.[\*^$()+?{|]/\\&/g')"
  printf '%s' "$report" | grep -qE "\b${esc}-[0-9]{2}(-[A-Za-z0-9_-]+)?\.md\b|(docs/specs/)?\b${esc}/${esc}-[0-9]{2}(\.md)?\b" \
                                                                          && { printf 'names the story file %s-NN' "$slug"; return; }
  printf '%s' "$report" | grep -qE "(docs/specs/)?\b${esc}/plan\.md"    && { printf 'names %s/plan.md' "$slug"; return; }
  printf '%s' "$report" | grep -qE "(docs/specs/)?\b${esc}/journal\.md" && { printf 'names %s/journal.md' "$slug"; return; }
  printf '%s' "$report" | grep -qE "(docs/specs/)?\b${esc}/council/"    && { printf 'names %s/council/' "$slug"; return; }
  return 0
}

ask_line_of() { # ask_line_of <report> <n> -> the first line starting "ASK <n>:"
  local line
  while IFS= read -r line; do
    case "$line" in "ASK $2:"*) printf '%s\n' "$line"; return ;; esac
  done <<<"$1"
}
ask_num_of() { # ask_num_of <ask-line> -> its ask number
  local re='^ASK ([0-9]+):'
  [[ $1 =~ $re ]] && printf '%s\n' "${BASH_REMATCH[1]}"
  return 0
}
ask_verdict_of() { # ask_verdict_of <ask-line> -> GREEN | RED | N/A | ""
  local re='^ASK [0-9]+:[[:space:]]*(GREEN|RED|N/A)'
  [[ $1 =~ $re ]] && printf '%s\n' "${BASH_REMATCH[1]}"
  return 0
}
ask_rest_of() { # ask_rest_of <ask-line> -> everything after "ASK n: <VERDICT>" and an optional
  # " - ", interior " - " kept intact (R8 - no truncation at the last dash); a line not of that
  # exact shape comes back whole
  local re='^ASK [0-9]+: (GREEN|RED|N/A)( - )?'
  if [[ $1 =~ $re ]]; then printf '%s' "${1:${#BASH_REMATCH[0]}}"; else printf '%s' "$1"; fi
}
ask_evidenced_of() { # ask_evidenced_of <ask-line> -> "1" iff run:+saw: or url:+saw: occur
  # anywhere in the remainder, "0" otherwise - the one rule record-seat and judge both use (R8).
  case "$(ask_rest_of "$1")" in
    *run:*saw:*|*url:*saw:*) printf 1 ;;
    *) printf 0 ;;
  esac
}

cmd_record_seat_review() { # cmd_record_seat_review <spec> <rd> <n> <attempt> <report> <model-opt> <head>
  local SPEC="$1" RD="$2" N="$3" ATTEMPT="$4" REPORT="$5" MODEL_OPT="$6" HEAD="$7"
  local RPACK; RPACK="$(round_field "$RD" pack)"
  local model="$MODEL_OPT"; [ -n "$model" ] || model="$(seat_field_str "$REPORT" MODEL)"; [ -n "$model" ] || model="unknown"

  local verdict; verdict="$(review_verdict_of_text "$REPORT")"
  if [ -z "$verdict" ]; then
    write_seat_file "$RD/review.attempt-$ATTEMPT.md" review "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "" "$REPORT"
    echo "cycle: record-seat - review round $N attempt $ATTEMPT: MALFORMED: review: first line is not VERDICT: PASS|BLOCK" >&2
    emit false record-seat 4 error "MALFORMED: review: first line is not VERDICT: PASS|BLOCK"
    exit 4
  fi

  # convergent-judge-07: a BLOCK must carry at least one finding line (plan ## Contracts) with
  # an anchor tag; otherwise it is MALFORMED like any seat - kept, exit 4, re-asked once. The tag
  # is not validated further here (ask range, regression claim: judge's business).
  if [ "$verdict" = BLOCK ] && ! review_blocking_lines_text "$REPORT" | grep -qE '\[ask [0-9]+\]|\[regression\]|\[unanchored\]'; then
    local why="review: BLOCK has no tagged finding - no list line under ## Critical / ## Major carries [ask N], [regression] or [unanchored]"
    write_seat_file "$RD/review.attempt-$ATTEMPT.md" review "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "" "$REPORT"
    echo "cycle: record-seat - review round $N attempt $ATTEMPT: MALFORMED: $why" >&2
    emit false record-seat 4 error "MALFORMED: $why"
    exit 4
  fi

  local extra; extra="$(printf ' \xc2\xb7 verdict: %s' "$verdict")"
  write_seat_file "$RD/review.md" review "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$extra" "$REPORT"
  echo "cycle: record-seat - review recorded for round $N (verdict $verdict)"
  local missing required next_val
  required="$(round_required_seats "$SPEC" "$RD")"
  missing="$(missing_required_seats "$RD" "$required")"
  next_val="judge"; [ -n "$missing" ] && next_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
  emit_status record-seat "$SPEC" "$next_val"
  exit 0
}

cmd_record_seat_council() { # cmd_record_seat_council <spec> <rd> <n> <seat> <attempt> <report> <model-opt> <head>
  local SPEC="$1" RD="$2" N="$3" SEAT="$4" ATTEMPT="$5" REPORT="$6" MODEL_OPT="$7" HEAD="$8"
  local SLUG; SLUG="$(slug_of "$SPEC")"
  local A; A="$(asks_count "$SPEC")"
  local RPACK; RPACK="$(round_field "$RD" pack)"
  local model="$MODEL_OPT"; [ -n "$model" ] || model="$(seat_field_str "$REPORT" MODEL)"; [ -n "$model" ] || model="unknown"

  local why; why="$(missing_label "$REPORT")"
  [ -z "$why" ] || reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" "missing label $why"

  local tr; tr="$(taint_reason "$REPORT" "$SLUG")"
  [ -z "$tr" ] || reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" "tainted, $tr"

  # --- structural pass: every ASK number exactly once, 1..A ---------------------------------
  local nums="" n line re_num='^ASK ([0-9]+):'
  while IFS= read -r line; do
    case "$line" in "ASK "[0-9]*) ;; *) continue ;; esac
    n=""; [[ $line =~ $re_num ]] && n="${BASH_REMATCH[1]}"
    [ -n "$n" ] || continue
    case " $nums " in
      *" $n "*) reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" "ASK $n appears more than once" ;;
    esac
    nums="$nums $n"
  done <<REPORTEOF
$REPORT
REPORTEOF
  nums="$(sort_num_list "$nums")"
  local expect; expect="$(sort_num_list "$(seq 1 "$A" 2>/dev/null | tr '\n' ' ')")"
  [ "$nums" = "$expect" ] || reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" \
    "ASK numbers are '$nums', expected 1..$A"

  # --- per-ask verdict/evidence pass ----------------------------------------------------------
  local i v rest red_any=0 nonNA_any=0
  for i in $(seq 1 "$A"); do
    line="$(ask_line_of "$REPORT" "$i")"
    v="$(ask_verdict_of "$line")"
    [ -n "$v" ] || reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" "ASK $i has no GREEN/RED/N/A token"
    rest="$(ask_rest_of "$line")"
    case "$v" in
      "N/A") case "$rest" in *why:*) ;; *) reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" "ASK $i is N/A without why:" ;; esac ;;
      RED)   red_any=1; nonNA_any=1 ;;
      GREEN) nonNA_any=1 ;;
    esac
  done
  local raw_overall="GREEN"
  [ "$nonNA_any" -eq 0 ] && raw_overall="N/A"
  [ "$red_any" -eq 1 ] && raw_overall="RED"

  local verdict_line; verdict_line="$(seat_field_str "$REPORT" VERDICT)"
  [ "$verdict_line" = "$raw_overall" ] || reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" \
    "VERDICT: $verdict_line inconsistent with ASK lines (computed $raw_overall)"

  # --- evidence: GREEN/RED need run:+saw: or url:+saw: - attempt 1 rejects, attempt 2 accepts --
  local unevidenced=""
  for i in $(seq 1 "$A"); do
    line="$(ask_line_of "$REPORT" "$i")"
    v="$(ask_verdict_of "$line")"
    case "$v" in
      GREEN|RED)
        [ "$(ask_evidenced_of "$line")" = "1" ] || unevidenced="$unevidenced $i"
        ;;
    esac
  done
  unevidenced="$(sort_num_list "$unevidenced")"

  if [ -n "$unevidenced" ] && [ "$ATTEMPT" -eq 1 ]; then
    reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" \
      "ask $(printf '%s' "$unevidenced" | tr ' ' ',') without run:+saw: or url:+saw:"
  fi

  # --- attempt 2 leniency (D3 last paragraph): unevidenced RED stays RED (flagged); ------------
  # unevidenced GREEN becomes N/A. Recompute VERDICT only if this changed it.
  local FINAL_REPORT="$REPORT" final_overall="$raw_overall" red_u_list=""
  if [ -n "$unevidenced" ]; then
    local u short
    for u in $unevidenced; do
      line="$(ask_line_of "$REPORT" "$u")"
      v="$(ask_verdict_of "$line")"
      if [ "$v" = GREEN ]; then
        # cosmetic label for the rewrite only (not evidence classification, R8 didn't touch
        # this): the description before the final dash-separated segment, same as before.
        short="$(printf '%s' "$line" | sed -E "s/^ASK $u: (GREEN|RED|N\/A) - //")"
        short="$(printf '%s' "$short" | sed 's/ - [^-]*$//')"
        FINAL_REPORT="$(printf '%s\n' "$FINAL_REPORT" | sed "s#^ASK $u:.*#ASK $u: N/A - $short - why: unevidenced on attempt 2#")"
      else
        red_u_list="$red_u_list $u"
      fi
    done
    red_u_list="$(sort_num_list "$red_u_list")"
    local red2=0 nonNA2=0
    for i in $(seq 1 "$A"); do
      line="$(ask_line_of "$FINAL_REPORT" "$i")"
      v="$(ask_verdict_of "$line")"
      case "$v" in RED) red2=1; nonNA2=1 ;; GREEN) nonNA2=1 ;; esac
    done
    final_overall="GREEN"
    [ "$nonNA2" -eq 0 ] && final_overall="N/A"
    [ "$red2" -eq 1 ] && final_overall="RED"
    [ "$final_overall" = "$raw_overall" ] || FINAL_REPORT="$(printf '%s\n' "$FINAL_REPORT" | sed "s/^VERDICT:.*/VERDICT: $final_overall/")"
  fi

  local extra=""
  [ -n "$red_u_list" ] && extra="$(printf ' \xc2\xb7 unevidenced: %s' "$(json_num_csv "$red_u_list")")"
  write_seat_file "$RD/$SEAT.md" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$extra" "$FINAL_REPORT"
  echo "cycle: record-seat - $SEAT recorded for round $N (attempt $ATTEMPT)$( [ -n "$red_u_list" ] && printf ', unevidenced: %s' "$(json_num_csv "$red_u_list")" )"

  local missing required next_val
  required="$(round_required_seats "$SPEC" "$RD")"
  missing="$(missing_required_seats "$RD" "$required")"
  next_val="judge"; [ -n "$missing" ] && next_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
  emit_status record-seat "$SPEC" "$next_val"
  exit 0
}

cmd_record_seat() { # cmd_record_seat <spec> <N> <seat> [--model <id>] [--stamp <s>] [--file <path>]
  # - report on stdin, or from --file when given (C1)
  local SPEC="${1:-}" N="${2:-}" SEAT="${3:-}"
  local nargs=$#
  if [ "$nargs" -ge 3 ]; then shift 3; else shift "$nargs"; fi
  local MODEL_OPT="" STAMP="" FILE_OPT="" FILE_SET=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) MODEL_OPT="${2:-}"; shift 2 2>/dev/null || shift $# ;;
      --stamp) STAMP="${2:-}"; shift 2 2>/dev/null || shift $# ;;
      --file) FILE_OPT="${2:-}"; FILE_SET=1; shift 2 2>/dev/null || shift $# ;;
      *) shift ;;
    esac
  done

  case "$SEAT" in
    haiku|sonnet|opus|review) ;;
    *)
      echo "cycle: usage: $0 record-seat <spec-dir> <N> <haiku|sonnet|opus|review> [--model <id>] [--stamp <s>] [--file <path>] [< report]" >&2
      emit false record-seat 1 error "usage"
      exit 1
      ;;
  esac
  case "$N" in
    ''|*[!0-9]*)
      echo "cycle: usage: $0 record-seat <spec-dir> <N> <seat> [--model <id>] [--stamp <s>] [--file <path>] [< report]" >&2
      emit false record-seat 1 error "usage"
      exit 1
      ;;
  esac
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 record-seat <spec-dir> <N> <seat> [--model <id>] [--stamp <s>] [--file <path>] [< report]" >&2
    emit false record-seat 1 error "usage"
    exit 1
  }

  pause_guard "$SPEC" record-seat
  driver_guard "$SPEC" record-seat "$STAMP"

  local RD="$SPEC/council/round-$N"
  [ -f "$RD/ROUND" ] || {
    echo "cycle: record-seat - no open round $N for $SPEC ($RD/ROUND not found)" >&2
    emit false record-seat 2 error "no open round $N"
    exit 2
  }
  local HEAD; HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  round_is_stale "$SPEC" "$N" && {
    echo "cycle: record-seat - round $N is stale (ROUND head=$(round_field "$RD" head), current HEAD=$HEAD)" >&2
    emit false record-seat 5 stale "stale"
    exit 5
  }

  [ -f "$RD/$SEAT.md" ] && {
    echo "cycle: record-seat - $SEAT is already recorded for round $N" >&2
    emit false record-seat 2 error "$SEAT already recorded"
    exit 2
  }
  local ATTEMPT=1
  if [ -f "$RD/$SEAT.attempt-2.md" ]; then
    echo "cycle: record-seat - $SEAT has exhausted both attempts for round $N; the seat is ABSENT" >&2
    emit false record-seat 2 error "$SEAT ABSENT: attempts exhausted"
    exit 2
  elif [ -f "$RD/$SEAT.attempt-1.md" ]; then
    ATTEMPT=2
  fi

  local REPORT
  if [ "$FILE_SET" = 1 ]; then
    # Last precondition, in place of the `cat`: nothing has been written yet, so a bad path
    # leaves no attempt file behind (C1). Checked verbatim as given, for the error string.
    [ -n "$FILE_OPT" ] && [ -f "$FILE_OPT" ] && [ -r "$FILE_OPT" ] && [ -s "$FILE_OPT" ] || {
      echo "cycle: record-seat - report file missing, unreadable or empty: $FILE_OPT" >&2
      emit false record-seat 2 error "file: $FILE_OPT"
      exit 2
    }
    REPORT="$(cat "$FILE_OPT")"
  else
    REPORT="$(cat)"
  fi

  if [ "$SEAT" = review ]; then
    cmd_record_seat_review "$SPEC" "$RD" "$N" "$ATTEMPT" "$REPORT" "$MODEL_OPT" "$HEAD"
  else
    cmd_record_seat_council "$SPEC" "$RD" "$N" "$SEAT" "$ATTEMPT" "$REPORT" "$MODEL_OPT" "$HEAD"
  fi
}

# --- close-story / open-round / reopen (autonomous-cycle-04: rounds in git) ------------------

verify_of() { # verify_of <story-file> - the `## Verification` block, comments and backticks
  # stripped. Verbatim mirror of wave-check.sh:89-97 (the Map slice's "reuse the same parse") -
  # duplicated rather than sourced because wave-check.sh is a standalone report script, not a
  # library, and Non-goals forbids touching it.
  awk '
    /^##[[:space:]]+Verification[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                           { inblock=0 }
    inblock && /^<!--/                         { incomment=1 }
    incomment                                  { if (/-->/) incomment=0; next }
    inblock && NF                              { gsub(/`/, ""); sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }
  ' "$1"
}

files_of() { # files_of <story-file> - the `## Files` block, comments skipped. Mirrors
  # scope-check.sh's own files_of() (also duplicated there, not sourced - same reason).
  awk '
    /^##[[:space:]]+Files[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                    { inblock=0 }
    inblock && /^<!--/                  { incomment=1 }
    incomment                           { if (/-->/) incomment=0; next }
    inblock && /^-[[:space:]]+/         { sub(/^-[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }
  ' "$1"
}

# command_cell_exists() and verification_segments() live in lib.sh since 0.18 - wave-check.sh
# runs the same ## Commands check at plan time, against the same constitution_file().

repeat_of() { # repeat_of <story-file> - the integer `repeat: N` under ## Verification, or 1
  local n
  n="$(verify_of "$1" | awk -F': *' '$1 ~ /^repeat$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
  case "$n" in ''|*[!0-9]*|0) n=1 ;; esac
  printf '%s' "$n"
}

wave_story_json() { # wave_story_json <story-file> - one C3 wave_stories object, keys in order
  # file/story/worker/model/repeat; `worker` defaults to worker-code when the frontmatter line is
  # absent, never null (Non-goals) - it is never computed from anything but that one line.
  local f="$1" id worker model
  id="$(fm_field "$f" story)"
  worker="$(fm_field "$f" worker)"; [ -n "$worker" ] || worker="worker-code"
  # `model` is the planner's per-story call (ADR-012: opus for every story unless the planner
  # writes another alias); absent means opus. The driver passes it as the dispatch parameter
  # and never reads the story file to learn it.
  model="$(fm_field "$f" model)"; [ -n "$model" ] || model="opus"
  printf '{"file":"%s","story":"%s","worker":"%s","model":"%s","repeat":%s}' "$f" "$id" "$worker" "$model" "$(repeat_of "$f")"
}

cmd_close_story() { # cmd_close_story <story-file> <commit:0|1> [<stamp>]
  local STORY="$1" DOCOMMIT="$2" STAMP="${3:-}"
  [ -n "$STORY" ] && [ -f "$STORY" ] || {
    echo "cycle: usage: $0 close-story <story-file> [--commit]" >&2
    emit false close-story 1 error "usage"
    exit 1
  }
  local SPECDIR; SPECDIR="$(dirname "$STORY")"
  pause_guard "$SPECDIR" close-story
  driver_guard "$SPECDIR" close-story "$STAMP"

  local ST SELFMARKED=0; ST="$(fm_field "$STORY" status)"
  case "$ST" in
    todo|in-progress) ;;
    done)
      # --- C3: a worker that self-marked `status: done` is a miss, not a fraud - if the
      # story's named files or the story file itself still carry an uncommitted diff, this
      # is the worker's own unfinished close, so proceed down the normal path (journaling the
      # self-mark) instead of refusing. A clean tree means a real prior close - since 0.18
      # (ADR-013 D5) that is a success, not exit 2: a worker that closes its own story and a
      # driver that retries the same close must both read "done", never an error.
      local -a DONE_PATHS=("$STORY")
      local donef
      while IFS= read -r donef; do
        [ -n "$donef" ] || continue
        DONE_PATHS+=("$donef")
      done <<EOF
$(files_of "$STORY")
EOF
      local DONE_DIRTY; DONE_DIRTY="$(git status --porcelain -- "${DONE_PATHS[@]}" 2>/dev/null)"
      if [ -z "$DONE_DIRTY" ]; then
        echo "cycle: $(fm_field "$STORY" story) - already done, nothing to close"
        emit_status close-story "$SPECDIR"
        exit 0
      fi
      # C3 revised (Minors 5, 6): the journal line is written once, below, only after
      # verification is green - every exit-4 path leaves journal.md untouched, so a retried
      # attempt never journals twice.
      SELFMARKED=1
      ;;
    *)
      echo "cycle: close-story - $STORY has status '$ST', expected todo or in-progress" >&2
      emit false close-story 2 error "status $ST, expected todo or in-progress"
      exit 2
      ;;
  esac

  # --- ADR-006: a story closes only when its worker wrote `returned: DONE` as its last edit;
  # `close-story` never writes or clears the key. Anything else is a miss, not a precondition
  # error - same exit 4 a red verification uses, so the driver's two-attempt rule sees one kind
  # of "not yet" (M3/K5).
  local RETURNED; RETURNED="$(fm_field "$STORY" returned)"
  case "$RETURNED" in
    DONE) ;;
    '')
      echo "cycle: close-story - $STORY has no 'returned: DONE'" >&2
      emit false close-story 4 repair "returned: missing"
      exit 4
      ;;
    *)
      echo "cycle: close-story - $STORY returned '$RETURNED', expected DONE" >&2
      emit false close-story 4 repair "returned $RETURNED"
      exit 4
      ;;
  esac

  bash "$HERE/scope-check.sh" "$STORY"

  local VERIFY; VERIFY="$(verify_of "$STORY")"
  local REPS; REPS="$(printf '%s\n' "$VERIFY" | awk -F': *' '$1 ~ /^repeat$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
  case "$REPS" in ''|*[!0-9]*|0) REPS=1 ;; esac
  local CMD_LIST; CMD_LIST="$(printf '%s\n' "$VERIFY" | awk -F': *' '$1 !~ /^repeat$/ { print }' | sed '/^[[:space:]]*$/d')"

  if [ -z "$CMD_LIST" ]; then
    echo "cycle: close-story - $STORY names no command under '## Verification'" >&2
    emit false close-story 4 repair "no verification command"
    exit 4
  fi

  # --- C2 amended (R11/C-4): every &&-segment of every line must be a literal cell of the
  # constitution's `## Commands` table (CLAUDE.vulyk.md in a sidecar hive, ADR-013 D1), or the
  # line is the literal "none - reviewed by lead-review" (which runs nothing, below) - a story
  # author never gets unprompted execution.
  local vline seg CONSTITUTION; CONSTITUTION="$(constitution_file "$ROOT")"
  while IFS= read -r vline; do
    [ -n "$vline" ] || continue
    [ "$vline" = "none — reviewed by lead-review" ] && continue
    # r2m9: a line matching a `## Commands` cell whole (its own `&&` and all) is one unit -
    # only a line that is NOT itself a cell gets split and checked segment by segment.
    command_cell_exists "$CONSTITUTION" "$vline" && continue
    while IFS= read -r seg; do
      [ -n "$seg" ] || continue
      command_cell_exists "$CONSTITUTION" "$seg" || {
        echo "cycle: close-story - verification command not in $CONSTITUTION's ## Commands: $seg" >&2
        emit false close-story 2 error "verification not in ## Commands: $seg"
        exit 2
      }
    done <<SEGEOF
$(verification_segments "$vline")
SEGEOF
  done <<EOF
$CMD_LIST
EOF

  # --- ADR-013 D5: the whole run - every line, every repeat - shares one budget under `timeout`,
  # so verification slower than the Bash tool's 10-minute cap reports exit 4 instead of dying
  # with the tool call. A per-command budget would not do: a repair story unions every story's
  # lines, and five 500 s commands still pass five 540 s limits. 540 s leaves the verb its own
  # margin inside that cap. `timeout 5 true` rather than `command -v`: on Windows a PATH that
  # finds System32's timeout.exe first would otherwise fail every verification line. ---------
  local VT="${VULYK_VERIFY_TIMEOUT:-540}" TIMEOUT_OK=0 vrc VSTART="$SECONDS" left
  case "$VT" in ''|*[!0-9]*|0) VT=540 ;; esac
  command -v timeout >/dev/null 2>&1 && timeout 5 true </dev/null >/dev/null 2>&1 && TIMEOUT_OK=1

  # --- run: one command at a time, the whole block repeated REPS times (R18/M-3) - a single
  # `bash -c "$multi_line_block"` used to report only the last line's exit status. -----------
  local i=1
  while [ "$i" -le "$REPS" ]; do
    while IFS= read -r vline; do
      [ -n "$vline" ] || continue
      [ "$vline" = "none — reviewed by lead-review" ] && continue
      if [ "$TIMEOUT_OK" -eq 1 ]; then
        left=$(( VT - (SECONDS - VSTART) ))
        if [ "$left" -le 0 ]; then vrc=124
        else timeout "$left" bash -c "$vline"; vrc=$?
        fi
      else
        bash -c "$vline"; vrc=$?
      fi
      if [ "$vrc" -eq 124 ] && [ "$TIMEOUT_OK" -eq 1 ]; then
        echo "cycle: close-story - verification timed out after ${VT}s (run $i/$REPS): $vline" >&2
        emit false close-story 4 repair "verification timed out after ${VT}s: $vline"
        exit 4
      fi
      if [ "$vrc" -ne 0 ]; then
        echo "cycle: close-story - verification failed (run $i/$REPS): $vline" >&2
        emit false close-story 4 repair "$vline"
        exit 4
      fi
    done <<EOF
$CMD_LIST
EOF
    i=$((i+1))
  done

  if [ "$SELFMARKED" = "1" ]; then
    # C3 revised: verification is green, so this closing is real - record the self-mark once,
    # with the story's own wave as `next` (Minor 5: never a hardcoded build:1).
    local SMWAVE; SMWAVE="$(fm_field "$STORY" wave)"
    case "$SMWAVE" in ''|*[!0-9]*) SMWAVE=1 ;; esac
    bash "$HERE/journal.sh" "$SPECDIR" "03-building" "close-story $(fm_field "$STORY" story): worker marked status: done itself, closing on the uncommitted diff" "build:$SMWAVE" >/dev/null
  fi

  if [ "$DOCOMMIT" = "1" ]; then
    # r2m2: `status: done` is written only after the commit lands - a failed commit (an
    # index.lock, say) must leave the story exactly as it was on disk, or a dirty tree with an
    # uncommitted `done` would misroute `status --json` on the next poll. Scoped to this
    # story's own declared Files (+ the story file itself, + the scope.jsonl row
    # scope-check.sh just wrote for it - R4/C-3(b)), never `-A`: a concurrent wave's other
    # in-progress story must not ride along in this commit.
    local ID TITLE f
    ID="$(fm_field "$STORY" story)"
    TITLE="$(grep -m1 '^# ' "$STORY" | sed 's/^#[[:space:]]*//; s/`//g')"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      git add -- "$f" >/dev/null 2>&1
    done <<EOF
$(files_of "$STORY")
EOF
    [ -f memory/stats/scope.jsonl ] && git add -- memory/stats/scope.jsonl >/dev/null 2>&1
    # Story 09: the anomaly-scan hook's log rides this commit too, same as scope.jsonl above.
    [ -n "$(git status --porcelain -- memory/stats/anomalies.jsonl 2>/dev/null)" ] && git add -- memory/stats/anomalies.jsonl >/dev/null 2>&1

    sed -i -E "s/^(status:[[:space:]]*)[^[:space:]#]+/\1done/" "$STORY"
    git add -- "$STORY" >/dev/null 2>&1

    local commit_err
    if ! commit_err="$(git commit -q -m "story($ID): $TITLE" 2>&1)"; then
      sed -i -E "s/^(status:[[:space:]]*)done/\1$ST/" "$STORY"
      echo "cycle: close-story - git commit failed: $commit_err" >&2
      emit false close-story 2 error "git commit failed"
      exit 2
    fi
  else
    sed -i -E "s/^(status:[[:space:]]*)[^[:space:]#]+/\1done/" "$STORY"
  fi

  echo "cycle: $(fm_field "$STORY" story) - closed, verification green"
  emit_status close-story "$SPECDIR"
  exit 0
}

# --- open-round: the court, staleness, orphan cleanup (D1/D5) ---------------------------------

remove_worktree_path() { # remove_worktree_path <path> - best-effort, never errors (D5: "a
  # missing court is not an error"); falls back to a plain rm -rf for a worktree git no
  # longer has registered (an orphan from a crash).
  local p="$1"
  [ -n "$p" ] || return 0
  git worktree remove --force "$p" >/dev/null 2>&1 || true
  rm -rf "$p" 2>/dev/null || true
}

clean_court() { # clean_court <slug> - removes every worktree (registered or orphaned) under
  # .vulyk/court/<slug>/ before a fresh one is built (D5: "an orphaned court ... is removed
  # by the next open-round before it creates its own" - covers a crashed judge's leftover
  # worktree and the previous round's court alike, unconditionally).
  local slug="$1" wt
  for wt in $(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | grep -F "/.vulyk/court/$slug/"); do
    remove_worktree_path "$wt"
  done
  rm -rf "$ROOT/.vulyk/court/$slug"
  git worktree prune >/dev/null 2>&1 || true
}

build_court() { # build_court <spec> <slug> <n> <head> <round-dir> - the blind seats' court: a
  # detached worktree at <head>, reduced to brief.md and committed inside itself. Prints
  # nothing; on a failure it reports, removes what it made and exits 2 (never returns then).
  local spec="$1" slug="$2" n="$3" head="$4" rd="$5"
  local court_abs="$ROOT/.vulyk/court/$slug/round-$n"
  mkdir -p "$(dirname "$court_abs")"
  local wt_err
  if ! wt_err="$(git worktree add --detach -q "$court_abs" "$head" 2>&1)"; then
    echo "cycle: open-round - could not create the court worktree at $court_abs: $wt_err" >&2
    # R17/M-6: ROUND is written last (below) precisely so a failure here leaves none behind;
    # also drop the now-empty round dir mkdir -p just created, so a retry sees no round at all
    # rather than an orphan directory current_round_dir() would otherwise pick up as open.
    rmdir "$rd" 2>/dev/null || true
    emit false open-round 2 error "worktree add failed"
    exit 2
  fi
  local court_spec="$court_abs/$spec"
  if [ -d "$court_spec" ]; then
    find "$court_spec" -mindepth 1 -maxdepth 1 ! -name 'brief.md' -exec rm -rf {} +
    # R15/M-1,M-2: the prune above leaves the court's own git status dirty (deletions
    # unstaged) and its HEAD still resolving the spec's real files via `git show` - commit the
    # reduction inside the court's own detached history (never the main repo's) so an
    # orientation `git status` in the court is clean and `HEAD:<spec>/plan.md` stops
    # resolving. A local identity is passed explicitly so a fixture without user.name works.
    if [ -n "$(git -C "$court_abs" status --porcelain 2>/dev/null)" ]; then
      git -C "$court_abs" add -A >/dev/null 2>&1
      # r2m7/N-m2: no `|| true` - a court that never reduced still resolves the spec's real
      # files via `git show`, and would be handed to a seat as though it were narrowed. Never
      # hooked or signed either: --no-verify because a repo-wide pre-commit hook has no
      # business running inside a throwaway detached worktree, gpgsign=false because there is
      # no key to sign with here and the main repo's signing config must not leak in.
      local red_err
      if ! red_err="$(git -C "$court_abs" -c user.name=VULYK -c user.email=vulyk@localhost \
        -c commit.gpgsign=false commit --no-verify -q -m "vulyk: reduce the court to brief.md" 2>&1)"; then
        echo "cycle: open-round - court reduction commit failed: $red_err" >&2
        remove_worktree_path "$court_abs"
        git worktree prune >/dev/null 2>&1 || true
        rmdir "$rd" 2>/dev/null || true
        emit false open-round 2 error "court reduction commit failed"
        exit 2
      fi
    fi
  fi
}

carry_seats() { # carry_seats <round-dir n> <round-dir n-1> <n-1> -> the space-separated blind
  # seats copied forward (ADR-013 D3): a GREEN or N/A report of round n-1 is copied into round n
  # as <seat>.md, its header marked ` · carried: round <n-1>` (inside the comment, so the header
  # stays one well-formed line). `review` is never carried - the reviewer always reads the new
  # diff. A seat round n already holds is left alone, so a re-stamp in place carries nothing twice.
  local rd="$1" prev="$2" pn="$3" seat src v out=""
  for seat in haiku sonnet opus; do
    src="$prev/$seat.md"
    [ -f "$src" ] || continue
    [ -f "$rd/$seat.md" ] && continue
    v="$(seat_field "$src" VERDICT)"
    case "$v" in GREEN|N/A) ;; *) continue ;; esac
    {
      head -1 "$src" | awk -v m=" $(printf '\xc2\xb7') carried: round $pn" '
        /[[:space:]]*-->[[:space:]]*$/ { sub(/[[:space:]]*-->[[:space:]]*$/, m " -->"); print; next }
        { print $0 m }'
      sed '1d' "$src"
    } > "$rd/$seat.md"
    out="$out $seat"
  done
  printf '%s' "${out# }"
}

build_round() { # build_round <spec> <slug> <n> <head> <pack> <ceiling> <commit:0|1> - the
  # "on success" effect shared by a fresh round and an in-place re-stamp (same code, same N).
  # Always terminates the process (exit 0 or, on a worktree failure, exit 2).
  local spec="$1" slug="$2" n="$3" head="$4" pack="$5" ceiling="$6" docommit="$7"
  local rd="$spec/council/round-$n"
  mkdir -p "$rd"
  clean_court "$slug"

  # C15/ADR-013 D3: the tier and the roster are derived once, here, and frozen into the round
  # (tier=, seats=) - a plan.md or Profile edit mid-round (or a stale re-stamp) never changes
  # what this round already requires.
  local tier required
  tier="$(tier_of "$spec")"
  required="$(required_seats_for_tier "$tier")"

  # No blind seat, no court (D3): the reviewer never enters one, so a review-only round would
  # pay a worktree for nobody.
  local court_abs=""
  case " $required " in
    *" haiku "*|*" sonnet "*|*" opus "*)
      build_court "$spec" "$slug" "$n" "$head" "$rd"
      court_abs="$ROOT/.vulyk/court/$slug/round-$n" ;;
  esac

  local since="" carried=""
  if [ "$n" -gt 1 ]; then
    since="$(round_field "$spec/council/round-$((n-1))" head)"
    carried="$(carry_seats "$rd" "$spec/council/round-$((n-1))" "$((n-1))")"
  fi

  {
    printf 'head=%s\n' "$head"
    printf 'pack=%s\n' "$pack"
    printf 'opened=%s\n' "$(now_ts)"
    printf 'court=%s\n' "$court_abs"
    printf 'ceiling=%s\n' "$ceiling"
    printf 'tier=%s\n' "$tier"
    printf 'seats=%s\n' "$required"
    [ -n "$since" ] && printf 'since=%s\n' "$since"
  } > "$rd/ROUND"

  local missing dispatch_val
  missing="$(missing_required_seats "$rd" "$required")"
  dispatch_val="judge"; [ -n "$missing" ] && dispatch_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
  local where="court at $court_abs"; [ -n "$court_abs" ] || where="no court (no blind seat required)"
  local note="round $n opened, $where"
  [ -n "$carried" ] && note="$note, carried from round $((n-1)): $(printf '%s' "$carried" | sed 's/ /, /g')"
  bash "$HERE/journal.sh" "$spec" "04-council:open" "$note" "$dispatch_val" >/dev/null

  [ "$docommit" = "1" ] && commit_paperwork open-round "vulyk($slug): open-round $n" "$spec"

  echo "cycle: $slug - $note"
  emit_status open-round "$spec" "$dispatch_val"
  exit 0
}

write_stale_row() { # write_stale_row <spec> <slug> <round-dir> <n> <a> - a STALE round record
  # (D1 crash rule: a manual code commit against an open round with a seat file folds it; the
  # row never counts against the ceiling - only RED rounds do, convergent-judge-07).
  # Idempotent like judge's own row/line/journal.
  local spec="$1" slug="$2" rd="$3" n="$4" a="$5"
  local rhead rpack; rhead="$(round_field "$rd" head)"; rpack="$(round_field "$rd" pack)"
  local plan="$spec/plan.md" dateonly; dateonly="$(date -u +%Y-%m-%d)"
  if ! row_exists "$slug" "$n"; then
    mkdir -p memory/stats
    # A seat this round's tier does not require defaults to "" like judge's own row, never
    # ABSENT (R21/minor 20, autonomous-cycle-19): ABSENT means "required and never recorded".
    local required; required="$(round_required_seats "$spec" "$rd")"
    local seat v model haiku_v="" sonnet_v="" opus_v="" review_v=""
    is_required_seat haiku  "$required" && haiku_v=ABSENT
    is_required_seat sonnet "$required" && sonnet_v=ABSENT
    is_required_seat opus   "$required" && opus_v=ABSENT
    is_required_seat review "$required" && review_v=ABSENT
    local haiku_model=unknown sonnet_model=unknown opus_model=unknown attempts=0
    for seat in haiku sonnet opus; do
      local f="$rd/$seat.md"
      if [ -f "$f" ]; then
        v="$(seat_field "$f" VERDICT)"; [ -n "$v" ] || v="RED"
        model="$(seat_header_field "$f" model)"; [ -n "$model" ] || model="unknown"
        case "$seat" in
          haiku)  haiku_v="$v";  haiku_model="$model" ;;
          sonnet) sonnet_v="$v"; sonnet_model="$model" ;;
          opus)   opus_v="$v";   opus_model="$model" ;;
        esac
      fi
      attempts=$((attempts + $(seat_attempt_count "$rd" "$seat")))
    done
    if [ -f "$rd/review.md" ]; then
      review_v="$(review_verdict_of "$rd/review.md")"; [ -n "$review_v" ] || review_v="ABSENT"
    fi
    attempts=$((attempts + $(seat_attempt_count "$rd" review)))
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"STALE","head":"%s","pack":"%s","asks":%s,"red":[],"red_unevidenced":[],"review_asks":[],"na":0,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":null,"note":"code moved after dispatch"}\n' \
      "$(now_ts)" "$slug" "$n" "${rhead:-unknown}" "$rpack" "$a" "$review_v" \
      "$haiku_v" "$haiku_model" "$sonnet_v" "$sonnet_model" "$opus_v" "$opus_model" "$attempts" >> memory/stats/council.jsonl
  fi
  if [ -f "$plan" ] && ! council_line_exists "$plan" "$n"; then
    council_append_line "$plan" "$(printf '**Council:** STALE round %s, %s, at %s, pack %s' "$n" "$dateonly" "${rhead:-unknown}" "$rpack")"
  fi
  journal_line_exists "$spec" "$n" "STALE" || bash "$HERE/journal.sh" "$spec" "04-council:STALE" "round $n stale, code moved after dispatch" "open-round" >/dev/null
}

cmd_open_round() { # cmd_open_round <spec> <commit:0|1> [<stamp>]
  local SPEC="$1" DOCOMMIT="$2" STAMP="${3:-}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 open-round <spec-dir> [--commit]" >&2
    emit false open-round 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" open-round
  driver_guard "$SPEC" open-round "$STAMP"

  local SLUG PLAN; SLUG="$(slug_of "$SPEC")"; PLAN="$SPEC/plan.md"

  # --- preconditions, in order, exit 2 naming the first failing one ------------------------
  local branch_v=""; [ -f "$PLAN" ] && branch_v="$(marker "$PLAN" Branch)"
  [ -n "$branch_v" ] || {
    echo "cycle: open-round - $SPEC has no **Branch:** line; run branch first" >&2
    emit false open-round 2 error "no Branch line"
    exit 2
  }

  local f st bad=""
  for f in "$SPEC"/*.md; do
    [ -f "$f" ] || continue
    is_story_file "$f" || continue
    st="$(fm_field "$f" status)"
    # r2m16/K1: a blocked story is its own named refusal, not a member of the "done or
    # blocked" set that lets open-round proceed - the council never opens a round while a
    # story is stuck, and the error names the story id and its file so the driver knows which
    # one to unblock, exit 2 same as every other precondition here (K1's Non-goal: no new
    # `next` value, no C3 state).
    if [ "$st" = blocked ]; then
      local sid; sid="$(fm_field "$f" story)"
      echo "cycle: open-round - story $sid is blocked: $f" >&2
      emit false open-round 2 open-round "story $sid is blocked: $f"
      exit 2
    fi
    case "$st" in done) ;; *) bad="$bad $(basename "$f")" ;; esac
  done
  [ -z "$bad" ] || {
    echo "cycle: open-round - stories not done/blocked:$bad" >&2
    emit false open-round 2 error "stories not done/blocked:$bad"
    exit 2
  }

  # The cycle's own paperwork is excluded, same whitelist as lib.sh's paperwork_only() (a
  # spec's plan.md/journal.md/council/*, the stats jsonls) - record-seat has no --commit of
  # its own, so an in-flight round's seat files are legitimately uncommitted here, and that
  # is exactly the state the HEAD-unchanged resume case below must tolerate, not reject.
  # Anything else dirty is real and still refuses (dirty_outside_paperwork, shared with claim).
  local dirty
  dirty="$(dirty_outside_paperwork)"
  [ -z "$dirty" ] || {
    echo "cycle: open-round - working tree has changes outside the cycle's own paperwork:" >&2
    printf '%s\n' "$dirty" | sed 's/^/  /' >&2
    emit false open-round 2 error "working tree not clean"
    exit 2
  }

  local A; A="$(asks_count "$SPEC")"
  { [ -n "$A" ] && [ "$A" -gt 0 ]; } 2>/dev/null || {
    echo "cycle: open-round - $SPEC/brief.md has no '## Asks' section, or it is empty" >&2
    emit false open-round 2 error "## Asks missing or empty"
    exit 2
  }

  # R21/M-10 (autonomous-cycle-19): an unparsable **Tier:** line must not silently buy the
  # largest court - it refuses here, naming the line, instead of tier_of() defaulting to 4.
  case "$(tier_of "$SPEC")" in
    [1-4]) ;;
    *)
      echo "cycle: open-round - $PLAN has no parsable **Tier:** line" >&2
      emit false open-round 2 error "no parsable **Tier:** line"
      exit 2
      ;;
  esac

  local HEAD PACK; HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"; PACK="$(pack_fingerprint "$SPEC")"
  local CEILING; CEILING="$(head -1 "$SPEC/council/CEILING" 2>/dev/null | tr -d '[:space:]')"; [ -n "$CEILING" ] || CEILING="$(tier_ceiling "$(tier_of "$SPEC")")"

  # --- an already-open round: resume, re-stamp in place, or fold it into a STALE + N+1 ------
  local RD; RD="$(current_round_dir "$SPEC")"
  if [ -n "$RD" ] && ! row_exists "$SLUG" "${RD##*/round-}"; then
    local N="${RD##*/round-}"
    # N-m3: a round dir without its own ROUND file (a crash before open-round's last write, or
    # ROUND lost) is not open at all - rewrite it in place, same N, never a no-op and never the
    # STALE/N+1 path below (which reads round_field values this dir does not have).
    if [ ! -f "$RD/ROUND" ]; then
      build_round "$SPEC" "$SLUG" "$N" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
    fi
    # A round's own opening (or STALE-folding) commit necessarily moves HEAD past the code head
    # it recorded - so "unchanged" must also accept a HEAD that only advanced by the cycle's own
    # paperwork since then (round_is_stale, C1), or every round would read itself as stale on
    # the very next call.
    if ! round_is_stale "$SPEC" "$N"; then
      # r2m3: an earlier --commit here may have failed after ROUND/journal.md were already
      # written (e.g. an index.lock) - a true no-op has nothing left to commit; anything still
      # uncommitted under this spec's own paperwork is finished now, not silently left behind.
      [ "$DOCOMMIT" = "1" ] && commit_paperwork open-round "vulyk($SLUG): open-round $N" "$SPEC"
      local missing required next_val
      required="$(round_required_seats "$SPEC" "$RD")"
      missing="$(missing_required_seats "$RD" "$required")"
      next_val="judge"; [ -n "$missing" ] && next_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
      echo "cycle: $SLUG - round $N already open at current HEAD, no-op"
      emit_status open-round "$SPEC" "$next_val"
      exit 0
    fi
    # A carried report is round n-1's evidence, not a dispatch of this round - a round holding
    # only carried seats re-stamps in place like an empty one (ADR-013 D3), no STALE fold.
    local has_seat=0 seat2
    for seat2 in haiku sonnet opus review; do
      [ -f "$RD/$seat2.md" ] && ! seat_is_carried "$RD/$seat2.md" && has_seat=1
    done
    if [ "$has_seat" -eq 0 ]; then
      build_round "$SPEC" "$SLUG" "$N" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
    fi
    write_stale_row "$SPEC" "$SLUG" "$RD" "$N" "$A"
    local NEXTN=$((N+1))
    # convergent-judge-07: the STALE row just written does not consume the budget - only
    # rounds that ended RED count against the ceiling.
    [ "$(red_rounds "$SLUG")" -lt "$CEILING" ] || {
      # R5/C-3(a): the ceiling reached here must leave a record - an ESCALATE row, the plan
      # line, ## Needs a human and the journal line - not just exit 6 into a silent loop.
      echo "cycle: open-round - $SLUG round $NEXTN would exceed ceiling $CEILING RED rounds" >&2
      write_ceiling_escalate "$SPEC" "$SLUG" "$N" "$RD"
      [ "$DOCOMMIT" = "1" ] && commit_paperwork open-round "vulyk($SLUG): escalate ceiling round $N" "$SPEC" memory/stats/council.jsonl
      emit true open-round 6 escalated
      exit 6
    }
    build_round "$SPEC" "$SLUG" "$NEXTN" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
  fi

  # --- no open round: a fresh round, gated by the ceiling -----------------------------------
  # ROUND_COUNT names the directory the next round follows; the gate itself counts rounds that
  # ended RED, not round numbers (convergent-judge-07).
  local ROUND_COUNT=0; [ -n "$RD" ] && ROUND_COUNT="${RD##*/round-}"
  [ "$(red_rounds "$SLUG")" -lt "$CEILING" ] || {
    echo "cycle: open-round - $SLUG is at the ceiling ($CEILING RED rounds)" >&2
    [ "$ROUND_COUNT" -gt 0 ] && {
      write_ceiling_escalate "$SPEC" "$SLUG" "$ROUND_COUNT" "$SPEC/council/round-$ROUND_COUNT"
      [ "$DOCOMMIT" = "1" ] && commit_paperwork open-round "vulyk($SLUG): escalate ceiling round $ROUND_COUNT" "$SPEC" memory/stats/council.jsonl
    }
    emit true open-round 6 escalated
    exit 6
  }
  build_round "$SPEC" "$SLUG" "$((ROUND_COUNT+1))" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
}

# --- reopen: the tier's own ceiling again after ESCALATE (D6; convergent-judge) - Tier 1 +1,
# Tier 2 +2, Tier 3-4 +3 RED rounds (GREEN and STALE rounds never count) ------------------------

append_after_answers() { # append_after_answers <brief.md> <block> - inserts before the next
  # "## " heading after "## Answers" (or at EOF if that's the last section); creates the
  # heading at EOF first when a spec was briefed a path that never wrote one (e.g. Tier 1).
  local brief="$1" block="$2"
  grep -q '^## Answers[[:space:]]*$' "$brief" 2>/dev/null || { printf '\n## Answers\n' >> "$brief"; }
  awk -v ins="$block" '
    BEGIN { in_ans=0; done=0 }
    { if (!done && in_ans && /^##[[:space:]]/) { print ins; done=1 }
      print
      if ($0 ~ /^##[[:space:]]+Answers[[:space:]]*$/) in_ans=1 }
    END { if (!done) print ins }
  ' "$brief" > "$brief.tmp.$$" && mv "$brief.tmp.$$" "$brief"
}

cmd_reopen() { # cmd_reopen <spec> <decision> <commit:0|1>
  local SPEC="$1" DECISION="$2" DOCOMMIT="$3"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] && [ -n "$DECISION" ] || {
    echo "cycle: usage: $0 reopen <spec-dir> \"<decision>\" [--commit]" >&2
    emit false reopen 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" reopen

  local SLUG; SLUG="$(slug_of "$SPEC")"
  local NEWEST; NEWEST="$(newest_row "$SLUG")"
  local nv=""; [ -n "$NEWEST" ] && nv="$(json_field "$NEWEST" verdict)"
  [ "$nv" = "ESCALATE" ] || {
    echo "cycle: reopen - $SLUG's newest council row is not ESCALATE (it is '${nv:-none}')" >&2
    emit false reopen 2 error "newest row is not ESCALATE"
    exit 2
  }
  local N; N="$(json_field "$NEWEST" round)"

  local BRIEF="$SPEC/brief.md"
  [ -f "$BRIEF" ] || {
    echo "cycle: reopen - $BRIEF not found" >&2
    emit false reopen 2 error "brief.md not found"
    exit 2
  }

  local dateonly; dateonly="$(date -u +%Y-%m-%d)"
  local marker_text="**After escalation (round $N, $dateonly).**"
  local already=0; grep -qF "$marker_text" "$BRIEF" 2>/dev/null && already=1

  local STEP; STEP="$(tier_ceiling "$(tier_of "$SPEC")")"
  local OLDCEIL; OLDCEIL="$(head -1 "$SPEC/council/CEILING" 2>/dev/null | tr -d '[:space:]')"; [ -n "$OLDCEIL" ] || OLDCEIL="$STEP"
  local NEWCEIL="$OLDCEIL"

  # ADR-013 D3: a reopened ESCALATE goes to repair - its row names the RED asks the owner just
  # decided about. `env` means the round itself failed, and a stale round is judged again
  # first; both re-run the round instead. `status` applies the same rule from disk.
  local REOPEN_NEXT="repair"
  if [ "$(json_field "$NEWEST" escalate)" = "env" ] || round_is_stale "$SPEC" "$N"; then
    REOPEN_NEXT="open-round"
  fi

  if [ "$already" -eq 0 ]; then
    append_after_answers "$BRIEF" "$(printf '\n%s\n> %s\n' "$marker_text" "$DECISION")"
    NEWCEIL=$((OLDCEIL+STEP))
    mkdir -p "$SPEC/council"
    printf '%s\n' "$NEWCEIL" > "$SPEC/council/CEILING"
    bash "$HERE/journal.sh" "$SPEC" "04-council:ESCALATE" "reopened after round $N, ceiling now $NEWCEIL" "$REOPEN_NEXT" >/dev/null
  fi

  # R7/M-4/C4: council/REOPEN names every round `reopen` has cleared, so `status` can tell an
  # ESCALATE row a human already reopened from one still waiting - one line per round, never
  # rewritten (mkdir -p: a spec can be reopened before any round dir of its own exists).
  mkdir -p "$SPEC/council"
  reopen_names_round "$SPEC" "$N" || printf 'round=%s \xc2\xb7 %s\n' "$N" "$(now_ts)" >> "$SPEC/council/REOPEN"

  [ "$DOCOMMIT" = "1" ] && commit_paperwork reopen "vulyk($SLUG): reopen after round $N" "$SPEC"

  echo "cycle: $SLUG - reopened after round $N, ceiling now $NEWCEIL"
  emit_status reopen "$SPEC" "$REOPEN_NEXT"
  exit 0
}

# --- pause / resume ------------------------------------------------------------------------
# Exempt from the PAUSE guard by design (C2): pause creates the semaphore, resume clears it.

cmd_pause() { # cmd_pause <spec> <why>
  local SPEC="$1" WHY="${2:-}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 pause <spec-dir> [\"why\"]" >&2
    emit false pause 1 error "usage"
    exit 1
  }
  local WHO="${OWNER:-${USER:-${USERNAME:-owner}}}"
  [ -n "$WHY" ] || WHY="no reason given"
  local HEAD; HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  {
    printf '%s \xc2\xb7 %s \xc2\xb7 %s\n' "$WHO" "$WHY" "$(now_ts)"
    printf 'head=%s\n' "$HEAD"
  } > "$SPEC/PAUSE"
  if [ -f "$SPEC/DRIVER" ]; then
    rm -f "$SPEC/DRIVER"
    bash "$HERE/journal.sh" "$SPEC" driver "driver released" paused >/dev/null
  fi
  bash "$HERE/journal.sh" "$SPEC" paused "$WHY" paused >/dev/null
  echo "cycle: $(slug_of "$SPEC") - paused: $WHY"
  emit true pause 0 paused
  exit 0
}

cmd_resume() { # cmd_resume <spec>
  local SPEC="$1"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 resume <spec-dir>" >&2
    emit false resume 1 error "usage"
    exit 1
  }
  local WAS_HEAD=""
  [ -f "$SPEC/PAUSE" ] && WAS_HEAD="$(sed -n 's/^head=//p' "$SPEC/PAUSE" | head -1)"
  rm -f "$SPEC/PAUSE"
  if [ -f "$SPEC/DRIVER" ]; then
    rm -f "$SPEC/DRIVER"
    bash "$HERE/journal.sh" "$SPEC" driver "driver released" status >/dev/null
  fi
  local NOWHEAD; NOWHEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  local STALE=false
  [ -n "$WAS_HEAD" ] && [ "$WAS_HEAD" != "$NOWHEAD" ] && STALE=true
  bash "$HERE/journal.sh" "$SPEC" resumed "resumed" status >/dev/null
  local status_out real_next
  status_out="$(cmd_status "$SPEC")"
  real_next="$(json_field "$status_out" next)"
  echo "cycle: $(slug_of "$SPEC") - resumed"
  printf '{"ok":true,"verb":"resume","exit":0,"next":"%s","stale":%s}\n' "$real_next" "$STALE"
  exit 0
}

# --- claim/release (ADR-004/K3: the DRIVER semaphore, no --commit accepted) ----------------

cmd_claim() { # cmd_claim <spec> <stamp>
  local SPEC="$1" STAMP="${2:-}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] && [ -n "$STAMP" ] || {
    echo "cycle: usage: $0 claim <spec-dir> <stamp>" >&2
    emit false claim 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" claim

  local holder; holder="$(driver_stamp "$SPEC")"
  if [ -n "$holder" ]; then
    if [ "$holder" = "$STAMP" ]; then
      echo "cycle: $(slug_of "$SPEC") - already claimed by $STAMP"
      emit true claim 0 claimed
      exit 0
    fi
    echo "cycle: $(slug_of "$SPEC") - DRIVER held by $holder" >&2
    emit false claim 2 error "held by $holder; run: bash scripts/cycle.sh release $SPEC $holder if that driver is dead"
    exit 2
  fi

  # ADR-013 D5: the same predicate open-round applies, checked before the build instead of
  # after it - an owner's stray file used to surface only when the first round tried to open.
  # A re-claim by the holder (above) is exempt: that run is already under way.
  local dirty; dirty="$(dirty_outside_paperwork)"
  if [ -n "$dirty" ]; then
    echo "cycle: claim - working tree has changes outside the cycle's own paperwork:" >&2
    printf '%s\n' "$dirty" | sed 's/^/  /' >&2
    emit false claim 2 error "working tree not clean"
    exit 2
  fi

  if ( set -o noclobber; { printf 'stamp=%s\n' "$STAMP"; printf 'claimed=%s\n' "$(now_ts)"; } > "$SPEC/DRIVER" ) 2>/dev/null; then
    echo "cycle: $(slug_of "$SPEC") - claimed by $STAMP"
    emit true claim 0 claimed
    exit 0
  fi

  # noclobber race: another claim won between our check and our write.
  holder="$(driver_stamp "$SPEC")"
  if [ "$holder" = "$STAMP" ]; then
    echo "cycle: $(slug_of "$SPEC") - already claimed by $STAMP"
    emit true claim 0 claimed
    exit 0
  fi
  echo "cycle: $(slug_of "$SPEC") - DRIVER held by $holder" >&2
  emit false claim 2 error "held by $holder; run: bash scripts/cycle.sh release $SPEC $holder if that driver is dead"
  exit 2
}

cmd_release() { # cmd_release <spec> <stamp>
  local SPEC="$1" STAMP="${2:-}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] && [ -n "$STAMP" ] || {
    echo "cycle: usage: $0 release <spec-dir> <stamp>" >&2
    emit false release 1 error "usage"
    exit 1
  }
  # No pause_guard (C4/ADR-001 D2): release is a lock-hygiene verb like status/pause/resume -
  # a dead driver's DRIVER file must be clearable while the spec is paused.

  local holder; holder="$(driver_stamp "$SPEC")"
  if [ -n "$holder" ] && [ "$holder" != "$STAMP" ]; then
    echo "cycle: $(slug_of "$SPEC") - DRIVER held by $holder" >&2
    emit false release 2 error "held by $holder"
    exit 2
  fi
  rm -f "$SPEC/DRIVER"
  echo "cycle: $(slug_of "$SPEC") - released"
  emit true release 0 released
  exit 0
}

# --- repair: the mechanical repair story (ADR-013 D4) - what the council found, quoted, with
# no planner in between: the asks come from the ledger row and the seat files, the findings
# verbatim, the scope and the verification from the stories already done -----------------------

ask_item() { # ask_item <spec> <n> -> the brief's `## Asks` item numbered n, as written
  awk -v want="$2" '
    /^##[[:space:]]+Asks[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                    { if (inblock) exit }
    inblock && /^[0-9]+\.[[:space:]]/  { n=$0; sub(/\..*$/, "", n); if (n+0 == want+0) { sub(/[[:space:]]+$/, ""); print; exit } }
  ' "$1/brief.md" 2>/dev/null
}

story_number() { # story_number <story-file> <slug> -> the NN of its `story: <slug>-NN` id or of
  # its <slug>-NN-*.md file name, whichever is larger; 0 when neither carries one
  local f="$1" slug="$2" a b
  a="$(fm_field "$f" story)"; a="${a#"$slug"-}"
  b="$(basename "$f" .md)"; b="${b#"$slug"-}"; b="${b%%-*}"
  case "$a" in ''|*[!0-9]*) a=0 ;; esac
  case "$b" in ''|*[!0-9]*) b=0 ;; esac
  a=$((10#$a)); b=$((10#$b))
  [ "$a" -gt "$b" ] && printf '%s' "$a" || printf '%s' "$b"
}

cmd_repair() { # cmd_repair <spec> <commit:0|1> [<stamp>]
  local SPEC="$1" DOCOMMIT="$2" STAMP="${3:-}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 repair <spec-dir> [--commit] [--stamp <s>]" >&2
    emit false repair 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" repair
  driver_guard "$SPEC" repair "$STAMP"

  local SLUG NEWEST N=""
  SLUG="$(slug_of "$SPEC")"
  NEWEST="$(newest_row "$SLUG")"
  [ -n "$NEWEST" ] && N="$(json_field "$NEWEST" round)"

  # Idempotent before the precondition: once a repair story for round N exists and is not done,
  # `status` routes to build, so a re-run must read "already there", not "next is not repair".
  # --commit here finishes a first run whose own commit failed (the r2m3 pattern).
  local f
  if [ -n "$N" ]; then
    for f in "$SPEC"/*-repair-round-"$N".md; do
      [ -f "$f" ] && is_story_file "$f" || continue
      [ "$(fm_field "$f" status)" = done ] && continue
      echo "cycle: $SLUG - $f already repairs round $N, nothing written"
      if [ "$DOCOMMIT" = "1" ]; then
        local -a cpaths=("$f"); [ -f "$SPEC/journal.md" ] && cpaths+=("$SPEC/journal.md")
        commit_paperwork repair "vulyk($SLUG): repair round $N" "${cpaths[@]}"
      fi
      emit_status repair "$SPEC"
      exit 0
    done
  fi

  local NEXT; NEXT="$(json_field "$(cmd_status "$SPEC")" next)"
  [ "$NEXT" = repair ] || {
    echo "cycle: repair - $SLUG's status says next is '$NEXT', not repair" >&2
    emit false repair 2 error "next is $NEXT, not repair"
    exit 2
  }

  local RD="$SPEC/council/round-$N" seat x asks=""
  # the asks: the row's red + review_asks, then any other RED ask a seat file carries (an
  # unevidenced RED is in the seat file, not in the row's red)
  for x in $(json_num_array "$NEWEST" red) $(json_num_array "$NEWEST" review_asks); do
    case " $asks " in *" $x "*) ;; *) asks="$asks $x" ;; esac
  done
  for seat in haiku sonnet opus; do
    [ -f "$RD/$seat.md" ] || continue
    for x in $(grep -E '^ASK [0-9]+:[[:space:]]*RED' "$RD/$seat.md" | sed -n 's/^ASK \([0-9][0-9]*\):.*/\1/p'); do
      case " $asks " in *" $x "*) ;; *) asks="$asks $x" ;; esac
    done
  done
  asks="$(sort_num_list "$asks")"

  local maxn=0 maxw=0 sf n w files="" verifs=""
  for sf in "$SPEC"/*.md; do
    is_story_file "$sf" || continue
    n="$(story_number "$sf" "$SLUG")"; [ "$n" -gt "$maxn" ] && maxn="$n"
    w="$(fm_field "$sf" wave)"; case "$w" in ''|*[!0-9]*) w=1 ;; esac
    [ "$w" -gt "$maxw" ] && maxw="$w"
    [ "$(fm_field "$sf" status)" = done ] || continue
    files="$files$(files_of "$sf")
"
    verifs="$verifs$(verify_of "$sf" | grep -vE '^repeat[[:space:]]*:')
"
  done
  local NN; NN="$(printf '%02d' $((maxn+1)))"
  local WAVE=$((maxw+1))
  local STORY="$SPEC/$SLUG-$NN-repair-round-$N.md"

  {
    printf -- '---\nstory: %s-%s\nstatus: todo\nreturned:\nworker: worker-code\nmodel: opus\nwave: %s\nblocked_by: []\n---\n\n' "$SLUG" "$NN" "$WAVE"
    printf '# Repair round %s\n\n' "$N"
    printf '## Goal\nMake the asks and findings council round %s left RED pass, and change nothing else.\n\n' "$N"
    printf '## Requirements\n'
    if [ -n "$asks" ]; then
      for x in $asks; do
        local item; item="$(ask_item "$SPEC" "$x")"
        [ -n "$item" ] && printf '> %s\n' "$item"
      done
    else
      printf 'No brief ask is RED in round %s - the findings below are the whole task.\n' "$N"
    fi
    printf '\n## Findings\n'
    for seat in haiku sonnet opus; do
      [ -f "$RD/$seat.md" ] && grep -E '^ASK [0-9]+:[[:space:]]*RED' "$RD/$seat.md"
    done
    # `[unanchored]` findings are never copied: they wait for /vulyk-ship's next circle.
    [ -f "$RD/review.md" ] && review_blocking_lines "$RD/review.md" \
      | grep -E '\[ask [0-9]+\]|\[regression\]' | grep -vF '[unanchored]'
    # An owner's REJECTED check at or after the round's opening turns it RED with no ask and no
    # finding (judge's override) - its note is then the only condition the repair can meet.
    local hlast hts ropened
    ropened="$(round_field "$RD" opened)"
    hlast="$(grep -F "\"spec\":\"$SLUG\"" memory/stats/human.jsonl 2>/dev/null | tail -1)"
    if [ -n "$hlast" ] && [ "$(json_field "$hlast" verdict)" = REJECTED ]; then
      hts="$(json_field "$hlast" ts)"
      if [ -n "$hts" ] && [ -n "$ropened" ] && { [ "$hts" \> "$ropened" ] || [ "$hts" = "$ropened" ]; }; then
        printf -- '- owner REJECTED at %s: %s\n' "$hts" "$(printf '%s' "$hlast" | sed -n 's/.*"note":"\(.*\)"}[[:space:]]*$/\1/p')"
      fi
    fi
    printf '\n## Files\n'
    printf '%s' "$files" | awk 'NF && !seen[$0]++ { print "- " $0 }'
    printf '\n## Verification\n'
    printf '%s' "$verifs" | awk 'NF && !seen[$0]++ { print "`" $0 "`" }'
  } > "$STORY"

  bash "$HERE/journal.sh" "$SPEC" "03-building" "repair round $N: $(basename "$STORY")" "build:$WAVE" >/dev/null
  [ "$DOCOMMIT" = "1" ] && commit_paperwork repair "vulyk($SLUG): repair round $N" "$STORY" "$SPEC/journal.md"

  echo "cycle: $SLUG - repair story for round $N: $STORY"
  emit_status repair "$SPEC"
  exit 0
}

# --- advance: one call per agent boundary (ADR-013 D2) - claim, ingest the seats' report
# files, then every mechanical step (branch, open-round, judge, repair) until the next thing
# needs an agent. Each step is the verb itself, run as a subprocess: the verbs stay the
# contract, advance only sequences them, so it can never disagree with them. ----------------

verb_json_str() { # verb_json_str <verb-line> <key> -> a string field of a verb's own last line,
  # still JSON-escaped (it goes back into JSON as is); the carried status is cut off first, so
  # a status key of the same name can never answer for the verb's own.
  printf '%s' "${1%%,\"status\":\{*}" | sed -nE "s/.*\"$2\":\"(([^\"\\\\]|\\\\.)*)\".*/\\1/p" | head -1
}

review_first_line() { # review_first_line <text> -> its first non-blank line, leading blanks and
  # a trailing CR dropped - the driver's foldReviews read `trim().split('\n')[0]`
  printf '%s\n' "$1" | awk 'NF { sub(/^[[:space:]]+/, ""); sub(/\r$/, ""); print; exit }'
}

fold_reviews() { # fold_reviews <top-file> <second-file> -> the Tier 4 `review` text (D2): the
  # 0.17 driver's foldReviews, moved here. Both first lines `VERDICT: PASS|BLOCK` -> one
  # verdict, BLOCK if either blocks, both bodies below; anything else -> `NO VERDICT: ...`,
  # which record-seat rejects, so the attempt is spent exactly as the driver spent it. A
  # missing file is an empty body.
  local r1="" r2="" f1 f2 v=PASS
  [ -f "$1" ] && r1="$(cat "$1")"
  [ -f "$2" ] && r2="$(cat "$2")"
  f1="$(review_first_line "$r1")"; f2="$(review_first_line "$r2")"
  if printf '%s' "$f1" | grep -qE '^VERDICT:[[:space:]]*(PASS|BLOCK)([^A-Za-z0-9_]|$)' \
    && printf '%s' "$f2" | grep -qE '^VERDICT:[[:space:]]*(PASS|BLOCK)([^A-Za-z0-9_]|$)'; then
    printf '%s\n%s\n' "$f1" "$f2" | grep -qE '^VERDICT:[[:space:]]*BLOCK([^A-Za-z0-9_]|$)' && v=BLOCK
    printf 'VERDICT: %s\n%s\n%s\n' "$v" "$r1" "$r2"
    return
  fi
  printf 'NO VERDICT: top=%s \xc2\xb7 second=%s\n%s\n%s\n' "${f1:-(no report)}" "${f2:-(no report)}" \
    "${r1:-(no report)}" "${r2:-(no report)}"
}

run_verb() { # run_verb <verb> <args...> - runs one cycle.sh verb as a subprocess (stdin is the
  # caller's redirect), forwards its prose lines, and leaves its last line in VERB_LINE and
  # its exit code in VERB_RC. Called in the current shell, never in a pipeline.
  local out
  out="$(bash "$HERE/cycle.sh" "$@")"; VERB_RC=$?
  VERB_LINE="$(printf '%s\n' "$out" | tail -1)"
  printf '%s\n' "$out" | sed '$d' | sed '/^$/d'
}

cmd_advance() { # cmd_advance <spec> <stamp> <claim:0|1> <ingest:0|1>
  local SPEC="$1" STAMP="$2" CLAIM="$3" INGEST="$4"
  local SLUG; SLUG="$(slug_of "$SPEC")"
  local -a SARG=(); [ -n "$STAMP" ] && SARG=(--stamp "$STAMP")
  local STEPS="" REJECTED="" VERB_LINE="" VERB_RC=0

  advance_stop() { # advance_stop <failed-verb> - the stop line, built from VERB_LINE/VERB_RC; a
    # verb that exited 0 without an ok:true line (garbled output) still stops as exit 2
    local rc="$VERB_RC" err; [ "$rc" -eq 0 ] && rc=2
    err="$(verb_json_str "$VERB_LINE" error)"; [ -n "$err" ] || err="$1: no JSON result line"
    printf '{"ok":false,"verb":"advance","exit":%s,"next":"%s","error":"%s","failed":"%s","steps":[%s],"rejected":[%s]}\n' \
      "$rc" "$(verb_json_str "$VERB_LINE" next)" "$err" "$1" "$STEPS" "$REJECTED"
    exit "$rc"
  }

  if [ "$CLAIM" = 1 ]; then
    run_verb claim "$SPEC" "$STAMP" </dev/null
    case "$VERB_LINE" in *'"ok":true'*) ;; *) advance_stop claim ;; esac
  fi

  # --- ingest: every missing seat of the open, non-stale round is recorded from the report
  # file the seat wrote at .vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md, or as an
  # empty report when it wrote none - a dead or turn-capped seat still spends its attempt. ---
  if [ "$INGEST" = 1 ]; then
    local RD N; RD="$(current_round_dir "$SPEC")"; N="${RD##*/round-}"
    if [ -n "$RD" ] && [ -f "$RD/ROUND" ] && ! row_exists "$SLUG" "$N" && ! round_is_stale "$SPEC" "$N"; then
      local REPDIR=".vulyk/reports/$SLUG/round-$N" TIER seat k err
      TIER="$(round_tier "$SPEC" "$RD")"
      for seat in $(missing_required_seats "$RD" "$(round_required_seats "$SPEC" "$RD")"); do
        k="$(seat_next_attempt "$RD" "$seat")"
        if [ "$seat" = review ] && [ "$TIER" = 4 ]; then
          run_verb record-seat "$SPEC" "$N" review ${SARG[@]+"${SARG[@]}"} \
            <<<"$(fold_reviews "$REPDIR/review-top.attempt-$k.md" "$REPDIR/review-second.attempt-$k.md")"
        elif [ -s "$REPDIR/$seat.attempt-$k.md" ]; then
          run_verb record-seat "$SPEC" "$N" "$seat" ${SARG[@]+"${SARG[@]}"} --file "$REPDIR/$seat.attempt-$k.md" </dev/null
        else
          run_verb record-seat "$SPEC" "$N" "$seat" ${SARG[@]+"${SARG[@]}"} </dev/null
        fi
        case "$VERB_RC" in
          0) ;;
          4)
            err="$(verb_json_str "$VERB_LINE" error)"
            REJECTED="${REJECTED:+$REJECTED,}{\"seat\":\"$seat\",\"attempt\":$k,\"error\":\"$err\"}" ;;
          *) advance_stop record-seat ;;
        esac
      done
    fi
  fi

  # --- the loop: status decides, the verb acts, at most 12 steps -----------------------------
  local st="" next last="" nsteps=0
  while :; do
    # A step's own last line carries the status it left behind (emit_status, C5) - read that
    # instead of computing it again; a line without one (exit 6) falls back to cmd_status.
    [ -n "$st" ] || st="$(cmd_status "$SPEC")"
    next="$(json_field "$st" next)"
    case "$next" in branch|open-round|judge|repair) ;; *) break ;; esac
    # A verb that leaves `next` naming itself again made no progress (a repair story that
    # cannot be built, say) - running it again would only repeat that; stop and say so.
    if [ "$next" = "$last" ]; then
      VERB_RC=2; VERB_LINE="{\"next\":\"$next\",\"error\":\"no progress: $next left next at $next\"}"
      advance_stop "$next"
    fi
    if [ "$nsteps" -ge 12 ]; then
      VERB_RC=2; VERB_LINE="{\"next\":\"$next\",\"error\":\"step cap: 12 steps and next is still $next\"}"
      advance_stop advance
    fi
    run_verb "$next" "$SPEC" --commit ${SARG[@]+"${SARG[@]}"} </dev/null
    nsteps=$((nsteps+1)); last="$next"
    STEPS="${STEPS:+$STEPS,}\"$next\""
    # exit 6 is ok:true (an escalation was recorded) - status reads `escalated` next time round
    case "$VERB_LINE" in *'"ok":true'*) ;; *) advance_stop "$next" ;; esac
    st=""
    case "$VERB_LINE" in *',"status":{'*) st="${VERB_LINE#*,\"status\":}"; st="${st%\}}" ;; esac
  done

  echo "cycle: $SLUG - advanced ${nsteps} step(s), next: $next"
  printf '{"ok":true,"verb":"advance","exit":0,"next":"%s","steps":[%s],"rejected":[%s],"status":%s}\n' \
    "$next" "$STEPS" "$REJECTED" "$st"
  exit 0
}

# --- dispatch ---------------------------------------------------------------------------------

case "$VERB" in
  status)
    [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
      echo "cycle: usage: $0 status <spec-dir> [--json]" >&2
      emit false status 1 error "usage"
      exit 1
    }
    cmd_status "$SPEC"
    ;;
  judge)
    COMMIT=0; STAMP=""
    prevarg=""
    for a in "$@"; do
      [ "$a" = "--commit" ] && COMMIT=1
      [ "$prevarg" = "--stamp" ] && STAMP="$a"
      prevarg="$a"
    done
    cmd_judge "$SPEC" "$COMMIT" "judge" "$STAMP"
    ;;
  escalate)
    cmd_escalate "$SPEC" "${@:3}"
    ;;
  briefed)
    COMMIT=0; MODE=""
    prevarg=""
    for a in "$@"; do
      [ "$a" = "--commit" ] && COMMIT=1
      [ "$prevarg" = "--mode" ] && MODE="$a"
      prevarg="$a"
    done
    cmd_briefed "$SPEC" "$COMMIT" "$MODE"
    ;;
  branch)
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_branch "$SPEC" "$COMMIT"
    ;;
  record-seat)
    shift
    cmd_record_seat "$@"
    ;;
  pause)
    cmd_pause "$SPEC" "${3:-}"
    ;;
  resume)
    cmd_resume "$SPEC"
    ;;
  claim)
    cmd_claim "$SPEC" "${3:-}"
    ;;
  release)
    cmd_release "$SPEC" "${3:-}"
    ;;
  close-story)
    COMMIT=0; STAMP=""
    prevarg=""
    for a in "$@"; do
      [ "$a" = "--commit" ] && COMMIT=1
      [ "$prevarg" = "--stamp" ] && STAMP="$a"
      prevarg="$a"
    done
    cmd_close_story "$SPEC" "$COMMIT" "$STAMP"
    ;;
  open-round)
    COMMIT=0; STAMP=""
    prevarg=""
    for a in "$@"; do
      [ "$a" = "--commit" ] && COMMIT=1
      [ "$prevarg" = "--stamp" ] && STAMP="$a"
      prevarg="$a"
    done
    cmd_open_round "$SPEC" "$COMMIT" "$STAMP"
    ;;
  reopen)
    DECISION="${3:-}"
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_reopen "$SPEC" "$DECISION" "$COMMIT"
    ;;
  repair)
    COMMIT=0; STAMP=""
    prevarg=""
    for a in "$@"; do
      [ "$a" = "--commit" ] && COMMIT=1
      [ "$prevarg" = "--stamp" ] && STAMP="$a"
      prevarg="$a"
    done
    cmd_repair "$SPEC" "$COMMIT" "$STAMP"
    ;;
  advance)
    # Unknown flags refuse here rather than being skipped like the older verbs' parsers do: a
    # mistyped --ingest would otherwise quietly leave every seat report unrecorded.
    STAMP=""; CLAIM=0; INGEST=0; BAD=""
    shift 2 2>/dev/null || shift $#
    while [ $# -gt 0 ]; do
      case "$1" in
        --stamp) STAMP="${2:-}"; [ -n "$STAMP" ] || BAD="--stamp needs a value"; shift 2 2>/dev/null || shift $# ;;
        --claim) CLAIM=1; shift ;;
        --ingest) INGEST=1; shift ;;
        *) BAD="unknown argument: $1"; shift ;;
      esac
    done
    [ "$CLAIM" = 1 ] && [ -z "$STAMP" ] && BAD="--claim needs --stamp"
    if [ -n "$BAD" ] || [ -z "$SPEC" ] || [ ! -d "$SPEC" ]; then
      echo "cycle: usage: $0 advance <spec-dir> [--stamp <s>] [--claim] [--ingest]${BAD:+ ($BAD)}" >&2
      emit false advance 1 error "usage${BAD:+: $BAD}"
      exit 1
    fi
    cmd_advance "$SPEC" "$STAMP" "$CLAIM" "$INGEST"
    ;;
  *)
    usage
    ;;
esac
