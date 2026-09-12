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
# (this story) adds `record-seat` (the D3 report contract: labels, ASK coverage, evidence,
# taint, the two-attempt re-ask), `briefed`, `branch`, `pause`/`resume` and the `PAUSE`
# guard on every mutating verb. `judge` itself is unchanged: it still reads seat files
# without re-validating the contract - `record-seat` is what keeps a malformed report off
# disk in the first place. `close-story`, `open-round` and `reopen` remain usage stubs
# (exit 1, after the PAUSE guard) for autonomous-cycle-04.
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

emit() { # emit <true|false> <verb> <exit> <next> [error]
  local ok="$1" verb="$2" ex="$3" next="$4" err="${5:-}"
  if [ -n "$err" ]; then
    printf '{"ok":%s,"verb":"%s","exit":%s,"next":"%s","error":"%s"}\n' "$ok" "$verb" "$ex" "$next" "$err"
  else
    printf '{"ok":%s,"verb":"%s","exit":%s,"next":"%s"}\n' "$ok" "$verb" "$ex" "$next"
  fi
}

usage() {
  echo "cycle: usage: $0 <verb> <spec-dir> [...]" >&2
  emit false "${VERB:-}" 1 "error" "usage: $0 <verb> <spec-dir> [...]"
  exit 1
}

pause_guard() { # pause_guard <spec> <verb-label> - exits 3 before anything mutates if PAUSEd;
  # returns (does not exit) when clear. `status`, `pause`, `resume` never call this (C2).
  local spec="$1" verb="$2"
  [ -n "$spec" ] && [ -f "$spec/PAUSE" ] || return 0
  echo "cycle: $(slug_of "$spec") - PAUSE present, $verb refuses to act." >&2
  emit false "$verb" 3 paused
  exit 3
}

[ -n "$VERB" ] || usage

# --- small parsers shared by status and judge ---------------------------------------------

fm_field() { # fm_field <story-file> <key> - a frontmatter "key: value" line, raw value
  awk -v k="$2" -F': *' '$1 == k { sub(/[[:space:]]*#.*$/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$1"
}

