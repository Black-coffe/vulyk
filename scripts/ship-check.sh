#!/usr/bin/env bash
# VULYK ship gate - which stage of the cycle is a spec at, and may it be published?
#
#   Usage: scripts/ship-check.sh <spec-dir>                       # READY or NOT READY, and why
#          scripts/ship-check.sh --record <spec-dir> <version> [where it was published]
#
# Six stages, six confirmation artifacts (docs/cycle.md). This script reads every one of
# them - brief, approval line, branch line, story statuses, the blind gate's verdict, the
# owner's check - and says which is missing or stale. Deterministic, no model, no tokens.
# `/vulyk-ship` runs it first and refuses on NOT READY, the way `/vulyk-build` refuses
# without an approval line. It is the reason "did anyone actually look?" is a question
# with a file behind it rather than a memory.
#
# `--record` writes stage 06's own artifact once the human has pressed the button: a
# `**Shipped:**` line in plan.md and a row in memory/stats/ship.jsonl. The publishing
# itself is never done here and never by an agent.
#
# Exit status is always 0: this reports, it does not block. The refusing is the command's.
set -u

# pack_fingerprint(), paperwork_only() and marker() now live in scripts/lib.sh, shared with
# human-check.sh, acceptance-log.sh, release-check.sh and cycle.sh (ADR-001 C1) - one
# implementation instead of several that had to agree by hand.
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$HERE/lib.sh"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ship-check: CANNOT RUN - not a git repo, so there is no history to fix and no stats to read." >&2
  exit 0
}

# --- `--record`: stage 06's artifact -------------------------------------------------------
if [ "${1:-}" = "--record" ]; then
  RSPEC="${2:-}"; RVER="${3:-}"; RNOTE="${4:-}"
  [ -n "$RSPEC" ] && [ -d "$RSPEC" ] && [ -n "$RVER" ] || {
    echo "ship-check: usage: $0 --record <spec-dir> <version> [note]" >&2; exit 0; }
  RPLAN="$RSPEC/plan.md"
  [ -f "$RPLAN" ] || { echo "ship-check: CANNOT RUN - $RPLAN does not exist." >&2; exit 0; }
  if [ -f "$ROOT/scripts/redact.sh" ]; then
    RNOTE="$(printf '%s' "$RNOTE" | bash "$ROOT/scripts/redact.sh")"
  fi
  RNOTE="$(printf '%s' "$RNOTE" | tr -d '\n' | tr -d '\r')"
  RHEAD="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  RDATE="$(date -u +%Y-%m-%d)"
  LINE="**Shipped:** $RVER, $RDATE, at $RHEAD"
  [ -n "$RNOTE" ] && LINE="$LINE - $RNOTE"
  if grep -q '^\*\*Shipped:\*\* <' "$RPLAN" 2>/dev/null; then
    TMP="$RPLAN.tmp$$"; grep -v '^\*\*Shipped:\*\* <' "$RPLAN" > "$TMP" && mv "$TMP" "$RPLAN"
  fi
  printf '%s\n' "$LINE" >> "$RPLAN"
  mkdir -p "$ROOT/memory/stats"
  ESC="$(printf '%s' "$RNOTE" | tr -d '\\' | tr '"' "'")"
  VESC="$(printf '%s' "$RVER" | tr -d '\\' | tr '"' "'")"
  printf '{"ts":"%s","spec":"%s","version":"%s","head":"%s","pack":"%s","note":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$RSPEC")" "$VESC" "$RHEAD" "$(pack_fingerprint "$RSPEC")" "$ESC" \
    >> "$ROOT/memory/stats/ship.jsonl"
  echo "ship-check: $(basename "$RSPEC") - shipped as $RVER at $RHEAD; recorded in $RPLAN and memory/stats/ship.jsonl."
  echo "  The circle is closed. Its leftovers (UNASKED, ## Descoped, unfixed CONCERNS) are the draft of the next brief."
  exit 0
fi

