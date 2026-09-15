#!/usr/bin/env bash
# VULYK anomaly telemetry - one script owns the whole path.
#
#   bash scripts/telemetry.sh enum|agents|consent
#   bash scripts/telemetry.sh record <code> <value> <threshold> [--spec s] [--story id]
#                                    [--ref r] [--model alias] [--tier n] [--agent token]
#   bash scripts/telemetry.sh scan [--transcript <path>]      # story 02
#   bash scripts/telemetry.sh bundle [--week YYYY-Www] [--out <file>]
#   bash scripts/telemetry.sh check <file>...
#   bash scripts/telemetry.sh publish [--week YYYY-Www] [--dry-run]
#   bash scripts/telemetry.sh inbox [--clear]                 # VULYK repo only
#
# `bundle` and `publish` with no --week cover the PREVIOUS ISO week and the current one
# (plan A15), so a weekly run never silently drops the week it is reporting on.
#
# Two schemas (docs/specs/anomaly-telemetry/plan.md ## Contracts): the LOCAL row, 12 keys,
# appended to memory/stats/anomalies.jsonl (committed paperwork, like the five stats files
# beside it); and the BUNDLE row, 10 keys, codes and numbers only - no ts, spec, story or ref,
# and no string that can carry a path, a slug or an address. `check` is the gate that keeps
# that promise, and it runs on the bundle before anything is copied anywhere.
#
# This script never sends: `publish` copies at most into a local checkout and PRINTS the
# command a human runs (.claude/commands/vulyk-ship.md:11). No `git push`, `git commit` or
# `gh` call exists anywhere below - by design, not by flag.
set -u

. "$(dirname "$0")/lib.sh"

ROOT="${VULYK_HIVE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG="$ROOT/memory/stats/anomalies.jsonl"

# --- fixed sets ------------------------------------------------------------------------------

# The v1 enum. Fixed: a code is a public contract - bundles from hives on older versions must
# still validate here, so codes are added, never renamed or removed.
ENUM="context_high
agent_prefix_high
agent_empty
council_rounds_high
stage_long
driver_refused
driver_relaunched
scope_breach"

MODELS="fable
opus
sonnet
haiku"