story_status_for_id() { # story_status_for_id <spec> <story-id>
  local spec="$1" id="$2" f
  for f in "$spec"/*.md; do
    [ -f "$f" ] || continue
    grep -q '^story:' "$f" 2>/dev/null || continue
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

round_field() { # round_field <round-dir> <key> - a ROUND file's "key=value" line
  sed -n "s/^$2=//p" "$1/ROUND" 2>/dev/null | head -1
}

row_exists() { # row_exists <slug> <round>
  [ -f memory/stats/council.jsonl ] || return 1
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl | grep -qF "\"round\":$2"
}

newest_row() { # newest_row <slug> -> the last council.jsonl line for this spec, or empty
  [ -f memory/stats/council.jsonl ] || return 0
  grep -F "\"spec\":\"$1\"" memory/stats/council.jsonl | tail -1
}

json_field() { # json_field <json-line> <key> - a flat top-level string or number value
  printf '%s' "$1" | sed -n "s/.*\"$2\":\"\\([^\"]*\\)\".*/\\1/p; s/.*\"$2\":\\([0-9][0-9]*\\).*/\\1/p" | head -1
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
  local TODO=0 PROG=0 DONE=0 BLOCKED=0 f st
  for f in "$SPEC"/*.md; do
    [ -f "$f" ] || continue
    grep -q '^story:' "$f" 2>/dev/null || continue
    st="$(fm_field "$f" status)"
    case "$st" in
      done) DONE=$((DONE+1)) ;;
      blocked) BLOCKED=$((BLOCKED+1)) ;;
      in-progress) PROG=$((PROG+1)) ;;
      *) TODO=$((TODO+1)) ;;
    esac
  done

  local BUILD_WAVE="" CLOSE_FILE="" WAVE_STORIES="" MAXWAVE=0 wv
  for f in "$SPEC"/*.md; do
    [ -f "$f" ] || continue
    grep -q '^story:' "$f" 2>/dev/null || continue
    wv="$(fm_field "$f" wave)"; [ -n "$wv" ] || wv=1
    [ "$wv" -gt "$MAXWAVE" ] 2>/dev/null && MAXWAVE="$wv"
  done
  local w
  for w in $(seq 1 "${MAXWAVE:-0}" 2>/dev/null); do
    local ready="" any_todo=0 any_prog="" wave_files=""
    for f in "$SPEC"/*.md; do
      [ -f "$f" ] || continue
      grep -q '^story:' "$f" 2>/dev/null || continue
      wv="$(fm_field "$f" wave)"; [ -n "$wv" ] || wv=1
      [ "$wv" = "$w" ] || continue
      st="$(fm_field "$f" status)"
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
          [ "$blockers_done" -eq 1 ] && ready="$ready $f"
          wave_files="$wave_files $f"
          ;;
        in-progress)
          [ -n "$any_prog" ] || any_prog="$f"
          wave_files="$wave_files $f"
          ;;
      esac
    done
    if [ -n "$ready" ]; then BUILD_WAVE="$w"; WAVE_STORIES="$wave_files"; break; fi
    if [ "$any_todo" -eq 0 ] && [ -n "$any_prog" ]; then CLOSE_FILE="$any_prog"; break; fi
  done
  local WAVE_JSON="null"; [ -n "$BUILD_WAVE" ] && WAVE_JSON="$BUILD_WAVE"

  # --- the open round, if any ---------------------------------------------------------------
  local RD ROUND_N=0 CEILING=3 COURT_JSON="null" OPEN_B=false MISSING="" STALE_B=false
  RD="$(current_round_dir "$SPEC")"
  if [ -n "$RD" ]; then
    ROUND_N="${RD##*/round-}"
    local RHEAD RCOURT
    RHEAD="$(round_field "$RD" head)"
    RCOURT="$(round_field "$RD" court)"
    CEILING="$(round_field "$RD" ceiling)"; [ -n "$CEILING" ] || CEILING=3
    [ -n "$RCOURT" ] && COURT_JSON="\"$RCOURT\""
    if ! row_exists "$SLUG" "$ROUND_N"; then
      OPEN_B=true
      local seat has_any=0
      for seat in haiku sonnet opus review; do
        if [ -f "$RD/$seat.md" ]; then has_any=1; else MISSING="$MISSING $seat"; fi
      done
      if [ "$has_any" -eq 1 ] && [ -n "$RHEAD" ] && [ "$RHEAD" != "$HEAD" ]; then STALE_B=true; fi
    fi
  fi
  MISSING="$(printf '%s' "$MISSING" | sed 's/^ *//')"

  # --- newest council.jsonl row for this spec -----------------------------------------------
  local NEWEST NEWEST_VERDICT="" NEWEST_ROUND="" NEWEST_PACK="" NEWEST_HEAD="" RED_LIST=""
  local VERDICT_JSON="null" ROUND_DIR_JSON="null"
  NEWEST="$(newest_row "$SLUG")"
  if [ -n "$NEWEST" ]; then
    NEWEST_VERDICT="$(json_field "$NEWEST" verdict)"
    NEWEST_ROUND="$(json_field "$NEWEST" round)"
    NEWEST_PACK="$(json_field "$NEWEST" pack)"
    NEWEST_HEAD="$(json_field "$NEWEST" head)"
    VERDICT_JSON="\"$NEWEST_VERDICT\""
    RED_LIST="$(printf '%s' "$NEWEST" | sed -n 's/.*"red":\[\([^]]*\)\].*/\1/p' | tr ',' ' ')"
    [ -n "$NEWEST_ROUND" ] && ROUND_DIR_JSON="\"$SPEC/council/round-$NEWEST_ROUND\""
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
    if [ -n "$MISSING" ]; then NEXT="dispatch:$(printf '%s' "$MISSING" | tr ' ' ',')"
    else NEXT="judge"
    fi
  elif [ "$NEWEST_VERDICT" = "ESCALATE" ]; then NEXT="escalated"
  elif [ "$NEWEST_VERDICT" = "GREEN" ] && [ "$NEWEST_PACK" = "$PACK" ] && { [ "$NEWEST_HEAD" = "$HEAD" ] || paperwork_only "$ROOT" "$NEWEST_HEAD" "$HEAD" 2>/dev/null; }; then
    NEXT="green"
  elif [ "$NEWEST_VERDICT" = "RED" ] && [ "$NEWEST_HEAD" = "$HEAD" ]; then
    NEXT="repair"
  else
    NEXT="open-round"
  fi

  printf '{"spec":"%s","slug":"%s","stage":"%s","next":"%s","briefed":%s,"approved":%s,"branch":%s,"head":"%s","pack":"%s","stories":{"todo":%s,"in-progress":%s,"done":%s,"blocked":%s},"wave":%s,"wave_stories":[%s],"round":%s,"ceiling":%s,"open":%s,"court":%s,"missing":[%s],"stale":%s,"verdict":%s,"red":[%s],"round_dir":%s,"paused":%s,"shipped":%s}\n' \
    "$SPEC" "$SLUG" "$(compute_stage "$SPEC" "$PLAN")" "$NEXT" "$BRIEFED_B" "$APPROVED_B" "$BRANCH_JSON" "$HEAD" "$PACK" \
    "$TODO" "$PROG" "$DONE" "$BLOCKED" \
    "$WAVE_JSON" "$(json_str_array "$WAVE_STORIES")" \
    "$ROUND_N" "$CEILING" "$OPEN_B" "$COURT_JSON" "$(json_str_array "$MISSING")" "$STALE_B" \
    "$VERDICT_JSON" "$(json_num_csv "$RED_LIST")" "$ROUND_DIR_JSON" "$PAUSED_B" "$SHIPPED_B"
}

