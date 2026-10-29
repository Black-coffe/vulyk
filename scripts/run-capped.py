#!/usr/bin/env python3
"""run-capped.py <secs> <cmd> [args...] - run <cmd> for at most <secs> seconds.

lib.sh's run_capped falls back to this when neither `timeout` nor `gtimeout` works (a stock macOS
has neither). stdin, stdout and stderr are inherited. On timeout the command's whole process group
gets SIGTERM, then SIGKILL after a 10 s grace, and the exit is 124, as `timeout -k 10` gives; on
Windows the process tree is killed. Otherwise the exit is the command's own (128+N for a signal).
"""
import os
import shutil
import signal
import subprocess
import sys

GRACE = 10
WINDOWS = os.name == "nt"


def kill_tree(p, sig):
    if WINDOWS:
        subprocess.call(["taskkill", "/T", "/F", "/PID", str(p.pid)],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    try:
        os.killpg(p.pid, sig)
    except OSError:
        pass


def code_of(rc):
    return 128 - rc if rc < 0 else rc


def main(argv):
    if len(argv) < 3:
        sys.stderr.write("usage: run-capped.py <secs> <cmd> [args...]\n")
        return 2
    try:
        secs = float(argv[1])
    except ValueError:
        sys.stderr.write("run-capped.py: <secs> is not a number: %s\n" % argv[1])
        return 2
    cmd = argv[2:]
    if WINDOWS:  # CreateProcess searches System32 before PATH; resolve the name the shell would run
        cmd[0] = shutil.which(cmd[0]) or cmd[0]
    try:
        p = subprocess.Popen(cmd, start_new_session=not WINDOWS)
    except OSError as e:
        sys.stderr.write("run-capped.py: %s: %s\n" % (cmd[0], e))
        return 126 if os.path.exists(cmd[0]) else 127
    try:
        return code_of(p.wait(timeout=secs))
    except subprocess.TimeoutExpired:
        kill_tree(p, signal.SIGTERM)
        try:
            p.wait(timeout=GRACE)
        except subprocess.TimeoutExpired:
            pass
        kill_tree(p, getattr(signal, "SIGKILL", signal.SIGTERM))
        p.wait()
        return 124
    except KeyboardInterrupt:
        kill_tree(p, signal.SIGTERM)
        p.wait()
        return 130


if __name__ == "__main__":
    sys.exit(main(sys.argv))