# The agent token set is resolved at runtime from the hive's own .claude/agents/ (plan A12):
# a hive that adds an agent gets it in its rows without a code change, and `check` in the
# VULYK repo resolves it from the repo's own agents. `other` absorbs everything else, so a
# dispatch name (owner-chosen text - it can carry a story name) never reaches a row.
agent_set() {
  local f
  for f in "$ROOT"/.claude/agents/*.md; do
    [ -f "$f" ] || continue
    basename "$f" .md
  done
  echo other
}

die() { printf 'telemetry: %s\n' "$1" >&2; exit "${2:-1}"; }

in_set() { # in_set <needle> <newline-separated set>
  printf '%s\n' "$2" | grep -qxF -- "$1"
}

json_array() { jq -Rsc 'split("\n") | map(select(length > 0))'; }

need_jq() { command -v jq >/dev/null 2>&1 || die "jq is required for this verb"; }

# Strings that reach a local row are stripped of everything that could break the line or the
# JSON: quotes, backslashes, control characters. Bundle rows never carry free strings at all.
sanitize() { printf '%s' "${1:-}" | tr -d '"\\\r\n\t'; }

is_number() { case "${1:-}" in ''|*[!0-9.-]*) return 1 ;; *) return 0 ;; esac; }

now_week() { date -u +%G-W%V; }

prev_week() { # the ISO week seven days back (GNU date, then BSD date; empty when neither works)
  local w=""
  w="$(date -u -d '7 days ago' +%G-W%V 2>/dev/null || true)"
  [ -n "$w" ] || w="$(date -u -v-7d +%G-W%V 2>/dev/null || true)"
  printf '%s' "$w"
}

# Plan A15: a weekly run must not drop the week it reports on. With no --week, `bundle` and
# `publish` cover the PREVIOUS ISO week and the current one, so a Monday run still carries
# last week's rows. A default, not a ledger: nothing on disk records what was published.
default_weeks() {
  local cur prev
  cur="$(now_week)"; prev="$(prev_week)"
  [ -n "$prev" ] && [ "$prev" != "$cur" ] && printf '%s\n' "$prev"
  printf '%s\n' "$cur"
}

# Every path that reaches a printed recipe goes through this: the recipe is pasted into a
# shell, and a bundle or checkout path can hold a space, a `#` or an `&` (review finding 14).
shq() { local s="${1:-}" q="'" r="'\''"; printf "'%s'" "${s//$q/$r}"; }

week_of() { # week_of <UTC ISO-8601 ts> -> YYYY-Www  (empty when the ts is unparseable)
  local ts="${1:-}" w=""
  [ -n "$ts" ] || return 0
  w="$(date -u -d "$ts" +%G-W%V 2>/dev/null || true)"
  [ -n "$w" ] || w="$(date -u -jf '%Y-%m-%dT%H:%M:%SZ' "$ts" +%G-W%V 2>/dev/null || true)"
  printf '%s' "$w"
}

# Plan A4: the hash input is `git rev-parse --show-toplevel` as printed. It only has to be
# stable per machine, never portable or reversible - 12 hex, the shape pack_fingerprint uses.
hive_id() {
  local top hasher=""
  top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || top="$ROOT"
  if command -v sha256sum >/dev/null 2>&1; then hasher="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then hasher="shasum -a 256"; fi
  if [ -n "$hasher" ]; then
    printf '%s' "$top" | $hasher | cut -c1-12
  else
    printf '%012x' "$(printf '%s' "$top" | cksum | cut -d' ' -f1)"
  fi
}

# Plan A3: install.sh writes .claude/vulyk-version; VULYK's own tree may not have it, and
# 0.0.0 is an honest answer for a dogfooding row.
vulyk_version() {
  local v=""
  [ -f "$ROOT/.claude/vulyk-version" ] && v="$(tr -d ' \r\n' < "$ROOT/.claude/vulyk-version")"
  case "$v" in
    [0-9]*.[0-9]*.[0-9]*) printf '%s' "$v" ;;
    *) printf '0.0.0' ;;
  esac
}

# --- verbs -----------------------------------------------------------------------------------

cmd_enum() { printf '%s\n' "$ENUM"; }

cmd_agents() { agent_set; }

# The consent row is `| Telemetry | on ... |` in the root CLAUDE.md Profile table (story 05
# installs it). Only the value cell's FIRST token is read, backticks tolerated; anything that
# is not exactly `on` - including a missing row - is `off`.
cmd_consent() {
  local row value=""
  row="$(grep -m1 '^|[[:space:]]*Telemetry[[:space:]]*|' "$ROOT/CLAUDE.md" 2>/dev/null || true)"
  if [ -n "$row" ]; then
    value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | tr -d '`' | awk '{print $1}')"
  fi
  case "$value" in on) echo on ;; *) echo off ;; esac
}

cmd_record() {
  local code value threshold spec="" story="" ref="" model="" tier="0" agent=""
  [ $# -ge 3 ] || die "record <code> <value> <threshold> [--spec s] [--story id] [--ref r] [--model m] [--tier n] [--agent a]"
  code="$1"; value="$2"; threshold="$3"; shift 3
  while [ $# -gt 0 ]; do
    case "$1" in
      --spec)  spec="${2:-}";  shift 2 ;;
      --story) story="${2:-}"; shift 2 ;;
      --ref)   ref="${2:-}";   shift 2 ;;
      --model) model="${2:-}"; shift 2 ;;
      --tier)  tier="${2:-}";  shift 2 ;;
      --agent) agent="${2:-}"; shift 2 ;;
      *) die "record: unknown option '$1'" ;;
    esac
  done

  in_set "$code" "$ENUM" || die "record: unknown code '$code' (see: telemetry.sh enum)"
  is_number "$value"     || die "record: value '$value' is not a number"
  is_number "$threshold" || die "record: threshold '$threshold' is not a number"
  case "$tier" in 0|1|2|3|4) ;; *) tier=0 ;; esac
  in_set "$model" "$MODELS" || model=""
  if [ -n "$agent" ] && ! in_set "$agent" "$(agent_set)"; then agent="other"; fi

  spec="$(sanitize "$spec")"; story="$(sanitize "$story")"; ref="$(sanitize "$ref")"

  # Idempotency (contract): a non-empty ref is the dedupe key, paired with the code. A detector
  # that re-runs over the same transcript on every Stop hook must not grow the log.
  if [ -n "$ref" ] && [ -f "$LOG" ]; then
    if grep -F "\"code\":\"$code\"" "$LOG" 2>/dev/null | grep -qF "\"ref\":\"$ref\""; then
      return 0
    fi
  fi

  mkdir -p "$ROOT/memory/stats"
  printf '{"v":1,"ts":"%s","code":"%s","value":%s,"threshold":%s,"vulyk":"%s","tier":%s,"model":"%s","agent":"%s","spec":"%s","story":"%s","ref":"%s"}\n' \
    "$(now_ts)" "$code" "$value" "$threshold" "$(vulyk_version)" "$tier" "$model" "$agent" \
    "$spec" "$story" "$ref" >> "$LOG"
}

# --- scan: the five detectors -----------------------------------------------------------------
# Thresholds (plan A2), one env var each, defaults baked in and echoed into every row so
# /vulyk-evolve can recalibrate from data later.
VULYK_ANOMALY_CONTEXT_PCT="${VULYK_ANOMALY_CONTEXT_PCT:-70}"
VULYK_ANOMALY_CONTEXT_TOKENS="${VULYK_ANOMALY_CONTEXT_TOKENS:-140000}"
VULYK_ANOMALY_AGENT_PREFIX_TOKENS="${VULYK_ANOMALY_AGENT_PREFIX_TOKENS:-50000}"
VULYK_ANOMALY_COUNCIL_ROUNDS="${VULYK_ANOMALY_COUNCIL_ROUNDS:-3}"
VULYK_ANOMALY_STAGE_HOURS="${VULYK_ANOMALY_STAGE_HOURS:-24}"

# handoff.py's own fail-open wrapper: whatever python3/python/py is on PATH, exits 0 with
# nothing on stdout when none is found. Reused rather than re-resolving the interpreter here.
measure() { # measure <transcript> [--sidechain]
  [ -f "$ROOT/.claude/hooks/handoff.sh" ] || return 0
  bash "$ROOT/.claude/hooks/handoff.sh" measure "$@" < /dev/null 2>/dev/null
}

# claude-fable-5-1 -> fable, claude-opus-... -> opus, etc. Anything else (or empty) -> "".
# cmd_record re-validates against MODELS anyway; this just gives it a token worth keeping.
model_alias() {
  case "${1:-}" in
    *fable*)  echo fable ;;
    *opus*)   echo opus ;;
    *sonnet*) echo sonnet ;;
    *haiku*)  echo haiku ;;
    *) echo "" ;;
  esac
}

epoch_of() { # epoch_of <UTC ISO-8601 ts> -> unix seconds, empty when unparseable
  local ts="${1:-}" e=""
  [ -n "$ts" ] || return 0
  e="$(date -u -d "$ts" +%s 2>/dev/null || true)"
  [ -n "$e" ] || e="$(date -u -jf '%Y-%m-%dT%H:%M:%SZ' "$ts" +%s 2>/dev/null || true)"
  printf '%s' "$e"
}

# context_high: the main-thread transcript's current context size (handoff.py's own
# context_tokens()) against a threshold that is percent-of-window when a window has actually
# been observed for this session (handoff's own state file), else the absolute fallback.
detect_context() { # detect_context <main transcript>
  local transcript="${1:-}" session_id measured tokens model window threshold state_file malias
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  measured="$(measure "$transcript")"
  [ -n "$measured" ] || return 0
  tokens="$(printf '%s' "$measured" | jq -r '.tokens // 0' 2>/dev/null)"
  model="$(printf '%s' "$measured" | jq -r '.model // ""' 2>/dev/null)"
  is_number "$tokens" || return 0
  [ "$tokens" != "0" ] || return 0

  session_id="$(basename "$transcript" .jsonl)"
  state_file="$ROOT/.claude/handoff/state/$session_id.json"
  window=""
  [ -f "$state_file" ] && window="$(jq -r '.window // empty' "$state_file" 2>/dev/null)"
  if [ -n "$window" ] && is_number "$window" && [ "$window" != "0" ]; then
    threshold=$(( window * VULYK_ANOMALY_CONTEXT_PCT / 100 ))
  else
    threshold="$VULYK_ANOMALY_CONTEXT_TOKENS"
  fi

  if [ "$tokens" -gt "$threshold" ] 2>/dev/null; then
    malias="$(model_alias "$model")"
    cmd_record context_high "$tokens" "$threshold" --model "$malias" \
      --ref "session:$(basename "$transcript")"
  fi
}

# agent_prefix_high / agent_empty: every subagent file under <session dir>/subagents/
# (plain dispatches and workflow ones alike - recon/hooks-and-stats.md §6).
detect_agents() { # detect_agents <session dir>
  local session_dir="${1:-}" f measured first_prefix turns last_has_text agent_type base ref
  [ -n "$session_dir" ] && [ -d "$session_dir/subagents" ] || return 0
  find "$session_dir/subagents" -type f -name '*.jsonl' 2>/dev/null | sort | \
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    measured="$(measure "$f" --sidechain)"
    [ -n "$measured" ] || continue
    first_prefix="$(printf '%s' "$measured" | jq -r '.first_prefix // 0' 2>/dev/null)"
    turns="$(printf '%s' "$measured" | jq -r '.assistant_turns // 0' 2>/dev/null)"
    last_has_text="$(printf '%s' "$measured" | jq -r '.last_has_text // false' 2>/dev/null)"
    agent_type="$(printf '%s' "$measured" | jq -r '.agent_type // ""' 2>/dev/null)"
    base="$(basename "$f")"
    ref="agent:$base"

    if is_number "$first_prefix" && [ "$first_prefix" -gt "$VULYK_ANOMALY_AGENT_PREFIX_TOKENS" ] 2>/dev/null; then
      cmd_record agent_prefix_high "$first_prefix" "$VULYK_ANOMALY_AGENT_PREFIX_TOKENS" \
        --ref "$ref" --agent "$agent_type"
    fi
    if is_number "$turns" && [ "$turns" != "0" ] && [ "$last_has_text" = "false" ]; then
      cmd_record agent_empty "$turns" 0 --ref "$ref" --agent "$agent_type"
    fi
  done
}

# spec_tier <slug> -> the number on that spec's plan.md "**Tier:**" line, else empty
# (cmd_record maps anything outside 0-4 to 0).
spec_tier() {
  local spec="${1:-}" f line
  f="$ROOT/docs/specs/$spec/plan.md"
  [ -f "$f" ] || return 0
  line="$(grep -m1 '\*\*Tier:\*\*' "$f" 2>/dev/null || true)"
  printf '%s' "$line" | sed -n 's/.*\*\*Tier:\*\*[[:space:]]*\([0-9]\).*/\1/p' | head -1
}