compute_stage() { # compute_stage <spec> <plan> - a best-effort mirror of state.sh's ladder,
  # extended with the council stage (C9); not itself read by anything yet in this story.
  local spec="$1" plan="$2" stage="01-spec"
  [ -f "$spec/brief.md" ] || { echo "$stage"; return; }
  [ -f "$plan" ] && stage="02-planned"
  if [ -f "$plan" ]; then
    { [ -n "$(marker "$plan" Approved)" ] || [ -n "$(marker "$plan" Briefed)" ]; } && stage="02-approved"
    [ -n "$(marker "$plan" Branch)" ] && stage="03-building"
  fi
  local total=0 done_n=0 other_n=0 f st
  for f in "$spec"/*.md; do
    [ -f "$f" ] || continue
    grep -q '^story:' "$f" 2>/dev/null || continue
    total=$((total+1))
    st="$(fm_field "$f" status)"
    [ "$st" = done ] && done_n=$((done_n+1)) || other_n=$((other_n+1))
  done
  [ "$stage" = "03-building" ] && [ "$total" -gt 0 ] && [ "$other_n" -eq 0 ] && stage="03-built"
  local slug row v; slug="$(slug_of "$spec")"
  row="$(newest_row "$slug")"
  [ -n "$row" ] && v="$(json_field "$row" verdict)" && [ -n "$v" ] && stage="04-council:$v"
  case "$(grep '^\*\*Checked:\*\*' "$plan" 2>/dev/null | grep -v '^\*\*Checked:\*\* <' | tail -1)" in
    *ACCEPTED*) stage="05-checked" ;;
    *REJECTED*) stage="05-rejected" ;;
  esac
  [ -f "$plan" ] && [ -n "$(marker "$plan" Shipped)" ] && stage="06-shipped"
  [ -f "$spec/PAUSE" ] && stage="paused"
  echo "$stage"
}

# --- judge / escalate ------------------------------------------------------------------------
# escalate is called by judge itself whenever the computed verdict is ESCALATE; as a CLI verb
# it currently runs the identical computation (the standalone case - open-round exiting 6
# before any round is judged - is story 04's, once open-round exists).

seat_field() { # seat_field <file> <LABEL> - value after "LABEL: " on the first matching line
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1
}

seat_field_str() { # seat_field_str <text> <LABEL> - same as seat_field, over a string, not a file
  printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1
}

seat_header_field() { # seat_header_field <file> <key> - from the "<!-- seat: ... -->" header
  head -1 "$1" 2>/dev/null | grep -oE "$2: [^·]*" | head -1 | sed "s/^$2: *//; s/ *$//"
}

seat_presence() { # seat_presence <round-dir> <seat> -> present | absent | missing
  local rd="$1" seat="$2"
  if [ -f "$rd/$seat.md" ]; then echo present
  elif [ -f "$rd/$seat.attempt-2.md" ]; then echo absent
  else echo missing
  fi
}

