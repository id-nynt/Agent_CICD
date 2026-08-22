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
    echo "[experiments] FAIL: Python interpreter not found"
    exit 1
  fi
}

echo "[experiments] running Phase 2 scenarios"
"$ROOT_DIR/simulation/scenario_runner.sh" --all

echo "[experiments] generating Phase 3 beliefs"
"$ROOT_DIR/telemetry/belief_mapper.sh"

echo "[experiments] assembling Phase 5 results"
run_python "$ROOT_DIR/experiments/compile_results.py"

echo "[experiments] PASS: results saved to experiments/results and experiments/comparison_table.md"