# council_rounds_high: the max round per spec in council.jsonl, at or above threshold.
detect_council() {
  local log="$ROOT/memory/stats/council.jsonl"
  [ -f "$log" ] || return 0
  jq -r 'select(type == "object") | [(.spec // ""), (.round // 0)] | @tsv' "$log" 2>/dev/null | \
  tr -d '\r' | \
  awk -F'\t' '$1 != "" { r = $2 + 0; if (!($1 in m) || r > m[$1]) m[$1] = r } END { for (s in m) print s "\t" m[s] }' | \
  while IFS="$(printf '\t')" read -r spec round; do
    [ -n "$spec" ] || continue
    is_number "$round" || continue
    if [ "$round" -ge "$VULYK_ANOMALY_COUNCIL_ROUNDS" ] 2>/dev/null; then
      cmd_record council_rounds_high "$round" "$VULYK_ANOMALY_COUNCIL_ROUNDS" \
        --spec "$spec" --tier "$(spec_tier "$spec")" --ref "council:$spec"
    fi
  done
}

# stage_long: the gap between two CONSECUTIVE journal.md lines, per spec. Plan A9: the still-
# open last stage (last line to now) is never measured - it would re-fire on every scan.
detect_stage() {
  local f spec prev_epoch=""  line_no cur_epoch gap
  for f in "$ROOT"/docs/specs/*/journal.md; do
    [ -f "$f" ] || continue
    spec="$(basename "$(dirname "$f")")"
    prev_epoch=""; line_no=0
    while IFS= read -r ts; do
      line_no=$((line_no + 1))
      [ -n "$ts" ] || continue
      cur_epoch="$(epoch_of "$ts")"
      [ -n "$cur_epoch" ] || continue
      if [ -n "$prev_epoch" ]; then
        gap=$(( (cur_epoch - prev_epoch) / 3600 ))
        if [ "$gap" -ge "$VULYK_ANOMALY_STAGE_HOURS" ]; then
          cmd_record stage_long "$gap" "$VULYK_ANOMALY_STAGE_HOURS" \
            --spec "$spec" --ref "stage:$spec:$line_no"
        fi
      fi
      prev_epoch="$cur_epoch"
    done < <(sed -n 's/^-[[:space:]]*\([^ ]*\)[[:space:]]·.*/\1/p' "$f")
  done
}

