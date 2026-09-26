#!/usr/bin/env bash
# Apply a VULYK upgrade the update-check hook noticed - after the owner said yes.
#
#   Dry run:  scripts/vulyk-update.sh . --check
#   Apply:    scripts/vulyk-update.sh .
#   Pin:      scripts/vulyk-update.sh . --version 0.7.0
#   Consent:  scripts/vulyk-update.sh . --telemetry ask     (on|off|ask; or VULYK_TELEMETRY)
#   Migrate:  scripts/vulyk-update.sh . --constitution replace
#             (the release's constitution over yours, your Profile and Commands blocks carried
#             over, the old file kept as <name>.pre-<major.minor>.md; add --check to see it first)
#
# Fetches the origin repository into a cache outside your project, checks out the requested
# tag (newest by default), and hands the work to that release's own `install.sh --upgrade`.
# The installer is what decides what may be replaced - agents, commands, hooks, meta-skills,
# bootstrap, templates, scripts - and what is yours and stays untouched: CLAUDE.md (unless you
# pass --constitution replace), memory/, docs/specs|adr|wiki, .claude/rules. This script adds no
# copying logic of its own, so an
# upgrade can never mean something different from what that release documented.
#
#   VULYK_REPO=owner/name     override the origin (forks); or a `.claude/vulyk-origin` file
#   VULYK_SRC=/path/to/cache  where the source clone lives (default ~/.vulyk/src)
set -euo pipefail

DEST="."; CHECK=""; WANT=""; TEL=""; CONST=""
USAGE="Usage: $0 [project-dir] [--check] [--version X.Y.Z] [--telemetry on|off|ask] [--constitution replace]"
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   CHECK="--check" ;;
    --version) shift; WANT="${1:-}"; [ -n "$WANT" ] || { echo "error: --version needs a value"; exit 1; } ;;
    # Passed through verbatim to the release's own install.sh, which owns the consent rule;
    # VULYK_TELEMETRY needs no plumbing at all (it travels in the environment), and neither
    # does stdin - the installer reads its question from /dev/tty, which is inherited here.
    --telemetry) shift; TEL="${1:-}"; [ -n "$TEL" ] || { echo "error: --telemetry needs a value (on|off|ask)"; exit 1; } ;;
    # Passed through the same way: the release's install.sh owns what a replace means.
    --constitution) shift; CONST="${1:-}"
               [ "$CONST" = "replace" ] || { echo "error: --constitution takes one value: replace (got '$CONST')"; exit 1; } ;;
    -*)        echo "error: unknown flag $1"; echo "$USAGE"; exit 1 ;;
    *)         DEST="$1" ;;
  esac
  shift
done

[ -d "$DEST" ] || { echo "error: $DEST is not a directory"; exit 1; }
DEST="$(cd "$DEST" && pwd)"
command -v git >/dev/null 2>&1 || { echo "error: git is required"; exit 1; }

REPO="${VULYK_REPO:-}"
if [ -z "$REPO" ] && [ -f "$DEST/.claude/vulyk-origin" ]; then
  REPO="$(tr -d '[:space:]' < "$DEST/.claude/vulyk-origin")"
fi
REPO="${REPO:-Black-coffe/vulyk}"
SRC="${VULYK_SRC:-$HOME/.vulyk/src}"

INSTALLED="$(tr -d '[:space:]' < "$DEST/.claude/vulyk-version" 2>/dev/null || echo none)"
echo "VULYK update"
echo "  project    $DEST"
echo "  installed  v$INSTALLED"
echo "  origin     $REPO"

# The cache is a plain clone. Refreshing it is a fetch, not a re-clone, so an upgrade on a
# slow link costs one delta.
if [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch --tags --quiet origin
else
  mkdir -p "$(dirname "$SRC")"
  git clone --quiet "https://github.com/$REPO.git" "$SRC"
  git -C "$SRC" fetch --tags --quiet origin
fi

if [ -n "$WANT" ]; then
  TAG="v${WANT#v}"
else
  TAG="$(git -C "$SRC" tag --list 'v*' | sed 's/^v//' | sort -V | tail -1)"
  [ -n "$TAG" ] || { echo "error: $REPO publishes no version tags"; exit 1; }
  TAG="v$TAG"
fi
git -C "$SRC" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
  || { echo "error: $REPO has no tag $TAG"; exit 1; }

git -C "$SRC" -c advice.detachedHead=false checkout --quiet "$TAG"
echo "  upgrading to ${TAG}"
echo ""

[ -x "$SRC/install.sh" ] || chmod +x "$SRC/install.sh" 2>/dev/null || true
if [ -n "$CHECK" ]; then
  echo "DRY RUN - nothing is written."
  echo ""
fi
TELARGS=()
if [ -n "$TEL" ]; then TELARGS=(--telemetry "$TEL"); fi
if [ -n "$CONST" ]; then
  # A release older than 0.18.0 has no replace; say so instead of letting its installer
  # reject the flag after the fetch.
  grep -q -- '--constitution' "$SRC/install.sh" 2>/dev/null \
    || { echo "error: $TAG's installer has no --constitution replace (it arrived in v0.18.0)"; exit 1; }
  TELARGS+=(--constitution "$CONST")
fi
"$SRC/install.sh" "$DEST" --upgrade $CHECK ${TELARGS[@]+"${TELARGS[@]}"}

echo ""
if [ -n "$CHECK" ]; then
  echo "Dry run done. Re-run without --check to apply."
else
  # The hook caches the newest tag it saw; a stale cache would keep announcing an upgrade
  # that already happened.
  rm -f "$DEST/.claude/.vulyk-update-cache" 2>/dev/null || true
  if [ -n "$CONST" ]; then
    echo "Upgraded to ${TAG}, constitution included - the old one is kept beside it (see above)."
  else
    echo "Upgraded to ${TAG}. The installer never overwrites your constitution on its own; if it"
    echo "changed this release, the installer's note above gives the size and the migrate command."
  fi
  echo "See the CHANGELOG: https://github.com/$REPO/blob/$TAG/CHANGELOG.md"
fi
