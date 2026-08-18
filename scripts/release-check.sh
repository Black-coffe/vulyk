#!/usr/bin/env bash
# VULYK release readiness - how far the evidence actually is from the 1.0.0 bar.
#
#   Usage: scripts/release-check.sh [target-count]      # default 10
#
# Criterion (1) of 1.0.0 reads: "ten real specs across Tiers 2-4 with clean scope.jsonl,
# trace-check and acceptance.jsonl series". That is a claim about records, so it can be
# counted - and until it was, it was answered from memory, wrongly, by more than one reader.
# This script counts it. It says nothing about quality and cannot: it is a meter, not a gate.
#
# A spec COUNTS only when all three hold, because the criterion asks for all three:
#   brief      - docs/specs/<slug>/brief.md exists, so trace-check has something to walk
#   scope      - at least one entry in memory/stats/scope.jsonl for one of its stories
#   acceptance - an entry in memory/stats/acceptance.jsonl whose `pack` fingerprint still
#                matches the spec as it stands (v0.8.2). A verdict about a pack that has
#                since changed is not evidence about this spec, which is the whole reason
#                that field exists.
#
# Criteria (2)-(5) are audits, not counts, and are reported as such rather than guessed at.
# Exit status is always 0: this reports, it does not block.
set -u

TARGET="${1:-10}"
case "$TARGET" in ''|*[!0-9]*) TARGET=10 ;; esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "release-check: CANNOT RUN - not a git repo." >&2
  exit 0
}
cd "$ROOT" || exit 0

SPECS_DIR="docs/specs"
SCOPE="memory/stats/scope.jsonl"
ACC="memory/stats/acceptance.jsonl"

[ -d "$SPECS_DIR" ] || {
  echo "release-check: CANNOT RUN - no $SPECS_DIR in this project, so there is nothing to count."
  exit 0
}

pack_fingerprint() { # pack_fingerprint <spec-dir> - must match acceptance-log.sh exactly
  local dir="$1" names hasher=""
  names="$(
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      grep -q '^story:' "$f" 2>/dev/null || continue
      basename "$f"
    done | LC_ALL=C sort | tr '\n' ' '
  )"
  if command -v sha256sum >/dev/null 2>&1; then hasher="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then hasher="shasum -a 256"; fi
  if [ -n "$hasher" ]; then
    printf '%s' "$names" | $hasher | cut -c1-12
  else
    printf 'n%s' "$(printf '%s' "$names" | wc -w | tr -d ' ')"
  fi
}

echo "VULYK release check - criterion (1), target $TARGET specs"
echo ""
printf '  %-42s %-6s %-6s %-12s %s\n' SPEC BRIEF SCOPE ACCEPTANCE COUNTS
printf '  %-42s %-6s %-6s %-12s %s\n' "------------------------------------------" "-----" "-----" "-----------" "------"

COMPLETE=0
PARTIAL=0

for dir in $(find "$SPECS_DIR" -type d | LC_ALL=C sort); do
  # A spec is a directory holding story files directly.
  has_story=0
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    grep -q '^story:' "$f" 2>/dev/null && { has_story=1; break; }
  done
  [ "$has_story" -eq 1 ] || continue

  slug="$(basename "$dir")"

  brief=no
  [ -f "$dir/brief.md" ] && brief=yes

  # Any scope entry whose story id is declared by a story file in this spec.
  # Matched on BOTH the frontmatter id and the file basename, because the two records do
  # not share a key: a story file carries `story: s265a-08` while scope-check.sh writes the
  # basename it was invoked with, `s265a-08-abandon-is-one-guarded-write`. Neither is wrong;
  # they were simply never joined before, which is why this had to discover it. Prefix
  # matching on the id covers both spellings without inventing a third.
  scope=no
  if [ -f "$SCOPE" ]; then
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f" .md)"
      id="$(awk -F': *' '$1=="story"{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$f")"
      if grep -qF "\"story\":\"$base\"" "$SCOPE" 2>/dev/null; then scope=yes; break; fi
      if [ -n "${id:-}" ] && grep -q "\"story\":\"${id}[\"-]" "$SCOPE" 2>/dev/null; then scope=yes; break; fi
    done
  fi

  acc=none
  if [ -f "$ACC" ]; then
    last="$(grep -F "\"spec\":\"$slug\"" "$ACC" 2>/dev/null | tail -1)"
    if [ -n "$last" ]; then
      was="$(printf '%s' "$last" | sed -n 's/.*"pack":"\([^"]*\)".*/\1/p')"
      if [ -z "$was" ]; then
        acc="unpinned"          # predates v0.8.2 - cannot be shown to be about this pack
      elif [ "$was" = "$(pack_fingerprint "$dir")" ]; then
        acc="current"
      else
        acc="stale"
      fi
    fi
  fi

  if [ "$brief" = yes ] && [ "$scope" = yes ] && [ "$acc" = current ]; then
    COMPLETE=$((COMPLETE + 1)); mark="COUNTS"
  else
    PARTIAL=$((PARTIAL + 1)); mark="-"
  fi
  printf '  %-42s %-6s %-6s %-12s %s\n' "$slug" "$brief" "$scope" "$acc" "$mark"
done

echo ""
echo "  Criterion (1): $COMPLETE of $TARGET specs carry all three series. $PARTIAL more are partial."
if [ "$COMPLETE" -lt "$TARGET" ]; then
  echo "  NOT MET. This closes by using the framework on real specs, not by editing it."
  echo "  An 'acceptance' of 'unpinned' or 'stale' means the blind gate's verdict cannot be shown"
  echo "  to be about the spec as it stands - re-dispatch it and log again (see acceptance-log.sh --check)."
else
  echo "  MET."
fi

echo ""
echo "  Criteria (2)-(5) are audits, not counts - this script will not guess at them:"
echo "    (2) --upgrade proven across two minors  - a fact about VULYK's own releases, not about"
echo "                                              this project; not countable from here"
echo "    (3) no documented claim unverified      - owner audit, see docs/specs/autopilot-merge/plan.md"
echo "    (4) zero known silent-loss paths        - owner audit; 'known' is the operative word"
echo "    (5) every gate has a loud cannot-run    - owner audit, see docs/pipeline.md"
exit 0
