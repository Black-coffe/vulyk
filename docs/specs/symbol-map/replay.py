"""Replay scripts/symbol-map.sh on stories that missed a path outside ## Files (stdlib only).

Usage: python docs/specs/symbol-map/replay.py <cases.json>

cases.json: {"cases": [{"story_file": <absolute path>, "files": [<repo-relative>...],
                        "missed": [<repo-relative>...]}, ...]}
The repo root per case is the nearest ancestor of story_file holding .git. The script runs on `files` with
`files` as --scope; a missed path is a hit when it appears on any output line; noise is the number of path
lines (`exact` / `textual`) printed. Stdout is local: per-case lines name unfound paths, never commit them.
Last line: replay: hits <h>/<m> noise <lines> over <n> stories. Exit 2 on a missing cases file or repo root.
"""
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SM = os.path.normpath(os.path.join(HERE, '..', '..', '..', 'scripts', 'symbol-map.sh'))
PATH_LINE = re.compile(r'^\s+(exact|textual)\s+\S')


def repo_root(story_file):
    d = os.path.dirname(os.path.abspath(story_file))
    while True:
        if os.path.exists(os.path.join(d, '.git')):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def main(argv):
    if len(argv) != 1:
        print('usage: python docs/specs/symbol-map/replay.py <cases.json>', file=sys.stderr)
        return 2
    if not os.path.isfile(argv[0]):
        print('replay: cases file not found: %s' % argv[0], file=sys.stderr)
        return 2
    with open(argv[0], encoding='utf-8') as fh:
        data = json.load(fh)
    cases = data['cases'] if isinstance(data, dict) else data
    roots = []
    for i, c in enumerate(cases, 1):
        root = repo_root(c['story_file'])
        if root is None:
            print('replay: case %d: no repo root above its story file' % i, file=sys.stderr)
            return 2
        roots.append(root)
    bash = shutil.which('bash') or 'bash'
    hits = missed = noise = 0
    for i, (c, root) in enumerate(zip(cases, roots), 1):
        files = list(c.get('files') or [])
        lines = []
        if files:
            cmd = [bash, SM]
            for f in files:
                cmd += ['--scope', f]
            cmd += files
            env = dict(os.environ, PYTHONIOENCODING='utf-8')
            out = subprocess.run(cmd, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env)
            lines = out.stdout.decode('utf-8', 'replace').splitlines()
        n = sum(1 for ln in lines if PATH_LINE.match(ln))
        found = [m for m in c.get('missed') or [] if any(m in ln for ln in lines)]
        unfound = [m for m in c.get('missed') or [] if m not in found]
        hits += len(found)
        missed += len(c.get('missed') or [])
        noise += n
        print('case %d: missed %d hits %d lines %d' % (i, len(c.get('missed') or []), len(found), n))
        for m in unfound:
            print('  unfound %s' % m)
    print('replay: hits %d/%d noise %d over %d stories' % (hits, missed, noise, len(cases)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
