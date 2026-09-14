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
# and `reopen` (ceiling +3 after ESCALATE); `judge` gains only the court removal - the
# verdict rule and the row schema are unchanged from story 01/03.
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

emit() { # emit <true|false> <verb> <exit> <next> [error]
  local ok="$1" verb="$2" ex="$3" next="$4" err="${5:-}"
  verb="$(json_escape "$verb")"
  next="$(json_escape "$next")"
  if [ -n "$err" ]; then
    err="$(json_escape "$err")"
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
  local v
  v="$(grep -E "^\*\*$2:\*\*" "$1" 2>/dev/null | tail -1 | sed "s/^\*\*$2:\*\*[[:space:]]*//")"
  case "$v" in ''|'<'*) return 0 ;; esac
  printf '%s' "$v"
}

pause_guard() { # pause_guard <spec> <verb-label> - exits 3 before anything mutates if PAUSEd;
  # returns (does not exit) when clear. `status`, `pause`, `resume` never call this (C2).
  local spec="$1" verb="$2"
  [ -n "$spec" ] && [ -f "$spec/PAUSE" ] || return 0
  echo "cycle: $(slug_of "$spec") - PAUSE present, $verb refuses to act." >&2
  local first_line; first_line="$(head -1 "$spec/PAUSE" 2>/dev/null)"
  emit false "$verb" 3 paused "paused: $first_line"
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

tier_of() { # tier_of <spec> -> the spec's tier 1-4, from plan.md's first "**Tier:**" line
  # (autonomous-cycle-18, C15). That line is "**Tier:** 4 \xc2\xb7 **Spec slug:** ..." on one
  # line, so this parses only the leading digit - never marker(), which would return the
  # whole rest of the line as the value. Absent or unparsable prints nothing (R21/m-1,
  # autonomous-cycle-19): there is no default tier anymore - a silent 4 used to buy the
  # largest court unasked, and this function never writes (status calls it on every read;
  # m-1 is exactly this journal write, now gone - journal.md is untouched by a status call).
  local spec="$1" plan
  plan="$spec/plan.md"
  grep -m1 '^\*\*Tier:\*\*' "$plan" 2>/dev/null | sed -n 's/^\*\*Tier:\*\* *\([1-4]\).*/\1/p'
}

round_tier() { # round_tier <spec> <round-dir> -> the round's frozen tier= (open-round writes
  # it at open time, C15); tier_of() as a fallback for a round opened before this story.
  local spec="$1" rd="$2" t
  t="$(round_field "$rd" tier)"
  case "$t" in [1-4]) printf '%s' "$t"; return ;; esac
  tier_of "$spec"
}

required_seats_for_tier() { # required_seats_for_tier <tier> -> the space-separated seats a
  # round of this tier must have before judge will run (C15). 3 and 4 (and any value outside
  # 1-4, which tier_of never produces) share the full court - Tier 4's extra reviewer is a
  # second `lead-review` dispatch, not a fifth seat here.
  case "$1" in
    1) printf 'sonnet' ;;
    2) printf 'sonnet opus review' ;;
    *) printf 'haiku sonnet opus review' ;;
  esac
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
    local ready="" any_todo=0 any_prog="" prog_files=""
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
  RD="$(current_round_dir "$SPEC")"
  # N-m3: a round directory without its own ROUND file (a crash before open-round's last write)
  # is not an open round - it reads exactly like no round at all, so `next` falls through to
  # the final "open-round" case below instead of a stale/dispatch/judge state built on empty
  # round_field() reads.
  if [ -n "$RD" ] && [ -f "$RD/ROUND" ]; then
    ROUND_N="${RD##*/round-}"
    local RCOURT
    RCOURT="$(round_field "$RD" court)"
    CEILING="$(round_field "$RD" ceiling)"; [ -n "$CEILING" ] || CEILING=3
    [ -n "$RCOURT" ] && COURT_JSON="\"$RCOURT\""
    if ! row_exists "$SLUG" "$ROUND_N"; then
      OPEN_B=true
      local seat REQUIRED
      REQUIRED="$(required_seats_for_tier "$(round_tier "$SPEC" "$RD")")"
      MISSING="$(missing_required_seats "$RD" "$REQUIRED")"
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
  else
    NEXT="open-round"
  fi

  printf '{"spec":"%s","slug":"%s","stage":"%s","next":"%s","briefed":%s,"approved":%s,"branch":%s,"head":"%s","pack":"%s","stories":{"todo":%s,"in-progress":%s,"done":%s,"blocked":%s},"wave":%s,"wave_stories":[%s],"round":%s,"ceiling":%s,"tier":%s,"open":%s,"court":%s,"missing":[%s],"stale":%s,"verdict":%s,"review":%s,"red":[%s],"round_dir":%s,"paused":%s,"shipped":%s}\n' \
    "$SPEC" "$SLUG" "$(compute_stage "$SPEC" "$PLAN")" "$NEXT" "$BRIEFED_B" "$APPROVED_B" "$BRANCH_JSON" "$HEAD" "$PACK" \
    "$TODO" "$PROG" "$DONE" "$BLOCKED" \
    "$WAVE_JSON" "$WAVE_STORIES_JSON" \
    "$ROUND_N" "$CEILING" "$TIER_JSON" "$OPEN_B" "$COURT_JSON" "$(json_str_array "$MISSING")" "$STALE_B" \
    "$VERDICT_JSON" "$REVIEW_JSON" "$(json_num_csv "$RED_LIST")" "$ROUND_DIR_JSON" "$PAUSED_B" "$SHIPPED_B"
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