seat_ask_lines() { # seat_ask_lines <file> -> "n verdict evidenced(1/0)" per ASK line
  grep -E '^ASK [0-9]+:' "$1" 2>/dev/null | while IFS= read -r line; do
    local n v ev=0
    n="$(printf '%s' "$line" | sed -n 's/^ASK \([0-9][0-9]*\):.*/\1/p')"
    v="$(printf '%s' "$line" | sed -n 's/^ASK [0-9][0-9]*:[[:space:]]*\(GREEN\|RED\|N\/A\).*/\1/p')"
    case "$line" in *run:*saw:*) ev=1 ;; *url:*saw:*) ev=1 ;; esac
    printf '%s %s %s\n' "$n" "$v" "$ev"
  done
}

review_verdict_of_text() { # review_verdict_of_text <text> -> PASS | BLOCK | "" (D3)
  local line
  line="$(printf '%s\n' "$1" | grep -m1 -E '^(PASS|BLOCK)\b|^VERDICT: (PASS|BLOCK)')"
  case "$line" in
    VERDICT:*) printf '%s' "$line" | sed -n 's/^VERDICT: \(PASS\|BLOCK\).*/\1/p' ;;
    PASS*) echo PASS ;;
    BLOCK*) echo BLOCK ;;
  esac
}

review_verdict_of() { # review_verdict_of <file> -> PASS | BLOCK | "" (D3)
  review_verdict_of_text "$(cat "$1" 2>/dev/null)"
}

council_line_exists() { grep -qE "^\*\*Council:\*\*.*round $2," "$1" 2>/dev/null; } # <plan> <round>
journal_line_exists() { [ -f "$1/journal.md" ] && grep -qF "round $2 verdict $3" "$1/journal.md"; } # <spec> <round> <verdict>

