#!/usr/bin/env bash
# VULYK tag push check - a push that carries a local dev-build tag, or more than one version tag, is refused.
#
#   Usage: <git pre-push lines> | bash scripts/tag-push-check.sh
#          (scripts/git-hooks/pre-push passes git's stdin here; /vulyk-ship step 2a copies that hook in place)
#
# Reads git's pre-push lines on stdin: `<local ref> <local sha> <remote ref> <remote sha>`. Refused (exit 1, one
# reason line per cause on stderr): a pushed `refs/tags/` ref holding `-dev.` (a `X.Y.Z-dev.N` build never leaves
# this machine), or more than one `refs/tags/v*` ref in one push (one publish, one tag pushed by name). A deletion
# (local sha all zeros) passes, so a leaked dev tag stays removable; a branch ref passes; empty input passes.
# Card public-release-per-change. Switched off by `git push --no-verify` or a clone without the hook.
set -u

refused=0; vtags=0; vlist=""
while read -r lref lsha rref _rsha || [ -n "${lref:-}" ]; do
  lref="${lref%$'\r'}"; lsha="${lsha:-}"; rref="${rref:-}"
  [ -n "$lref" ] || continue
  case "$lsha" in *[!0]*) ;; *) continue ;; esac   # a deletion: nothing is pushed
  dev=""
  for r in "$rref" "$lref"; do
    case "$r" in refs/tags/*-dev.*) dev="$r"; break ;; esac
  done
  if [ -n "$dev" ]; then
    echo "tag-push-check: refused - $dev is a local dev-build tag (-dev.N); it never leaves this machine (card public-release-per-change)" >&2
    refused=1
  fi
  case "$rref" in refs/tags/v*) vtags=$((vtags + 1)); vlist="$vlist${vlist:+, }$rref" ;; esac
done
if [ "$vtags" -gt 1 ]; then
  echo "tag-push-check: refused - $vtags version tags in one push ($vlist); push exactly one tag, by name (card public-release-per-change)" >&2
  refused=1
fi
exit "$refused"