seat_ask_lines() { # seat_ask_lines <file> -> "n verdict evidenced(1/0)" per ASK line - evidenced
  # comes from ask_evidenced_of (below), the same classification record-seat uses (R8), so a
  # header's unevidenced: list and judge's red/red_unevidenced never disagree on one report.
  grep -E '^ASK [0-9]+:' "$1" 2>/dev/null | while IFS= read -r line; do
    local n v ev
    n="$(printf '%s' "$line" | sed -n 's/^ASK \([0-9][0-9]*\):.*/\1/p')"
    v="$(printf '%s' "$line" | sed -n 's/^ASK [0-9][0-9]*:[[:space:]]*\(GREEN\|RED\|N\/A\).*/\1/p')"
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
  local verb="$1" msg="$2"; shift 2
  [ -n "$(git status --porcelain -- "$@" 2>/dev/null)" ] || return 0
  git add -A -- "$@" >/dev/null 2>&1
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
  local haiku_v="" sonnet_v="" opus_v="" review_v=""
  local haiku_model=unknown sonnet_model=unknown opus_model=unknown attempts=0
  # r2m5/r2m6: the ceiling gate closes over a round whose seats already carry RED asks (a RED
  # verdict at N-1, or a STALE-folded round whose seat files were filed before code moved) - the
  # ESCALATE row and the ## Needs a human block must show those same asks, not empty arrays,
  # same evidenced/unevidenced split cmd_judge uses (seat_ask_lines, ask_evidenced_of).
  local red_e="" red_u=""
  required="$(required_seats_for_tier "$(round_tier "$spec" "$rd")")"
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
    # LR19: attempts counts every stored file for the seat this round - a re-ask counts 2.
    [ -f "$f" ] && attempts=$((attempts+1))
    [ -f "$rd/$seat.attempt-1.md" ] && attempts=$((attempts+1))
    [ -f "$rd/$seat.attempt-2.md" ] && attempts=$((attempts+1))
  done
  # evidenced wins over unevidenced for the same ask number (same rule as cmd_judge)
  local cleaned="" u
  for u in $red_u; do case " $red_e " in *" $u "*) ;; *) cleaned="$cleaned $u" ;; esac; done
  red_u="$cleaned"
  red_e="$(sort_num_list "$red_e")"
  red_u="$(sort_num_list "$red_u")"
  if [ -f "$rd/review.md" ]; then
    review_v="$(review_verdict_of "$rd/review.md")"; [ -n "$review_v" ] || review_v="ABSENT"
  elif is_required_seat review "$required"; then
    review_v="ABSENT"
  fi
  [ -f "$rd/review.md" ] && attempts=$((attempts+1))
  [ -f "$rd/review.attempt-1.md" ] && attempts=$((attempts+1))
  [ -f "$rd/review.attempt-2.md" ] && attempts=$((attempts+1))

  if ! escalate_row_exists "$slug" "$n"; then
    mkdir -p memory/stats
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"ESCALATE","head":"%s","pack":"%s","asks":%s,"red":[%s],"red_unevidenced":[%s],"na":0,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":"%s","note":"%s"}\n' \
      "$(now_ts)" "$slug" "$n" "$rhead" "$rpack" "$a" \
      "$(json_num_csv "$red_e")" "$(json_num_csv "$red_u")" \
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
  local REQUIRED; REQUIRED="$(required_seats_for_tier "$(round_tier "$SPEC" "$RD")")"

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

  local rf="$RD/review.md"
  if [ -f "$rf" ]; then
    review_v="$(review_verdict_of "$rf")"; [ -n "$review_v" ] || review_v="BLOCK"
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
    if [ "$N" -ge "$RCEILING" ]; then
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
      # LR19: attempts counts every stored file for the seat this round - a re-ask counts 2.
      [ -f "$RD/$seat.md" ] && attempts=$((attempts+1))
      [ -f "$RD/$seat.attempt-1.md" ] && attempts=$((attempts+1))
      [ -f "$RD/$seat.attempt-2.md" ] && attempts=$((attempts+1))
    done
    local noteval=""
    [ "$escalate_reason" = "env" ] && noteval="$(redact_note "$(printf '%s' "$absent_seats" | sed 's/ /, /g') ABSENT")"
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"%s","head":"%s","pack":"%s","asks":%s,"red":[%s],"red_unevidenced":[%s],"na":%s,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":%s,"note":"%s"}\n' \
      "$(now_ts)" "$SLUG" "$N" "$overall" "$head7" "$RPACK" "$A" \
      "$(json_num_csv "$red_e")" "$(json_num_csv "$red_u")" "$na_count" \
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
  emit true "$VERBLABEL" "$exit_code" "$next_val"
  exit "$exit_code"
}

