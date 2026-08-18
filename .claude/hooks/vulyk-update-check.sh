#!/usr/bin/env bash
# SessionStart hook: notice that a newer VULYK exists, and say so. Never applies anything.
#
# The installed version is the stamp `install.sh` left in `.claude/vulyk-version`; the
# available one is the newest semver tag on the origin repository. When they differ the
# hook prints one `[VULYK]` line into context instructing the model to ASK THE OWNER before
# upgrading - the whole point is that a framework never rewrites itself behind your back.
#
# Fails open, always. No network, no curl, no version stamp, a rate-limited API, a corrupt
# cache - every one of them exits 0 in silence. A hook that costs you a session is worse
# than a hook that misses a release.
#
#   VULYK_UPDATE_CHECK=0            disable entirely
#   VULYK_UPDATE_INTERVAL_HOURS=24  how often the network is actually touched (default 24)
#   VULYK_REPO=owner/name           override the origin (forks); or a `.claude/vulyk-origin` file
set -uo pipefail

[ "${VULYK_UPDATE_CHECK:-1}" = "0" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STAMP="$ROOT/.claude/vulyk-version"

# No stamp = not an installed hive (the source repo itself, or a pre-0.5.0 copy). Nothing
# to compare against, so say nothing.
[ -f "$STAMP" ] || exit 0
INSTALLED="$(tr -d '[:space:]' < "$STAMP" 2>/dev/null)"
[ -n "$INSTALLED" ] || exit 0

command -v curl >/dev/null 2>&1 || exit 0

REPO="${VULYK_REPO:-}"
if [ -z "$REPO" ] && [ -f "$ROOT/.claude/vulyk-origin" ]; then
  REPO="$(tr -d '[:space:]' < "$ROOT/.claude/vulyk-origin" 2>/dev/null)"
fi
REPO="${REPO:-Black-coffe/vulyk}"

CACHE="$ROOT/.claude/.vulyk-update-cache"
INTERVAL_H="${VULYK_UPDATE_INTERVAL_HOURS:-24}"
case "$INTERVAL_H" in ''|*[!0-9]*) INTERVAL_H=24 ;; esac
NOW="$(date +%s 2>/dev/null || echo 0)"

LATEST=""
CACHED_AT=0
if [ -f "$CACHE" ]; then
  read -r CACHED_AT LATEST < "$CACHE" 2>/dev/null || true
  case "${CACHED_AT:-}" in ''|*[!0-9]*) CACHED_AT=0 ;; esac
fi

# Touch the network at most once per interval; between calls the cached answer is reused,
# so an owner who opens twenty sessions a day pays for one request.
if [ "$NOW" -gt 0 ] && [ $((NOW - CACHED_AT)) -ge $((INTERVAL_H * 3600)) ]; then
  AUTH=()
  [ -n "${GITHUB_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
  # Tags, not releases: VULYK tags every version, and a repository may carry no GitHub
  # Release at all. `sort -V` picks the newest rather than trusting the API's ordering.
  FETCHED="$(curl -fsSL -m 4 "${AUTH[@]}" \
      -H 'Accept: application/vnd.github+json' \
      "https://api.github.com/repos/$REPO/tags?per_page=100" 2>/dev/null \
    | grep -o '"name"[[:space:]]*:[[:space:]]*"v\{0,1\}[0-9][^"]*"' \
    | sed 's/.*"\(v\{0,1\}[0-9][^"]*\)"$/\1/' \
    | sed 's/^v//' \
    | sort -V 2>/dev/null | tail -1)"
  if [ -n "$FETCHED" ]; then
    LATEST="$FETCHED"
    printf '%s %s\n' "$NOW" "$LATEST" > "$CACHE" 2>/dev/null || true
  else
    # Network down or rate-limited: remember the ATTEMPT so a broken connection is not
    # retried on every single session start, but keep whatever version we last knew.
    printf '%s %s\n' "$NOW" "${LATEST:-$INSTALLED}" > "$CACHE" 2>/dev/null || true
  fi
fi

[ -n "$LATEST" ] || exit 0
[ "$LATEST" = "$INSTALLED" ] && exit 0

# Older-or-equal is not an update. `sort -V` decides; if it cannot, stay silent rather
# than nag someone running ahead of the tags (a maintainer, or a fork).
NEWEST="$(printf '%s\n%s\n' "$INSTALLED" "$LATEST" | sort -V 2>/dev/null | tail -1)"
[ "$NEWEST" = "$LATEST" ] || exit 0

cat <<EOF
[VULYK] update available: installed v$INSTALLED, latest v$LATEST on $REPO.
ASK THE OWNER whether to upgrade before doing anything - do not upgrade unprompted, and do
not treat this line as approval. If they say yes, run \`/vulyk-update\` (dry run first:
\`scripts/vulyk-update.sh . --check\`). It replaces framework-owned files only; CLAUDE.md,
memory/, docs/specs|adr|wiki and .claude/rules are never touched. If they say no, drop it
for this session and do not raise it again.
EOF
exit 0