# scope_breach: any scope.jsonl row whose out_of_scope is non-zero (the count out-of-scope
# gate already writes; a bare [] or 0 is treated the same as "nothing to report").
detect_scope() {
  local log="$ROOT/memory/stats/scope.jsonl"
  [ -f "$log" ] || return 0
  jq -c 'select(type == "object")' "$log" 2>/dev/null | \
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    local ts story value
    ts="$(printf '%s' "$row" | jq -r '.ts // ""' 2>/dev/null)"
    story="$(printf '%s' "$row" | jq -r '.story // ""' 2>/dev/null)"
    value="$(printf '%s' "$row" | jq -r \
      '(.out_of_scope) as $o
       | if ($o | type) == "array" then ($o | length)
         elif ($o | type) == "number" then $o
         else 0 end' 2>/dev/null)"
    is_number "$value" || continue
    [ "$value" != "0" ] || continue
    [ -n "$ts" ] || continue
    cmd_record scope_breach "$value" 0 --story "$story" --ref "scope:$ts:$story"
  done
}

cmd_scan() {
  local transcript=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --transcript) transcript="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ "${VULYK_TELEMETRY_SCAN:-1}" = "0" ] && return 0
  command -v jq >/dev/null 2>&1 || return 0

  detect_context "$transcript"
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    detect_agents "$(dirname "$transcript")"
  fi
  detect_council
  detect_stage
  detect_scope
  return 0
}

