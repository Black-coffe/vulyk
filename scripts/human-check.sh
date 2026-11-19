#!/usr/bin/env bash
# VULYK human check - stage 05 of the cycle, the one no agent may take.
#
#   Usage: scripts/human-check.sh <spec-dir> <ACCEPTED|REJECTED> [where you looked / note] [--commit]
#          scripts/human-check.sh docs/specs/oauth ACCEPTED "staging, logged in as a new user, logout works" --commit
#          scripts/human-check.sh --check <spec-dir>       # is the newest check still about THIS pack at THIS commit?
#          scripts/human-check.sh --show <spec-dir>        # the pack's change as text, for the reply before ACCEPTED
#
# The blind acceptance gate can say the software does what the brief's words said. Only
# the person who wrote the words can say whether the words said what they meant, so the
# owner looks - on a test or a live version - and this script writes down that they did.
# It never judges anything: the verdict is the caller's, and the caller is a human. The
# Queen runs it AFTER the owner has answered, quoting their words in the note, and never
# before - a check recorded on the owner's behalf is the failure this stage exists to stop.
#
# Two records, same fact:
#   plan.md                  - one `**Checked:**` line appended, beside `**Approved:**`: the
#                              artifact /vulyk-ship refuses without.
#   memory/stats/human.jsonl - the same line as data, stamped with the commit and the pack
#                              fingerprint it was given against, so `--check` can say whether
#                              a later commit or a repair story has made it about something else.
#
# Exit status is always 0: this records, it does not block. `/vulyk-ship` is what blocks.
set -u

# pack_fingerprint() and paperwork_only() now live in scripts/lib.sh, shared with
# ship-check.sh, acceptance-log.sh, release-check.sh and cycle.sh (ADR-001 C1) - one
# implementation instead of several that had to agree by hand.
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$HERE/lib.sh"