cmd_escalate() { # cmd_escalate <spec-dir> [--commit] [--reason <ceiling|half|env>] ["<note>"]
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
  case "$REASON" in ''|ceiling|half|env) ;; *)
    echo "cycle: usage: $0 escalate <spec-dir> [--commit] [--reason <ceiling|half|env>] [\"<note>\"]" >&2
    emit false escalate 1 error "usage"
    exit 1
    ;;
  esac
  [ -n "$REASON" ] || REASON="env"

  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 escalate <spec-dir> [--commit] [--reason <ceiling|half|env>] [\"<note>\"]" >&2
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
  required="$(required_seats_for_tier "$(round_tier "$SPEC" "$RD")")"
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
  # Path-anchored (R9): a hit needs the slug immediately before /plan.md, /journal.md or
  # /council/ - optionally under docs/specs/ - or a word-bounded <slug>-NN (two digits) story
  # id. The bare words plan.md/journal.md/council/, a command file like vulyk-plan.md, and
  # another spec's paths are never taint; literal, case-sensitive, no prose heuristics.
  local report="$1" slug="$2" esc
  esc="$(printf '%s' "$slug" | sed 's/[.[\*^$()+?{|]/\\&/g')"
  printf '%s' "$report" | grep -qE "\b${esc}-[0-9]{2}\b"                && { printf 'names a story id %s-NN' "$slug"; return; }
  printf '%s' "$report" | grep -qE "(docs/specs/)?\b${esc}/plan\.md"    && { printf 'names %s/plan.md' "$slug"; return; }
  printf '%s' "$report" | grep -qE "(docs/specs/)?\b${esc}/journal\.md" && { printf 'names %s/journal.md' "$slug"; return; }
  printf '%s' "$report" | grep -qE "(docs/specs/)?\b${esc}/council/"    && { printf 'names %s/council/' "$slug"; return; }
  return 0
}