# One week of local rows -> bundle rows. Everything that could identify a hive's work is
# dropped here rather than filtered later: ts, spec, story and ref never leave this function.
bundle_emit() { # bundle_emit <week> <hive> <agent-set>
  local week="$1" hive="$2" agents="$3"
  local ts code value threshold vulyk tier model agent rowweek vsan
  [ -f "$LOG" ] || return 0
  # `tr -d '\r'` below is load-bearing on Windows: jq there ends every output line with CRLF,
  # and the CR would ride into the last @tsv field (agent) and push every token out of its set.
  jq -r 'select(type == "object")
         | [ (.ts // ""), (.code // ""), (.value // ""), (.threshold // ""),
             (.vulyk // ""), (.tier // 0), (.model // ""), (.agent // "") ]
         | @tsv' "$LOG" 2>/dev/null | tr -d '\r' |
  while IFS="$(printf '\t')" read -r ts code value threshold vulyk tier model agent; do
    rowweek="$(week_of "$ts")"
    [ "$rowweek" = "$week" ] || continue
    in_set "$code" "$ENUM" || continue
    is_number "$value" || continue
    is_number "$threshold" || continue
    case "$tier" in 0|1|2|3|4) ;; *) tier=0 ;; esac
    in_set "$model" "$MODELS" || model=""
    if [ -n "$agent" ] && ! in_set "$agent" "$agents"; then agent="other"; fi
    case "$vulyk" in [0-9]*.[0-9]*.[0-9]*) vsan="$vulyk" ;; *) vsan="0.0.0" ;; esac
    printf '{"v":1,"code":"%s","value":%s,"threshold":%s,"vulyk":"%s","tier":%s,"model":"%s","agent":"%s","week":"%s","hive":"%s"}\n' \
      "$code" "$value" "$threshold" "$vsan" "$tier" "$model" "$agent" "$week" "$hive"
  done
}

cmd_bundle() {
  local week="" out="" weeks w hive agents
  while [ $# -gt 0 ]; do
    case "$1" in
      --week) week="${2:-}"; shift 2 ;;
      --out)  out="${2:-}";  shift 2 ;;
      *) die "bundle: unknown option '$1'" ;;
    esac
  done
  need_jq
  # --week selects exactly one week; without it, the previous ISO week and the current one.
  if [ -n "$week" ]; then weeks="$week"; else weeks="$(default_weeks)"; fi
  hive="$(hive_id)"; agents="$(agent_set)"
  if [ -n "$out" ]; then
    mkdir -p "$(dirname "$out")"
    : > "$out"
  fi
  for w in $weeks; do
    if [ -n "$out" ]; then bundle_emit "$w" "$hive" "$agents" >> "$out"
    else bundle_emit "$w" "$hive" "$agents"; fi
  done
  return 0
}

