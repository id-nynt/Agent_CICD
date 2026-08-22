#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT_DIR/telemetry/belief_mapper.py" "$@"
elif command -v python >/dev/null 2>&1; then
  python "$ROOT_DIR/telemetry/belief_mapper.py" "$@"
elif command -v py >/dev/null 2>&1; then
  py "$ROOT_DIR/telemetry/belief_mapper.py" "$@"
else
  echo "[belief_mapper] FAIL: Python interpreter not found"
  exit 1
fi