cmd_judge() { # cmd_judge <spec> <commit:0|1> [<verb-label>]
  local SPEC="$1" DOCOMMIT="$2" VERBLABEL="${3:-judge}"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 $VERBLABEL <spec-dir> [--commit]" >&2
    emit false "$VERBLABEL" 1 error "usage"
    exit 1
  }
  local SLUG PLAN; SLUG="$(slug_of "$SPEC")"; PLAN="$SPEC/plan.md"

  pause_guard "$SPEC" "$VERBLABEL"

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
  RCEILING="$(round_field "$RD" ceiling)"; [ -n "$RCEILING" ] || RCEILING=3

  # --- presence pass: every seat must be present or ABSENT, in order -----------------------
  local seat pres
  for seat in haiku sonnet opus review; do
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
    else
      v="ABSENT"; model="unknown"
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

  local rf="$RD/review.md"
  if [ -f "$rf" ]; then
    review_v="$(review_verdict_of "$rf")"; [ -n "$review_v" ] || review_v="BLOCK"
  else
    review_v="ABSENT"
  fi

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
      if [ "$hv" = REJECTED ] && [ -n "$hts" ] && [ -n "$ROPENED" ] && [ "$hts" \> "$ROPENED" ]; then
        override_red=1
      fi
    fi
  fi

  # --- the verdict rule (D4), first match wins ----------------------------------------------
  local overall="" next_val="" escalate_reason=""
  local half=$(( (A+1)/2 ))
  if [ "$override_red" -eq 1 ]; then
    overall="RED"; next_val="repair"
  elif [ "$haiku_v" = ABSENT ] && [ "$sonnet_v" = ABSENT ] && [ "$opus_v" = ABSENT ]; then
    overall="ESCALATE"; escalate_reason="env"; next_val="escalated"
  elif [ "$red_e_count" -gt 0 ] && [ "$red_e_count" -ge "$half" ]; then
    overall="ESCALATE"; escalate_reason="half"; next_val="escalated"
  elif [ "$review_v" = "BLOCK" ] || [ "$red_e_count" -gt 0 ] || [ "$red_u_count" -gt 0 ]; then
    if [ "$N" -ge "$RCEILING" ]; then
      overall="ESCALATE"; escalate_reason="ceiling"; next_val="escalated"
    else
      overall="RED"; next_val="repair"
    fi
  else
    local ok=1
    for v in "$haiku_v" "$sonnet_v" "$opus_v"; do case "$v" in GREEN|N/A) ;; *) ok=0 ;; esac; done
    if [ "$ok" -eq 1 ] && [ "$review_v" = "PASS" ]; then
      overall="GREEN"; next_val="green"
    else
      overall="RED"; next_val="repair" # not reached by any story-01 fixture; conservative default
    fi
  fi

  # --- write: row -> plan line -> (Needs a human) -> journal, each idempotently ------------
  local head7="${RHEAD:-unknown}" dateonly; dateonly="$(date -u +%Y-%m-%d)"
  if ! row_exists "$SLUG" "$N"; then
    mkdir -p memory/stats
    local escjson="null"; [ -n "$escalate_reason" ] && escjson="\"$escalate_reason\""
    local attempts=0
    for seat in haiku sonnet opus review; do [ -f "$RD/$seat.md" ] && attempts=$((attempts+1)); done
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"%s","head":"%s","pack":"%s","asks":%s,"red":[%s],"red_unevidenced":[%s],"na":%s,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":%s,"note":""}\n' \
      "$(now_ts)" "$SLUG" "$N" "$overall" "$head7" "$RPACK" "$A" \
      "$(json_num_csv "$red_e")" "$(json_num_csv "$red_u")" "$na_count" \
      "$review_v" "$haiku_v" "$haiku_model" "$sonnet_v" "$sonnet_model" "$opus_v" "$opus_model" \
      "$attempts" "$escjson" >> memory/stats/council.jsonl
  fi

  if [ -f "$PLAN" ] && ! council_line_exists "$PLAN" "$N"; then
    local suffix=""; [ -n "$red_e" ] && suffix=" - red: $(json_num_csv "$red_e")"
    printf '**Council:** %s round %s, %s, at %s, pack %s%s\n' \
      "$overall" "$N" "$dateonly" "$head7" "$RPACK" "$suffix" >> "$PLAN"
  fi

  if [ "$overall" = "ESCALATE" ] && [ -f "$PLAN" ] && ! grep -qF "reason: $escalate_reason · round $N" "$PLAN" 2>/dev/null; then
    {
      grep -q '^## Needs a human' "$PLAN" 2>/dev/null || printf '\n## Needs a human\n'
      printf -- '- reason: %s · round %s · %s\n' "$escalate_reason" "$N" "$dateonly"
      for u in $red_e $red_u; do
        printf -- '- ask %s: RED - see %s/*.md for evidence\n' "$u" "$RD"
      done
      printf -- '- seats: %s/\n' "$RD"
    } >> "$PLAN"
  fi

  if ! journal_line_exists "$SPEC" "$N" "$overall"; then
    bash "$HERE/journal.sh" "$SPEC" "04-council:$overall" "round $N verdict $overall at $head7 pack $RPACK" "$next_val" >/dev/null
  fi

  if [ "$DOCOMMIT" = "1" ] && [ -n "$(git status --porcelain -- "$SPEC" memory/stats/council.jsonl 2>/dev/null)" ]; then
    git add -A -- "$SPEC" memory/stats/council.jsonl >/dev/null 2>&1
    git commit -q -m "vulyk($SLUG): $VERBLABEL round $N -> $overall" >/dev/null 2>&1 || true
  fi

  echo "cycle: $SLUG - round $N judged: $overall"
  local exit_code=0
  case "$overall" in GREEN) exit_code=0 ;; RED) exit_code=4 ;; ESCALATE) exit_code=6 ;; esac
  emit true "$VERBLABEL" "$exit_code" "$next_val"
  exit "$exit_code"
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

  if [ "$DOCOMMIT" = "1" ] && [ -n "$(git status --porcelain -- "$SPEC" 2>/dev/null)" ]; then
    git add -A -- "$SPEC" >/dev/null 2>&1
    git commit -q -m "vulyk($SLUG): briefed" >/dev/null 2>&1 || true
  fi

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
    if git rev-parse --verify -q "$BR" >/dev/null 2>&1; then
      git checkout -q "$BR" >/dev/null 2>&1
    else
      git checkout -q -b "$BR" >/dev/null 2>&1
    fi
    local line="**Branch:** $BR"
    if grep -q '^\*\*Branch:\*\*' "$PLAN"; then
      sed -i "s#^\*\*Branch:\*\*.*#$line#" "$PLAN"
    else
      printf '%s\n' "$line" >> "$PLAN"
    fi
    bash "$HERE/journal.sh" "$SPEC" "03-building" "branch $BR created" "build:1" >/dev/null
  fi

  if [ "$DOCOMMIT" = "1" ] && [ -n "$(git status --porcelain -- "$SPEC" 2>/dev/null)" ]; then
    git add -A -- "$SPEC" >/dev/null 2>&1
    git commit -q -m "vulyk($SLUG): branch $BR" >/dev/null 2>&1 || true
  fi

  echo "cycle: $SLUG - branch $BR"
  emit true branch 0 "build:1"
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