SPEC="${1:-}"
[ -n "$SPEC" ] && [ -d "$SPEC" ] || {
  echo "ship-check: usage: $0 <spec-dir>   |   $0 --record <spec-dir> <version> [note]" >&2
  exit 0
}
cd "$ROOT" || exit 0
SLUG="$(basename "$SPEC")"
PLAN="$SPEC/plan.md"
MISSING=0
say()  { printf '  %-4s %-8s %s\n' "$1" "$2" "$3"; }
fail() { say "$1" "OPEN" "$2"; MISSING=$((MISSING + 1)); }
ok()   { say "$1" "ok" "$2"; }

echo "ship-check: $SLUG - the six confirmations"
echo ""

# 01 Spec
if [ -f "$SPEC/brief.md" ]; then ok 01 "spec: brief.md exists"
else fail 01 "spec: no brief.md - there is no verbatim request for anything below to answer to"; fi

# 02 Plan - **Approved:** (the default) or **Briefed:** (--go / Tier 1) close this
# stage; ship-check.sh accepts either (ADR-001 D1).
if [ ! -f "$PLAN" ]; then
  fail 02 "plan: no plan.md"
elif [ -n "$(marker "$PLAN" Briefed)" ]; then
  ok 02 "plan: briefed - $(marker "$PLAN" Briefed)"
elif [ -n "$(marker "$PLAN" Approved)" ]; then
  ok 02 "plan: approved - $(marker "$PLAN" Approved)"
else
  fail 02 "plan: no **Briefed:** or **Approved:** line in plan.md - /vulyk-build would have refused this pack"
fi

# 03 Code - the branch line, the branch itself, and whether the tree is settled
BRANCH_NOW="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
DEFAULT="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
[ -n "$DEFAULT" ] || { git show-ref --verify --quiet refs/heads/main && DEFAULT=main; }
[ -n "$DEFAULT" ] || { git show-ref --verify --quiet refs/heads/master && DEFAULT=master; }
[ -n "$DEFAULT" ] || DEFAULT="main"
BRANCH_REC=""
[ -f "$PLAN" ] && BRANCH_REC="$(marker "$PLAN" Branch)"
if [ -z "$BRANCH_REC" ]; then
  fail 03 "code: no **Branch:** line in plan.md - the build did not record where its commits live"
else
  ok 03 "code: branch recorded - $BRANCH_REC (now on $BRANCH_NOW)"
fi
if [ "$BRANCH_NOW" = "$DEFAULT" ]; then
  say "" "note" "you are on $DEFAULT: ship-check reads the spec branch; run it there, before the merge"
elif [ -n "$BRANCH_REC" ] && [ "$BRANCH_NOW" != "$BRANCH_REC" ]; then
  fail 03 "code: on $BRANCH_NOW, but the spec's commits live on $BRANCH_REC - switch to it before shipping"
fi
# ship-safety: prove the spec branch merges into the default branch before /vulyk-ship merges it.
# merge-tree (git 2.38+) writes no ref and touches no checkout. Exit 0 is clean, 1 is a conflict;
# anything else (an old git, a missing ref) is "cannot check", never clean. A missing ref also
# exits 1, so both refs are verified first, and a "conflict" naming no file is "cannot check" too.
if [ -n "$BRANCH_REC" ]; then
  MT_RC=0; MT_OUT=""
  for mt_ref in "$DEFAULT" "$BRANCH_REC"; do
    git rev-parse --verify -q "$mt_ref^{commit}" >/dev/null 2>&1 || { MT_RC=128; MT_OUT="no branch $mt_ref"; }
  done
  [ "$MT_RC" -eq 0 ] && { MT_OUT="$(git merge-tree --write-tree --name-only --no-messages "$DEFAULT" "$BRANCH_REC" 2>&1)"; MT_RC=$?; }
  MT_FILES=""
  [ "$MT_RC" -eq 1 ] && MT_FILES="$(printf '%s\n' "$MT_OUT" | sed -n '2,$p' | grep -v '^$' | tr '\n' ' ' | sed 's/ $//')"
  [ "$MT_RC" -eq 1 ] && [ -z "$MT_FILES" ] && MT_RC=129
  case "$MT_RC" in
    0) ok 03 "code: $BRANCH_REC merges into $DEFAULT cleanly (git merge-tree)" ;;
    1) fail 03 "code: $BRANCH_REC conflicts with $DEFAULT in: $MT_FILES - repair: merge $DEFAULT into $BRANCH_REC, then open a new council round" ;;
    *) fail 03 "code: cannot check the merge of $BRANCH_REC into $DEFAULT (git merge-tree exit $MT_RC: $(printf '%s' "$MT_OUT" | head -1)) - needs git 2.38+ and both branches" ;;
  esac
