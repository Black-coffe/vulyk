#!/usr/bin/env python3
"""Card handoff-offered-too-early: does a handoff.py speak before 70% of the session's real window?

Usage: bash scripts/py.sh scripts/handoff-window-check.py [<handoff.py>]   (default .claude/hooks/handoff.py)

Runs the given hook, as Claude Code does (payload on stdin, `stop` and `prompt` modes), through three
sessions on a 1M window, each in its own temporary HOME and project:
  A  151k tokens; this session has no statusLine copy, and the only copy on the machine is 8 h old, from
     another session of the same model: the hook must stay silent (15% of 1M, not 76% of 200k).
  B  650k tokens, this session's own copy says 1M: silent (65% is under the first offer at 70%).
  C  710k tokens, same copy: the prompt mode must offer /vulyk-handoff (control: the check can see speech).
Exit 0 when all three hold, 1 when the hook speaks early or not at all, 2 on a usage error.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

MODEL = "claude-opus-5-5"
WINDOW = 1000000


def write_transcript(path, tokens):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    row = {"type": "assistant", "isSidechain": False, "timestamp": ts,
           "message": {"model": MODEL, "content": [{"type": "text", "text": "done"}],
                       "usage": {"input_tokens": 2, "cache_read_input_tokens": tokens - 2,
                                 "cache_creation_input_tokens": 0, "output_tokens": 0}}}
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def write_statusline(path, session_id, age_s=0):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = {"session_id": session_id, "model": {"id": MODEL},
            "context_window": {"context_window_size": WINDOW}}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh)
    if age_s:
        t = time.time() - age_s
        os.utime(path, (t, t))


def run(hook, base, tag, tokens, own_copy, foreign_age_s=0):
    """stdout of the `stop` and `prompt` modes for one session, joined."""
    home, proj = os.path.join(base, tag, "home"), os.path.join(base, tag, "proj")
    os.makedirs(os.path.join(proj, ".claude"))
    os.makedirs(home)
    sid = "session-" + tag
    transcript = os.path.join(home, "t", sid + ".jsonl")
    write_transcript(transcript, tokens)
    cache = os.path.join(home, ".cache", "claude-statusbar")
    if own_copy:
        write_statusline(os.path.join(cache, "sessions", sid, "last_stdin.json"), sid)
    if foreign_age_s:
        write_statusline(os.path.join(cache, "last_stdin.json"), "another-session", foreign_age_s)
    env = dict(os.environ)
    for k in ("CLAUDE_CODE_AUTO_COMPACT_WINDOW", "CLAUDE_CODE_DISABLE_1M_CONTEXT", "CLAUDE_CONFIG_DIR"):
        env.pop(k, None)
    env.update({"HOME": home, "USERPROFILE": home, "CLAUDE_PROJECT_DIR": proj, "PYTHONIOENCODING": "utf-8"})
    payload = json.dumps({"session_id": sid, "transcript_path": transcript, "cwd": proj}).encode("utf-8")
    out = []
    for mode in ("stop", "prompt"):
        r = subprocess.run([sys.executable, hook, mode], input=payload, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        out.append(r.stdout.decode("utf-8", "replace").strip())
    return "\n".join(o for o in out if o)


def main():
    if len(sys.argv) > 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    hook = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(".claude", "hooks", "handoff.py"))
    if os.path.basename(hook) == "telemetry.sh":
        # The card guards telemetry.sh for its shared window logic; the hook that speaks is the tree's handoff.py.
        hook = os.path.join(os.path.dirname(os.path.dirname(hook)), ".claude", "hooks", "handoff.py")
    if not os.path.isfile(hook):
        print("handoff-window-check: no such file: %s" % hook, file=sys.stderr)
        return 2
    base = tempfile.mkdtemp(prefix="vulyk-hwc-")
    bad = []
    try:
        a = run(hook, base, "a", 151000, own_copy=False, foreign_age_s=8 * 3600)
        if a:
            bad.append("A 151k tokens on a 1M model (only a stale copy from another session): the hook spoke: " + a[:160])
        b = run(hook, base, "b", 650000, own_copy=True)
        if b:
            bad.append("B 650k of 1M (65%): the hook spoke before 70%: " + b[:160])
        c = run(hook, base, "c", 710000, own_copy=True)
        if "/vulyk-handoff" not in c:
            bad.append("C 710k of 1M (71%): no /vulyk-handoff offer")
    finally:
        shutil.rmtree(base, ignore_errors=True)
    for line in bad:
        print("handoff-window-check: %s" % line)
    if bad:
        return 1
    print("handoff-window-check: ok - silent at 151k and 650k of 1M, offers /vulyk-handoff at 710k")
    return 0


if __name__ == "__main__":
    sys.exit(main())
