#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  elif command -v python >/dev/null 2>&1; then
    python "$@"
  elif command -v py >/dev/null 2>&1; then
    py "$@"
  else
    echo "[real_experiments] FAIL: Python interpreter not found"
    exit 1
  fi
}

run_python "$ROOT_DIR/experiments/real_telemetry_runner.py" "$@"
