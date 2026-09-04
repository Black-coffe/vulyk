# -*- coding: utf-8 -*-
"""Synthetic matrix for handoff.py context-window resolution.

Every case builds its own HOME, project and transcript, then runs the real hook
in `prompt` mode through a subprocess and asserts on what it injects.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

HOOK = sys.argv[1] if len(sys.argv) > 1 else ".claude/hooks/handoff.py"
ROOT = tempfile.mkdtemp(prefix="vulyk-window-")
fails = []
n = [0]


def case(name, tokens, expect_silent, expect_needle=None,
         window=None, foreign=False, no_statusbar=False,
         config=None, env=None, per_session=False):
    n[0] += 1
    sid = "0000000-session-%02d" % n[0]
    home = os.path.join(ROOT, "home%02d" % n[0])
    proj = os.path.join(ROOT, "proj%02d" % n[0])
    tdir = os.path.join(ROOT, "tr%02d" % n[0])
    os.makedirs(os.path.join(proj, ".claude"))
    os.makedirs(tdir)
    os.makedirs(home)

    # transcript: one main-thread assistant turn of `tokens` context
    tp = os.path.join(tdir, sid + ".jsonl")
    entry = {
        "type": "assistant", "isSidechain": False,
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "message": {"model": "claude-opus-5", "usage": {
            "input_tokens": 2, "cache_read_input_tokens": tokens - 2,
            "cache_creation_input_tokens": 0, "output_tokens": 0}},
    }
    with open(tp, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(entry) + "\n")

    if not no_statusbar:
        payload = {
            "session_id": "somebody-elses-session" if foreign else sid,
            "transcript_path": tp,
            "context_window": {"context_window_size": window or 200000},
        }
        if per_session:
            d = os.path.join(home, ".cache", "claude-statusbar", "sessions", sid)
            os.makedirs(d)
            with open(os.path.join(d, "last_stdin.json"), "w", encoding="utf-8") as fh:
                json.dump(payload, fh)
            # the global file simultaneously belongs to a different window
            d2 = os.path.join(home, ".cache", "claude-statusbar")
            with open(os.path.join(d2, "last_stdin.json"), "w", encoding="utf-8") as fh:
                json.dump({"session_id": "other", "context_window":
                           {"context_window_size": 200000}}, fh)
        else:
            d = os.path.join(home, ".cache", "claude-statusbar")
            os.makedirs(d)
            with open(os.path.join(d, "last_stdin.json"), "w", encoding="utf-8") as fh:
                json.dump(payload, fh)

    if config is not None:
        with open(os.path.join(proj, ".claude", "handoff.config.json"), "w",
                  encoding="utf-8") as fh:
            json.dump(config, fh)

    e = dict(os.environ)
    e.pop("CLAUDE_CODE_AUTO_COMPACT_WINDOW", None)
    e.pop("CLAUDE_CODE_DISABLE_1M_CONTEXT", None)
    e.update({"HOME": home, "USERPROFILE": home, "CLAUDE_PROJECT_DIR": proj})
    e.update(env or {})

    stdin = json.dumps({"session_id": sid, "transcript_path": tp, "cwd": proj,
                        "hook_event_name": "UserPromptSubmit"})
    r = subprocess.run([sys.executable, HOOK, "prompt"], input=stdin,
                       capture_output=True, text=True, env=e)
    out = (r.stdout or "").strip()

    ok = True
    detail = ""
    if r.returncode != 0:
        ok, detail = False, "exit %d stderr=%s" % (r.returncode, (r.stderr or "")[:200])
    elif expect_silent and out:
        ok, detail = False, "expected silence, got: %s" % out[:200]
    elif not expect_silent and not out:
        ok, detail = False, "expected a nag, got silence"
    elif expect_needle and expect_needle not in out:
        ok, detail = False, "missing %r in: %s" % (expect_needle, out[:240])

    print(("  ok    " if ok else "  FAIL  ") + name + ("" if ok else "  -> " + detail))
    if not ok:
        fails.append(name)


# --- the reported bug: 150k on a 1M window is 15%, not 75% ------------------
case("1M window, 150k -> silent", 150000, True, window=1000000)
case("1M window via per-session cache -> silent", 150000, True,
     window=1000000, per_session=True)
case("200k window, 150k -> nags with the right denominator", 150000, False,
     "(75% of 200k)", window=200000)

# --- the statusbar cannot answer for this session --------------------------
case("foreign session in cache -> stays quiet rather than guess", 150000, True,
     foreign=True)
case("no statusbar at all -> legacy 200k behaviour preserved", 150000, False,
     "(75% of 200k)", no_statusbar=True)
case("no statusbar, 300k measured -> treated as 1M, silent", 300000, True,
     no_statusbar=True)

# --- explicit operator overrides -------------------------------------------
case("config pin beats a foreign cache", 150000, True,
     foreign=True, config={"context_limit": 1000000})
case("env CLAUDE_CODE_AUTO_COMPACT_WINDOW wins", 150000, True,
     window=200000, env={"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000"})
case("env CLAUDE_CODE_DISABLE_1M_CONTEXT caps back to 200k", 150000, False,
     "(75% of 200k)", window=1000000,
     env={"CLAUDE_CODE_DISABLE_1M_CONTEXT": "1"})

# --- backwards compatibility ------------------------------------------------
case("legacy absolute thresholds still honoured", 150000, False, "of 1.00M",
     window=1000000, config={"thresholds": [110000, 140000, 165000]})
case("legacy 200k pin still honoured", 150000, False, "(75% of 200k)",
     window=1000000, config={"context_limit": 200000})

# --- the escalation floor ---------------------------------------------------
case("1M window, 750k -> nags at the real level", 750000, False, "(75% of 1.00M)",
     window=1000000)

shutil.rmtree(ROOT, ignore_errors=True)
print()
if fails:
    print("FAILED %d/%d: %s" % (len(fails), n[0], ", ".join(fails)))
    sys.exit(1)
print("all %d cases passed" % n[0])