missing_label() { # missing_label <report> -> the first required C5 label absent, or ""
  printf '%s\n' "$1" | grep -q '^COUNCIL:'        || { printf 'COUNCIL:'; return; }
  printf '%s\n' "$1" | grep -q '^MODEL:'          || { printf 'MODEL:'; return; }
  printf '%s\n' "$1" | grep -q '^COURT:'          || { printf 'COURT:'; return; }
  printf '%s\n' "$1" | grep -q '^VERDICT:'        || { printf 'VERDICT:'; return; }
  printf '%s\n' "$1" | grep -q '^ASSUMED CONFIG:' || { printf 'ASSUMED CONFIG:'; return; }
  printf '%s\n' "$1" | grep -q '^RAN:'            || { printf 'RAN:'; return; }
  printf '%s\n' "$1" | grep -q '^PATH:'           || { printf 'PATH:'; return; }
  printf '%s\n' "$1" | grep -q '^UNASKED:'        || { printf 'UNASKED:'; return; }
  printf '%s\n' "$1" | grep -q '^BREACH:'         || { printf 'BREACH:'; return; }
  return 0
}

taint_reason() { # taint_reason <report> <slug> -> the D3 taint description, or "" when clean.
  # The four literal patterns, case-sensitive, nothing else (no prose heuristics).
  local report="$1" slug="$2" esc
  esc="$(printf '%s' "$slug" | sed 's/[.[\*^$()+?{|]/\\&/g')"
  printf '%s' "$report" | grep -qE "${esc}-[0-9]+" && { printf 'names a story id %s-NN' "$slug"; return; }
  printf '%s' "$report" | grep -qF 'plan.md'       && { printf 'names plan.md'; return; }
  printf '%s' "$report" | grep -qF 'journal.md'    && { printf 'names journal.md'; return; }
  printf '%s' "$report" | grep -qF 'council/'      && { printf 'names council/'; return; }
  return 0
}

ask_line_of() { printf '%s\n' "$1" | grep -m1 -E "^ASK $2:"; } # ask_line_of <report> <n>
ask_verdict_of() { printf '%s' "$1" | sed -n 's/^ASK [0-9][0-9]*:[[:space:]]*\(GREEN\|RED\|N\/A\).*/\1/p'; } # <ask-line>
ask_rest_of() { printf '%s' "$1" | sed 's/.* - //'; } # <ask-line> -> its evidence/why clause (text after the last " - ")