ask_line_of() { printf '%s\n' "$1" | grep -m1 -E "^ASK $2:"; } # ask_line_of <report> <n>
ask_verdict_of() { printf '%s' "$1" | sed -n 's/^ASK [0-9][0-9]*:[[:space:]]*\(GREEN\|RED\|N\/A\).*/\1/p'; } # <ask-line>
ask_rest_of() { printf '%s' "$1" | sed -E 's/^ASK [0-9]+: (GREEN|RED|N\/A)( - )?//'; } # <ask-line> -> everything
  # after the verdict token, interior " - " kept intact (R8 - no truncation at the last dash)
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

  local extra; extra="$(printf ' \xc2\xb7 verdict: %s' "$verdict")"
  write_seat_file "$RD/review.md" review "$model" "$N" "$HEAD" "$RPACK" "$ATTEMPT" "$extra" "$REPORT"
  echo "cycle: record-seat - review recorded for round $N (verdict $verdict)"
  local missing required
  required="$(required_seats_for_tier "$(round_tier "$SPEC" "$RD")")"
  missing="$(missing_required_seats "$RD" "$required")"
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

  local missing required
  required="$(required_seats_for_tier "$(round_tier "$SPEC" "$RD")")"
  missing="$(missing_required_seats "$RD" "$required")"
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

  local REPORT; REPORT="$(cat)"

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

command_cell_exists() { # command_cell_exists <claude-md> <command> -> 0 iff <command> equals,
  # byte for byte, the backticked command cell of some row of the hive's `## Commands` table
  # (a `\|` inside the cell is a literal `|`, R11/C-4). Reads only that one table's rows -
  # nothing else in CLAUDE.md (Non-goals) - by slicing to the section first.
  local file="$1" want="$2"
  [ -f "$file" ] || return 1
  awk '
    /^## Commands[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/            { if (inblock) exit }
    inblock                     { print }
  ' "$file" \
    | sed -n 's/^|[^|]*|[[:space:]]*`\(.*\)`[[:space:]]*|[[:space:]]*$/\1/p' \
    | sed 's/\\|/|/g' \
    | grep -qxF "$want"
}

verification_segments() { # verification_segments <line> -> one &&-separated segment per line
  # (R11/C-4): every segment of every ## Verification line must be its own ## Commands cell.
  local rest="$1" seg
  while :; do
    case "$rest" in
      *' && '*) seg="${rest%%' && '*}"; printf '%s\n' "$seg"; rest="${rest#*' && '}" ;;
      *) printf '%s\n' "$rest"; break ;;
    esac
  done
}

repeat_of() { # repeat_of <story-file> - the integer `repeat: N` under ## Verification, or 1
  local n
  n="$(verify_of "$1" | awk -F': *' '$1 ~ /^repeat$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
  case "$n" in ''|*[!0-9]*|0) n=1 ;; esac
  printf '%s' "$n"
}

wave_story_json() { # wave_story_json <story-file> - one C3 wave_stories object, keys in order
  # file/story/worker/repeat; `worker` defaults to worker-code when the frontmatter line is
  # absent, never null (Non-goals) - it is never computed from anything but that one line.
  local f="$1" id worker
  id="$(fm_field "$f" story)"
  worker="$(fm_field "$f" worker)"; [ -n "$worker" ] || worker="worker-code"
  printf '{"file":"%s","story":"%s","worker":"%s","repeat":%s}' "$f" "$id" "$worker" "$(repeat_of "$f")"
}

cmd_close_story() { # cmd_close_story <story-file> <commit:0|1>
  local STORY="$1" DOCOMMIT="$2"
  [ -n "$STORY" ] && [ -f "$STORY" ] || {
    echo "cycle: usage: $0 close-story <story-file> [--commit]" >&2
    emit false close-story 1 error "usage"
    exit 1
  }
  local SPECDIR; SPECDIR="$(dirname "$STORY")"
  pause_guard "$SPECDIR" close-story

  local ST; ST="$(fm_field "$STORY" status)"
  case "$ST" in
    todo|in-progress) ;;
    done)
      echo "cycle: close-story - $STORY is already done" >&2
      emit false close-story 2 error "already done"
      exit 2
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
  # hive's CLAUDE.md `## Commands` table, or the line is the literal "none - reviewed by
  # lead-review" (which runs nothing, below) - a story author never gets unprompted execution.
  local vline seg
  while IFS= read -r vline; do
    [ -n "$vline" ] || continue
    [ "$vline" = "none — reviewed by lead-review" ] && continue
    # r2m9: a line matching a `## Commands` cell whole (its own `&&` and all) is one unit -
    # only a line that is NOT itself a cell gets split and checked segment by segment.
    command_cell_exists "$ROOT/CLAUDE.md" "$vline" && continue
    while IFS= read -r seg; do
      [ -n "$seg" ] || continue
      command_cell_exists "$ROOT/CLAUDE.md" "$seg" || {
        echo "cycle: close-story - verification command not in $ROOT/CLAUDE.md's ## Commands: $seg" >&2
        emit false close-story 2 error "verification not in ## Commands: $seg"
        exit 2
      }
    done <<SEGEOF
