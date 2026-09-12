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
# This story (autonomous-cycle-01) implements `status`, `judge` and `escalate` only.
# `briefed`, `branch`, `close-story`, `open-round`, `record-seat`, `reopen`, `pause`,
# `resume` are registered below as usage stubs (exit 1) so the CLI surface is visible
# end-to-end; they are story 02/03/04's work. `judge` reads seat files written by hand
# (tests) or, later, by `record-seat` - it does not validate the report contract beyond
# the `VERDICT:` line, `ASK <n>:` verdicts and their evidence tokens; full D3 validation
# (MALFORMED, taint, the re-ask) is `record-seat`'s job.
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

review_verdict_of() { # review_verdict_of <file> -> PASS | BLOCK | "" (D3)
  local line
  line="$(grep -m1 -E '^(PASS|BLOCK)\b|^VERDICT: (PASS|BLOCK)' "$1" 2>/dev/null)"
  case "$line" in
    VERDICT:*) printf '%s' "$line" | sed -n 's/^VERDICT: \(PASS\|BLOCK\).*/\1/p' ;;
    PASS*) echo PASS ;;
    BLOCK*) echo BLOCK ;;
  esac
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

  if [ -f "$SPEC/PAUSE" ]; then
    echo "cycle: $SLUG - PAUSE present, $VERBLABEL refuses to act." >&2
    emit false "$VERBLABEL" 3 paused
    exit 3
  fi

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
  briefed|branch|close-story|open-round|record-seat|reopen|pause|resume)
    echo "cycle: '$VERB' is not implemented yet - autonomous-cycle story 02/03/04. CLI surface only." >&2
    emit false "$VERB" 1 error "not implemented"
    exit 1
    ;;
  *)
    usage
    ;;
esac
