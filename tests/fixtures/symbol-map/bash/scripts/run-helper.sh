#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
exec python "$DIR/helper.py" "$@"
