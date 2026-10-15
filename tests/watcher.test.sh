#!/usr/bin/env bash
# Watcher mod checks: claude plugin validate (the mod and the root marketplace), and claude plugin test once a *.test.ts exists.
cd "$(dirname "$0")/.." || exit 2
MOD=.claude/mods/vulyk-watcher
if ! command -v claude >/dev/null 2>&1; then
  echo "watcher.test.sh: claude is not on PATH, the mod cannot be checked" >&2
  exit 2
fi
claude plugin validate "$MOD" || exit 1
claude plugin validate . >/dev/null || { claude plugin validate .; exit 1; }   # the root marketplace
if [ -n "$(find "$MOD" -name '*.test.ts' -print -quit)" ]; then
  claude plugin test "$MOD" || exit 1
fi
echo "watcher mod: ok"