$(verification_segments "$vline")
SEGEOF
  done <<EOF
$CMD_LIST
EOF

  # --- run: one command at a time, the whole block repeated REPS times (R18/M-3) - a single
  # `bash -c "$multi_line_block"` used to report only the last line's exit status. -----------
  local i=1
  while [ "$i" -le "$REPS" ]; do
    while IFS= read -r vline; do
      [ -n "$vline" ] || continue
      [ "$vline" = "none — reviewed by lead-review" ] && continue
      if ! bash -c "$vline"; then
        echo "cycle: close-story - verification failed (run $i/$REPS): $vline" >&2
        emit false close-story 4 repair "$vline"
        exit 4
      fi
    done <<EOF
$CMD_LIST
EOF
    i=$((i+1))
  done

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
  local status_out real_next
  status_out="$(cmd_status "$SPECDIR")"
  real_next="$(json_field "$status_out" next)"
  emit true close-story 0 "$real_next"
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

build_round() { # build_round <spec> <slug> <n> <head> <pack> <ceiling> <commit:0|1> - the
  # "on success" effect shared by a fresh round and an in-place re-stamp (same code, same N).
  # Always terminates the process (exit 0 or, on a worktree failure, exit 2).
  local spec="$1" slug="$2" n="$3" head="$4" pack="$5" ceiling="$6" docommit="$7"
  local rd="$spec/council/round-$n"
  mkdir -p "$rd"
  clean_court "$slug"
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

  # C15: the tier is derived once, here, and frozen into the round - a plan.md edit mid-round
  # (or a stale re-stamp) never changes what this round already requires.
  local tier required
  tier="$(tier_of "$spec")"
  required="$(required_seats_for_tier "$tier")"

  {
    printf 'head=%s\n' "$head"
    printf 'pack=%s\n' "$pack"
    printf 'opened=%s\n' "$(now_ts)"
    printf 'court=%s\n' "$court_abs"
    printf 'ceiling=%s\n' "$ceiling"
    printf 'tier=%s\n' "$tier"
  } > "$rd/ROUND"

  local dispatch_val; dispatch_val="dispatch:$(printf '%s' "$required" | tr ' ' ',')"
  bash "$HERE/journal.sh" "$spec" "04-council:open" "round $n opened, court at $court_abs" "$dispatch_val" >/dev/null

  [ "$docommit" = "1" ] && commit_paperwork open-round "vulyk($slug): open-round $n" "$spec"

  echo "cycle: $slug - round $n opened, court at $court_abs"
  emit true open-round 0 "$dispatch_val"
  exit 0
}