# The schema gate. Anything it rejects is a bundle that must not travel: a key set other than
# the ten, a code or token outside its set, or any string carrying a path, an address or
# whitespace - the last one is the anonymization guard, not a formatting nicety.
CHECK_JQ='
  (sub("\r$"; "")) as $line
  | input_line_number as $n
  | if ($line | test("^[[:space:]]*$")) then empty
    else
      ((try ($line | fromjson) catch null) as $o
       | (if   $o == null                  then "not valid JSON"
          elif ($o | type) != "object"     then "not a JSON object"
          elif (($o | keys) != ($keys | sort)) then "key set is not the 10 bundle keys"
          elif ($o.v != 1)                 then "v is not 1"
          elif (($codes | index($o.code)) == null) then "code is not in the enum"
          elif (($o.value | type) != "number") then "value is not a number"
          elif (($o.threshold | type) != "number") then "threshold is not a number"
          elif (($o.tier | type) != "number" or $o.tier < 0 or $o.tier > 4) then "tier is outside 0-4"
          elif (($models | index($o.model)) == null) then "model is not in the model set"
          elif (($agents | index($o.agent)) == null) then "agent is not in the agent token set"
          elif (($o.week | type) != "string" or ($o.week | test("^[0-9]{4}-W[0-9]{2}$") | not)) then "week is not YYYY-Www"
          elif (($o.hive | type) != "string" or ($o.hive | test("^[0-9a-f]{12}$") | not)) then "hive is not 12 hex"
          elif (($o.vulyk | type) != "string" or ($o.vulyk | test("^[0-9]+[.][0-9]+[.][0-9]+") | not)) then "vulyk is not a semver"
          elif ([$o | to_entries[] | select(.value | type == "string") | .value]
                | map(test("[/\\\\@]") or test("[[:space:]]")) | any) then "a string value carries a path, an address or whitespace"
          else "" end) as $r
       | if $r == "" then empty else "\($n): \($r)" end)
    end
'

cmd_check() {
  local f rc=0 out codes models agents keys
  [ $# -ge 1 ] || die "check <file>..."
  need_jq
  codes="$(printf '%s\n' "$ENUM" | json_array)"
  # "" is a member of both the model set and the agent token set: rows that are not about a
  # model or an agent carry it.
  models="$(printf '%s\n' "$MODELS" | json_array | jq -c '. + [""]')"
  agents="$(agent_set | json_array | jq -c '. + [""]')"
  keys='["v","code","value","threshold","vulyk","tier","model","agent","week","hive"]'
  for f in "$@"; do
    if [ ! -f "$f" ]; then printf '%s: no such file\n' "$f" >&2; rc=1; continue; fi
    if ! out="$(jq -R -r --argjson codes "$codes" --argjson models "$models" \
                  --argjson agents "$agents" --argjson keys "$keys" "$CHECK_JQ" "$f")"; then
      printf '%s: unreadable\n' "$f" >&2; rc=1; continue
    fi
    if [ -n "$out" ]; then
      # Not `sed "s#^#$f:#"`: a `#` in the path closes sed's own delimiter (finding 14).
      printf '%s\n' "$out" | while IFS= read -r line; do printf '%s:%s\n' "$f" "$line"; done >&2
      rc=1
    fi
  done
  return $rc
}

# Plan A1. Order: VULYK_LOCAL (explicit, must be a git worktree with telemetry/inbox/), else
# this hive when its origin URL carries the origin slug. ~/.vulyk/src is deliberately NOT a
# target: it is vulyk-update.sh's pull-only cache, usually detached at a tag.
# The public repo both recipes point at: VULYK_REPO, else .claude/vulyk-origin, else default.
origin_slug() {
  local slug="${VULYK_REPO:-}"
  if [ -z "$slug" ] && [ -f "$ROOT/.claude/vulyk-origin" ]; then
    slug="$(tr -d ' \r\n' < "$ROOT/.claude/vulyk-origin")"
  fi
  [ -n "$slug" ] || slug="Black-coffe/vulyk"
  printf '%s' "$slug"
}

local_vulyk_repo() {
  local cand origin slug
  cand="${VULYK_LOCAL:-}"
  if [ -n "$cand" ] && [ -d "$cand/telemetry/inbox" ] &&
     git -C "$cand" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$cand" rev-parse --show-toplevel
    return 0
  fi
  slug="$(origin_slug)"
  origin="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  if [ -n "$origin" ] && [ -d "$ROOT/telemetry/inbox" ]; then
    case "$origin" in *"$slug"*) printf '%s' "$ROOT"; return 0 ;; esac
  fi
  return 1
}

