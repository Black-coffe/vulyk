#!/usr/bin/env bash
# The check of card upgrade-overwrites-host-edits (contracts U1, audit-fixes-1113, and B1, tails-1115): does an
# installer replace a hive file that is not the copy the hive's installed release, or its stamped commit, shipped?
#
#   Usage: bash scripts/upgrade-base-check.sh <installer>
#
# It builds a throwaway source: the installer under test as install.sh, beside this checkout's VERSION, CLAUDE.md,
# AGENTS.md and scripts/lib.sh, with tags v0.1.0, v0.2.0, v0.3.0, an unmerged branch `side` and an untagged commit C
# (VERSION 0.2.5) between v0.2.0 and v0.3.0. Two hives are upgraded with `install.sh <hive> --upgrade --telemetry off`.
# Hive 1 is tag v0.2.0's tree with .claude/vulyk-version 0.2.0 (the base is that tag):
#   - u1-old.md holds the v0.1.0 text (an owner who went back to an older release's line): it must keep that line;
#   - u1-branch.md holds a blob only the side branch has: it must keep that line;
#   - u1-copy.md equals the v0.2.0 blob: it must become the v0.3.0 text (proof the installer ran at all).
# Hive 2 is C's tree with .claude/vulyk-version 0.2.5, which has no tag, and C stamped in .claude/vulyk-commit (the
# base is C):
#   - u2-old.md holds the v0.2.0 text, which C changed: it must keep that line (a tag below C is no base);
#   - u2-copy.md equals C's blob: it must become the v0.3.0 text (the stamped commit is the base).
# Exit 1 with one line per broken rule; 0 when U1 and B1 hold, or when the file is no installer (no `OWNED=` line:
# defects-check.sh runs a block check on any argument, a command page included); 2 with no argument or a path that
# is not a readable regular file, or when the throwaway source cannot be built.
set -u
[ $# -ge 1 ] && [ -n "$1" ] || { echo "usage: bash scripts/upgrade-base-check.sh <installer>" >&2; exit 2; }
[ -f "$1" ] && [ -r "$1" ] || { echo "upgrade-base-check: no such file: $1" >&2; exit 2; }
grep -q '^OWNED=' "$1" || { echo "upgrade-base-check: $1 is no installer (no OWNED= line) - nothing to judge"; exit 0; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
W="$(mktemp -d)" || { echo "upgrade-base-check: mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$W"' EXIT
S="$W/src"; H="$W/hive"; H2="$W/hive2"; A=".claude/agents"
mkdir -p "$S/scripts" "$S/$A" "$H" "$H2"
cp "$1" "$S/install.sh" && cp "$ROOT/scripts/lib.sh" "$S/scripts/" && cp "$ROOT/CLAUDE.md" "$ROOT/AGENTS.md" "$S/" \
  || { echo "upgrade-base-check: could not build the source from $ROOT" >&2; exit 2; }
body() { printf 'line 1\nline 2\n%s\nline 4\nline 5\nline 6\nline 7\nline 8\nline 9\nline 10\nline 11\n%s\n' "$1" "$2"; }
g() { git -C "$S" -c user.name=check -c user.email=check@localhost -c core.autocrlf=false "$@"; }
u2() { # u2 <u2-old line 3> <u2-old tail> <u2-copy tail>
  body "$1" "$2" > "$S/$A/u2-old.md"; body 'model: haiku' "$3" > "$S/$A/u2-copy.md"
}
release() { # release <version> <u1-old line 3> <tail>
  body "$2" "$3" > "$S/$A/u1-old.md"; body 'model: haiku' "$3" > "$S/$A/u1-copy.md"; body 'model: haiku' "$3" > "$S/$A/u1-branch.md"
  printf '%s\n' "$1" > "$S/VERSION"
  g add -A >/dev/null 2>&1 && g commit -qm "v$1" && g tag "v$1"
}
{ g init -q && g checkout -q -b main \
  && u2 'model: sonnet' 'tail one' 'tail one' && release 0.1.0 'model: sonnet' 'tail one' \
  && release 0.2.0 'model: haiku' 'tail one' \
  && g archive v0.2.0 | tar -xf - -C "$H" \
  && g checkout -q -b side && body 'model: opus' 'tail one' > "$S/$A/u1-branch.md" && g commit -qam side \
  && cp "$S/$A/u1-branch.md" "$H/$A/u1-branch.md" && g checkout -q main \
  && u2 'model: haiku' 'tail one' 'tail two' && printf '0.2.5\n' > "$S/VERSION" && g commit -qam c \
  && C="$(g rev-parse HEAD)" && g archive "$C" | tar -xf - -C "$H2" \
  && u2 'model: haiku' 'tail three' 'tail three' && release 0.3.0 'model: haiku' 'tail three'; } >/dev/null 2>&1 \
  || { echo "upgrade-base-check: could not build the throwaway source with git" >&2; exit 2; }
mkdir -p "$H/.claude" "$H2/.claude" && printf '0.2.0\n' > "$H/.claude/vulyk-version"
printf '0.2.5\n' > "$H2/.claude/vulyk-version" && printf '%s\n' "$C" > "$H2/.claude/vulyk-commit"
body 'model: sonnet' 'tail one' > "$H/$A/u1-old.md"
body 'model: sonnet' 'tail one' > "$H2/$A/u2-old.md"
VULYK_CLAUDE="$W/no-claude" bash "$S/install.sh" "$H" --upgrade --telemetry off > "$W/upgrade.out" 2>&1 < /dev/null
VULYK_CLAUDE="$W/no-claude" bash "$S/install.sh" "$H2" --upgrade --telemetry off > "$W/upgrade2.out" 2>&1 < /dev/null
line() { tr -d '\r' < "$1/$A/$2" 2>/dev/null | sed -n "$3p"; }
bad=0
[ "$(line "$H" u1-old.md 3)" = 'model: sonnet' ] || { bad=1
  echo "upgrade-base-check: $1 replaced an edit equal to an older release (v0.1.0) - the base must be the installed tag v0.2.0"; }
[ "$(line "$H" u1-branch.md 3)" = 'model: opus' ] || { bad=1
  echo "upgrade-base-check: $1 replaced a file equal to a blob only an unmerged branch holds - only tag v0.2.0's blob is a release copy"; }
[ "$(line "$H" u1-copy.md 12)" = 'tail three' ] || { bad=1
  echo "upgrade-base-check: $1 did not replace a file equal to tag v0.2.0's blob - did it run? $(tail -n 1 "$W/upgrade.out")"; }
[ "$(line "$H2" u2-old.md 3)" = 'model: sonnet' ] || { bad=1
  echo "upgrade-base-check: $1 replaced an edit equal to tag v0.2.0's blob in a hive stamped at an untagged commit - the base must be that commit"; }
[ "$(line "$H2" u2-copy.md 12)" = 'tail three' ] || { bad=1
  echo "upgrade-base-check: $1 did not replace a file equal to the stamped commit's blob (no v0.2.5 tag) - the base must be .claude/vulyk-commit"; }
exit "$bad"