write_stale_row() { # write_stale_row <spec> <slug> <round-dir> <n> <a> - a STALE round record
  # (D1 crash rule: a manual code commit against an open round with a seat file "was a
  # dispatch, it counts against the ceiling"). Idempotent like judge's own row/line/journal.
  local spec="$1" slug="$2" rd="$3" n="$4" a="$5"
  local rhead rpack; rhead="$(round_field "$rd" head)"; rpack="$(round_field "$rd" pack)"
  local plan="$spec/plan.md" dateonly; dateonly="$(date -u +%Y-%m-%d)"
  if ! row_exists "$slug" "$n"; then
    mkdir -p memory/stats
    # A seat this round's tier does not require defaults to "" like judge's own row, never
    # ABSENT (R21/minor 20, autonomous-cycle-19): ABSENT means "required and never recorded".
    local required; required="$(required_seats_for_tier "$(round_tier "$spec" "$rd")")"
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
      # LR19: attempts counts every stored file for the seat this round - a re-ask counts 2.
      [ -f "$f" ] && attempts=$((attempts+1))
      [ -f "$rd/$seat.attempt-1.md" ] && attempts=$((attempts+1))
      [ -f "$rd/$seat.attempt-2.md" ] && attempts=$((attempts+1))
    done
    if [ -f "$rd/review.md" ]; then
      review_v="$(review_verdict_of "$rd/review.md")"; [ -n "$review_v" ] || review_v="ABSENT"
    fi
    [ -f "$rd/review.md" ] && attempts=$((attempts+1))
    [ -f "$rd/review.attempt-1.md" ] && attempts=$((attempts+1))
    [ -f "$rd/review.attempt-2.md" ] && attempts=$((attempts+1))
    printf '{"ts":"%s","spec":"%s","round":%s,"verdict":"STALE","head":"%s","pack":"%s","asks":%s,"red":[],"red_unevidenced":[],"na":0,"review":"%s","haiku":"%s","haiku_model":"%s","sonnet":"%s","sonnet_model":"%s","opus":"%s","opus_model":"%s","attempts":%s,"escalate":null,"note":"code moved after dispatch"}\n' \
      "$(now_ts)" "$slug" "$n" "${rhead:-unknown}" "$rpack" "$a" "$review_v" \
      "$haiku_v" "$haiku_model" "$sonnet_v" "$sonnet_model" "$opus_v" "$opus_model" "$attempts" >> memory/stats/council.jsonl
  fi
  if [ -f "$plan" ] && ! council_line_exists "$plan" "$n"; then
    council_append_line "$plan" "$(printf '**Council:** STALE round %s, %s, at %s, pack %s' "$n" "$dateonly" "${rhead:-unknown}" "$rpack")"
  fi
  journal_line_exists "$spec" "$n" "STALE" || bash "$HERE/journal.sh" "$spec" "04-council:STALE" "round $n stale, code moved after dispatch" "open-round" >/dev/null
}