cmd_record_seat_review() { # cmd_record_seat_review <spec> <rd> <n> <attempt> <report> <model-opt> <head>
  local SPEC="$1" RD="$2" N="$3" ATTEMPT="$4" REPORT="$5" MODEL_OPT="$6" HEAD="$7"
  local RPACK; RPACK="$(round_field "$RD" pack)"
  local model="$MODEL_OPT"; [ -n "$model" ] || model="$(seat_field_str "$REPORT" MODEL)"; [ -n "$model" ] || model="unknown"

  local verdict; verdict="$(review_verdict_of_text "$REPORT")"
  if [ -z "$verdict" ]; then
    write_seat_file "$RD/review.attempt-$ATTEMPT.md" review "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "" "$REPORT"
    echo "cycle: record-seat - review round $N attempt $ATTEMPT: MALFORMED: no PASS or BLOCK found" >&2
    emit false record-seat 4 error "MALFORMED: no PASS or BLOCK found"
    exit 4
  fi

  local extra; extra="$(printf ' \xc2\xb7 verdict: %s' "$verdict")"
  write_seat_file "$RD/review.md" review "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$extra" "$REPORT"
  echo "cycle: record-seat - review recorded for round $N (verdict $verdict)"
  local seat missing=""
  for seat in haiku sonnet opus review; do [ -f "$RD/$seat.md" ] || missing="$missing $seat"; done
  missing="$(printf '%s' "$missing" | sed 's/^ *//')"
  local next_val="judge"; [ -n "$missing" ] && next_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
  emit true record-seat 0 "$next_val"
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
  local nums="" n line
  while IFS= read -r line; do
    case "$line" in "ASK "[0-9]*) ;; *) continue ;; esac
    n="$(printf '%s' "$line" | sed -n 's/^ASK \([0-9][0-9]*\):.*/\1/p')"
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
      "N/A") case "$rest" in why:*) ;; *) reject_seat_report "$RD" "$SEAT" "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$REPORT" "ASK $i is N/A without why:" ;; esac ;;
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
        rest="$(ask_rest_of "$line")"
        case "$rest" in
          run:*saw:*|url:*saw:*) ;;
          *) unevidenced="$unevidenced $i" ;;
        esac
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
    local u short prefix_stripped
    for u in $unevidenced; do
      line="$(ask_line_of "$REPORT" "$u")"
      v="$(ask_verdict_of "$line")"
      if [ "$v" = GREEN ]; then
        rest="$(ask_rest_of "$line")"
        prefix_stripped="$(printf '%s' "$line" | sed -E "s/^ASK $u: (GREEN|RED|N\/A) - //")"
        short="${prefix_stripped% - $rest}"
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

  local seat missing=""
  for seat in haiku sonnet opus review; do [ -f "$RD/$seat.md" ] || missing="$missing $seat"; done
  missing="$(printf '%s' "$missing" | sed 's/^ *//')"
  local next_val="judge"; [ -n "$missing" ] && next_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
  emit true record-seat 0 "$next_val"
  exit 0
}

cmd_record_seat() { # cmd_record_seat <spec> <N> <seat> [--model <id>] - report on stdin
  local SPEC="${1:-}" N="${2:-}" SEAT="${3:-}"
  local nargs=$#
  if [ "$nargs" -ge 3 ]; then shift 3; else shift "$nargs"; fi
  local MODEL_OPT=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) MODEL_OPT="${2:-}"; shift 2 2>/dev/null || shift $# ;;
      *) shift ;;
    esac
  done

  case "$SEAT" in
    haiku|sonnet|opus|review) ;;
    *)
      echo "cycle: usage: $0 record-seat <spec-dir> <N> <haiku|sonnet|opus|review> [--model <id>] < report" >&2
      emit false record-seat 1 error "usage"
      exit 1
      ;;
  esac
  case "$N" in
    ''|*[!0-9]*)
      echo "cycle: usage: $0 record-seat <spec-dir> <N> <seat> [--model <id>] < report" >&2
      emit false record-seat 1 error "usage"
      exit 1
      ;;
  esac
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 record-seat <spec-dir> <N> <seat> [--model <id>] < report" >&2
    emit false record-seat 1 error "usage"
    exit 1
  }

  pause_guard "$SPEC" record-seat

  local RD="$SPEC/council/round-$N"
  [ -f "$RD/ROUND" ] || {
    echo "cycle: record-seat - no open round $N for $SPEC ($RD/ROUND not found)" >&2
    emit false record-seat 2 error "no open round $N"
    exit 2
  }
  local HEAD; HEAD="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  local RHEAD; RHEAD="$(round_field "$RD" head)"
  [ "$RHEAD" = "$HEAD" ] || {
    echo "cycle: record-seat - round $N is stale (ROUND head=$RHEAD, current HEAD=$HEAD)" >&2
    emit false record-seat 5 stale
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

  local REPORT; REPORT="$(cat)"

  if [ "$SEAT" = review ]; then
    cmd_record_seat_review "$SPEC" "$RD" "$N" "$ATTEMPT" "$REPORT" "$MODEL_OPT" "$HEAD"
  else
    cmd_record_seat_council "$SPEC" "$RD" "$N" "$SEAT" "$ATTEMPT" "$REPORT" "$MODEL_OPT" "$HEAD"
  fi
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
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_judge "$SPEC" "$COMMIT" "judge"
    ;;
  escalate)
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_judge "$SPEC" "$COMMIT" "escalate"
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
  close-story|open-round|reopen)
    pause_guard "$SPEC" "$VERB"
    echo "cycle: '$VERB' is not implemented yet - autonomous-cycle story 04. CLI surface only." >&2
    emit false "$VERB" 1 error "not implemented"
    exit 1
    ;;
  *)
    usage
    ;;
esac
