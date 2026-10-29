#!/usr/bin/env bash
# py.sh - run Python 3 under whatever name this machine gives it (python3, python, py).
#
#   Usage: bash scripts/py.sh <python-args...>      e.g. bash scripts/py.sh -m py_compile x.py
#
# A stock macOS has no bare `python`, Windows' `python3` may be the Store alias that exits 9009:
# lib.sh's vulyk_python picks the first that really runs Python 3 (a preset VULYK_PY is trusted).
# No Python 3 at all: one stderr line, exit 2. lib.sh is found beside this file, not in the cwd.
# shellcheck source=scripts/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
vulyk_python || { echo "py.sh: no python 3 found (tried python3 python py)" >&2; exit 2; }
exec "$VULYK_PY" "$@"