fi
DIRTY="$(git status --porcelain 2>/dev/null)"
if [ -n "$DIRTY" ]; then
  # Story 09: a tree dirty only in the hook-written memory/stats/anomalies.jsonl (the
  # anomaly-scan Stop hook writes it on every run, outside any commit) is not a build in
  # progress - pass it through, named, rather than blocking stage 03 on a file no story owns.
  # skills.json joins it (spec skills-json-exempt, 2026-09-29, reversing Story 12's "real dirt"
  # line under the owner's delegation): the PostToolUse(Skill) hook rewrites it on every Skill
  # call, and since 0.21.0 maintenance itself runs through the Skill tool. A path the hive's own
  # .claude/vulyk-paperwork names (hive_paperwork_path, ADR-010 amendment 2026-10-16) passes too,
  # read with -z so a non-ASCII name is itself. Nothing else is exempt.
  ALLHOOK=1
  HOOKPATHS=""
  while IFS= read -r -d '' dline; do
    dp="${dline:3}"
    case "${dline:0:2}" in *R*|*C*) IFS= read -r -d '' _ ; ALLHOOK=0; continue ;; esac
    if [ "$dp" = memory/stats/anomalies.jsonl ] || [ "$dp" = memory/stats/skills.json ] \
      || hive_paperwork_path "$dp" "$ROOT"; then
      HOOKPATHS="$HOOKPATHS${HOOKPATHS:+, }$dp"
      continue
    fi
    ALLHOOK=0
  done < <(git status --porcelain -uall -z 2>/dev/null)
  if [ "$ALLHOOK" = "1" ]; then
    ok 03 "code: clean (hook-written stats pending: $HOOKPATHS)"
  else
    fail 03 "code: working tree is not clean - uncommitted changes are not part of any story's commit"
  fi
fi