# One week's recipe, printed - never run. Every path goes through shq() so a bundle or a
# checkout path holding a space, a `#` or an `&` survives the paste (review finding 14).
recipe_local() { # recipe_local <repo> <rel> <week>
  printf 'Run this yourself - nothing is sent for you:\n\n'
  printf '```\n'
  printf 'cd %s && git add %s && git commit -m %s && git push\n' \
    "$(shq "$1")" "$(shq "$2")" "$(shq "telemetry: $3 bundle")"
  printf '```\n'
}

# The cross-machine path (council round 1, ask 2): fork, clone, branch, copy, add, commit,
# push, open the PR. Pasted as-is it ends in an open pull request - the previous two-line
# form left the copy untracked, so `gh pr create` had nothing to open from.
# `gh repo fork --clone` is a boolean flag; the clone directory is a git-clone argument,
# which `gh repo fork` passes through after `--` (confirmed with `gh repo fork --help`).
recipe_pr() { # recipe_pr <slug> <dir> <bundle> <rel> <week> <hive> <branch>
  local slug="$1" dir="$2" bundle="$3" rel="$4" week="$5" hive="$6" branch="$7"
  printf 'No local VULYK checkout found. Run this yourself - nothing is sent for you:\n\n'
  printf '```\n'
  printf 'gh repo fork %s --clone -- %s\n' "$(shq "$slug")" "$(shq "$dir")"
  printf 'cd %s\n'                         "$(shq "$dir")"
  printf 'git switch -c %s\n'              "$(shq "$branch")"
  printf 'mkdir -p %s\n'                   "$(shq "telemetry/inbox/$week")"
  printf 'cp %s %s\n'                      "$(shq "$bundle")" "$(shq "$rel")"
  printf 'git add %s\n'                    "$(shq "$rel")"
  printf 'git commit -m %s\n'              "$(shq "telemetry($week): $hive")"
  printf 'git push -u origin %s\n'         "$(shq "$branch")"
  printf 'gh pr create --repo %s --head %s --title %s --body %s\n' \
    "$(shq "$slug")" "$(shq "$branch")" "$(shq "telemetry($week): $hive")" \
    "$(shq 'An anonymized weekly anomaly bundle - codes and numbers only.')"
  printf '```\n'
}

