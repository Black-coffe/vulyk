#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
handoff.py - proactive context-budget guard + session handoff for VULYK.

Claude Code hooks do not receive token usage (see the official hooks docs), but
every hook gets `transcript_path`. Each assistant entry in that JSONL carries a
`message.usage` block; input + cache_read + cache_creation + output of the LAST
main-thread assistant message is the true current context size. That is what
this script measures. Sidechain entries (`isSidechain: true` = subagents) are
excluded - counting them would skew the number.

Modes (argv[1]); hook modes read the hook JSON payload on stdin:
    stop           Stop hook          -> escalating systemMessage banner to the user
    prompt         UserPromptSubmit   -> additionalContext nudging the model to offer a handoff
    precompact     PreCompact         -> emergency mechanical handoff dump
    sessionend     SessionEnd         -> mechanical handoff dump on /clear or exit
    sessionstart   SessionStart       -> injects the freshest handoff for this project
    dump           manual             -> writes the mechanical skeleton, prints its path (used by /vulyk-handoff)
    status         debug              -> human-readable current numbers

Storage (all project-local, gitignored):
    .claude/handoff/*.md          handoff documents
    .claude/handoff/index.json    pointer to the freshest handoff
    .claude/handoff/state/        per-session anti-spam state (self-pruned after 7 days)
Optional config: .claude/handoff.config.json (same keys as DEFAULTS below).

Contract: NEVER crash, NEVER block. Any failure exits 0 with no stdout.
Invoked through handoff.sh, which fails open when no Python 3 is on PATH.
"""

import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = os.path.expanduser("~")
CLAUDE_USER_DIR = os.path.join(HOME, ".claude")

DEFAULTS = {
    "enabled": True,
    # Standard Claude Code window. Raise to 1000000 if you run a 1M-context model.
    "context_limit": 200000,
    # absolute token thresholds -> escalation levels 1, 2, 3 (55% / 70% / ~82%)
    "thresholds": [110000, 140000, 165000],
    # below this, a session is too small to be worth dumping
    "min_dump_tokens": 25000,
    # prompt-cache TTL: 60 min on subscription plans, 5 on an API key
    # (unless ENABLE_PROMPT_CACHING_1H=1). Checkpointing inside this window
    # re-reads the conversation at cache price; outside it, at full price.
    "cache_ttl_minutes": 60,
    # SessionStart(startup) only restores a handoff younger than this
    "restore_max_age_hours": 12,
    # how much transcript tail to parse for a dump (bytes)
    "dump_tail_bytes": 12 * 1024 * 1024,
    "max_user_prompts": 12,
    "max_touched_files": 40,
}


# --------------------------------------------------------------------------- utils

def project_root(payload):
    root = os.environ.get("CLAUDE_PROJECT_DIR")
    if root and os.path.isdir(root):
        return root
    cwd = (payload or {}).get("cwd")
    if cwd and os.path.isdir(cwd):
        return cwd
    return os.getcwd()


def handoff_dir(root):
    return os.path.join(root, ".claude", "handoff")


def index_path(root):
    return os.path.join(handoff_dir(root), "index.json")


def load_config(root):
    cfg = dict(DEFAULTS)
    try:
        with open(os.path.join(root, ".claude", "handoff.config.json"), "r", encoding="utf-8") as fh:
            cfg.update(json.load(fh) or {})
    except Exception:
        pass
    return cfg


def emit(payload):
    """Print a hook JSON response and exit cleanly."""
    if payload:
        sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.exit(0)


def read_stdin_json():
    try:
        raw = sys.stdin.read()
    except Exception:
        return {}
    if not raw or not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def slugify_cwd(cwd):
    return re.sub(r"[^A-Za-z0-9]", "-", cwd or "unknown")


def human(n):
    if n >= 1000000:
        return "%.2fM" % (n / 1000000.0)
    if n >= 1000:
        return "%dk" % round(n / 1000.0)
    return str(n)


def now_local():
    return datetime.now(timezone.utc).astimezone()


# ------------------------------------------------------------------- transcript IO

def iter_tail_lines(path, max_bytes):
    """Return decoded lines from the tail of a file, oldest-first, without loading it all."""
    try:
        size = os.path.getsize(path)
    except Exception:
        return []
    start = max(0, size - max_bytes)
    try:
        with open(path, "rb") as fh:
            fh.seek(start)
            data = fh.read()
    except Exception:
        return []
    if start > 0:
        nl = data.find(b"\n")
        data = data[nl + 1:] if nl != -1 else b""
    try:
        text = data.decode("utf-8", "replace")
    except Exception:
        return []
    return text.splitlines()


def parse_entries(path, max_bytes):
    out = []
    for line in iter_tail_lines(path, max_bytes):
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            out.append(json.loads(line))
        except Exception:
            continue
    return out


def parse_ts(value):
    """Claude Code stamps entries with ISO-8601 UTC ('...Z'). Never raise on a surprise."""
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


def minutes_since(ts):
    if ts is None:
        return None
    try:
        delta = (datetime.now(timezone.utc) - ts.astimezone(timezone.utc)).total_seconds() / 60.0
    except Exception:
        return None
    return delta if delta >= 0 else 0.0


def cache_note(ts, cfg):
    """One clause about the prompt cache, or '' when the age is unknown.

    Compacting or checkpointing re-reads the conversation. Inside the TTL that read is a
    cache hit (~0.1x input); once the prefix has expired it is a full-price re-prefill.
    So the cheapest moment to check out is *now*, not after the break.
    """
    age = minutes_since(ts)
    ttl = cfg.get("cache_ttl_minutes") or 0
    if age is None or ttl <= 0:
        return ""
    left = ttl - age
    if left <= 0:
        return (" The cached prefix (%d min TTL) has expired, so the next turn re-prefills at "
                "full price either way - no reason to delay the checkpoint." % ttl)
    if left <= 10:
        return (" Cached prefix expires in ~%d min: checkpoint now, while re-reading the "
                "conversation is still a cache hit." % round(left))
    return (" Cached prefix stays warm for ~%d more min - checkpointing inside that window is "
            "far cheaper than after it." % round(left))


def context_tokens(transcript_path):
    """(tokens, model, timestamp) of the last main-thread assistant message.

    Sidechains (subagents) are excluded: they run in their own context window and
    counting them skews the number. The timestamp is when that turn was written -
    i.e. how long the prompt cache has been sitting idle.
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return 0, None, None
    # 2 MB of tail is far more than one assistant entry; widen once if we miss.
    for budget in (2 * 1024 * 1024, 24 * 1024 * 1024):
        for entry in reversed(parse_entries(transcript_path, budget)):
            if entry.get("type") != "assistant" or entry.get("isSidechain"):
                continue
            msg = entry.get("message") or {}
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            total = (
                (usage.get("input_tokens") or 0)
                + (usage.get("cache_read_input_tokens") or 0)
                + (usage.get("cache_creation_input_tokens") or 0)
                + (usage.get("output_tokens") or 0)
            )
            if total:
                return total, msg.get("model"), parse_ts(entry.get("timestamp"))
    return 0, None, None


def newest_transcript_for_cwd(cwd):
    d = os.path.join(CLAUDE_USER_DIR, "projects", slugify_cwd(cwd))
    try:
        files = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".jsonl")]
    except Exception:
        return None
    if not files:
        return None
    try:
        return max(files, key=os.path.getmtime)
    except Exception:
        return None


# ------------------------------------------------------------------------- state

def state_path(root, session_id):
    return os.path.join(handoff_dir(root), "state", "%s.json" % (session_id or "unknown"))


def load_state(root, session_id):
    try:
        with open(state_path(root, session_id), "r", encoding="utf-8") as fh:
            return json.load(fh) or {}
    except Exception:
        return {}


def save_state(root, session_id, state):
    try:
        p = state_path(root, session_id)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            json.dump(state, fh, ensure_ascii=False)
    except Exception:
        pass
    prune_state(root)


def prune_state(root, max_age_days=7):
    """Keep the state dir from growing one file per session forever."""
    cutoff = time.time() - max_age_days * 86400
    d = os.path.join(handoff_dir(root), "state")
    try:
        for name in os.listdir(d):
            p = os.path.join(d, name)
            if os.path.isfile(p) and os.path.getmtime(p) < cutoff:
                os.remove(p)
    except Exception:
        pass


def level_for(tokens, thresholds):
    lvl = 0
    for i, t in enumerate(thresholds, start=1):
        if tokens >= t:
            lvl = i
    return lvl


# ------------------------------------------------------------------ handoff build

def git_info(cwd):
    def run(args):
        try:
            r = subprocess.run(
                args, cwd=cwd, capture_output=True, text=True, timeout=5,
                encoding="utf-8", errors="replace",
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            return ""

    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    if not branch:
        return None
    status = run(["git", "status", "--short"])
    return {"branch": branch, "status": status}


def block_text(content):
    """Flatten an assistant/user message content field into plain text."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts = []
    for b in content:
        if isinstance(b, dict) and b.get("type") == "text" and b.get("text"):
            parts.append(b["text"])
    return "\n".join(parts)


def harvest(entries, cfg):
    """Pull prompts, touched files, todos and the last reply out of transcript entries."""
    prompts, touched, todos, last_reply = [], {}, None, ""
    for entry in entries:
        if entry.get("isSidechain"):
            continue
        etype = entry.get("type")
        msg = entry.get("message") or {}

        if etype == "user" and not entry.get("isMeta"):
            content = msg.get("content")
            if isinstance(content, list) and any(
                isinstance(b, dict) and b.get("type") == "tool_result" for b in content
            ):
                continue
            text = block_text(content).strip()
            if text and not text.startswith("<"):
                prompts.append(text)

        elif etype == "assistant":
            text = block_text(msg.get("content")).strip()
            if text:
                last_reply = text
            for b in msg.get("content") or []:
                if not isinstance(b, dict) or b.get("type") != "tool_use":
                    continue
                name = b.get("name") or ""
                args = b.get("input") or {}
                if name in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
                    fp = args.get("file_path") or args.get("path")
                    if fp:
                        touched[fp] = touched.get(fp, 0) + 1
                elif name == "TodoWrite":
                    items = args.get("todos")
                    if isinstance(items, list) and items:
                        todos = items

    return {
        "prompts": prompts[-cfg["max_user_prompts"]:],
        "touched": list(touched.items())[-cfg["max_touched_files"]:],
        "todos": todos,
        "last_reply": last_reply[:1500],
    }


# Minimal mirror of scripts/redact.sh for environments without bash - that script is
# the single source of truth for the pattern list; extend both together.
_REDACT_FALLBACK = [
    re.compile(r"(?:AKIA|ASIA)[0-9A-Z]{16}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{22,}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"AIza[0-9A-Za-z_-]{35}"),
    re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}"),
    re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?"
               r"(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|\Z)", re.S),
    re.compile(r"([\"']?[A-Za-z0-9_-]*(?:password|passwd|secret|api[_-]?key|access[_-]?key"
               r"|auth[_-]?token|client[_-]?secret|private[_-]?key)[A-Za-z0-9_-]*[\"']?"
               r"\s*[=:]\s*)[\"']?[^\"'\s]{6,}[\"']?", re.I),
]


def redact_text(root, text):
    """Pass transcript-derived text through scripts/redact.sh before writing it.

    Handoffs are gitignored but get re-injected into future sessions and are routinely
    shared - a pasted secret must not survive into either. Contract holds: never crash,
    never block; on total failure the text passes through unredacted rather than the
    handoff being eaten (that would be a silent-loss path of its own)."""
    if not text:
        return text
    script = os.path.join(root, "scripts", "redact.sh")
    if os.path.isfile(script):
        try:
            p = subprocess.run(
                ["bash", script], input=text.encode("utf-8"),
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=15)
            if p.returncode == 0 and p.stdout:
                return p.stdout.decode("utf-8", "replace")
        except Exception:
            pass
    try:
        for pat in _REDACT_FALLBACK:
            text = pat.sub(
                lambda m: (m.group(1) if m.groups() else "") + "[VULYK:REDACTED]", text)
    except Exception:
        pass
    return text


def write_handoff(payload, cfg, reason):
    root = project_root(payload)
    cwd = payload.get("cwd") or root
    session_id = payload.get("session_id") or "unknown"
    transcript = payload.get("transcript_path") or newest_transcript_for_cwd(cwd)
    tokens, model, _ = context_tokens(transcript)
    entries = parse_entries(transcript, cfg["dump_tail_bytes"]) if transcript else []
    data = harvest(entries, cfg)
    git = git_info(root)
    stamp = now_local()

    lines = [
        "---",
        "handoff: true",
        "session_id: %s" % session_id,
        "created: %s" % stamp.isoformat(timespec="seconds"),
        "cwd: %s" % cwd,
        "reason: %s" % reason,
        "context_tokens: %d" % tokens,
        "model: %s" % (model or "unknown"),
        "enriched: false",
        "---",
        "",
        "# Handoff - %s - %s" % (os.path.basename(root.rstrip("\\/")) or root,
                                 stamp.strftime("%Y-%m-%d %H:%M")),
        "",
        "> Mechanical auto-dump (%s). Context at dump time: %s tokens." % (reason, human(tokens)),
        "> The `## Summary` section is filled in by `/vulyk-handoff` - that is the model-written narrative.",
        "",
    ]

    if git:
        lines += ["## Git", "", "branch: `%s`" % git["branch"], ""]
        if git["status"]:
            lines += ["```", git["status"][:4000], "```", ""]
        else:
            lines += ["_working tree clean_", ""]

    if data["todos"]:
        lines += ["## Tasks (last TodoWrite)", ""]
        for item in data["todos"]:
            if not isinstance(item, dict):
                continue
            st = (item.get("status") or "").lower()
            mark = "x" if st == "completed" else ("~" if st == "in_progress" else " ")
            lines.append("- [%s] %s" % (mark, item.get("content") or item.get("activeForm") or ""))
        lines.append("")

    if data["touched"]:
        lines += ["## Touched files", ""]
        for fp, n in data["touched"]:
            lines.append("- `%s`%s" % (fp, (" (x%d)" % n) if n > 1 else ""))
        lines.append("")

    if data["prompts"]:
        lines += ["## Recent user prompts", ""]
        for i, p in enumerate(data["prompts"], start=1):
            snippet = p.strip().replace("\r", "")
            if len(snippet) > 500:
                snippet = snippet[:500] + " ..."
            lines.append("%d. %s" % (i, snippet.replace("\n", "\n   ")))
        lines.append("")

    if data["last_reply"]:
        lines += ["## Last assistant reply (truncated)", "", data["last_reply"], ""]

    lines += ["## Summary", "",
              "_not enriched - run `/vulyk-handoff` so the model rewrites this section_", ""]

    target_dir = handoff_dir(root)
    os.makedirs(target_dir, exist_ok=True)
    fname = "%s-%s.md" % (stamp.strftime("%Y%m%d-%H%M%S"), str(session_id)[:8])
    path = os.path.join(target_dir, fname)
    doc = redact_text(root, "\n".join(lines))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(doc)

    try:
        with open(index_path(root), "w", encoding="utf-8") as fh:
            json.dump({
                "path": path,
                "cwd": cwd,
                "session_id": session_id,
                "reason": reason,
                "context_tokens": tokens,
                "ts": time.time(),
                "created": stamp.isoformat(timespec="seconds"),
            }, fh, ensure_ascii=False, indent=2)
    except Exception:
        pass

    return path, tokens


# ------------------------------------------------------------------------- modes

def banner(tokens, level, cfg, ts=None):
    limit = cfg["context_limit"]
    pct = (tokens * 100.0 / limit) if limit else 0
    head = "[VULYK] Context %s / %s (%.0f%%)" % (human(tokens), human(limit), pct)
    if level == 1:
        return ("🟡 %s. Still in the working zone, but quality degrades from here - "
                "aim to finish the current task rather than start an adjacent one." % head)
    if level == 2:
        return ("🟠 %s. Time to wrap up. Run `/vulyk-handoff` to save session state to "
                ".claude/handoff/, then `/clear` (or exit + restart): the next session "
                "picks the handoff up automatically.%s" % (head, cache_note(ts, cfg)))
    return ("🔴 %s. Do not start new multi-step work - context rot is real at this size. "
            "`/vulyk-handoff` -> `/clear`.%s" % (head, cache_note(ts, cfg)))


def mode_stop(payload, cfg, root):
    if payload.get("agent_id"):  # subagent stop, not the main loop
        emit(None)
    session_id = payload.get("session_id")
    tokens, _, ts = context_tokens(payload.get("transcript_path"))
    level = level_for(tokens, cfg["thresholds"])
    if level == 0:
        emit(None)
    state = load_state(root, session_id)
    if state.get("stop_level", 0) >= level:
        emit(None)
    state["stop_level"] = level
    state["last_tokens"] = tokens
    save_state(root, session_id, state)
    emit({"systemMessage": banner(tokens, level, cfg, ts), "suppressOutput": True})


def mode_prompt(payload, cfg, root):
    session_id = payload.get("session_id")
    tokens, _, ts = context_tokens(payload.get("transcript_path"))
    level = level_for(tokens, cfg["thresholds"])
    if level < 2:
        emit(None)
    state = load_state(root, session_id)
    if state.get("prompt_level", 0) >= level:
        emit(None)
    state["prompt_level"] = level
    save_state(root, session_id, state)

    limit = cfg["context_limit"]
    pct = (tokens * 100.0 / limit) if limit else 0
    urgency = "Strongly" if level >= 3 else "Gently"
    ctx = (
        "[VULYK handoff] This session has consumed ~%s context tokens (%.0f%% of %s). "
        "%s suggest that the user checkpoint now: run `/vulyk-handoff` (saves "
        ".claude/handoff/*.md), then `/clear` or restart - the next session restores the "
        "handoff automatically. Suggest it ONCE, briefly, at the end of your reply. "
        "If the user asks to continue, continue without repeating the reminder.%s %s"
        % (human(tokens), pct, human(limit), urgency, cache_note(ts, cfg),
           "Do not start new large multi-step tasks in this session." if level >= 3 else "")
    ).rstrip()
    emit({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": ctx}})


def mode_dump_hook(payload, cfg, reason, min_tokens_check=True):
    tokens, _, _ = context_tokens(payload.get("transcript_path"))
    if min_tokens_check and tokens < cfg["min_dump_tokens"]:
        emit(None)
    try:
        path, tokens = write_handoff(payload, cfg, reason)
    except Exception:
        emit(None)
    emit({"systemMessage": "💾 [VULYK] handoff: session state saved -> %s" % path,
          "suppressOutput": True})


def mode_sessionstart(payload, cfg, root):
    source = (payload.get("source") or "").lower()
    if source in ("resume", "fork"):
        emit(None)
    idx = index_path(root)
    try:
        with open(idx, "r", encoding="utf-8") as fh:
            meta = json.load(fh)
    except Exception:
        emit(None)

    path = meta.get("path")
    if not path or not os.path.exists(path):
        emit(None)

    age_h = (time.time() - float(meta.get("ts") or 0)) / 3600.0
    deliberate = source in ("clear", "compact")
    if not deliberate:
        if age_h > cfg["restore_max_age_hours"]:
            emit(None)
        if meta.get("consumed_by_startup"):
            emit(None)

    try:
        with open(path, "r", encoding="utf-8") as fh:
            body = fh.read()
    except Exception:
        emit(None)
    if len(body) > 12000:
        body = body[:12000] + "\n\n...(truncated)"

    try:
        meta["consumed_by_startup"] = True
        with open(idx, "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False, indent=2)
    except Exception:
        pass

    ctx = (
        "[VULYK handoff] Found a handoff from the previous session in this project "
        "(%s, age %.1f h, file %s). Its content follows.\n\n"
        "How to use it: do NOT rush into the work. First confirm to the user, in one or "
        "two sentences, where the previous session stopped and what the next step was, "
        "then wait for their decision.\n\n---\n\n%s"
        % (meta.get("reason", "?"), age_h, path, body)
    )
    emit({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}})


def mode_status(payload, cfg, root):
    cwd = payload.get("cwd") or os.getcwd()
    transcript = payload.get("transcript_path") or newest_transcript_for_cwd(cwd)
    tokens, model, ts = context_tokens(transcript)
    limit = cfg["context_limit"]
    age = minutes_since(ts)
    print("root       : %s" % root)
    print("transcript : %s" % transcript)
    print("model      : %s" % model)
    print("context    : %s / %s (%.1f%%)" % (human(tokens), human(limit),
                                             tokens * 100.0 / limit if limit else 0))
    print("thresholds : %s" % cfg["thresholds"])
    print("level      : %d" % level_for(tokens, cfg["thresholds"]))
    print("last turn  : %s" % ("%.0f min ago" % age if age is not None else "unknown"))
    print("cache      : %s (ttl %s min)" % (
        "unknown" if age is None
        else ("warm, ~%.0f min left" % (cfg["cache_ttl_minutes"] - age)
              if age < cfg["cache_ttl_minutes"] else "expired"),
        cfg["cache_ttl_minutes"]))
    sys.exit(0)


HOOK_MODES = ("stop", "prompt", "precompact", "sessionend", "sessionstart")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    # Only hook modes consume stdin; dump/status are invoked from a shell where
    # a blind stdin read could block on an open pipe.
    payload = read_stdin_json() if mode in HOOK_MODES else {}
    root = project_root(payload)
    cfg = load_config(root)

    if not cfg.get("enabled", True):
        emit(None)

    if mode == "stop":
        mode_stop(payload, cfg, root)
    elif mode == "prompt":
        mode_prompt(payload, cfg, root)
    elif mode == "precompact":
        mode_dump_hook(payload, cfg, "precompact", min_tokens_check=False)
    elif mode == "sessionend":
        reason = (payload.get("reason") or "other").lower()
        if reason not in ("clear", "logout", "other", "exit"):
            emit(None)
        mode_dump_hook(payload, cfg, "sessionend-%s" % reason)
    elif mode == "sessionstart":
        mode_sessionstart(payload, cfg, root)
    elif mode == "dump":
        if not payload.get("cwd"):
            payload["cwd"] = os.getcwd()
        if not payload.get("transcript_path"):
            payload["transcript_path"] = newest_transcript_for_cwd(payload["cwd"])
        if not payload.get("session_id") and payload.get("transcript_path"):
            # transcripts are named <session_id>.jsonl
            payload["session_id"] = os.path.splitext(
                os.path.basename(payload["transcript_path"]))[0]
        path, tokens = write_handoff(payload, cfg, "manual")
        print(path)
        print("context_tokens=%d" % tokens)
        sys.exit(0)
    elif mode == "status":
        mode_status(payload, cfg, root)
    emit(None)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        # A guard hook must never break the session.
        sys.exit(0)