# --- `--show`: the pack's change, for the Queen to paste into her reply before the owner answers ----
# Base: the merge-base with the default branch while on the spec's branch; otherwise (on the default
# branch, after a merge) the parent of the commit that added <spec>/plan.md, or the empty tree. Prints
# `git diff --stat`, then the diff (code first, docs/specs/ after) capped at SHOW_CAP lines and a line naming the cut and the command
# for the rest. Writes nothing. A missing spec dir or no git repo exits 2: never a silent pass.
SHOW_CAP=300
if [ "${1:-}" = "--show" ]; then
  SSPEC="${2:-}"
  [ -n "$SSPEC" ] && [ -d "$SSPEC" ] || {
    echo "human-check: --show - no spec dir '${SSPEC}': usage: $0 --show <spec-dir>" >&2; exit 2; }
  git rev-parse --show-toplevel >/dev/null 2>&1 || {
    echo "human-check: --show - not a git repo, there is no diff to show" >&2; exit 2; }
  SDEF="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"; SDEF="${SDEF#origin/}"
  [ -n "$SDEF" ] || { git show-ref --verify --quiet refs/heads/main && SDEF=main; }
  [ -n "$SDEF" ] || { git show-ref --verify --quiet refs/heads/master && SDEF=master; }
  SBASE=""
  if [ -n "$SDEF" ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" != "$SDEF" ]; then
    SBASE="$(git merge-base "$SDEF" HEAD 2>/dev/null)"
  fi
  if [ -z "$SBASE" ]; then
    SADD="$(git log --diff-filter=A --format=%H -- "$SSPEC/plan.md" 2>/dev/null | tail -n 1)"
    [ -n "$SADD" ] && SBASE="$(git rev-parse -q --verify "$SADD^" 2>/dev/null)"
    [ -n "$SBASE" ] || SBASE="$(git hash-object -t tree /dev/null)"   # the empty tree
  fi
  SB7="$(printf '%s' "$SBASE" | cut -c1-7)"
  echo "human-check: $(basename "$SSPEC") - the change from $SB7 to HEAD"
  git -c core.quotePath=false diff --stat "$SBASE" HEAD
  # Code first, spec paperwork (docs/specs/) after, one cap over both: paperwork sorts first in git's
  # order and filled the cap before a line of code showed (tails-1115-05, T16).
  STOTAL="$(git diff "$SBASE" HEAD | wc -l | tr -d ' ')"
  { git -c core.quotePath=false diff "$SBASE" HEAD -- ':(top)' ':(top,exclude)docs/specs/'
    git -c core.quotePath=false diff "$SBASE" HEAD -- ':(top)docs/specs/'; } | head -n "$SHOW_CAP"
  if [ "$STOTAL" -gt "$SHOW_CAP" ]; then
    echo "... $((STOTAL - SHOW_CAP)) more lines cut; the rest: git diff $SB7 HEAD"
  fi
  exit 0
fi

# --- `--check`: does the newest recorded human check still describe this pack, here? ----
if [ "${1:-}" = "--check" ]; then
  CSPEC="${2:-}"
  [ -n "$CSPEC" ] && [ -d "$CSPEC" ] || {
    echo "human-check: usage: $0 --check <spec-dir>" >&2; exit 0; }
  CROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "human-check: CANNOT RUN - not a git repo, so there is no memory/stats to read." >&2
    exit 0; }
  CSTATS="$CROOT/memory/stats/human.jsonl"
  CNAME="$(basename "$CSPEC")"
  LAST="$(grep -F "\"spec\":\"$CNAME\"" "$CSTATS" 2>/dev/null | tail -1)"
  if [ -z "$LAST" ]; then
    echo "human-check: $CNAME - NO HUMAN CHECK RECORDED. Nobody has looked at this pack yet."
    exit 0
  fi
  WAS_V="$(printf '%s' "$LAST" | sed -n 's/.*"verdict":"\([^"]*\)".*/\1/p')"
  WAS_P="$(printf '%s' "$LAST" | sed -n 's/.*"pack":"\([^"]*\)".*/\1/p')"
  WAS_H="$(printf '%s' "$LAST" | sed -n 's/.*"head":"\([^"]*\)".*/\1/p')"
  NOW_P="$(pack_fingerprint "$CSPEC")"
  NOW_H="$(git -C "$CROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if [ "$WAS_V" != "ACCEPTED" ]; then
    echo "human-check: $CNAME - REJECTED. The owner looked and said no; the newest record is a rejection."
    echo "  Route the findings into fix stories and re-run the cycle from /vulyk-build; then look again."
    exit 0
  fi
  case "$(verdict_stale "$CSPEC" "$WAS_H" "$WAS_P")" in
    "STALE (pack)")
      echo "human-check: $CNAME - STALE (pack). The owner accepted a different set of stories"
      echo "  (recorded $WAS_P, now $NOW_P). Stories were added, removed or renamed since - look again."
      exit 0 ;;
    "STALE (commit)")
      echo "human-check: $CNAME - STALE (commit). The owner accepted at $WAS_H; HEAD is now $NOW_H."
      echo "  Something was committed after they looked. What they saw is not what ships - look again."
      exit 0 ;;
  esac
  echo "human-check: $CNAME - CURRENT. The owner accepted this exact pack at commit $WAS_H, and nothing but cycle paperwork has landed since."
  exit 0
fi

# `--commit`, anywhere among the arguments: commit the plan.md line and the record row this run writes, and only
# those two paths. owner-guard denies any agent command naming the record beside a verdict word, a git commit of
# it included, so this is the way the record is committed.
COMMIT=0
ARGS=()
for a in "$@"; do
  if [ "$a" = "--commit" ]; then COMMIT=1; else ARGS+=("$a"); fi
done
SPEC="${ARGS[0]:-}"
VERDICT="${ARGS[1]:-}"
NOTE="${ARGS[2]:-}"

if [ -z "$SPEC" ] || [ ! -d "$SPEC" ] || [ -z "$VERDICT" ]; then
  echo "human-check: usage: $0 <spec-dir> <ACCEPTED|REJECTED> [note]" >&2
  exit 0
fi

case "$VERDICT" in
  ACCEPTED|REJECTED) ;;
  *) echo "human-check: verdict must be ACCEPTED or REJECTED (got '$VERDICT') - a human check has no cannot-run branch; if you could not look, you have not checked." >&2; exit 0 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "human-check: CANNOT RUN - not a git repo, so there is no memory/stats to append to." >&2
  exit 0
}

PLAN="$SPEC/plan.md"
[ -f "$PLAN" ] || {
  echo "human-check: CANNOT RUN - $PLAN does not exist. A check is recorded beside the approval it follows; without a plan there is nothing to record it against." >&2
  exit 0
}

# `--commit` commits the two paths whole, so they must hold nothing but what this run appends: an uncommitted
# change already in either would ride into the commit under the owner's verdict. Refuse before writing anything.
if [ "$COMMIT" = 1 ]; then
  for p in "$PLAN" "$ROOT/memory/stats/human.jsonl"; do
    [ -e "$p" ] || continue
    if [ -n "$(git -C "$ROOT" status --porcelain -- "$p" 2>/dev/null)" ]; then
      echo "human-check: REFUSED --commit - $p has uncommitted changes; they would be committed under this verdict. Commit or drop them first; nothing is recorded." >&2
      exit 1
    fi
  done
fi

# Who looked: the committer identity is the closest thing to a signature git has. Never
# invent a name - an unnamed check is still a check, an attributed one nobody made is not.
OWNER="$(git -C "$ROOT" config user.name 2>/dev/null || true)"
[ -n "$OWNER" ] || OWNER="${USER:-${USERNAME:-owner}}"
DATE="$(date -u +%Y-%m-%d)"
HEAD_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
PACK="$(pack_fingerprint "$SPEC")"

# The note is the owner's own words about what they saw, and it lands in two committed
# files - same exposure as an acceptance note, same filter first.
# No redact.sh to run (missing, or not a file) refuses the same way, as journal.sh and ship-check.sh do.
[ -f "$ROOT/scripts/redact.sh" ] || {
  echo "human-check: REFUSED - scripts/redact.sh is missing, so the note cannot be masked; nothing is recorded. Restore it and run this again." >&2
  exit 1
}
# redact.sh exits 1 when it cannot mask; its stdout is then a marker, not the note. Nothing is recorded.
SAFE_NOTE="$(printf '%s' "$NOTE" | bash "$ROOT/scripts/redact.sh")" || {
  echo "human-check: REFUSED - scripts/redact.sh failed (its stderr says why), so the note cannot be masked; nothing is recorded. Fix it and run this again." >&2
  exit 1
}
ONE_LINE="$(printf '%s' "$SAFE_NOTE" | tr -d '\n' | tr -d '\r')"
ESCAPED="$(printf '%s' "$ONE_LINE" | tr -d '\\' | tr '"' "'")"

# plan.md: append, never replace. A second look after a repair round is a second line, and
# the sequence is the record - a rejection that was later accepted stays visible as both.
LINE="**Checked:** $VERDICT by $OWNER, $DATE, at $HEAD_SHA"
[ -n "$ONE_LINE" ] && LINE="$LINE - $ONE_LINE"
# Drop the template placeholder the first time a real line lands.
if grep -q '^\*\*Checked:\*\* <' "$PLAN" 2>/dev/null; then
  TMP="$PLAN.tmp$$"
  grep -v '^\*\*Checked:\*\* <' "$PLAN" > "$TMP" && mv "$TMP" "$PLAN"
fi
printf '%s\n' "$LINE" >> "$PLAN"

mkdir -p "$ROOT/memory/stats"
STATS="$ROOT/memory/stats/human.jsonl"
BY_ESC="$(printf '%s' "$OWNER" | tr -d '\\' | tr '"' "'")"
printf '{"ts":"%s","spec":"%s","verdict":"%s","by":"%s","head":"%s","pack":"%s","note":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$SPEC")" "$VERDICT" "$BY_ESC" "$HEAD_SHA" "$PACK" "$ESCAPED" >> "$STATS"

echo "human-check: $(basename "$SPEC") - $VERDICT by $OWNER at $HEAD_SHA (pack $PACK)"
if [ "$COMMIT" = 1 ]; then
  # `git commit -- <paths>` commits those paths only: anything else staged stays staged and uncommitted
  if git -C "$ROOT" add -- "$(cd "$SPEC" && pwd)/plan.md" "$STATS" &&
     git -C "$ROOT" commit -q -m "vulyk($(basename "$SPEC")): human check $VERDICT" -- \
       "$(cd "$SPEC" && pwd)/plan.md" "$STATS"; then
    echo "  recorded in $PLAN and memory/stats/human.jsonl and committed ($(git -C "$ROOT" rev-parse --short HEAD))."
  else
    echo "human-check: the record is written but the commit failed (git said why above); commit $PLAN and memory/stats/human.jsonl yourself, or ask the owner to." >&2
    exit 1
  fi
else
  echo "  recorded in $PLAN and memory/stats/human.jsonl. Commit it with --commit next time; an agent's own"
  echo "  git commit naming the record beside the verdict is refused by owner-guard."
fi
echo "  Any CODE commit after it makes it stale; '$0 --check $SPEC' says whether it still describes what ships."
if [ "$VERDICT" = REJECTED ]; then
  echo "  ! The owner said no. Each thing they named becomes a fix story in this spec, through"
  echo "    /vulyk-build - never a hand patch - and both gates run again before the next look."
fi
exit 0