cmd_open_round() { # cmd_open_round <spec> <commit:0|1>
  local SPEC="$1" DOCOMMIT="$2"
  [ -n "$SPEC" ] && [ -d "$SPEC" ] || {
    echo "cycle: usage: $0 open-round <spec-dir> [--commit]" >&2
    emit false open-round 1 error "usage"
    exit 1
  }
  pause_guard "$SPEC" open-round

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
    grep -q '^story:' "$f" 2>/dev/null || continue
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
  # Anything else dirty is real and still refuses.
  local status_out dirty="" line
  status_out="$(git status --porcelain 2>/dev/null)"
  if [ -n "$status_out" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      is_paperwork_path "${line:3}" || dirty="${dirty}${line}
"
    done <<EOF
$status_out
EOF
  fi
  [ -z "$dirty" ] || {
    echo "cycle: open-round - working tree has changes outside the cycle's own paperwork:" >&2
    printf '%s' "$dirty" | sed 's/^/  /' >&2
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
  local CEILING; CEILING="$(head -1 "$SPEC/council/CEILING" 2>/dev/null | tr -d '[:space:]')"; [ -n "$CEILING" ] || CEILING=3

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
      local missing required
      required="$(required_seats_for_tier "$(round_tier "$SPEC" "$RD")")"
      missing="$(missing_required_seats "$RD" "$required")"
      local next_val="judge"; [ -n "$missing" ] && next_val="dispatch:$(printf '%s' "$missing" | tr ' ' ',')"
      # r2m3: an earlier --commit here may have failed after ROUND/journal.md were already
      # written (e.g. an index.lock) - a true no-op has nothing left to commit; anything still
      # uncommitted under this spec's own paperwork is finished now, not silently left behind.
      [ "$DOCOMMIT" = "1" ] && commit_paperwork open-round "vulyk($SLUG): open-round $N" "$SPEC"
      echo "cycle: $SLUG - round $N already open at current HEAD, no-op"
      emit true open-round 0 "$next_val"
      exit 0
    fi
    local has_seat=0 seat2
    for seat2 in haiku sonnet opus review; do [ -f "$RD/$seat2.md" ] && has_seat=1; done
    if [ "$has_seat" -eq 0 ]; then
      build_round "$SPEC" "$SLUG" "$N" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
    fi
    write_stale_row "$SPEC" "$SLUG" "$RD" "$N" "$A"
    local NEXTN=$((N+1))
    [ "$NEXTN" -le "$CEILING" ] || {
      # R5/C-3(a): the ceiling reached here must leave a record - an ESCALATE row, the plan
      # line, ## Needs a human and the journal line - not just exit 6 into a silent loop.
      echo "cycle: open-round - $SLUG round $NEXTN would exceed ceiling $CEILING" >&2
      write_ceiling_escalate "$SPEC" "$SLUG" "$N" "$RD"
      [ "$DOCOMMIT" = "1" ] && commit_paperwork open-round "vulyk($SLUG): escalate ceiling round $N" "$SPEC" memory/stats/council.jsonl
      emit true open-round 6 escalated
      exit 6
    }
    build_round "$SPEC" "$SLUG" "$NEXTN" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
  fi

  # --- no open round: a fresh round, gated by the ceiling -----------------------------------
  local ROUND_COUNT=0; [ -n "$RD" ] && ROUND_COUNT="${RD##*/round-}"
  [ "$ROUND_COUNT" -lt "$CEILING" ] || {
    echo "cycle: open-round - $SLUG is at the ceiling ($CEILING rounds)" >&2
    [ "$ROUND_COUNT" -gt 0 ] && {
      write_ceiling_escalate "$SPEC" "$SLUG" "$ROUND_COUNT" "$SPEC/council/round-$ROUND_COUNT"
      [ "$DOCOMMIT" = "1" ] && commit_paperwork open-round "vulyk($SLUG): escalate ceiling round $ROUND_COUNT" "$SPEC" memory/stats/council.jsonl
    }
    emit true open-round 6 escalated
    exit 6
  }
  build_round "$SPEC" "$SLUG" "$((ROUND_COUNT+1))" "$HEAD" "$PACK" "$CEILING" "$DOCOMMIT"
}

# --- reopen: three more rounds after ESCALATE (D6) --------------------------------------------

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

  local OLDCEIL; OLDCEIL="$(head -1 "$SPEC/council/CEILING" 2>/dev/null | tr -d '[:space:]')"; [ -n "$OLDCEIL" ] || OLDCEIL=3
  local NEWCEIL="$OLDCEIL"

  if [ "$already" -eq 0 ]; then
    append_after_answers "$BRIEF" "$(printf '\n%s\n> %s\n' "$marker_text" "$DECISION")"
    NEWCEIL=$((OLDCEIL+3))
    mkdir -p "$SPEC/council"
    printf '%s\n' "$NEWCEIL" > "$SPEC/council/CEILING"
    bash "$HERE/journal.sh" "$SPEC" "04-council:ESCALATE" "reopened after round $N, ceiling now $NEWCEIL" "open-round" >/dev/null
  fi

  # R7/M-4/C4: council/REOPEN names every round `reopen` has cleared, so `status` can tell an
  # ESCALATE row a human already reopened from one still waiting - one line per round, never
  # rewritten (mkdir -p: a spec can be reopened before any round dir of its own exists).
  mkdir -p "$SPEC/council"
  reopen_names_round "$SPEC" "$N" || printf 'round=%s \xc2\xb7 %s\n' "$N" "$(now_ts)" >> "$SPEC/council/REOPEN"

  [ "$DOCOMMIT" = "1" ] && commit_paperwork reopen "vulyk($SLUG): reopen after round $N" "$SPEC"

  echo "cycle: $SLUG - reopened after round $N, ceiling now $NEWCEIL"
  emit true reopen 0 open-round
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
  close-story)
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_close_story "$SPEC" "$COMMIT"
    ;;
  open-round)
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_open_round "$SPEC" "$COMMIT"
    ;;
  reopen)
    DECISION="${3:-}"
    COMMIT=0
    for a in "$@"; do [ "$a" = "--commit" ] && COMMIT=1; done
    cmd_reopen "$SPEC" "$DECISION" "$COMMIT"
    ;;
  *)
    usage
    ;;
esac
