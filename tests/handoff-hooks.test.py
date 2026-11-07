# -*- coding: utf-8 -*-
"""Hook-mode regressions for handoff.py (audit P10 of VULYK 0.46).

Every case builds its own HOME, project and transcript under one temp root, then runs
the real hook through a subprocess - the same way Claude Code does, payload bytes on
stdin - and asserts on what it prints or writes. Run by tests/handoff.test.sh.

    Usage: python3 tests/handoff-hooks.test.py [<handoff.py>]
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

HOOK = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".claude/hooks/handoff.py")
# A non-ASCII root on purpose: the owner's home on Windows is often Cyrillic (P10-01).
ROOT = tempfile.mkdtemp(prefix="vulyk-handoff-")
ROOT = os.path.join(ROOT, "Користувач")
os.makedirs(ROOT)
fails = []
count = [0]


def check(name, cond, detail=""):
    count[0] += 1
    print(("  ok    " if cond else "  FAIL  ") + name + ("" if cond else "  -> " + detail))
    if not cond:
        fails.append(name)


def fresh(tag):
    """(home, proj) for one case: empty HOME, a project with .claude/."""
    base = os.path.join(ROOT, tag)
    home, proj = os.path.join(base, "home"), os.path.join(base, "proj")
    os.makedirs(os.path.join(proj, ".claude"))
    os.makedirs(home)
    return home, proj


def env_for(home, proj, extra=None):
    e = dict(os.environ)
    for k in ("CLAUDE_CODE_AUTO_COMPACT_WINDOW", "CLAUDE_CODE_DISABLE_1M_CONTEXT",
              "CLAUDE_CONFIG_DIR", "PYTHONUTF8"):
        e.pop(k, None)
    e.update({"HOME": home, "USERPROFILE": home, "CLAUDE_PROJECT_DIR": proj,
              "PYTHONIOENCODING": "utf-8"})
    e.update(extra or {})
    return e


def write_transcript(path, tokens, prompts=(), reply=""):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    rows = [{"type": "user", "message": {"role": "user", "content": p}} for p in prompts]
    rows.append({
        "type": "assistant", "isSidechain": False, "timestamp": ts,
        "message": {"model": "claude-opus-5", "content": [{"type": "text", "text": reply or "done"}],
                    "usage": {"input_tokens": 2, "cache_read_input_tokens": tokens - 2,
                              "cache_creation_input_tokens": 0, "output_tokens": 0}},
    })
    with open(path, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    return path


def run(mode, env, payload=None, args=()):
    stdin = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else b""
    r = subprocess.run([sys.executable, HOOK, mode] + list(args), input=stdin,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


def handoffs(proj):
    d = os.path.join(proj, ".claude", "handoff")
    try:
        return sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".md"))
    except OSError:
        return []


def read(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


# --- P10-01: the payload is UTF-8 whatever the locale's code page ------------------------------
print("--- P10-01 stdin is read as UTF-8")
home, proj = fresh("p01")
tp = write_transcript(os.path.join(ROOT, "p01", "Сесія", "s01.jsonl"), 150000)
# cp1251 stands in for a Cyrillic Windows locale on every OS: Python decodes a piped stdin with it.
rc, out, err = run("stop", env_for(home, proj, {"PYTHONIOENCODING": "cp1251"}),
                   {"session_id": "s01", "transcript_path": tp, "cwd": proj})
check("P10-01 a Cyrillic transcript_path under a cp1251 locale still yields the Stop banner",
      rc == 0 and "systemMessage" in out and "150k" in out, "rc=%d out=%r err=%r" % (rc, out[:200], err[:200]))


shutil.rmtree(os.path.dirname(ROOT), ignore_errors=True)
print()
if fails:
    print("FAILED %d/%d: %s" % (len(fails), count[0], ", ".join(fails)))
    sys.exit(1)
print("all %d cases passed" % count[0])
