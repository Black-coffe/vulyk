#!/usr/bin/env bash
# VULYK version order - sourced, never run. The one comparison the update-check hook and
# scripts/vulyk-update.sh share (docs/specs/audit-fixes-1113/plan.md ## Contracts V1).
#
#   version_newer <a> <b>   exit 0 when <a> is strictly newer than <b>, else 1
#   version_newest          print the newest of the versions on stdin (one per line, as given); nothing for none
#
# A leading `v` is dropped; X, Y and Z compare as numbers (0.10.0 after 0.9.0); a release X.Y.Z is newer than
# every X.Y.Z-<pre>; two pre-releases of one X.Y.Z compare by the number after their last dot (dev.10 after
# dev.3). A field that is not a number counts as 0. No `sort -V` (stock macOS sort has none), no bash 4,
# no subshell per comparison: the hook runs this over a hundred tags at session start.

# _vo_n <field> -> _VO_N, the field as a number (0 when it is not one)
_vo_n() { case "$1" in ''|*[!0-9]*) _VO_N=0 ;; *) _VO_N=$((10#$1)) ;; esac; }

# _vo_key <version> -> _VO_K, "X Y Z R N": R is 1 for a release and 0 for a pre-release, N the pre-release number
_vo_key() {
  local v="${1#v}" core pre="" x y z p r=1 k=""
  v="${v%%[[:space:]]*}"
  core="${v%%-*}"
  if [ "$core" != "$v" ]; then pre="${v#*-}"; r=0; fi
  x="${core%%.*}"; core="${core#"$x"}"; core="${core#.}"
  y="${core%%.*}"; core="${core#"$y"}"; core="${core#.}"
  z="${core%%.*}"
  for p in "$x" "$y" "$z"; do _vo_n "$p"; k="$k $_VO_N"; done
  _vo_n "${pre##*.}"
  _VO_K="$k $r $_VO_N"
}

version_newer() {
  local ka kb i
  _vo_key "$1"; ka=($_VO_K)
  _vo_key "$2"; kb=($_VO_K)
  for i in 0 1 2 3 4; do
    if [ "${ka[$i]}" -gt "${kb[$i]}" ]; then return 0; fi
    if [ "${ka[$i]}" -lt "${kb[$i]}" ]; then return 1; fi
  done
  return 1
}

version_newest() {
  local line best=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [ -n "$line" ] || continue
    if [ -z "$best" ] || version_newer "$line" "$best"; then best="$line"; fi
  done
  if [ -n "$best" ]; then printf '%s\n' "$best"; fi
  return 0
}
