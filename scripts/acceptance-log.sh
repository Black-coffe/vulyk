#!/usr/bin/env bash
# VULYK acceptance drift log - fourth deterministic record, beside scope/wave/trace.
#
#   Usage: scripts/acceptance-log.sh <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]
#          scripts/acceptance-log.sh docs/specs/oauth REJECTED "logout ask never wired up"
#          scripts/acceptance-log.sh --check <spec-dir>       # is the newest verdict still about THIS pack?
#
# `drone-acceptance` judges the built software against brief.md alone - it never sees the
# stories, so it does not know what the hive believes it finished. This script writes down
# both accounts side by side and computes the only number worth keeping:
#
#   drift = the stories all say `done` and the blind gate did NOT accept.
#
# That is the framework contradicting its own story about itself, and it is the one series
# no other gate in VULYK can produce. Read it for what it is: `drift` is evidence about
# DELIVERY - whether the asks got built - and never about PROOF that the build is sound.
# The two are independent, and the first real run showed it: the blind gate accepted a pack
# `lead-review` then blocked twice, on coverage holes that were entirely real. A long run of
# `false` says the pipeline delivers what was asked; it says nothing about how well anyone
# checked.
#
# A verdict is about the pack that existed when the drone ran, so each record carries that
# pack's IDENTITY - `head` (the commit) and `pack` (a fingerprint over the story files) -
# not merely its size. Without them the series is falsifiable by ordinary process: run the
# gate, let review carve out repair stories, ship. The record then reads ACCEPTED with no
# drift about a pack the gate never saw, which is exactly what happened on the first real
# run (katan S2.6.5a: accepted at six stories, shipped at nine). `--check` is what makes
# that visible - it recomputes the fingerprint and says whether the newest verdict for this
# spec still describes it.
#
# Story statuses come from the spec dir (frontmatter `status:`), the verdict from the
# caller - the Queen, right after reading the drone's report. Deterministic, no model.
# Exit status is always 0: this records, it does not block.

set -u

# The identity of a pack: its story files, by name, in a stable order. Adding, removing or
# renaming a story changes it; editing a story's body does not - a verdict is about which
# work was judged, not about later wording. Degrades to the plain count where no sha256 tool
# exists, which still catches the case that actually happened.
pack_fingerprint() { # pack_fingerprint <spec-dir>
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

# --- `--check`: does the newest recorded verdict still describe this pack? -------------
if [ "${1:-}" = "--check" ]; then
  CSPEC="${2:-}"
  [ -n "$CSPEC" ] && [ -d "$CSPEC" ] || {
    echo "acceptance-log: usage: $0 --check <spec-dir>" >&2; exit 0; }
  CROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "acceptance-log: CANNOT RUN - not a git repo, so there is no memory/stats to read." >&2
    exit 0; }
  CSTATS="$CROOT/memory/stats/acceptance.jsonl"
  CNAME="$(basename "$CSPEC")"
  LAST="$(grep -F "\"spec\":\"$CNAME\"" "$CSTATS" 2>/dev/null | tail -1)"
  if [ -z "$LAST" ]; then
    echo "acceptance-log: $CNAME - NO VERDICT RECORDED. The blind gate has never judged this pack."
    exit 0
  fi
  WAS="$(printf '%s' "$LAST" | sed -n 's/.*"pack":"\([^"]*\)".*/\1/p')"
  NOW="$(pack_fingerprint "$CSPEC")"
  if [ -z "$WAS" ]; then
    echo "acceptance-log: $CNAME - the newest verdict predates pack fingerprints; it cannot be"
    echo "  shown to describe the pack as it stands. Re-run the gate if the pack has changed since."
    exit 0
  fi
  if [ "$WAS" = "$NOW" ]; then
    echo "acceptance-log: $CNAME - CURRENT. The newest verdict was given against this exact pack."
  else
    echo "acceptance-log: $CNAME - STALE. The newest verdict was given against a different pack"
    echo "  (recorded $WAS, now $NOW). Stories were added, removed or renamed after the gate ran,"
    echo "  so the recorded verdict - and its drift number - are about work that is not what ships."
    echo "  Re-dispatch drone-acceptance and log again before treating this spec as accepted."
  fi
  exit 0
fi

SPEC="${1:-}"
VERDICT="${2:-}"
NOTE="${3:-}"

if [ -z "$SPEC" ] || [ ! -d "$SPEC" ] || [ -z "$VERDICT" ]; then
  echo "acceptance-log: usage: $0 <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]" >&2
  exit 0
fi

case "$VERDICT" in
  ACCEPTED|REJECTED|CANNOT_RUN) ;;
  *) echo "acceptance-log: verdict must be ACCEPTED, REJECTED or CANNOT_RUN (got '$VERDICT')" >&2; exit 0 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "acceptance-log: CANNOT RUN - not a git repo, so there is no memory/stats to append to." >&2
  exit 0
}

TOTAL=0; DONE=0; BLOCKED=0
for f in "$SPEC"/*.md; do
  [ -f "$f" ] || continue
  grep -q '^story:' "$f" 2>/dev/null || continue
  TOTAL=$((TOTAL+1))
  st="$(awk -F': *' '$1 == "status" { sub(/[[:space:]]*#.*$/, "", $2); gsub(/[[:space:]]/, "", $2); print $2; exit }' "$f")"
  case "$st" in
    done)    DONE=$((DONE+1)) ;;
    blocked) BLOCKED=$((BLOCKED+1)) ;;
  esac
done

DRIFT=false
if [ "$TOTAL" -gt 0 ] && [ "$DONE" -eq "$TOTAL" ] && [ "$VERDICT" != "ACCEPTED" ]; then
  DRIFT=true
fi

# Keep the free-text note JSON-safe the blunt way: double quotes become apostrophes,
# backslashes and newlines are dropped. The note is a human hint sitting next to the
# numbers, not data anything parses - losing a character beats emitting a broken line.
ESCAPED="$(printf '%s' "$NOTE" | tr -d '\n' | tr -d '\\' | tr '"' "'")"

mkdir -p "$ROOT/memory/stats"
STATS="$ROOT/memory/stats/acceptance.jsonl"
# The pack this verdict is ABOUT, so a later reader can tell whether it still is.
HEAD_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
PACK="$(pack_fingerprint "$SPEC")"

printf '{"ts":"%s","spec":"%s","verdict":"%s","stories":%s,"done":%s,"blocked":%s,"drift":%s,"head":"%s","pack":"%s","note":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$SPEC")" "$VERDICT" \
  "$TOTAL" "$DONE" "$BLOCKED" "$DRIFT" "$HEAD_SHA" "$PACK" "$ESCAPED" >> "$STATS"

echo "acceptance-log: $(basename "$SPEC") - verdict $VERDICT, stories $DONE/$TOTAL done, $BLOCKED blocked, drift $DRIFT"
echo "  pack $PACK at $HEAD_SHA - this verdict is about THAT pack; re-check with --check before merging."
if [ "$DRIFT" = true ]; then
  echo "  ! Every story reports done and the blind gate did not accept. One of the two accounts"
  echo "    is wrong, and the story statuses are the one written by the party with an interest."
fi
exit 0