# Stories - every one closed, one way or the other
TOTAL=0; DONE=0; BLOCKED=0; OPEN=0; UNREC=0
for f in "$SPEC"/*.md; do
  [ -f "$f" ] || continue
  grep -q '^story:' "$f" 2>/dev/null || continue
  TOTAL=$((TOTAL+1))
  st="$(awk -F': *' '$1 == "status" { sub(/[[:space:]]*#.*$/, "", $2); gsub(/[[:space:]]/, "", $2); print $2; exit }' "$f")"
  case "$st" in
    done) DONE=$((DONE+1)) ;;
    blocked) BLOCKED=$((BLOCKED+1)) ;;
    todo|in-progress) OPEN=$((OPEN+1)) ;;
    *) UNREC=$((UNREC+1)) ;;
  esac
done
if [ "$TOTAL" -eq 0 ]; then
  fail 03 "code: no story files - nothing was built under this spec"
elif [ "$OPEN" -gt 0 ] || [ "$UNREC" -gt 0 ]; then
  fail 03 "code: stories $DONE/$TOTAL done, $BLOCKED blocked, $OPEN still open, $UNREC unrecognised - the build is not closed"
elif [ "$BLOCKED" -gt 0 ]; then
  if [ -f "$PLAN" ] && awk '/^## Descoped/{f=1;next} /^## /{f=0} f && /^- /{c++} END{exit !(c>0)}' "$PLAN"; then
    ok 03 "code: stories $DONE/$TOTAL done, $BLOCKED blocked with ## Descoped entries on the record"
  else
    fail 03 "code: $BLOCKED blocked and ## Descoped is empty - a story that shrank with no line is a requirement that vanished"
  fi
else
  ok 03 "code: stories $DONE/$TOTAL done"
fi

# 04+05 Tests + Human - the council's verdict now closes both stages at once (ADR-001 D4):
# a GREEN council row for the current pack, at HEAD or only paperwork since, is enough on
# its own. **Checked:** stays the owner's override in both directions - whichever of the
# two records is newer wins, and the report always names both. With no council row for this
# spec, both stages fall back to their pre-council behaviour below - the blind gate's
# acceptance.jsonl verdict, then the owner's human.jsonl check - unchanged.
NOW_P="$(pack_fingerprint "$SPEC")"
HEAD_NOW="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
HUM="memory/stats/human.jsonl"
HLAST=""
[ -f "$HUM" ] && HLAST="$(grep -F "\"spec\":\"$SLUG\"" "$HUM" | tail -1)"

COUNCIL="memory/stats/council.jsonl"
CLAST=""
[ -f "$COUNCIL" ] && CLAST="$(grep -F "\"spec\":\"$SLUG\"" "$COUNCIL" | tail -1)"

if [ -n "$CLAST" ]; then
  CV="$(printf '%s' "$CLAST" | sed -n 's/.*"verdict":"\([^"]*\)".*/\1/p')"
  CP="$(printf '%s' "$CLAST" | sed -n 's/.*"pack":"\([^"]*\)".*/\1/p')"
  CH="$(printf '%s' "$CLAST" | sed -n 's/.*"head":"\([^"]*\)".*/\1/p')"
  CROUND="$(printf '%s' "$CLAST" | sed -n 's/.*"round":\([0-9]*\).*/\1/p')"
  CTS="$(printf '%s' "$CLAST" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')"

  HV=""; HTS=""; HB=""
  if [ -n "$HLAST" ]; then
    HV="$(printf '%s' "$HLAST" | sed -n 's/.*"verdict":"\([^"]*\)".*/\1/p')"
    HTS="$(printf '%s' "$HLAST" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')"
    HB="$(printf '%s' "$HLAST" | sed -n 's/.*"by":"\([^"]*\)".*/\1/p')"
  fi

  COUNCIL_OK=0
  COUNCIL_REASON=""
  case "$CV" in
    GREEN)
      if [ "$CP" != "$NOW_P" ]; then
        COUNCIL_REASON="council verdict is STALE (pack) - judged $CP, now $NOW_P; open a new round"
      elif [ "$CH" != "$HEAD_NOW" ] && ! paperwork_only "$ROOT" "$CH" "$HEAD_NOW"; then
        COUNCIL_REASON="council verdict is STALE (commit) - judged at $CH, HEAD is $HEAD_NOW with code changed since; open a new round"
      else
        COUNCIL_OK=1
      fi
      ;;
    RED) COUNCIL_REASON="council RED round $CROUND - repair needed (pack $CP at $CH)" ;;
    ESCALATE) COUNCIL_REASON="council ESCALATE round $CROUND - see ## Needs a human in plan.md" ;;
    STALE) COUNCIL_REASON="council round $CROUND went STALE before judging - open a new round" ;;
    *) COUNCIL_REASON="council verdict '$CV' unrecognised - treat as not ready" ;;
  esac

  OVERRIDE=""
  if [ -n "$HLAST" ] && [ -n "$HTS" ] && [ -n "$CTS" ] \
     && { [ "$HTS" \> "$CTS" ] || [ "$HTS" = "$CTS" ]; }; then
    case "$HV" in
      ACCEPTED) OVERRIDE=ACCEPTED ;;
      REJECTED) OVERRIDE=REJECTED ;;
    esac
  fi

  COUNCIL_LINE="council $CV round $CROUND, pack $CP at $CH"
  if [ -n "$HLAST" ]; then CHECKED_LINE="**Checked:** $HV by $HB"
  else CHECKED_LINE="no **Checked:** override recorded"; fi

  if [ "$OVERRIDE" = REJECTED ]; then
    fail 04 "tests+human: $COUNCIL_LINE, but $CHECKED_LINE is newer and overrides to OPEN"
    fail 05 "tests+human: $CHECKED_LINE - newer than the council row, overrides $CV"
  elif [ "$OVERRIDE" = ACCEPTED ]; then
    ok 04 "tests+human: $COUNCIL_LINE, $CHECKED_LINE overrides"
    ok 05 "tests+human: $CHECKED_LINE - newer than the council row, overrides $CV"
  elif [ "$COUNCIL_OK" -eq 1 ]; then
    ok 04 "tests+human: $COUNCIL_LINE, current for this pack ($CHECKED_LINE)"
    ok 05 "tests+human: $COUNCIL_LINE closes both stages ($CHECKED_LINE)"
  else
    fail 04 "tests+human: $COUNCIL_REASON ($CHECKED_LINE)"
    fail 05 "tests+human: $COUNCIL_REASON ($CHECKED_LINE)"
  fi
else
  # --- no council row for this spec: pre-council behaviour, unchanged -------------------
  ACC="memory/stats/acceptance.jsonl"
  LAST=""
  [ -f "$ACC" ] && LAST="$(grep -F "\"spec\":\"$SLUG\"" "$ACC" | tail -1)"
  if [ -z "$LAST" ]; then
    fail 04 "tests: no acceptance verdict recorded - the blind gate never judged this pack (/vulyk-review)"
  else
    AV="$(printf '%s' "$LAST" | sed -n 's/.*"verdict":"\([^"]*\)".*/\1/p')"
    AP="$(printf '%s' "$LAST" | sed -n 's/.*"pack":"\([^"]*\)".*/\1/p')"
    if [ "$AP" != "$NOW_P" ]; then
      fail 04 "tests: acceptance verdict $AV is STALE - given against pack $AP, now $NOW_P; run /vulyk-review to record a current council verdict"
    elif [ "$AV" = ACCEPTED ]; then
      ok 04 "tests: acceptance ACCEPTED, current for this pack"
    elif [ "$AV" = CANNOT_RUN ]; then
      say 04 "weak" "tests: acceptance CANNOT_RUN - nothing observed the asks working; the owner's look at 05 is the only run there is"
    else
      fail 04 "tests: acceptance $AV - the blind gate said the asks do not work"
    fi
  fi

  if [ -z "$HLAST" ]; then
    fail 05 "human: nobody has looked - no record in memory/stats/human.jsonl (scripts/human-check.sh after the owner answers)"
  else
    HV="$(printf '%s' "$HLAST" | sed -n 's/.*"verdict":"\([^"]*\)".*/\1/p')"
    HP="$(printf '%s' "$HLAST" | sed -n 's/.*"pack":"\([^"]*\)".*/\1/p')"
    HH="$(printf '%s' "$HLAST" | sed -n 's/.*"head":"\([^"]*\)".*/\1/p')"
    HB="$(printf '%s' "$HLAST" | sed -n 's/.*"by":"\([^"]*\)".*/\1/p')"
    if [ "$HV" != ACCEPTED ]; then
      fail 05 "human: the owner REJECTED - route what they named into fix stories and look again"
    elif [ "$HP" != "$NOW_P" ]; then
      fail 05 "human: check is STALE (pack) - accepted $HP, now $NOW_P"
    elif [ "$HH" != "$HEAD_NOW" ] && ! paperwork_only "$ROOT" "$HH" "$HEAD_NOW"; then
      fail 05 "human: check is STALE (commit) - $HB looked at $HH, HEAD is $HEAD_NOW with code changed since; what they saw is not what ships"
    else
      ok 05 "human: ACCEPTED by $HB at $HH - this pack, this code (only cycle records landed since, if anything)"
    fi
  fi
fi

# 06 Ship - already done?
if [ -f "$PLAN" ] && [ -n "$(marker "$PLAN" Shipped)" ]; then
  say 06 "done" "ship: already recorded - $(marker "$PLAN" Shipped)"
fi

echo ""
if [ "$MISSING" -eq 0 ]; then
  echo "  READY. Every confirmation exists and is about this pack at this commit. /vulyk-ship may proceed."
else
  echo "  NOT READY - $MISSING open confirmation(s). The cycle is not at 06; the lines above say where it is."
fi
exit 0