cmd_publish() {
  local week="" dry=0 weeks w hive agents bundle repo="" haslocal=0 sent=0 dest rel slug
  while [ $# -gt 0 ]; do
    case "$1" in
      --week)    week="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "publish: unknown option '$1'" ;;
    esac
  done
  if [ "$(cmd_consent)" != "on" ]; then
    echo "telemetry: off (Profile row Telemetry) - nothing to send"
    return 0
  fi
  need_jq
  if [ -n "$week" ]; then weeks="$week"; else weeks="$(default_weeks)"; fi
  hive="$(hive_id)"; agents="$(agent_set)"
  if repo="$(local_vulyk_repo)"; then haslocal=1; fi
  slug="$(origin_slug)"

  for w in $weeks; do
    bundle="$ROOT/.vulyk/telemetry/$w-$hive.jsonl"
    mkdir -p "$(dirname "$bundle")"
    bundle_emit "$w" "$hive" "$agents" > "$bundle"
    # A week with no rows is skipped silently: a run covering two weeks routinely has rows
    # in only one of them.
    if [ ! -s "$bundle" ]; then rm -f "$bundle"; continue; fi
    cmd_check "$bundle" || die "publish: the bundle failed check, nothing was copied"
    sent=1

    rel="telemetry/inbox/$w/$hive.jsonl"
    if [ "$haslocal" -eq 1 ]; then
      dest="$repo/$rel"
      if [ "$dry" -eq 0 ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$bundle" "$dest"
        echo "telemetry: wrote $dest"
      else
        echo "telemetry: --dry-run, would write $dest"
      fi
      recipe_local "$repo" "$rel" "$w"
    else
      recipe_pr "$slug" "vulyk-telemetry" "$bundle" "$rel" "$w" "$hive" "telemetry/$w-$hive"
    fi
  done

  if [ "$sent" -eq 0 ]; then
    echo "telemetry: no anomalies for $(printf '%s' "$weeks" | tr '\n' ' ' | sed 's/ $//') - nothing to send"
  fi
  return 0
}

# Plan A16: the repo side of the weekly promise. `/vulyk-evolve` in the VULYK repo distils the
# inbox into per-week, per-code counts for its diagnosis and its CHANGELOG entry, and `--clear`
# STAGES the emptied week directories (`git rm`) so the deletions ride in that same reviewable
# changeset. Like every other verb here it never commits and never pushes - a human does.
cmd_inbox() {
  local clear=0 dir list f rowtsv weeks w rc=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --clear) clear=1; shift ;;
      *) die "inbox: unknown option '$1'" ;;
    esac
  done
  dir="$ROOT/telemetry/inbox"
  if [ ! -d "$dir" ]; then
    echo "telemetry: no inbox at $ROOT - nothing to distil"
    return 0
  fi
  need_jq

  # `telemetry/inbox/*/*.jsonl` - one week directory deep, exactly where publish's recipes put
  # a bundle. README.md and anything else that is not a bundle is left alone.
  list="$(find "$dir" -mindepth 2 -maxdepth 2 -type f -name '*.jsonl' 2>/dev/null | sort || true)"
  # An inbox holding no bundles at all: nothing to print, and `--clear` has nothing to stage.
  [ -n "$list" ] || return 0

  # The gate first: a bundle that fails `check` is never distilled and never deleted, so a bad
  # merge is still on disk when the maintainer reads the failure.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    cmd_check "$f" || rc=1
  done <<EOF
$list
EOF
  [ "$rc" -eq 0 ] || return 1

  # `<week>\t<code>\t<rows>\t<hives>`, sorted by week then code. `week` and `hive` come from the
  # rows themselves (the schema carries both), not from the path.
  rowtsv="$(while IFS= read -r f; do
              [ -n "$f" ] || continue
              jq -r 'select(type == "object") | [(.week // ""), (.code // ""), (.hive // "")] | @tsv' \
                "$f" 2>/dev/null
            done <<EOF
$list
EOF
)"
  printf '%s\n' "$rowtsv" | tr -d '\r' |
  awk -F'\t' '
    $1 != "" && $2 != "" {
      k = $1 "\t" $2
      rows[k]++
      if (!((k "\t" $3) in seen)) { seen[k "\t" $3] = 1; hives[k]++ }
    }
    END { for (k in rows) printf "%s\t%d\t%d\n", k, rows[k], hives[k] }
  ' | LC_ALL=C sort

  [ "$clear" -eq 1 ] || return 0

  # Every week directory that held a bundle, staged as a deletion. `-q` because the table above
  # is the output of this verb; `--` because a week name is data, however well-shaped.
  weeks="$(printf '%s\n' "$list" | while IFS= read -r f; do
             [ -n "$f" ] && basename "$(dirname "$f")"; done | LC_ALL=C sort -u)"
  for w in $weeks; do
    git -C "$ROOT" rm -r -q -- "telemetry/inbox/$w" ||
      die "inbox: could not stage the deletion of telemetry/inbox/$w"
  done
  return 0
}

# --- dispatch --------------------------------------------------------------------------------

[ $# -ge 1 ] || die "usage: telemetry.sh enum|agents|consent|record|scan|bundle|check|publish|inbox"
VERB="$1"; shift
case "$VERB" in
  enum)    cmd_enum "$@" ;;
  agents)  cmd_agents "$@" ;;
  consent) cmd_consent "$@" ;;
  record)  cmd_record "$@" ;;
  scan)    cmd_scan "$@" ;;
  bundle)  cmd_bundle "$@" ;;
  check)   cmd_check "$@" ;;
  publish) cmd_publish "$@" ;;
  inbox)   cmd_inbox "$@" ;;
  *) die "unknown verb '$VERB'" ;;
esac
